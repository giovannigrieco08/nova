# Technical Research: Events Feed

**Feature**: 003-events-feed
**Date**: 2025-01-02
**Purpose**: Document technical decisions, patterns, and best practices for implementing Instagram-style infinite scroll events feed with offline-first architecture.

---

## 1. Offline-First Architecture with Hive + Supabase Sync

### Decision

Use **two-layer caching strategy**:
1. **Primary cache**: Hive NoSQL stores last 100 viewed events as typed `EventModel` objects
2. **Offline queue**: Hive stores pending actions (likes, comments, participations) with exponential backoff retry

### Rationale

- **Instant startup**: App loads from Hive cache in <1s (FR-058), showing events immediately
- **Offline access**: Students can browse cached events without network (FR-009)
- **Background sync**: Fresh data fetched silently after cache renders (FR-008)
- **Optimistic UI**: Actions queued offline and synced when connection restored (FR-010)

### Implementation Pattern

```dart
// EventsRepository - Cache-first pattern
class EventsRepository {
  final EventsLocalDataSource localDataSource;  // Hive
  final EventsRemoteDataSource remoteDataSource; // Supabase

  Future<List<Event>> getEventsFeed({int page = 1, int limit = 20}) async {
    // 1. Load from cache FIRST (instant UI render)
    final cachedEvents = await localDataSource.getCachedEvents(page, limit);

    // 2. Return cached data immediately
    if (cachedEvents.isNotEmpty) {
      // Trigger background refresh (don't await)
      _refreshCacheInBackground(page, limit);
      return cachedEvents;
    }

    // 3. If no cache, fetch from network (first load)
    final freshEvents = await remoteDataSource.fetchEvents(page, limit);

    // 4. Cache for next time
    await localDataSource.cacheEvents(freshEvents);

    return freshEvents;
  }

  Future<void> _refreshCacheInBackground(int page, int limit) async {
    try {
      final freshEvents = await remoteDataSource.fetchEvents(page, limit);
      await localDataSource.cacheEvents(freshEvents);
    } catch (e) {
      // Silent failure - user already has cached data
      debugPrint('Background refresh failed: $e');
    }
  }
}
```

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| **Sqflite** (SQL database) | Hive is faster for key-value storage, no schema migrations, better for offline-first Flutter apps |
| **SharedPreferences** | Limited to small key-value pairs, not suitable for storing 100 event objects |
| **In-memory cache only** | Lost on app restart, violates offline-first requirement (FR-007) |

### References

