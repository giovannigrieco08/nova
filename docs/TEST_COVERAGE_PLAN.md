# Piano Test Coverage 80%

**Obiettivo:** Raggiungere 80% di code coverage
**Stato attuale:** 12.2% (12/98 linee nei file caricati dai test)
**Codebase:** 407 file Dart, ~23,474 linee di codice

---

## Analisi Codebase

### Feature per dimensione (linee di codice)

| Priorita | Feature | File | Linee | % Codebase |
|----------|---------|------|-------|------------|
| P1 | events | 81 | 21,694 | 28.7% |
| P1 | chat | 41 | 13,601 | 18.0% |
| P1 | comments | 51 | 10,323 | 13.7% |
| P1 | profile | 37 | 10,078 | 13.4% |
| P2 | tutoring | 19 | 5,115 | 6.8% |
| P2 | admin | 24 | 3,949 | 5.2% |
| P2 | notifications | 27 | 3,872 | 5.1% |
| P3 | safety | 24 | 3,638 | 4.8% |
| P3 | search | 19 | 3,053 | 4.0% |
| P3 | moderation | 8 | 2,087 | 2.8% |
| P3 | auth | 5 | 1,750 | 2.3% |
| P3 | bacheche | 1 | 110 | 0.1% |

### Core modules (~43 file)

- animations (9), theme (10), utils (8), services (5), providers (2), router (1), etc.

---

## Strategia di Testing

### Piramide dei Test

```
         /\
        /  \  Integration (10%)
       /----\
      /      \  Widget Tests (30%)
     /--------\
    /          \  Unit Tests (60%)
   /--------------\
```

### Layer da testare per ogni feature

```
feature/
├── domain/
│   ├── entities/      → Unit test (puro Dart, nessuna dipendenza)
│   ├── usecases/      → Unit test (mock repository)
│   └── repositories/  → Interface only, no test needed
├── data/
│   ├── models/        → Unit test (serialization/deserialization)
│   ├── repositories/  → Unit test (mock datasources)
│   └── datasources/   → Integration test (Supabase mock)
└── presentation/
    ├── providers/     → Unit test (mock dependencies)
    ├── screens/       → Widget test
    └── widgets/       → Widget test
```

---

## Edge Cases per Layer

Ogni layer ha categorie specifiche di edge case da testare. Questi NON sono opzionali - un test senza edge cases copre solo l'happy path e non previene regressioni.

### Domain Layer - Entities

| Categoria | Esempi | Test Pattern |
|-----------|--------|--------------|
| **Null/Empty values** | `title: null`, `title: ""`, `description: "   "` | `expect(() => Entity(title: null), throwsA(isA<AssertionError>()))` |
| **Boundary values** | `maxParticipants: 0`, `maxParticipants: -1`, `maxParticipants: 999999` | Test min/max/overflow |
| **Invalid dates** | `startDate > endDate`, `createdAt` nel futuro | Validation logic |
| **Unicode/Special chars** | Emoji in title, RTL text, SQL injection attempts | `title: "Test 🎉 עברית"` |
| **Equality edge cases** | Same ID different fields, different ID same fields | `expect(a, isNot(equals(b)))` |

```dart
group('Event entity edge cases', () {
  test('throws when title is empty', () {
    expect(
      () => Event(id: '1', title: '', startDate: DateTime.now()),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('throws when end date is before start date', () {
    final start = DateTime(2024, 1, 10);
    final end = DateTime(2024, 1, 5);
    expect(
      () => Event(id: '1', title: 'Test', startDate: start, endDate: end),
      throwsA(isA<InvalidDateRangeException>()),
    );
  });

  test('handles emoji in title correctly', () {
    final event = Event(id: '1', title: 'Party 🎉🎊', startDate: DateTime.now());
    expect(event.title, 'Party 🎉🎊');
  });
});
```

### Data Layer - Models (JSON Serialization)

| Categoria | Esempi | Test Pattern |
|-----------|--------|--------------|
| **Malformed JSON** | `{title: "no quotes"}`, `{"unclosed": ` | `expect(() => Model.fromJson(bad), throwsA(isA<FormatException>()))` |
| **Missing required fields** | `{"id": "1"}` senza `title` | Graceful failure o default |
| **Extra unexpected fields** | `{"id": "1", "title": "X", "hackerField": "injection"}` | Deve ignorare campi extra |
| **Type mismatches** | `{"count": "not a number"}`, `{"active": 1}` vs `true` | Type coercion o error |
| **Null vs missing** | `{"title": null}` vs `{}` | Comportamento diverso? |
| **Date formats** | ISO8601, Unix timestamp, locale string | Parse robusto |

