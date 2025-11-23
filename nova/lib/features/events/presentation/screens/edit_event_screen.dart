// Screen: EditEventScreen
// Feature: 004-event-creation-moderation (Phase 7 - Co-Organizers)
// Purpose: Edit existing events (creators + co-organizers only)
//
// Features:
// - Pre-populated form with existing event data
// - Same validation as event creation
// - Updates trigger re-moderation (status → pending)
// - Notifies all co-organizers of changes

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/event.dart';
import '../providers/repository_providers.dart';
import '../widgets/image_picker_widget.dart';
import '../widgets/user_search_widget.dart';

/// Edit event screen for creators and co-organizers
class EditEventScreen extends ConsumerStatefulWidget {
  final Event event;

  const EditEventScreen({
    super.key,
    required this.event,
  });

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  // Form controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;

  // Form state
  late DateTime? _eventDate;
  File? _imageFile;
  String? _imagePath;
  List<Profile> _selectedCoOrganizers = [];

  // UI state
  bool _isSubmitting = false;
  String? _submitError;
  bool _isLoadingProfiles = false;

  // Validation errors
  String? _titleError;
  String? _descriptionError;
  String? _eventDateError;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with event data
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController = TextEditingController(text: widget.event.description);
    _locationController = TextEditingController(text: widget.event.location ?? '');
    _eventDate = widget.event.eventDate;
    _imagePath = widget.event.imageUrl;

    // Load co-organizer profiles
    _loadCoOrganizerProfiles();

