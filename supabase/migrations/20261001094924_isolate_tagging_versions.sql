-- Keep previous tags for reference, but re-read them with the refined v2 rubric.
-- Sample independently of engagement, round-robin across accounts.
create or replace function public.laya_next_posts_v2(p_token text, p_limit integer default 25)
returns table(id text, platform text, handle text, text text)
language plpgsql security definer set search_path = '' as $$
begin
  if p_token is null or p_token is distinct from (select value from private.config where key = 'worker_token') then
    raise exception 'invalid worker token';
  end if;
  return query
  with queue as (
    select p.id, p.platform, p.handle, left(p.text,3000) as body,
      row_number() over (partition by p.account_id order by md5(p.id || ':v2')) as account_rank
    from public.posts p join public.accounts a on a.id=p.account_id
    left join public.post_tags t on t.post_id=p.id
    where a.status='watch' and length(coalesce(p.text,''))>=15
      and coalesce(t.answers->>'_schema_version','') <> '2'
  )
  select q.id, q.platform, q.handle, q.body from queue q
  order by q.account_rank, md5(q.id || ':v2') limit greatest(0,least(p_limit,100));
end $$;
revoke all on function public.laya_next_posts_v2(text,integer) from public;
grant execute on function public.laya_next_posts_v2(text,integer) to anon, authenticated;


-- Older in-flight workers may finish untagged posts, but cannot overwrite v2 tags.
create or replace function public.laya_next_posts(p_token text,p_limit integer default 25)
returns table(id text,platform text,handle text,text text)
language plpgsql security definer set search_path='' as $$
begin
  if p_token is null or p_token is distinct from (select value from private.config where key='worker_token') then
    raise exception 'invalid worker token';
  end if;
  return query select p.id,p.platform,p.handle,left(p.text,3000)
  from public.posts p join public.accounts a on a.id=p.account_id
  left join public.post_tags t on t.post_id=p.id
  where a.status='watch' and t.post_id is null and length(coalesce(p.text,''))>=15
  order by md5(p.id) limit greatest(0,least(p_limit,100));
end $$;
revoke all on function public.laya_next_posts(text,integer) from public;
grant execute on function public.laya_next_posts(text,integer) to anon,authenticated;
