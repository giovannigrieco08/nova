# Real-Time Subscriptions: Global Chat

**Feature**: 011-global-chat
**Version**: 1.0.0

## Overview

The Global Chat feature uses three Supabase Realtime channel types:
1. **Postgres Changes** - For message INSERT/DELETE events
2. **Presence Channel** - For typing indicators
3. **Broadcast Channel** - For reaction updates (low-latency)

---

## Channel Configuration

### 1. Messages Channel (Postgres Changes)

Subscribe to new messages and deletions in real-time.

```dart
final messagesChannel = supabase.channel('global-chat:messages');

messagesChannel
  .onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'chat_messages',
    callback: (payload) {
      // New message received
      final newMessage = ChatMessage.fromJson(payload.newRecord);
      // Add to state
    },
  )
  .onPostgresChanges(
    event: PostgresChangeEvent.delete,
    schema: 'public',
    table: 'chat_messages',
    callback: (payload) {
      // Message deleted (24h cleanup or moderation)
      final deletedId = payload.oldRecord['id'];
      // Remove from state
    },
  )
  .onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'chat_messages',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'hidden_at',
    ),
    callback: (payload) {
      // Message hidden (moderation)
      final hiddenMessage = ChatMessage.fromJson(payload.newRecord);
      // Remove from visible state
    },
  )
  .subscribe();
```

**Payload Schema (INSERT)**:
```json
{
  "type": "INSERT",
  "table": "chat_messages",
  "schema": "public",
  "commit_timestamp": "2025-01-15T10:30:00Z",
  "new": {
    "id": "uuid",
    "user_id": "uuid",
    "content": "Ciao a tutti!",
    "mentions": [],
    "reaction_count": 0,
    "reply_count": 0,
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

---

### 2. Presence Channel (Typing Indicators)

Track which users are currently typing.

```dart
final presenceChannel = supabase.channel('global-chat:presence');

presenceChannel
  .onPresenceSync((payload) {
    // Get current typing users
    final presences = presenceChannel.presenceState();
    final typingUsers = presences.entries
      .where((e) => e.value.any((p) => p['is_typing'] == true))
      .map((e) => TypingUser(
        userId: e.key,
        name: e.value.first['name'] as String,
      ))
      .toList();
    // Update UI
  })
  .onPresenceJoin((payload) {
    // User joined or started typing
  })
  .onPresenceLeave((payload) {
    // User left or stopped typing
  })
  .subscribe((status) async {
    if (status == 'SUBSCRIBED') {
      // Track own presence
      await presenceChannel.track({
        'user_id': currentUserId,
        'name': currentUserName,
        'is_typing': false,
      });
    }
  });
```

**Presence State Schema**:
```json
{
  "user_id_1": [
    {
      "user_id": "uuid",
      "name": "Mario Rossi",
      "is_typing": true,
      "presence_ref": "ref_1"
    }
  ],
  "user_id_2": [
    {
      "user_id": "uuid",
      "name": "Giulia Bianchi",
      "is_typing": false,
      "presence_ref": "ref_2"
    }
  ]
}
```

**Typing State Updates**:
```dart
// Start typing (debounced, call on keystroke)
Future<void> startTyping() async {
  await presenceChannel.track({
    'user_id': currentUserId,
    'name': currentUserName,
    'is_typing': true,
  });

  // Auto-stop after 3 seconds
  _typingTimer?.cancel();
  _typingTimer = Timer(Duration(seconds: 3), stopTyping);
}

// Stop typing (call when send or timeout)
Future<void> stopTyping() async {
  await presenceChannel.track({
    'user_id': currentUserId,
    'name': currentUserName,
    'is_typing': false,
  });
}
```

---

### 3. Reactions Channel (Broadcast)

Low-latency reaction updates via broadcast (faster than Postgres Changes).

```dart
final reactionsChannel = supabase.channel('global-chat:reactions');

reactionsChannel
  .onBroadcast(
    event: 'reaction_added',
    callback: (payload) {
      final messageId = payload['message_id'] as String;
      final emoji = payload['emoji'] as String;
      final userId = payload['user_id'] as String;
      // Update reaction count in UI
    },
  )
  .onBroadcast(
    event: 'reaction_removed',
    callback: (payload) {
      final messageId = payload['message_id'] as String;
      final emoji = payload['emoji'] as String;
      final userId = payload['user_id'] as String;
      // Decrement reaction count in UI
    },
  )
  .subscribe();