```dart
group('EventModel JSON edge cases', () {
  test('fromJson ignores unknown fields', () {
    final json = {
      'id': '1',
      'title': 'Test',
      'unknown_field': 'should be ignored',
      'another_unknown': 123,
    };
    final model = EventModel.fromJson(json);
    expect(model.id, '1');
    expect(model.title, 'Test');
  });

  test('fromJson throws on missing required field', () {
    final json = {'id': '1'}; // missing title
    expect(
      () => EventModel.fromJson(json),
      throwsA(isA<MissingRequiredFieldException>()),
    );
  });

  test('fromJson handles null optional fields', () {
    final json = {'id': '1', 'title': 'Test', 'description': null};
    final model = EventModel.fromJson(json);
    expect(model.description, isNull);
  });

  test('toJson then fromJson is identity', () {
    final original = EventModel(id: '1', title: 'Test', createdAt: DateTime.now());
    final json = original.toJson();
    final restored = EventModel.fromJson(json);
    expect(restored, equals(original));
  });
});
```

### Data Layer - Repositories

| Categoria | Esempi | Test Pattern |
|-----------|--------|--------------|
| **Network failures** | Timeout, no internet, DNS failure | `when(() => remote.get()).thenThrow(SocketException())` |
| **HTTP errors** | 400, 401, 403, 404, 500, 503 | Ogni status code ha handling diverso |
| **Empty responses** | `[]`, `null`, `{}` | Lista vuota vs errore |
| **Partial data** | Response con alcuni campi mancanti | Graceful degradation |
| **Pagination edge cases** | Pagina vuota, ultima pagina, offset invalido | `page: 0`, `page: 999999` |
| **Cache invalidation** | Stale cache, cache miss, cache corruption | Test cache states |

```dart
group('EventRepository edge cases', () {
  test('returns empty list on 404', () async {
    when(() => mockRemote.getEvents())
        .thenThrow(NotFoundException());

    final result = await repository.getEvents();
    expect(result, isEmpty);
  });

  test('throws on 401 unauthorized', () async {
    when(() => mockRemote.getEvents())
        .thenThrow(UnauthorizedException());

    expect(
      () => repository.getEvents(),
      throwsA(isA<AuthenticationException>()),
    );
  });

  test('returns cached data on network timeout', () async {
    when(() => mockRemote.getEvents())
        .thenThrow(TimeoutException('Network timeout'));
    when(() => mockLocal.getCachedEvents())
        .thenAnswer((_) async => [cachedEvent]);

    final result = await repository.getEvents();
    expect(result, [cachedEvent]);
  });

  test('handles empty response gracefully', () async {
    when(() => mockRemote.getEvents())
        .thenAnswer((_) async => []);

    final result = await repository.getEvents();
    expect(result, isEmpty);
    verify(() => mockLocal.clearCache()).called(1);
  });
});
```

### Presentation Layer - Providers

| Categoria | Esempi | Test Pattern |
|-----------|--------|--------------|
| **Disposed state** | Accesso dopo dispose | `expect(() => container.read(provider), throwsStateError)` |
| **Rapid refresh** | Pull-to-refresh spam | Debounce, cancel previous |
| **Stale data** | Cache vecchia mentre loading | Show stale + loading indicator |
| **Error recovery** | Retry after error | State transitions |
| **Initial state** | Prima del primo fetch | Loading vs empty |

```dart
group('EventsFeedProvider edge cases', () {
  test('debounces rapid refresh calls', () async {
    final container = createContainer();

    // Trigger 5 rapid refreshes
    for (var i = 0; i < 5; i++) {
      container.read(eventsFeedProvider.notifier).refresh();
    }

    await Future.delayed(Duration(milliseconds: 500));

    // Should only call repository once due to debounce
    verify(() => mockRepository.getEvents()).called(1);
  });

  test('shows stale data while refreshing', () async {
    final container = createContainer();

    // Initial load
    await container.read(eventsFeedProvider.future);
    expect(container.read(eventsFeedProvider).value, [event1]);

    // Start refresh (slow)
    when(() => mockRepository.getEvents())
        .thenAnswer((_) async {
          await Future.delayed(Duration(seconds: 2));
          return [event1, event2];
        });

    container.read(eventsFeedProvider.notifier).refresh();

    // Should still show old data while loading
    final state = container.read(eventsFeedProvider);
    expect(state.isLoading, isTrue);
    expect(state.value, [event1]); // stale data still visible
  });
});
```

