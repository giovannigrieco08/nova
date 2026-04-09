# Task Atomiche - Test Coverage 80%

> Riferimento: [TEST_COVERAGE_PLAN.md](TEST_COVERAGE_PLAN.md)
> File generati (.freezed.dart, .g.dart) esclusi dai test.

## Legenda

- `[P]` = Parallelizzabile con altri task dello stesso gruppo
- `[dopo: TX.X.X]` = Dipendenza da altro task
- `H` = Happy path tests | `E` = Edge case tests | `R` = Race condition tests
- Durata in ore (1h-4h per task)

---

## Fase 0: Setup Infrastruttura

### Gruppo 0.A: Dependencies & Config

| ID | Task | Durata | Dipendenze | Test |
|----|------|--------|------------|------|
| T0.1 | Aggiungere `mocktail`, `fake_async`, `golden_toolkit` a `pubspec.yaml` | 1h | - | - |
| T0.2 | Creare `test/helpers/pump_app.dart` (wrapper MaterialApp per widget test) | 1h | T0.1 | - |
| T0.3 | Creare `test/helpers/provider_container.dart` (ProviderContainer con mock default) | 1h | T0.1 | - |

### Gruppo 0.B: Mock Factory [dopo: T0.1]

| ID | Task | Durata | Dipendenze | Test |
|----|------|--------|------------|------|
| T0.4 | Creare `test/mocks/mock_repositories.dart` (mock di tutti i repository interfaces) | 2h | T0.1 | - |
| T0.5 | Aggiornare `test/mocks/mock_supabase.dart` (mock SupabaseClient, auth, storage) | 1h | T0.1 | - |
| T0.6 | Creare `test/mocks/mock_services.dart` (push, error handler, share, deep link) | 1h | T0.1 | - |

### Gruppo 0.C: Fixtures [P con 0.B]

| ID | Task | Durata | Dipendenze | Test |
|----|------|--------|------------|------|
| T0.7 | Creare `test/fixtures/event_fixtures.dart` | 1h | T0.1 | - |
| T0.8 | Creare `test/fixtures/profile_fixtures.dart` | 1h | T0.1 | - |
| T0.9 | Creare `test/fixtures/chat_fixtures.dart` | 1h | T0.1 | - |
| T0.10 | Creare `test/fixtures/comment_fixtures.dart` | 1h | T0.1 | - |

### Gruppo 0.D: CI/CD [P con tutto]

| ID | Task | Durata | Dipendenze | Test |
|----|------|--------|------------|------|
| T0.11 | Creare `.github/workflows/test.yml` (flutter test --coverage + Codecov) | 2h | - | - |

**Fase 0 totale: 13h (~2 giorni)**

---

## Fase 1: Domain Layer - Entities & Models

### Gruppo 1.A: Events Entities [P] - tutti parallelizzabili tra loro

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T1.1 | `test/unit/features/events/domain/entities/event_test.dart` | event.dart (140 LOC) | 3h | T0.7 | 5 | 4 |
| T1.2 | `test/unit/features/events/domain/entities/event_status_test.dart` | event_status.dart (58 LOC) | 1h | T0.1 | 3 | 2 |
| T1.3 | `test/unit/features/events/domain/entities/event_help_request_test.dart` | event_help_request.dart (119 LOC) | 2h | T0.7 | 4 | 3 |
| T1.4 | `test/unit/features/events/domain/entities/collaboration_invite_test.dart` | collaboration_invite.dart (132 LOC) | 2h | T0.7 | 3 | 3 |
| T1.5 | `test/unit/features/events/domain/entities/user_profile_test.dart` | user_profile.dart (77 LOC) | 1h | T0.7 | 3 | 2 |
| T1.6 | `test/unit/features/events/domain/entities/app_notification_test.dart` | app_notification.dart (52 LOC) | 1h | T0.7 | 2 | 2 |
| T1.7 | `test/unit/features/events/domain/entities/offline_action_test.dart` | offline_action.dart (105 LOC) | 2h | T0.7 | 3 | 3 |
| T1.8 | `test/unit/features/events/domain/entities/notification_channel_test.dart` | notification_channel.dart (92 LOC) | 1h | T0.1 | 2 | 2 |

### Gruppo 1.B: Events Models [P] - tutti parallelizzabili tra loro

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T1.9 | `test/unit/features/events/data/models/event_model_test.dart` | event_model.dart (231 LOC) | 3h | T0.7 | 4 | 5 |
| T1.10 | `test/unit/features/events/data/models/event_draft_test.dart` | event_draft.dart (144 LOC) | 2h | T0.7 | 3 | 3 |
| T1.11 | `test/unit/features/events/data/models/like_model_test.dart` | like_model.dart (65 LOC) | 1h | T0.7 | 2 | 2 |
| T1.12 | `test/unit/features/events/data/models/participation_model_test.dart` | participation_model.dart (65 LOC) | 1h | T0.7 | 2 | 2 |
| T1.13 | `test/unit/features/events/data/models/report_model_test.dart` | report_model.dart (132 LOC) | 2h | T0.7 | 3 | 3 |
| T1.14 | `test/unit/features/events/data/models/comment_model_test.dart` | comment_model.dart (125 LOC) | 2h | T0.7 | 3 | 3 |
| T1.15 | `test/unit/features/events/data/models/notification_model_test.dart` | notification_model.dart (133 LOC) | 2h | T0.7 | 3 | 3 |
| T1.16 | `test/unit/features/events/data/models/event_help_request_model_test.dart` | event_help_request_model.dart (187 LOC) | 2h | T0.7 | 3 | 4 |