    // Add listeners for validation
    _titleController.addListener(_validateTitle);
    _descriptionController.addListener(_validateDescription);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// Load profiles for existing co-organizers
  Future<void> _loadCoOrganizerProfiles() async {
    if (widget.event.coOrganizers.isEmpty) return;

    setState(() => _isLoadingProfiles = true);

    try {
      final repository = ref.read(profileRepositoryProvider);
      final profiles = <Profile>[];

      for (final userId in widget.event.coOrganizers) {
        try {
          final profile = await repository.getProfileById(userId);
          profiles.add(profile);
        } catch (e) {
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

  void _validateTitle() {
    setState(() {
      final length = _titleController.text.trim().length;
      if (length < 5) {
        _titleError = 'Minimo 5 caratteri';
      } else if (length > 100) {
        _titleError = 'Massimo 100 caratteri';
      } else {
        _titleError = null;
      }
    });
  }

  void _validateDescription() {
    setState(() {
      final length = _descriptionController.text.trim().length;
      if (length < 20) {
        _descriptionError = 'Minimo 20 caratteri';
      } else if (length > 500) {
        _descriptionError = 'Massimo 500 caratteri';
      } else {
        _descriptionError = null;
      }
    });
  }

  void _validateEventDate() {
    setState(() {
      if (_eventDate != null && _eventDate!.isBefore(DateTime.now())) {
        _eventDateError = 'La data deve essere futura';
      } else {
        _eventDateError = null;
      }
    });
  }

  bool get _isValid {
    return _titleController.text.trim().length >= 5 &&
        _titleController.text.trim().length <= 100 &&
        _descriptionController.text.trim().length >= 20 &&
        _descriptionController.text.trim().length <= 500 &&
        _eventDate != null &&
        _eventDate!.isAfter(DateTime.now()) &&
        _selectedCoOrganizers.length <= 3 &&
        _titleError == null &&
        _descriptionError == null &&
        _eventDateError == null;
  }

  Future<void> _submitUpdate() async {
    if (!_isValid) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final repository = ref.read(eventRepositoryProvider);

      // Prepare update data
      final updates = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'event_date': _eventDate!.toIso8601String(),
        'location': _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        'co_organizers': _selectedCoOrganizers.map((p) => p.id).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // TODO(#004): Handle image upload to Supabase Storage if _imageFile != null (reuse logic from EventCreationScreen)

      // Update event (triggers re-moderation if content changed)
      await repository.updateEvent(
        widget.event.id,
        updates,
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Evento aggiornato con successo'),
            backgroundColor: NovaColors.success(context),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate back
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _submitError = 'Errore durante l\'aggiornamento: ${e.toString()}';
      });
    }
  }

  Future<void> _showDateTimePicker() async {
    // Pick date
    final date = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now().add(const Duration(days: 1)),
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

    if (date == null || !mounted) return;

    // Pick time
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _eventDate ?? DateTime.now().add(const Duration(hours: 1)),
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

    if (time == null || !mounted) return;

    // Combine date and time
    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      _eventDate = dateTime;
    });
    _validateEventDate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifica Evento'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NovaColors.background(context),
        foregroundColor: NovaColors.textPrimary(context),
      ),
      body: Stack(
        children: [
          // Form
          SingleChildScrollView(
            padding: EdgeInsets.all(NovaSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning banner
                Container(
                  padding: EdgeInsets.all(NovaSpacing.m),
                  margin: EdgeInsets.only(bottom: NovaSpacing.l),
                  decoration: BoxDecoration(
                    color: NovaColors.warning(context).withOpacity(0.1),
                    borderRadius: NovaRadius.circularM,
                    border: Border.all(
                      color: NovaColors.warning(context).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: NovaColors.warning(context),
                      ),
                      SizedBox(width: NovaSpacing.s),
                      Expanded(
                        child: Text(
                          'Le modifiche richiederanno una nuova approvazione del moderatore',
                          style: NovaTextStyles.caption.copyWith(
                            color: NovaColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Title field
                _buildTextField(
                  label: 'Titolo *',
                  controller: _titleController,
                  maxLength: 100,
                  error: _titleError,
                  hint: 'Es: Torneo di Calcetto 5vs5',
                  charCount: '${_titleController.text.length}/100',
                ),
                SizedBox(height: NovaSpacing.l),

                // Description field
                _buildTextField(
                  label: 'Descrizione *',
                  controller: _descriptionController,
                  maxLength: 500,
                  maxLines: 5,
                  error: _descriptionError,
                  hint: 'Descrivi l\'evento, luogo di ritrovo, costi, ecc...',
                  charCount: '${_descriptionController.text.length}/500',
                ),
                SizedBox(height: NovaSpacing.l),

                // Date/Time picker
                _buildDateTimePicker(),
                SizedBox(height: NovaSpacing.l),

                // Location field
                _buildTextField(
                  label: 'Luogo (Opzionale)',
                  controller: _locationController,
                  hint: 'Es: Campo sportivo del liceo',
                ),
                SizedBox(height: NovaSpacing.l),

                // Image picker
                ImagePickerWidget(
                  imageFile: _imageFile,
                  imagePath: _imagePath,
                  onImagePicked: (file) {
                    setState(() {
                      _imageFile = file;
                      _imagePath = file.path;
                    });
                  },
                  onImageRemoved: () {
                    setState(() {
                      _imageFile = null;
                      _imagePath = null;
                    });
                  },
                ),
                SizedBox(height: NovaSpacing.l),

                // Co-organizers section
                _buildCoOrganizersSection(),
              ],
            ),
          ),

          // Loading overlay
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? error,
    String? charCount,
    int? maxLength,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: NovaTextStyles.body),
            if (charCount != null)
              Text(
                charCount,
                style: NovaTextStyles.caption.copyWith(
                  color: NovaColors.textSecondary(context),
                ),
              ),
          ],
        ),
        SizedBox(height: NovaSpacing.s),
        TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            errorText: error,
            counterText: '',
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

  Widget _buildDateTimePicker() {
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final displayText = _eventDate != null
        ? dateFormatter.format(_eventDate!)
        : 'Seleziona data e ora';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Data e Ora *', style: NovaTextStyles.body),
        SizedBox(height: NovaSpacing.s),
        InkWell(
          onTap: _showDateTimePicker,
          borderRadius: NovaRadius.circularM,
          child: Container(
            padding: EdgeInsets.all(NovaSpacing.m),
            decoration: BoxDecoration(
              color: NovaColors.surface(context),
              borderRadius: NovaRadius.circularM,
              border: Border.all(
                color: _eventDateError != null
                    ? NovaColors.error(context)
                    : NovaColors.border(context),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: _eventDate != null
                      ? NovaColors.textPrimary(context)
                      : NovaColors.textSecondary(context),
                ),
                SizedBox(width: NovaSpacing.m),
                Text(
                  displayText,
                  style: NovaTextStyles.body.copyWith(
                    color: _eventDate != null
                        ? NovaColors.textPrimary(context)
                        : NovaColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_eventDateError != null) ...[
          SizedBox(height: NovaSpacing.xs),
          Text(
            _eventDateError!,
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.error(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCoOrganizersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Co-Organizzatori (Opzionale)', style: NovaTextStyles.body),
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
            onSelectionChanged: (profiles) {
              setState(() => _selectedCoOrganizers = profiles);
            },
            maxSelections: 3,
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.l),
      decoration: BoxDecoration(
        color: NovaColors.background(context),
        border: Border(
          top: BorderSide(
            color: NovaColors.border(context),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error message
            if (_submitError != null) ...[
              Container(
                padding: EdgeInsets.all(NovaSpacing.m),
                margin: EdgeInsets.only(bottom: NovaSpacing.m),
                decoration: BoxDecoration(
                  color: NovaColors.error(context).withOpacity(0.1),
                  borderRadius: NovaRadius.circularM,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: NovaColors.error(context),
                      size: 20,
                    ),
                    SizedBox(width: NovaSpacing.s),
                    Expanded(
                      child: Text(
                        _submitError!,
                        style: NovaTextStyles.caption.copyWith(
                          color: NovaColors.error(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isValid && !_isSubmitting ? _submitUpdate : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NovaColors.primary(context),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: NovaColors.border(context),
                  disabledForegroundColor: NovaColors.textSecondary(context),
                  padding: EdgeInsets.symmetric(vertical: NovaSpacing.m),
                  shape: RoundedRectangleBorder(
                    borderRadius: NovaRadius.circularM,
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Salva Modifiche',
                        style: NovaTextStyles.button,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
