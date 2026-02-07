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
  final _contactController = TextEditingController();
  String _contactType = 'instagram'; // 'instagram' or 'whatsapp'
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if user already offered
    final hasOfferedAsync = ref.watch(hasUserOfferedProvider(widget.requestId));
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
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
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
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

  /// Build the offer form with contact info and message fields
  Widget _buildOfferForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Contact type selector
        const Text(
          'Come può contattarti l\'organizzatore?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),

        // Instagram / WhatsApp toggle
        Row(
          children: [
            Expanded(
              child: _buildContactTypeButton(
                type: 'instagram',
                icon: Icons.camera_alt_outlined,
                label: 'Instagram',
                isSelected: _contactType == 'instagram',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildContactTypeButton(
                type: 'whatsapp',
                icon: Icons.phone_outlined,
                label: 'WhatsApp',
                isSelected: _contactType == 'whatsapp',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Contact info field (required)
        TextField(
          controller: _contactController,
          keyboardType: _contactType == 'whatsapp'
              ? TextInputType.phone
              : TextInputType.text,
          decoration: InputDecoration(
            hintText: _contactType == 'instagram'
                ? '@username'
                : 'Numero WhatsApp',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: NovaColors.grayDark,
            ),
            prefixIcon: Icon(
              _contactType == 'instagram'
                  ? Icons.alternate_email
                  : Icons.phone,
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
        const SizedBox(height: 16),

        // Message field (optional)
        TextField(
          controller: _messageController,
          maxLines: 2,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: 'Messaggio (opzionale)',
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

  /// Build contact type toggle button
  Widget _buildContactTypeButton({
    required String type,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _contactType = type;
          _contactController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? NovaColors.brandViolet.withValues(alpha: 0.1)
              : NovaColors.grayLight,
          borderRadius: NovaRadius.circularS,
          border: Border.all(
            color: isSelected ? NovaColors.brandViolet : NovaColors.grayMedium,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? NovaColors.brandViolet : NovaColors.grayDark,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? NovaColors.brandViolet : NovaColors.grayDark,
              ),
            ),
          ],
        ),
      ),
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

  /// Show snackbar safely (handles missing ScaffoldMessenger in bottom sheets)
  void _showSnackBar(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : NovaColors.successLight,
        ),
      );
    }
  }

  /// Handle form submission
  Future<void> _handleSubmit() async {
    // Close keyboard first
    FocusScope.of(context).unfocus();

    // Validate contact info
    if (_contactController.text.trim().isEmpty) {
      _showSnackBar('Inserisci il tuo contatto per essere ricontattato', isError: true);
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnackBar('Devi essere loggato per offrire aiuto', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final notifier = ref.read(helpOffersProvider(widget.requestId).notifier);
      final error = await notifier.createOffer(
        userId: userId,
        contactType: _contactType,
        contactInfo: _contactController.text.trim(),
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );

      if (mounted) {
        // Close sheet first, then show snackbar on parent scaffold
        Navigator.pop(context, error == null ? 'success' : error);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, 'Errore imprevisto');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
