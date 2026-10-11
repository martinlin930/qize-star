create schema qize_private;
revoke all on schema qize_private from public;
create table qize_private.accounts (id uuid primary key default gen_random_uuid(), name text not null, name_key text unique not null, password_hash text not null, created_at timestamptz not null default now());
create table qize_private.sessions (token_hash text primary key, account_id uuid not null references qize_private.accounts(id) on delete cascade, expires_at timestamptz not null default now()+interval '7 days');
create index on qize_private.sessions(account_id);
create table qize_private.attempts (name_key text primary key, count integer not null default 1, reset_at timestamptz not null default now()+interval '10 minutes');
alter table qize_private.accounts enable row level security;
alter table qize_private.sessions enable row level security;
alter table qize_private.attempts enable row level security;
revoke all on all tables in schema qize_private from public, anon, authenticated;
create function qize_private.authenticate(p_name text,p_password text,p_register boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare a qize_private.accounts%rowtype; v_name text; v_key text; v_token text; attempts integer;
begin
 v_name:=trim(normalize(p_name,NFKC)); v_key:=lower(v_name);
 if char_length(v_name)<2 or char_length(v_name)>24 or v_name !~ '^[[:alnum:]_一-龥-]+$' or octet_length(p_password)<6 or octet_length(p_password)>72 then return jsonb_build_object('error','名字需为2–24个字；密码需为6–72字节。'); end if;
 insert into qize_private.attempts(name_key) values(v_key) on conflict(name_key) do update set count=case when qize_private.attempts.reset_at<now() then 1 else qize_private.attempts.count+1 end,reset_at=case when qize_private.attempts.reset_at<now() then now()+interval '10 minutes' else qize_private.attempts.reset_at end returning count into attempts;
 if attempts>12 then return jsonb_build_object('error','尝试次数过多，请10分钟后再试。'); end if;
 if p_register then
  insert into qize_private.accounts(name,name_key,password_hash) values(v_name,v_key,extensions.crypt(p_password,extensions.gen_salt('bf',10))) on conflict(name_key) do nothing returning * into a;
  if a.id is null then return jsonb_build_object('error','这个名字已被使用。'); end if;
 else
  select * into a from qize_private.accounts where name_key=v_key;
  if a.id is null or a.password_hash<>extensions.crypt(p_password,a.password_hash) then return jsonb_build_object('error','名字或密码不正确。'); end if;
 end if;
 delete from qize_private.attempts where name_key=v_key;
 v_token:=encode(extensions.gen_random_bytes(32),'hex');
 delete from qize_private.sessions where account_id=a.id and expires_at<now();
 insert into qize_private.sessions(token_hash,account_id) values(encode(extensions.digest(v_token,'sha256'),'hex'),a.id);
 return jsonb_build_object('name',a.name,'token',v_token);
end;$$;
create function qize_private.session(p_token text,p_logout boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_name text; v_hash text;
begin
 if p_token is null or length(p_token)<>64 then return jsonb_build_object('name',null); end if;
 v_hash:=encode(extensions.digest(p_token,'sha256'),'hex');
 if p_logout then delete from qize_private.sessions where token_hash=v_hash;return jsonb_build_object('name',null);end if;
 select a.name into v_name from qize_private.sessions s join qize_private.accounts a on a.id=s.account_id where s.token_hash=v_hash and s.expires_at>now();
 return jsonb_build_object('name',v_name);
end;$$;
revoke all on all functions in schema qize_private from public;
grant usage on schema qize_private to anon;
grant execute on function qize_private.authenticate(text,text,boolean),qize_private.session(text,boolean) to anon;
create function public.qize_register(p_name text,p_password text) returns jsonb language sql security invoker set search_path='' as $$select qize_private.authenticate(p_name,p_password,true);$$;
create function public.qize_login(p_name text,p_password text) returns jsonb language sql security invoker set search_path='' as $$select qize_private.authenticate(p_name,p_password,false);$$;
create function public.qize_session(p_token text) returns jsonb language sql security invoker set search_path='' as $$select qize_private.session(p_token,false);$$;
create function public.qize_logout(p_token text) returns jsonb language sql security invoker set search_path='' as $$select qize_private.session(p_token,true);$$;
revoke all on function public.qize_register(text,text),public.qize_login(text,text),public.qize_session(text),public.qize_logout(text) from public;
grant execute on function public.qize_register(text,text),public.qize_login(text,text),public.qize_session(text),public.qize_logout(text) to anon;
notify pgrst,'reload schema';
