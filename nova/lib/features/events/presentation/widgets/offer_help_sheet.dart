// Widget: OfferHelpSheet
// Feature: Event Help Requests
// Purpose: Bottom sheet for users to offer help for a specific request
//
// Design: Clean Instagram-like style with:
// - User info display (avatar + name + class)
// - Request description
// - Optional message field
// - Submit button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../providers/event_help_provider.dart';

/// Bottom sheet for offering help on a specific request
class OfferHelpSheet extends ConsumerStatefulWidget {
  final String requestId;
  final String requestDescription;
  final String eventId;

  const OfferHelpSheet({
    super.key,
    required this.requestId,
    required this.requestDescription,
    required this.eventId,
  });

  @override
  ConsumerState<OfferHelpSheet> createState() => _OfferHelpSheetState();
}

class _OfferHelpSheetState extends ConsumerState<OfferHelpSheet> {
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if user already offered
    final hasOfferedAsync = ref.watch(hasUserOfferedProvider(widget.requestId));
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: NovaColors.handleBar,
                      borderRadius: NovaRadius.circularXxs,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Offri il tuo aiuto',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),

                // User info section
                _buildUserInfo(currentUser),
                const SizedBox(height: 16),

                // Request description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NovaColors.helpBackground,
                    borderRadius: NovaRadius.circularXs,
                    border: Border.all(
                      color: NovaColors.helpBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.help_outline,
                        size: 20,
                        color: NovaColors.helpText,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Per:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: NovaColors.helpText,
                              ),
                            ),
                            Text(
                              widget.requestDescription,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Check if already offered
                hasOfferedAsync.when(
                  data: (hasOffered) {
                    if (hasOffered) {
                      return _buildAlreadyOfferedMessage();
                    }
                    return _buildOfferForm();
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, __) => _buildOfferForm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build user info row with avatar, name and class
  Widget _buildUserInfo(User? currentUser) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchUserProfile(currentUser?.id),
      builder: (context, snapshot) {
        final name = snapshot.data?['full_name'] ?? 'Utente';
        final className = snapshot.data?['class'] ?? '';
        final avatarUrl = snapshot.data?['avatar_url'] as String?;

        return Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: NovaColors.brandViolet.withValues(alpha: 0.2),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: NovaColors.brandViolet,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Name and class
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                if (className.isNotEmpty)
                  Text(
                    className,
                    style: const TextStyle(
                      fontSize: 14,
                      color: NovaColors.grayDark,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Fetch user profile data
  Future<Map<String, dynamic>?> _fetchUserProfile(String? userId) async {
    if (userId == null) return null;
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('full_name, class, avatar_url')
          .eq('user_id', userId)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Build the offer form with message field and submit button
  Widget _buildOfferForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Message field (optional)
        TextField(
          controller: _messageController,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: 'Scrivi un messaggio (opzionale)',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: NovaColors.grayDark,
            ),
            border: OutlineInputBorder(
              borderRadius: NovaRadius.circularS,
              borderSide: const BorderSide(color: NovaColors.grayMedium),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: NovaRadius.circularS,
              borderSide: const BorderSide(color: NovaColors.grayMedium),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: NovaRadius.circularS,
              borderSide: BorderSide(color: NovaColors.brandViolet),
            ),
            filled: true,
            fillColor: NovaColors.grayLight,
            contentPadding: const EdgeInsets.all(16),
          ),
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),

        // Submit button
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: NovaColors.helpAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: NovaRadius.circularXs,
            ),
            elevation: 0,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Invia offerta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  /// Build message shown when user has already offered
  Widget _buildAlreadyOfferedMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.successLight.withValues(alpha: 0.1),
        borderRadius: NovaRadius.circularS,
        border: Border.all(
          color: NovaColors.successLight,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            size: 24,
            color: NovaColors.successLight,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hai già offerto aiuto',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: NovaColors.successLight,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'La tua offerta è stata inviata. Attendi la risposta dell\'organizzatore.',
                  style: TextStyle(
                    fontSize: 14,
                    color: NovaColors.successLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Handle form submission
  Future<void> _handleSubmit() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devi essere loggato per offrire aiuto')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final notifier = ref.read(helpOffersProvider(widget.requestId).notifier);
      final error = await notifier.createOffer(
        userId: userId,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );

      if (mounted) {
        if (error == null) {
          // Success - close sheet and show confirmation
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offerta inviata con successo!'),
              backgroundColor: NovaColors.successLight,
            ),
          );
        } else {
          // Error - show specific error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
