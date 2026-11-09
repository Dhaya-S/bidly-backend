import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../providers/my_listings_provider.dart';

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  final List<String> _auctionFilters = ['All', 'Active', 'Shipping', 'Completed', 'Cancelled'];
  final List<String> _directFilters = ['All', 'Active', 'Completed', 'Cancelled'];

  @override
  Widget build(BuildContext context) {
    final listingsState = ref.watch(myListingsProvider);
    final isAuction = listingsState.selectedTab == 'AUCTION';
    final currentFilters = isAuction ? _auctionFilters : _directFilters;

    final fullList = isAuction ? listingsState.auctionListings : listingsState.directListings;
    final selectedFilter = listingsState.selectedFilter.toUpperCase();

    final filteredList = fullList.where((item) {
      if (selectedFilter == 'ALL') return true;
      return item.status.toUpperCase() == selectedFilter;
    }).toList();

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
          'My Listings',
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

            // ── Main Tab Bar (Auction vs Direct Buy) ────────────
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
                        onTap: () {
                          ref.read(myListingsProvider.notifier).setTab('AUCTION');
                        },
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
                        onTap: () {
                          ref.read(myListingsProvider.notifier).setTab('DIRECT');
                        },
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

            // ── Sub-Filter Pills Row ────────────────────────────
            Container(
              height: 38,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: currentFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final f = currentFilters[idx];
                  final isSelected = listingsState.selectedFilter.toUpperCase() == f.toUpperCase();

                  return GestureDetector(
                    onTap: () => ref.read(myListingsProvider.notifier).setFilter(f.toUpperCase()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF004E54) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          f,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Listings List with Pull-to-Refresh ───────────────
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF004E54),
                onRefresh: () async {
                  await ref.read(myListingsProvider.notifier).fetchMyListings();
                },
                child: filteredList.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront_outlined, size: 54, color: AppTheme.textHint),
                                const SizedBox(height: 12),
                                Text(
                                  'No ${listingsState.selectedFilter.toLowerCase()} listings found',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: filteredList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, idx) {
                          final item = filteredList[idx];
                          return _buildListingCard(item, isAuction);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingCard(MyListingItemModel item, bool isAuction) {
    final priceFormatted = '₹${item.price.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';

    // Status Pill properties
    Color statusBg = const Color(0xFFE6F8F3);
    Color statusTextColor = const Color(0xFF10B981);
    String statusText = 'Active';

    final normStatus = item.status.toUpperCase();
    if (normStatus == 'COMPLETED' || normStatus == 'SOLD') {
      statusBg = const Color(0xFFE0F2FE);
      statusTextColor = const Color(0xFF0369A1);
      statusText = 'Completed';
    } else if (normStatus == 'SHIPPING') {
      statusBg = const Color(0xFFEFF6FF);
      statusTextColor = const Color(0xFF3B82F6);
      statusText = 'Shipping';
    } else if (normStatus == 'CANCELLED') {
      statusBg = const Color(0xFFFEE2E2);
      statusTextColor = const Color(0xFFEF4444);
      statusText = 'Cancelled';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          // Touch post opens Product Details screen in real-time
          await context.push('/listing/${item.id}');
          if (mounted) {
            ref.read(myListingsProvider.notifier).fetchMyListings();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: ApiClient.resolveMediaUrl(item.imageUrl!),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _buildFallbackIcon(item.title),
                            )
                          : _buildFallbackIcon(item.title),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title & Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),

                        // Price / Highest Bid
                        Text(
                          isAuction
                              ? (normStatus == 'SHIPPING'
                                  ? 'Sold: $priceFormatted'
                                  : 'Highest Bid: $priceFormatted')
                              : priceFormatted,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF004E54),
                          ),
                        ),
                        const SizedBox(height: 3),

                        // Subtitle: Time left / Bids / Transit
                        if (isAuction) ...[
                          if (normStatus == 'SHIPPING')
                            const Row(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 12, color: Color(0xFF3B82F6)),
                                SizedBox(width: 4),
                                Text(
                                  'In Transit',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 12, color: AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  '${item.timeLeft ?? "Ended"} · ${item.bidsCount} bids',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Action Buttons for Auction
              if (isAuction) ...[
                const SizedBox(height: 12),
                if (normStatus == 'ACTIVE')
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () {
                        context.push('/auction/tracker/${item.id}?isSeller=true');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004E54),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'View Bids',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                else if (normStatus == 'COMPLETED' || normStatus == 'SOLD')
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton(
                      onPressed: () {
                        context.push('/my-listings/sale-summary/${item.id}');
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8F6F5),
                        side: const BorderSide(color: Color(0xFFB8E0DC)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'View Sale Details',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF004E54),
                        ),
                      ),
                    ),
                  )
                else if (normStatus == 'SHIPPING')
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push(AppRoutes.orders);
                      },
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: const Text(
                        'View Shipping',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
              ],

              // Action Buttons for Direct Buy
              if (!isAuction && (normStatus == 'COMPLETED' || normStatus == 'SOLD')) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton(
                    onPressed: () {
                      context.push('/my-listings/sale-summary/${item.id}');
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8F6F5),
                      side: const BorderSide(color: Color(0xFFB8E0DC)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'View Sale Details',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF004E54),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon(String title) {
    final lower = title.toLowerCase();
    IconData iconData = Icons.devices_other_rounded;
    if (lower.contains('macbook') || lower.contains('laptop')) {
      iconData = Icons.laptop_mac_rounded;
    } else if (lower.contains('camera') || lower.contains('nikon')) {
      iconData = Icons.camera_alt_outlined;
    } else if (lower.contains('headphone') || lower.contains('sony')) {
      iconData = Icons.headphones_outlined;
    } else if (lower.contains('desk') || lower.contains('table')) {
      iconData = Icons.table_restaurant_outlined;
    } else if (lower.contains('phone') || lower.contains('kindle')) {
      iconData = Icons.tablet_android_rounded;
    }

    return Center(
      child: Icon(
        iconData,
        color: const Color(0xFF004E54),
        size: 30,
      ),
    );
  }
}