### Gruppo 1.C: Chat Entities & Models [P con 1.A, 1.B]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T1.17 | `test/unit/features/chat/domain/entities/chat_message_test.dart` | chat_message.dart (221 LOC) | 3h | T0.9 | 4 | 4 |
| T1.18 | `test/unit/features/chat/domain/entities/chat_media_info_test.dart` | chat_media_info.dart (116 LOC) | 2h | T0.9 | 3 | 3 |
| T1.19 | `test/unit/features/chat/domain/entities/chat_reaction_test.dart` | chat_reaction.dart (69 LOC) | 1h | T0.9 | 2 | 2 |
| T1.20 | `test/unit/features/chat/domain/entities/chat_report_test.dart` | chat_report.dart (84 LOC) | 1h | T0.9 | 2 | 2 |
| T1.21 | `test/unit/features/chat/domain/entities/mention_info_test.dart` | mention_info.dart (54 LOC) | 1h | T0.9 | 2 | 2 |
| T1.22 | `test/unit/features/chat/data/models/chat_message_model_test.dart` | chat_message_model.dart (307 LOC) | 3h | T0.9 | 4 | 5 |
| T1.23 | `test/unit/features/chat/data/models/chat_reaction_model_test.dart` | chat_reaction_model.dart (68 LOC) | 1h | T0.9 | 2 | 2 |
| T1.24 | `test/unit/features/chat/data/models/chat_report_model_test.dart` | chat_report_model.dart (97 LOC) | 1h | T0.9 | 2 | 2 |
| T1.25 | `test/unit/features/chat/data/models/chat_media_model_test.dart` | chat_media_model.dart (144 LOC) | 2h | T0.9 | 3 | 3 |

### Gruppo 1.D: Comments Entities & Models [P con 1.A, 1.B, 1.C]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T1.26 | `test/unit/features/comments/domain/entities/comment_test.dart` | comment.dart (256 LOC) | 3h | T0.10 | 4 | 4 |
| T1.27 | `test/unit/features/comments/domain/entities/comment_like_test.dart` | comment_like.dart (51 LOC) | 1h | T0.10 | 2 | 2 |
| T1.28 | `test/unit/features/comments/domain/entities/comment_report_test.dart` | comment_report.dart (133 LOC) | 2h | T0.10 | 3 | 3 |
| T1.29 | `test/unit/features/comments/domain/entities/mention_test.dart` | mention.dart (103 LOC) | 2h | T0.10 | 3 | 2 |
| T1.30 | `test/unit/features/comments/domain/exceptions/comments_exceptions_test.dart` | comments_exceptions.dart (244 LOC) | 2h | T0.1 | 4 | 3 |
| T1.31 | `test/unit/features/comments/data/models/comment_model_test.dart` | comment_model.dart (263 LOC) | 3h | T0.10 | 4 | 4 |
| T1.32 | `test/unit/features/comments/data/models/comment_like_model_test.dart` | comment_like_model.dart (105 LOC) | 1h | T0.10 | 2 | 2 |
| T1.33 | `test/unit/features/comments/data/models/comment_report_model_test.dart` | comment_report_model.dart (191 LOC) | 2h | T0.10 | 3 | 3 |

### Gruppo 1.E: Profile Entities & Models [P con 1.A-1.D]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T1.34 | `test/unit/features/profile/domain/entities/profile_test.dart` | profile.dart (97 LOC) | 2h | T0.8 | 3 | 3 |
| T1.35 | `test/unit/features/profile/domain/entities/profile_stats_test.dart` | profile_stats.dart (69 LOC) | 1h | T0.8 | 2 | 2 |
| T1.36 | `test/unit/features/profile/data/models/profile_model_test.dart` | profile_model.dart (183 LOC) | 2h | T0.8 | 3 | 4 |