### Presentation Layer - Widgets

| Categoria | Esempi | Test Pattern |
|-----------|--------|--------------|
| **Text overflow** | Titolo 1000 caratteri | `expect(find.byType(Text), findsOneWidget)` no overflow |
| **Empty states** | Lista vuota, nessun risultato | Empty state widget shown |
| **Loading states** | Shimmer, skeleton, spinner | Loading indicator visible |
| **Error states** | Network error, generic error | Error message + retry button |
| **Responsive** | Small screen, large screen, rotation | Layout adapts |
| **Accessibility** | Screen reader, large fonts | Semantics correct |

```dart
group('EventCard widget edge cases', () {
  testWidgets('truncates very long title', (tester) async {
    final longTitle = 'A' * 500;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventCard(event: Event(id: '1', title: longTitle)),
        ),
      ),
    );

    // Should not overflow
    expect(tester.takeException(), isNull);
    // Should show ellipsis
    final text = tester.widget<Text>(find.byType(Text).first);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('shows empty state for no participants', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParticipantAvatars(participants: []),
        ),
      ),
    );

    expect(find.text('Nessun partecipante'), findsOneWidget);
  });

  testWidgets('handles rapid tap without double-action', (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventCard(
            event: testEvent,
            onTap: () => tapCount++,
          ),
        ),
      ),
    );

    // Rapid taps
    await tester.tap(find.byType(EventCard));
    await tester.tap(find.byType(EventCard));
    await tester.tap(find.byType(EventCard));
    await tester.pumpAndSettle();

    // Should only register once (debounced)
    expect(tapCount, 1);
  });
});
```

---

## Race Conditions e Concurrency

Nova ha molte feature realtime che richiedono test specifici per race conditions. Usare `fake_async` per controllare il timing nei test.

### Matrice Race Conditions per Feature

| Feature | Race Condition | Rischio | Priorita |
|---------|----------------|---------|----------|
| **Chat Realtime** | Messaggi fuori ordine | Alto - UX confusa | P1 |
| **Chat Realtime** | Messaggi duplicati | Alto - Spam visivo | P1 |
| **Chat Realtime** | Typing indicator stale | Medio - UX minore | P2 |
| **Comments Realtime** | Edit/delete concorrenti | Alto - Data loss | P1 |
| **Comments Realtime** | Like count inconsistente | Medio - UX minore | P2 |
| **Offline Queue** | Sync durante nuovo edit | Alto - Data loss | P1 |
| **Offline Queue** | Retry loop infinito | Alto - Battery drain | P1 |
| **Feed Refresh** | Pull + auto refresh | Medio - Flicker | P2 |
| **Auth State** | Token refresh durante request | Alto - 401 cascade | P1 |
| **Profile Update** | Concurrent avatar + bio update | Medio - Partial update | P2 |
| **Search** | Rapid typing results overlap | Medio - Wrong results | P2 |

### Pattern di Test per Race Conditions

#### 1. Messaggi Chat Fuori Ordine

```dart
group('Chat message ordering race conditions', () {
  test('reorders messages received out of order', () async {
    fakeAsync((async) {
      final container = createContainer();
      final notifier = container.read(chatMessagesProvider.notifier);

      // Simulate messages arriving out of order from realtime
      notifier.onRealtimeMessage(ChatMessage(id: '3', text: 'Third', timestamp: DateTime(2024, 1, 1, 12, 0, 2)));
      async.elapse(Duration(milliseconds: 50));

      notifier.onRealtimeMessage(ChatMessage(id: '1', text: 'First', timestamp: DateTime(2024, 1, 1, 12, 0, 0)));
      async.elapse(Duration(milliseconds: 50));

      notifier.onRealtimeMessage(ChatMessage(id: '2', text: 'Second', timestamp: DateTime(2024, 1, 1, 12, 0, 1)));
      async.elapse(Duration(milliseconds: 100));

      final messages = container.read(chatMessagesProvider);
      expect(messages.map((m) => m.id), ['1', '2', '3']); // Correctly ordered
    });
  });

  test('deduplicates messages with same ID', () async {
    fakeAsync((async) {
      final container = createContainer();
      final notifier = container.read(chatMessagesProvider.notifier);

      // Same message received twice (network retry)
      notifier.onRealtimeMessage(ChatMessage(id: '1', text: 'Hello'));
      async.elapse(Duration(milliseconds: 100));
      notifier.onRealtimeMessage(ChatMessage(id: '1', text: 'Hello'));
      async.elapse(Duration(milliseconds: 100));

      final messages = container.read(chatMessagesProvider);
      expect(messages.length, 1); // No duplicate
    });
  });
});
```

