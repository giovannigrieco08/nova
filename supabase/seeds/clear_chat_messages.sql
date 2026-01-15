-- =====================================================================
-- Script: clear_chat_messages.sql
-- Purpose: Clear all chat messages from the database
-- Usage: Run this in Supabase SQL Editor to delete all chat messages
-- =====================================================================

-- WARNING: This will permanently delete ALL chat messages, reactions, reports, and media!
-- This action cannot be undone.

-- Step 1: Delete all media files from storage
-- Note: Storage cleanup must be done manually via Supabase Dashboard
-- Go to Storage > ephemeral-media > Delete all files

-- Step 2: Delete all chat messages (CASCADE will handle reactions, reports, media records)
DELETE FROM chat_messages;

-- Step 3: Verify deletion
SELECT COUNT(*) as remaining_messages FROM chat_messages;
SELECT COUNT(*) as remaining_reactions FROM chat_reactions;
SELECT COUNT(*) as remaining_reports FROM chat_reports;
SELECT COUNT(*) as remaining_media FROM chat_media;

-- Expected output: all counts should be 0
