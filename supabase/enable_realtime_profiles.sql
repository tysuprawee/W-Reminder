-- Enable Realtime for Profiles Table
-- This is required for clients to receive UPDATE events.

-- 1. Add 'profiles' to the default 'supabase_realtime' publication
begin;
  -- Remove from publication first to avoid errors if already present (optional safety, or just try add)
  -- But simpler: Just add it. If it exists, SQL might warn or error slightly depending on version, 
  -- but usually 'alter publication ... add table' is idempotent-ish or we can check.
  
  -- The safe way:
  alter publication supabase_realtime add table profiles;
  
commit;

-- 2. Ensure Replica Identity is set so we get enough info (usually DEFAULT is fine for ID filtering)
alter table profiles replica identity full; 
-- 'full' ensures we get the *old* record too, which helps sometimes, 
-- but for simple ID filtering 'default' (pk) is enough. 'full' is safer for debugging.