### Gruppo 1.F: Other Features Entities & Models [P con 1.A-1.E]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T1.37 | `test/unit/features/notifications/domain/entities/notification_test.dart` | notification.dart (195 LOC) | 2h | T0.1 | 3 | 3 |
| T1.38 | `test/unit/features/notifications/domain/entities/push_payload_test.dart` | push_payload.dart (86 LOC) | 1h | T0.1 | 2 | 2 |
| T1.39 | `test/unit/features/notifications/data/models/fcm_token_model_test.dart` | fcm_token_model.dart (83 LOC) | 1h | T0.1 | 2 | 2 |
| T1.40 | `test/unit/features/search/domain/entities/search_results_test.dart` | search_results.dart (146 LOC) | 2h | T0.1 | 3 | 3 |
| T1.41 | `test/unit/features/admin/domain/entities/activity_log_entry_test.dart` | activity_log_entry.dart (117 LOC) | 2h | T0.1 | 3 | 2 |
| T1.42 | `test/unit/features/admin/domain/entities/moderator_test.dart` | moderator.dart (51 LOC) | 1h | T0.1 | 2 | 2 |
| T1.43 | `test/unit/features/admin/domain/entities/system_stats_test.dart` | system_stats.dart (45 LOC) | 1h | T0.1 | 2 | 1 |
| T1.44 | `test/unit/features/safety/data/models/content_check_result_test.dart` | content_check_result.dart (80 LOC) | 1h | T0.1 | 2 | 2 |
| T1.45 | `test/unit/features/safety/data/models/user_block_test.dart` | user_block.dart (84 LOC) | 1h | T0.1 | 2 | 2 |
| T1.46 | `test/unit/features/safety/data/models/user_sanction_test.dart` | user_sanction.dart (126 LOC) | 2h | T0.1 | 3 | 2 |
| T1.47 | `test/unit/features/safety/data/models/report_test.dart` | report.dart (157 LOC) | 2h | T0.1 | 3 | 3 |
| T1.48 | `test/unit/features/safety/data/models/tos_status_test.dart` | tos_status.dart (112 LOC) | 1h | T0.1 | 2 | 2 |
| T1.49 | `test/unit/features/tutoring/domain/entities/tutor_profile_test.dart` | tutor_profile.dart (59 LOC) | 1h | T0.1 | 2 | 2 |
| T1.50 | `test/unit/features/tutoring/domain/entities/subject_test.dart` | subject.dart (78 LOC) | 1h | T0.1 | 2 | 2 |
| T1.51 | `test/unit/features/tutoring/data/models/tutor_profile_model_test.dart` | tutor_profile_model.dart (269 LOC) | 2h | T0.1 | 3 | 4 |
| T1.52 | `test/unit/features/moderation/data/models/moderation_event_test.dart` | moderation_event.dart (153 LOC) | 2h | T0.1 | 3 | 3 |
| T1.53 | `test/unit/features/moderation/data/models/moderation_report_test.dart` | moderation_report.dart (138 LOC) | 2h | T0.1 | 3 | 2 |
| T1.54 | `test/unit/features/admin/data/models/admin_action_test.dart` | admin_action.dart (31 LOC) | 1h | T0.1 | 2 | 1 |

**Fase 1 riepilogo:**

| Metrica | Valore |
|---------|--------|
| Task totali | 54 (T1.1 → T1.54) |
| Tutti parallelizzabili | Si (dopo fixtures) |
| Ore stimate | ~90h |
| Happy path | 149 |
| Edge cases | 143 |

---

## Fase 2: Domain Layer - Use Cases

### Gruppo 2.A: Events Use Cases [P]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T2.1 | `test/unit/features/events/domain/usecases/get_events_feed_test.dart` | get_events_feed.dart (48 LOC) | 2h | T0.4, T0.7 | 3 | 2 |

### Gruppo 2.B: Comments Use Cases [P con 2.A]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T2.2 | `test/unit/features/comments/domain/usecases/get_comments_for_event_test.dart` | get_comments_for_event.dart (50 LOC) | 2h | T0.4, T0.10 | 3 | 2 |
| T2.3 | `test/unit/features/comments/domain/usecases/post_comment_test.dart` | post_comment.dart (70 LOC) | 2h | T0.4, T0.10 | 3 | 3 |
| T2.4 | `test/unit/features/comments/domain/usecases/edit_comment_test.dart` | edit_comment.dart (128 LOC) | 3h | T0.4, T0.10 | 4 | 4 |
| T2.5 | `test/unit/features/comments/domain/usecases/delete_comment_test.dart` | delete_comment.dart (47 LOC) | 2h | T0.4, T0.10 | 2 | 2 |
| T2.6 | `test/unit/features/comments/domain/usecases/like_comment_test.dart` | like_comment.dart (53 LOC) | 1h | T0.4, T0.10 | 2 | 2 |
| T2.7 | `test/unit/features/comments/domain/usecases/unlike_comment_test.dart` | unlike_comment.dart (47 LOC) | 1h | T0.4, T0.10 | 2 | 2 |
| T2.8 | `test/unit/features/comments/domain/usecases/reply_to_comment_test.dart` | reply_to_comment.dart (54 LOC) | 2h | T0.4, T0.10 | 3 | 2 |
| T2.9 | `test/unit/features/comments/domain/usecases/report_comment_test.dart` | report_comment.dart (68 LOC) | 2h | T0.4, T0.10 | 3 | 2 |
| T2.10 | `test/unit/features/comments/domain/usecases/moderator_remove_comment_test.dart` | moderator_remove_comment.dart (80 LOC) | 2h | T0.4, T0.10 | 3 | 3 |
| T2.11 | `test/unit/features/comments/domain/usecases/moderator_restore_comment_test.dart` | moderator_restore_comment.dart (45 LOC) | 1h | T0.4, T0.10 | 2 | 2 |
| T2.12 | `test/unit/features/comments/domain/usecases/send_reply_notification_test.dart` | send_reply_notification.dart (70 LOC) | 2h | T0.4, T0.10 | 3 | 2 |
| T2.13 | `test/unit/features/comments/domain/usecases/subscribe_to_realtime_test.dart` | subscribe_to_realtime.dart (47 LOC) | 2h | T0.4, T0.10 | 2 | 2 |
| T2.14 | `test/unit/features/comments/domain/usecases/get_replies_for_comment_test.dart` | get_replies_for_comment.dart (45 LOC) | 1h | T0.4, T0.10 | 2 | 2 |

### Gruppo 2.C: Profile Use Cases [P con 2.A, 2.B]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T2.15 | `test/unit/features/profile/domain/usecases/create_profile_test.dart` | create_profile.dart (123 LOC) | 3h | T0.4, T0.8 | 4 | 3 |
| T2.16 | `test/unit/features/profile/domain/usecases/upload_avatar_test.dart` | upload_avatar.dart (85 LOC) | 2h | T0.4, T0.8 | 3 | 3 |
| T2.17 | `test/unit/features/profile/domain/usecases/check_profile_complete_test.dart` | check_profile_complete.dart (44 LOC) | 1h | T0.4, T0.8 | 2 | 2 |

