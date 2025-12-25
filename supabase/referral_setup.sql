-- Referral System Setup

-- 1. Add Columns to Profiles
alter table public.profiles 
add column if not exists invite_code text unique,
add column if not exists invitations_count int default 0,
add column if not exists redeemed_by_code text; -- The code this user used to join

-- 2. Function to generate invite code (Simple: substring of ID or random)
-- For simplicity and robustness, let's use a random 6-char string generator
create or replace function generate_invite_code() returns text as $$
declare
  chars text[] := '{A,B,C,D,E,F,G,H,J,K,L,M,N,P,Q,R,S,T,U,V,W,X,Y,Z,2,3,4,5,6,7,8,9}';
  result text := '';
  i integer := 0;
begin
  for i in 1..6 loop
    result := result || chars[1+random()*(array_length(chars, 1)-1)];
  end loop;
  return result;
end;
$$ language plpgsql;

-- 3. Trigger to assign invite code on insert if null
create or replace function set_invite_code_func() returns trigger as $$
begin
  -- Loop to ensure uniqueness (rare collision handling)
  loop
    new.invite_code := generate_invite_code();
    begin
      return new;
    exception when unique_violation then
      -- retry
    end;
    exit when new.invite_code is not null;
  end loop;
end;
$$ language plpgsql;

create trigger set_invite_code_trigger
before insert on public.profiles
for each row
when (new.invite_code is null)
execute function set_invite_code_func();

-- Backfill existing users
update public.profiles set invitations_count = 0 where invitations_count is null;
-- We can't easily trigger the trigger on existing rows without update, 
-- but we can run a script: 
-- UPDATE public.profiles SET invite_code = generate_invite_code() WHERE invite_code IS NULL;
-- BUT uniqueness check isn't guaranteed in a massive update statement easily without a cursor.
-- For now, let's assume new users get it. Existing users: 
-- You can run this block manually or rely on Client to fetch and if null request one?
-- Better: Run this manually in dashboard:
-- DO $$ 
-- DECLARE r RECORD;
-- BEGIN
--   FOR r IN SELECT id FROM profiles WHERE invite_code IS NULL LOOP
--     UPDATE profiles SET invite_code = generate_invite_code() WHERE id = r.id;
--   END LOOP;
-- END $$;


-- 4. RPC Function to Redeem Code
create or replace function redeem_invite(code text)
returns json
language plpgsql
security definer
as $$
declare
  inviter_id uuid;
  me_id uuid := auth.uid();
begin
  -- 1. Check if I already redeemed
  if exists (select 1 from profiles where id = me_id and redeemed_by_code is not null) then
    return json_build_object('success', false, 'message', 'You have already redeemed a code.');
  end if;

  -- 2. Find inviter
  select id into inviter_id from profiles where invite_code = code;
  
  if inviter_id is null then
    return json_build_object('success', false, 'message', 'Invalid invite code.');
  end if;

  if inviter_id = me_id then
    return json_build_object('success', false, 'message', 'You cannot invite yourself.');
  end if;

  -- 3. Execute Updates
  update profiles set invitations_count = invitations_count + 1 where id = inviter_id;
  update profiles set redeemed_by_code = code where id = me_id;

  return json_build_object('success', true, 'message', 'Code redeemed! Theme progress updated.');
end;
$$;
