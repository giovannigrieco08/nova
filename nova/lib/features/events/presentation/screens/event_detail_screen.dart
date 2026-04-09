// Screen: EventDetailScreen
// Feature: 004-event-creation-moderation (Phase 6 - Event Sharing)
// Purpose: Display full event details with Instagram-style layout
//
// Design: Instagram-style consistent with EventCard
// - 1:1 hero image with double-tap like
// - Actions row (like, comment, share)
// - Inline caption style
// - Participate button with count
// - Meta info with icons

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/animations/page_transitions.dart';
import '../providers/event_detail_provider.dart';
import '../providers/events_feed_provider.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_status.dart';
import '../../../comments/presentation/screens/comments_sheet.dart';
import '../../../profile/presentation/screens/other_profile_screen.dart';
import 'event_detail_body.dart';
import 'event_detail_sheets.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  /// Event ID to display.
  /// - If null, expects Event object passed via route arguments.
  /// - If provided, fetches event by ID (deep link navigation).
  final String? eventId;

  const EventDetailScreen({super.key, this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  // Engagement state
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLikeLoading = false;
  bool _isParticipating = false;
  bool _isParticipateLoading = false;
  int _participantCount = 0;
  int _commentCount = 0;

  Event? _event;
  bool _stateInitialized = false;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  void _initializeState(Event event) {
    if (!_stateInitialized) {
      _event = event;
      _likeCount = 0;
      _commentCount = 0;
      _participantCount = 0;
      _isLiked = false;
      _isParticipating = false;
      _stateInitialized = true;
      _loadEngagementState(event.id);
    }
  }

  Future<void> _loadEngagementState(String eventId) async {
    final userId = ref.read(currentUserIdProvider);
    final repository = ref.read(eventsRepositoryProvider);

    try {
      final results = await Future.wait([
        repository.getParticipationCount(eventId),
        repository.getLikeCount(eventId),
        if (userId.isNotEmpty)
          repository.isUserParticipating(eventId: eventId, userId: userId)
        else
          Future.value(false),
        if (userId.isNotEmpty)
          repository.hasUserLikedEvent(eventId: eventId, userId: userId)
        else
          Future.value(false),
      ]);

      if (mounted) {
        setState(() {
          _participantCount = (results[0] as int?) ?? 0;
          _likeCount = (results[1] as int?) ?? 0;
          _isParticipating = (results[2] as bool?) ?? false;
          _isLiked = (results[3] as bool?) ?? false;
        });
      }
    } catch (e) {
      debugPrint('[EventDetail] Failed to load engagement state: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);

    if (widget.eventId != null) {
      final eventAsync = ref.watch(eventDetailProvider(widget.eventId!));

      return eventAsync.when(
        data: (event) {
          if (event == null) {
            return _scaffold(
              body: _buildErrorState(context, 'Evento non trovato',
                  'Questo evento non esiste o è stato eliminato.'),
            );
          }
          if (event.status == EventStatus.pending &&
              event.creatorId != currentUserId) {
            return _scaffold(
              body: _buildErrorState(context, 'Evento in attesa',
                  'Questo evento è in attesa di moderazione.'),
            );
          }
          if (event.status == EventStatus.rejected &&
              event.creatorId != currentUserId) {
            return _scaffold(
              body: _buildErrorState(context, 'Evento non disponibile',
                  'Questo evento non è disponibile.'),
            );
          }

          _initializeState(event);
          return _scaffold(body: _buildBody(event, currentUserId));
        },
        loading: () => Scaffold(
          backgroundColor: NovaColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: NovaColors.backgroundLight,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new,
                  color: NovaColors.textPrimaryLight, size: 24),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Indietro',
            ),
          ),
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                NovaColors.primary(context),
              ),
            ),
          ),
        ),
        error: (error, stack) => _scaffold(
          body: _buildErrorState(
            context,
            'Errore',
            'Impossibile caricare l\'evento: $error',
          ),
        ),
      );
    }

    final event = ModalRoute.of(context)!.settings.arguments as Event;
    _initializeState(event);
    return _scaffold(body: _buildBody(event, currentUserId));
  }

  Scaffold _scaffold({required Widget body}) {
    return Scaffold(
      backgroundColor: NovaColors.backgroundLight,
      appBar: _buildAppBar(),
      body: body,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: NovaColors.backgroundLight,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new,
            color: NovaColors.textPrimaryLight, size: 24),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Indietro',
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_vert, color: NovaColors.textPrimaryLight),
          onPressed: () => _showMenu(),
          tooltip: 'Altre opzioni',
        ),
      ],
    );
  }

  Widget _buildBody(Event event, String? currentUserId) {
    return EventDetailBody(
      event: event,
      currentUserId: currentUserId,
      isLiked: _isLiked,
      likeCount: _likeCount,
      commentCount: _commentCount,
      isParticipating: _isParticipating,
      participantCount: _participantCount,
      isParticipateLoading: _isParticipateLoading,
      onDoubleTapLike: _handleDoubleTapLike,
      onLike: _handleLike,
      onComment: () => _openCommentsSheet(event),
      onParticipateToggle: _handleParticipateToggle,
      onShowParticipants: () => showDetailParticipantsSheet(context),
      onNavigateToOrganizer: (e) =>
          () => _navigateToOrganizerProfile(e),
    );
  }

  // ---------------------------------------------------------------------------
  // Interaction handlers
  // ---------------------------------------------------------------------------

  void _handleDoubleTapLike() async {
    if (_isLiked || _isLikeLoading) return;

    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    HapticFeedback.mediumImpact();
    final previousCount = _likeCount;

    setState(() {
      _isLiked = true;
      _likeCount = _likeCount + 1;
      _isLikeLoading = true;
    });

    try {
      await ref
          .read(eventsRepositoryProvider)
          .likeEvent(eventId: _event!.id, userId: userId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = false;
          _likeCount = previousCount;
        });
      }
    } finally {
      if (mounted) setState(() => _isLikeLoading = false);
    }
  }

  void _handleLike() async {
    if (_isLikeLoading) return;

    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    HapticFeedback.lightImpact();
    final wasLiked = _isLiked;
    final previousCount = _likeCount;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
      _isLikeLoading = true;
    });

    try {
      final repository = ref.read(eventsRepositoryProvider);
      if (_isLiked) {
        await repository.likeEvent(eventId: _event!.id, userId: userId);
      } else {
        await repository.unlikeEvent(eventId: _event!.id, userId: userId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = previousCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante l\'operazione')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLikeLoading = false);
    }
  }

  void _handleParticipateToggle() async {
    if (_isParticipateLoading) return;

    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    HapticFeedback.mediumImpact();
    final wasParticipating = _isParticipating;

    setState(() {
      _isParticipating = !wasParticipating;
      _participantCount = wasParticipating
          ? (_participantCount > 0 ? _participantCount - 1 : 0)
          : _participantCount + 1;
      _isParticipateLoading = true;
    });

    try {
      final repository = ref.read(eventsRepositoryProvider);
      if (wasParticipating) {
        await repository.unparticipateFromEvent(
            eventId: _event!.id, userId: userId);
      } else {
        await repository.participateInEvent(
            eventId: _event!.id, userId: userId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isParticipating = wasParticipating;
          _participantCount = wasParticipating
              ? _participantCount + 1
              : (_participantCount > 0 ? _participantCount - 1 : 0);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(wasParticipating
                  ? 'Errore durante l\'annullamento'
                  : 'Errore durante la partecipazione')),
        );
      }
    } finally {
      if (mounted) setState(() => _isParticipateLoading = false);
    }
  }

  void _openCommentsSheet(Event event) {
    showCommentsSheet(
      context: context,
      eventId: event.id,
      eventTitle: event.title,
    );
  }

  void _navigateToOrganizerProfile(Event event) {
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(
          page: OtherProfileScreen(userId: event.creatorId)),
    );
  }

  // ---------------------------------------------------------------------------
  // Menu / delete
  // ---------------------------------------------------------------------------

  bool _canEditEvent(Event event) {
    final difference = DateTime.now().difference(event.createdAt);
    return difference.inMinutes < 30;
  }

  void _showMenu() {
    final event = _event;
    if (event == null) return;

    final currentUserId = ref.read(currentUserIdProvider);
    final isOwner = event.creatorId == currentUserId;

    showDetailMenuSheet(
      context: context,
      ref: ref,
      event: event,
      isOwner: isOwner,
      canEdit: isOwner && _canEditEvent(event),
      onDelete: () => _confirmDelete(event),
      onReport: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Funzionalità di segnalazione in arrivo')),
        );
      },
      onEdited: (result) {
        if (result != null && mounted) {
          ref.invalidate(eventDetailProvider(event.id));
          setState(() {
            _event = result;
            _stateInitialized = false;
          });
        }
      },
    );
  }

  void _confirmDelete(Event event) async {
    final deleted = await confirmDeleteEvent(
      context: context,
      ref: ref,
      event: event,
    );
    if (deleted && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento eliminato')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------------

  Widget _buildErrorState(
      BuildContext context, String title, String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: NovaColors.textSecondary(context)),
            SizedBox(height: NovaSpacing.m),
            Text(
              title,
              style: NovaTextStyles.h2
                  .copyWith(color: NovaColors.textPrimary(context)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.s),
            Text(
              message,
              style: NovaTextStyles.body
                  .copyWith(color: NovaColors.textSecondary(context)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.l),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.primary(context),
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.l,
                  vertical: NovaSpacing.m,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NovaRadius.s),
                ),
              ),
              child: Text(
                'Torna indietro',
                style: NovaTextStyles.button.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
