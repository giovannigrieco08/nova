// Screen: EditProfileScreen
// Feature: 006-user-profile (User Story 1 - T040, T041, T042)
// Purpose: Modal/screen for editing profile (avatar, name, class, bio)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/profile.dart';
import '../providers/profile_provider.dart';
import '../providers/avatar_upload_provider.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/profile_bio.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../shared/widgets/adaptive/adaptive_scaffold.dart';
import '../../../../shared/widgets/adaptive/adaptive_button.dart';
import '../../../../shared/widgets/adaptive/adaptive_text_field.dart';
import '../../../../shared/widgets/adaptive/adaptive_loading_indicator.dart';

/// Edit profile screen with avatar picker, name, class, bio
///
/// **Form Fields**:
/// - Avatar: Tap to change (image_picker → image_cropper circular crop)
/// - Full Name: Text field (min 2 words validation)
/// - Class: Dropdown (38 classes + "Altro")
/// - Bio: Textarea (max 150 chars with counter)
///
/// **Validation** (T041):
/// - Full name: Required, min 2 words (e.g., "Marco Rossi")
/// - Class: Required, must be valid class
/// - Bio: Optional, max 150 characters
/// - Avatar: Optional, max 2MB, min 200×200px
///
/// **Save Flow** (T042):
/// 1. Validate all fields
/// 2. If avatar changed: compress to WebP <500KB, upload to Storage
/// 3. Update profiles table (full_name, class, bio, avatar_url)
/// 4. Show toast "Profilo aggiornato!"
/// 5. Navigate back to ProfileScreen
/// 6. On error: rollback optimistic UI, show error message
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  String? _selectedClass;

  // 38 classes from database schema: Scientifico A-E (1-5), F partial (1,3,4), Classico Ac-Bc (1-5), Altro
  static const List<String> _classList = [
    // Scientifico A (1A-5A)
    '1A', '2A', '3A', '4A', '5A',
    // Scientifico B (1B-5B)
    '1B', '2B', '3B', '4B', '5B',
    // Scientifico C (1C-5C)
    '1C', '2C', '3C', '4C', '5C',
    // Scientifico D (1D-5D)
    '1D', '2D', '3D', '4D', '5D',
    // Scientifico E (1E-5E)
    '1E', '2E', '3E', '4E', '5E',
    // Scientifico F partial (1F, 3F, 4F)
    '1F', '3F', '4F',
    // Classico Ac (1Ac-5Ac)
    '1Ac', '2Ac', '3Ac', '4Ac', '5Ac',
    // Classico Bc (1Bc-5Bc)
    '1Bc', '2Bc', '3Bc', '4Bc', '5Bc',
    // Other
    'Altro',
  ];

  @override
  void initState() {
    super.initState();

    // Initialize controllers from current profile
    final profileAsync = ref.read(currentProfileProvider);
    profileAsync.when(
      data: (profile) {
        _nameController = TextEditingController(text: profile.fullName);
        _bioController = TextEditingController(text: profile.bio);
        _selectedClass = profile.classYear;
      },
      loading: () {
        _nameController = TextEditingController();
        _bioController = TextEditingController();
      },
      error: (err, stack) {
        _nameController = TextEditingController();
        _bioController = TextEditingController();
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final uploadState = ref.watch(avatarUploadProvider);

    return profileAsync.when(
      data: (profile) => _buildEditView(profile, uploadState),
      loading: () => _buildLoadingView(),
      error: (error, stack) => _buildErrorView(error),
    );
  }

  /// Build edit view with form
  Widget _buildEditView(Profile profile, AvatarUploadState uploadState) {
    final isBusy = uploadState.isBusy;

    return AdaptiveScaffold(
      appBar: _buildAppBar(isBusy),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(NovaSpacing.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar picker
              Center(
                child: AvatarPicker(
                  currentAvatarUrl: profile.avatarUrl,
                  onImageSelected: (File croppedFile) async {
                    // Upload avatar via AvatarUploadProvider
                    final uploadNotifier = ref.read(avatarUploadProvider.notifier);
                    uploadNotifier.setSelectedImage(croppedFile);
                    final updatedProfile = await uploadNotifier.upload();

                    if (updatedProfile != null) {
                      // Success - refresh profile provider
                      ref.invalidate(currentProfileProvider);
                      if (mounted) {
                        _showToast('Avatar aggiornato!');
                      }
                    } else if (uploadState.errorMessage != null) {
                      if (mounted) {
                        _showError(uploadState.errorMessage!);
                      }
                    }
                  },
                  onRemoveAvatar: () async {
                    // Remove avatar (set avatar_url to null)
                    final updateProfile = ref.read(updateProfileUseCaseProvider);
                    final userId = profile.id;

                    try {
                      await updateProfile(userId, {'avatar_url': null});
                      ref.invalidate(currentProfileProvider);
                      if (mounted) {
                        _showToast('Avatar rimosso');
                      }
                    } catch (e) {
                      if (mounted) {
                        _showError('Errore nel rimuovere l\'avatar: ${e.toString()}');
                      }
                    }
                  },
                ),
              ),

              // Show upload progress
              if (uploadState.isBusy) ...[
                SizedBox(height: NovaSpacing.small),
                Center(
                  child: Text(
                    uploadState.isCompressing
                        ? 'Compressione...'
                        : 'Caricamento...',
                    style: NovaTypography.bodySmall.copyWith(
                      color: NovaColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(height: NovaSpacing.xsmall),
                const AdaptiveLoadingIndicator(),
              ],

              SizedBox(height: NovaSpacing.large),

              // Full Name field
              _buildSectionLabel('Nome completo'),
              SizedBox(height: NovaSpacing.small),
              AdaptiveTextField(
                controller: _nameController,
                placeholder: 'Nome e cognome',
                enabled: !isBusy,
                validator: _validateFullName,
              ),

              SizedBox(height: NovaSpacing.large),

              // Class dropdown
              _buildSectionLabel('Classe'),
              SizedBox(height: NovaSpacing.small),
              _buildClassDropdown(isBusy),

              SizedBox(height: NovaSpacing.large),

              // Bio editor
              _buildSectionLabel('Bio (opzionale)'),
              SizedBox(height: NovaSpacing.small),
              BioEditor(
                initialValue: profile.bio,
                onChanged: (value) {
                  _bioController.text = value;
                },
              ),

              SizedBox(height: NovaSpacing.xlarge),

              // Save button
              AdaptiveButton(
                onPressed: isBusy ? null : () => _save(profile),
                backgroundColor: NovaColors.brandViolet,
                child: Text(
                  'Salva',
                  style: NovaTypography.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build app bar with cancel/save buttons
  PreferredSizeWidget _buildAppBar(bool isBusy) {
    if (Platform.isIOS) {
      return CupertinoNavigationBar(
        middle: Text(
          'Modifica Profilo',
          style: NovaTypography.headingMedium,
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: isBusy ? null : () => Navigator.pop(context),
          child: Text(
            'Annulla',
            style: NovaTypography.bodyMedium.copyWith(
              color: NovaColors.brandViolet,
            ),
          ),
        ),
      );
    } else {
      return AppBar(
        title: Text(
          'Modifica Profilo',
          style: NovaTypography.headingMedium,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: isBusy ? null : () => Navigator.pop(context),
        ),
      );
    }
  }

  /// Build section label
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: NovaTypography.bodyMedium.copyWith(
        color: NovaColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// Build class dropdown
  Widget _buildClassDropdown(bool isBusy) {
    return DropdownButtonFormField<String>(
      value: _selectedClass,
      decoration: InputDecoration(
        hintText: 'Seleziona la tua classe',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NovaRadius.medium),
          borderSide: BorderSide(color: NovaColors.borderPrimary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NovaRadius.medium),
          borderSide: BorderSide(color: NovaColors.brandViolet, width: 2),
        ),
        enabled: !isBusy,
      ),
      items: _classList.map((className) {
        return DropdownMenuItem(
          value: className,
          child: Text(className),
        );
      }).toList(),
      onChanged: isBusy ? null : (value) {
        setState(() => _selectedClass = value);
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Seleziona la tua classe';
        }
        return null;
      },
    );
  }

  /// Validate full name (min 2 words)
  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nome completo richiesto';
    }

    final words = value.trim().split(RegExp(r'\s+'));
    if (words.length < 2) {
      return 'Inserisci nome e cognome';
    }

    return null;
  }

  /// Save profile changes
  Future<void> _save(Profile profile) async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Prepare updates
    final updates = <String, dynamic>{};

    if (_nameController.text.trim() != profile.fullName) {
      updates['full_name'] = _nameController.text.trim();
    }

    if (_selectedClass != profile.classYear) {
      updates['class'] = _selectedClass!;
    }

    if (_bioController.text.trim() != profile.bio) {
      updates['bio'] = _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim();
    }

    // If no changes, just go back
    if (updates.isEmpty) {
      Navigator.pop(context);
      return;
    }

    // Update profile
    try {
      final updateProfile = ref.read(updateProfileUseCaseProvider);
      await updateProfile(profile.id, updates);

      // Refresh profile provider
      ref.invalidate(currentProfileProvider);

      if (mounted) {
        _showToast('Profilo aggiornato!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showError('Errore nel salvare il profilo: ${e.toString()}');
      }
    }
  }

  /// Show success toast
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: NovaColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: NovaColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Build loading view
  Widget _buildLoadingView() {
    return AdaptiveScaffold(
      appBar: _buildAppBar(false),
      body: const Center(
        child: AdaptiveLoadingIndicator(),
      ),
    );
  }

  /// Build error view
  Widget _buildErrorView(Object error) {
    return AdaptiveScaffold(
      appBar: _buildAppBar(false),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(NovaSpacing.large),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: NovaColors.error,
              ),
              SizedBox(height: NovaSpacing.medium),
              Text(
                'Errore nel caricare il profilo',
                style: NovaTypography.headingSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: NovaSpacing.small),
              Text(
                error.toString(),
                style: NovaTypography.bodySmall.copyWith(
                  color: NovaColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
