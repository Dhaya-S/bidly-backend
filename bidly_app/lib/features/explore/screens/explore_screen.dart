import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/listing_model.dart';
import '../models/top_seller_model.dart';
import '../providers/explore_provider.dart';
import '../widgets/deal_near_you_card.dart';
import '../widgets/top_seller_card.dart';
import '../widgets/recently_viewed_card.dart';
import '../widgets/marketplace_grid_card.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      ref.read(exploreProvider.notifier).fetchNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(exploreProvider.notifier).updateSearchQuery(value);
  }

  void _showFilterModal(BuildContext context) {
    final state = ref.read(exploreProvider);
    String tempSortBy = state.sortBy;
    String tempMethod = state.selectedSellingMethod;
    String tempCondition = state.condition;
    String tempCategory = state.selectedCategory;
    int tempRadius = state.selectedRadiusKm;
    final minPriceCtrl = TextEditingController(text: state.minPrice != null ? state.minPrice!.toInt().toString() : '');
    final maxPriceCtrl = TextEditingController(text: state.maxPrice != null ? state.maxPrice!.toInt().toString() : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Modal Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempSortBy = 'relevance';
                                tempMethod = 'ALL';
                                tempCondition = 'ANY';
                                tempCategory = 'All';
                                tempRadius = 10;
                                minPriceCtrl.clear();
                                maxPriceCtrl.clear();
                              });
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Scrollable Filters Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Sort By
                        _buildFilterSectionTitle('Sort By'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: [
                            _buildSelectablePill('Relevance', 'relevance', tempSortBy == 'relevance', () {
                              setModalState(() => tempSortBy = 'relevance');
                            }),
                            _buildSelectablePill('Price: Low to High', 'price_asc', tempSortBy == 'price_asc', () {
                              setModalState(() => tempSortBy = 'price_asc');
                            }),
                            _buildSelectablePill('Price: High to Low', 'price_desc', tempSortBy == 'price_desc', () {
                              setModalState(() => tempSortBy = 'price_desc');
                            }),
                            _buildSelectablePill('Newest First', 'newest', tempSortBy == 'newest', () {
                              setModalState(() => tempSortBy = 'newest');
                            }),
                            _buildSelectablePill('Ending Soon', 'ending_soon', tempSortBy == 'ending_soon', () {
                              setModalState(() => tempSortBy = 'ending_soon');
                            }),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // 2. Listing Type
                        _buildFilterSectionTitle('Listing Type'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: [
                            _buildSelectablePill('All', 'ALL', tempMethod == 'ALL', () {
                              setModalState(() => tempMethod = 'ALL');
                            }),
                            _buildSelectablePill('Bidding', 'AUCTION', tempMethod == 'AUCTION', () {
                              setModalState(() => tempMethod = 'AUCTION');
                            }),
                            _buildSelectablePill('Direct Buy', 'DIRECT_BUY', tempMethod == 'DIRECT_BUY', () {
                              setModalState(() => tempMethod = 'DIRECT_BUY');
                            }),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // 3. Price Range
                        _buildFilterSectionTitle('Price Range (₹)'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: TextField(
                                  controller: minPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Min',
                                    hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Color(0xFF94A3B8)),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('—', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: TextField(
                                  controller: maxPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Max',
                                    hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Color(0xFF94A3B8)),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // 4. Condition
                        _buildFilterSectionTitle('Condition'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: [
                            _buildSelectablePill('Any', 'ANY', tempCondition == 'ANY', () {
                              setModalState(() => tempCondition = 'ANY');
                            }),
                            _buildSelectablePill('New', 'NEW', tempCondition == 'NEW', () {
                              setModalState(() => tempCondition = 'NEW');
                            }),
                            _buildSelectablePill('Like New', 'LIKE_NEW', tempCondition == 'LIKE_NEW', () {
                              setModalState(() => tempCondition = 'LIKE_NEW');
                            }),
                            _buildSelectablePill('Good', 'GOOD', tempCondition == 'GOOD', () {
                              setModalState(() => tempCondition = 'GOOD');
                            }),
                            _buildSelectablePill('Fair', 'FAIR', tempCondition == 'FAIR', () {
                              setModalState(() => tempCondition = 'FAIR');
                            }),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // 5. Category (Dynamic from Realtime Backend)
                        _buildFilterSectionTitle('Category'),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final itemWidth = (constraints.maxWidth - 10) / 2;
                            final cats = state.categories.where((c) => c != 'All').toList();
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: cats.map((cat) {
                                final isSelected = tempCategory == cat;
                                return SizedBox(
                                  width: itemWidth,
                                  child: _buildSelectablePill(
                                    cat,
                                    cat,
                                    isSelected,
                                    () {
                                      setModalState(() {
                                        tempCategory = (tempCategory == cat) ? 'All' : cat;
                                      });
                                    },
                                    isExpanded: true,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),

                        const SizedBox(height: 22),

                        // 6. Distance
                        _buildFilterSectionTitle('Distance'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: [
                            _buildSelectablePill('Any Distance', '0', tempRadius == 0, () {
                              setModalState(() => tempRadius = 0);
                            }),
                            _buildSelectablePill('< 1 km', '1', tempRadius == 1, () {
                              setModalState(() => tempRadius = 1);
                            }),
                            _buildSelectablePill('< 5 km', '5', tempRadius == 5, () {
                              setModalState(() => tempRadius = 5);
                            }),
                            _buildSelectablePill('< 10 km', '10', tempRadius == 10, () {
                              setModalState(() => tempRadius = 10);
                            }),
                            _buildSelectablePill('< 25 km', '25', tempRadius == 25, () {
                              setModalState(() => tempRadius = 25);
                            }),
                          ],
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),

                // Sticky Apply Filters Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          final minVal = double.tryParse(minPriceCtrl.text.replaceAll(',', '').trim());
                          final maxVal = double.tryParse(maxPriceCtrl.text.replaceAll(',', '').trim());

                          ref.read(exploreProvider.notifier).applyFilters(
                            sortBy: tempSortBy,
                            sellingMethod: tempMethod,
                            minPrice: minVal,
                            maxPrice: maxVal,
                            condition: tempCondition,
                            category: tempCategory,
                            radiusKm: tempRadius,
                          );

                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004E54),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }

  Widget _buildFilterSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildSelectablePill(
    String label,
    String value,
    bool isSelected,
    VoidCallback onTap, {
    bool isExpanded = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF004E54) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF004E54) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF004E54).withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        alignment: isExpanded ? Alignment.center : null,
        child: Row(
          mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllDealsModal(BuildContext context, List<ListingModel> deals) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Deals Near You',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${deals.length} deals based on your location',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.67,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: deals.length,
                itemBuilder: (ctx, index) {
                  return MarketplaceGridCard(listing: deals[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllTopSellersModal(BuildContext context, List<TopSellerModel> topSellers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top Sellers',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${topSellers.length} community verified sellers',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                itemCount: topSellers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, index) {
                  final seller = topSellers[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: seller.avatarColor,
                          child: Text(
                            seller.initials.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                seller.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${seller.listingsCount} active listings',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _searchController.text = seller.name;
                            ref.read(exploreProvider.notifier).updateSearchQuery(seller.name);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004E54),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text(
                            'View Items',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllRecentlyViewedModal(BuildContext context, List<ListingModel> recentlyViewed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recently Viewed',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${recentlyViewed.length} items viewed by you',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.67,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: recentlyViewed.length,
                itemBuilder: (ctx, index) {
                  return MarketplaceGridCard(listing: recentlyViewed[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exploreState = ref.watch(exploreProvider);
    final selectedCategory = exploreState.selectedCategory;
    final selectedMethod = exploreState.selectedSellingMethod;
    final radius = exploreState.selectedRadiusKm;

    final bool hasActiveFilters = selectedMethod != 'ALL' ||
        selectedCategory != 'All' ||
        radius != 10 ||
        exploreState.sortBy != 'relevance' ||
        exploreState.condition != 'ANY' ||
        exploreState.minPrice != null ||
        exploreState.maxPrice != null;

    final categories = exploreState.categories;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF004E54),
          onRefresh: () => ref.read(exploreProvider.notifier).fetchExploreData(isRefresh: true),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // 1. Top Search Bar & Filter Tune Button (Exact User Mockup Layout)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      // Search Input Container (#F1F5F9)
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search products, sellers...',
                              hintStyle: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF94A3B8),
                                size: 22,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Dark Teal Rounded Square Filter Button (#004E54)
                      GestureDetector(
                        onTap: () => _showFilterModal(context),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF004E54),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              if (hasActiveFilters)
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF59E0B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 2. Realtime Category Filter Carousel (Clean Text-Only Pills)
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final catName = categories[index];
                      final isSelected = selectedCategory == catName;

                      return GestureDetector(
                        onTap: () => ref.read(exploreProvider.notifier).selectCategory(catName),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF004E54) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF004E54) : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            catName,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 18),

                // 3. Deals Near You Section (Shown when "All" is active)
                if (selectedCategory == 'All' && exploreState.searchQuery.isEmpty && exploreState.dealsNearYou.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Deals Near You',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Based on your location',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B).withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _showAllDealsModal(context, exploreState.dealsNearYou),
                          child: const Text(
                            'See All >',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF004E54),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 248,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: exploreState.dealsNearYou.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return DealNearYouCard(listing: exploreState.dealsNearYou[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                // 4. Top Sellers Section (Shown when "All" is active)
                if (selectedCategory == 'All' && exploreState.searchQuery.isEmpty && exploreState.topSellers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Top Sellers',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showAllTopSellersModal(context, exploreState.topSellers),
                          child: const Text(
                            'See All >',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF004E54),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 124,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: exploreState.topSellers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return TopSellerCard(seller: exploreState.topSellers[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                // 5. Recently Viewed Section (Shown when "All" is active)
                if (selectedCategory == 'All' && exploreState.searchQuery.isEmpty && exploreState.recentlyViewed.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recently Viewed',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showAllRecentlyViewedModal(context, exploreState.recentlyViewed),
                          child: const Text(
                            'See All >',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF004E54),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 142,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: exploreState.recentlyViewed.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return RecentlyViewedCard(listing: exploreState.recentlyViewed[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                // 6. Marketplace Section (Realtime 2-Column Grid)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            selectedCategory != 'All' ? selectedCategory : 'Marketplace',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (selectedCategory != 'All') ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => ref.read(exploreProvider.notifier).selectCategory('All'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      'Clear',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Icon(Icons.close_rounded, size: 12, color: Color(0xFF475569)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${exploreState.marketplaceListings.length} listings',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: exploreState.isLoading && exploreState.marketplaceListings.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(color: Color(0xFF004E54)),
                          ),
                        )
                      : exploreState.marketplaceListings.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(36.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.search_off_rounded, size: 54, color: Color(0xFF94A3B8)),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No listings found',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      selectedCategory != 'All'
                                          ? 'No items currently listed in "$selectedCategory". Tap Clear to view all items.'
                                          : 'Try changing your filter or search query.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                    ),
                                    if (selectedCategory != 'All') ...[
                                      const SizedBox(height: 14),
                                      ElevatedButton(
                                        onPressed: () => ref.read(exploreProvider.notifier).selectCategory('All'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF004E54),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                          elevation: 0,
                                        ),
                                        child: const Text('Show All Listings', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        ref.read(exploreProvider.notifier).resetFilters();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF004E54),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Reset Filters', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.67,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: exploreState.marketplaceListings.length,
                              itemBuilder: (context, index) {
                                return MarketplaceGridCard(
                                  listing: exploreState.marketplaceListings[index],
                                );
                              },
                            ),
                ),

                // Pagination Loading Indicator
                if (exploreState.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF004E54)),
                      ),
                    ),
                  ),

                const SizedBox(height: 110),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
