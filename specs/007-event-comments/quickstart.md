# Quickstart Guide: Event Comments System

**Feature**: Event Comments System
**Branch**: `007-event-comments`
**Created**: 2025-01-22
**Phase**: Phase 1 (Integration & Testing Scenarios)

## Overview

This guide provides step-by-step integration scenarios and testing instructions for developers implementing the event comments system. Follow these examples to understand the complete user flows and validate implementation.

---

## Prerequisites

### 1. Development Environment Setup

```bash
# Ensure Flutter SDK is installed
flutter doctor

# Navigate to project root
cd c:\Users\grigi\nova_def\nova

# Install dependencies (including new comment feature dependencies)
flutter pub get

# Run code generation (for Riverpod, Freezed, etc.)
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Supabase Database Setup

```bash
# Navigate to Supabase directory
cd c:\Users\grigi\nova_def\supabase

# Apply migration (creates comments, comment_likes, comment_reports tables)
supabase db push

# Verify tables exist
psql "postgresql://postgres.jhnxscorszeslkhnxtif:Luciferasfuck2006.@aws-0-eu-central-1.pooler.supabase.com:6543/postgres" -c "\dt"

# Expected output:
# comments
# comment_likes
# comment_reports
```

### 3. Test Data Seed

```sql
-- Insert test event (if not exists)
INSERT INTO events (id, title, description, status, created_by_user_id)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Torneo di Pallavolo',
  'Torneo amichevole tra classi',
  'approved',
  (SELECT id FROM profiles LIMIT 1)
);

-- Insert test user profiles (if not exists)
INSERT INTO profiles (id, name, email, class, role)
VALUES
  ('00000000-0000-0000-0000-000000000010', 'Marco Rossi', 'marco.rossi@galileimoro.edu.it', '5A', 'student'),
  ('00000000-0000-0000-0000-000000000020', 'Giulia Bianchi', 'giulia.bianchi@galileimoro.edu.it', '4B', 'student'),
  ('00000000-0000-0000-0000-000000000030', 'Prof. Anna Verdi', 'anna.verdi@galileimoro.edu.it', null, 'moderator')
ON CONFLICT (id) DO NOTHING;
```

---

## Integration Scenario 1: View and Post Comments

### User Story
As a student, I open an event detail screen, view existing comments, and post a new comment asking a question about the event.

### Implementation Steps

#### Step 1: Navigate to Event Detail Screen

```dart
// From events feed, tap on event card
Navigator.of(context).push(
  Platform.isIOS
    ? CupertinoPageRoute(builder: (_) => EventDetailScreen(eventId: eventId))
    : MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: eventId)),
);
```

#### Step 2: Display Comments Button

```dart
// In EventDetailScreen, add comments button to bottom action bar
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    // ... Like button, Share button ...

    // Comments button
    AdaptiveButton(
      onPressed: () => _openCommentsSheet(context, ref),
      child: Row(
        children: [
          Icon(Platform.isIOS ? CupertinoIcons.chat_bubble : Icons.comment),
          SizedBox(width: 4),
          Text('${event.commentCount} commenti'),
        ],
      ),
    ),
  ],
)
```

#### Step 3: Open Comments Bottom Sheet

```dart
void _openCommentsSheet(BuildContext context, WidgetRef ref) {
  if (Platform.isIOS) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CommentsSheet(eventId: widget.eventId),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CommentsSheet(eventId: widget.eventId),
    );
  }
}
```

#### Step 4: Load Comments with Riverpod

```dart
// In CommentsSheet widget
class CommentsSheet extends ConsumerStatefulWidget {
  final String eventId;

