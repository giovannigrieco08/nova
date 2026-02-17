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
import '../../../../shared/widgets/adaptive/adaptive_date_picker.dart';
import '../../../../shared/widgets/adaptive/adaptive_time_picker.dart';
import '../providers/event_creation_provider.dart';
import '../../../search/presentation/providers/search_provider.dart';
import '../../../search/domain/entities/search_results.dart';
import './image_picker_widget.dart';
import './location_picker_sheet.dart';
// UGC Safety: Content filter (T073)
import '../../../safety/presentation/providers/content_filter_provider.dart';
import '../../../safety/presentation/widgets/content_warning_banner.dart';

/// Complete event creation form
class EventForm extends ConsumerStatefulWidget {
  const EventForm({super.key});

  @override
  ConsumerState<EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<EventForm> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _syncControllersWithState(EventFormState state) {
    // Sync on first build, draft restore, or form reset
    final shouldSyncTitle = !_initialized ||
        (_titleController.text.isEmpty && state.title.isNotEmpty) ||
        (_titleController.text.isNotEmpty && state.title.isEmpty);
    final shouldSyncDescription = !_initialized ||
        (_descriptionController.text.isEmpty && state.description.isNotEmpty) ||
        (_descriptionController.text.isNotEmpty && state.description.isEmpty);

    if (shouldSyncTitle && _titleController.text != state.title) {
      _titleController.text = state.title;
      if (state.title.isNotEmpty) {
        _titleController.selection =
            TextSelection.collapsed(offset: state.title.length);
      }
    }
    if (shouldSyncDescription &&
        _descriptionController.text != state.description) {
      _descriptionController.text = state.description;
      if (state.description.isNotEmpty) {
        _descriptionController.selection =
            TextSelection.collapsed(offset: state.description.length);
      }
    }
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventCreationProvider);
    final notifier = ref.read(eventCreationProvider.notifier);

    // Sync controllers with state (for draft restoration)
    _syncControllersWithState(state);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image picker (Instagram-style: FIRST and PROMINENT)
            ImagePickerWidget(
              imageFile: state.imageFile,
              imagePath: state.imagePath,
              onImagePicked: (file) => notifier.pickImage(file),
              onImageRemoved: () => notifier.removeImage(),
              errorText: state.imageError,
            ),