- [Hive Documentation - Flutter Offline Storage](https://docs.hivedb.dev/)
- [Flutter Offline-First Best Practices](https://flutter.dev/docs/cookbook/persistence)
- Supabase client already handles HTTP retry logic for network failures

---

## 2. Optimistic UI Implementation with Rollback

### Decision

Implement **optimistic UI pattern** for all user interactions (like, comment, participate) with automatic rollback on server failure.

### Rationale

- **Instant feedback**: <200ms perceived response time (FR-064) - feels native
- **Offline resilience**: Actions queued and synced when back online (FR-010)
- **Better UX**: No loading spinners for every tap - reduces friction
- **Server truth wins**: Rollback on conflict ensures data consistency

### Implementation Pattern

```dart
// Example: Optimistic Like Implementation
class InteractionsRepository {
  Future<void> likeEvent(String eventId, String userId) async {
    // 1. IMMEDIATELY update local state (optimistic)
    await localDataSource.setLikeState(eventId, userId, liked: true);

    try {
      // 2. Send to server in background
      await remoteDataSource.likeEvent(eventId);

      // 3. Success - local state matches server
    } catch (e) {
      // 4. ROLLBACK on failure - revert to previous state
      await localDataSource.setLikeState(eventId, userId, liked: false);

      // 5. Show error to user
      throw Exception('Failed to like event. Try again.');
    }
  }
}

// Riverpod Provider - UI watches this
final eventLikeStateProvider = FutureProvider.family<bool, String>((ref, eventId) async {
  final repository = ref.read(interactionsRepositoryProvider);
  return repository.isEventLiked(eventId);
});
```

### Offline Queue Pattern

```dart
// Offline action queue (stored in Hive)
class OfflineAction {
  final String id;
  final String type;  // 'like', 'unlike', 'comment', 'participate'
  final Map<String, dynamic> payload;
  final DateTime queuedAt;
  final int retryCount;
}

class OfflineQueueRepository {
  Future<void> queueAction(OfflineAction action) async {
    await hiveBox.put(action.id, action);
  }

  Future<void> syncQueue() async {
    final pendingActions = hiveBox.values.toList();

    for (final action in pendingActions) {
      try {
        await _executeAction(action);
        await hiveBox.delete(action.id);  // Success - remove from queue
      } catch (e) {
        // Retry logic handled by exponential backoff (see section 8)
      }
    }
  }
}
```

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| **Server-first (always show loading)** | Poor UX, violates <200ms perceived response time requirement (FR-064) |
| **Pessimistic locking** | Overkill for likes/comments, increases complexity, worse offline support |
| **CRDT (Conflict-free Replicated Data Types)** | Too complex for simple like/comment actions, better for collaborative editing |

### References

- [Flutter Optimistic UI Pattern](https://verygood.ventures/blog/optimistic-ui-pattern-flutter)
- [Riverpod AsyncNotifier for State Management](https://riverpod.dev/docs/providers/notifier_provider)

---

## 3. Supabase Realtime Subscriptions for Live Comments

### Decision

Use **Supabase Realtime (WebSocket subscriptions)** to push new comments to all users viewing an event detail screen in real-time.

### Rationale

- **Instant updates**: New comments appear within 2 seconds (SC-007) without manual refresh
- **Zero polling overhead**: WebSocket connection is persistent, more efficient than polling
- **Built-in filtering**: Supabase Realtime supports RLS policies, only sends authorized data
- **Scale**: Handles 500 students with minimal server load

### Implementation Pattern

```dart
// CommentsRepository - Realtime subscription
class CommentsRepository {
  StreamSubscription? _commentsSubscription;

  Stream<List<Comment>> watchComments(String eventId) {
    // Create Supabase Realtime subscription
    final stream = supabase
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .order('created_at', ascending: true);

    return stream.map((data) =>
      data.map((json) => Comment.fromJson(json)).toList()
    );
  }

  void dispose() {
    _commentsSubscription?.cancel();
  }
}

// Riverpod Provider - UI watches this stream
final commentsStreamProvider = StreamProvider.family<List<Comment>, String>((ref, eventId) {
  final repository = ref.read(commentsRepositoryProvider);
  return repository.watchComments(eventId);
});
```

### Supabase Realtime Configuration

```sql
-- Enable Realtime on comments table
ALTER PUBLICATION supabase_realtime ADD TABLE comments;

-- RLS policy ensures users only receive authorized comments
CREATE POLICY "Users can view approved event comments"
  ON comments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = comments.event_id
        AND events.status = 'approved'
    )
  );
```

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| **HTTP polling (every 5s)** | Wasteful network requests, battery drain, not truly real-time |
| **Firebase Firestore** | Already committed to Supabase (constitution mandates stack consistency) |
| **Custom WebSocket server** | Supabase Realtime is battle-tested, zero DevOps overhead |

### References

- [Supabase Realtime Documentation](https://supabase.com/docs/guides/realtime)
- [Supabase Flutter Client - Realtime Streams](https://supabase.com/docs/reference/dart/stream)

---

## 4. Infinite Scroll Pagination with ListView.builder

### Decision

Use **`ListView.builder`** with `ScrollController` for infinite scroll pagination (20 events per page) with automatic next page load when user scrolls near bottom.

### Rationale

- **Lazy loading**: Only builds visible widgets, handles thousands of events efficiently
- **Memory efficient**: Old widgets destroyed when scrolled out of view
- **Native feel**: Smooth 60fps scrolling (FR-060)
- **Debounced loading**: Prevents duplicate page requests (FR-063)

### Implementation Pattern

```dart
class EventsFeedScreen extends ConsumerStatefulWidget {
  @override
  _EventsFeedScreenState createState() => _EventsFeedScreenState();
}

class _EventsFeedScreenState extends ConsumerState<EventsFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Trigger pagination when within 3 items of bottom (FR-001)
    final threshold = _scrollController.position.maxScrollExtent - (3 * 200); // 200 = item height estimate

    if (_scrollController.position.pixels >= threshold && !_isLoadingMore) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore) return;  // Debounce (FR-063)

    setState(() => _isLoadingMore = true);

    try {
      await ref.read(eventsFeedProvider.notifier).loadPage(_currentPage + 1);
      _currentPage++;
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsFeedProvider);

    return eventsAsync.when(
      data: (events) => ListView.builder(
        controller: _scrollController,
        itemCount: events.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == events.length) {
            // Loading indicator at bottom
            return Center(child: CircularProgressIndicator());
          }

          return EventCard(event: events[index]);
        },
      ),
      loading: () => Center(child: CircularProgressIndicator()),
      error: (err, stack) => ErrorWidget(error: err),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
```

### Debouncing Logic

```dart
// Prevent multiple page loads within 500ms (FR-063)
class EventsFeedNotifier extends AsyncNotifier<List<Event>> {
  DateTime? _lastPageLoad;

  Future<void> loadPage(int page) async {
    final now = DateTime.now();

    // Debounce: max 1 page load every 500ms
    if (_lastPageLoad != null && now.difference(_lastPageLoad!) < Duration(milliseconds: 500)) {
      return;
    }

    _lastPageLoad = now;

    // Fetch page...
  }
}
```

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| **`ListView` (non-builder)** | Loads all items upfront, terrible memory performance for large lists |
| **`infinite_scroll_pagination` package** | Adds dependency, `ListView.builder` is sufficient and native |
| **Load all events at once** | Violates performance requirements, wastes bandwidth/battery |

### References

- [Flutter ListView.builder Documentation](https://api.flutter.dev/flutter/widgets/ListView/ListView.builder.html)
- [Infinite Scroll Best Practices](https://flutter.dev/docs/cookbook/lists/long-lists)

---

## 5. Image Optimization (WebP Format + Progressive Loading)

### Decision

Use **`cached_network_image`** package with WebP format (max 200KB per image) and progressive blur-up effect.

### Rationale

- **Bandwidth savings**: WebP is 25-35% smaller than JPEG at same quality (FR-061)
- **Progressive loading**: Show blurry placeholder instantly while high-quality loads (FR-062, SC-003)
- **Caching**: Images cached on device, faster subsequent loads
- **Network-aware**: Automatically retries on failure

### Implementation Pattern

```dart
import 'package:cached_network_image/cached_network_image.dart';

class EventImage extends StatelessWidget {
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,

      // Progressive loading: Show blur-up effect
      placeholder: (context, url) => Container(
        color: NovaColors.backgroundSecondary,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: NovaColors.accent,
          ),
        ),
      ),

      // Error fallback: Show Nova logo placeholder
      errorWidget: (context, url, error) => Container(
        color: NovaColors.backgroundSecondary,
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 48,
            color: NovaColors.textSecondary,
          ),
        ),
      ),

      // Fade-in animation (300ms)
      fadeInDuration: NovaDurations.medium,

      // Aspect ratio 16:9 (design requirement)
      fit: BoxFit.cover,
    );
  }
}
```

### WebP Conversion (Backend)

```dart
// Supabase Edge Function - Convert uploaded images to WebP
import { ImageMagick } from 'imagemagick';

Deno.serve(async (req) => {
  const file = await req.formData();
  const image = file.get('image');

  // Convert to WebP with 85% quality (balance size vs quality)
  const webp = await ImageMagick.convert(image, {
    format: 'webp',
    quality: 85,
    maxSize: 200 * 1024, // 200KB max
  });

  return new Response(webp, {
    headers: { 'Content-Type': 'image/webp' },
  });
});
```

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| **JPEG format** | 25-35% larger files, worse performance on slow networks |
| **AVIF format** | Not yet widely supported on older Android devices (Android 8+) |
| **No progressive loading** | Blank white boxes during load, poor UX (violates SC-003) |
| **No caching** | Wasteful bandwidth, slow subsequent loads |

### References

- [`cached_network_image` Package](https://pub.dev/packages/cached_network_image)
- [WebP vs JPEG Comparison](https://developers.google.com/speed/webp/docs/webp_study)
- [Supabase Storage Best Practices](https://supabase.com/docs/guides/storage/uploads/image-transformations)

---

## 6. Pull-to-Refresh Gesture with RefreshIndicator

### Decision

Use **`RefreshIndicator`** widget (native Flutter) on both feed screen and detail screen for manual content refresh.

### Rationale

- **Native UX**: Standard Android/iOS pull-to-refresh pattern (FR-006a, FR-014a)
- **Explicit control**: Complements automatic background refresh, gives users control
- **Simple API**: Wraps scrollable widgets, minimal code
- **Platform-aware**: Uses iOS/Android native indicators automatically

### Implementation Pattern

```dart
// Feed Screen - Pull-to-Refresh
class EventsFeedScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsFeedProvider);

    return RefreshIndicator(
      // Trigger manual refresh
      onRefresh: () async {
        await ref.read(eventsFeedProvider.notifier).refreshFeed();
      },

      // Native loading indicator color
      color: NovaColors.accent,
      backgroundColor: NovaColors.backgroundPrimary,

      // Child must be scrollable
      child: eventsAsync.when(
        data: (events) => ListView.builder(/* ... */),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, stack) => ErrorWidget(error: err),
      ),
    );
  }
}

// Detail Screen - Pull-to-Refresh
class EventDetailScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      // Refresh event data, comments, participant list (FR-014b)
      onRefresh: () async {
        await Future.wait([
          ref.read(eventDetailProvider(eventId).notifier).refresh(),
          ref.read(commentsProvider(eventId).notifier).refresh(),
        ]);
      },

      child: SingleChildScrollView(/* ... */),
    );
  }
}
```

### Provider Refresh Logic

```dart
class EventsFeedNotifier extends AsyncNotifier<List<Event>> {
  Future<void> refreshFeed() async {
    // Set loading state
    state = const AsyncLoading();

    try {
      // Fetch first page (20 events), reset scroll position (FR-006c)
      final freshEvents = await repository.getEventsFeed(page: 1, limit: 20);

      // Update cache
      await localDataSource.clearCache();
      await localDataSource.cacheEvents(freshEvents);

      // Update state
      state = AsyncData(freshEvents);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }
}
```

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| **Custom gesture detector** | Reinventing the wheel, `RefreshIndicator` is battle-tested |
| **Manual refresh button** | Less intuitive, pull-to-refresh is standard mobile UX pattern |
| **Auto-refresh only** | Users want explicit control, especially when debugging or viewing specific data |

### References

- [Flutter RefreshIndicator Documentation](https://api.flutter.dev/flutter/material/RefreshIndicator-class.html)
- [Material Design - Pull-to-Refresh](https://m3.material.io/components/lists/guidelines#refresh)

---

## 7. Character Limit Validation (Client + Server)

### Decision

Implement **dual-layer validation**: Client-side live character counter + server-side VARCHAR(500) constraint.

### Rationale

- **Instant feedback**: Client-side counter shows "X/500" in real-time (FR-029b)
- **Security**: Server-side constraint prevents malicious bypass (defense in depth)
- **Data integrity**: Database enforces max length even if client bug exists
- **UX**: Disabled send button when empty or >500 chars (FR-029c)

### Implementation Pattern

**Client-Side (Flutter)**:

```dart
class CommentInputField extends ConsumerStatefulWidget {
  @override
  _CommentInputFieldState createState() => _CommentInputFieldState();
}

class _CommentInputFieldState extends ConsumerState<CommentInputField> {
  final TextEditingController _controller = TextEditingController();
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateCharCount);
  }

  void _updateCharCount() {
    setState(() {
      _charCount = _controller.text.length;
    });
  }

  bool get _canSend => _charCount > 0 && _charCount <= 500;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          maxLength: 500,  // Hard limit - prevents typing beyond 500
          decoration: InputDecoration(
            hintText: 'Write a comment...',
            counterText: '$_charCount/500',  // Live counter (FR-029b)
            counterStyle: TextStyle(
              color: _charCount > 500
                ? NovaColors.error
                : NovaColors.textSecondary,
            ),
          ),
        ),

        ElevatedButton(
          onPressed: _canSend ? _postComment : null,  // Disabled when invalid (FR-029c)
          child: Text('Send'),
        ),
      ],
    );
  }

  Future<void> _postComment() async {
    final text = _controller.text.trim();

    // Final validation before sending
    if (text.isEmpty || text.length > 500) return;

    await ref.read(commentsProvider.notifier).postComment(text);
    _controller.clear();
  }
}
```

**Server-Side (Supabase)**:

```sql
-- Database constraint (FR-029a)
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  text VARCHAR(500) NOT NULL,  -- Max 500 characters enforced
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT comment_text_not_empty CHECK (length(trim(text)) > 0)
);

-- Index for performance
CREATE INDEX idx_comments_event_id ON comments(event_id);
```

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| **Client-side only** | Insecure - malicious users can bypass, no data integrity guarantee |
| **Server-side only** | Poor UX - user types 600 chars, hits send, sees error message |
| **No character limit** | Violates requirement (FR-029a), risks UI layout issues with 10,000 char comments |
| **TEXT column (unlimited)** | Wastes storage, allows abuse, inconsistent with spec (500 char requirement) |

### References

- [Flutter TextField maxLength](https://api.flutter.dev/flutter/material/TextField/maxLength.html)
- [PostgreSQL VARCHAR Constraints](https://www.postgresql.org/docs/current/datatype-character.html)

---

## 8. Exponential Backoff Retry Logic for Offline Sync

### Decision

Implement **exponential backoff with 3 retry attempts** (1s, 2s, 4s delays) for queued offline actions, then show persistent notification with manual retry button.

### Rationale

- **Automatic recovery**: Transient network errors (weak signal, brief disconnect) auto-resolve (FR-010a)
- **Backpressure**: Exponential delays prevent hammering the server during outages
- **User control**: After 3 failures, user sees notification with "Retry" button (FR-010b)
- **Persistence**: Actions stored in Hive, survive app restarts (FR-010c)

### Implementation Pattern

```dart
class OfflineQueueRepository {
  Future<void> syncAction(OfflineAction action) async {
    const maxRetries = 3;
    const delays = [1, 2, 4];  // Exponential backoff: 1s, 2s, 4s

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // Execute action (like, comment, participate)
        await _executeAction(action);

        // Success - remove from queue
        await hiveBox.delete(action.id);
        return;

      } catch (e) {
        // Failure - wait before retry
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: delays[attempt]));
        } else {
          // All retries exhausted - show notification (FR-010b)
          await _showSyncFailedNotification(action);
        }
      }
    }
  }

  Future<void> _executeAction(OfflineAction action) async {
    switch (action.type) {
      case 'like':
        await supabase.from('likes').insert(action.payload);
        break;
      case 'comment':
        await supabase.from('comments').insert(action.payload);
        break;
      case 'participate':
        await supabase.from('participations').insert(action.payload);
        break;
    }
  }

  Future<void> _showSyncFailedNotification(OfflineAction action) async {
    // Persistent notification with "Retry" button
    await FlutterLocalNotificationsPlugin().show(
      0,
      'Sync Failed',
      'Some actions couldn\'t be synced. Tap to retry.',
      NotificationDetails(/* ... */),
      payload: 'retry_sync',
    );
  }
}
```

### Background Sync Trigger

```dart
// Trigger sync when app regains connectivity
class ConnectivityService {
  StreamSubscription? _subscription;

  void listen(OfflineQueueRepository repository) {
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        // Back online - trigger sync
        repository.syncQueue();
      }
    });
  }
}
```

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| **No retries (fail immediately)** | Poor UX - transient errors like weak signal would fail permanently |
| **Linear backoff (1s, 1s, 1s)** | Hammers server during outages, doesn't give network time to recover |
| **Infinite retries** | Battery drain, no user feedback, feels broken |
| **Custom retry logic per action** | Overcomplicated, exponential backoff is industry standard |

### References

- [Exponential Backoff Best Practices](https://cloud.google.com/iot/docs/how-tos/exponential-backoff)
- [Flutter Connectivity Package](https://pub.dev/packages/connectivity_plus)

---

## 9. Date-Based Event Archival Filtering

### Decision

Use **server-side SQL filter** `WHERE event_date >= CURRENT_DATE` with database index on `event_date` column.

### Rationale

- **Performance**: Database index makes date filtering fast even with 10,000+ events (FR-003b)
- **Accuracy**: `CURRENT_DATE` uses server timezone (UTC), consistent for all users
- **Future-proof**: Past events accessible via separate "Past Events" screen (future feature)
- **Clean separation**: Main feed shows only upcoming events, keeps UX focused

### Implementation Pattern

**Database Schema**:

```sql
-- Events table with date-based archival
CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title VARCHAR(200) NOT NULL,
  description TEXT NOT NULL,
  event_date DATE NOT NULL,           -- Date of the event (e.g., 2025-01-15)
  event_time TIME NOT NULL,           -- Time of the event (e.g., 15:00:00)
  location VARCHAR(200) NOT NULL,
  creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',  -- 'pending', 'approved', 'rejected'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT status_values CHECK (status IN ('pending', 'approved', 'rejected'))
);

-- Index for date-based filtering (FR-003b)
CREATE INDEX idx_events_date_status ON events(event_date, status);

-- Index for feed ordering
CREATE INDEX idx_events_created_at ON events(created_at DESC);
```

**Supabase Query**:

```dart
// EventsRemoteDataSource - Fetch upcoming events only
class EventsRemoteDataSource {
  Future<List<EventModel>> fetchEvents({int page = 1, int limit = 20}) async {
    final offset = (page - 1) * limit;

    final response = await supabase
        .from('events')
        .select('''
          *,
          creator:users(id, name, avatar_url, class)
        ''')
        .eq('status', 'approved')                // Only approved events (FR-002)
        .gte('event_date', 'current_date')       // Only upcoming events (FR-003, FR-003a)
        .order('created_at', ascending: false)   // Newest first (FR-003)
        .range(offset, offset + limit - 1);      // Pagination (FR-001)

    return (response as List)
        .map((json) => EventModel.fromJson(json))
        .toList();
  }
}
```

**RLS Policy**:

```sql
-- Row-Level Security: Users can view upcoming approved events
CREATE POLICY "Users can view upcoming approved events"
  ON events FOR SELECT
  USING (
    status = 'approved'
    AND event_date >= CURRENT_DATE
  );
```

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| **Time-based (created_at > now() - 7 days)** | Arbitrary 7-day limit, events created 8 days ago but happening tomorrow would be hidden |
| **Client-side filtering** | Wastes bandwidth (fetches all events, filters locally), violates performance requirements |
| **Separate "archived" flag** | Redundant with event_date, requires manual cron job to update flag |
| **Soft delete after date** | Loses event history, violates GDPR Right to Access (users should be able to see past events they attended) |

### References

- [PostgreSQL Date/Time Functions](https://www.postgresql.org/docs/current/functions-datetime.html)
- [Supabase Row-Level Security](https://supabase.com/docs/guides/auth/row-level-security)
- [Database Indexing Best Practices](https://use-the-index-luke.com/)

---

## Summary of Key Technologies

| Technology | Purpose | Rationale |
|------------|---------|-----------|
| **Hive** | Offline-first local cache | Fast, typed, NoSQL storage for events and offline queue |
| **Supabase Realtime** | Live comment updates | WebSocket-based, <2s latency, RLS-filtered |
| **ListView.builder** | Infinite scroll | Memory-efficient lazy loading, 60fps performance |
| **cached_network_image** | Image optimization | WebP support, progressive loading, caching |
| **RefreshIndicator** | Pull-to-refresh | Native Flutter widget, platform-aware |
| **VARCHAR(500) constraint** | Comment length limit | Database-enforced, prevents abuse |
| **Exponential backoff** | Offline sync retry | Industry standard, automatic recovery |
| **Date-based filtering** | Event archival | Indexed SQL query, server-side logic |

---

**Research Status**: ✅ Complete - All 9 key areas documented with implementation patterns
