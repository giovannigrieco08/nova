# Supabase Realtime Subscriptions: Events Feed

**Feature**: 003-events-feed
**Date**: 2025-01-02
**Purpose**: Document Supabase Realtime (WebSocket) subscription patterns for live updates.

---

## Overview

Supabase Realtime provides WebSocket-based subscriptions for real-time data updates. Events Feed uses Realtime for:

1. **Live comments** - New comments appear instantly without manual refresh (SC-007: <2s latency)
2. **Event updates** - Creator edits broadcast to all viewers (FR-040)
3. **Participant updates** - Live participant count changes
4. **Like count updates** - Real-time like count changes (optional - optimistic UI is primary)

---

## Subscription 1: Watch Comments on Event

**Purpose**: Real-time comment updates for event detail screen.

**Requirements**: FR-032, SC-007

### Enable Realtime on Comments Table

```sql
-- In Supabase Dashboard → Database → Publications
-- OR via SQL:
ALTER PUBLICATION supabase_realtime ADD TABLE comments;
```

### Dart (Flutter) Implementation

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsRepository {
  final SupabaseClient supabase;
  RealtimeChannel? _commentsChannel;

  // Stream of comments for a specific event
  Stream<List<Comment>> watchComments(String eventId) {
    // Create stream subscription
    final stream = supabase
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .order('created_at', ascending: true);

    // Transform to Comment objects
    return stream.map((data) =>
      data.map((json) => Comment.fromJson(json)).toList()
    );
  }

  // Alternative: Manual channel subscription for fine-grained control
  void subscribeToComments(
    String eventId,
    void Function(Comment) onNewComment,
  ) {
    _commentsChannel = supabase.channel('comments:$eventId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'comments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'event_id',
          value: eventId,
        ),
        callback: (payload) {
          final comment = Comment.fromJson(payload.newRecord);
          onNewComment(comment);
        },
      )
      .subscribe();
  }

  void dispose() {
    _commentsChannel?.unsubscribe();
  }
}
```

### Riverpod Provider

```dart
// Stream provider - UI watches this for real-time updates
final commentsStreamProvider = StreamProvider.family<List<Comment>, String>(
  (ref, eventId) {
    final repository = ref.read(commentsRepositoryProvider);
    return repository.watchComments(eventId);
  },
);

// Widget usage
class CommentsList extends ConsumerWidget {
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(commentsStreamProvider(eventId));

    return commentsAsync.when(
      data: (comments) => ListView.builder(
        itemCount: comments.length,
        itemBuilder: (context, index) => CommentListItem(comment: comments[index]),
      ),
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => ErrorWidget(error: err),
    );
  }
}
```

### Performance Notes

- **Latency**: <2 seconds from comment post to all clients (SC-007)
- **Filtering**: RLS policies applied - users only receive comments on approved events
- **Scale**: 500 concurrent users, ~50 events with comments = ~50 active channels
- **Battery impact**: Minimal - WebSocket connection reused across all subscriptions

---

## Subscription 2: Watch Event Updates (Creator Edits)

**Purpose**: Broadcast event edits to all viewers in real-time.

**Requirements**: FR-040

### Enable Realtime on Events Table

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE events;
```

### Dart (Flutter) Implementation

```dart
class EventsRepository {
  final SupabaseClient supabase;
  RealtimeChannel? _eventChannel;

  // Watch single event for updates
  void subscribeToEventUpdates(
    String eventId,
    void Function(Event) onEventUpdated,
  ) {
    _eventChannel = supabase.channel('event:$eventId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'events',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: eventId,
        ),
        callback: (payload) {
          final updatedEvent = Event.fromJson(payload.newRecord);
          onEventUpdated(updatedEvent);
        },
      )
      .subscribe();
  }

  void dispose() {
    _eventChannel?.unsubscribe();
  }
}
```

### Riverpod Provider

```dart
// Event detail provider with real-time updates
class EventDetailNotifier extends AsyncNotifier<Event> {
  RealtimeChannel? _channel;

  @override
  Future<Event> build(String eventId) async {
    // Fetch initial data
    final event = await repository.fetchEvent(eventId);

    // Subscribe to real-time updates
    _subscribeToUpdates(eventId);

    return event;
  }

  void _subscribeToUpdates(String eventId) {
    _channel = supabase.channel('event:$eventId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'events',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: eventId,
        ),
        callback: (payload) {
          final updatedEvent = Event.fromJson(payload.newRecord);
          state = AsyncData(updatedEvent);  // Update provider state
        },
      )
      .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final eventDetailProvider = AsyncNotifierProvider.family<EventDetailNotifier, Event, String>(
  () => EventDetailNotifier(),
);
```

