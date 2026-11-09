import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/bidly_loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/auction_model.dart';
import '../providers/auction_provider.dart';
import '../widgets/auction_winner_dialog.dart';

class AuctionTrackerScreen extends ConsumerStatefulWidget {
  final String listingId;
  final bool isSellerRoute;

  const AuctionTrackerScreen({
    super.key,
    required this.listingId,
    this.isSellerRoute = false,
  });

  @override
  ConsumerState<AuctionTrackerScreen> createState() => _AuctionTrackerScreenState();
}

class _AuctionTrackerScreenState extends ConsumerState<AuctionTrackerScreen> {
  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Always connect WebSocket and fetch fresh details.
      // initAuction is idempotent — if auctionDetails is already loaded for this listing
      // it updates in the background without showing a loading spinner.
      final existingDetails = ref.read(auctionProvider).auctionDetails;
      if (existingDetails != null) {
        // Details already loaded (e.g. navigated from PlaceBidScreen). Connect WS silently.
        ref.read(auctionProvider.notifier).initAuctionSilent(widget.listingId);
      } else {
        ref.read(auctionProvider.notifier).initAuction(widget.listingId);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    ref.read(auctionProvider.notifier).disconnectWebSocket();
    super.dispose();
  }

  void _showIncreaseBidModal(BuildContext context, AuctionDetailsModel details, double currentHighest, double userBid, {double? initialAmount}) {
    final live = ref.read(auctionProvider).liveStatus;
    final authoritativeHighest = live?.currentHighestBid ?? details.currentHighestBid;
    final minInc = details.minBidIncrement > 0 ? details.minBidIncrement : 500.0;
    double newAmount = initialAmount ?? (authoritativeHighest + minInc);

    final wallet = ref.read(auctionProvider).wallet;
    final availableBalance = wallet?.availableBalance ?? 0.0;

    bool isPlacing = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // If user currently has active winning bid, they only need additional difference
          final currentUserBid = live?.currentUserBid ?? details.currentUserBid ?? 0.0;
          final isUserWinning = live?.isCurrentUserWinning ?? details.isCurrentUserWinning;
          final additionalNeeded = isUserWinning ? (newAmount - currentUserBid) : newAmount;
          final sufficient = availableBalance >= additionalNeeded;

          return Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Increase Your Bid',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                const Text('New Bid Amount', style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF004E54), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Text(
                        currencyFormatter.format(newAmount),
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Current highest: ${currencyFormatter.format(authoritativeHighest)} • Min raise: ${currencyFormatter.format(authoritativeHighest + minInc)}',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),

                // Quick Add Pills
                Row(
                  children: [
                    _buildModalQuickAdd('+₹500', () => setModalState(() => newAmount += 500)),
                    const SizedBox(width: 8),
                    _buildModalQuickAdd('+₹1,000', () => setModalState(() => newAmount += 1000)),
                    const SizedBox(width: 8),
                    _buildModalQuickAdd('+₹2,000', () => setModalState(() => newAmount += 2000)),
                    const SizedBox(width: 8),
                    _buildModalQuickAdd('+₹5,000', () => setModalState(() => newAmount += 5000)),
                  ],
                ),
                const SizedBox(height: 16),

                // Wallet status pill
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sufficient ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sufficient ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(sufficient ? Icons.check_circle_outline : Icons.error_outline, color: sufficient ? const Color(0xFF15803D) : const Color(0xFFB91C1C), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              sufficient ? 'Wallet balance sufficient' : 'Amount not in wallet. Top up your wallet.',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: sufficient ? const Color(0xFF15803D) : const Color(0xFFB91C1C)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Available: ${currencyFormatter.format(availableBalance)}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                          Text('Required: ${currencyFormatter.format(additionalNeeded)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                ),

                if (modalError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      modalError!,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFFB91C1C)),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Confirm Increase CTA or Top Up CTA
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: sufficient
                      ? ElevatedButton(
                          onPressed: !isPlacing
                              ? () async {
                                  setModalState(() {
                                    isPlacing = true;
                                    modalError = null;
                                  });

                                  final success = await ref.read(auctionProvider.notifier).placeBid(widget.listingId, newAmount);

                                  if (!ctx.mounted) return;

                                  if (success) {
                                    Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Bid increased to ${currencyFormatter.format(newAmount)}!'),
                                          backgroundColor: const Color(0xFF10B981),
                                        ),
                                      );
                                    }
                                  } else {
                                    final err = ref.read(auctionProvider).errorMessage ?? 'Failed to place bid. Please try again.';
                                    setModalState(() {
                                      isPlacing = false;
                                      modalError = err;
                                    });
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004E54),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isPlacing
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('Confirm • ${currencyFormatter.format(newAmount)}', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15)),
                        )
                      : ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.push('/wallet/add-money').then((_) {
                              ref.read(auctionProvider.notifier).fetchWallet();
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: Text(
                            'Amount not in wallet • Top Up ₹${(additionalNeeded - availableBalance).ceil()}',
                            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalQuickAdd(String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0369A1)),
          ),
        ),
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Withdraw Bid?', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text('Withdrawing will cancel your bid and immediately return your reserved funds to your available wallet balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              nav.pop();

              final success = await ref.read(auctionProvider.notifier).withdrawBid(widget.listingId);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bid successfully withdrawn. Funds returned to your wallet.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                } else {
                  final err = ref.read(auctionProvider).errorMessage ?? 'Failed to withdraw bid';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: const Color(0xFFEF4444)),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  void _confirmEndAuction(BuildContext context, AuctionDetailsModel details) {
    final highestBidder = details.highestBidderName.isNotEmpty ? details.highestBidderName : 'highest bidder';
    final highestAmount = details.currentHighestBid > 0 ? currencyFormatter.format(details.currentHighestBid) : '₹0';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 26),
            SizedBox(width: 10),
            Text('End Auction Early?', style: TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          details.totalBids > 0
              ? 'Are you sure you want to end this auction now? The current highest bidder ($highestBidder - $highestAmount) will be declared the winner immediately.'
              : 'Are you sure you want to end this auction now? No bids have been placed yet.',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF475569)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final winner = await ref.read(auctionProvider.notifier).endAuction(widget.listingId);
              if (winner != null && context.mounted) {
                AuctionWinnerDialog.show(context, winner: winner, listingId: widget.listingId);
              } else if (context.mounted) {
                final err = ref.read(auctionProvider).errorMessage ?? 'Failed to end auction';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err), backgroundColor: const Color(0xFFEF4444)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('End Auction', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(auctionProvider, (prev, next) {
      final prevEnded = prev?.liveStatus?.isAuctionEnded ?? prev?.auctionDetails?.isAuctionEnded ?? false;
      final nextEnded = next.liveStatus?.isAuctionEnded ?? next.auctionDetails?.isAuctionEnded ?? false;
      if (!prevEnded && nextEnded && mounted) {
        ref.read(auctionProvider.notifier).fetchAuctionWinner(widget.listingId).then((winner) {
          if (winner != null && mounted && context.mounted) {
            AuctionWinnerDialog.show(context, winner: winner, listingId: widget.listingId);
          }
        });
      }
    });

    final state = ref.watch(auctionProvider);
    final details = state.auctionDetails;
    final live = state.liveStatus;
    final wallet = state.wallet;

    if (details == null && state.isLoading) {
      return const BidlyLoadingScreen(
        message: 'Connecting to live auction...',
        appBarTitle: 'Auction Tracker',
        showBackButton: true,
      );
    }

    if (details == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Auction Tracker')),
        body: const Center(child: Text('Auction not found')),
      );
    }

    final currentHighest = live?.currentHighestBid ?? details.currentHighestBid;
    final userBid = live?.currentUserBid ?? details.currentUserBid ?? currentHighest;
    final isWinning = live != null ? live.isCurrentUserWinning : details.isCurrentUserWinning;
    final isOutbid = live != null ? live.isCurrentUserOutbid : (!isWinning && currentHighest > userBid);
    final totalBids = live?.totalBids ?? details.totalBids;
    final watchingCount = live?.watchingCount ?? details.watchingCount;
    final timeLeft = live?.timeLeftFormatted ?? details.timeLeftFormatted;

    final currentUserId = ref.watch(authProvider).user?.id;
    final isSeller = widget.isSellerRoute || (currentUserId != null && (details.sellerId == currentUserId));
    final isAuctionEnded = details.isAuctionEnded || details.status == 'SOLD' || details.status == 'COMPLETED' || (live?.isAuctionEnded ?? false);

    final totalBalance = wallet?.balance ?? 0.0;
    final reservedBalance = isWinning ? userBid : (wallet?.reservedBalance ?? 0.0);
    final availableBalance = totalBalance - reservedBalance;

    final bidFeed = (live?.liveBidFeed.isNotEmpty == true)
        ? live!.liveBidFeed
        : details.recentBids;

    if (isSeller) {
      return _buildSellerView(
        context: context,
        details: details,
        live: live,
        currentHighest: currentHighest,
        totalBids: totalBids,
        watchingCount: watchingCount,
        timeLeft: timeLeft,
        isAuctionEnded: isAuctionEnded,
        bidFeed: bidFeed,
      );
    }

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
              'Auction Tracker',
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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.remove_red_eye_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text('$watchingCount', style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Status Banner (Teal if winning, Red if outbid)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isOutbid ? const Color(0xFFEF4444) : const Color(0xFF004E54),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isOutbid ? "You've been outbid" : "You are the highest bidder!",
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormatter.format(currentHighest),
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const SizedBox(height: 14),

                      // 3 Mini Stat Pills
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildHeaderPill(Icons.access_time_rounded, timeLeft, 'Time Left'),
                          _buildHeaderPill(Icons.trending_up_rounded, '$totalBids', 'Total Bids'),
                          _buildHeaderPill(Icons.people_alt_outlined, '$watchingCount', 'Watching'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. BIDLY Wallet Card
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
                              Icon(Icons.account_balance_wallet_outlined, size: 18, color: Color(0xFF004E54)),
                              SizedBox(width: 6),
                              Text('BIDLY Wallet', style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          if (reservedBalance > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.lock_outline, size: 12, color: Color(0xFFD97706)),
                                  SizedBox(width: 4),
                                  Text('Funds Reserved', style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildWalletStat('Total Balance', currencyFormatter.format(totalBalance)),
                          _buildWalletStat('Reserved', currencyFormatter.format(reservedBalance), color: const Color(0xFFD97706)),
                          _buildWalletStat('Available', currencyFormatter.format(availableBalance), color: const Color(0xFF004E54)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Reserved amount will be released if you\'re outbid • Moved to escrow if you win',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. User's Current Position / Bid Card OR Seller Status Card
                if (!isSeller) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Your bid', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(
                              currencyFormatter.format(userBid),
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isWinning
                                  ? '✓ Currently winning'
                                  : 'Behind by ${currencyFormatter.format(currentHighest - userBid)}',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isWinning ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                        if (isOutbid)
                          ElevatedButton.icon(
                            onPressed: () => _showIncreaseBidModal(context, details, currentHighest, userBid),
                            icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                            label: const Text('Increase Bid', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isOutbid) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildTrackerQuickAdd('+₹1,000', () {
                          _showIncreaseBidModal(context, details, currentHighest, userBid, initialAmount: currentHighest + 1000);
                        }),
                        const SizedBox(width: 8),
                        _buildTrackerQuickAdd('+₹2,000', () {
                          _showIncreaseBidModal(context, details, currentHighest, userBid, initialAmount: currentHighest + 2000);
                        }),
                        const SizedBox(width: 8),
                        _buildTrackerQuickAdd('+₹5,000', () {
                          _showIncreaseBidModal(context, details, currentHighest, userBid, initialAmount: currentHighest + 5000);
                        }),
                      ],
                    ),
                  ],
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF004E54).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Top Bidder', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(
                              details.highestBidderName.isNotEmpty ? details.highestBidderName : 'No bids yet',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              details.totalBids > 0 ? '${details.totalBids} bids placed' : 'Waiting for initial bid',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0D9488)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF99F6E4)),
                          ),
                          child: Text(
                            currencyFormatter.format(currentHighest),
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF004E54)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 4. Live Bid Feed Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text(
                          'Live Bid Feed',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    Text(
                      '$totalBids total',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Live Bid Feed Items
                if (bidFeed.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No bids yet. Be the first to bid!')),
                  )
                else
                  ...bidFeed.map((b) => _buildBidFeedItem(b)),

                if (!isSeller) ...[
                  const SizedBox(height: 16),

                  // 5. Withdraw from Auction Card
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
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFF64748B), size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Withdraw from Auction',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Withdrawing releases your reserved funds back to your wallet immediately.',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => _showWithdrawDialog(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              backgroundColor: const Color(0xFFFEF2F2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Withdraw My Bid', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Sticky Bottom Actions
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
                child: isSeller
                    ? (isAuctionEnded
                        ? SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final winner = await ref.read(auctionProvider.notifier).fetchAuctionWinner(widget.listingId);
                                if (winner != null && context.mounted) {
                                  AuctionWinnerDialog.show(context, winner: winner, listingId: widget.listingId);
                                }
                              },
                              icon: const Icon(Icons.emoji_events_outlined, size: 20),
                              label: const Text(
                                'View Winner & Delivery',
                                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF004E54),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          )
                        : SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => _confirmEndAuction(context, details),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'End Auction',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ))
                    : (isAuctionEnded
                        ? SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final winner = await ref.read(auctionProvider.notifier).fetchAuctionWinner(widget.listingId);
                                if (winner != null && context.mounted) {
                                  AuctionWinnerDialog.show(context, winner: winner, listingId: widget.listingId);
                                } else if (context.mounted) {
                                  context.push('/auction/${widget.listingId}/won');
                                }
                              },
                              icon: const Icon(Icons.emoji_events_outlined, size: 20),
                              label: Text(
                                isWinning ? 'Claim Your Won Item' : 'View Auction Results',
                                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isWinning ? const Color(0xFF10B981) : const Color(0xFF004E54),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showIncreaseBidModal(context, details, currentHighest, userBid),
                                    icon: const Icon(Icons.arrow_upward_rounded, size: 18, color: Color(0xFF004E54)),
                                    label: const Text('Increase Bid', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: Color(0xFF004E54))),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF004E54), width: 1.5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () => context.push('/listing/${widget.listingId}'),
                                    icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                                    label: const Text('View Product', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF004E54),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPill(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTrackerQuickAdd(String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB91C1C),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBidFeedItem(BidHistoryItemModel b) {
    final isTop = b.isHighest;
    final isUser = b.isCurrentUser;

    // Pick a distinct color based on bidder name
    final avatarColors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFF10B981), // Green
      const Color(0xFF004E54), // Dark Teal
    ];
    final colorIdx = b.bidderName.hashCode.abs() % avatarColors.length;
    final avatarColor = isTop ? const Color(0xFF8B5CF6) : avatarColors[colorIdx];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFFF0FDFA) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUser ? const Color(0xFF004E54) : const Color(0xFFE2E8F0),
          width: isUser ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarColor,
            child: Text(
              b.bidderInitials,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      b.bidderName,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(width: 6),
                    if (isTop)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(4)),
                        child: const Text('HIGHEST', style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    if (isUser) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFCCFBF1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('YOU', style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF004E54))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  b.relativeTime,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Text(
            currencyFormatter.format(b.amount),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isTop ? const Color(0xFFEF4444) : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerView({
    required BuildContext context,
    required AuctionDetailsModel details,
    required AuctionLiveStatusModel? live,
    required double currentHighest,
    required int totalBids,
    required int watchingCount,
    required String timeLeft,
    required bool isAuctionEnded,
    required List<BidHistoryItemModel> bidFeed,
  }) {
    final images = details.imageUrls.isNotEmpty
        ? details.imageUrls
        : (details.primaryImageUrl != null && details.primaryImageUrl!.isNotEmpty
            ? [details.primaryImageUrl!]
            : <String>[]);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Swipable Hero Carousel + Floating Header Controls (Container 2)
                Stack(
                  children: [
                    // Image Carousel
                    Container(
                      height: 300,
                      width: double.infinity,
                      color: const Color(0xFFF1F5F9),
                      child: images.isNotEmpty
                          ? PageView.builder(
                              controller: _pageController,
                              itemCount: images.length,
                              onPageChanged: (i) => setState(() => _currentImageIndex = i),
                              itemBuilder: (ctx, i) {
                                return CachedNetworkImage(
                                  imageUrl: ApiClient.resolveMediaUrl(images[i]),
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Center(
                                    child: CircularProgressIndicator(color: Color(0xFF004E54), strokeWidth: 2),
                                  ),
                                  errorWidget: (_, __, ___) => const Center(
                                    child: Icon(Icons.image_outlined, size: 48, color: Color(0xFF94A3B8)),
                                  ),
                                );
                              },
                            )
                          : const Center(
                              child: Icon(Icons.image_outlined, size: 64, color: Color(0xFFCBD5E1)),
                            ),
                    ),

                    // Floating Header Row
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back button
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
                              ),
                            ),

                            // LIVE AUCTION Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isAuctionEnded ? const Color(0xFF64748B) : const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isAuctionEnded) ...[
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    isAuctionEnded ? 'AUCTION ENDED' : 'LIVE AUCTION',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Heart & Share Actions
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.favorite_border_rounded, size: 18, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.share_outlined, size: 18, color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Page Indicators
                    if (images.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _currentImageIndex == i ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _currentImageIndex == i ? Colors.white : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // 2. Listing Details Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Red AUCTION Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AUCTION',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEF4444),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        details.title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Location & Condition
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            [
                              if (details.city.trim().isNotEmpty) details.city.trim(),
                              if (details.state.trim().isNotEmpty) details.state.trim(),
                              if (details.productCondition.trim().isNotEmpty) details.productCondition.replaceAll('_', ' '),
                            ].join(' · '),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. Dark Teal Current Highest Bid Card (Container 2 center)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF004E54),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF004E54).withValues(alpha: 0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current Highest Bid',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currencyFormatter.format(currentHighest),
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$totalBids bids · $watchingCount watching',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeLeft,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Ends in $timeLeft',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: Colors.white60,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 4. Description
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        details.description != null && details.description!.trim().isNotEmpty
                            ? details.description!
                            : '${details.title} in ${details.productCondition.replaceAll('_', ' ')} condition. Original accessories included, in full working condition.',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          height: 1.55,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 5. Bid History
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.trending_up_rounded, color: Color(0xFF004E54), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Bid History',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$totalBids total bids',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (bidFeed.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          alignment: Alignment.center,
                          child: const Text(
                            'No bids placed yet. Bids will appear here in real-time.',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF94A3B8)),
                          ),
                        )
                      else
                        ...bidFeed.map((b) => _buildBidFeedItem(b)),

                      const SizedBox(height: 22),

                      // 6. Trust & Safety
                      const Text(
                        'Trust & Safety',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTrustBullet('BIDLY Buyer Protection covers this auction'),
                      const SizedBox(height: 8),
                      _buildTrustBullet('Seller identity and contact verified on BIDLY'),
                      const SizedBox(height: 8),
                      if (details.sellerReviewsCount > 0)
                        _buildTrustBullet('Seller has ${details.sellerRating.toStringAsFixed(1)}★ rating across ${details.sellerReviewsCount} verified reviews')
                      else if (details.sellerRating > 0)
                        _buildTrustBullet('Seller rated ${details.sellerRating.toStringAsFixed(1)}★ by buyers on BIDLY')
                      else
                        _buildTrustBullet('Protected transaction with escrow payment security'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 7. Fixed Bottom Action Button (Container 2 End Auction)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: isAuctionEnded
                    ? SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final winner = await ref.read(auctionProvider.notifier).fetchAuctionWinner(widget.listingId);
                            if (winner != null && context.mounted) {
                              AuctionWinnerDialog.show(context, winner: winner, listingId: widget.listingId);
                            }
                          },
                          icon: const Icon(Icons.emoji_events_outlined, size: 20),
                          label: const Text(
                            'View Winner & Delivery',
                            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004E54),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _confirmEndAuction(context, details),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'End Auction',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF004E54)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              color: Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }
}
