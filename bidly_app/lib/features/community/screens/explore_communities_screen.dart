import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../models/community_model.dart';
import '../providers/community_provider.dart';
import 'community_preview_screen.dart';

class ExploreCommunitiesScreen extends ConsumerStatefulWidget {
  const ExploreCommunitiesScreen({super.key});

  @override
  ConsumerState<ExploreCommunitiesScreen> createState() => _ExploreCommunitiesScreenState();
}

class _ExploreCommunitiesScreenState extends ConsumerState<ExploreCommunitiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Location', 'College', 'Apartment', 'Interest'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commState = ref.watch(communityProvider);
    final allCommunities = commState.communities;

    final query = _searchController.text.trim().toLowerCase();

    bool matchesSearchAndFilter(CommunityModel c) {
      if (query.isNotEmpty) {
        final matchesName = c.name.toLowerCase().contains(query);
        final matchesDesc = c.description != null && c.description!.toLowerCase().contains(query);
        final matchesCat = c.category.toLowerCase().contains(query);
        final matchesType = c.type.toLowerCase().contains(query);
        final matchesCity = c.city != null && c.city!.toLowerCase().contains(query);
        if (!matchesName && !matchesDesc && !matchesCat && !matchesType && !matchesCity) {
          return false;
        }
      }

      if (_selectedFilter != 'All') {
        final filterLower = _selectedFilter.toLowerCase();
        final typeLower = c.type.toLowerCase();
        final catLower = c.category.toLowerCase();

        if (filterLower == 'location') {
          final isLoc = typeLower.contains('location') ||
              typeLower.contains('neighbourhood') ||
              catLower.contains('neighbourhood') ||
              (c.city != null && c.city!.isNotEmpty);
          if (!isLoc) return false;
        } else {
          final isMatch = typeLower.contains(filterLower) || catLower.contains(filterLower);
          if (!isMatch) return false;
        }
      }

      return true;
    }

    final isFiltered = _selectedFilter != 'All' || query.isNotEmpty;
    final filteredResults = allCommunities.where(matchesSearchAndFilter).toList();

    // Group real-time communities into sections
    final discoverList = allCommunities.where((c) {
      final t = c.type.toUpperCase();
      return t == 'APARTMENT' || t == 'COLLEGE' || t == 'NEIGHBORHOOD' || t == 'NEIGHBOURHOOD';
    }).toList();

    final suggestedList = allCommunities.where((c) {
      final t = c.type.toUpperCase();
      final cat = c.category.toLowerCase();
      return t == 'INTEREST' || cat.contains('book') || cat.contains('fashion') || cat.contains('tech');
    }).toList();

    final nearbyList = allCommunities.where((c) {
      final t = c.type.toUpperCase();
      return t == 'LOCATION' || (c.city != null && c.city!.isNotEmpty);
    }).toList();

    final trendingList = allCommunities.where((c) {
      return c.membersCount >= 100 || c.category.toLowerCase().contains('electronics') || c.category.toLowerCase().contains('technology');
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 22),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: const Text(
          'Explore Communities',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: InkWell(
                onTap: _showFilterModal,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Text(
                    'Filter',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF004E54),
          onRefresh: () => ref.read(communityProvider.notifier).fetchCommunities(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Search communities...',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Filter Pills Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFilter = filter),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFE6F4F1) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF004E54) : const Color(0xFFCBD5E1),
                                width: isSelected ? 1.4 : 1.0,
                              ),
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? const Color(0xFF004E54) : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Realtime Stored Data Display
                if (commState.isLoading && allCommunities.isEmpty) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(color: Color(0xFF004E54)),
                    ),
                  ),
                ] else if (allCommunities.isEmpty) ...[
                  // Database has no communities yet
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6F4F1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.groups_rounded, color: Color(0xFF004E54), size: 30),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No communities created yet',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Be the first to build a local community for your campus, apartment or neighbourhood!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => context.push(AppRoutes.createCommunity),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'Create Community',
                              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004E54),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (!isFiltered) ...[
                  // Grouped View (Discover, Suggested, Nearby, Trending) using real stored communities
                  if (discoverList.isNotEmpty)
                    _buildSection('Discover', Icons.explore_outlined, discoverList),

                  if (suggestedList.isNotEmpty)
                    _buildSection('Suggested', Icons.people_outline_rounded, suggestedList),

                  if (nearbyList.isNotEmpty)
                    _buildSection('Nearby', Icons.location_on_outlined, nearbyList),

                  if (trendingList.isNotEmpty)
                    _buildSection('Trending', Icons.trending_up_rounded, trendingList),

                  // If none of the specific groupings matched, display all stored communities cleanly
                  if (discoverList.isEmpty && suggestedList.isEmpty && nearbyList.isEmpty && trendingList.isEmpty)
                    _buildSection('All Communities', Icons.explore_outlined, allCommunities),
                ] else ...[
                  // Filtered list view (when search query or category chip is active)
                  if (filteredResults.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE6F4F1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.search_off_rounded, color: Color(0xFF004E54), size: 26),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No matching communities found',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedFilter != 'All' ? '$_selectedFilter Communities' : 'Search Results',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${filteredResults.length} found',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...filteredResults.map((community) => _buildCommunityCard(community)),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<CommunityModel> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF004E54)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                if (title == 'Discover') setState(() => _selectedFilter = 'Apartment');
                if (title == 'Nearby') setState(() => _selectedFilter = 'Location');
                if (title == 'Suggested' || title == 'Trending') setState(() => _selectedFilter = 'Interest');
              },
              child: const Text(
                'See all',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF004E54),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Real Community Cards from Database
        ...items.map((community) => _buildCommunityCard(community)),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildCommunityCard(CommunityModel community) {
    final typeLabel = community.type.isNotEmpty
        ? '${community.type[0].toUpperCase()}${community.type.substring(1).toLowerCase()}'
        : community.category;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Community Avatar Icon
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.groups_rounded,
                color: Color(0xFF004E54),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name and Members Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  community.name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatMembers(community.membersCount)} members · $typeLabel',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // View Button
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CommunityPreviewScreen(community: community),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF004E54),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'View',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMembers(int count) {
    if (count >= 1000) {
      final k = (count / 1000).toStringAsFixed(1).replaceAll('.0', '');
      return '$k,${count % 1000 == 0 ? "000" : (count % 1000).toString().padLeft(3, '0')}';
    }
    return count.toString();
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Communities',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _filters.map((f) {
                final isSel = _selectedFilter == f;
                return ChoiceChip(
                  label: Text(f),
                  selected: isSel,
                  selectedColor: const Color(0xFFE6F4F1),
                  labelStyle: TextStyle(
                    color: isSel ? const Color(0xFF004E54) : AppTheme.textPrimary,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedFilter = f);
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