#### 2. Edit/Delete Concorrenti su Commenti

```dart
group('Comment edit/delete race conditions', () {
  test('delete wins over concurrent edit', () async {
    fakeAsync((async) {
      final container = createContainer();

      // User A starts editing
      container.read(commentEditProvider('comment-1').notifier).startEdit('New text');
      async.elapse(Duration(milliseconds: 100));

      // User B deletes (arrives via realtime)
      container.read(commentsRealtimeProvider.notifier)
          .onCommentDeleted('comment-1');
      async.elapse(Duration(milliseconds: 50));

      // User A tries to save edit
      final result = await container.read(commentEditProvider('comment-1').notifier).save();

      expect(result.isFailure, isTrue);
      expect(result.error, isA<CommentDeletedException>());
    });
  });

  test('optimistic update rolls back on conflict', () async {
    fakeAsync((async) {
      final container = createContainer();
      final originalText = 'Original';

      // Optimistic update
      container.read(commentProvider('1').notifier).optimisticUpdate('New text');
      expect(container.read(commentProvider('1')).text, 'New text');

      // Server rejects (409 Conflict)
      when(() => mockRepository.updateComment(any()))
          .thenThrow(ConflictException());

      await container.read(commentProvider('1').notifier).save();
      async.elapse(Duration(milliseconds: 100));

      // Should rollback
      expect(container.read(commentProvider('1')).text, originalText);
    });
  });
});
```

#### 3. Offline Queue Sync Conflicts

```dart
group('Offline queue race conditions', () {
  test('pauses queue during active sync', () async {
    fakeAsync((async) {
      final queue = OfflineQueue();

      // Start syncing item 1
      queue.enqueue(OfflineAction.createEvent(event1));
      final syncFuture = queue.startSync();
      async.elapse(Duration(milliseconds: 100));

      // User creates another event while syncing
      queue.enqueue(OfflineAction.createEvent(event2));

      // Item 2 should wait until item 1 completes
      expect(queue.pendingCount, 1); // item 2 queued but not syncing

      async.elapse(Duration(seconds: 2)); // item 1 completes
      await syncFuture;

      expect(queue.pendingCount, 0); // both synced
    });
  });

  test('handles edit to queued create', () async {
    fakeAsync((async) {
      final queue = OfflineQueue();

      // Queue create (offline)
      final tempId = 'temp-123';
      queue.enqueue(OfflineAction.createEvent(Event(id: tempId, title: 'Original')));

      // User edits before sync completes
      queue.enqueue(OfflineAction.updateEvent(Event(id: tempId, title: 'Edited')));

      // Should merge into single create with final state
      expect(queue.pendingCount, 1);
      expect(queue.peek()!.event.title, 'Edited');
    });
  });

  test('prevents retry loop on permanent failure', () async {
    fakeAsync((async) {
      final queue = OfflineQueue();
      var attemptCount = 0;

      when(() => mockRemote.createEvent(any())).thenAnswer((_) async {
        attemptCount++;
        throw PermanentFailureException(); // 400 Bad Request
      });

      queue.enqueue(OfflineAction.createEvent(event1));

      // Should stop after max retries
      for (var i = 0; i < 10; i++) {
        await queue.processNext();
        async.elapse(Duration(seconds: 1));
      }

      expect(attemptCount, lessThanOrEqualTo(3)); // Max 3 retries
      expect(queue.failedItems, contains(event1.id));
    });
  });
});
```

#### 4. Auth Token Refresh Race

```dart
group('Auth token refresh race conditions', () {
  test('queues requests during token refresh', () async {
    fakeAsync((async) {
      final authService = AuthService();

      // Token expires
      authService.simulateTokenExpiry();

      // Multiple requests hit 401 simultaneously
      final futures = [
        authService.authenticatedRequest('/events'),
        authService.authenticatedRequest('/profile'),
        authService.authenticatedRequest('/notifications'),
      ];

      async.elapse(Duration(milliseconds: 100));

      // Should only refresh once
      verify(() => mockAuth.refreshToken()).called(1);

      // All requests should complete after refresh
      final results = await Future.wait(futures);
      expect(results.every((r) => r.isSuccess), isTrue);
    });
  });

  test('handles refresh failure gracefully', () async {
    fakeAsync((async) {
      final authService = AuthService();

      when(() => mockAuth.refreshToken())
          .thenThrow(RefreshTokenExpiredException());

      authService.simulateTokenExpiry();

      final result = await authService.authenticatedRequest('/events');

      expect(result.isFailure, isTrue);
      expect(result.error, isA<AuthenticationRequiredException>());

      // Should trigger logout
      verify(() => mockAuth.logout()).called(1);
    });
  });
});
```