### Gruppo 2.D: Notifications Use Cases [P con 2.A-2.C]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T2.18 | `test/unit/features/notifications/domain/usecases/register_fcm_token_test.dart` | register_fcm_token.dart (32 LOC) | 1h | T0.4 | 2 | 1 |
| T2.19 | `test/unit/features/notifications/domain/usecases/remove_fcm_token_test.dart` | remove_fcm_token.dart (32 LOC) | 1h | T0.4 | 2 | 1 |
| T2.20 | `test/unit/features/notifications/domain/usecases/handle_push_tap_test.dart` | handle_push_tap.dart (158 LOC) | 3h | T0.4 | 4 | 3 |

### Gruppo 2.E: Safety Services [P con 2.A-2.D]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T2.21 | `test/unit/features/safety/domain/services/block_service_test.dart` | block_service.dart (77 LOC) | 2h | T0.4 | 3 | 2 |
| T2.22 | `test/unit/features/safety/domain/services/content_filter_service_test.dart` | content_filter_service.dart (60 LOC) | 2h | T0.4 | 3 | 2 |
| T2.23 | `test/unit/features/safety/domain/services/report_service_test.dart` | report_service.dart (88 LOC) | 2h | T0.4 | 3 | 2 |
| T2.24 | `test/unit/features/safety/domain/services/tos_service_test.dart` | tos_service.dart (44 LOC) | 1h | T0.4 | 2 | 2 |

**Fase 2 riepilogo:**

| Metrica | Valore |
|---------|--------|
| Task totali | 24 (T2.1 → T2.24) |
| Tutti parallelizzabili | Si (dopo mocks + fixtures) |
| Ore stimate | ~43h |
| Happy path | ~65 |
| Edge cases | ~53 |

---

## Fase 3: Data Layer - Repositories & Datasources

### Gruppo 3.A: Events Repositories [P]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T3.1 | `test/unit/features/events/data/repositories/event_repository_test.dart` | event_repository.dart (308 LOC) | 4h | T0.4, T0.5 | 5 | 4 | 2 |
| T3.2 | `test/unit/features/events/data/repositories/events_repository_test.dart` | events_repository.dart (472 LOC) | 4h | T0.4, T0.5 | 6 | 5 | 3 |
| T3.3 | `test/unit/features/events/data/repositories/offline_queue_repository_test.dart` | offline_queue_repository.dart (249 LOC) | 4h | T0.4, T0.5 | 4 | 4 | 4 |
| T3.4 | `test/unit/features/events/data/repositories/notification_repository_test.dart` | notification_repository.dart (122 LOC) | 2h | T0.4, T0.5 | 3 | 2 | 1 |

### Gruppo 3.B: Events Datasources [P con 3.A]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T3.5 | `test/unit/features/events/data/datasources/event_remote_datasource_test.dart` | event_remote_datasource.dart (293 LOC) | 3h | T0.5 | 4 | 4 | 1 |
| T3.6 | `test/unit/features/events/data/datasources/event_local_datasource_test.dart` | event_local_datasource.dart (132 LOC) | 2h | T0.5 | 3 | 2 | - |
| T3.7 | `test/unit/features/events/data/services/nominatim_service_test.dart` | nominatim_service.dart (151 LOC) | 2h | T0.5 | 3 | 3 | - |

### Gruppo 3.C: Chat Repository & Datasources [P con 3.A, 3.B]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T3.8 | `test/unit/features/chat/data/repositories/chat_repository_impl_test.dart` | chat_repository_impl.dart (439 LOC) | 4h | T0.4, T0.5 | 5 | 4 | 3 |
| T3.9 | `test/unit/features/chat/data/datasources/chat_remote_datasource_test.dart` | chat_remote_datasource.dart (597 LOC) | 4h | T0.5 | 5 | 5 | 2 |
| T3.10 | `test/unit/features/chat/data/datasources/chat_local_datasource_test.dart` | chat_local_datasource.dart (276 LOC) | 3h | T0.5 | 4 | 3 | - |

### Gruppo 3.D: Comments Repository & Datasources [P con 3.A-3.C]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T3.11 | `test/unit/features/comments/data/repositories/comments_repository_test.dart` | comments_repository.dart (498 LOC) | 4h | T0.4, T0.5 | 5 | 5 | 3 |
| T3.12 | `test/unit/features/comments/data/datasources/comments_remote_datasource_test.dart` | comments_remote_datasource.dart (1006 LOC) | 4h | T0.5 | 6 | 5 | 2 |
| T3.13 | `test/unit/features/comments/data/datasources/comments_local_datasource_test.dart` | comments_local_datasource.dart (354 LOC) | 3h | T0.5 | 4 | 3 | - |

### Gruppo 3.E: Profile Repository & Datasources [P con 3.A-3.D]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T3.14 | `test/unit/features/profile/data/repositories/profile_repository_test.dart` | profile_repository.dart (341 LOC) | 4h | T0.4, T0.5 | 5 | 4 | 2 |
| T3.15 | `test/unit/features/profile/data/datasources/profile_remote_datasource_test.dart` | profile_remote_datasource.dart (326 LOC) | 3h | T0.5 | 4 | 4 | - |
| T3.16 | `test/unit/features/profile/data/datasources/profile_local_datasource_test.dart` | profile_local_datasource.dart (100 LOC) | 2h | T0.5 | 3 | 2 | - |
| T3.17 | `test/unit/features/profile/data/services/avatar_upload_service_test.dart` | avatar_upload_service.dart (227 LOC) | 3h | T0.5 | 3 | 3 | - |

