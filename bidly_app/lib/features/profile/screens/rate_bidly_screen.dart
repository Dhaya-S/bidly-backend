import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_theme.dart';

class RateBidlyScreen extends StatefulWidget {
  const RateBidlyScreen({super.key});

  @override
  State<RateBidlyScreen> createState() => _RateBidlyScreenState();
}

class _RateBidlyScreenState extends State<RateBidlyScreen> {
  int _rating = 5;
  final _reviewController = TextEditingController();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    if (_rating >= 4) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thank you! Redirecting to Google Play Store... ⭐'),
          backgroundColor: AppTheme.success,
        ),
      );
      final playStoreUri = Uri.parse('market://details?id=com.bidly.bidly_app');
      final webPlayStoreUri = Uri.parse('https://play.google.com/store/apps/details?id=com.bidly.bidly_app');
      try {
        if (await canLaunchUrl(playStoreUri)) {
          await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(webPlayStoreUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        // Fallback gracefully if store is not available
      }
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thank you for your valuable feedback! Our team will review your comments.'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }

    if (mounted) {
      if (nav.canPop()) {
        nav.pop();
      } else {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: const Text(
          'Rate Bidly',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppTheme.border.withValues(alpha: 0.7),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              const Text(
                'How do you like Bidly?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your feedback helps us improve the experience for everyone',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // 5 Stars Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starNum = index + 1;
                  final isFilled = starNum <= _rating;

                  return GestureDetector(
                    onTap: () => setState(() => _rating = starNum),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Icon(
                        isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 40,
                        color: const Color(0xFFFFB300),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Review Input
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Leave a review (optional)',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reviewController,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Tell us what you love or what we can improve...',
                  alignLabelWithHint: true,
                ),
              ),
              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Submit Review',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
