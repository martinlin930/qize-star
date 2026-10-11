create table qize_private.saves(account_id uuid not null references qize_private.accounts(id) on delete cascade,slot integer not null check(slot between 1 and 3),state jsonb not null check(octet_length(state::text)<=4096),updated_at timestamptz not null default now(),primary key(account_id,slot));
alter table qize_private.saves enable row level security;
revoke all on qize_private.saves from public,anon,authenticated;
create function qize_private.save_access(p_token text,p_slot integer,p_state jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare a uuid; items jsonb;
begin
if p_token is null or length(p_token)<>64 then return jsonb_build_object('error','请先登录。');end if;
select account_id into a from qize_private.sessions where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') and expires_at>now();
if a is null then return jsonb_build_object('error','登录已失效，请重新登录。');end if;
if p_slot is not null then
 if p_slot<1 or p_slot>3 or p_state is null or jsonb_typeof(p_state)<>'object' or octet_length(p_state::text)>4096 or p_state->>'scene' is distinct from 'board' or p_state->>'chapter' is distinct from '1' then return jsonb_build_object('error','存档内容无效。');end if;
 insert into qize_private.saves(account_id,slot,state) values(a,p_slot,p_state) on conflict(account_id,slot) do update set state=excluded.state,updated_at=now();
end if;
select coalesce(jsonb_agg(jsonb_build_object('slot',slot,'state',state,'updated_at',updated_at) order by slot),'[]'::jsonb) into items from qize_private.saves where account_id=a;
return jsonb_build_object('saves',items);
end;$$;
revoke all on function qize_private.save_access(text,integer,jsonb) from public;
grant execute on function qize_private.save_access(text,integer,jsonb) to anon;
create function public.qize_saves(p_token text) returns jsonb language sql security invoker set search_path='' as $$select qize_private.save_access(p_token,null,null);$$;
create function public.qize_save(p_token text,p_slot integer,p_state jsonb) returns jsonb language sql security invoker set search_path='' as $$select qize_private.save_access(p_token,p_slot,p_state);$$;
revoke all on function public.qize_saves(text),public.qize_save(text,integer,jsonb) from public;
grant execute on function public.qize_saves(text),public.qize_save(text,integer,jsonb) to anon;
notify pgrst,'reload schema';