import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/bidly_loading_indicator.dart';
import '../models/auction_model.dart';
import '../providers/auction_provider.dart';

class PlaceBidScreen extends ConsumerStatefulWidget {
  final String listingId;

  const PlaceBidScreen({
    super.key,
    required this.listingId,
  });

  @override
  ConsumerState<PlaceBidScreen> createState() => _PlaceBidScreenState();
}

class _PlaceBidScreenState extends ConsumerState<PlaceBidScreen> {
  late double _bidAmount;
  bool _isInitialized = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();

  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(auctionProvider.notifier);
      await notifier.fetchAuctionDetails(widget.listingId);
      await notifier.fetchWallet();
      await notifier.fetchAddresses();

      final details = ref.read(auctionProvider).auctionDetails;
      if (details != null && mounted) {
        setState(() {
          _bidAmount = details.minNextBid > 0 ? details.minNextBid : details.currentHighestBid + 500;
          _isInitialized = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _increaseBid(double amount) {
    setState(() {
      _bidAmount += amount;
    });
  }

  void _decreaseBid(double amount, double minBid) {
    if (_bidAmount - amount >= minBid) {
      setState(() {
        _bidAmount -= amount;
      });
    }
  }

  void _onConfirmBidTapped(AuctionDetailsModel details) async {
    final state = ref.read(auctionProvider);
    if (state.selectedAddress == null && state.addresses.isEmpty) {
      _showDeliveryAddressModal(context, onSaved: () {
        _onConfirmBidTapped(details);
      });
      return;
    }

    final notifier = ref.read(auctionProvider.notifier);
    final sufficient = await notifier.validateWallet(widget.listingId, _bidAmount);
    if (!mounted) return;

    final wallet = ref.read(auctionProvider).wallet;
    if (wallet == null) {
      // Wallet not loaded yet — should not happen since fetchWallet runs in initState
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet data unavailable. Please try again.'), backgroundColor: Color(0xFFEF4444)),
        );
      }
      return;
    }
    final balance = wallet.availableBalance;

    _showWalletValidationSheet(context, balance, _bidAmount, sufficient);
  }

  void _showDeliveryAddressModal(BuildContext context, {VoidCallback? onSaved}) {
    final state = ref.read(auctionProvider);
    if (state.selectedAddress != null) {
      _nameController.text = state.selectedAddress!.fullName;
      _phoneController.text = state.selectedAddress!.phone;
      _addressController.text = state.selectedAddress!.addressLine;
      _cityController.text = state.selectedAddress!.city;
      _pincodeController.text = state.selectedAddress!.pincode;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(22),
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
                    'Delivery Address',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.black54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildAddressField('Full Name', _nameController, 'Recipient name'),
              const SizedBox(height: 12),
              _buildAddressField('Phone Number', _phoneController, '+91 XXXXX XXXXX', keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildAddressField('Address', _addressController, 'Street / Flat / Area'),
              const SizedBox(height: 12),
              _buildAddressField('City', _cityController, 'City name'),
              const SizedBox(height: 12),
              _buildAddressField('PIN Code', _pincodeController, '6-digit PIN', keyboardType: TextInputType.number),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_nameController.text.trim().isNotEmpty && _addressController.text.trim().isNotEmpty) {
                      await ref.read(auctionProvider.notifier).saveAddress(
                            fullName: _nameController.text.trim(),
                            phone: _phoneController.text.trim(),
                            addressLine: _addressController.text.trim(),
                            city: _cityController.text.trim(),
                            pincode: _pincodeController.text.trim(),
                          );
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        onSaved?.call();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save & Continue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressField(String label, TextEditingController ctrl, String hint, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF004E54)),
            ),
          ),
        ),
      ],
    );
  }

  void _showWalletValidationSheet(BuildContext context, double balance, double bidAmt, bool sufficient) {
    bool isPlacing = false;
    String? sheetError;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final shortAmount = bidAmt > balance ? (bidAmt - balance) : 0.0;

          return Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text(
                  'Wallet Validation',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  sufficient ? 'Ready to place your bid' : 'Amount not in wallet. Top up your wallet.',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),

                // Balance vs Bid Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Wallet Balance', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(
                            currencyFormatter.format(balance),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: sufficient ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Bid Amount', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(
                            currencyFormatter.format(bidAmt),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Status Pill
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: sufficient ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                    child: Text(
                      sufficient
                          ? 'Your wallet has enough funds to place this bid'
                          : 'Amount not in wallet (Short by ${currencyFormatter.format(shortAmount)}). Top up your wallet to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: sufficient ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),

                  // Error message inside sheet
                  if (sheetError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        sheetError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isPlacing
                          ? null
                          : () async {
                              if (!sufficient) {
                                Navigator.of(ctx).pop();
                                await context.push('/wallet/add-money?minTopUp=${shortAmount.toInt()}');
                                if (!mounted) return;
                                await ref.read(auctionProvider.notifier).fetchWallet();
                                final wallet = ref.read(auctionProvider).wallet;
                                final newBal = wallet?.availableBalance ?? wallet?.balance ?? 0.0;
                                if (context.mounted) {
                                  _showWalletValidationSheet(context, newBal, bidAmt, newBal >= bidAmt);
                                }
                                return;
                              }

                              setSheetState(() {
                                isPlacing = true;
                                sheetError = null;
                              });
                              final router = GoRouter.of(context);
                              try {
                                final success = await ref.read(auctionProvider.notifier).placeBid(widget.listingId, bidAmt);
                                if (!mounted) return;
                                if (success) {
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  router.go('/auction/${widget.listingId}/tracker');
                                } else {
                                  final errMsg = ref.read(auctionProvider).errorMessage ?? 'Failed to place bid. Please try again.';
                                  setSheetState(() {
                                    isPlacing = false;
                                    sheetError = errMsg;
                                  });
                                }
                              } catch (e) {
                                setSheetState(() {
                                  isPlacing = false;
                                  sheetError = 'Network error. Please try again.';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sufficient ? const Color(0xFF004E54) : const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isPlacing
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              sufficient
                                  ? 'Continue Bid • ${currencyFormatter.format(bidAmt)}'
                                  : 'Top Up Wallet',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isPlacing ? null : () => Navigator.pop(ctx),
                    child: const Text('Go Back', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auctionProvider);
    final details = state.auctionDetails;

    if (state.isLoading && details == null) {
      return const BidlyLoadingScreen(
        message: 'Loading auction details...',
        appBarTitle: 'Place Your Bid',
        showBackButton: true,
      );
    }

    if (details == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Place Your Bid')),
        body: const Center(child: Text('Auction not found')),
      );
    }

    final minBid = details.minNextBid > 0 ? details.minNextBid : details.currentHighestBid + 500;
    final currentBid = _isInitialized ? _bidAmount : minBid;
    final platformFee = currentBid * 0.02;
    final totalPayable = currentBid + platformFee;
    final selectedAddress = state.selectedAddress;
    final wallet = state.wallet;
    final availableBalance = wallet?.availableBalance ?? 0.0;
    final isSufficient = availableBalance >= currentBid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Place Your Bid',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            Text(
              details.title,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Current Highest Bid Teal Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF004E54),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Highest Bid',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF99F6E4), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currencyFormatter.format(details.currentHighestBid),
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          if (details.highestBidderName.isNotEmpty)
                            Text(
                              'by ${details.highestBidderName}${details.highestBidderTime.isNotEmpty ? ' • ${details.highestBidderTime}' : ''}',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFFCCFBF1)),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Ends in', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF99F6E4))),
                          const SizedBox(height: 2),
                          Text(
                            details.timeLeftFormatted,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${details.totalBids} bids placed',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFFCCFBF1)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Your Bid Amount Stepper Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Bid Amount',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF004E54), width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              currencyFormatter.format(currentBid),
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                            ),
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _increaseBid(500),
                                  child: const Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFF004E54), size: 26),
                                ),
                                GestureDetector(
                                  onTap: () => _decreaseBid(500, minBid),
                                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 26),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Minimum bid: ${currencyFormatter.format(minBid)}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Real-time Wallet Balance & Top-up prompt
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSufficient ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSufficient ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              isSufficient ? Icons.account_balance_wallet_rounded : Icons.warning_amber_rounded,
                              color: isSufficient ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Wallet Balance: ',
                                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                      Text(
                                        currencyFormatter.format(availableBalance),
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isSufficient ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isSufficient
                                        ? '✓ Realtime funds ready for bid'
                                        : 'Amount not in wallet. Top up your wallet.',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isSufficient ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isSufficient)
                        TextButton(
                          onPressed: () async {
                            final shortAmt = (currentBid > availableBalance) ? (currentBid - availableBalance) : 500.0;
                            await context.push('/wallet/add-money?minTopUp=${shortAmt.toInt()}');
                            if (mounted) {
                              await ref.read(auctionProvider.notifier).fetchWallet();
                            }
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Top Up', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Quick Add Pills
                const Text(
                  'Quick Add',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildQuickAddPill('+₹500', () => _increaseBid(500)),
                    const SizedBox(width: 8),
                    _buildQuickAddPill('+₹1k', () => _increaseBid(1000)),
                    const SizedBox(width: 8),
                    _buildQuickAddPill('+₹2k', () => _increaseBid(2000)),
                    const SizedBox(width: 8),
                    _buildQuickAddPill('+₹5k', () => _increaseBid(5000)),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Win Probability Card (only shown when server provides real data)
                if (details.winProbability > 0)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.trending_up_rounded, color: Color(0xFF004E54), size: 18),
                                SizedBox(width: 6),
                                Text('Win Probability', style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            Text('${details.winProbability}%', style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF004E54))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: details.winProbability / 100.0,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Competitive — increase bid to improve odds',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // 5. Bid Breakdown Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bid Breakdown', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      _buildBreakdownRow('Your bid', currencyFormatter.format(currentBid)),
                      _buildBreakdownRow('Platform fee (2%)', currencyFormatter.format(platformFee)),
                      _buildBreakdownRow('Buyer protection', 'FREE', isHighlight: true),
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total payable if you win', style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          Text(currencyFormatter.format(totalPayable), style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Delivery Address Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF004E54).withValues(alpha: 0.3), style: BorderStyle.solid),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_on_outlined, color: Color(0xFF004E54), size: 18),
                              SizedBox(width: 6),
                              Text('Delivery Address', style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => _showDeliveryAddressModal(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF004E54),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.edit_outlined, color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    selectedAddress != null ? 'Change' : 'Add Address',
                                    style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedAddress != null
                            ? '${selectedAddress.fullName} • ${selectedAddress.formattedAddress}'
                            : 'Add your delivery address so the seller knows where to ship if you win.',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 7. Security Guarantee Pill
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFF15803D), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You will only be charged if you win. Your payment is secured by BIDLY Buyer Protection.',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky Bottom Confirm Bid Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -3)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _onConfirmBidTapped(details),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Confirm Bid • ${currencyFormatter.format(currentBid)}',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'By bidding you agree to BIDLY\'s Auction Terms',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddPill(String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0369A1)),
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isHighlight ? const Color(0xFF10B981) : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
