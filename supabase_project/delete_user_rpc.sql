-- Run this exact block in your Supabase SQL Editor to enable true account deletion

CREATE OR REPLACE FUNCTION delete_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 1. Delete the user from the public.users table. 
  -- Since ON DELETE CASCADE is set on related tables (topics, subjects, review_history), they will be wiped automatically.
  DELETE FROM public.users WHERE user_id = auth.uid();
  
  -- 2. Delete the user from the system authentication table.
  -- This requires SECURITY DEFINER privileges to execute successfully.
  -- This makes sure the user is completely gone, meaning Google/Apple logins will act as brand new accounts next time.
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;
