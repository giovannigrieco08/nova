// Screen: ProfilePhotoViewerScreen
// Feature: 006-user-profile
// Purpose: Full-screen profile photo viewer with blurred background and edit button

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/avatar_picker_bottom_sheet.dart';
import '../widgets/avatar_cropper.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../shared/widgets/nova_toast.dart';

/// Full-screen profile photo viewer with blurred background
///
/// **Features**:
/// - Blurred background using the profile photo
/// - Large circular profile photo centered
/// - Edit button (pencil icon) at bottom-right of photo
/// - Tap anywhere outside photo to dismiss
/// - Edit button opens avatar picker for changing photo
///
/// **Design (Instagram-style)**:
/// - Background: Profile photo with heavy blur effect
/// - Photo: Large circle (70% of screen width) centered
/// - Edit button: White circular button with pencil icon
class ProfilePhotoViewerScreen extends ConsumerStatefulWidget {
  final Profile profile;

  const ProfilePhotoViewerScreen({
    required this.profile,
    super.key,
  });

  @override
  ConsumerState<ProfilePhotoViewerScreen> createState() =>
      _ProfilePhotoViewerScreenState();
}

class _ProfilePhotoViewerScreenState
    extends ConsumerState<ProfilePhotoViewerScreen> {
  bool _isUploadingAvatar = false;
  double _uploadProgress = 0.0;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = widget.profile.avatarUrl;
  }

  /// Handle avatar selection and upload
  Future<void> _handleEditPhoto() async {
    // Show picker bottom sheet
    final selectedFile = await AvatarPickerBottomSheet.show(
      context,
      hasExistingAvatar:
          _currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty,
      onRemoveAvatar: _handleRemoveAvatar,
    );

    if (selectedFile == null || !mounted) return;

    // Show cropper
    final croppedFile = await AvatarCropper.show(context, selectedFile);

    if (croppedFile == null || !mounted) return;

    // Upload to Supabase Storage
    await _uploadAvatar(croppedFile);
  }

  /// Remove avatar
  void _handleRemoveAvatar() async {
    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final repository = ref.read(profileRepositoryProvider);
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Update profile to remove avatar
      await repository.updateProfile(userId, {
        'avatar_url': null,
      });

      // Invalidate profile provider to refresh data
      ref.invalidate(currentProfileProvider);

      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _currentAvatarUrl = null;
          _isUploadingAvatar = false;
        });

        NovaToast.showInfo(context, 'Foto profilo rimossa');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });

        NovaToast.showError(
          context,
          'Errore nella rimozione: ${e.toString()}',
        );
      }
    }
  }

  /// Upload avatar to Supabase Storage
  Future<void> _uploadAvatar(File croppedFile) async {
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

      // Update profile with new avatar URL
      final repository = ref.read(profileRepositoryProvider);
      await repository.updateProfile(userId, {
        'avatar_url': avatarUrl,
      });

      // Invalidate profile provider to refresh data
      ref.invalidate(currentProfileProvider);

      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _currentAvatarUrl = avatarUrl;
          _isUploadingAvatar = false;
        });

        NovaToast.showSuccess(context, 'Foto profilo aggiornata');
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final photoSize = screenSize.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blur the underlying profile screen interface
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),

            // Centered photo with edit button
            SafeArea(
              child: Center(
                child: GestureDetector(
                  // Prevent tap from closing when tapping on photo
                  onTap: () {},
                  child: Stack(
                    children: [
                      // Main profile photo
                      _buildProfilePhoto(photoSize),

                      // Edit button
                      if (!_isUploadingAvatar)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: _buildEditButton(),
                        ),

                      // Upload progress overlay
                      if (_isUploadingAvatar)
                        Positioned.fill(
                          child: _buildUploadOverlay(photoSize),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Close button (X) at top right
            Positioned(
              top: MediaQuery.of(context).padding.top + NovaSpacing.medium,
              right: NovaSpacing.medium,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: EdgeInsets.all(NovaSpacing.small),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build main profile photo
  Widget _buildProfilePhoto(double size) {
    final hasAvatar = _currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: NovaColors.backgroundSecondary(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: hasAvatar
            ? Image.network(
                _currentAvatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (ctx, error, stackTrace) {
                  return _buildInitialsAvatar(size);
                },
              )
            : _buildInitialsAvatar(size),
      ),
    );
  }

  /// Build initials avatar with gradient background
  Widget _buildInitialsAvatar(double size) {
    final initials = _getInitials();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [NovaColors.brandViolet, NovaColors.brandPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: NovaTypography.headingLarge.copyWith(
            color: Colors.white,
            fontSize: size * 0.35,
          ),
        ),
      ),
    );
  }

  /// Extract initials from profile
  String _getInitials() {
    if (widget.profile.fullName.isNotEmpty) {
      final words = widget.profile.fullName.trim().split(RegExp(r'\s+'));
      if (words.length >= 2) {
        return '${words[0][0]}${words[1][0]}'.toUpperCase();
      } else if (words.isNotEmpty) {
        return words[0][0].toUpperCase();
      }
    }

    if (widget.profile.username.length >= 2) {
      return widget.profile.username.substring(0, 2).toUpperCase();
    }

    return widget.profile.username[0].toUpperCase();
  }

  /// Build edit button
  Widget _buildEditButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _handleEditPhoto();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.edit,
          color: Colors.black87,
          size: 24,
        ),
      ),
    );
  }

  /// Build upload progress overlay
  Widget _buildUploadOverlay(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: NovaSpacing.medium),
          Text(
            '${(_uploadProgress * 100).toInt()}%',
            style: NovaTypography.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