  const CommentsSheet({required this.eventId, super.key});

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  @override
  void initState() {
    super.initState();
    // Load comments on mount
    Future.microtask(() {
      ref.read(commentsNotifierProvider(widget.eventId).notifier).loadComments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsNotifierProvider(widget.eventId));

    return commentsAsync.when(
      data: (comments) => _buildCommentsList(comments),
      loading: () => Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Errore: $error')),
    );
  }
}
```

#### Step 5: Display Comments List

```dart
Widget _buildCommentsList(List<Comment> comments) {
  if (comments.isEmpty) {
    return EmptyCommentsState(
      message: 'Nessun commento ancora',
      subtitle: 'Sii il primo a commentare!',
    );
  }

  return ListView.builder(
    itemCount: comments.length,
    itemBuilder: (context, index) {
      final comment = comments[index];
      return CommentCard(
        comment: comment,
        onLike: () => _onLikeComment(comment.id),
        onReply: () => _onReplyToComment(comment),
        onReport: () => _onReportComment(comment),
      );
    },
  );
}
```

#### Step 6: Post New Comment

```dart
// Comment input field at bottom of sheet (sticky)
class CommentInputField extends ConsumerStatefulWidget {
  final String eventId;
  final Comment? replyingTo; // null for top-level comment

  const CommentInputField({
    required this.eventId,
    this.replyingTo,
    super.key,
  });

  @override
  ConsumerState<CommentInputField> createState() => _CommentInputFieldState();
}

class _CommentInputFieldState extends ConsumerState<CommentInputField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  Future<void> _onSubmit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      if (widget.replyingTo != null) {
        await ref.read(commentsNotifierProvider(widget.eventId).notifier).replyToComment(
          parentCommentId: widget.replyingTo!.id,
          text: text,
        );
      } else {
        await ref.read(commentsNotifierProvider(widget.eventId).notifier).postComment(
          text: text,
        );
      }

      _controller.clear();
      _focusNode.unfocus();

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Commento pubblicato!')),
      );
    } catch (e) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS
      ? CupertinoTextField(
          controller: _controller,
          focusNode: _focusNode,
          placeholder: widget.replyingTo != null
            ? 'Rispondi a ${widget.replyingTo!.author.name}...'
            : 'Aggiungi un commento...',
          maxLength: 500,
          maxLines: null, // Grows up to 5 lines
          suffix: CupertinoButton(
            child: Text('Pubblica'),
            onPressed: _onSubmit,
          ),
        )
      : TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: widget.replyingTo != null
              ? 'Rispondi a ${widget.replyingTo!.author.name}...'
              : 'Aggiungi un commento...',
            suffixIcon: IconButton(
              icon: Icon(Icons.send),
              onPressed: _onSubmit,
            ),
          ),
          maxLength: 500,
        );
  }
}
```

### Testing Scenario

1. **Open event detail screen** for "Torneo di Pallavolo"
2. **Tap "Commenti" button** → Comments sheet slides up
3. **Verify empty state** (if no comments yet): "Nessun commento ancora"
4. **Type comment**: "Ci sono ancora posti disponibili?"
5. **Tap "Pubblica"** → Comment appears instantly (optimistic UI)
6. **Verify server sync**: Comment persists after refresh
7. **Verify counter update**: Event card shows "1 commento"

---

## Integration Scenario 2: Like and Unlike Comments

### User Story
As a student, I like a helpful comment and later unlike it if I change my mind. The UI updates instantly without waiting for the server.

### Implementation Steps

#### Step 1: Display Like Button in CommentCard

```dart
class CommentCard extends ConsumerWidget {
  final Comment comment;
  final VoidCallback onLike;

