import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import 'bank_account_screen.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  List<Map<String, dynamic>> _methods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final user = ref.read(authProvider).user;

    // Check saved UPI
    String upiDetail = prefs.getString('saved_upi_vpa') ?? prefs.getString('payout_upi_id') ?? '';
    if (upiDetail.isEmpty) {
      if (user?.phone != null && user!.phone.isNotEmpty) {
        upiDetail = '${user.phone}@upi';
      } else if (user?.email != null && user!.email!.isNotEmpty) {
        upiDetail = '${user.email!.split('@').first}@upi';
      } else {
        upiDetail = 'user@upi';
      }
    }

    final bankName = prefs.getString('payout_bank_name') ?? 'HDFC Bank';
    final rawAccount = prefs.getString('payout_account_number') ?? '••••8789';
    final maskedAccount = rawAccount.length > 4 ? '••••${rawAccount.substring(rawAccount.length - 4)}' : rawAccount;

    if (mounted) {
      setState(() {
        _methods = [
          {
            'id': 'upi',
            'type': 'UPI (Instant / AutoPay)',
            'detail': upiDetail,
            'icon': Icons.phone_android_rounded,
            'isDefault': true,
          },
          {
            'id': 'bank',
            'type': 'Bank Account (Payouts & Refunds)',
            'detail': '$bankName — $maskedAccount',
            'icon': Icons.account_balance_outlined,
            'isDefault': false,
          },
          {
            'id': 'card',
            'type': 'Cards & NetBanking',
            'detail': 'Razorpay 256-bit Secure Gateway',
            'icon': Icons.credit_card_rounded,
            'isDefault': false,
          },
        ];
        _isLoading = false;
      });
    }
  }

  void _promptAddUpi() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add UPI ID (VPA)',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Virtual Payment Address (e.g. mobile@okhdfcbank, name@upi)',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'yourname@upi',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isEmpty || !val.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid UPI ID with @ symbol')),
                );
                return;
              }
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('saved_upi_vpa', val);
              await prefs.setString('payout_upi_id', val);
              await _loadPaymentMethods();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('UPI ID updated successfully!'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004E54),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save UPI', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showCardInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F6F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.security_rounded, color: Color(0xFF004E54), size: 24),
                ),
                const SizedBox(width: 14),
                const Text(
                  'PCI-DSS Secure Payments',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Under Reserve Bank of India (RBI) tokenization guidelines, debit and credit cards are entered directly into the secure Razorpay 256-bit encrypted gateway during wallet top-up or instant checkout. Bidly never stores your raw card numbers or CVV on disk.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004E54),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Understood', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPaymentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Payment Method',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildModalOption(
              'UPI ID (VPA)',
              'e.g. yourname@upi',
              Icons.phone_android_rounded,
              () {
                Navigator.pop(ctx);
                _promptAddUpi();
              },
            ),
            const SizedBox(height: 10),
            _buildModalOption(
              'Credit / Debit Card',
              'Visa, Mastercard, RuPay via Razorpay',
              Icons.credit_card_rounded,
              () {
                Navigator.pop(ctx);
                _showCardInfo();
              },
            ),
            const SizedBox(height: 10),
            _buildModalOption(
              'Bank Account (Payouts)',
              'Manage Account number & IFSC for withdrawals',
              Icons.account_balance_outlined,
              () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BankAccountScreen()),
                ).then((_) => _loadPaymentMethods());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalOption(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF004E54), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textHint),
          ],
        ),
      ),
    );
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
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } else { Navigator.of(context).maybePop(); } },
        ),
        title: const Text(
          'Payment Methods',
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF004E54)))
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      children: [
                        const Text(
                          'SAVED METHODS',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            children: List.generate(_methods.length, (idx) {
                              final item = _methods[idx];
                              final isLast = idx == _methods.length - 1;

                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (item['id'] == 'bank') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const BankAccountScreen()),
                                        ).then((_) => _loadPaymentMethods());
                                      } else if (item['id'] == 'upi') {
                                        _promptAddUpi();
                                      } else if (item['id'] == 'card') {
                                        _showCardInfo();
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F4F6),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              item['icon'] as IconData,
                                              color: const Color(0xFF004E54),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['type'] as String,
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  item['detail'] as String,
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 11.5,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (item['isDefault'] == true)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8F6F5),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Primary',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF004E54),
                                                ),
                                              ),
                                            ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textHint),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!isLast)
                                    const Divider(height: 1, indent: 68, endIndent: 16),
                                ],
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // + Add Payment Method Button
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _showAddPaymentModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004E54),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          '+ Add Payment Method',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
