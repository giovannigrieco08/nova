# Quickstart Guide: Global Chat

**Feature**: 011-global-chat
**Version**: 1.0.0

This guide provides step-by-step integration scenarios for testing and validating the Global Chat feature.

---

## Prerequisites

Before testing, ensure:

1. **User Account**: Authenticated with `@galileimoro.edu.it` email
2. **Complete Profile**: Has `full_name` and `class` set
3. **Database Migrations**: `011_global_chat_system.sql` applied
4. **Storage Bucket**: `ephemeral-media` bucket created
5. **pg_cron Extension**: Enabled and jobs scheduled

---

## Scenario 1: Send and Receive Messages (P1)

### Test: Basic Message Flow

**Objective**: Verify real-time message delivery between users.

**Steps**:

1. Open the app as User A (Mario)
2. Navigate to Chat tab
3. Type "Ciao a tutti!" in the compose area
4. Tap Send button
5. Open the app as User B (Giulia) on another device
6. Verify message appears within 1 second

**Expected Results**:
- [x] Message appears immediately for User A (optimistic UI)
- [x] Message appears within 1 second for User B
- [x] Message shows Mario's avatar, name, class (3A), timestamp
- [x] Character counter shows 12/500

**Code Path**:
```
ChatScreen → ChatMessageList → ChatMessageTile
           → ChatComposeBar → sendMessage()
           → ChatRepository.sendMessage()
           → Supabase INSERT + Realtime broadcast
```

---

### Test: Rate Limiting

**Objective**: Verify 10 messages/minute limit.

**Steps**:

1. Send 10 messages rapidly (within 1 minute)
2. Attempt to send 11th message
3. Wait 60 seconds
4. Send another message

**Expected Results**:
- [x] First 10 messages succeed
- [x] 11th message fails with "Troppi messaggi. Attendi qualche secondo."
- [x] After 60 seconds, messages can be sent again

**Error Code**: `P0001` from rate limit trigger

---

## Scenario 2: Report Messages (P1)

### Test: Report Flow

**Objective**: Verify report submission and auto-hide.

**Steps**:

1. User A sends a message
2. User B long-presses the message
3. User B selects "Segnala" from context menu
4. User B selects "Contenuto inappropriato"
5. User B taps "Invia"
6. Repeat with Users C and D

**Expected Results**:
- [x] Report dialog shows 4 options (Spam, Contenuto inappropriato, Bullismo, Off-topic)
- [x] Confirmation "Segnalazione inviata" appears
- [x] User B cannot report same message again
- [x] After 3 reports, message is hidden from all users
- [x] Message appears in moderation queue

**Verification Query**:
```sql
SELECT id, content, report_count, hidden_at, hidden_reason
FROM chat_messages
WHERE id = '[message_id]';
-- Expected: report_count = 3, hidden_at NOT NULL, hidden_reason = 'auto_hide_reports'
```

---

## Scenario 3: 24-Hour Auto-Delete (P1)

### Test: Message Expiration

**Objective**: Verify automatic message deletion.

**Steps**:

1. Send a message
2. Note the message ID
3. Wait 24 hours (or manually trigger pg_cron job)
4. Check if message exists

**Expected Results**:
- [x] Message deleted from `chat_messages` table
- [x] Associated reactions deleted (CASCADE)
- [x] Associated reports deleted (CASCADE)
- [x] Message no longer visible in chat

**Manual Trigger** (for testing):
```sql
-- Force run the deletion job
DELETE FROM chat_messages
WHERE created_at < NOW() - INTERVAL '24 hours';
```

---

## Scenario 4: @Mentions (P2)

### Test: Mention Autocomplete and Notification

**Objective**: Verify mention parsing and notifications.

**Steps**:

1. Type "@" in compose area
2. Continue typing "mar"
3. Select "Mario Rossi" from autocomplete
4. Send the message
5. Check Mario's notifications

