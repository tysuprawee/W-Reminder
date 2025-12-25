# Push Notification Deployment Guide

To complete the setup of your "Notification Silo" fix using Supabase Edge Functions:

## 1. Database Setup
1. Open your Supabase Dashboard -> **SQL Editor**.
2. Copy the content from `supabase/database_setup.sql` in your project and run it.
   - This creates the `device_tokens` table.

## 2. Deploy the Edge Function
1. Ensure you have the Supabase CLI installed.
2. Login: `supabase login`
3. Deploy:
   ```bash
   supabase functions deploy push-dispatcher
   ```
   Note: If you haven't linked your project, run `supabase link --project-ref your-project-ref` first.

## 3. Set Secrets
Go to Supabase Dashboard -> **Edge Functions** -> `push-dispatcher` -> **Secrets** and add:

- `APNS_TEAM_ID`: Your Apple Team ID (e.g. X1Y2Z3...)
- `APNS_KEY_ID`: The Key ID of your .p8 file.
- `APNS_P8_KEY`: The **contents** of your .p8 file. 
  - *Tip*: Copy the full content including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`.

## 4. Setup Webhooks
1. Go to Supabase Dashboard -> **Database** -> **Webhooks**.
2. Create a new Webhook.
   - **Name**: `notify-on-task`
   - **Table**: `simple_checklists`
   - **Events**: `INSERT`
   - **Type**: `HTTP Request`
   - **Method**: `POST`
   - **URL**: (Your Edge Function URL, e.g., `https://xyz.supabase.co/functions/v1/push-dispatcher`)
   - **HTTP Headers**: Add `Authorization: Bearer <YOUR_ANON_KEY>` (or service role specific header if needed, but usually Anon is fine if function handles permissions, though strictly Service Role is safer for internal webhooks).
3. Repeat for `milestones` table.