### Gruppo 3.F: Other Repositories [P con 3.A-3.E]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T3.18 | `test/unit/features/notifications/data/repositories/push_repository_test.dart` | push_repository.dart (58 LOC) | 1h | T0.4, T0.5 | 2 | 2 | - |
| T3.19 | `test/unit/features/search/data/repositories/search_repository_test.dart` | search_repository.dart (267 LOC) | 3h | T0.4, T0.5 | 4 | 3 | 1 |
| T3.20 | `test/unit/features/admin/data/repositories/admin_repository_test.dart` | admin_repository.dart (281 LOC) | 3h | T0.4, T0.5 | 4 | 3 | - |
| T3.21 | `test/unit/features/safety/data/repositories/block_repository_test.dart` | block_repository.dart (152 LOC) | 2h | T0.4, T0.5 | 3 | 2 | - |
| T3.22 | `test/unit/features/safety/data/repositories/report_repository_test.dart` | report_repository.dart (125 LOC) | 2h | T0.4, T0.5 | 3 | 2 | - |
| T3.23 | `test/unit/features/safety/data/repositories/content_filter_repository_test.dart` | content_filter_repository.dart (126 LOC) | 2h | T0.4, T0.5 | 3 | 2 | - |
| T3.24 | `test/unit/features/safety/data/repositories/tos_repository_test.dart` | tos_repository.dart (61 LOC) | 1h | T0.4, T0.5 | 2 | 2 | - |
| T3.25 | `test/unit/features/tutoring/data/repositories/tutor_repository_test.dart` | tutor_repository.dart (187 LOC) | 2h | T0.4, T0.5 | 3 | 3 | - |
| T3.26 | `test/unit/features/auth/data/repositories/auth_repository_test.dart` | auth_repository.dart (416 LOC) | 4h | T0.4, T0.5 | 5 | 4 | 2 |

**Fase 3 riepilogo:**

| Metrica | Valore |
|---------|--------|
| Task totali | 26 (T3.1 → T3.26) |
| Tutti parallelizzabili | Si (dopo mocks) |
| Ore stimate | ~75h |
| Happy path | 101 |
| Edge cases | 85 |
| Race conditions | 26 |

---

## Fase 4: Core Module

### Gruppo 4.A: Core Providers [P]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T4.1 | Espandere `test/unit/core/core_providers_test.dart` (aggiungere edge cases) | core_providers.dart (125 LOC) | 1h | - | 2 | 4 | - |
| T4.2 | `test/unit/core/models/auth_state_test.dart` | auth_state.dart (203 LOC) | 2h | T0.5 | 3 | 3 | 2 |

### Gruppo 4.B: Core Services [P con 4.A]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T4.3 | `test/unit/core/services/error_handler_service_test.dart` | error_handler_service.dart (334 LOC) | 3h | T0.6 | 4 | 4 | - |
| T4.4 | `test/unit/core/services/share_service_test.dart` | share_service.dart (227 LOC) | 2h | T0.6 | 3 | 3 | - |
| T4.5 | `test/unit/core/services/push_notification_service_test.dart` | push_notification_service.dart (428 LOC) | 4h | T0.6 | 5 | 4 | 3 |
| T4.6 | `test/unit/core/services/notification_service_test.dart` | notification_service.dart (210 LOC) | 2h | T0.6 | 3 | 3 | - |
| T4.7 | `test/unit/core/services/deep_link_service_test.dart` | deep_link_service.dart (85 LOC) | 1h | T0.6 | 2 | 2 | - |

### Gruppo 4.C: Core Utils [P con 4.A, 4.B]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T4.8 | `test/unit/core/utils/validators_test.dart` | validators.dart (172 LOC) | 2h | - | 4 | 5 | - |
| T4.9 | `test/unit/core/utils/email_validator_test.dart` | email_validator.dart (122 LOC) | 2h | - | 3 | 4 | - |
| T4.10 | `test/unit/core/utils/avatar_initials_generator_test.dart` | avatar_initials_generator.dart (85 LOC) | 1h | - | 2 | 3 | - |
| T4.11 | `test/unit/core/utils/deep_link_handler_test.dart` | deep_link_handler.dart (140 LOC) | 2h | - | 3 | 2 | 1 |
| T4.12 | `test/unit/core/utils/image_compressor_test.dart` | image_compressor.dart (174 LOC) | 2h | - | 3 | 2 | - |
| T4.13 | `test/unit/core/utils/image_orientation_fixer_test.dart` | image_orientation_fixer.dart (116 LOC) | 1h | - | 2 | 2 | - |

### Gruppo 4.D: Core Exceptions & Enums [P con 4.A-4.C]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T4.14 | `test/unit/core/exceptions/nova_exceptions_test.dart` | nova_exceptions.dart (478 LOC) | 3h | - | 5 | 4 | - |
| T4.15 | `test/unit/core/enums/user_role_test.dart` | user_role.dart (56 LOC) | 1h | - | 2 | 2 | - |
| T4.16 | `test/unit/core/extensions/async_value_extensions_test.dart` | async_value_extensions.dart (323 LOC) | 3h | - | 4 | 3 | 2 |

