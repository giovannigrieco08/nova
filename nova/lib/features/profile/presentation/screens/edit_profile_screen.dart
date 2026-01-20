// Screen: EditProfileScreen
// Feature: 002-profile-setup
// Purpose: Edit existing profile with pre-populated fields

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../widgets/class_picker_bottom_sheet.dart';
import '../widgets/avatar_picker_bottom_sheet.dart';
import '../widgets/avatar_cropper.dart';
import '../widgets/banner_picker_bottom_sheet.dart';
import '../widgets/banner_cropper.dart';

/// Edit profile screen for existing users
///
/// **Features**:
/// - All fields pre-populated from existing profile
/// - Avatar upload/change/remove
/// - Name editing
/// - Class selection
/// - Bio editing (max 150 chars with live counter)
/// - Pronouns selection (optional)
/// - Save button (updates existing profile)
/// - Navigate back after save
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

  String? _selectedClass;
  String? _avatarUrl;
  String? _originalAvatarUrl; // Track original URL for cache eviction
  File? _selectedAvatarFile;
  String? _bannerUrl;
  String? _originalBannerUrl; // Track original URL for cache eviction
  File? _selectedBannerFile;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingBanner = false;
  double _uploadProgress = 0.0;
  double _bannerUploadProgress = 0.0;
  int _bioCharCount = 0;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
    _bioController.addListener(_updateBioCharCount);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Update bio character count
  void _updateBioCharCount() {
    setState(() {
      _bioCharCount = _bioController.text.length;
    });
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

        NovaToast.showSuccess(context, 'Foto profilo aggiornata ✓');
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

  /// Handle banner selection and upload
  Future<void> _handleBannerPicker() async {
    // Show picker bottom sheet
    final selectedFile = await BannerPickerBottomSheet.show(
      context,
      hasExistingBanner: _bannerUrl != null || _selectedBannerFile != null,
      onRemoveBanner: () {
        setState(() {
          _bannerUrl = null;
          _selectedBannerFile = null;
        });
        NovaToast.showInfo(context, 'Banner rimosso');
      },
    );

    if (selectedFile == null) return;

    // Show cropper with 3:1 aspect ratio
    final croppedFile = await BannerCropper.show(context, selectedFile);

    if (croppedFile == null) return;

    // Upload to Supabase Storage
    setState(() {
      _isUploadingBanner = true;
      _bannerUploadProgress = 0.0;
    });

    try {
      final uploadService = ref.read(bannerUploadServiceProvider);
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final bannerUrl = await uploadService.uploadBanner(
        userId: userId,
        imageFile: croppedFile,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _bannerUploadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _bannerUrl = bannerUrl;
          _selectedBannerFile = croppedFile;
          _isUploadingBanner = false;
        });

        NovaToast.showSuccess(context, 'Banner aggiornato ✓');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingBanner = false;
        });

        NovaToast.showError(
          context,
          'Errore nel caricamento banner: ${e.toString()}',
        );
      }
    }
  }

  /// Load existing profile and pre-populate fields
  Future<void> _loadExistingProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profileAsync = ref.read(currentProfileProvider);
      await profileAsync.when(
        data: (profile) async {
          if (mounted) {
            setState(() {
              _nameController.text = profile.fullName;
              _selectedClass = profile.classYear;
              _avatarUrl = profile.avatarUrl;
              _originalAvatarUrl = profile.avatarUrl; // Save for cache eviction
              _bannerUrl = profile.bannerUrl;
              _originalBannerUrl = profile.bannerUrl; // Save for cache eviction
              _bioController.text = profile.bio ?? '';
              _bioCharCount = profile.bio?.length ?? 0;
              _isLoading = false;
            });
          }
        },
        loading: () async {},
        error: (error, stack) async {
          if (mounted) {
            NovaToast.showError(
              context,
              'Errore nel caricamento profilo: ${error.toString()}',
            );
            Navigator.of(context).pop();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        NovaToast.showError(context, 'Errore: ${e.toString()}');
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Save profile changes
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(profileRepositoryProvider);
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Update profile
      await repository.updateProfile(userId, {
        'full_name': _nameController.text.trim(),
        'class': _selectedClass,
        'avatar_url': _avatarUrl,
        'banner_url': _bannerUrl,
        'bio': _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
      });

      // Clear CachedNetworkImage cache for avatar to force refresh
      // Evict BOTH old and new URLs to ensure fresh image display
      if (_originalAvatarUrl != null && _originalAvatarUrl!.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(_originalAvatarUrl!);
      }
      if (_avatarUrl != null && _avatarUrl!.isNotEmpty && _avatarUrl != _originalAvatarUrl) {
        await CachedNetworkImage.evictFromCache(_avatarUrl!);
      }

      // Clear CachedNetworkImage cache for banner to force refresh
      if (_originalBannerUrl != null && _originalBannerUrl!.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(_originalBannerUrl!);
      }
      if (_bannerUrl != null && _bannerUrl!.isNotEmpty && _bannerUrl != _originalBannerUrl) {
        await CachedNetworkImage.evictFromCache(_bannerUrl!);
      }

      // Invalidate BOTH profile providers to refresh data everywhere
      ref.invalidate(currentProfileProvider);
      ref.invalidate(profileNotifierProvider);

      if (mounted) {
        NovaToast.showSuccess(context, 'Profilo aggiornato ✓');
        Navigator.of(context).pop(); // Navigate back
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background(context),
      appBar: AppBar(
        backgroundColor: NovaColors.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: NovaColors.textPrimary(context)),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Modifica profilo',
          style: NovaTextStyles.h3.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ),
        actions: [
          // Save button
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: NovaColors.primary(context),
                    ),
                  )
                : Text(
                    'Salva',
                    style: NovaTextStyles.bodyLarge.copyWith(
                      color: NovaColors.primary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Banner section with edit overlay
                    _buildBannerSection(context),

                    SizedBox(height: NovaSpacing.xl),

                    // Avatar with edit button (centered below banner)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: NovaSpacing.xl),
                      child: Center(
                      child: Stack(
                        children: [
                          // Avatar (skeleton, initials, or uploaded image)
                          if (_isUploadingAvatar)
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
                                    color: Colors.black.withValues(alpha: 0.6),
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
                          else if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                            CircleAvatar(
                              radius: 64,
                              backgroundImage: NetworkImage(_avatarUrl!),
                              onBackgroundImageError: (_, __) {},
                            )
                          else
                            AvatarInitials(
                              fullName: _nameController.text.isNotEmpty
                                  ? _nameController.text
                                  : 'Utente Nova',
                            ),

                          // Edit button overlay
                          if (!_isUploadingAvatar)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _handleAvatarPicker,
                                borderRadius:
                                    BorderRadius.circular(NovaRadius.full),
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
                    ),

                    SizedBox(height: NovaSpacing.xxl),

                    // Form fields with horizontal padding
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: NovaSpacing.xl),
                      child: Column(
                        children: [
                    // Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nome e Cognome *',
                        hintText: 'Giovanni Rossi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(NovaRadius.m),
                          borderSide: BorderSide(color: NovaColors.border(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(NovaRadius.m),
                          borderSide: BorderSide(color: NovaColors.border(context)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(NovaRadius.m),
                          borderSide: BorderSide(color: NovaColors.primary(context), width: 2),
                        ),
                      ),
                      validator: Validators.validateName,
                      enabled: !_isSaving,
                    ),

                    SizedBox(height: NovaSpacing.l),

                    // Class picker
                    InkWell(
                      onTap: _isSaving
                          ? null
                          : () async {
                              final selectedClass =
                                  await ClassPickerBottomSheet.show(
                                context,
                                selectedClass: _selectedClass,
                              );

                              if (selectedClass != null && mounted) {
                                setState(() {
                                  _selectedClass = selectedClass;
                                });
                              }
                            },
                      child: Container(
                        padding: EdgeInsets.all(NovaSpacing.l),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: NovaColors.border(context),
                          ),
                          borderRadius: BorderRadius.circular(NovaRadius.m),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedClass != null
                                  ? getClassById(_selectedClass!)
                                          ?.displayName ??
                                      'Classe non trovata'
                                  : 'Seleziona classe',
                              style: NovaTextStyles.bodyLarge.copyWith(
                                color: _selectedClass != null
                                    ? NovaColors.textPrimary(context)
                                    : NovaColors.textSecondary(context),
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

                    SizedBox(height: NovaSpacing.l),

                    // Bio field
                    TextFormField(
                      controller: _bioController,
                      decoration: InputDecoration(
                        labelText: 'Bio (opzionale)',
                        hintText: 'Racconta qualcosa di te...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(NovaRadius.m),
                          borderSide: BorderSide(color: NovaColors.border(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(NovaRadius.m),
                          borderSide: BorderSide(color: NovaColors.border(context)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(NovaRadius.m),
                          borderSide: BorderSide(color: NovaColors.primary(context), width: 2),
                        ),
                        helperText: '$_bioCharCount/150 caratteri',
                        helperStyle: TextStyle(
                          color: _bioCharCount > 150
                              ? NovaColors.error(context)
                              : NovaColors.textSecondary(context),
                        ),
                      ),
                      maxLines: 3,
                      maxLength: 150,
                      validator: Validators.validateBio,
                      enabled: !_isSaving,
                    ),

                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Build banner section with edit overlay
  Widget _buildBannerSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bannerHeight = screenWidth / 3.0; // 3:1 aspect ratio

    return GestureDetector(
      onTap: _isUploadingBanner || _isSaving ? null : _handleBannerPicker,
      child: Stack(
        children: [
          // Banner (gradient, file, or network image)
          if (_isUploadingBanner)
            Stack(
              children: [
                // Show previous banner or gradient while uploading
                _buildBannerImage(context, screenWidth, bannerHeight),
                // Upload progress overlay
                Container(
                  width: screenWidth,
                  height: bannerHeight,
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(height: NovaSpacing.s),
                      Text(
                        '${(_bannerUploadProgress * 100).toInt()}%',
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
          else
            _buildBannerImage(context, screenWidth, bannerHeight),

          // Edit icon overlay (bottom right)
          if (!_isUploadingBanner && !_isSaving)
            Positioned(
              bottom: NovaSpacing.s,
              right: NovaSpacing.s,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build banner image (gradient fallback, file, or network)
  Widget _buildBannerImage(BuildContext context, double width, double height) {
    // Show local file if selected
    if (_selectedBannerFile != null) {
      return Image.file(
        _selectedBannerFile!,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }

    // Show network image if URL exists
    if (_bannerUrl != null && _bannerUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _bannerUrl!,
        cacheKey: _bannerUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildBannerGradient(width, height),
        errorWidget: (context, url, error) => _buildBannerGradient(width, height),
      );
    }

    // Fallback gradient
    return _buildBannerGradient(width, height);
  }

  /// Build default banner gradient
  Widget _buildBannerGradient(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [NovaColors.brandViolet, NovaColors.brandPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
