-- RPC to generate invite code for existing user (self)
create or replace function generate_my_invite_code()
returns text
language plpgsql
security definer
as $$
declare
  new_code text;
  me_id uuid := auth.uid();
begin
  -- Check if already has one
  select invite_code into new_code from profiles where id = me_id;
  if new_code is not null then
    return new_code;
  end if;

  -- Generate
  loop
    new_code := generate_invite_code();
    begin
      update profiles set invite_code = new_code where id = me_id;
      return new_code;
    exception when unique_violation then
      -- retry
    end;
  end loop;
end;
$$;
