alter table qize_private.accounts add column character_name text check(char_length(character_name) between 1 and 24);
create function qize_private.profile(p_token text,p_name text) returns jsonb language plpgsql security definer set search_path='' as $$
declare a uuid;v_name text;
begin
if p_token is null or length(p_token)<>64 then return jsonb_build_object('error','请先登录。');end if;
select account_id into a from qize_private.sessions where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') and expires_at>now();
if a is null then return jsonb_build_object('error','登录已失效，请重新登录。');end if;
if p_name is not null then
 v_name:=trim(normalize(p_name,NFKC));
 if char_length(v_name)<1 or char_length(v_name)>24 or v_name ~ '[[:cntrl:]]' then return jsonb_build_object('error','名字需为1–24个字。');end if;
 update qize_private.accounts set character_name=v_name where id=a and character_name is null;
end if;
select character_name into v_name from qize_private.accounts where id=a;
return jsonb_build_object('character_name',v_name);
end;$$;
revoke all on function qize_private.profile(text,text) from public;
grant execute on function qize_private.profile(text,text) to anon;
create function public.qize_profile(p_token text,p_name text default null) returns jsonb language sql security invoker set search_path='' as $$select qize_private.profile(p_token,p_name);$$;
revoke all on function public.qize_profile(text,text) from public;
grant execute on function public.qize_profile(text,text) to anon;
create or replace function qize_private.save_access(p_token text,p_slot integer,p_state jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare a uuid;items jsonb;v_name text;
begin
if p_token is null or length(p_token)<>64 then return jsonb_build_object('error','请先登录。');end if;
select account_id into a from qize_private.sessions where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') and expires_at>now();
if a is null then return jsonb_build_object('error','登录已失效，请重新登录。');end if;
select character_name into v_name from qize_private.accounts where id=a;
if p_slot is not null then
 if p_slot<1 or p_slot>3 or p_state is null or jsonb_typeof(p_state)<>'object' or octet_length(p_state::text)>4096 or p_state->>'scene' is null or p_state->>'scene' not in ('board','play') or p_state->>'chapter' is distinct from '1' then return jsonb_build_object('error','存档内容无效。');end if;
 if p_state->>'scene'='play' and v_name is null then return jsonb_build_object('error','请先输入你的角色名字。');end if;
 insert into qize_private.saves(account_id,slot,state) values(a,p_slot,p_state||jsonb_build_object('character_name',v_name)) on conflict(account_id,slot) do update set state=excluded.state,updated_at=now();
end if;
select coalesce(jsonb_agg(jsonb_build_object('slot',slot,'state',state||jsonb_build_object('character_name',v_name),'updated_at',updated_at) order by slot),'[]'::jsonb) into items from qize_private.saves where account_id=a;
return jsonb_build_object('saves',items);
end;$$;
notify pgrst,'reload schema';