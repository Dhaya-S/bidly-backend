import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_theme.dart';
import '../models/community_model.dart';
import '../providers/community_provider.dart';
import 'community_detail_screen.dart';

class CommunityPreviewScreen extends ConsumerStatefulWidget {
  final CommunityModel community;

  const CommunityPreviewScreen({
    super.key,
    required this.community,
  });

  @override
  ConsumerState<CommunityPreviewScreen> createState() => _CommunityPreviewScreenState();
}

class _CommunityPreviewScreenState extends ConsumerState<CommunityPreviewScreen> {
  List<Map<String, dynamic>> _recentListings = [];
  bool _isLoadingListings = true;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    final commState = ref.read(communityProvider);
    CommunityModel target = widget.community;
    try {
      final backendMatch = commState.communities.firstWhere(
        (b) => b.id == target.id || b.name.trim().toLowerCase() == target.name.trim().toLowerCase(),
      );
      target = backendMatch;
    } catch (_) {}

    final posts = await ref.read(communityProvider.notifier).fetchCommunityPosts(target.id);
    if (mounted) {
      setState(() {
        _recentListings = posts.take(4).toList();
        _isLoadingListings = false;
      });
    }
  }

  void _handleOpenOrJoin() {
    final commState = ref.read(communityProvider);
    CommunityModel target = widget.community;
    try {
      final backendMatch = commState.communities.firstWhere(
        (b) => b.id == target.id || b.name.trim().toLowerCase() == target.name.trim().toLowerCase(),
      );
      target = backendMatch;
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CommunityDetailScreen(community: target),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final comm = widget.community;
    final typeLabel = comm.type.isNotEmpty
        ? '${comm.type[0].toUpperCase()}${comm.type.substring(1).toLowerCase()} Community'
        : '${comm.category} Community';

    final membersText = comm.membersCount >= 1000
        ? '${(comm.membersCount / 1000).toStringAsFixed(1).replaceAll('.0', '')},${(comm.membersCount % 1000).toString().padLeft(3, '0')}'
        : comm.membersCount.toString();

    final remainingMembers = (comm.membersCount - 4) > 0 ? (comm.membersCount - 4) : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004E54),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: Text(
          comm.name,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Hero Gradient Container
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 120,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF004E54),
                                Color(0xFF006D75),
                              ],
                            ),
                          ),
                        ),

                        // Overlapping White Hero Card
                        Padding(
                          padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                Text(
                                  comm.name,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),

                                // Subtitle
                                Text(
                                  typeLabel,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Members Count Row
                                Row(
                                  children: [
                                    const Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFF004E54)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$membersText members',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF004E54),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Description
                                Text(
                                  comm.description?.isNotEmpty == true
                                      ? comm.description!
                                      : 'A thriving buy-sell community for residents and members. Discover trusted local deals from your neighbours!',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12.5,
                                    color: Color(0xFF475569),
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Avatar Circles Stack
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 90,
                                      height: 32,
                                      child: Stack(
                                        children: [
                                          _buildAvatarItem(0, const Color(0xFF1E293B)),
                                          Positioned(left: 18, child: _buildAvatarItem(1, const Color(0xFF004E54))),
                                          Positioned(left: 36, child: _buildAvatarItem(2, const Color(0xFF059669))),
                                          Positioned(left: 54, child: _buildAvatarItem(3, const Color(0xFF2563EB))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      remainingMembers > 0
                                          ? '+$remainingMembers more members'
                                          : 'active community members',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Recent Listings Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Listings',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (_recentListings.isNotEmpty)
                            const Text(
                              'Realtime',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF004E54),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Listings List
                    if (_isLoadingListings) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(color: Color(0xFF004E54)),
                        ),
                      ),
                    ] else if (_recentListings.isEmpty) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8), size: 28),
                              SizedBox(height: 8),
                              Text(
                                'No items listed yet in this community',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Join and be the first to post a deal!',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      ..._recentListings.map((post) {
                        final title = post['title'] as String? ?? 'Community Item';
                        final price = post['priceText'] as String? ?? '';
                        final method = post['sellingMethod'] as String? ?? 'DIRECT';
                        final img = post['imageUrl'] as String?;
                        return _buildListingItem(title, price.isNotEmpty ? price : 'Direct Sale', method, img);
                      }),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Open Community Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _handleOpenOrJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Open Community',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarItem(int index, Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Center(
        child: Icon(Icons.person_rounded, size: 14, color: Colors.white),
      ),
    );
  }

  Widget _buildListingItem(String title, String price, String method, String? imageUrl) {
    final isAuction = method.toUpperCase() == 'AUCTION';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 52,
              height: 52,
              color: const Color(0xFFF1F5F9),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: ApiClient.resolveMediaUrl(imageUrl),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8), size: 24),
                    )
                  : const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8), size: 24),
            ),
          ),
          const SizedBox(width: 14),

          // Title & Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  price,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF004E54),
                  ),
                ),
              ],
            ),
          ),

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isAuction ? const Color(0xFFFEF2F2) : const Color(0xFFE6F4F1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isAuction ? 'AUCTION' : 'DIRECT',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isAuction ? const Color(0xFFEF4444) : const Color(0xFF004E54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