#### 5. Search Debounce e Results Overlap

```dart
group('Search race conditions', () {
  test('cancels previous search on new input', () async {
    fakeAsync((async) {
      final container = createContainer();
      final notifier = container.read(searchProvider.notifier);

      // Rapid typing
      notifier.search('a');
      async.elapse(Duration(milliseconds: 50));
      notifier.search('ab');
      async.elapse(Duration(milliseconds: 50));
      notifier.search('abc');
      async.elapse(Duration(milliseconds: 300)); // debounce completes

      // Should only search for final term
      verify(() => mockRepository.search('abc')).called(1);
      verifyNever(() => mockRepository.search('a'));
      verifyNever(() => mockRepository.search('ab'));
    });
  });

  test('discards stale results', () async {
    fakeAsync((async) {
      final container = createContainer();
      final notifier = container.read(searchProvider.notifier);

      // First search (slow)
      when(() => mockRepository.search('slow'))
          .thenAnswer((_) async {
            await Future.delayed(Duration(seconds: 2));
            return ['slow-result'];
          });

      // Second search (fast)
      when(() => mockRepository.search('fast'))
          .thenAnswer((_) async => ['fast-result']);

      notifier.search('slow');
      async.elapse(Duration(milliseconds: 500));
      notifier.search('fast');
      async.elapse(Duration(seconds: 3));

      // Should show fast results, not slow (even though slow completes later)
      expect(container.read(searchProvider).results, ['fast-result']);
    });
  });
});
```

### Checklist Race Conditions per PR

Prima di ogni PR che tocca codice realtime/async, verificare:

- [ ] **Ordering**: I dati arrivano in ordine corretto?
- [ ] **Deduplication**: Gestiti messaggi/eventi duplicati?
- [ ] **Cancellation**: Le operazioni precedenti vengono cancellate?
- [ ] **Rollback**: Gli optimistic update hanno rollback su errore?
- [ ] **Debounce**: Input rapidi sono debounced?
- [ ] **Stale data**: I risultati vecchi vengono scartati?
- [ ] **Queue conflicts**: La queue offline gestisce edit su item pending?
- [ ] **Token refresh**: Le richieste attendono il refresh?

---

## Piano di Esecuzione

### Fase 0: Setup Infrastruttura (1-2 giorni)

**Obiettivo:** Creare foundation per testing scalabile

- [ ] **0.1** Setup test dependencies in `pubspec.yaml`
  ```yaml
  dev_dependencies:
    flutter_test:
      sdk: flutter
    mocktail: ^1.0.0
    fake_async: ^1.3.0
    golden_toolkit: ^0.15.0
  ```

- [ ] **0.2** Creare mock factory centralizzata
  ```
  test/
  ├── mocks/
  │   ├── mock_repositories.dart
  │   ├── mock_services.dart
  │   └── mock_supabase.dart (esistente)
  ├── fixtures/
  │   ├── event_fixtures.dart
  │   ├── user_fixtures.dart
  │   └── chat_fixtures.dart
  └── helpers/
      ├── pump_app.dart
      └── golden_helpers.dart
  ```

- [ ] **0.3** Configurare CI per coverage report
  - GitHub Action per `flutter test --coverage`
  - Upload a Codecov/Coveralls
  - Badge in README

---

### Fase 1: Domain Layer - Entities & Models (5 giorni)

**Obiettivo:** +15% coverage (target: ~27%)
**Test totali:** ~250 (150 happy path + 100 edge cases)

Test puri Dart senza dipendenze Flutter. Focus su:
- Serialization/deserialization JSON
- Equality e hashCode
- copyWith methods
- Validation logic
- **Edge cases:** null/empty values, boundary values, unicode, invalid dates

#### 1.1 Events Domain (P1 - maggior impatto)

```
test/unit/features/events/domain/entities/
├── event_test.dart
├── event_status_test.dart
├── collaboration_invite_test.dart
├── user_profile_test.dart
└── app_notification_test.dart

test/unit/features/events/data/models/
├── event_model_test.dart
├── like_model_test.dart
├── participation_model_test.dart
└── report_model_test.dart
```