```

**Broadcasting Reactions** (after DB insert):
```dart
// After successfully inserting reaction to DB
await reactionsChannel.sendBroadcastMessage(
  event: 'reaction_added',
  payload: {
    'message_id': messageId,
    'emoji': emoji,
    'user_id': currentUserId,
  },
);
```

**Broadcast Payload Schema**:
```json
{
  "event": "reaction_added",
  "payload": {
    "message_id": "uuid",
    "emoji": "❤️",
    "user_id": "uuid"
  }
}
```

---

## Channel Lifecycle Management

### Initialization (on Chat Screen Mount)

```dart
class ChatRealtimeService {
  late RealtimeChannel _messagesChannel;
  late RealtimeChannel _presenceChannel;
  late RealtimeChannel _reactionsChannel;

  Future<void> initialize(SupabaseClient supabase) async {
    // Subscribe to all channels in parallel
    _messagesChannel = supabase.channel('global-chat:messages');
    _presenceChannel = supabase.channel('global-chat:presence');
    _reactionsChannel = supabase.channel('global-chat:reactions');

    // Setup listeners and subscribe
    await Future.wait([
      _setupMessagesChannel(),
      _setupPresenceChannel(),
      _setupReactionsChannel(),
    ]);
  }

  Future<void> dispose() async {
    await Future.wait([
      _messagesChannel.unsubscribe(),
      _presenceChannel.unsubscribe(),
      _reactionsChannel.unsubscribe(),
    ]);
  }
}
```

### Connection State Handling

```dart
// Monitor connection status
supabase.realtime.onConnStateChange.listen((state) {
  switch (state) {
    case ConnState.connected:
      // Show "Connected" indicator
      break;
    case ConnState.disconnected:
      // Show "Reconnecting..." indicator
      // Messages are queued locally
      break;
    case ConnState.connecting:
      // Show "Connecting..." indicator
      break;
  }
});
```

---

## Performance Considerations

### Message Batching

For high-volume scenarios, batch UI updates:

```dart
// Debounce rapid message arrivals
final _messageBuffer = <ChatMessage>[];
Timer? _batchTimer;

void onNewMessage(ChatMessage message) {
  _messageBuffer.add(message);

  _batchTimer?.cancel();
  _batchTimer = Timer(Duration(milliseconds: 100), () {
    // Batch update state with all buffered messages
    state = [..._messageBuffer, ...state];
    _messageBuffer.clear();
  });
}
```

### Presence Throttling

Limit typing indicator updates:

```dart
// Debounce typing events (300ms between updates)
DateTime? _lastTypingUpdate;

Future<void> onUserTyping() async {
  final now = DateTime.now();
  if (_lastTypingUpdate != null &&
      now.difference(_lastTypingUpdate!) < Duration(milliseconds: 300)) {
    return; // Skip update, too soon
  }

  _lastTypingUpdate = now;
  await startTyping();
}
```

---

## Error Handling

### Subscription Errors

```dart
messagesChannel.subscribe((status, error) {
  if (error != null) {
    // Log error, show user message
    _logger.error('Chat subscription failed', error);
    _showConnectionError();
  }
});
```

### Reconnection Strategy

```dart
// Supabase Realtime handles reconnection automatically
// On reconnect, refetch recent messages to fill gaps

supabase.realtime.onConnStateChange.listen((state) {
  if (state == ConnState.connected && _wasDisconnected) {
    // Refetch last 50 messages to catch up
    _refetchRecentMessages();
    _wasDisconnected = false;
  } else if (state == ConnState.disconnected) {
    _wasDisconnected = true;
  }
});
```

---

## Channel Summary

| Channel Name | Type | Purpose | Events |
|-------------|------|---------|--------|
| `global-chat:messages` | Postgres Changes | Message delivery | INSERT, DELETE, UPDATE |
| `global-chat:presence` | Presence | Typing indicators | sync, join, leave |
| `global-chat:reactions` | Broadcast | Reaction updates | reaction_added, reaction_removed |

---

## Latency Requirements

Per Constitution (Principle 4 - Performance First):

| Operation | Target Latency | Measurement |
|-----------|---------------|-------------|
| Message delivery | <1 second | Time from send to appear on other clients |
| Typing indicator | <500ms | Time from keystroke to indicator visible |
| Reaction update | <200ms | Time from tap to count update |

---

**Status**: Contract Complete
**Next**: Flutter Repository Implementation
