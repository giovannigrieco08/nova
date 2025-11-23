// Widget: EventForm
// Feature: 004-event-creation-moderation (US1 - Event Creation)
// Purpose: Complete event creation form with all fields and validation
//
// Fields:
// - Title (5-100 chars, required)
// - Description (20-500 chars, required)
// - Event Date/Time (future dates only, required)
// - Location (optional)
// - Image (optional)
// - Character counters for title and description

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/event_creation_provider.dart';
import './image_picker_widget.dart';
import './user_search_widget.dart';

/// Complete event creation form
class EventForm extends ConsumerStatefulWidget {
  const EventForm({super.key});

  @override
  ConsumerState<EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<EventForm> {
  List<Profile> _selectedCoOrganizers = [];
  bool _isLoadingProfiles = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCoOrganizersFromState();
  }

  /// Sync co-organizers from EventFormState (for draft restore)
  Future<void> _syncCoOrganizersFromState() async {
    final state = ref.read(eventCreationProvider);

    // If state has co-organizer IDs but we don't have profiles yet
    if (state.coOrganizers.isNotEmpty && _selectedCoOrganizers.isEmpty) {
      setState(() => _isLoadingProfiles = true);

      try {
        final repository = ref.read(profileRepositoryProvider);
        final profiles = <Profile>[];

        for (final userId in state.coOrganizers) {
          try {
            final profile = await repository.getProfileById(userId);
            profiles.add(profile);
          } catch (e) {
            // Skip profiles that can't be loaded
            debugPrint('Failed to load profile $userId: $e');
          }
        }

        if (mounted) {
          setState(() {
            _selectedCoOrganizers = profiles;
            _isLoadingProfiles = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingProfiles = false);
        }
      }
    }
  }

  void _onCoOrganizersChanged(List<Profile> profiles) {
    setState(() => _selectedCoOrganizers = profiles);

    // Update EventFormState with user IDs
    final notifier = ref.read(eventCreationProvider.notifier);
    final userIds = profiles.map((p) => p.id).toList();

    // Clear existing co-organizers
    final currentIds = ref.read(eventCreationProvider).coOrganizers;
    for (final id in currentIds) {
      notifier.removeCoOrganizer(id);
    }

    // Add new co-organizers
    for (final id in userIds) {
      notifier.addCoOrganizer(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventCreationProvider);
    final notifier = ref.read(eventCreationProvider.notifier);

    return SingleChildScrollView(
      padding: EdgeInsets.all(NovaSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title field
          _buildTitleField(context, state, notifier),
          SizedBox(height: NovaSpacing.l),

          // Description field
          _buildDescriptionField(context, state, notifier),
          SizedBox(height: NovaSpacing.l),

          // Date/Time picker
          _buildDateTimePicker(context, state, notifier),
          SizedBox(height: NovaSpacing.l),

          // Location field (optional)
          _buildLocationField(context, state, notifier),
          SizedBox(height: NovaSpacing.l),

          // Image picker
          ImagePickerWidget(
            imageFile: state.imageFile,
            imagePath: state.imagePath,
            onImagePicked: (file) => notifier.pickImage(file),
            onImageRemoved: () => notifier.removeImage(),
          ),
          SizedBox(height: NovaSpacing.l),

          // Co-organizers section
          _buildCoOrganizersSection(context),
          SizedBox(height: NovaSpacing.l),

          // Info text
          _buildInfoText(context),
        ],
      ),
    );
  }

  /// Title field with character counter and validation
  Widget _buildTitleField(
    BuildContext context,
    EventFormState state,
    EventCreationNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Titolo *',
              style: NovaTextStyles.body,
            ),
            Text(
              state.titleCharCount,
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
        SizedBox(height: NovaSpacing.s),
        TextField(
          onChanged: notifier.updateTitle,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: 'Es: Torneo di Calcetto 5vs5',
            errorText: state.titleError,
            counterText: '', // Hide default counter (using custom)
            filled: true,
            fillColor: NovaColors.surface(context),
            border: OutlineInputBorder(
              borderRadius: NovaRadius.circularM,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: NovaRadius.circularM,
              borderSide: BorderSide(color: NovaColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: NovaRadius.circularM,
              borderSide: BorderSide(color: NovaColors.primary(context), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: NovaRadius.circularM,
              borderSide: BorderSide(color: NovaColors.error(context)),
            ),
          ),
          style: NovaTextStyles.body,
        ),
      ],
    );
  }

