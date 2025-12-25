// Setup for Supabase Database to support Push Notifications

-- 1. Create Device Tokens Table
create table public.device_tokens (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) not null,
  token text not null,
  platform text default 'ios',
  updated_at timestamptz default now(),
  unique(user_id, token)
);

-- 2. RLS Policies
alter table public.device_tokens enable row level security;

create policy "Users can insert their own tokens" 
on public.device_tokens for insert 
with check (auth.uid() = user_id);

create policy "Users can update their own tokens" 
on public.device_tokens for update 
using (auth.uid() = user_id);

create policy "Users can read their own tokens" 
on public.device_tokens for select 
using (auth.uid() = user_id);

-- 3. Webhook Trigger
-- You must go to Supabase Dashboard -> Database -> Webhooks to creating this link visually OR use the below if supported in your tier.
-- Trigger name: "push_on_task"
-- Table: "simple_checklists"
-- Events: INSERT
-- Webhook URL: (Your deployed Edge Function URL)

-- Repeat for "milestones" table.