**Stima:** ~20 test file, ~60 happy path + ~40 edge cases

#### 1.2 Chat Domain (P1)

```
test/unit/features/chat/domain/entities/
├── chat_message_test.dart
├── chat_reaction_test.dart
├── chat_report_test.dart
└── mention_info_test.dart

test/unit/features/chat/data/models/
├── chat_message_model_test.dart
├── chat_reaction_model_test.dart
└── chat_media_model_test.dart
```

**Stima:** ~15 test file, ~45 happy path + ~30 edge cases

#### 1.3 Comments Domain (P1)

```
test/unit/features/comments/domain/entities/
├── comment_test.dart
├── comment_like_test.dart
├── comment_report_test.dart
└── mention_test.dart
```

**Stima:** ~10 test file, ~30 happy path + ~20 edge cases

#### 1.4 Profile Domain (P1)

```
test/unit/features/profile/domain/entities/
└── profile_test.dart

test/unit/features/profile/data/models/
└── profile_model_test.dart
```

**Stima:** ~5 test file, ~15 happy path + ~10 edge cases

---

### Fase 2: Domain Layer - Use Cases (5 giorni)

**Obiettivo:** +15% coverage (target: ~42%)
**Test totali:** ~150 (100 happy path + 50 edge cases)

Test degli use case con repository mockati.
- **Edge cases:** invalid inputs, repository errors, permission denied

#### 2.1 Events Use Cases

```
test/unit/features/events/domain/usecases/
├── get_events_feed_test.dart
├── create_event_test.dart
├── update_event_test.dart
├── delete_event_test.dart
├── join_event_test.dart
└── leave_event_test.dart
```

#### 2.2 Comments Use Cases

```
test/unit/features/comments/domain/usecases/
├── get_comments_for_event_test.dart
├── post_comment_test.dart
├── edit_comment_test.dart
├── delete_comment_test.dart
├── like_comment_test.dart
├── unlike_comment_test.dart
├── reply_to_comment_test.dart
└── moderator_remove_comment_test.dart
```

#### 2.3 Profile Use Cases

```
test/unit/features/profile/domain/usecases/
├── check_profile_complete_test.dart
├── upload_avatar_test.dart
├── update_profile_test.dart
└── get_profile_test.dart
```

#### 2.4 Notifications Use Cases

```
test/unit/features/notifications/domain/usecases/
├── register_fcm_token_test.dart
└── remove_fcm_token_test.dart
```

**Stima totale Fase 2:** ~30 test file, ~100 happy path + ~50 edge cases

---

### Fase 3: Data Layer - Repositories (5 giorni)

**Obiettivo:** +13% coverage (target: ~55%)
**Test totali:** ~120 (60 happy path + 40 edge cases + 20 race conditions)

Test dei repository con datasources mockati.
- **Edge cases:** network failures, HTTP errors, cache states, pagination
- **Race conditions:** offline queue sync, cache invalidation

#### 3.1 Core Repositories

```
test/unit/features/events/data/repositories/
├── event_repository_test.dart
└── offline_queue_repository_test.dart

test/unit/features/profile/data/repositories/
└── profile_repository_test.dart

test/unit/features/notifications/data/repositories/
├── notification_repository_test.dart
└── push_repository_test.dart
```

#### 3.2 Pattern di test per repository

```dart
void main() {
  late EventRepository repository;
  late MockEventRemoteDatasource mockRemote;
  late MockEventLocalDatasource mockLocal;

  setUp(() {
    mockRemote = MockEventRemoteDatasource();
    mockLocal = MockEventLocalDatasource();
    repository = EventRepository(
      remoteDatasource: mockRemote,
      localDatasource: mockLocal,
    );
  });

  group('getEvents', () {
    test('returns events from remote when online', () async {
      // arrange
      when(() => mockRemote.getEvents()).thenAnswer((_) async => [testEvent]);
      // act
      final result = await repository.getEvents();
      // assert
      expect(result, [testEvent]);
      verify(() => mockRemote.getEvents()).called(1);
    });

    test('returns cached events when offline', () async {
      // ...
    });
  });
}
```

**Stima:** ~15 test file, ~60 happy path + ~40 edge cases + ~20 race conditions

---

### Fase 4: Core Module (3 giorni)

**Obiettivo:** +5% coverage (target: ~60%)
**Test totali:** ~85 (50 happy path + 25 edge cases + 10 race conditions)

#### 4.1 Providers (esistente, da espandere)

```
test/unit/core/providers/
├── core_providers_test.dart (esistente - 8 test)
└── auth_state_provider_test.dart
```

