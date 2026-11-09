import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_theme.dart';
import '../providers/wallet_provider.dart';
import 'money_added_success_screen.dart';

class AddMoneyScreen extends ConsumerStatefulWidget {
  final double? minTopUp;

  const AddMoneyScreen({super.key, this.minTopUp});

  @override
  ConsumerState<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends ConsumerState<AddMoneyScreen> {
  late final TextEditingController _amountController;
  int _selectedChipIndex = 0;
  String _selectedPaymentMethod = 'UPI';

  final List<int> _quickAmounts = [500, 1000, 2000, 5000, 10000];

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'UPI',
      'title': 'UPI',
      'subtitle': 'GPay, PhonePe, Paytm',
      'icon': Icons.phone_android_rounded,
    },
    {
      'id': 'DEBIT_CARD',
      'title': 'Debit Card',
      'subtitle': 'Visa, Mastercard, RuPay',
      'icon': Icons.credit_card_outlined,
    },
    {
      'id': 'CREDIT_CARD',
      'title': 'Credit Card',
      'subtitle': 'All major cards accepted',
      'icon': Icons.credit_card_rounded,
    },
    {
      'id': 'NET_BANKING',
      'title': 'Net Banking',
      'subtitle': 'All major banks',
      'icon': Icons.account_balance_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.minTopUp != null && widget.minTopUp! > 0) {
      _amountController = TextEditingController(text: widget.minTopUp!.toInt().toString());
      _selectedChipIndex = -1;
    } else {
      _amountController = TextEditingController(text: '500');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).fetchWallet();
    });
  }

  Timer? _statusPollTimer;
  bool _isCheckingStatus = false;

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _onSelectChip(int index) {
    setState(() {
      _selectedChipIndex = index;
      _amountController.text = _quickAmounts[index].toString();
    });
  }

  Future<void> _handleAddMoney() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // 1. Create real Razorpay payment link via backend
    final plinkData = await ref.read(walletProvider.notifier).createRazorpayPaymentLink(amount);
    if (!mounted) return;

    if (plinkData == null) {
      final err = ref.read(walletProvider).errorMessage ?? 'Failed to initialize Razorpay payment. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final shortUrl = plinkData['shortUrl']?.toString();
    final paymentLinkId = plinkData['paymentLinkId']?.toString();

    if (shortUrl == null || shortUrl.isEmpty || paymentLinkId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid payment link returned by Razorpay.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // 2. Launch Razorpay Checkout in browser/UPI
    final uri = Uri.parse(shortUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open payment link: $err'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
        return;
      }
    }

    // 3. Show live awaiting payment modal with automatic real-time status verification
    _showPaymentWaitingModal(paymentLinkId, amount);
  }

  void _showPaymentWaitingModal(String paymentLinkId, double amount) {
    int attempts = 0;
    const maxAttempts = 60; // 60 * 2.5s = 2.5 minutes
    bool isModalOpen = true;

    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) async {
      attempts++;
      if (attempts >= maxAttempts) {
        timer.cancel();
        return;
      }

      if (_isCheckingStatus) return;
      _isCheckingStatus = true;

      try {
        final txn = await ref.read(walletProvider.notifier).checkRazorpayPaymentLinkStatus(paymentLinkId);
        if (txn != null) {
          timer.cancel();
          if (isModalOpen && mounted) {
            Navigator.of(context).pop(); // dismiss waiting modal
          }
          if (mounted) {
            _navigateToSuccess(txn);
          }
        }
      } finally {
        _isCheckingStatus = false;
      }
    });

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6F4F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF004E54)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Complete Payment',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We opened Razorpay. Approve the payment of ₹${amount.toInt()} in Google Pay, PhonePe, Paytm, or your bank app, then return here.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      height: 1.4,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        setModalState(() {});
                        final txn = await ref.read(walletProvider.notifier).checkRazorpayPaymentLinkStatus(paymentLinkId);
                        if (txn != null) {
                          _statusPollTimer?.cancel();
                          if (mounted) {
                            Navigator.of(sheetCtx).pop();
                            _navigateToSuccess(txn);
                          }
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payment not completed yet. Please finish in your UPI app.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004E54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'I Have Paid · Check Status',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      _statusPollTimer?.cancel();
                      ref.read(walletProvider.notifier).resetAddingState();
                      Navigator.of(sheetCtx).pop();
                    },
                    child: const Text(
                      'Cancel Payment',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      isModalOpen = false;
      _statusPollTimer?.cancel();
      ref.read(walletProvider.notifier).resetAddingState();
    });
  }

  Future<void> _navigateToSuccess(WalletTransaction txn) async {
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MoneyAddedSuccessScreen(
          transaction: txn,
          isFromBidding: widget.minTopUp != null,
        ),
      ),
    );
    if (res == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final currentBalanceFormatted = '₹${walletState.balance.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Add Money',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Top up your BIDLY Wallet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Current Balance Card ──────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF004E54),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current Balance',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentBalanceFormatted,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (widget.minTopUp != null && widget.minTopUp! > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Min top-up: ₹${NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0).format(widget.minTopUp).trim()}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFCA5A5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 2. Quick Select Chips ─────────────────────────────
              const Text(
                'Quick Select',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_quickAmounts.length, (index) {
                  final amt = _quickAmounts[index];
                  final label = amt >= 1000 ? '₹${amt ~/ 1000}K' : '₹$amt';
                  final isSelected = _selectedChipIndex == index;

                  return GestureDetector(
                    onTap: () => _onSelectChip(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE6F4F2) : const Color(0xFFF3F7F8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF004E54) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF004E54),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // ── 3. Or Enter Custom Amount ─────────────────────────
              const Text(
                'Or enter custom amount',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  final parsed = int.tryParse(val.replaceAll(',', '').trim());
                  final idx = _quickAmounts.indexOf(parsed ?? -1);
                  setState(() {
                    _selectedChipIndex = idx;
                  });
                },
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 16, right: 8),
                    child: Text(
                      '₹',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  hintText: 'Enter amount',
                  hintStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppTheme.textHint,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF004E54), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── 4. Saved Payment Banner ───────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB8E0DC)),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF007A87),
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Saved: GPay — ayan@okaxis · Quick pay',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF004E54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 5. Payment Methods List ───────────────────────────
              const Text(
                'Payment Method',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: List.generate(_paymentMethods.length, (i) {
                    final item = _paymentMethods[i];
                    final isSelected = _selectedPaymentMethod == item['id'];
                    final isLast = i == _paymentMethods.length - 1;

                    return Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedPaymentMethod = item['id'] as String;
                            });
                          },
                          borderRadius: BorderRadius.vertical(
                            top: i == 0 ? const Radius.circular(16) : Radius.zero,
                            bottom: isLast ? const Radius.circular(16) : Radius.zero,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
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
                                        item['title'] as String,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        item['subtitle'] as String,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF004E54) : AppTheme.border,
                                      width: isSelected ? 6 : 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 68,
                            color: AppTheme.border.withValues(alpha: 0.6),
                          ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 32),

              // ── 6. Add Money Button ───────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: walletState.isAdding ? null : _handleAddMoney,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF004E54),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: walletState.isAdding
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Add Money',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),

              // ── 7. Encryption Security Footer ─────────────────────
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF004E54)),
                    const SizedBox(width: 5),
                    Text(
                      'Secured by Razorpay · 256-bit Bank Grade Encryption',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