**Expected Results**:
- [x] Autocomplete appears after typing "@"
- [x] Results filter as user types
- [x] Selected name appears highlighted in compose
- [x] Sent message shows @Mario highlighted in purple
- [x] Mario receives notification "Ti hanno menzionato in chat"

**Code Path**:
```
ChatComposeBar.onTextChanged()
  → MentionAutocomplete.search()
  → ChatRepository.searchUsers()
  → Display dropdown

sendMessage()
  → parseMentions()
  → INSERT with mentions JSONB
  → notify_chat_mentions() trigger
  → Notification created
```

---

## Scenario 5: Reply to Messages (P2)

### Test: Reply Flow

**Objective**: Verify reply threading.

**Steps**:

1. Swipe right on a message
2. Verify compose area shows quoted preview
3. Type reply message
4. Send
5. Verify reply appears with quoted content

**Expected Results**:
- [x] Swipe gesture activates reply mode
- [x] Preview shows original message snippet
- [x] X button cancels reply mode
- [x] Sent reply shows quoted context above content
- [x] Tapping quote scrolls to original message
- [x] If original deleted, quote shows "[Messaggio eliminato]"

**Code Path**:
```
ChatMessageTile.onSwipeRight()
  → ChatState.setReplyTo(message)
  → ChatComposeBar shows preview

sendMessage()
  → INSERT with reply_to_id
  → UI shows ChatReplyPreview widget
```

---

## Scenario 6: Emoji Reactions (P2)

### Test: Add and Remove Reactions

**Objective**: Verify reaction functionality.

**Steps**:

1. Long-press on a message
2. Select heart emoji from picker
3. Verify reaction appears below message
4. Tap heart again to remove
5. Have multiple users react

**Expected Results**:
- [x] Reaction picker shows 6 options (❤️👍😂😮😢🔥)
- [x] Selected reaction appears with count "❤️ 1"
- [x] Tapping same emoji removes reaction
- [x] Multiple users' reactions aggregate ("❤️ 3")
- [x] Reactions update in real-time for all users

**Reaction Counts Query**:
```sql
SELECT emoji, COUNT(*) as count
FROM chat_reactions
WHERE message_id = '[message_id]'
GROUP BY emoji;
```

---

## Scenario 7: Typing Indicators (P3)

### Test: Typing State

**Objective**: Verify typing indicator display.

**Steps**:

1. User A opens chat
2. User B starts typing
3. Verify User A sees "Mario sta scrivendo..."
4. User B stops typing (wait 3 seconds)
5. Verify indicator disappears

**Expected Results**:
- [x] Indicator appears within 500ms of typing
- [x] Shows single name: "Mario sta scrivendo..."
- [x] Shows two names: "Mario e Giulia stanno scrivendo..."
- [x] Shows 3+: "Mario, Giulia e altri 2 stanno scrivendo..."
- [x] Indicator disappears 3 seconds after last keystroke
- [x] User doesn't see own name

**Code Path**:
```
ChatComposeBar.onTextChanged()
  → TypingIndicatorService.startTyping()
  → presenceChannel.track({is_typing: true})
  → 3s Timer → stopTyping()

TypingIndicatorWidget
  → listens to presenceChannel.onPresenceSync()
  → filters typing users
  → displays formatted string
```

---

## Scenario 8: View-Once Media (P3)

### Test: Send and View Ephemeral Image

**Objective**: Verify view-once media lifecycle.

**Steps**:

1. Tap camera icon in compose
2. Select image from gallery
3. Enable "Visualizzazione singola" toggle
4. Send
5. User B taps on view-once message
6. Media displays full-screen
7. Close viewer
8. Verify media cannot be reopened

**Expected Results**:
- [x] Image compressed to <10MB
- [x] Message shows view-once indicator icon
- [x] Opening activates screenshot protection (Android: FLAG_SECURE)
- [x] After closing, message shows "Visualizzato"
- [x] Tapping again shows "Media gia visualizzato"
- [x] Storage file deleted after viewing