#### 4.2 Services

```
test/unit/core/services/
├── supabase_service_test.dart
├── storage_service_test.dart
└── analytics_service_test.dart
```

#### 4.3 Utils

```
test/unit/core/utils/
├── deep_link_handler_test.dart
├── platform_utils_test.dart
└── validators_test.dart
```

#### 4.4 Theme

```
test/unit/core/theme/
├── nova_spacing_test.dart
├── nova_radius_test.dart
└── nova_animations_test.dart
```

**Stima:** ~15 test file, ~50 happy path + ~25 edge cases + ~10 race conditions

---

### Fase 5: Presentation Layer - Providers (5 giorni)

**Obiettivo:** +10% coverage (target: ~70%)
**Test totali:** ~130 (60 happy path + 40 edge cases + 30 race conditions)

Test dei Riverpod providers con container mockati.
- **Edge cases:** disposed state, rapid refresh, stale data, error recovery
- **Race conditions:** concurrent updates, debounce, stale results discard

#### 5.1 Setup Provider Testing

```dart
// test/helpers/provider_container.dart
ProviderContainer createContainer({
  List<Override> overrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      // Default mocks
      supabaseClientProvider.overrideWithValue(mockSupabase),
      ...overrides,
    ],
  );
}
```

#### 5.2 Provider Tests

```
test/unit/features/events/presentation/providers/
├── events_feed_provider_test.dart
├── event_detail_provider_test.dart
└── event_form_provider_test.dart

test/unit/features/comments/presentation/providers/
├── comments_provider_test.dart
├── replies_provider_test.dart
└── mention_navigation_provider_test.dart

test/unit/features/search/presentation/providers/
├── search_provider_test.dart
└── search_history_provider_test.dart
```

**Stima:** ~20 test file, ~60 happy path + ~40 edge cases + ~30 race conditions

---

### Fase 6: Widget Tests (6 giorni)

**Obiettivo:** +10% coverage (target: ~80%)
**Test totali:** ~125 (80 happy path + 45 edge cases)

#### 6.1 Shared Widgets

```
test/widget/shared/widgets/
├── adaptive/
│   ├── adaptive_dialog_test.dart
│   ├── adaptive_bottom_sheet_test.dart
│   └── adaptive_card_test.dart
├── nova_tabs_test.dart
└── nova_button_test.dart
```

#### 6.2 Feature Widgets (componenti critici)

```
test/widget/features/events/
├── event_card_test.dart
├── event_list_tile_test.dart
└── participant_avatars_test.dart

test/widget/features/profile/
├── avatar_initials_test.dart
└── incomplete_profile_banner_test.dart

test/widget/features/comments/
├── comment_tile_test.dart
├── realtime_status_banner_test.dart
└── delete_confirmation_dialog_test.dart
```

#### 6.3 Pattern Widget Test

```dart
void main() {
  testWidgets('EventCard displays event title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventCard(event: testEvent),
        ),
      ),
    );

    expect(find.text(testEvent.title), findsOneWidget);
  });

  testWidgets('EventCard calls onTap when pressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventCard(
            event: testEvent,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(EventCard));
    expect(tapped, isTrue);
  });
}
```

**Stima:** ~25 test file, ~80 happy path + ~45 edge cases

---

## Task Atomiche

> **Documento completo:** [TEST_TASKS.md](TEST_TASKS.md)

Il piano e stato decomposto in **181 task atomiche** (1-4h ciascuna), tutte parallelizzabili per gruppo.

### Riepilogo Task per Fase

| Fase | Task | Ore | Happy Path | Edge Cases | Race Cond. | Totale Test |
|------|------|-----|------------|------------|------------|-------------|
| 0: Setup | 11 | 13h | - | - | - | - |
| 1: Entities/Models | 54 | 90h | 149 | 143 | - | 292 |
| 2: Use Cases | 24 | 43h | 65 | 53 | - | 118 |
| 3: Repositories | 26 | 75h | 101 | 85 | 26 | 212 |
| 4: Core | 18 | 35h | 55 | 54 | 8 | 117 |
| 5: Providers | 23 | 70h | 80 | 62 | 43 | 185 |
| 6: Widgets | 25 | 45h | 69 | 57 | - | 126 |
| **Totale** | **181** | **371h** | **519** | **454** | **77** | **1050** |

### Grafo Dipendenze

