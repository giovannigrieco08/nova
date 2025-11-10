// =====================================================================
// Nova - Login Screen (MVP Version)
// =====================================================================
// Purpose: First-time user login with magic link authentication
// Architecture: Stateful widget with Riverpod integration
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/utils/email_validator.dart';
import 'package:nova/core/widgets/nova_logo.dart';
import 'package:nova/features/auth/presentation/providers/auth_notifier.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_text_field.dart';

/// Login screen for magic link authentication
///
/// User flow:
/// 1. Enter email (@galileimoro.edu.it)
/// 2. Tap "Send Magic Link" button
/// 3. See success message
/// 4. Check email and click link
/// 5. Automatically navigate to main feed (handled in main.dart)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Email text controller
  final _emailController = TextEditingController();

  // Token controller (for debug manual verification)
  final _tokenController = TextEditingController();

  // Loading state (for button)
  bool _isLoading = false;

  // Success state (magic link sent)
  bool _showSuccess = false;

  // Error state for email field
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  /// Handle "Send Magic Link" button press
  Future<void> _handleSendMagicLink() async {
    // Get email from controller
    final email = _emailController.text.trim();

    // Validate email manually
    final emailValidation = EmailValidator.validate(email);
    if (emailValidation != null) {
      setState(() {
        _emailError = emailValidation;
      });
      return;
    }

    // Set loading state
    setState(() {
      _isLoading = true;
      _showSuccess = false;
      _emailError = null; // Clear any previous errors
    });

    try {
      // Send magic link via auth notifier
      final success =
          await ref.read(authNotifierProvider.notifier).sendMagicLink(email);

      if (success && mounted) {
        // Show success message
        setState(() {
          _showSuccess = true;
        });

        // Show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Magic link sent to $email'),
            backgroundColor: NovaColors.success(context),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Error handling (state is already updated by notifier)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: NovaColors.error(context),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Handle manual token verification (DEBUG only)
  ///
  /// Used for testing magic link verification without deep linking.
  /// User manually copies token_hash from email URL and pastes here.
  Future<void> _handleManualVerification() async {
    // Get token from controller
    final token = _tokenController.text.trim();

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please paste a token first'),
          backgroundColor: NovaColors.warning(context),
        ),
      );
      return;
    }

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // Construct URI with token
      // Format: novaapp://auth/callback?token_hash=XXX&type=magiclink
      final uri = Uri.parse(
        'novaapp://auth/callback?token_hash=$token&type=magiclink',
      );

      // Verify via auth notifier
      final success =
          await ref.read(authNotifierProvider.notifier).verifyMagicLink(uri);

      if (success && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Token verified! Logging in...'),
            backgroundColor: NovaColors.success(context),
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigation will be handled automatically by AuthGuard
        // when auth state changes to AuthStateAuthenticated
      }
    } catch (e) {
      // Error handling
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Verification failed: ${e.toString()}'),
            backgroundColor: NovaColors.error(context),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(NovaSpacing.xxl),
            child: _showSuccess ? _buildSuccessView() : _buildLoginForm(),
          ),
        ),
      ),
    );
  }

  /// Build login form (email input + button)
  Widget _buildLoginForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // App logo
        const NovaLogo.extraLarge(),
        const SizedBox(height: NovaSpacing.xxl),

        // Title
        Text(
          'Welcome to Nova',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NovaSpacing.s),

        // Subtitle
        Text(
          'Sign in with your school email',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NovaSpacing.xxxl),

        // Email input field (adaptive: native CupertinoTextField on iOS, Material on Android)
        AdaptiveTextField(
          controller: _emailController,
          label: 'Email',
          placeholder: 'your.name@galileimoro.edu.it',
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          onChanged: (_) {
            // Clear error when user types
            if (_emailError != null) {
              setState(() {
                _emailError = null;
              });
            }
          },
        ),

        const SizedBox(height: NovaSpacing.xxl),

        // Send magic link button
        FilledButton(
            onPressed: _isLoading ? null : _handleSendMagicLink,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: NovaSpacing.l),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Send Magic Link',
                    style: NovaTextStyles.bodyLarge,
                  ),
        ),

        const SizedBox(height: NovaSpacing.l),

        // Help text
        Text(
            EmailValidator.isDevelopment
                ? 'Development mode: Any valid email accepted'
                : 'Only @galileimoro.edu.it emails are allowed',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: EmailValidator.isDevelopment
                      ? NovaColors.warning(context)
                      : NovaColors.textSecondary(context),
                ),
            textAlign: TextAlign.center,
        ),

        // Debug section (only in development mode)
        if (EmailValidator.isDevelopment) ...[
          const SizedBox(height: NovaSpacing.xxxl),
          const Divider(),
          const SizedBox(height: NovaSpacing.l),

          // Debug header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bug_report, color: NovaColors.warning(context), size: 20),
              const SizedBox(width: NovaSpacing.s),
              Text(
                'DEBUG: Manual Token Verification',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: NovaColors.warning(context),
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),

          const SizedBox(height: NovaSpacing.m),

          // Instructions
          Text(
            '1. Send magic link above\n2. Copy token_hash from email URL\n3. Paste here and verify',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NovaColors.textSecondary(context),
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: NovaSpacing.l),

          // Token input field (adaptive)
          AdaptiveTextField(
            controller: _tokenController,
            label: 'Token Hash',
            placeholder: 'Paste token_hash from email URL',
            maxLines: 3,
          ),

          const SizedBox(height: NovaSpacing.l),

          // Verify button
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleManualVerification,
            icon: _isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Verify Token'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: NovaSpacing.m),
              side: BorderSide(color: NovaColors.warning(context), width: 2),
              foregroundColor: NovaColors.warning(context),
            ),
          ),
        ],
      ],
    );
  }

  /// Build success view
  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success icon
        Icon(
          Icons.mark_email_read_rounded,
          size: 80,
          color: NovaColors.success(context),
        ),
        const SizedBox(height: NovaSpacing.xxl),

        // Title
        Text(
          'Check Your Email',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NovaSpacing.l),

        // Email text
        Text(
          'We sent a magic link to:',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NovaSpacing.s),

        Text(
          _emailController.text.trim(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: NovaColors.primary(context),
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NovaSpacing.xxl),

        // Instructions
        Text(
          'Click the link in your email to sign in.\nThe link expires in 15 minutes.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NovaSpacing.xxxl),

        // "Try again" button
        OutlinedButton(
          onPressed: () {
            setState(() {
              _showSuccess = false;
              _emailController.clear();
            });
          },
          child: const Text('Use a different email'),
        ),
      ],
    );
  }
}