### Gruppo 4.E: Core Config [P]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T4.17 | `test/unit/core/config/supabase_config_test.dart` | supabase_config.dart (113 LOC) | 1h | - | 2 | 2 | - |
| T4.18 | `test/unit/core/constants/classes_test.dart` | classes.dart (325 LOC) | 2h | - | 3 | 2 | - |

**Fase 4 riepilogo:**

| Metrica | Valore |
|---------|--------|
| Task totali | 18 (T4.1 → T4.18) |
| Tutti parallelizzabili | Si (utils/config non hanno dipendenze) |
| Ore stimate | ~35h |
| Happy path | 55 |
| Edge cases | 54 |
| Race conditions | 8 |

---

## Fase 5: Presentation Layer - Providers

### Gruppo 5.A: Events Providers [P]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T5.1 | `test/unit/features/events/presentation/providers/events_feed_provider_test.dart` | events_feed_provider.dart (278 LOC) | 4h | T0.3, T0.4 | 4 | 3 | 3 |
| T5.2 | `test/unit/features/events/presentation/providers/event_creation_provider_test.dart` | event_creation_provider.dart (666 LOC) | 4h | T0.3, T0.4 | 5 | 4 | 2 |
| T5.3 | `test/unit/features/events/presentation/providers/event_engagement_provider_test.dart` | event_engagement_provider.dart (159 LOC) | 2h | T0.3, T0.4 | 3 | 2 | 1 |
| T5.4 | `test/unit/features/events/presentation/providers/event_help_provider_test.dart` | event_help_provider.dart (407 LOC) | 4h | T0.3, T0.4 | 4 | 3 | 2 |
| T5.5 | `test/unit/features/events/presentation/providers/event_likes_notifier_test.dart` | event_likes_notifier.dart (137 LOC) | 2h | T0.3, T0.4 | 3 | 2 | 2 |
| T5.6 | `test/unit/features/events/presentation/providers/moderation_queue_provider_test.dart` | moderation_queue_provider.dart (155 LOC) | 2h | T0.3, T0.4 | 3 | 2 | 1 |

### Gruppo 5.B: Chat Providers [P con 5.A]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T5.7 | `test/unit/features/chat/presentation/providers/chat_providers_test.dart` | chat_providers.dart (552 LOC) | 4h | T0.3, T0.4 | 5 | 4 | 3 |
| T5.8 | `test/unit/features/chat/presentation/providers/chat_realtime_provider_test.dart` | chat_realtime_provider.dart (390 LOC) | 4h | T0.3, T0.4 | 4 | 3 | 4 |
| T5.9 | `test/unit/features/chat/presentation/providers/typing_indicator_provider_test.dart` | typing_indicator_provider.dart (221 LOC) | 3h | T0.3, T0.4 | 3 | 2 | 3 |

### Gruppo 5.C: Comments Providers [P con 5.A, 5.B]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T5.10 | `test/unit/features/comments/presentation/providers/comments_notifier_test.dart` | comments_notifier.dart (381 LOC) | 4h | T0.3, T0.4 | 4 | 3 | 3 |
| T5.11 | `test/unit/features/comments/presentation/providers/comment_likes_notifier_test.dart` | comment_likes_notifier.dart (219 LOC) | 3h | T0.3, T0.4 | 3 | 2 | 2 |
| T5.12 | `test/unit/features/comments/presentation/providers/realtime_comments_provider_test.dart` | realtime_comments_provider.dart (220 LOC) | 3h | T0.3, T0.4 | 3 | 2 | 4 |
| T5.13 | `test/unit/features/comments/presentation/providers/comment_input_notifier_test.dart` | comment_input_notifier.dart (317 LOC) | 3h | T0.3, T0.4 | 4 | 3 | - |
| T5.14 | `test/unit/features/comments/presentation/providers/edit_comment_provider_test.dart` | edit_comment_provider.dart (228 LOC) | 3h | T0.3, T0.4 | 3 | 3 | 2 |

### Gruppo 5.D: Profile Providers [P con 5.A-5.C]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T5.15 | `test/unit/features/profile/presentation/providers/profile_provider_test.dart` | profile_provider.dart (354 LOC) | 4h | T0.3, T0.4 | 4 | 3 | 2 |
| T5.16 | `test/unit/features/profile/presentation/providers/gdpr_export_provider_test.dart` | gdpr_export_provider.dart (258 LOC) | 3h | T0.3, T0.4 | 3 | 3 | - |
| T5.17 | `test/unit/features/profile/presentation/providers/connectivity_provider_test.dart` | connectivity_provider.dart (114 LOC) | 2h | T0.3, T0.4 | 2 | 2 | 2 |

### Gruppo 5.E: Other Feature Providers [P con 5.A-5.D]

