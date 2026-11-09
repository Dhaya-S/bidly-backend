import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/bidly_loading_indicator.dart';
import '../providers/orders_provider.dart';
import 'product_history_screen.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final List<String> _filters = ['Recent', 'Last Month', 'Last Year'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersProvider.notifier).fetchOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);
    final isAuction = ordersState.selectedTab == 'AUCTION';
    final currentList = isAuction ? ordersState.auctionOrders : ordersState.directOrders;

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
          'Orders',
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
        child: Column(
          children: [
            const SizedBox(height: 14),

            // ── Tab Bar (Auction vs Direct Buy) ────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => ref.read(ordersProvider.notifier).setTab('AUCTION'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isAuction ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isAuction
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Auction',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.5,
                                fontWeight: isAuction ? FontWeight.w700 : FontWeight.w500,
                                color: isAuction ? const Color(0xFF004E54) : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => ref.read(ordersProvider.notifier).setTab('DIRECT'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isAuction ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !isAuction
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Direct Buy',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.5,
                                fontWeight: !isAuction ? FontWeight.w700 : FontWeight.w500,
                                color: !isAuction ? const Color(0xFF004E54) : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Timeframe Filter Chips ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = ordersState.selectedFilter.toLowerCase() == filter.toLowerCase().replaceAll(' ', '_');

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => ref.read(ordersProvider.notifier).setFilter(filter.toLowerCase().replaceAll(' ', '_')),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF004E54) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // ── Order Cards List ───────────────────────────────
            Expanded(
              child: ordersState.isLoading && currentList.isEmpty
                  ? const Center(child: BidlyLoadingIndicator(message: 'Loading orders...'))
                  : currentList.isEmpty
                      ? RefreshIndicator(
                          color: const Color(0xFF004E54),
                          onRefresh: () => ref.read(ordersProvider.notifier).fetchOrders(),
                          child: ListView(
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.shopping_bag_outlined, size: 54, color: AppTheme.textHint),
                                    const SizedBox(height: 14),
                                    Text(
                                      isAuction ? 'No auction orders yet' : 'No direct buy orders yet',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Items you win in live bids or purchase directly will appear here',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: const Color(0xFF004E54),
                          onRefresh: () => ref.read(ordersProvider.notifier).fetchOrders(),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: currentList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (ctx, idx) {
                              final order = currentList[idx];
                              final priceFormatted = '₹${order.price.toInt().toString().replaceAllMapped(
                                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                    (Match m) => '${m[1]},',
                                  )}';

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        // Product Icon / Thumbnail
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: order.imageUrl != null && order.imageUrl!.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: ApiClient.resolveMediaUrl(order.imageUrl!),
                                                  width: 52,
                                                  height: 52,
                                                  fit: BoxFit.cover,
                                                  placeholder: (_, __) => Container(
                                                    width: 52,
                                                    height: 52,
                                                    color: const Color(0xFFF3F4F6),
                                                    child: const Center(
                                                      child: SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF004E54)),
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget: (_, __, ___) => Container(
                                                    width: 52,
                                                    height: 52,
                                                    color: const Color(0xFFF3F4F6),
                                                    child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF004E54), size: 28),
                                                  ),
                                                )
                                              : Container(
                                                  width: 52,
                                                  height: 52,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF3F4F6),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      order.title.toLowerCase().contains('chair')
                                                          ? Icons.chair_outlined
                                                          : (order.title.toLowerCase().contains('phone') || order.title.toLowerCase().contains('iphone')
                                                              ? Icons.phone_iphone_rounded
                                                              : (order.title.toLowerCase().contains('ps5')
                                                                  ? Icons.videogame_asset_outlined
                                                                  : (order.title.toLowerCase().contains('headphone')
                                                                      ? Icons.headphones_outlined
                                                                      : Icons.shopping_bag_outlined))),
                                                      color: const Color(0xFF004E54),
                                                      size: 28,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Title, Price, Date/Seller
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                order.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                priceFormatted,
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF004E54),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                order.date,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 11,
                                                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // View Product History Button
                                    Container(
                                      width: double.infinity,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F6F5),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          ref.read(ordersProvider.notifier).selectOrder(order);
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ProductHistoryScreen(order: order),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: const Center(
                                          child: Text(
                                            'View Product History',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF004E54),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
