import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';

class FaqsScreen extends StatefulWidget {
  const FaqsScreen({super.key});

  @override
  State<FaqsScreen> createState() => _FaqsScreenState();
}

class _FaqsScreenState extends State<FaqsScreen> {
  int _expandedIndex = 0; // First one expanded by default as in Image 5

  final List<Map<String, String>> _faqItems = const [
    {
      'q': 'How do I place a bid?',
      'a': 'Navigate to any auction listing and tap the "Place Bid" button. You\'ll need to have sufficient Bidly Wallet balance. Enter your bid amount (must be above the current highest bid and meet the minimum increment), then confirm. You\'ll be notified if you are outbid.',
    },
    {
      'q': 'How do I become a seller?',
      'a': 'Tap the "+" icon in the bottom navbar to create your first listing. You can list items for Auction or Direct Sale with photos, description, and price.',
    },
    {
      'q': 'How do refunds work?',
      'a': 'If an item is not received or differs significantly from description, our Buyer Protection guarantees a full refund to your Bidly Wallet within 24 hours of investigation.',
    },
    {
      'q': 'How do I cancel an order?',
      'a': 'You can cancel a direct sale order prior to shipment directly from your Orders tab by tapping "Cancel Order" on the order details screen.',
    },
    {
      'q': 'How do I contact support?',
      'a': 'Our support team is available 24/7 via in-app Live Chat, email at support@bidly.in, or by calling our toll-free hotline 1800-123-4567.',
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
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: const Text(
          'FAQs',
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
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          itemCount: _faqItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, idx) {
            final faq = _faqItems[idx];
            final isExpanded = _expandedIndex == idx;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _expandedIndex = isExpanded ? -1 : idx;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isExpanded ? const Color(0xFF004E54) : AppTheme.border,
                    width: isExpanded ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF004E54),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Q',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            faq['q']!,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                    if (isExpanded) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 38.0),
                        child: Text(
                          faq['a']!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