  const CommentCard({
    required this.comment,
    required this.onLike,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.all(NovaSpacing.medium),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            backgroundImage: NetworkImage(comment.author.avatarUrl ?? ''),
            radius: 20,
          ),

          SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author name + timestamp
                Row(
                  children: [
                    Text(
                      comment.author.name,
                      style: NovaTypography.bodyMediumBold,
                    ),
                    SizedBox(width: 8),
                    Text(
                      comment.relativeTimestamp,
                      style: NovaTypography.captionSecondary,
                    ),
                  ],
                ),

                SizedBox(height: 4),

                // Comment text
                Text(
                  comment.displayText,
                  style: NovaTypography.bodyMedium,
                ),

                SizedBox(height: 8),

                // Actions row
                Row(
                  children: [
                    // Like button
                    LikeButton(
                      isLiked: comment.isLikedByCurrentUser,
                      likeCount: comment.likeCount,
                      onTap: onLike,
                    ),

                    SizedBox(width: 16),

                    // Reply button
                    TextButton(
                      onPressed: () => onReply?.call(),
                      child: Text('Rispondi'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### Step 2: Implement Like Button with Optimistic UI

```dart
class LikeButton extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final VoidCallback onTap;

  const LikeButton({
    required this.isLiked,
    required this.likeCount,
    required this.onTap,
    super.key,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  void _handleTap() {
    // Trigger animation
    _controller.forward().then((_) => _controller.reverse());

    // Call parent handler (optimistic update)
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Row(
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Icon(
              widget.isLiked
                ? (Platform.isIOS ? CupertinoIcons.heart_fill : Icons.favorite)
                : (Platform.isIOS ? CupertinoIcons.heart : Icons.favorite_border),
              color: widget.isLiked ? NovaColors.accent : NovaColors.textSecondary,
              size: 20,
            ),
          ),
          if (widget.likeCount > 0) ...[
            SizedBox(width: 4),
            Text(
              '${widget.likeCount}',
              style: NovaTypography.caption.copyWith(
                color: widget.isLiked ? NovaColors.accent : NovaColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

#### Step 3: Handle Like/Unlike in CommentsNotifier

```dart
class CommentsNotifier extends AsyncNotifier<List<Comment>> {
  @override
  Future<List<Comment>> build() async {
    return [];
  }

  Future<void> toggleLike(String commentId) async {
    final currentComments = state.value ?? [];
    final comment = currentComments.firstWhere((c) => c.id == commentId);

    // Optimistic update (instant UI feedback)
    final optimisticComments = currentComments.map((c) {
      if (c.id == commentId) {
        return c.copyWith(
          isLikedByCurrentUser: !c.isLikedByCurrentUser,
          likeCount: c.isLikedByCurrentUser ? c.likeCount - 1 : c.likeCount + 1,
        );
      }
      return c;
    }).toList();

    state = AsyncValue.data(optimisticComments);

    // Server request (background)
    try {
      if (comment.isLikedByCurrentUser) {
        await ref.read(commentsRepositoryProvider).unlikeComment(commentId: commentId);
      } else {
        await ref.read(commentsRepositoryProvider).likeComment(commentId: commentId);
      }
    } catch (e) {
      // Rollback on error
      state = AsyncValue.data(currentComments);

      // Show error notification
      ref.read(errorNotifierProvider.notifier).show('Errore: impossibile mettere mi piace');
    }
  }
}
```

### Testing Scenario

1. **View comment** with 3 likes (heart icon empty)
2. **Tap heart icon** → Icon fills immediately, count shows "4" (optimistic)
3. **Verify animation** → Heart scales up 1.3x and back (200ms)
4. **Verify server sync** → Network request completes, like persists
5. **Tap heart again** → Icon empties, count shows "3" (optimistic unlike)
6. **Test error handling** → Disconnect network, tap heart → Error toast shown, count reverts to "3"

---

## Integration Scenario 3: Reply to Comments (Threading)

### User Story
As a student, I reply to another student's question to help them out. The reply appears indented beneath the original comment.

### Implementation Steps

#### Step 1: Add Reply Button to CommentCard

```dart
// In CommentCard actions row
TextButton(
  onPressed: () => onReply?.call(),
  child: Text('Rispondi'),
)
```

#### Step 2: Enable Reply Mode in CommentsSheet

```dart
class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  Comment? _replyingTo;

  void _onReplyToComment(Comment comment) {
    setState(() {
      _replyingTo = comment;
    });
    _inputFocusNode.requestFocus(); // Focus input field
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Reply indicator banner (if replying)
        if (_replyingTo != null)
          ReplyIndicatorBanner(
            comment: _replyingTo!,
            onCancel: _cancelReply,
          ),

        // Comments list
        Expanded(child: _buildCommentsList()),

        // Input field (sticky bottom)
        CommentInputField(
          eventId: widget.eventId,
          replyingTo: _replyingTo,
          onSubmit: () => _cancelReply(), // Clear reply mode after submit
        ),
      ],
    );
  }
}
```

#### Step 3: Display Reply Indicator Banner

```dart
class ReplyIndicatorBanner extends StatelessWidget {
  final Comment comment;
  final VoidCallback onCancel;

  const ReplyIndicatorBanner({
    required this.comment,
    required this.onCancel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: NovaColors.backgroundSecondary,
      child: Row(
        children: [
          Icon(
            Platform.isIOS ? CupertinoIcons.reply : Icons.reply,
            size: 16,
            color: NovaColors.textSecondary,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Risposta a ${comment.author.name}: "${comment.text.substring(0, min(30, comment.text.length))}..."',
              style: NovaTypography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Platform.isIOS ? CupertinoIcons.xmark : Icons.close),
            iconSize: 18,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
```

#### Step 4: Render Indented Replies

```dart
Widget _buildCommentsList(List<Comment> comments) {
  // Flatten thread: top-level comments + indented replies
  final flatComments = <CommentWithLevel>[];

  for (final comment in comments) {
    // Add top-level comment
    flatComments.add(CommentWithLevel(comment, level: 0));

    // Add replies (1-level deep)
    if (comment.replies != null && comment.replies!.isNotEmpty) {
      for (final reply in comment.replies!) {
        flatComments.add(CommentWithLevel(reply, level: 1));
      }
    }
  }

  return ListView.builder(
    itemCount: flatComments.length,
    itemBuilder: (context, index) {
      final item = flatComments[index];
      return Padding(
        padding: EdgeInsets.only(left: item.level * 48.0), // 48px indent per level
        child: CommentCard(
          comment: item.comment,
          isReply: item.level > 0,
          onLike: () => _onLikeComment(item.comment.id),
          onReply: () => _onReplyToComment(item.comment),
        ),
      );
    },
  );
}

class CommentWithLevel {
  final Comment comment;
  final int level;

  const CommentWithLevel(this.comment, {required this.level});
}
```

### Testing Scenario

1. **View comment** from Marco: "Quando inizia il torneo?"
2. **Tap "Rispondi"** → Reply banner appears: "Risposta a Marco: 'Quando inizia il...'"
3. **Type reply**: "Inizia alle 14:30 in palestra!"
4. **Tap "Pubblica"** → Reply appears indented 48px below Marco's comment
5. **Verify reply count** → Marco's comment shows "1 risposta"
6. **Reply to reply** → New reply becomes sibling (same parent), not nested further
7. **Verify threading limit** → Max 1 level deep enforced

---

## Integration Scenario 4: Report Inappropriate Comment

### User Story
As a student, I see a spam comment promoting an external event and report it. The comment auto-hides after 3 students report it.

### Implementation Steps

#### Step 1: Add Report Action to CommentCard

```dart
// Long-press menu (iOS: CupertinoActionSheet, Android: ModalBottomSheet)
void _showActionMenu(BuildContext context, Comment comment) {
  if (Platform.isIOS) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          if (comment.userId == currentUserId)
            CupertinoActionSheetAction(
              onPressed: () => _onEditComment(comment),
              child: Text('Modifica'),
            ),
          if (comment.userId == currentUserId)
            CupertinoActionSheetAction(
              onPressed: () => _onDeleteComment(comment),
              isDestructiveAction: true,
              child: Text('Elimina'),
            ),
          if (comment.userId != currentUserId)
            CupertinoActionSheetAction(
              onPressed: () => _onReportComment(comment),
              child: Text('Segnala'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Annulla'),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          if (comment.userId == currentUserId)
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Modifica'),
              onTap: () => _onEditComment(comment),
            ),
          if (comment.userId == currentUserId)
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Elimina', style: TextStyle(color: Colors.red)),
              onTap: () => _onDeleteComment(comment),
            ),
          if (comment.userId != currentUserId)
            ListTile(
              leading: Icon(Icons.flag),
              title: Text('Segnala'),
              onTap: () => _onReportComment(comment),
            ),
        ],
      ),
    );
  }
}
```

#### Step 2: Show Report Dialog

```dart
void _onReportComment(Comment comment) {
  Navigator.pop(context); // Close action sheet

  showDialog(
    context: context,
    builder: (context) => ReportDialog(
      comment: comment,
      onSubmit: (reason, details) async {
        try {
          await ref.read(commentsNotifierProvider(eventId).notifier).reportComment(
            commentId: comment.id,
            reason: reason,
            details: details,
          );

          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Segnalazione inviata. Grazie!')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e')),
          );
        }
      },
    ),
  );
}
```

#### Step 3: Report Dialog UI

```dart
class ReportDialog extends StatefulWidget {
  final Comment comment;
  final Function(CommentReportReason reason, String? details) onSubmit;