| ID | Task | File sorgente | Durata | Dipendenze | H | E | R |
|----|------|--------------|--------|------------|---|---|---|
| T5.18 | `test/unit/features/search/presentation/providers/search_provider_test.dart` | search_provider.dart (240 LOC) | 3h | T0.3, T0.4 | 3 | 3 | 3 |
| T5.19 | `test/unit/features/notifications/presentation/providers/push_providers_test.dart` | push_providers.dart (328 LOC) | 3h | T0.3, T0.4 | 4 | 3 | 2 |
| T5.20 | `test/unit/features/notifications/presentation/providers/notification_providers_test.dart` | notification_providers.dart (384 LOC) | 3h | T0.3, T0.4 | 4 | 3 | 1 |
| T5.21 | `test/unit/features/safety/presentation/providers/block_provider_test.dart` | block_provider.dart (175 LOC) | 2h | T0.3, T0.4 | 3 | 2 | - |
| T5.22 | `test/unit/features/safety/presentation/providers/report_provider_test.dart` | report_provider.dart (113 LOC) | 2h | T0.3, T0.4 | 2 | 2 | - |
| T5.23 | `test/unit/features/tutoring/presentation/providers/tutor_providers_test.dart` | tutor_providers.dart (394 LOC) | 3h | T0.3, T0.4 | 4 | 3 | 1 |

**Fase 5 riepilogo:**

| Metrica | Valore |
|---------|--------|
| Task totali | 23 (T5.1 → T5.23) |
| Tutti parallelizzabili | Si (dopo helper + mocks) |
| Ore stimate | ~70h |
| Happy path | 80 |
| Edge cases | 62 |
| Race conditions | 43 |

---

## Fase 6: Widget Tests

### Gruppo 6.A: Shared Widgets [P]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T6.1 | `test/widget/shared/widgets/adaptive/adaptive_dialog_test.dart` | adaptive_dialog.dart | 2h | T0.2 | 3 | 2 |
| T6.2 | `test/widget/shared/widgets/adaptive/adaptive_bottom_sheet_test.dart` | adaptive_bottom_sheet.dart | 2h | T0.2 | 3 | 2 |
| T6.3 | `test/widget/shared/widgets/adaptive/adaptive_card_test.dart` | adaptive_card.dart | 1h | T0.2 | 2 | 2 |
| T6.4 | `test/widget/shared/widgets/nova_tabs_test.dart` | nova_tabs.dart | 2h | T0.2 | 3 | 2 |

### Gruppo 6.B: Events Widgets [P con 6.A]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T6.5 | `test/widget/features/events/event_card_test.dart` | event_card.dart (1591 LOC) | 4h | T0.2, T0.7 | 6 | 5 |
| T6.6 | `test/widget/features/events/event_status_badge_test.dart` | event_status_badge.dart (97 LOC) | 1h | T0.2 | 2 | 2 |
| T6.7 | `test/widget/features/events/participant_avatars_test.dart` | participant_avatars.dart (166 LOC) | 2h | T0.2 | 3 | 3 |
| T6.8 | `test/widget/features/events/offline_banner_test.dart` | offline_banner.dart (199 LOC) | 2h | T0.2 | 2 | 2 |
| T6.9 | `test/widget/features/events/pending_event_banner_test.dart` | pending_event_banner.dart (147 LOC) | 1h | T0.2 | 2 | 2 |

### Gruppo 6.C: Comments Widgets [P con 6.A, 6.B]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T6.10 | `test/widget/features/comments/comment_card_test.dart` | comment_card.dart (592 LOC) | 4h | T0.2, T0.10 | 5 | 4 |
| T6.11 | `test/widget/features/comments/like_button_test.dart` | like_button.dart (205 LOC) | 2h | T0.2 | 3 | 3 |
| T6.12 | `test/widget/features/comments/comment_sort_toggle_test.dart` | comment_sort_toggle.dart (244 LOC) | 2h | T0.2 | 3 | 2 |
| T6.13 | `test/widget/features/comments/delete_confirmation_dialog_test.dart` | delete_confirmation_dialog.dart (158 LOC) | 1h | T0.2 | 2 | 2 |
| T6.14 | `test/widget/features/comments/realtime_status_banner_test.dart` | realtime_status_banner.dart (161 LOC) | 2h | T0.2 | 2 | 2 |
| T6.15 | `test/widget/features/comments/empty_comments_state_test.dart` | empty_comments_state.dart (68 LOC) | 1h | T0.2 | 2 | 1 |

### Gruppo 6.D: Profile Widgets [P con 6.A-6.C]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T6.16 | `test/widget/features/profile/avatar_initials_test.dart` | avatar_initials.dart (53 LOC) | 1h | T0.2 | 2 | 2 |
| T6.17 | `test/widget/features/profile/incomplete_profile_banner_test.dart` | incomplete_profile_banner.dart (111 LOC) | 1h | T0.2 | 2 | 2 |
| T6.18 | `test/widget/features/profile/profile_header_test.dart` | profile_header.dart (344 LOC) | 3h | T0.2, T0.8 | 4 | 3 |
| T6.19 | `test/widget/features/profile/profile_stats_widget_test.dart` | profile_stats.dart (102 LOC) | 1h | T0.2 | 2 | 2 |

### Gruppo 6.E: Chat Widgets [P con 6.A-6.D]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T6.20 | `test/widget/features/chat/chat_typing_indicator_test.dart` | chat_typing_indicator.dart (56 LOC) | 1h | T0.2 | 2 | 1 |
| T6.21 | `test/widget/features/chat/chat_message_skeleton_test.dart` | chat_message_skeleton.dart (155 LOC) | 1h | T0.2 | 2 | 2 |
| T6.22 | `test/widget/features/chat/failed_message_tile_test.dart` | failed_message_tile.dart (204 LOC) | 2h | T0.2 | 3 | 2 |

### Gruppo 6.F: Notification & Safety Widgets [P con 6.A-6.E]

