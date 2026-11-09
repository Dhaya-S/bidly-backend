import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  final List<Map<String, String>> _clauses = const [
    {
      'title': '1. Acceptance of Terms',
      'body': 'By accessing or using Bidly, you agree to be bound by these Terms and Conditions and all applicable laws and regulations. If you do not agree with any of these terms, you are prohibited from using the platform.',
    },
    {
      'title': '2. User Accounts',
      'body': 'You must be at least 18 years old to create an account. You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.',
    },
    {
      'title': '3. Marketplace Rules',
      'body': 'Bidly is a peer-to-peer marketplace. Sellers are responsible for the accuracy of their listings. Bidly does not guarantee the quality, safety, or legality of items listed. All transactions are between buyers and sellers directly.',
    },
    {
      'title': '4. Bidding & Auctions',
      'body': 'All bids placed are binding. Winning bidders are obligated to complete the purchase. Bid manipulation, shill bidding, or other fraudulent bidding activity is strictly prohibited.',
    },
    {
      'title': '5. Payments & Fees',
      'body': 'Bidly Wallet is used for auction participation. Funds are held in escrow until delivery is confirmed. Platform fees are deducted automatically before payout to sellers.',
    },
    {
      'title': '6. Prohibited Items',
      'body': 'Listings for illegal goods, counterfeit items, weapons, hazardous materials, and adult content are strictly prohibited. Violation will result in immediate account termination.',
    },
    {
      'title': '7. Termination',
      'body': 'Bidly reserves the right to terminate or suspend accounts at its sole discretion for any violation of these terms, fraudulent activity, or behavior deemed harmful to the platform or its users.',
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
          'Terms & Conditions',
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
            ..._clauses.map((clause) {
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
                      clause['title']!,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      clause['body']!,
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