---

## Subscription 3: Watch Participations (Optional)

**Purpose**: Live participant count updates (less critical than comments).

**Requirements**: Implicit in FR-013 (participant list display)

### Enable Realtime on Participations Table

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE participations;
```

### Dart (Flutter) Implementation

```dart
class ParticipationsRepository {
  // Watch participant count for event
  Stream<int> watchParticipantCount(String eventId) {
    return supabase
        .from('participations')
        .stream(primaryKey: ['user_id', 'event_id'])
        .eq('event_id', eventId)
        .map((data) => data.length);  // Count records
  }

  // Watch participant list for event (with user details)
  Stream<List<UserProfile>> watchParticipants(String eventId) {
    return supabase
        .from('participations')
        .stream(primaryKey: ['user_id', 'event_id'])
        .eq('event_id', eventId)
        .asyncMap((data) async {
          // For each participation, fetch user details
          final userIds = data.map((p) => p['user_id'] as String).toList();

          final users = await supabase
              .from('users')
              .select()
              .in_('id', userIds);

          return users.map((u) => UserProfile.fromJson(u)).toList();
        });
  }
}
```

**Note**: This subscription is **optional** - optimistic UI already provides instant feedback for participations. Real-time updates are only needed if multiple users are viewing the same event simultaneously and you want them to see each other's RSVPs instantly.

---

## Subscription 4: Watch Likes (Optional)

**Purpose**: Live like count updates (less critical than comments).

**Requirements**: Implicit in FR-015 (like display)

### Enable Realtime on Likes Table

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE likes;
```

### Dart (Flutter) Implementation

```dart
class LikesRepository {
  // Watch like count for event
  Stream<int> watchLikeCount(String eventId) {
    return supabase
        .from('likes')
        .stream(primaryKey: ['user_id', 'event_id'])
        .eq('event_id', eventId)
        .map((data) => data.length);  // Count records
  }

  // Watch current user's like state
  Stream<bool> watchUserLikeState(String eventId, String userId) {
    return supabase
        .from('likes')
        .stream(primaryKey: ['user_id', 'event_id'])
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .map((data) => data.isNotEmpty);  // True if liked
  }
}
```

**Note**: This subscription is **optional** - optimistic UI already provides instant like feedback. Real-time updates are only needed for seeing other users' likes instantly.

---

## Connection Management

### Automatic Reconnection

Supabase Realtime automatically reconnects on network disruption. Handle reconnection status in UI:

```dart
class RealtimeConnectionService {
  final SupabaseClient supabase;

  void monitorConnection(void Function(String status) onStatusChange) {
    supabase.realtime.onMessage((event) {
      if (event.event == 'system') {
        final status = event.payload['status'] as String;
        onStatusChange(status);  // 'connected', 'disconnected', 'reconnecting'
      }
    });
  }
}

// Show reconnection indicator in UI
class ReconnectionIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(realtimeConnectionStatusProvider);

    if (status == 'reconnecting') {
      return Container(
        padding: EdgeInsets.all(8),
        color: NovaColors.warning,
        child: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(width: 8),
            Text('Reconnecting...'),
          ],
        ),
      );
    }

    return SizedBox.shrink();
  }
}
```

### Manual Reconnection on Resume

```dart
// In main.dart
class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconnect Realtime when app resumes from background
      Supabase.instance.client.realtime.connect();
    } else if (state == AppLifecycleState.paused) {
      // Optionally disconnect to save battery
      Supabase.instance.client.realtime.disconnect();
    }
  }
}
```

---

## Subscription Lifecycle Best Practices

### 1. Subscribe in `initState`, Unsubscribe in `dispose`

