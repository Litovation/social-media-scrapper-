-- A separate dashboard token avoids putting a service-role key on the laptop.
insert into private.config(key, value) values
  ('dashboard_token', encode(extensions.gen_random_bytes(24), 'hex'))
on conflict (key) do nothing;

create or replace function private.check_dashboard_token(p_token text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_token is null or p_token is distinct from (select value from private.config where key = 'dashboard_token') then
    raise exception 'Invalid dashboard token' using errcode = '42501';
  end if;
end $$;

create or replace function public.signal_dashboard(p_token text, p_days int default 30)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform private.check_dashboard_token(p_token);
  return public.dashboard(p_days);
end $$;

create or replace function public.signal_add_account(p_token text, p_platform text, p_handle text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform private.check_dashboard_token(p_token);
  return public.add_account(p_platform, p_handle);
end $$;

create or replace function public.signal_add_source(p_token text, p_platform text, p_value text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform private.check_dashboard_token(p_token);
  return public.add_source(p_platform, p_value);
end $$;

create or replace function public.signal_set_account_status(p_token text, p_id bigint, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform private.check_dashboard_token(p_token);
  if p_status not in ('watch','ignored') then raise exception 'Invalid status'; end if;
  perform public.set_account_status(p_id, p_status);
end $$;

revoke all on function private.check_dashboard_token(text) from public, anon, authenticated;
revoke all on function public.signal_dashboard(text, int), public.signal_add_account(text, text, text), public.signal_add_source(text, text, text), public.signal_set_account_status(text, bigint, text) from public;
grant execute on function public.signal_dashboard(text, int), public.signal_add_account(text, text, text), public.signal_add_source(text, text, text), public.signal_set_account_status(text, bigint, text) to anon, authenticated;
