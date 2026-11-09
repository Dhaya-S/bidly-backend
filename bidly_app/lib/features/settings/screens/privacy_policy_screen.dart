import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  final List<Map<String, String>> _sections = const [
    {
      'title': 'Information We Collect',
      'body': 'We collect information you provide (name, email, phone, address), transaction data, device information, and usage patterns to improve our services and personalize your experience.',
    },
    {
      'title': 'How We Use Your Data',
      'body': 'Your data is used to operate and improve Bidly, facilitate transactions, communicate with you, prevent fraud, and comply with legal obligations. We do not sell your personal data to third parties.',
    },
    {
      'title': 'Data Sharing',
      'body': 'We may share your information with payment processors, logistics partners, and when required by law. All third-party partners are bound by strict data protection agreements.',
    },
    {
      'title': 'Your Rights',
      'body': 'You have the right to access, correct, or delete your personal data. You may also opt out of marketing communications at any time. Contact our support team to exercise these rights.',
    },
    {
      'title': 'Data Security',
      'body': 'We implement industry-standard encryption and security measures to protect your data. However, no method of transmission over the internet is 100% secure.',
    },
    {
      'title': 'Cookies',
      'body': 'Bidly uses cookies and similar technologies to enhance your experience. You can control cookie settings through your device preferences.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } else { Navigator.of(context).maybePop(); } },
        ),
        title: const Text(
          'Privacy Policy',
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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            const Text(
              'Last updated: 1 June 2026',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ..._sections.map((sec) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sec['title']!,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sec['body']!,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
