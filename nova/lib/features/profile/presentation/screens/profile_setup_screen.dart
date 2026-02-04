// Screen: ProfileSetupScreen
// Feature: 002-profile-setup
// Purpose: First-time profile setup with Instagram-inspired UX

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/classes.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../shared/widgets/nova_toast.dart';
import '../providers/profile_provider.dart';
import '../widgets/avatar_initials.dart';
import '../widgets/skeleton_avatar.dart';
import '../widgets/class_picker_bottom_sheet.dart';
import '../widgets/avatar_picker_bottom_sheet.dart';
import '../widgets/avatar_cropper.dart';

/// First-time profile setup screen
///
/// **Features**:
/// - Name auto-populated from email (via Supabase RPC)
/// - Class picker (required)
/// - Skip button (top-right)
/// - "Salva e inizia" button (disabled until class selected)
/// - Replace navigation after save (no back to setup)
///
/// **User Flow**:
/// 1. User completes magic link authentication
/// 2. App checks if profile exists
/// 3. If no profile → Navigate here
/// 4. User fills name + class
/// 5. Tap "Salva e inizia" → Navigate to Feed (replace)
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();

  String? _selectedClass;
  String? _avatarUrl;
  File? _selectedAvatarFile;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  double _uploadProgress = 0.0;

  // Username availability check state
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  Timer? _usernameDebounceTimer;

  @override
  void initState() {
    super.initState();
    _autoPopulateName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _usernameDebounceTimer?.cancel();
    super.dispose();
  }

  /// Check username availability with debounce
  void _onUsernameChanged(String value) {
    // Reset availability state
    setState(() {
      _isUsernameAvailable = null;
    });

    // Cancel previous timer
    _usernameDebounceTimer?.cancel();

    // Validate locally first
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length < 3 || trimmed.contains(' ')) {
      return; // Don't check availability for invalid usernames
    }

    // Debounce the API call (300ms)
    _usernameDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _checkUsernameAvailability(trimmed);
    });
  }

  /// Check if username is available via API
  Future<void> _checkUsernameAvailability(String username) async {
    if (!mounted) return;

    setState(() {
      _isCheckingUsername = true;
    });

    try {
      final repository = ref.read(profileRepositoryProvider);
      final isAvailable = await repository.isUsernameAvailable(username);

      if (mounted) {
        setState(() {
          _isUsernameAvailable = isAvailable;
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUsernameAvailable = null;
          _isCheckingUsername = false;
        });
      }
    }
  }

  /// Build suffix icon for username field showing availability status
  Widget? _buildUsernameStatusIcon() {
    if (_isCheckingUsername) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_isUsernameAvailable == true) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Icon(Icons.check_circle, color: Colors.green),
      );
    }

    if (_isUsernameAvailable == false) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Icon(Icons.cancel, color: Colors.red),
      );
    }

    return null;
  }

  /// Handle avatar selection and upload
  Future<void> _handleAvatarPicker() async {
    // Show picker bottom sheet
    final selectedFile = await AvatarPickerBottomSheet.show(
      context,
      hasExistingAvatar: _avatarUrl != null || _selectedAvatarFile != null,
      onRemoveAvatar: () {
        setState(() {
          _avatarUrl = null;
          _selectedAvatarFile = null;
        });
        NovaToast.showInfo(context, 'Foto profilo rimossa');
      },
    );

    if (selectedFile == null) return;

    // Show cropper
    final croppedFile = await AvatarCropper.show(context, selectedFile);

    if (croppedFile == null) return;

    // Upload to Supabase Storage
    setState(() {
      _isUploadingAvatar = true;
      _uploadProgress = 0.0;
    });

    try {
      final uploadService = ref.read(avatarUploadServiceProvider);
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final avatarUrl = await uploadService.uploadAvatar(
        userId: userId,
        imageFile: croppedFile,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _avatarUrl = avatarUrl;
          _selectedAvatarFile = croppedFile;
          _isUploadingAvatar = false;
        });

        NovaToast.showSuccess(context, 'Foto profilo caricata ✓');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });

        NovaToast.showError(
          context,
          'Errore nel caricamento: ${e.toString()}',
        );
      }
    }
  }

  /// Auto-populate name from email using Supabase RPC
  /// Example: giovanni.rossi@galileimoro.edu.it → "Giovanni Rossi"
  Future<void> _autoPopulateName() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(profileRepositoryProvider);
      final supabase = ref.read(supabaseClientProvider);

      final email = supabase.auth.currentUser?.email ?? '';
      final parsedName = await repository.parseNameFromEmail(email);

      if (parsedName != null && mounted) {
        _nameController.text = parsedName;
      }
    } catch (e) {
      // Silently fail - user can enter name manually
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Save profile and navigate to Feed
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedClass == null) {
      NovaToast.showError(
        context,
        'Seleziona la tua classe per continuare',
      );
      return;
    }

    // Check if username is available
    if (_isUsernameAvailable == false) {
      NovaToast.showError(
        context,
        'Lo username scelto non è disponibile',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final createProfileUseCase = ref.read(createProfileUseCaseProvider);
      final supabase = ref.read(supabaseClientProvider);

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create profile
      final email = supabase.auth.currentUser?.email ?? '';
      await createProfileUseCase(
        userId: userId,
        email: email,
        fullName: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        classYear: _selectedClass!,
        avatarUrl: _avatarUrl, // Include avatar URL if uploaded
      );

      if (mounted) {
        NovaToast.showSuccess(context, 'Profilo creato ✓');

        // Invalidate profile provider so _ProfileCheckGuard re-evaluates
        // and navigates to MainFeedScreen (since profile is now complete)
        ref.invalidate(currentProfileProvider);
      }
    } catch (e) {
      if (mounted) {
        NovaToast.showError(
          context,
          'Errore nel salvataggio: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Skip setup (navigate to Feed with incomplete profile)
  Future<void> _skipSetup() async {
    // Username is still required even when skipping
    final usernameError = Validators.validateUsername(_usernameController.text);
    if (usernameError != null) {
      NovaToast.showError(
          context, 'Inserisci uno username valido prima di continuare');
      return;
    }

    // Check if username is available
    if (_isUsernameAvailable == false) {
      NovaToast.showError(context, 'Lo username scelto non è disponibile');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final createProfileUseCase = ref.read(createProfileUseCaseProvider);
      final supabase = ref.read(supabaseClientProvider);

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create incomplete profile (class = null)
      final email = supabase.auth.currentUser?.email ?? '';
      await createProfileUseCase(
        userId: userId,
        email: email,
        fullName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'Utente Nova',
        username: _usernameController.text.trim(),
        classYear: null, // Incomplete profile
      );

      if (mounted) {
        NovaToast.showInfo(
          context,
          'Profilo salvato. Completa più tardi!',
        );

        // Invalidate profile provider so _ProfileCheckGuard re-evaluates
        // and navigates to MainFeedScreen (profile created, even if incomplete)
        ref.invalidate(currentProfileProvider);
      }
    } catch (e) {
      if (mounted) {
        NovaToast.showError(
          context,
          'Errore: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background(context),
      appBar: AppBar(
        backgroundColor: NovaColors.surface(context),
        elevation: 0,
        automaticallyImplyLeading: false, // No back button
        actions: [
          // Skip button
          TextButton(
            onPressed: _isSaving ? null : _skipSetup,
            child: Text(
              'Skip per ora',
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(NovaSpacing.xl),
            children: [
              // Title
              Text(
                'Completa il tuo profilo',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: NovaColors.textPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: NovaSpacing.s),

              // Subtitle
              Text(
                'Pochi passaggi per iniziare',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NovaColors.textSecondary(context),
                    ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: NovaSpacing.xxl),

              // Avatar with edit button
              Center(
                child: Stack(
                  children: [
                    // Avatar (skeleton, initials, or uploaded image)
                    if (_isLoading)
                      const SkeletonAvatar()
                    else if (_isUploadingAvatar)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Show previous avatar or initials while uploading
                          _selectedAvatarFile != null
                              ? CircleAvatar(
                                  radius: 64,
                                  backgroundImage:
                                      FileImage(_selectedAvatarFile!),
                                )
                              : AvatarInitials(
                                  fullName: _nameController.text.isNotEmpty
                                      ? _nameController.text
                                      : 'Utente Nova',
                                ),
                          // Upload progress overlay
                          Container(
                            width: 128,
                            height: 128,
                            decoration: BoxDecoration(
                              color:
                                  NovaColors.overlayDark.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                                SizedBox(height: NovaSpacing.s),
                                Text(
                                  '${(_uploadProgress * 100).toInt()}%',
                                  style: NovaTextStyles.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else if (_selectedAvatarFile != null)
                      CircleAvatar(
                        radius: 64,
                        backgroundImage: FileImage(_selectedAvatarFile!),
                      )
                    else
                      AvatarInitials(
                        fullName: _nameController.text.isNotEmpty
                            ? _nameController.text
                            : 'Utente Nova',
                      ),

                    // Edit button overlay
                    if (!_isLoading && !_isUploadingAvatar)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _handleAvatarPicker,
                          borderRadius: BorderRadius.circular(NovaRadius.full),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: NovaColors.primary(context),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: NovaColors.surface(context),
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: NovaSpacing.xxl),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome e Cognome *',
                  hintText: 'Es: Giovanni Rossi',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(NovaRadius.m),
                  ),
                  filled: true,
                  fillColor: NovaColors.surface(context),
                ),
                validator: Validators.validateName,
                textCapitalization: TextCapitalization.words,
                enabled: !_isSaving,
              ),

              SizedBox(height: NovaSpacing.l),

              // Username field
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username *',
                  hintText: 'Es: giovanni_rossi',
                  prefixIcon: const Icon(Icons.alternate_email),
                  suffixIcon: _buildUsernameStatusIcon(),
                  helperText: _isUsernameAvailable == false
                      ? 'Username non disponibile'
                      : null,
                  helperStyle: TextStyle(
                    color: Colors.red,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(NovaRadius.m),
                  ),
                  filled: true,
                  fillColor: NovaColors.surface(context),
                ),
                validator: Validators.validateUsername,
                onChanged: _onUsernameChanged,
                enabled: !_isSaving,
                autocorrect: false,
                textInputAction: TextInputAction.next,
              ),

              SizedBox(height: NovaSpacing.l),

              // Class picker
              InkWell(
                onTap: _isSaving
                    ? null
                    : () async {
                        final selectedClass = await ClassPickerBottomSheet.show(
                          context,
                          selectedClass: _selectedClass,
                        );

                        if (selectedClass != null) {
                          setState(() {
                            _selectedClass = selectedClass;
                          });
                        }
                      },
                borderRadius: BorderRadius.circular(NovaRadius.m),
                child: Container(
                  padding: EdgeInsets.all(NovaSpacing.l),
                  decoration: BoxDecoration(
                    color: NovaColors.surface(context),
                    borderRadius: BorderRadius.circular(NovaRadius.m),
                    border: Border.all(
                      color: NovaColors.border(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        color: NovaColors.textSecondary(context),
                      ),
                      SizedBox(width: NovaSpacing.l),
                      Expanded(
                        child: Text(
                          _selectedClass != null
                              ? getClassById(_selectedClass!)?.displayName ??
                                  'Classe non trovata'
                              : 'Seleziona classe *',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: _selectedClass != null
                                        ? NovaColors.textPrimary(context)
                                        : NovaColors.textSecondary(context),
                                  ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: NovaColors.textSecondary(context),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: NovaSpacing.xxl),

              // Save button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedClass != null && !_isSaving
                      ? _saveProfile
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NovaColors.primary(context),
                    disabledBackgroundColor: NovaColors.textSecondary(context)
                        .withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(NovaRadius.m),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Salva e inizia',
                          style: NovaTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
