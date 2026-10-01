create or replace function private.signal_analysis(p_days integer)
returns jsonb language sql stable security invoker set search_path = '' as $$
with eligible as materialized (
  select p.*, t.relevant, t.purpose, t.hook as tagged_hook, t.subject, t.has_cta,
    t.specificity, t.slop, t.answers, t.post_id is not null as tagged,
    coalesce(t.answers->>'_schema_version','')='2' as refined
  from public.posts p join public.accounts a on a.id=p.account_id
  left join public.post_tags t on t.post_id=p.id
  where a.status='watch' and p.posted_at > now()-make_interval(days=>p_days)
    and p.posted_at<=now()
), counts as (
  select count(*) as posts, count(*) filter(where outlier is not null) as scored,
    count(*) filter(where outlier is not null and is_winner) as winners,
    count(*) filter(where tagged) as tagged,
    count(*) filter(where outlier is not null and length(coalesce(text,''))>=15) as eligible,
    count(*) filter(where refined and outlier is not null and length(coalesce(text,''))>=15) as refined,
    count(*) filter(where length(coalesce(text,''))>=15 and not refined) as pending
  from eligible
), cohort as materialized (
  select *, case when has_cta>=0.65 then 'with_cta' when has_cta<=0.35 then 'no_cta' end as cta
  from eligible where refined and relevant>=0.7 and outlier is not null
    and length(coalesce(text,''))>=15
), dimensions as materialized (
  select c.id, c.account_id, c.platform, c.is_winner, c.outlier, d.dim, d.val
  from cohort c cross join lateral (values
    ('purpose',c.purpose), ('hook',c.tagged_hook), ('subject',c.subject), ('format',c.format),
    ('cta',c.cta), ('cta_kind',case when c.cta='no_cta' then 'none' when c.cta='with_cta' then c.answers->>'_cta_kind' end),
    ('length',c.features->>'length_bucket'),
    ('weekday',trim(to_char(c.posted_at at time zone 'UTC','Day'))),
    ('specificity',case when c.specificity>=1.5 then 'specific' when c.specificity is not null then 'vague' end),
    ('voice',case when c.slop>=0.65 then 'sounds_ai' when c.slop<=0.35 then 'sounds_human' end),
    ('platform',c.platform)
  ) d(dim,val) where d.val is not null
), baselines as (
  select dim,count(*) as n,avg(is_winner::integer) as rate from dimensions group by dim
), grouped as (
  select d.dim,d.val,count(*) as posts,count(*) filter(where d.is_winner) as winners,
    count(distinct d.account_id) as accounts,avg(d.is_winner::integer) as rate,
    percentile_cont(0.5) within group(order by d.outlier) as median_outlier,
    (array_agg(d.id order by d.outlier desc) filter(where d.is_winner))[1:3] as examples
  from dimensions d group by d.dim,d.val
), pattern_rows as (
  select g.*,b.n as baseline_posts,b.rate as baseline_rate,
    g.rate/nullif(b.rate,0) as lift,
    (g.rate+3.8416/(2*g.posts)-1.96*sqrt((g.rate*(1-g.rate)+3.8416/(4*g.posts))/g.posts))/(1+3.8416/g.posts) as low,
    (g.rate+3.8416/(2*g.posts)+1.96*sqrt((g.rate*(1-g.rate)+3.8416/(4*g.posts))/g.posts))/(1+3.8416/g.posts) as high
  from grouped g join baselines b using(dim)
), patterns as (
  select dim,jsonb_agg(jsonb_build_object('value',val,'posts',posts,'winners',winners,'accounts',accounts,
    'win_rate',rate,'lift',lift,'median_outlier',median_outlier,'examples',examples,
    'baseline_posts',baseline_posts,'baseline_win_rate',baseline_rate,'ci_low',low,'ci_high',high,
    'label_coverage',baseline_posts::numeric/nullif((select count(*) from cohort),0),
    'recommendable',posts>=30 and accounts>=3 and baseline_posts::numeric/nullif((select count(*) from cohort),0)>=0.8 and (select refined::numeric/nullif(eligible,0)>=0.8 from counts)
      and (low>baseline_rate or high<baseline_rate)
  ) order by lift desc nulls last) as vals from pattern_rows group by dim
), pair_base as (
  select a.dim as da,b.dim as db,count(*) as n,avg(a.is_winner::integer) as rate
  from dimensions a join dimensions b on a.id=b.id and a.dim<b.dim
  where a.dim in ('purpose','hook','subject','format','cta','length')
    and b.dim in ('purpose','hook','subject','format','cta','length') group by a.dim,b.dim
), pairs as (
  select a.dim as da,a.val as va,b.dim as db,b.val as vb,count(*) as posts,
    count(*) filter(where a.is_winner) as winners,count(distinct a.account_id) as accounts,
    avg(a.is_winner::integer) as rate,percentile_cont(0.5) within group(order by a.outlier) as median_outlier,
    (array_agg(a.id order by a.outlier desc) filter(where a.is_winner))[1:3] as examples
  from dimensions a join dimensions b on a.id=b.id and a.dim<b.dim
  where a.dim in ('purpose','hook','subject','format','cta','length')
    and b.dim in ('purpose','hook','subject','format','cta','length') group by a.dim,a.val,b.dim,b.val
), paired_accounts as (
  select account_id, platform, format,
    avg(is_winner::integer) filter(where cta='with_cta') as with_rate,
    avg(is_winner::integer) filter(where cta='no_cta') as without_rate
  from cohort where cta is not null group by account_id,platform,format
  having count(*) filter(where cta='with_cta')>=3 and count(*) filter(where cta='no_cta')>=3
), cta_platform as (
  select platform,cta,count(*) as posts,count(*) filter(where is_winner) as winners,
    count(distinct account_id) as accounts,avg(is_winner::integer) as win_rate
  from cohort where cta is not null group by platform,cta
)
select jsonb_build_object(
  'summary',jsonb_build_object('posts',c.posts,'posts_scored',c.scored,'winners',c.winners,
    'base_win_rate',c.winners::numeric/nullif(c.scored,0),'tagged',c.tagged,'untagged',c.pending),
  'analysis',jsonb_build_object('schema_version',2,'eligible_posts',c.eligible,'refined_posts',c.refined,
    'coverage',coalesce(c.refined::numeric/nullif(c.eligible,0),0),'posts',(select count(*) from cohort),
    'winners',(select count(*) from cohort where is_winner),
    'accounts',(select count(distinct account_id) from cohort),
    'minimum_posts',30,'minimum_accounts',3,'minimum_coverage',0.8,
    'scope','Watched accounts in selected dates. Patterns use scored posts read with rubric v2 and relevant >= 0.7. Each dimension uses only posts with a known label.',
    'limitations','Text-only labels; public collection is incomplete and X favors older top posts. Observational associations do not prove causation or client demand.'),
  'platforms',coalesce((select jsonb_agg(jsonb_build_object('platform',platform,'posts',posts,'winners',winners,'accounts',accounts) order by posts desc)
    from (select platform,count(*) as posts,count(*) filter(where outlier is not null and is_winner) as winners,count(distinct account_id) as accounts from eligible group by platform) p),'[]'::jsonb),
  'patterns',coalesce((select jsonb_object_agg(dim,vals) from patterns),'{}'::jsonb),
  'combos',coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('a',p.da,'va',p.va,'b',p.db,'vb',p.vb,'posts',p.posts,'winners',p.winners,
      'accounts',p.accounts,'lift',p.rate/nullif(b.rate,0),'median_outlier',p.median_outlier,'examples',p.examples) as x
    from pairs p join pair_base b on p.da=b.da and p.db=b.db
    where p.posts>=30 and p.accounts>=3 and p.winners>=5 and p.rate>b.rate
      and b.n::numeric/nullif((select count(*) from cohort),0)>=0.8
      and c.refined::numeric/nullif(c.eligible,0)>=0.8
      and (p.rate+3.8416/(2*p.posts)-1.96*sqrt((p.rate*(1-p.rate)+3.8416/(4*p.posts))/p.posts))/(1+3.8416/p.posts)>b.rate
    order by p.rate/nullif(b.rate,0) desc limit 14) z),'[]'::jsonb),
  'cta_analysis',jsonb_build_object(
    'groups',coalesce((select jsonb_agg(to_jsonb(r)) from pattern_rows r where dim='cta'),'[]'::jsonb),
    'by_platform',coalesce((select jsonb_agg(to_jsonb(r)) from cta_platform r),'[]'::jsonb),
    'paired_groups',(select count(*) from paired_accounts),
    'paired_accounts',(select count(distinct account_id) from paired_accounts),
    'paired_difference',(select avg(with_rate-without_rate) from paired_accounts),
    'unknown',(select count(*) from cohort where cta is null),
    'note','Compare CTA and no CTA within the same account and format. Free-resource replies are engagement incentives, not sales evidence. A CTA is optional; this analysis does not establish viral causation.'),
  'top_posts',coalesce((select jsonb_agg(public.post_card(id) order by outlier desc) from
    (select id,outlier from eligible where is_winner and outlier is not null order by outlier desc limit 40) t),'[]'::jsonb),
  'examples',coalesce((select jsonb_object_agg(id,public.post_card(id)) from cohort where is_winner),'{}'::jsonb)
) from counts c;
$$;
revoke all on function private.signal_analysis(integer) from public,anon,authenticated;