  const ReportDialog({
    required this.comment,
    required this.onSubmit,
    super.key,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  CommentReportReason? _selectedReason;
  final _detailsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Segnala commento'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Perché vuoi segnalare questo commento?'),
          SizedBox(height: 16),

          // Reason checkboxes
          ...CommentReportReason.values.map((reason) => RadioListTile<CommentReportReason>(
            title: Text(reason.label),
            value: reason,
            groupValue: _selectedReason,
            onChanged: (value) => setState(() => _selectedReason = value),
          )),

          SizedBox(height: 16),

          // Optional details
          TextField(
            controller: _detailsController,
            decoration: InputDecoration(
              labelText: 'Dettagli aggiuntivi (opzionale)',
              hintText: 'Spiega il problema...',
            ),
            maxLength: 500,
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _selectedReason == null
            ? null
            : () => widget.onSubmit(_selectedReason!, _detailsController.text.trim()),
          child: Text('Invia segnalazione'),
        ),
      ],
    );
  }
}
```

### Testing Scenario

1. **Long-press spam comment** → Action sheet appears
2. **Tap "Segnala"** → Report dialog appears
3. **Select reason**: "Spam o pubblicità"
4. **Type details**: "Pubblicizza evento esterno alla scuola"
5. **Tap "Invia segnalazione"** → Success toast: "Segnalazione inviata. Grazie!"
6. **Verify report_count** → Comment now has 1 report
7. **Repeat from 2 other accounts** → After 3rd report, comment auto-hides
8. **Verify auto-hide** → Comment no longer visible to students
9. **Moderator view** → Comment visible in moderation queue

---

## Integration Scenario 5: Real-Time Updates

### User Story
As a student, I have the comments sheet open. When another student posts a comment, I see it appear instantly without refreshing.

### Implementation Steps

#### Step 1: Subscribe to Real-Time Updates

```dart
class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  StreamSubscription? _realtimeSubscription;

  @override
  void initState() {
    super.initState();

    // Load initial comments
    Future.microtask(() {
      ref.read(commentsNotifierProvider(widget.eventId).notifier).loadComments();
    });

    // Subscribe to real-time updates
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    _realtimeSubscription = ref
      .read(commentsRepositoryProvider)
      .subscribeToComments(eventId: widget.eventId)
      .listen(
        (updatedComments) {
          // Update state with new comments
          ref.read(commentsNotifierProvider(widget.eventId).notifier)
            .updateFromRealtime(updatedComments);
        },
        onError: (error) {
          print('Real-time error: $error');
        },
      );
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsNotifierProvider(widget.eventId));

    return commentsAsync.when(
      data: (comments) => _buildCommentsList(comments),
      loading: () => Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Errore: $error')),
    );
  }
}
```

#### Step 2: Handle Real-Time Updates in Notifier

```dart
class CommentsNotifier extends AsyncNotifier<List<Comment>> {
  void updateFromRealtime(List<Comment> updatedComments) {
    // Merge real-time data with local state
    // Preserve optimistic updates (isLikedByCurrentUser flag from local state)
    final currentComments = state.value ?? [];

    final mergedComments = updatedComments.map((serverComment) {
      final localComment = currentComments.firstWhereOrNull((c) => c.id == serverComment.id);

      if (localComment != null) {
        // Prefer server data, but keep local isLikedByCurrentUser flag
        return serverComment.copyWith(
          isLikedByCurrentUser: localComment.isLikedByCurrentUser,
        );
      }

      return serverComment;
    }).toList();

    state = AsyncValue.data(mergedComments);
  }
}
```

### Testing Scenario

1. **User A**: Open comments sheet on device A
2. **User B**: Open comments sheet on device B (same event)
3. **User B**: Post comment "Posso portare un amico?"
4. **Verify User A**: Comment appears instantly on device A (real-time update)
5. **User A**: Like comment
6. **Verify User B**: Like count updates from 0 to 1 on device B (real-time)
7. **Verify latency**: <500ms from post to display (success criteria SC-014)

---

## Testing Checklist

### Unit Tests

- [ ] `CommentModel.fromJson()` correctly deserializes Supabase response
- [ ] `Comment.canEdit` returns true if within 5-min window
- [ ] `Comment.relativeTimestamp` formats "2h fa" correctly
- [ ] `CommentsRepository.postComment` throws `ValidationException` for profanity
- [ ] `CommentsRepository.likeComment` is idempotent (duplicate like ignored)
- [ ] `CommentsNotifier.toggleLike` performs optimistic update + rollback on error

### Widget Tests

- [ ] `CommentCard` displays author name, avatar, text, like count
- [ ] `LikeButton` animates heart scale on tap
- [ ] `CommentInputField` shows character count (X/500)
- [ ] `EmptyCommentsState` displays when no comments
- [ ] `ReplyIndicatorBanner` shows reply context and cancel button

### Integration Tests

- [ ] Full flow: Open sheet → Load comments → Post comment → Comment appears
- [ ] Like flow: Tap heart → Optimistic update → Server sync → Persist after refresh
- [ ] Reply flow: Tap reply → Enter text → Submit → Reply indented 48px
- [ ] Report flow: Long-press → Select reason → Submit → Report count increments
- [ ] Auto-hide flow: 3 reports from different users → Comment hidden
- [ ] Real-time flow: User B posts → User A sees update <500ms
- [ ] Offline flow: Post comment offline → Queue → Reconnect → Sync

### Performance Tests

- [ ] Load 20 comments: <1 second on 4G (SC-013)
- [ ] Scroll through 100 comments: 60fps sustained (SC-015)
- [ ] Like button tap: <200ms perceived response (SC-016)
- [ ] Real-time update: <500ms latency (SC-014)

---

## Debugging Tips

### Enable Supabase Logging

```dart
// In main.dart
Supabase.initialize(
  url: supabaseUrl,
  anonKey: supabaseAnonKey,
  debug: true, // Enable verbose logging
);
```

### Inspect Real-Time Connection

```dart
// In Supabase dashboard: Real-time Inspector
// Watch for:
// - Connection established (WebSocket handshake)
// - Subscription confirmed (event: postgres_changes)
// - Updates received (payload with INSERT/UPDATE/DELETE)
```

### Test RLS Policies

```sql
-- Impersonate user to test RLS
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "00000000-0000-0000-0000-000000000010"}';

-- Try query (should respect RLS)
SELECT * FROM comments WHERE event_id = '00000000-0000-0000-0000-000000000001';
```

---

**Status**: ✅ Quickstart Guide Complete
**Ready for**: `/speckit.tasks` (Generate implementation task list)
