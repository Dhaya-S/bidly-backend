import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/sell_provider.dart';

class SellPreviewScreen extends ConsumerWidget {
  const SellPreviewScreen({super.key});

  Future<void> _handleSubmit(BuildContext context, WidgetRef ref) async {
    final success = await ref.read(sellProvider.notifier).submitListing();
    if (context.mounted) {
      if (success) {
        context.pushReplacement(AppRoutes.sellSuccess);
      } else {
        final err = ref.read(sellProvider).errorMessage ?? 'Failed to list product';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellState = ref.watch(sellProvider);
    final user = ref.watch(authProvider).user;
    final isAuction = sellState.sellingMethod == 'AUCTION';
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final displayPrice = isAuction
        ? currencyFormatter.format(sellState.minimumBid ?? sellState.price)
        : currencyFormatter.format(sellState.price);

    final scopeDisplay = sellState.sellingScope == 'COMMUNITIES'
        ? (sellState.communityName != null ? 'Community: ${sellState.communityName}' : 'Community Only')
        : (sellState.sellingScope == 'CUSTOM_RADIUS' ? '${sellState.targetRadiusKm}km Radius' : 'Global (Home Screen)');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: const Text(
          'Preview Listing',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Step 4/4',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF004E54),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: 1.0,
            backgroundColor: Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF004E54)),
            minHeight: 3,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Review before listing',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Hero Image / Preview Media Card
              Container(
                width: double.infinity,
                height: 230,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                  image: sellState.photos.isNotEmpty
                      ? DecorationImage(
                          image: FileImage(File(sellState.photos.first)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: sellState.photos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: const Color(0xFF004E54).withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            Text(
                              sellState.title.isNotEmpty ? sellState.title : 'Product Image',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: const Color(0xFF004E54).withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : (sellState.photos.length > 1
                        ? Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '1/${sellState.photos.length}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : null),
              ),
              const SizedBox(height: 18),

              // Title and Edit Button Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      sellState.title.isNotEmpty ? sellState.title : 'Product Name',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textSecondary),
                    onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Category • Subcategory Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${sellState.category} • ${sellState.subcategory}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF004E54),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Price & Sell Type Badge Row
              Row(
                children: [
                  Text(
                    displayPrice,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAuction ? const Color(0xFFFFEAEA) : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAuction ? 'Bid' : 'Direct Sale',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isAuction ? const Color(0xFFEF4444) : const Color(0xFF004E54),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Description Text
              Text(
                sellState.description.isNotEmpty
                    ? sellState.description
                    : 'No description provided.',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),

              // Detail Specs Grid Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildSpecItem('Condition', sellState.condition)),
                        Expanded(child: _buildSpecItem('Scope', scopeDisplay)),
                      ],
                    ),
                    if (isAuction) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _buildSpecItem('Bid ends', sellState.auctionEndDate ?? 'TBD')),
                          Expanded(child: _buildSpecItem('End time', sellState.auctionEndTime ?? 'TBD')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _buildSpecItem('Minimum Bid', '₹${(sellState.minimumBid ?? sellState.price).toStringAsFixed(0)}')),
                          Expanded(child: _buildSpecItem('Bid Increment', '₹${(sellState.bidIncrement ?? 100).toStringAsFixed(0)}')),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Seller Profile Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F4F1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline_rounded, color: Color(0xFF004E54), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name != null && user!.name!.isNotEmpty ? user.name! : 'Verified Seller',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '4.9 • Verified Seller',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      user?.city != null && user!.city!.isNotEmpty ? user.city! : 'Chennai',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Publish Listing Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: sellState.isLoading ? null : () => _handleSubmit(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF004E54),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: sellState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'List Product',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
