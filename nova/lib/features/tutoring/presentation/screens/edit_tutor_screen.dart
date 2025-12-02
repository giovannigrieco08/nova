// Screen: EditTutorScreen
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: Form for editing an existing tutor profile

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/tutor_profile.dart';
import '../providers/tutor_providers.dart';

/// EditTutorScreen - Form for editing an existing tutor profile
///
/// FR-016 to FR-017: Edit bio, subjects, price, availability, contacts
/// FR-018: Deactivate/reactivate profile
///
/// Pre-populates form with existing tutor profile data.
class EditTutorScreen extends ConsumerStatefulWidget {
  /// The current tutor profile to edit
  final TutorProfile profile;

  const EditTutorScreen({
    super.key,
    required this.profile,
  });

  @override
  ConsumerState<EditTutorScreen> createState() => _EditTutorScreenState();
}

class _EditTutorScreenState extends ConsumerState<EditTutorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bioController;
  late final TextEditingController _priceController;
  late final TextEditingController _timeSlotController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _instagramController;

  late Set<Subject> _selectedSubjects;
  late Set<AvailabilityDay> _selectedDays;
  bool _isSubmitting = false;
  bool _isDeactivating = false;

  @override
  void initState() {
    super.initState();
    // T037: Pre-populate form fields with existing data
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _priceController = TextEditingController(
      text: widget.profile.pricePerHour.toStringAsFixed(0),
    );
    _timeSlotController = TextEditingController(
      text: widget.profile.timeSlot ?? '',
    );
    _whatsappController = TextEditingController(
      text: widget.profile.whatsappPhone ?? '',
    );
    _instagramController = TextEditingController(
      text: widget.profile.instagramUsername ?? '',
    );
    _selectedSubjects = widget.profile.subjects.toSet();
    _selectedDays = widget.profile.availabilityDays.toSet();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _priceController.dispose();
    _timeSlotController.dispose();
    _whatsappController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS
        ? _buildCupertinoScreen(context)
        : _buildMaterialScreen(context);
  }

  Widget _buildCupertinoScreen(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Modifica Profilo Tutor'),
        backgroundColor: NovaColors.surface(context),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSubmitting ? null : _submitForm,
          child: _isSubmitting
              ? const CupertinoActivityIndicator()
              : Text(
                  'Salva',
                  style: TextStyle(
                    color: NovaColors.primary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
      backgroundColor: NovaColors.background(context),
      child: SafeArea(
        child: _buildForm(context),
      ),
    );
  }

  Widget _buildMaterialScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifica Profilo Tutor'),
        backgroundColor: NovaColors.surface(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          _isSubmitting
              ? const Padding(
                  padding: EdgeInsets.all(NovaSpacing.l),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _submitForm,
                  child: const Text('Salva'),
                ),
        ],
      ),
      backgroundColor: NovaColors.background(context),
      body: SafeArea(
        child: _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(NovaSpacing.l),
        children: [
          // Bio section
          _buildSectionTitle(context, 'Presentati'),
          const SizedBox(height: NovaSpacing.s),
          _buildBioField(context),
          const SizedBox(height: NovaSpacing.xl),

          // Subjects section
          _buildSectionTitle(context, 'Materie (max 5)'),
          const SizedBox(height: NovaSpacing.s),
          _buildSubjectsSelector(context),
          const SizedBox(height: NovaSpacing.xl),

          // Price section
          _buildSectionTitle(context, 'Prezzo'),
          const SizedBox(height: NovaSpacing.s),
          _buildPriceField(context),
          const SizedBox(height: NovaSpacing.xl),

          // Availability section
          _buildSectionTitle(context, 'Disponibilità'),
          const SizedBox(height: NovaSpacing.s),
          _buildAvailabilitySelector(context),
          const SizedBox(height: NovaSpacing.s),
          _buildTimeSlotField(context),
          const SizedBox(height: NovaSpacing.xl),

          // Contact section
          _buildSectionTitle(context, 'Contatti (almeno uno)'),
          const SizedBox(height: NovaSpacing.s),
          _buildWhatsAppField(context),
          const SizedBox(height: NovaSpacing.m),
          _buildInstagramField(context),
          const SizedBox(height: NovaSpacing.xxxl),

          // Deactivate section (T040-T041)
          _buildDeactivateSection(context),
          const SizedBox(height: NovaSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: NovaColors.textPrimary(context),
      ),
    );
  }

  Widget _buildBioField(BuildContext context) {
    return TextFormField(
      controller: _bioController,
      maxLength: 200,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Descrivi la tua esperienza e come puoi aiutare...',
        filled: true,
        fillColor: NovaColors.card(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NovaColors.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NovaColors.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NovaColors.primary(context), width: 2),
        ),
      ),
      validator: (value) {
        if (value != null && value.length > 200) {
          return 'La bio non può superare 200 caratteri';
        }
        return null;
      },
    );
  }

  Widget _buildSubjectsSelector(BuildContext context) {
    return Wrap(
      spacing: NovaSpacing.s,
      runSpacing: NovaSpacing.s,
      children: Subject.values.map((subject) {
        final isSelected = _selectedSubjects.contains(subject);
        final canSelect = _selectedSubjects.length < 5 || isSelected;

        return FilterChip(
          label: Text(subject.displayName),
          selected: isSelected,
          onSelected: canSelect
              ? (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSubjects.add(subject);
                    } else {
                      _selectedSubjects.remove(subject);
                    }
                  });
                }
              : null,
          selectedColor: NovaColors.primary(context),
          backgroundColor: NovaColors.card(context),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : NovaColors.textPrimary(context),
          ),
          checkmarkColor: Colors.white,
          side: isSelected
              ? BorderSide.none
              : BorderSide(color: NovaColors.border(context)),
        );
      }).toList(),
    );
  }

  Widget _buildPriceField(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              prefixText: '€ ',
              suffixText: '/ora',
              hintText: '0',
              filled: true,
              fillColor: NovaColors.card(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: NovaColors.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: NovaColors.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: NovaColors.primary(context), width: 2),
              ),
            ),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final price = double.tryParse(value);
                if (price == null || price < 0) {
                  return 'Prezzo non valido';
                }
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: NovaSpacing.m),
        OutlinedButton(
          onPressed: () {
            _priceController.text = '0';
          },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: NovaColors.success(context)),
          ),
          child: Text(
            'Gratis',
            style: TextStyle(color: NovaColors.success(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilitySelector(BuildContext context) {
    return Wrap(
      spacing: NovaSpacing.s,
      runSpacing: NovaSpacing.s,
      children: AvailabilityDay.values.map((day) {
        final isSelected = _selectedDays.contains(day);

        return FilterChip(
          label: Text(day.displayName),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedDays.add(day);
              } else {
                _selectedDays.remove(day);
              }
            });
          },
          selectedColor: NovaColors.primary(context),
          backgroundColor: NovaColors.card(context),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : NovaColors.textPrimary(context),
          ),
          checkmarkColor: Colors.white,
          side: isSelected
              ? BorderSide.none
              : BorderSide(color: NovaColors.border(context)),
        );
      }).toList(),
    );
  }

  Widget _buildTimeSlotField(BuildContext context) {
    return TextFormField(
      controller: _timeSlotController,
      decoration: InputDecoration(
        hintText: 'Es: 15:00-18:00',
        labelText: 'Fascia oraria (opzionale)',
        filled: true,
        fillColor: NovaColors.card(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NovaColors.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NovaColors.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NovaColors.primary(context), width: 2),
        ),
      ),
    );
  }

  Widget _buildWhatsAppField(BuildContext context) {
    return TextFormField(
      controller: _whatsappController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        hintText: '393201234567',
        labelText: 'WhatsApp',
        prefixIcon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
        helperText: 'Numero con prefisso internazionale (es: 393201234567)',
        filled: true,
        fillColor: NovaColors.card(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NovaColors.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NovaColors.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NovaColors.primary(context), width: 2),
        ),
      ),
    );
  }

  Widget _buildInstagramField(BuildContext context) {
    return TextFormField(
      controller: _instagramController,
      decoration: InputDecoration(
        hintText: 'username',
        labelText: 'Instagram',
        prefixText: '@',
        prefixIcon: const Icon(Icons.camera_alt_rounded, color: Color(0xFFE4405F)),
        helperText: 'Username senza @',
        filled: true,
        fillColor: NovaColors.card(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NovaColors.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NovaColors.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NovaColors.primary(context), width: 2),
        ),
      ),
    );
  }

  /// T040-T041: Deactivate profile section
  Widget _buildDeactivateSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NovaSpacing.l),
      decoration: BoxDecoration(
        color: NovaColors.error(context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NovaColors.error(context).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zona Pericolo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: NovaColors.error(context),
            ),
          ),
          const SizedBox(height: NovaSpacing.s),
          Text(
            'Disattivando il profilo, non sarai più visibile nelle ricerche. Potrai riattivarlo in qualsiasi momento.',
            style: TextStyle(
              fontSize: 14,
              color: NovaColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: NovaSpacing.m),
          SizedBox(
            width: double.infinity,
            child: Platform.isIOS
                ? CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: NovaSpacing.m),
                    color: NovaColors.error(context),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: _isDeactivating ? null : _showDeactivateConfirmation,
                    child: _isDeactivating
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Text(
                            'Disattiva Profilo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  )
                : ElevatedButton(
                    onPressed: _isDeactivating ? null : _showDeactivateConfirmation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NovaColors.error(context),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: NovaSpacing.m),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isDeactivating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Disattiva Profilo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  /// T041: Show confirmation dialog for deactivation
  void _showDeactivateConfirmation() {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Disattiva Profilo?'),
          content: const Text(
            'Il tuo profilo tutor non sarà più visibile agli altri studenti. Potrai riattivarlo in qualsiasi momento.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Annulla'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(context).pop();
                _deactivateProfile();
              },
              child: const Text('Disattiva'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Disattiva Profilo?'),
          content: const Text(
            'Il tuo profilo tutor non sarà più visibile agli altri studenti. Potrai riattivarlo in qualsiasi momento.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deactivateProfile();
              },
              style: TextButton.styleFrom(
                foregroundColor: NovaColors.error(context),
              ),
              child: const Text('Disattiva'),
            ),
          ],
        ),
      );
    }
  }

  /// T042: Execute deactivation
  Future<void> _deactivateProfile() async {
    setState(() => _isDeactivating = true);

    try {
      final notifier = ref.read(toggleTutorActiveProvider.notifier);
      final result = await notifier.deactivate();

      if (!mounted) return;

      if (result != null) {
        _showSuccess('Profilo tutor disattivato');
        Navigator.of(context).pop(); // Return to profile
      } else {
        _showError('Errore durante la disattivazione');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeactivating = false);
      }
    }
  }

  /// T039: Submit form to update profile
  Future<void> _submitForm() async {
    // Validate form
    if (!_formKey.currentState!.validate()) return;

    // Validate subjects
    if (_selectedSubjects.isEmpty) {
      _showError('Seleziona almeno una materia');
      return;
    }

    // Validate contacts
    final whatsapp = _whatsappController.text.trim();
    final instagram = _instagramController.text.trim();
    if (whatsapp.isEmpty && instagram.isEmpty) {
      _showError('Inserisci almeno un contatto (WhatsApp o Instagram)');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final notifier = ref.read(updateTutorProfileProvider.notifier);
      final result = await notifier.update(
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        subjects: _selectedSubjects.toList(),
        pricePerHour: double.tryParse(_priceController.text) ?? 0.0,
        availabilityDays: _selectedDays.toList(),
        timeSlot: _timeSlotController.text.trim().isEmpty ? null : _timeSlotController.text.trim(),
        whatsappPhone: whatsapp.isEmpty ? null : whatsapp,
        instagramUsername: instagram.isEmpty ? null : instagram,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        _showSuccess('Profilo aggiornato!');
        Navigator.of(context).pop();
      } else {
        _showError(result.error ?? 'Errore durante l\'aggiornamento');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Errore'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: NovaColors.error(context),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (!Platform.isIOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: NovaColors.success(context),
        ),
      );
    }
  }
}
