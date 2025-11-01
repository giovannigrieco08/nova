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
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Email text controller
  final _emailController = TextEditingController();

  // Token controller (for debug manual verification)
  final _tokenController = TextEditingController();

  // Loading state (for button)
  bool _isLoading = false;

  // Success state (magic link sent)
  bool _showSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  /// Handle "Send Magic Link" button press
  Future<void> _handleSendMagicLink() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Get email from controller
    final email = _emailController.text.trim();

    // Set loading state
    setState(() {
      _isLoading = true;
      _showSuccess = false;
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
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
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
        const SnackBar(
          content: Text('Please paste a token first'),
          backgroundColor: Colors.orange,
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
          const SnackBar(
            content: Text('✅ Token verified! Logging in...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
            backgroundColor: Colors.red,
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
            padding: const EdgeInsets.all(24.0),
            child: _showSuccess ? _buildSuccessView() : _buildLoginForm(),
          ),
        ),
      ),
    );
  }

  /// Build login form (email input + button)
  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App logo
          const NovaLogo.extraLarge(),
          const SizedBox(height: 24),

          // Title
          Text(
            'Welcome to Nova',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Sign in with your school email',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Email input field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'your.name@galileimoro.edu.it',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) => EmailValidator.validate(value),
            enabled: !_isLoading,
          ),

          const SizedBox(height: 24),

          // Send magic link button
          FilledButton(
            onPressed: _isLoading ? null : _handleSendMagicLink,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
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
                : const Text(
                    'Send Magic Link',
                    style: TextStyle(fontSize: 16),
                  ),
          ),

          const SizedBox(height: 16),

          // Help text
          Text(
            EmailValidator.isDevelopment
                ? 'Development mode: Any valid email accepted'
                : 'Only @galileimoro.edu.it emails are allowed',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: EmailValidator.isDevelopment
                      ? Colors.orange[700]
                      : Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),

          // Debug section (only in development mode)
          if (EmailValidator.isDevelopment) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Debug header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bug_report, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'DEBUG: Manual Token Verification',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Instructions
            Text(
              '1. Send magic link above\n2. Copy token_hash from email URL\n3. Paste here and verify',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Token input field
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Token Hash',
                hintText: 'Paste token_hash from email URL',
                prefixIcon: Icon(Icons.key),
                border: OutlineInputBorder(),
              ),
              enabled: !_isLoading,
              maxLines: 3,
              minLines: 1,
            ),

            const SizedBox(height: 16),

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
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Colors.orange, width: 2),
                foregroundColor: Colors.orange[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build success view
  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success icon
        const Icon(
          Icons.mark_email_read_rounded,
          size: 80,
          color: Colors.green,
        ),
        const SizedBox(height: 24),

        // Title
        Text(
          'Check Your Email',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Email text
        Text(
          'We sent a magic link to:',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Text(
          _emailController.text.trim(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        // Instructions
        Text(
          'Click the link in your email to sign in.\nThe link expires in 15 minutes.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

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
