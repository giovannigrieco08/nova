-- =====================================================================
-- Migration: 015b_fix_chat_policies_idempotent.sql
-- Purpose: Make chat RLS policies idempotent by dropping before creating
-- Date: 2025-12-05
-- =====================================================================
-- Run this INSTEAD of 015 if policies already exist partially

-- =====================================================================
-- PHASE 1: DROP EXISTING POLICIES (if any)
-- =====================================================================

-- chat_messages policies
DROP POLICY IF EXISTS "chat_messages_select_visible" ON chat_messages;
DROP POLICY IF EXISTS "chat_messages_select_moderators" ON chat_messages;
DROP POLICY IF EXISTS "chat_messages_insert_own" ON chat_messages;
DROP POLICY IF EXISTS "chat_messages_update_moderators" ON chat_messages;

-- chat_reactions policies
DROP POLICY IF EXISTS "chat_reactions_select_visible" ON chat_reactions;
DROP POLICY IF EXISTS "chat_reactions_insert_own" ON chat_reactions;
DROP POLICY IF EXISTS "chat_reactions_delete_own" ON chat_reactions;

-- chat_reports policies
DROP POLICY IF EXISTS "chat_reports_select_own" ON chat_reports;
DROP POLICY IF EXISTS "chat_reports_select_moderators" ON chat_reports;
DROP POLICY IF EXISTS "chat_reports_insert_own" ON chat_reports;
DROP POLICY IF EXISTS "chat_reports_update_moderators" ON chat_reports;

-- chat_media policies
DROP POLICY IF EXISTS "chat_media_select_visible" ON chat_media;
DROP POLICY IF EXISTS "chat_media_insert_own" ON chat_media;
DROP POLICY IF EXISTS "chat_media_update_viewed" ON chat_media;

-- =====================================================================
-- PHASE 2: RECREATE ALL POLICIES
-- =====================================================================

-- ---------------------------------------------------------------------
-- chat_messages RLS
-- ---------------------------------------------------------------------

-- Policy 1: Authenticated users can view non-hidden messages
CREATE POLICY "chat_messages_select_visible"
  ON chat_messages FOR SELECT
  TO authenticated
  USING (hidden_at IS NULL);

-- Policy 2: Moderators can view all messages (including hidden)
CREATE POLICY "chat_messages_select_moderators"
  ON chat_messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  );

-- Policy 3: Users can insert their own messages
CREATE POLICY "chat_messages_insert_own"
  ON chat_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND hidden_at IS NULL
  );

-- Policy 4: Moderators can update messages (hide/unhide)
CREATE POLICY "chat_messages_update_moderators"
  ON chat_messages FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  );

-- ---------------------------------------------------------------------
-- chat_reactions RLS
-- ---------------------------------------------------------------------

-- Policy 1: Users can view reactions on visible messages
CREATE POLICY "chat_reactions_select_visible"
  ON chat_reactions FOR SELECT
  TO authenticated
  USING (
    message_id IN (
      SELECT id FROM chat_messages WHERE hidden_at IS NULL
    )
  );

-- Policy 2: Users can add reactions
CREATE POLICY "chat_reactions_insert_own"
  ON chat_reactions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Policy 3: Users can remove their own reactions
CREATE POLICY "chat_reactions_delete_own"
  ON chat_reactions FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- chat_reports RLS
-- ---------------------------------------------------------------------

-- Policy 1: Users can view own reports
CREATE POLICY "chat_reports_select_own"
  ON chat_reports FOR SELECT
  TO authenticated
  USING (auth.uid() = reporter_user_id);

-- Policy 2: Moderators can view all reports
CREATE POLICY "chat_reports_select_moderators"
  ON chat_reports FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  );

-- Policy 3: Users can submit reports
CREATE POLICY "chat_reports_insert_own"
  ON chat_reports FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = reporter_user_id
    AND status = 'pending'
  );

-- Policy 4: Moderators can update report status
CREATE POLICY "chat_reports_update_moderators"
  ON chat_reports FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  );

-- ---------------------------------------------------------------------
-- chat_media RLS
-- ---------------------------------------------------------------------

-- Policy 1: Users can view media metadata for visible messages
CREATE POLICY "chat_media_select_visible"
  ON chat_media FOR SELECT
  TO authenticated
  USING (
    message_id IN (
      SELECT id FROM chat_messages WHERE hidden_at IS NULL
    )
  );

-- Policy 2: Users can insert media (uploader only)
CREATE POLICY "chat_media_insert_own"
  ON chat_media FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = uploader_user_id);

-- Policy 3: Any user can mark media as viewed (not own media)
CREATE POLICY "chat_media_update_viewed"
  ON chat_media FOR UPDATE
  TO authenticated
  USING (
    is_viewed = FALSE
    AND auth.uid() != uploader_user_id
  )
  WITH CHECK (
    is_viewed = TRUE
    AND viewed_by_user_id = auth.uid()
  );

-- =====================================================================
-- DONE - All policies recreated
-- =====================================================================