```
T0.1 (deps)
├── T0.2 (pump_app)           → Fase 6 (widgets)
├── T0.3 (provider_container) → Fase 5 (providers)
├── T0.4 (mock_repos)  → Fase 2 (usecases) ┐
├── T0.5 (mock_supabase) → Fase 3 (repos)   ├→ Fase 5 → Fase 6
├── T0.6 (mock_services) → Fase 4 (core)    │
├── T0.7-T0.10 (fixtures) → Fase 1 (entities)┘
└── T0.11 (CI) → (parallelo a tutto)

Fase 1 ←→ Fase 4 (parallele!)
  ↓           ↓
Fase 2 ←→ Fase 4 (parallele!)
  ↓           ↓
Fase 3 ──→ Fase 5 ──→ Fase 6
```

### Timeline per Team Size

| Team | Durata | Note |
|------|--------|------|
| 1 dev | ~9 settimane | Sequenziale ottimizzato |
| 2 dev | ~5 settimane | Split per feature |
| 4 dev | ~6 settimane | Massimo parallelismo |

---

## Timeline Stimata (1 developer)

| Settimana | Focus | Coverage Target |
|-----------|-------|-----------------|
| 1-2 | Setup + Entities quick wins | 27% |
| 3 | Entities (cont.) + Core utils | 35% |
| 4 | Use Cases | 42% |
| 5-6 | Repositories | 55% |
| 7 | Core services + Providers (start) | 65% |
| 8 | Providers | 70% |
| 9 | Widgets | **80%** |

---

## Metriche e Monitoraggio

### Coverage Goals per Layer

| Layer | Target | Rationale |
|-------|--------|-----------|
| Domain (entities) | 95% | Puro Dart, facile da testare |
| Domain (usecases) | 90% | Logica core dell'app |
| Data (models) | 90% | Serialization critica |
| Data (repositories) | 85% | Business logic |
| Presentation (providers) | 80% | State management |
| Presentation (widgets) | 70% | UI components |
| Integration | 50% | Happy paths principali |

### File da Escludere da Coverage

```yaml
# In pubspec.yaml o coverage config
coverage:
  exclude:
    - "**/*.g.dart"           # Generated code
    - "**/*.freezed.dart"     # Freezed generated
    - "**/generated/**"       # Other generated
    - "lib/main.dart"         # Entry point
    - "lib/firebase_options.dart"
```

### CI/CD Integration

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
        with:
          files: coverage/lcov.info
          fail_ci_if_error: true
          threshold: 80
```

---

## Priorita di Implementazione

### Sprint 1 (Settimana 1-2): Foundation + Events
1. Setup infrastruttura test
2. Events entities + models
3. Events use cases
4. Events repository

### Sprint 2 (Settimana 3-4): Chat + Comments
1. Chat entities + models
2. Comments entities + use cases
3. Comments repository

### Sprint 3 (Settimana 5-6): Profile + Core
1. Profile complete testing
2. Core providers/services/utils
3. Notifications testing

### Sprint 4 (Settimana 7-8): Presentation Layer
1. All providers testing
2. Critical widgets testing
3. Integration tests happy paths

---

## Quick Wins (Primi 3 giorni)

Per vedere risultati immediati, iniziare con:

1. **Entities semplici** - Event, Comment, Profile entities
2. **Models con toJson/fromJson** - Facili da testare
3. **Pure functions in utils** - Validators, formatters
4. **Existing providers expansion** - Espandere core_providers_test

Questo puo portare rapidamente al 30-35% di coverage.

---

## Note Finali

### Principi Generali
- **Non testare codice generato** (.g.dart, .freezed.dart)
- **Preferire test veloci** - Unit > Widget > Integration
- **Mock dependencies** - Usare mocktail, non implementazioni reali
- **Test behavior, not implementation** - Cosa fa, non come
- **Mantenere test indipendenti** - Ogni test deve poter girare da solo

### Edge Cases (obbligatori)
- Ogni test file DEVE includere edge cases (vedi sezione "Edge Cases per Layer")
- Coverage senza edge cases e un falso senso di sicurezza
- Priorita: null handling > boundary values > error states

### Race Conditions (per feature realtime)
- Usare `fake_async` per controllare timing
- Testare ordering, deduplication, cancellation
- Verificare checklist race conditions prima di ogni PR

### Definition of Done per Test
Un test e completo quando include:
1. Happy path
2. Almeno 2 edge cases rilevanti
3. Error handling
4. Per codice async: almeno 1 race condition test

---

*Piano creato il 2026-04-02*
*Ultimo aggiornamento: 2026-04-02*
*Coverage attuale: 12.2% | Target: 80%*