| ID | Task | File sorgente | Durata | Dipendenze | H | E |
|----|------|--------------|--------|------------|---|---|
| T6.23 | `test/widget/features/notifications/notification_tile_test.dart` | notification_tile.dart (315 LOC) | 3h | T0.2 | 4 | 3 |
| T6.24 | `test/widget/features/notifications/notification_badge_test.dart` | notification_badge.dart (136 LOC) | 1h | T0.2 | 2 | 2 |
| T6.25 | `test/widget/features/safety/content_warning_banner_test.dart` | content_warning_banner.dart (226 LOC) | 2h | T0.2 | 3 | 2 |

**Fase 6 riepilogo:**

| Metrica | Valore |
|---------|--------|
| Task totali | 25 (T6.1 → T6.25) |
| Tutti parallelizzabili | Si (dopo pump_app helper) |
| Ore stimate | ~45h |
| Happy path | 69 |
| Edge cases | 57 |

---

## Riepilogo Globale

### Totale Task per Fase

| Fase | Task | Ore | H | E | R | Totale Test |
|------|------|-----|---|---|---|-------------|
| 0: Setup | 11 | 13h | - | - | - | - |
| 1: Entities/Models | 54 | 90h | 149 | 143 | - | 292 |
| 2: Use Cases | 24 | 43h | 65 | 53 | - | 118 |
| 3: Repositories | 26 | 75h | 101 | 85 | 26 | 212 |
| 4: Core | 18 | 35h | 55 | 54 | 8 | 117 |
| 5: Providers | 23 | 70h | 80 | 62 | 43 | 185 |
| 6: Widgets | 25 | 45h | 69 | 57 | - | 126 |
| **Totale** | **181** | **371h** | **519** | **454** | **77** | **1050** |

### Grafo Dipendenze (Fasi)

```
T0.1 (deps)
├── T0.2 (pump_app)        ──────────────────────────→ Fase 6 (widgets)
├── T0.3 (provider_container) ────────────────────────→ Fase 5 (providers)
├── T0.4 (mock_repos) ───→ Fase 2 (usecases) ──┐
├── T0.5 (mock_supabase) ─→ Fase 3 (repos)     ├──→ Fase 5 ──→ Fase 6
├── T0.6 (mock_services) ─→ Fase 4 (core)      │
├── T0.7-T0.10 (fixtures) ─→ Fase 1 (entities) ┘
└── T0.11 (CI) ──→ (parallelo a tutto)

Fase 1 ←──────────→ Fase 4 (parallele!)
   ↓                    ↓
Fase 2 ←──────────→ Fase 4 (parallele!)
   ↓                    ↓
Fase 3 ────────────→ Fase 5
                        ↓
                     Fase 6
```

### Massimo Parallelismo Possibile

Con **4 developer** in parallelo:

| Settimana | Dev 1 | Dev 2 | Dev 3 | Dev 4 |
|-----------|-------|-------|-------|-------|
| **1** | T0.1-T0.6 (setup) | T0.7-T0.10 (fixtures) | T0.11 (CI) | - |
| **2** | T1.1-T1.8 (events entities) | T1.17-T1.25 (chat) | T1.26-T1.33 (comments) | T1.34-T1.54 (profile+other) |
| **3** | T1.9-T1.16 (events models) | T2.2-T2.14 (comments UC) | T4.8-T4.18 (core utils) | T2.15-T2.24 (profile+safety UC) |
| **4** | T3.1-T3.7 (events repo) | T3.8-T3.10 (chat repo) | T3.11-T3.13 (comments repo) | T3.14-T3.26 (profile+other repo) |
| **5** | T5.1-T5.6 (events prov) | T5.7-T5.9 (chat prov) | T5.10-T5.14 (comments prov) | T5.15-T5.23 (profile+other prov) |
| **6** | T6.5-T6.9 (events widgets) | T6.20-T6.22 (chat widgets) | T6.10-T6.15 (comments widgets) | T6.16-T6.25 (profile+other widgets) |
| **6** | T4.1-T4.7 (core services) | T6.1-T6.4 (shared widgets) | T2.1 (events UC) | Buffer/rework |

**Con 4 dev: ~6 settimane (era 31 giorni con 1 dev)**

### Con 1 Developer (sequenziale ottimizzato)

| Settimana | Focus | Task |
|-----------|-------|------|
| **1-2** | Setup + Entities (quick wins) | T0.1-T0.11, T1.1-T1.16 |
| **3** | Entities (cont.) + Core utils | T1.17-T1.54, T4.8-T4.18 |
| **4** | Use Cases | T2.1-T2.24 |
| **5-6** | Repositories | T3.1-T3.26 |
| **7** | Core services + Providers (start) | T4.1-T4.7, T5.1-T5.6 |
| **8** | Providers | T5.7-T5.23 |
| **9** | Widgets | T6.1-T6.25 |

---

## Acceptance Criteria per Task

Ogni task e completo quando:

1. **File test creato** nella posizione corretta
2. **Tutti i test passano** (`flutter test <file>`)
3. **Nessun test skippato** (no `skip: true`)
4. **Coverage del file sorgente** verificabile con `--coverage`
5. **Include almeno:**
   - Happy path tests (come da colonna H)
   - Edge case tests (come da colonna E)
   - Race condition tests se indicati (come da colonna R)

---

*Generato il 2026-04-02*
*Task totali: 181 | Test totali stimati: 1050 | Ore totali: 371h*