  /// Description field with character counter and validation
  Widget _buildDescriptionField(
    BuildContext context,
    EventFormState state,
    EventCreationNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Descrizione *',
              style: NovaTextStyles.body,
            ),
            Text(
              state.descriptionCharCount,
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
        SizedBox(height: NovaSpacing.s),
        TextField(
          onChanged: notifier.updateDescription,
          maxLength: 500,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Descrivi l\'evento, luogo di ritrovo, costi, ecc...',
            errorText: state.descriptionError,
            counterText: '', // Hide default counter
            filled: true,
            fillColor: NovaColors.surface(context),
            border: OutlineInputBorder(
              borderRadius: NovaRadius.circularM,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: NovaRadius.circularM,
              borderSide: BorderSide(color: NovaColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: NovaRadius.circularM,
              borderSide: BorderSide(color: NovaColors.primary(context), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: NovaRadius.circularM,
              borderSide: BorderSide(color: NovaColors.error(context)),
            ),
          ),
          style: NovaTextStyles.body,
        ),
      ],
    );
  }

  /// Date/Time picker
  Widget _buildDateTimePicker(
    BuildContext context,
    EventFormState state,
    EventCreationNotifier notifier,
  ) {
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final displayText = state.eventDate != null
        ? dateFormatter.format(state.eventDate!)
        : 'Seleziona data e ora';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data e Ora *',
          style: NovaTextStyles.body,
        ),
        SizedBox(height: NovaSpacing.s),
        InkWell(
          onTap: () => _showDateTimePicker(context, state, notifier),
          borderRadius: NovaRadius.circularM,
          child: Container(
            padding: EdgeInsets.all(NovaSpacing.m),
            decoration: BoxDecoration(
              color: NovaColors.surface(context),
              borderRadius: NovaRadius.circularM,
              border: Border.all(
                color: state.eventDateError != null
                    ? NovaColors.error(context)
                    : NovaColors.border(context),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: state.eventDate != null
                      ? NovaColors.textPrimary(context)
                      : NovaColors.textSecondary(context),
                ),
                SizedBox(width: NovaSpacing.m),
                Text(
                  displayText,
                  style: NovaTextStyles.body.copyWith(
                    color: state.eventDate != null
                        ? NovaColors.textPrimary(context)
                        : NovaColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.eventDateError != null) ...[
          SizedBox(height: NovaSpacing.xs),
          Text(
            state.eventDateError!,
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.error(context),
            ),
          ),
        ],
      ],
    );
  }

  /// Location field (optional)
  Widget _buildLocationField(
    BuildContext context,
    EventFormState state,
    EventCreationNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Luogo (Opzionale)',
          style: NovaTextStyles.body,
        ),
        SizedBox(height: NovaSpacing.s),
        TextField(
          onChanged: (value) => notifier.updateLocation(
            value.isEmpty ? null : value,
          ),
          decoration: InputDecoration(
            hintText: 'Es: Campo sportivo del liceo',
            filled: true,
            fillColor: NovaColors.surface(context),
            border: OutlineInputBorder(
              borderRadius: NovaRadius.circularM,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: NovaRadius.circularM,
              borderSide: BorderSide(color: NovaColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: NovaRadius.circularM,
              borderSide: BorderSide(color: NovaColors.primary(context), width: 2),
            ),
          ),
          style: NovaTextStyles.body,
        ),
      ],
    );
  }

  /// Co-organizers section (optional)
  Widget _buildCoOrganizersSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Co-Organizzatori (Opzionale)',
          style: NovaTextStyles.body,
        ),
        SizedBox(height: NovaSpacing.xs),
        Text(
          'Aggiungi fino a 3 co-organizzatori che potranno modificare l\'evento',
          style: NovaTextStyles.caption.copyWith(
            color: NovaColors.textSecondary(context),
          ),
        ),
        SizedBox(height: NovaSpacing.s),
        if (_isLoadingProfiles)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(NovaSpacing.m),
              child: CircularProgressIndicator(),
            ),
          )
        else
          UserSearchWidget(
            selectedUsers: _selectedCoOrganizers,
            onSelectionChanged: _onCoOrganizersChanged,
            maxSelections: 3,
          ),
      ],
    );
  }

  /// Info text at bottom
  Widget _buildInfoText(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.m),
      decoration: BoxDecoration(
        color: NovaColors.primary(context).withOpacity(0.1),
        borderRadius: NovaRadius.circularM,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: NovaColors.primary(context),
          ),
          SizedBox(width: NovaSpacing.s),
          Expanded(
            child: Text(
              'Il tuo evento sarà visibile dopo l\'approvazione del moderatore. '
              'La bozza viene salvata automaticamente.',
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show date and time picker
  Future<void> _showDateTimePicker(
    BuildContext context,
    EventFormState state,
    EventCreationNotifier notifier,
  ) async {
    // Pick date
    final date = await showDatePicker(
      context: context,
      initialDate: state.eventDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: NovaColors.primary(context),
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null) return;

    // Pick time
    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        state.eventDate ?? DateTime.now().add(const Duration(hours: 1)),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: NovaColors.primary(context),
            ),
          ),
          child: child!,
        );
      },
    );

    if (time == null) return;

    // Combine date and time
    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    notifier.updateEventDate(dateTime);
  }
}
