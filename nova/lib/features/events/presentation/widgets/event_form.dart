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
import '../providers/event_creation_provider.dart';
import './image_picker_widget.dart';

/// Complete event creation form
class EventForm extends ConsumerWidget {
  const EventForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            errorText: state.imageError,
          ),
          SizedBox(height: NovaSpacing.l),

          // Collaborators picker
          _buildCollaboratorsPicker(context, ref, state, notifier),
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
          'Luogo',
          style: NovaTextStyles.labelLarge,
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
            // Pending invite chips
            ...state.pendingInvites.map((userId) => _buildPendingInviteChip(
                  context,
                  userId,
                  () => notifier.removePendingInvite(userId),
                )),
            // Add button (if less than 3)
            if (state.pendingInvites.length < 3)
              InkWell(
                onTap: () => _showCollaboratorPicker(context, ref, state, notifier),
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
    String userId,
    VoidCallback onRemove,
  ) {
    // TODO: Get actual user info from profile provider
    // For now, show userId truncated
    final displayName = userId.length > 8 ? '${userId.substring(0, 8)}...' : userId;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.s,
        vertical: NovaSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: NovaColors.warning(context).withOpacity(0.1),
        borderRadius: NovaRadius.circularM,
        border: Border.all(
          color: NovaColors.warning(context).withOpacity(0.3),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _CollaboratorPickerSheet(
        selectedIds: state.pendingInvites,
        onSelect: (userId) {
          notifier.addPendingInvite(userId);
          Navigator.pop(sheetContext);
        },
        maxSelections: 3,
      ),
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

// =============================================================================
// COLLABORATOR PICKER SHEET
// =============================================================================

/// Bottom sheet for selecting collaborators
class _CollaboratorPickerSheet extends StatefulWidget {
  final List<String> selectedIds;
  final void Function(String userId) onSelect;
  final int maxSelections;

  const _CollaboratorPickerSheet({
    required this.selectedIds,
    required this.onSelect,
    required this.maxSelections,
  });

  @override
  State<_CollaboratorPickerSheet> createState() => _CollaboratorPickerSheetState();
}

class _CollaboratorPickerSheetState extends State<_CollaboratorPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // TODO: Replace with actual users from profile search provider
  // Mock data for now
  final List<Map<String, String>> _mockUsers = [
    {'id': 'user1', 'name': 'Marco Rossi', 'class': '3A'},
    {'id': 'user2', 'name': 'Luigi Verdi', 'class': '4B'},
    {'id': 'user3', 'name': 'Anna Bianchi', 'class': '3A'},
    {'id': 'user4', 'name': 'Sofia Romano', 'class': '5C'},
    {'id': 'user5', 'name': 'Alessandro Conti', 'class': '2D'},
    {'id': 'user6', 'name': 'Giulia Esposito', 'class': '4A'},
    {'id': 'user7', 'name': 'Francesco Marino', 'class': '3B'},
    {'id': 'user8', 'name': 'Elena Ferrari', 'class': '5A'},
  ];

  List<Map<String, String>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _mockUsers;
    return _mockUsers.where((user) {
      final name = user['name']!.toLowerCase();
      final className = user['class']!.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || className.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              color: const Color(0xFFD0D0D0),
              borderRadius: BorderRadius.circular(2),
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
              onChanged: (value) => setState(() => _searchQuery = value),
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
            child: _filteredUsers.isEmpty
                ? Center(
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
                          'Nessun risultato',
                          style: NovaTextStyles.body.copyWith(
                            color: NovaColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final userId = user['id']!;
                      final isSelected = widget.selectedIds.contains(userId);
                      final canSelect = !isSelected &&
                          widget.selectedIds.length < widget.maxSelections;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? NovaColors.primary(context)
                                : NovaColors.primary(context).withOpacity(0.2),
                          ),
                          child: Center(
                            child: Text(
                              user['name']![0].toUpperCase(),
                              style: NovaTextStyles.body.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : NovaColors.primary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          user['name']!,
                          style: NovaTextStyles.body.copyWith(
                            color: NovaColors.textPrimary(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          user['class']!,
                          style: NovaTextStyles.caption.copyWith(
                            color: NovaColors.textSecondary(context),
                          ),
                        ),
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
                            ? () => widget.onSelect(userId)
                            : null,
                        enabled: canSelect,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