```dart
class EventDetailScreen extends StatefulWidget {
  final String eventId;

  @override
  _EventDetailScreenState createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late StreamSubscription<List<Comment>> _commentsSubscription;

  @override
  void initState() {
    super.initState();

    // Subscribe to comments stream
    _commentsSubscription = ref
        .read(commentsRepositoryProvider)
        .watchComments(widget.eventId)
        .listen((comments) {
          setState(() {
            _comments = comments;
          });
        });
  }

  @override
  void dispose() {
    _commentsSubscription.cancel();  // IMPORTANT: Prevent memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

### 2. Use Riverpod `ref.watch` for Automatic Cleanup

```dart
// Preferred approach - Riverpod handles subscription lifecycle
class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Riverpod automatically subscribes/unsubscribes
    final commentsAsync = ref.watch(commentsStreamProvider(eventId));

    return commentsAsync.when(/* ... */);
  }
}
```

### 3. Throttle High-Frequency Updates

For very active events with 100+ comments/min, throttle updates to avoid UI jank:

```dart
import 'package:rxdart/rxdart.dart';

Stream<List<Comment>> watchCommentsThrottled(String eventId) {
  return watchComments(eventId)
      .throttleTime(Duration(seconds: 1));  // Max 1 update per second
}
```

---

## Error Handling

### Handle Subscription Errors

```dart
void subscribeToComments(String eventId) {
  final channel = supabase.channel('comments:$eventId')
    .onPostgresChanges(/* ... */)
    .subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('✅ Subscribed to comments');
      } else if (status == RealtimeSubscribeStatus.channelError) {
        debugPrint('❌ Subscription error: $error');

        // Retry after delay
        Future.delayed(Duration(seconds: 5), () {
          subscribeToComments(eventId);
        });
      }
    });
}
```

### Fallback to Polling on Persistent Failure

```dart
class CommentsRepository {
  Stream<List<Comment>> watchComments(String eventId) {
    try {
      // Try Realtime first
      return supabase
          .from('comments')
          .stream(primaryKey: ['id'])
          .eq('event_id', eventId);
    } catch (e) {
      // Fallback to polling every 10 seconds
      return Stream.periodic(Duration(seconds: 10), (_) async {
        return await fetchComments(eventId);
      }).asyncMap((future) => future);
    }
  }
}
```

---

## Performance Optimization

### Limit Subscriptions per Screen

- **DO**: Subscribe only to the current event's comments (detail screen)
- **DON'T**: Subscribe to all events in the feed (wasteful, battery drain)

### Use RLS-Filtered Subscriptions

Supabase Realtime respects RLS policies - users only receive data they're authorized to see. This prevents unnecessary data transfer.

### Batch Updates

If receiving high-frequency updates (e.g., live like count), batch them:

```dart
Stream<int> watchLikeCountBatched(String eventId) {
  return watchLikeCount(eventId)
      .bufferTime(Duration(seconds: 2))  // Batch updates every 2 seconds
      .map((batches) => batches.last);   // Only use latest value
}
```

---

## Testing Real-Time Updates

### Manual Test (Two Devices)

1. **Device A**: Open event detail screen, view comments
2. **Device B**: Post a comment on the same event
3. **Expected**: Device A sees the new comment within 2 seconds (SC-007)

### Automated Test (Supabase Dashboard)

1. Open Supabase Dashboard → Database → Table Editor → comments
2. Manually insert a comment row
3. **Expected**: App shows the new comment instantly without refresh

### Load Test (100 Concurrent Users)

```dart
// Simulate 100 users watching the same event
for (int i = 0; i < 100; i++) {
  final subscription = supabase
      .from('comments')
      .stream(primaryKey: ['id'])
      .eq('event_id', eventId)
      .listen((data) {
        print('User $i received ${data.length} comments');
      });
}

// Expected: All 100 users receive updates within 2 seconds
```

---

## Summary

| Subscription | Priority | Latency Target | Battery Impact |
|--------------|----------|----------------|----------------|
| **Comments** | P1 (Critical) | <2s (SC-007) | Low (1 channel per event) |
| **Event Updates** | P2 (Nice-to-have) | <5s | Very Low (rare updates) |
| **Participations** | P3 (Optional) | N/A | Low (optimistic UI is primary) |
| **Likes** | P3 (Optional) | N/A | Low (optimistic UI is primary) |

**Recommended**: Enable comments (P1) and event updates (P2). Skip participations and likes subscriptions - optimistic UI provides instant feedback without WebSocket overhead.

---

**Realtime Subscriptions Status**: ✅ Complete - All patterns documented with implementation examples