            // Form fields with padding
            Padding(
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

                  // Collaborators picker
                  _buildCollaboratorsPicker(context, ref, state, notifier),
                  SizedBox(height: NovaSpacing.l),

                  // Help requests section
                  _buildHelpRequestsSection(context, state, notifier),
                  SizedBox(height: NovaSpacing.l),

                  // UGC Safety: Content warning banner (T073)
                  const ContentWarningBanner(),

                  // Info text
                  _buildInfoText(context),
                ],
              ),
            ),
          ],
        ),
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
              'Titolo',
              style: NovaTextStyles.labelLarge,
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
          controller: _titleController,
          onChanged: (value) {
            notifier.updateTitle(value);
            // UGC Safety: Check content for banned words (T073)
            final combined = '$value ${_descriptionController.text}';
            ref
                .read(contentCheckNotifierProvider.notifier)
                .checkWithDebounce(combined);
          },
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
              borderSide:
                  BorderSide(color: NovaColors.primary(context), width: 2),
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
              'Descrizione',
              style: NovaTextStyles.labelLarge,
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
          controller: _descriptionController,
          onChanged: (value) {
            notifier.updateDescription(value);
            // UGC Safety: Check content for banned words (T073)
            final combined = '${_titleController.text} $value';
            ref
                .read(contentCheckNotifierProvider.notifier)
                .checkWithDebounce(combined);
          },
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
              borderSide:
                  BorderSide(color: NovaColors.primary(context), width: 2),
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
          'Data e Ora',
          style: NovaTextStyles.labelLarge,
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

  /// Location field (optional) with map picker
  Widget _buildLocationField(
    BuildContext context,
    EventFormState state,
    EventCreationNotifier notifier,
  ) {
    final hasLocation = state.location != null && state.location!.isNotEmpty;
    final hasCoordinates = state.hasMapLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Luogo',
              style: NovaTextStyles.labelLarge,
            ),
            if (hasCoordinates)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: NovaColors.success(context).withValues(alpha: 0.1),
                  borderRadius: NovaRadius.circularS,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 12,
                      color: NovaColors.success(context),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Maps',
                      style: NovaTextStyles.caption.copyWith(
                        color: NovaColors.success(context),
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: NovaSpacing.s),
        InkWell(
          onTap: () => _showLocationPicker(context, state, notifier),
          borderRadius: NovaRadius.circularM,
          child: Container(
            padding: EdgeInsets.all(NovaSpacing.m),
            decoration: BoxDecoration(
              color: NovaColors.surface(context),
              borderRadius: NovaRadius.circularM,
              border: Border.all(color: NovaColors.border(context)),
            ),
            child: Row(
              children: [
                Icon(
                  hasLocation ? Icons.place : Icons.add_location_alt_outlined,
                  size: 20,
                  color: hasLocation
                      ? NovaColors.primary(context)
                      : NovaColors.textSecondary(context),
                ),
                SizedBox(width: NovaSpacing.m),
                Expanded(
                  child: Text(
                    hasLocation ? state.location! : 'Cerca un luogo su Maps',
                    style: NovaTextStyles.body.copyWith(
                      color: hasLocation
                          ? NovaColors.textPrimary(context)
                          : NovaColors.textSecondary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasLocation)
                  GestureDetector(
                    onTap: () => notifier.clearLocationAndCoordinates(),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: NovaColors.textSecondary(context),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: NovaColors.textSecondary(context),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Show location picker bottom sheet
  void _showLocationPicker(
    BuildContext context,
    EventFormState state,
    EventCreationNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NovaColors.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => LocationPickerSheet(
        currentLocation: state.location,
        onLocationSelected: (result) {
          notifier.updateLocationWithCoordinates(
            locationName: result.name,
            latitude: result.latitude,
            longitude: result.longitude,
            placeId: result.placeId,
          );
        },
        onManualLocationEntered: (locationName) {
          // Manual entry - location without coordinates
          notifier.updateLocation(locationName);
        },
        onLocationCleared: () {
          notifier.clearLocationAndCoordinates();
        },
      ),
    );
  }

  /// Collaborators picker (max 3)
  /// Shows pending invites - users must accept before becoming co-organizers
  Widget _buildCollaboratorsPicker(
    BuildContext context,
    WidgetRef ref,
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
              'Collaboratori',
              style: NovaTextStyles.labelLarge,
            ),
            Text(
              '${state.pendingInvites.length}/3',
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
        SizedBox(height: NovaSpacing.xs),
        Text(
          'Invita altri studenti come co-organizzatori',
          style: NovaTextStyles.caption.copyWith(
            color: NovaColors.textSecondary(context),
          ),
        ),
        SizedBox(height: NovaSpacing.s),
        // Pending invites chips + add button
        Wrap(
          spacing: NovaSpacing.s,
          runSpacing: NovaSpacing.s,
          children: [
            // Pending invite chips - using PendingInviteInfo with real names
            ...state.pendingInvites.map((invite) => _buildPendingInviteChip(
                  context,
                  invite,
                  () => notifier.removePendingInvite(invite.id),
                )),
            // Add button (if less than 3)
            if (state.pendingInvites.length < 3)
              InkWell(
                onTap: () =>
                    _showCollaboratorPicker(context, ref, state, notifier),
                borderRadius: NovaRadius.circularM,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: NovaSpacing.m,
                    vertical: NovaSpacing.s,
                  ),
                  decoration: BoxDecoration(
                    color: NovaColors.surface(context),
                    borderRadius: NovaRadius.circularM,
                    border: Border.all(
                      color: NovaColors.border(context),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_add_outlined,
                        size: 18,
                        color: NovaColors.primary(context),
                      ),
                      SizedBox(width: NovaSpacing.xs),
                      Text(
                        'Invita',
                        style: NovaTextStyles.caption.copyWith(
                          color: NovaColors.primary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Build a chip for pending invite (shows "In attesa" indicator)
  Widget _buildPendingInviteChip(
    BuildContext context,
    PendingInviteInfo invite,
    VoidCallback onRemove,
  ) {
    // Use the real name from PendingInviteInfo
    final displayName = invite.fullName;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.s,
        vertical: NovaSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: NovaColors.warning(context).withValues(alpha: 0.1),
        borderRadius: NovaRadius.circularM,
        border: Border.all(
          color: NovaColors.warning(context).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with clock indicator
          Stack(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NovaColors.warning(context),
                ),
                child: Center(
                  child: Text(
                    displayName[0].toUpperCase(),
                    style: NovaTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // Small clock badge
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Icon(
                    Icons.schedule,
                    size: 10,
                    color: NovaColors.warning(context),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: NovaSpacing.xs),
          // Name + pending label
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: NovaTextStyles.caption.copyWith(
                  color: NovaColors.textPrimary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'In attesa',
                style: TextStyle(
                  fontSize: 10,
                  color: NovaColors.warning(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(width: NovaSpacing.xs),
          // Remove button
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 16,
              color: NovaColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Show bottom sheet to pick collaborators
  void _showCollaboratorPicker(
    BuildContext context,
    WidgetRef ref,
    EventFormState state,
    EventCreationNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NovaColors.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _CollaboratorPickerSheet(
        selectedIds: state.pendingInvites.map((i) => i.id).toList(),
        onSelect: (inviteInfo) {
          notifier.addPendingInvite(inviteInfo);
          Navigator.pop(sheetContext);
        },
        maxSelections: 3,
      ),
    );
  }

  /// Help requests section
  /// Allows event creators to add free-text help requests
  Widget _buildHelpRequestsSection(
    BuildContext context,
    EventFormState state,
    EventCreationNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with toggle
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Richieste di aiuto',
                    style: NovaTextStyles.labelLarge,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Cerca collaboratori per il tuo evento',
                    style: NovaTextStyles.caption.copyWith(
                      color: NovaColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: state.needsHelp,
              onChanged: (value) => notifier.toggleNeedsHelp(value),
              activeColor: NovaColors.primary(context),
            ),
          ],
        ),

        // Help requests list (only show if needsHelp is true)
        if (state.needsHelp) ...[
          SizedBox(height: NovaSpacing.m),

          // Existing help requests as chips
          if (state.helpRequests.isNotEmpty) ...[
            Wrap(
              spacing: NovaSpacing.s,
              runSpacing: NovaSpacing.s,
              children: state.helpRequests.asMap().entries.map((entry) {
                return _buildHelpRequestChip(
                  context,
                  entry.value,
                  () => notifier.removeHelpRequest(entry.key),
                );
              }).toList(),
            ),
            SizedBox(height: NovaSpacing.m),
          ],

          // Add new request (if less than 5)
          if (state.helpRequests.length < 5)
            _buildAddHelpRequestField(context, notifier),

          // Limit info
          if (state.helpRequests.length >= 5)
            Text(
              'Massimo 5 richieste per evento',
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
        ],
      ],
    );
  }

  /// Build a chip for a help request
  Widget _buildHelpRequestChip(
    BuildContext context,
    String description,
    VoidCallback onRemove,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      decoration: BoxDecoration(
        color: NovaColors.primary(context).withValues(alpha: 0.1),
        borderRadius: NovaRadius.circularM,
        border: Border.all(
          color: NovaColors.primary(context).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.help_outline,
            size: 16,
            color: NovaColors.primary(context),
          ),
          SizedBox(width: NovaSpacing.xs),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 200),
            child: Text(
              description,
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textPrimary(context),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: NovaSpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 16,
              color: NovaColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Field to add a new help request
  Widget _buildAddHelpRequestField(
    BuildContext context,
    EventCreationNotifier notifier,
  ) {
    final controller = TextEditingController();

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Es: Cerco fotografo, grafico...',
              hintStyle: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
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
                borderSide:
                    BorderSide(color: NovaColors.primary(context), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: NovaSpacing.m,
                vertical: NovaSpacing.s,
              ),
            ),
            style: NovaTextStyles.body,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                notifier.addHelpRequest(value.trim());
                controller.clear();
              }
            },
          ),
        ),
        SizedBox(width: NovaSpacing.s),
        IconButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              notifier.addHelpRequest(controller.text.trim());
              controller.clear();
            }
          },
          icon: Icon(
            Icons.add_circle,
            color: NovaColors.primary(context),
            size: 32,
          ),
          tooltip: 'Aggiungi',
        ),
      ],
    );
  }

  /// Info text at bottom
  Widget _buildInfoText(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.m),
      decoration: BoxDecoration(
        color: NovaColors.primary(context).withValues(alpha: 0.1),
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
              'I collaboratori invitati dovranno accettare prima di essere aggiunti. '
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

  /// Show date and time picker (platform-adaptive)
  ///
  /// - iOS: CupertinoDatePicker wheel picker
  /// - Android: Material date/time dialogs
  Future<void> _showDateTimePicker(
    BuildContext context,
    EventFormState state,
    EventCreationNotifier notifier,
  ) async {
    // Pick date (adaptive: iOS wheel picker, Android Material dialog)
    final date = await showAdaptiveDatePicker(
      context: context,
      initialDate:
          state.eventDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    // Pick time (adaptive: iOS wheel picker, Android Material dialog)
    if (!context.mounted) return;
    final time = await showAdaptiveTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        state.eventDate ?? DateTime.now().add(const Duration(hours: 1)),
      ),
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

// =============================================================================
// COLLABORATOR PICKER SHEET
// =============================================================================

/// Bottom sheet for selecting collaborators using real profile search
class _CollaboratorPickerSheet extends ConsumerStatefulWidget {
  final List<String> selectedIds;
  final void Function(PendingInviteInfo inviteInfo) onSelect;
  final int maxSelections;

  const _CollaboratorPickerSheet({
    required this.selectedIds,
    required this.onSelect,
    required this.maxSelections,
  });

  @override
  ConsumerState<_CollaboratorPickerSheet> createState() =>
      _CollaboratorPickerSheetState();
}

class _CollaboratorPickerSheetState
    extends ConsumerState<_CollaboratorPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<ProfileSearchResult> _searchResults = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Load initial results (empty query shows recent/popular)
    _performSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _searchQuery = query;
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = ref.read(searchRepositoryProvider);
      final results = await repository.search(query);
      if (mounted) {
        setState(() {
          _searchResults = results.profiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Errore nella ricerca';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NovaColors.divider(context),
              borderRadius: NovaRadius.circularXxs,
            ),
          ),
          // Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.l),
            child: Row(
              children: [
                Text(
                  'Invita collaboratore',
                  style: NovaTextStyles.h3.copyWith(
                    color: NovaColors.textPrimary(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.selectedIds.length}/${widget.maxSelections}',
                  style: NovaTextStyles.caption.copyWith(
                    color: NovaColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: NovaSpacing.m),
          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.l),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _performSearch(value),
              decoration: InputDecoration(
                hintText: 'Cerca studente...',
                hintStyle: NovaTextStyles.body.copyWith(
                  color: NovaColors.textSecondary(context),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: NovaColors.textSecondary(context),
                ),
                filled: true,
                fillColor: NovaColors.surface(context),
                border: OutlineInputBorder(
                  borderRadius: NovaRadius.circularM,
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.m,
                  vertical: NovaSpacing.s,
                ),
              ),
              style: NovaTextStyles.body,
            ),
          ),
          SizedBox(height: NovaSpacing.m),
          // Users list
          Expanded(
            child: _buildContent(scrollController),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: NovaColors.error(context),
            ),
            SizedBox(height: NovaSpacing.m),
            Text(
              _error!,
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && _searchQuery.length >= 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: NovaColors.textSecondary(context),
            ),
            SizedBox(height: NovaSpacing.m),
            Text(
              'Nessun risultato per "$_searchQuery"',
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 48,
              color: NovaColors.textSecondary(context),
            ),
            SizedBox(height: NovaSpacing.m),
            Text(
              'Cerca uno studente per nome o classe',
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final profile = _searchResults[index];
        final isSelected = widget.selectedIds.contains(profile.id);
        final canSelect =
            !isSelected && widget.selectedIds.length < widget.maxSelections;

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? NovaColors.primary(context)
                  : NovaColors.primary(context).withValues(alpha: 0.2),
              image: profile.avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(profile.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: profile.avatarUrl == null
                ? Center(
                    child: Text(
                      profile.fullName.isNotEmpty
                          ? profile.fullName[0].toUpperCase()
                          : '?',
                      style: NovaTextStyles.body.copyWith(
                        color: isSelected
                            ? Colors.white
                            : NovaColors.primary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
          ),
          title: Text(
            profile.fullName,
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: profile.className != null && profile.className!.isNotEmpty
              ? Text(
                  profile.className!,
                  style: NovaTextStyles.caption.copyWith(
                    color: NovaColors.textSecondary(context),
                  ),
                )
              : null,
          trailing: isSelected
              ? Icon(
                  Icons.check_circle,
                  color: NovaColors.primary(context),
                )
              : canSelect
                  ? Icon(
                      Icons.add_circle_outline,
                      color: NovaColors.textSecondary(context),
                    )
                  : null,
          onTap: canSelect
              ? () {
                  // Convert ProfileSearchResult to PendingInviteInfo
                  final inviteInfo = PendingInviteInfo(
                    id: profile.id,
                    fullName: profile.fullName,
                    className: profile.className ?? '',
                    avatarUrl: profile.avatarUrl,
                  );
                  widget.onSelect(inviteInfo);
                }
              : null,
          enabled: canSelect,
        );
      },
    );
  }
}