**Screenshot Test (Android)**:
1. Open view-once media
2. Attempt to take screenshot
3. Screenshot should show black screen

**Screenshot Test (iOS)**:
1. Open view-once media
2. Take screenshot
3. Sender receives notification "Giulia ha fatto uno screenshot"

---

## Scenario 9: Offline Queue

### Test: Message Queuing Without Network

**Objective**: Verify offline message handling.

**Steps**:

1. Enable airplane mode
2. Send a message
3. Verify "pending" indicator
4. Disable airplane mode
5. Verify message sent

**Expected Results**:
- [x] Message appears locally with pending icon
- [x] Toast shows "Sei offline. Il messaggio verra inviato al reconnect."
- [x] On reconnect, message sent automatically
- [x] Pending icon replaced with timestamp

**Error State**:
- After 3 retries (1s, 2s, 4s), show "Invio fallito. Riprova."
- User can tap to retry manually

---

## Integration Test Suite

### Flutter Test File: `chat_integration_test.dart`

```dart
void main() {
  group('Global Chat Integration', () {
    testWidgets('sends message and appears in feed', (tester) async {
      // Setup mock Supabase
      await tester.pumpWidget(ProviderScope(
        overrides: [supabaseClientProvider.overrideWith(mockClient)],
        child: MaterialApp(home: ChatScreen()),
      ));

      // Type message
      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Verify optimistic update
      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('shows rate limit error after 10 messages', (tester) async {
      // Send 10 messages
      for (int i = 0; i < 10; i++) {
        await sendTestMessage(tester, 'Message $i');
      }

      // 11th should fail
      await sendTestMessage(tester, 'Message 11');
      expect(find.text('Troppi messaggi'), findsOneWidget);
    });

    testWidgets('reports message and shows confirmation', (tester) async {
      await tester.pumpWidget(chatScreenWithMessages());

      // Long press message
      await tester.longPress(find.byType(ChatMessageTile).first);
      await tester.pumpAndSettle();

      // Tap report
      await tester.tap(find.text('Segnala'));
      await tester.pumpAndSettle();

      // Select reason
      await tester.tap(find.text('Contenuto inappropriato'));
      await tester.tap(find.text('Invia'));

      expect(find.text('Segnalazione inviata'), findsOneWidget);
    });
  });
}
```

---

## Verification Checklist

### P1 - Core Messaging
- [ ] Messages display with avatar, name, class, timestamp
- [ ] Real-time delivery <1 second
- [ ] Rate limiting works (10/min)
- [ ] Profanity filter blocks inappropriate words
- [ ] Report button accessible via long-press
- [ ] Auto-hide at 3 reports
- [ ] 24h auto-delete working

### P2 - Engagement Features
- [ ] @mention autocomplete appears
- [ ] Mentions highlighted in purple
- [ ] Mention notifications delivered
- [ ] Reply swipe gesture works
- [ ] Quoted preview displays correctly
- [ ] Reactions add/remove properly
- [ ] Reaction counts update real-time

### P3 - Advanced Features
- [ ] Typing indicator shows/hides correctly
- [ ] Multiple typers display properly
- [ ] View-once media uploads successfully
- [ ] Screenshot protection active (Android)
- [ ] Screenshot detection works (iOS)
- [ ] Media cannot be re-viewed
- [ ] Daily limit enforced (5/day)

---

## Common Issues and Solutions

### Issue: Messages not appearing in real-time
**Solution**: Check WebSocket connection. Ensure `supabase.realtime` is connected.

### Issue: Rate limit too aggressive
**Solution**: Check `check_chat_rate_limit()` trigger. Ensure sliding window is correct.

### Issue: Mentions not highlighted
**Solution**: Verify `parseMentions()` correctly populates `mentions` JSONB array.

### Issue: View-once media still accessible
**Solution**: Check `markMediaViewed()` UPDATE policy and storage RLS.

---

**Status**: Quickstart Complete
**Next**: Implementation (tasks.md)
