import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_theme.dart';
import '../providers/wallet_provider.dart';

class MoneyAddedSuccessScreen extends ConsumerWidget {
  final WalletTransaction transaction;
  final bool isFromBidding;

  const MoneyAddedSuccessScreen({
    super.key,
    required this.transaction,
    this.isFromBidding = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountFormatted = '₹${transaction.amountAdded.toInt()}';
    final updatedBalanceFormatted = '₹${transaction.updatedBalance.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Top Close button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppTheme.textPrimary),
                  onPressed: () {
                    ref.read(walletProvider.notifier).fetchWallet();
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),

              const Spacer(flex: 1),

              // Large Success Checkmark Circle
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: Color(0xFF005459), // Deep rich teal
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Money Added!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Big Green Amount
              Text(
                amountFormatted,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF10B981), // Vibrant Green
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Text(
                'Successfully added to BIDLY Wallet',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 32),

              // Transaction Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transaction Details',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildDetailRow('Amount Added', amountFormatted, isBoldValue: true),
                    const SizedBox(height: 12),

                    _buildDetailRow('Transaction ID', transaction.transactionId, isMonospace: true),
                    const SizedBox(height: 12),

                    _buildDetailRow('Updated Balance', updatedBalanceFormatted, isBoldValue: true),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Row(
                          children: const [
                            Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text(
                              'Success',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // If navigated from bidding flow, show Continue Bidding button
              if (isFromBidding) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(walletProvider.notifier).fetchWallet();
                      Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004E54),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue Bidding',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // View Wallet Button
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  onTap: () {
                    ref.read(walletProvider.notifier).fetchWallet();
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop(); // pop success
                    }
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop(); // pop add money back to profile
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                        color: Color(0xFF004E54),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'View Wallet',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF004E54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBoldValue = false, bool isMonospace = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: isMonospace ? 'monospace' : 'Poppins',
            fontSize: isBoldValue ? 13.5 : 12.5,
            fontWeight: isBoldValue ? FontWeight.w700 : FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
