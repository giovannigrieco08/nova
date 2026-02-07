// =====================================================================
// Nova - Login Screen (MVP Version)
// =====================================================================
// Purpose: First-time user login with magic link authentication
// Architecture: Stateful widget with Riverpod integration
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/exceptions/nova_exceptions.dart';
import 'package:nova/core/utils/email_validator.dart';
import 'package:nova/core/widgets/nova_logo.dart';
import 'package:nova/features/auth/presentation/providers/auth_notifier.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_text_field.dart';

/// Login screen for magic link authentication
///
/// User flow:
/// 1. Enter email address
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

  // Loading state (for button)
  bool _isLoading = false;

  // Success state (magic link sent)
  bool _showSuccess = false;

  // Error state for email field
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
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

        // Show snackbar (with fallback for CupertinoApp on iOS)
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Magic link inviato a $email'),
              backgroundColor: NovaColors.success(context),
              duration: const Duration(seconds: 4),
            ),
          );
        } catch (_) {
          // ScaffoldMessenger not available - success view is already shown
        }
      }
    } catch (e) {
      // Error handling (state is already updated by notifier)
      if (mounted) {
        // Check if it's a rate limit error
        if (e is RateLimitException) {
          _showRateLimitDialog(e.retryAfter ?? const Duration(minutes: 15));
        } else {
          // Use try-catch for ScaffoldMessenger in case we're on iOS with CupertinoApp
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString()),
                backgroundColor: NovaColors.error(context),
                duration: const Duration(seconds: 4),
              ),
            );
          } catch (_) {
            // ScaffoldMessenger not available (e.g., CupertinoApp on iOS)
            // Show error dialog instead
            _showErrorDialog(e.toString());
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Show error dialog (fallback for when ScaffoldMessenger is not available)
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: NovaColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NovaRadius.l),
        ),
        icon: Icon(
          Icons.error_outline,
          size: 48,
          color: NovaColors.error(context),
        ),
        title: Text(
          'Errore',
          style: NovaTypography.headingSmall.copyWith(
            color: NovaColors.textPrimary(context),
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: NovaTypography.bodyMedium.copyWith(
            color: NovaColors.textSecondary(context),
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.primary(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NovaRadius.m),
                ),
                padding: const EdgeInsets.symmetric(vertical: NovaSpacing.m),
              ),
              child: Text(
                'OK',
                style: NovaTypography.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(
          NovaSpacing.l,
          0,
          NovaSpacing.l,
          NovaSpacing.l,
        ),
      ),
    );
  }

  /// Show rate limit dialog when too many login attempts
  void _showRateLimitDialog(Duration retryAfter) {
    final minutes = retryAfter.inMinutes;
    final waitTimeText = minutes == 1 ? '1 minuto' : '$minutes minuti';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: NovaColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NovaRadius.l),
        ),
        icon: Icon(
          Icons.timer_outlined,
          size: 48,
          color: NovaColors.warning(context),
        ),
        title: Text(
          'Troppe richieste',
          style: NovaTypography.headingSmall.copyWith(
            color: NovaColors.textPrimary(context),
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Hai effettuato troppi tentativi di accesso.\n\n'
          'Per motivi di sicurezza, attendi $waitTimeText prima di riprovare.',
          style: NovaTypography.bodyMedium.copyWith(
            color: NovaColors.textSecondary(context),
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.primary(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NovaRadius.m),
                ),
                padding: const EdgeInsets.symmetric(vertical: NovaSpacing.m),
              ),
              child: Text(
                'Ho capito',
                style: NovaTypography.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(
          NovaSpacing.l,
          0,
          NovaSpacing.l,
          NovaSpacing.l,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background(context),
      appBar: AppBar(
        backgroundColor: NovaColors.surface(context),
        elevation: 0,
        title: Text(
          'Accedi',
          style: NovaTextStyles.headingSmall.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ),
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
          'Benvenuto su Nova',
          style: NovaTypography.headingMedium.copyWith(
            color: NovaColors.textPrimary(context),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NovaSpacing.s),

        // Subtitle
        Text(
          'Accedi con la tua email',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NovaColors.textSecondary(context),
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NovaSpacing.xxxl),

        // Email input field (adaptive: native CupertinoTextField on iOS, Material on Android)
        AdaptiveTextField(
          controller: _emailController,
          label: 'Email',
          placeholder: 'la.tua.email@esempio.com',
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
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSendMagicLink,
            style: ElevatedButton.styleFrom(
              backgroundColor: NovaColors.primary(context),
              disabledBackgroundColor:
                  NovaColors.textSecondary(context).withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NovaRadius.m),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Invia Magic Link',
                    style: NovaTextStyles.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
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
          'Controlla la tua email',
          style: NovaTypography.headingMedium.copyWith(
            color: NovaColors.textPrimary(context),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NovaSpacing.l),

        // Email text
        Text(
          'Abbiamo inviato un magic link a:',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: NovaColors.textSecondary(context),
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NovaSpacing.s),

        Text(
          _emailController.text.trim(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: NovaColors.primary(context),
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NovaSpacing.xxl),

        // Instructions
        Text(
          'Clicca il link nella tua email per accedere.\nIl link scade tra 15 minuti.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NovaColors.textSecondary(context),
              ),
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
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: NovaColors.border(context)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NovaRadius.m),
            ),
            padding: const EdgeInsets.symmetric(vertical: NovaSpacing.m),
          ),
          child: Text(
            'Usa un\'altra email',
            style: NovaTextStyles.bodyLarge.copyWith(
              color: NovaColors.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}
