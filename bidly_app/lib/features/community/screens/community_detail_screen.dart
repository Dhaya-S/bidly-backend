import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/bidly_snackbar.dart';
import '../models/community_model.dart';
import '../providers/community_provider.dart';
import '../../../core/providers/live_location_provider.dart';
import '../../sell/providers/sell_provider.dart';
import 'manage_community_screen.dart';
import 'community_reels_screen.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  final CommunityModel community;

  const CommunityDetailScreen({
    super.key,
    required this.community,
  });

  @override
  ConsumerState<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
  final List<Map<String, dynamic>> _communityPosts = [];
  bool _isLoadingPosts = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(communityProvider.notifier).fetchCommunity(widget.community.id);
      ref.read(communityProvider.notifier).fetchMembers(widget.community.id);
      _loadRealPosts();
    });
  }

  Future<void> _loadRealPosts() async {
    setState(() => _isLoadingPosts = true);
    final userLoc = ref.read(liveLocationProvider);
    final posts = await ref.read(communityProvider.notifier).fetchCommunityPosts(
      widget.community.id,
      latitude: userLoc.latitude,
      longitude: userLoc.longitude,
    );
    if (mounted) {
      setState(() {
        _communityPosts.clear();
        _communityPosts.addAll(posts);
        _isLoadingPosts = false;
      });
    }
  }

  void _handleHidePost(String postId) {
    final originalIndex = _communityPosts.indexWhere((p) => p['id']?.toString() == postId);
    if (originalIndex == -1) return;
    final removedPost = _communityPosts[originalIndex];

    setState(() {
      _communityPosts.removeAt(originalIndex);
    });

    try {
      ref.read(apiClientProvider).dio.post('/posts/$postId/hide');
    } catch (_) {}

    BidlySnackBar.showUndo(
      context: context,
      message: 'Post hidden from your feed',
      icon: Icons.visibility_off_outlined,
      onUndo: () {
        setState(() {
          _communityPosts.insert(originalIndex, removedPost);
        });
        try {
          ref.read(apiClientProvider).dio.delete('/posts/$postId/hide');
        } catch (_) {}
      },
    );
  }

  void _handleRestrictUser(String authorId, String authorName) {
    if (authorId.isEmpty) return;
    final removedPosts = _communityPosts.where((p) => p['authorId']?.toString() == authorId).toList();

    setState(() {
      _communityPosts.removeWhere((p) => p['authorId']?.toString() == authorId);
    });

    try {
      ref.read(apiClientProvider).dio.post('/posts/restrict/$authorId');
    } catch (_) {}

    BidlySnackBar.showUndo(
      context: context,
      message: 'Restricted $authorName. Posts hidden.',
      icon: Icons.block_rounded,
      onUndo: () {
        setState(() {
          _communityPosts.addAll(removedPosts);
        });
        try {
          ref.read(apiClientProvider).dio.delete('/posts/restrict/$authorId');
        } catch (_) {}
      },
    );
  }

  void _confirmLeaveCommunity(CommunityModel community) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Leave Community',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to leave ${community.name}? You will no longer have access to this community\'s member feed and private listings.',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              final success = await ref.read(communityProvider.notifier).leaveCommunity(community.id);
              if (success) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('You have left ${community.name}'),
                    backgroundColor: const Color(0xFF004E54),
                  ),
                );
                nav.pop();
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to leave community. Community creators cannot leave their own community.'),
                    backgroundColor: Color(0xFFE11D48),
                  ),
                );
              }
            },
            child: const Text('Leave', style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }





  void _showContactSheet(String sellerName, String productTitle) {
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
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F4F1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF004E54)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact $sellerName',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'About: $productTitle',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF004E54)),
              title: const Text('Chat on Bidly', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                context.push(AppRoutes.chatList);
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined, color: Color(0xFF004E54)),
              title: const Text('Call Seller', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('tel:');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _navigateToSell(CommunityModel comm) {
    ref.read(sellProvider.notifier).initForCommunity(
      communityId: comm.id,
      communityName: comm.name,
    );
    context.push(AppRoutes.sell);
  }

  @override
  Widget build(BuildContext context) {
    final commState = ref.watch(communityProvider);
    final match = commState.myCommunities.firstWhere(
      (c) => c.id == widget.community.id,
      orElse: () => commState.communities.firstWhere(
        (c) => c.id == widget.community.id,
        orElse: () => commState.selectedCommunity?.id == widget.community.id
            ? commState.selectedCommunity!
            : widget.community,
      ),
    );
    final community = match;
    final isAdmin = community.isAdmin || community.userRole == 'ADMIN';
    final isJoined = community.isJoined || isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: const Color(0xFFE2E8F0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 24, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ManageCommunityScreen(community: community),
              ),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F4F1),
                  shape: BoxShape.circle,
                ),
                child: (community.iconUrl != null && community.iconUrl!.isNotEmpty)
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: ApiClient.resolveMediaUrl(community.iconUrl!),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.groups_rounded,
                            color: Color(0xFF0F172A),
                            size: 22,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.groups_rounded,
                        color: Color(0xFF0F172A),
                        size: 22,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      community.name,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${community.membersCount > 0 ? _formatCurrency(community.membersCount) : '1'} members',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined, color: Color(0xFF0F172A), size: 24),
            tooltip: 'Community Members',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManageCommunityScreen(community: community),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              community.isMuted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_none_rounded,
              color: community.isMuted ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
              size: 24,
            ),
            tooltip: community.isMuted ? 'Unmute Notifications' : 'Mute Notifications',
            onPressed: () => _toggleMute(community),
          ),
          Theme(
            data: Theme.of(context).copyWith(
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF0F172A), size: 24),
              color: Colors.white,
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.18),
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              offset: const Offset(0, 48),
              onSelected: (val) {
                if (val == 'list_product') {
                  if (isJoined) {
                    _navigateToSell(community);
                  } else {
                    _showJoinToInteractModal(community);
                  }
                } else if (val == 'mute_toggle') {
                  _toggleMute(community);
                } else if (val == 'leave') {
                  _confirmLeaveCommunity(community);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem<String>(
                  value: 'list_product',
                  height: 48,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'List your product',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'mute_toggle',
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    community.isMuted ? 'Unmute Notification' : 'Mute Notification',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const PopupMenuDivider(height: 1),
                const PopupMenuItem<String>(
                  value: 'leave',
                  height: 48,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Leave Community',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: SafeArea(
        child: _isLoadingPosts
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF004E54)))
            : _communityPosts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6F4F1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.storefront_outlined, color: Color(0xFF004E54), size: 32),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No items in ${widget.community.name} yet',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E232A),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isJoined
                                ? 'Be the first to post something in this community!'
                                : 'Join this community to see and post items.',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (!isJoined) ...[
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final ok = await ref.read(communityProvider.notifier).joinCommunity(community.id);
                                if (mounted && ok) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Welcome to ${community.name}!'), backgroundColor: const Color(0xFF004E54)),
                                  );
                                  _loadRealPosts();
                                }
                              },
                              icon: const Icon(Icons.group_add_rounded, size: 18),
                              label: const Text('Join Community', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF004E54),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                          if (isJoined) ...[
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _navigateToSell(community),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Post First Item', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF004E54),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: const Color(0xFF004E54),
                    onRefresh: _loadRealPosts,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
                      itemCount: _communityPosts.length,
                      itemBuilder: (context, index) {
                        final post = _communityPosts[index];
                        return _CommunityPostCardItem(
                          post: post,
                          allPosts: _communityPosts,
                          isJoined: isJoined,
                          community: community,
                          onLike: (postId, action) => ref.read(communityProvider.notifier).likePost(postId, action: action),
                          onShare: (postId) => ref.read(communityProvider.notifier).sharePost(postId),
                          onContact: (seller, title) => _showContactSheet(seller, title),
                          onJoinPrompt: () => _showJoinToInteractModal(community),
                          onHide: _handleHidePost,
                          onRestrict: _handleRestrictUser,
                        );
                      },
                    ),
                  ),
      ),

      // Floating Action Button shown to all community members
      floatingActionButton: isJoined
          ? FloatingActionButton(
              onPressed: () => _navigateToSell(community),
              backgroundColor: const Color(0xFF004E54),
              elevation: 4,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            )
          : null,
    );
  }

  void _showJoinToInteractModal(CommunityModel community) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(color: Color(0xFFE6F4F1), shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF004E54), size: 26),
            ),
            const SizedBox(height: 16),
            const Text(
              'Members Only',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E232A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Join ${community.name} to make offers, bid, and contact sellers.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.group_add_rounded, color: Colors.white, size: 20),
                label: const Text('Join Community', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004E54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final ok = await ref.read(communityProvider.notifier).joinCommunity(community.id);
                  if (mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Welcome to ${community.name}!'), backgroundColor: const Color(0xFF004E54)),
                    );
                    ref.read(communityProvider.notifier).fetchMembers(community.id);
                    _loadRealPosts();
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not now', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF64748B))),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    num val = 0;
    if (amount is num) {
      val = amount;
    } else {
      val = num.tryParse(amount.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    }
    final str = val.toInt().toString();
    final len = str.length;
    if (len <= 3) return str;
    final last3 = str.substring(len - 3);
    String remaining = str.substring(0, len - 3);
    final buffer = StringBuffer();
    while (remaining.length > 2) {
      buffer.write(',${remaining.substring(remaining.length - 2)}');
      remaining = remaining.substring(0, remaining.length - 2);
    }
    return '$remaining$buffer,$last3';
  }


  Future<void> _toggleMute(CommunityModel community) async {
    final newMuted = await ref.read(communityProvider.notifier).toggleMuteCommunity(community.id);
    if (!mounted) return;

    BidlySnackBar.showUndo(
      context: context,
      message: newMuted
          ? 'Notifications muted for ${community.name}'
          : 'Notifications turned on for ${community.name}',
      icon: newMuted ? Icons.notifications_off_rounded : Icons.notifications_active_rounded,
      onUndo: () {
        ref.read(communityProvider.notifier).toggleMuteCommunity(community.id);
      },
    );
  }

}

class _CommunityPostCardItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final List<Map<String, dynamic>> allPosts;
  final bool isJoined;
  final CommunityModel community;
  final Future<Map<String, dynamic>?> Function(String postId, String action) onLike;
  final Future<int?> Function(String postId) onShare;
  final void Function(String sellerName, String productTitle) onContact;
  final VoidCallback onJoinPrompt;
  final void Function(String postId)? onHide;
  final void Function(String authorId, String authorName)? onRestrict;

  const _CommunityPostCardItem({
    required this.post,
    required this.allPosts,
    required this.isJoined,
    required this.community,
    required this.onLike,
    required this.onShare,
    required this.onContact,
    required this.onJoinPrompt,
    this.onHide,
    this.onRestrict,
  });

  @override
  State<_CommunityPostCardItem> createState() => _CommunityPostCardItemState();
}

class _CommunityPostCardItemState extends State<_CommunityPostCardItem> with TickerProviderStateMixin, WidgetsBindingObserver {
  late PageController _pageController;
  int _currentMediaIndex = 0;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isInitializingVideo = false;
  bool _isMuted = true;
  bool _showHeartBurst = false;

  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnim;
  late Animation<double> _heartOpacityAnim;

  late AnimationController _likeButtonAnimController;
  late Animation<double> _likeButtonScaleAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();

    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _heartScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInBack)), weight: 20),
    ]).animate(_heartAnimController);

    _heartOpacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_heartAnimController);

    _heartAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showHeartBurst = false);
      }
    });

    _likeButtonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );

    _likeButtonScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9).chain(CurveTween(curve: Curves.easeInCubic)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    ]).animate(_likeButtonAnimController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndInitVideoForSlide(0);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _videoController?.pause();
      if (mounted) setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant _CommunityPostCardItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post['id'] != widget.post['id']) {
      _disposeVideo();
      _currentMediaIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndInitVideoForSlide(0);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeVideo();
    _pageController.dispose();
    _heartAnimController.dispose();
    _likeButtonAnimController.dispose();
    super.dispose();
  }

  void _disposeVideo() {
    if (_videoController != null) {
      _videoController!.pause();
      _videoController!.dispose();
      _videoController = null;
      _isVideoInitialized = false;
      _isInitializingVideo = false;
    }
  }

  List<Map<String, dynamic>> _getMediaList() {
    final rawMediaItems = widget.post['mediaItems'] as List?;
    final List<Map<String, dynamic>> mediaList = [];
    if (rawMediaItems != null && rawMediaItems.isNotEmpty) {
      for (final item in rawMediaItems) {
        if (item is Map) {
          mediaList.add(Map<String, dynamic>.from(item));
        }
      }
    }
    if (mediaList.isEmpty) {
      final img = widget.post['imageUrl'] as String?;
      final vid = widget.post['videoUrl'] as String? ?? widget.post['reelUrl'] as String?;
      if (img != null && img.isNotEmpty) {
        mediaList.add({'url': img, 'type': 'IMAGE'});
      }
      if (vid != null && vid.isNotEmpty) {
        mediaList.add({'url': vid, 'type': 'VIDEO'});
      }
    }
    return mediaList;
  }

  void _checkAndInitVideoForSlide(int index) {
    final mediaList = _getMediaList();
    if (index < 0 || index >= mediaList.length) {
      _disposeVideo();
      return;
    }
    final item = mediaList[index];
    final isVideo = (item['type'] == 'VIDEO' || item['type']?.toString().toUpperCase() == 'VIDEO');
    final url = item['url']?.toString() ?? '';
    if (isVideo && url.isNotEmpty) {
      _initializeVideo(url);
    } else {
      _disposeVideo();
    }
  }

  Future<void> _initializeVideo(String rawUrl) async {
    _disposeVideo();
    final resolvedUrl = ApiClient.resolveMediaUrl(rawUrl);
    if (mounted) setState(() => _isInitializingVideo = true);

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(resolvedUrl));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.setLooping(true);
      controller.setVolume(_isMuted ? 0.0 : 1.0);
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent == true;
      if (isCurrentRoute) {
        controller.play();
      } else {
        controller.pause();
      }

      if (mounted) {
        setState(() {
          _videoController = controller;
          _isVideoInitialized = true;
          _isInitializingVideo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializingVideo = false;
          _isVideoInitialized = false;
        });
      }
      debugPrint('[CommunityPostCard] Failed to init video: $e');
    }
  }

  void _togglePlayPause() {
    if (_videoController != null && _isVideoInitialized) {
      setState(() {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
      });
    }
  }

  void _toggleMute() {
    if (_videoController != null && _isVideoInitialized) {
      final newMuted = !_isMuted;
      _videoController!.setVolume(newMuted ? 0.0 : 1.0);
      setState(() => _isMuted = newMuted);
    }
  }

  void _triggerDoubleTapHeart() {
    HapticFeedback.mediumImpact();
    setState(() => _showHeartBurst = true);
    _heartAnimController.forward(from: 0.0);

    final isLiked = widget.post['isLiked'] as bool? ?? false;
    if (!isLiked) {
      _handleLikeTap();
    }
  }

  void _handleLikeTap() async {
    final isLiked = widget.post['isLiked'] as bool? ?? false;
    final likesCount = widget.post['likesCount'] as int? ?? 0;
    final nextLiked = !isLiked;

    if (nextLiked) {
      HapticFeedback.mediumImpact();
      _likeButtonAnimController.forward(from: 0.0);
    } else {
      HapticFeedback.lightImpact();
      _likeButtonAnimController.forward(from: 0.0);
    }

    setState(() {
      widget.post['isLiked'] = nextLiked;
      widget.post['likesCount'] = nextLiked ? (likesCount + 1) : (likesCount > 0 ? likesCount - 1 : 0);
    });

    final result = await widget.onLike(
      widget.post['id'] as String,
      nextLiked ? 'like' : 'unlike',
    );
    if (result != null && mounted) {
      setState(() {
        if (result['liked'] != null) widget.post['isLiked'] = result['liked'];
        if (result['likesCount'] != null) widget.post['likesCount'] = result['likesCount'];
      });
    }
  }

  void _openFullReelScreen() {
    _videoController?.pause();
    _disposeVideo();
    final currentIndex = widget.allPosts.indexOf(widget.post);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityReelsScreen(
          community: widget.community,
          posts: widget.allPosts,
          initialIndex: currentIndex >= 0 ? currentIndex : 0,
        ),
      ),
    ).then((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        _checkAndInitVideoForSlide(_currentMediaIndex);
      }
    });
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    num val = 0;
    if (amount is num) {
      val = amount;
    } else {
      val = num.tryParse(amount.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    }
    final str = val.toInt().toString();
    final len = str.length;
    if (len <= 3) return str;
    final last3 = str.substring(len - 3);
    String remaining = str.substring(0, len - 3);
    final buffer = StringBuffer();
    while (remaining.length > 2) {
      buffer.write(',${remaining.substring(remaining.length - 2)}');
      remaining = remaining.substring(0, remaining.length - 2);
    }
    return '$remaining$buffer,$last3';
  }

  String _formatTimeRemaining(String? auctionEndTime) {
    if (auctionEndTime == null || auctionEndTime.isEmpty) return '2h 14m';
    try {
      final end = DateTime.parse(auctionEndTime);
      final diff = end.difference(DateTime.now().toUtc());
      if (diff.isNegative) return 'Ended';
      if (diff.inDays > 0) {
        return '${diff.inDays}d ${diff.inHours % 24}h';
      }
      if (diff.inHours > 0) {
        return '${diff.inHours}h ${diff.inMinutes % 60}m';
      }
      if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m';
      }
      return '${diff.inSeconds}s';
    } catch (_) {
      return '2h 14m';
    }
  }

  Widget _buildAuctionInfoCard() {
    final currentBidVal = widget.post['currentBid'] ?? widget.post['startingBid'] ?? widget.post['price'];
    final currentBidFormatted = _formatCurrency(currentBidVal);
    final bidsCount = widget.post['bidsCount'] as int? ?? 0;
    final timeRemaining = _formatTimeRemaining(widget.post['auctionEndTime'] as String?);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current bid',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹$currentBidFormatted',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$bidsCount bids placed',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFF59E0B)),
                const SizedBox(width: 5),
                Text(
                  '$timeRemaining remaining',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectBuyInfoCard() {
    final priceVal = widget.post['price'] ?? widget.post['priceText'];
    final priceFormatted = _formatCurrency(priceVal);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Direct Buy Price',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF15803D),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹$priceFormatted',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF166534),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF15803D)),
                SizedBox(width: 4),
                Text(
                  'Direct Buy',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSlide(Map<String, dynamic> item, int index) {
    final isVideo = (item['type'] == 'VIDEO' || item['type']?.toString().toUpperCase() == 'VIDEO');
    final url = item['url']?.toString() ?? '';

    if (isVideo) {
      if (_videoController != null && _isVideoInitialized) {
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayPause,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            ),
            // Paused Icon Overlay
            if (!_videoController!.value.isPlaying)
              Center(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
            // Mute / Unmute Button
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        return Container(
          color: Colors.black,
          child: Center(
            child: _isInitializingVideo && index == _currentMediaIndex
                ? const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF004E54)),
                    ),
                  )
                : GestureDetector(
                    onTap: () => _checkAndInitVideoForSlide(index),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 52),
                        SizedBox(height: 6),
                        Text(
                          'Tap to play Reel',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: ApiClient.resolveMediaUrl(url),
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF004E54),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, color: Color(0xFF94A3B8), size: 36),
        ),
      ),
    );
  }

  String _formatLocationBadge(Map<String, dynamic> post) {
    final double? dist = (post['distanceKm'] as num?)?.toDouble();
    final locality = post['locality'] as String?;
    final city = post['city'] as String?;
    final loc = locality?.trim().isNotEmpty == true
        ? locality!.trim()
        : (city?.trim().isNotEmpty == true ? city!.trim() : null);

    if (dist != null && dist > 0) {
      final distStr = dist < 0.1 ? '< 0.1 km' : '${dist.toStringAsFixed(1)} km';
      if (loc != null) {
        return '$loc · $distStr';
      }
      return distStr;
    }
    if (loc != null) return loc;
    return 'Nearby';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isAuction = post['sellingMethod'] == 'AUCTION';
    final isLiked = post['isLiked'] as bool? ?? false;
    final likesCount = post['likesCount'] as int? ?? 0;
    final sharesCount = post['sharesCount'] as int? ?? 0;
    final title = post['title'] as String? ?? '';
    final priceText = post['priceText'] as String? ?? '';
    final description = post['description'] as String? ?? '';

    final mediaList = _getMediaList();
    final currentItem = (mediaList.isNotEmpty && _currentMediaIndex < mediaList.length)
        ? mediaList[_currentMediaIndex]
        : null;
    final currentIsVideo = currentItem != null &&
        (currentItem['type'] == 'VIDEO' || currentItem['type']?.toString().toUpperCase() == 'VIDEO');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Author Row matching Screen 3
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                (post['authorAvatarUrl'] != null && (post['authorAvatarUrl'] as String).isNotEmpty)
                    ? CircleAvatar(
                        radius: 21,
                        backgroundImage: CachedNetworkImageProvider(
                          ApiClient.resolveMediaUrl(post['authorAvatarUrl'] as String),
                        ),
                      )
                    : Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF2FF),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(post['authorName'] as String? ?? 'Member'),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post['authorName'] as String? ?? 'Member',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, size: 13, color: Color(0xFF059669)),
                          const SizedBox(width: 3),
                          const Text(
                            'Trusted',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('·', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Text(
                            post['timeAgo'] as String? ?? 'Recently',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // More Options Menu (Not Interested, Restrict)
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerTheme: const DividerThemeData(
                      color: Color(0xFFF1F5F9),
                      thickness: 1,
                      space: 1,
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    tooltip: 'More options',
                    icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF64748B), size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 170, maxWidth: 200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
                    ),
                    color: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.12),
                    offset: const Offset(0, 36),
                    onOpened: () {
                      _videoController?.pause();
                      if (mounted) setState(() {});
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem<String>(
                        value: 'not_interested',
                        height: 48,
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          'Not Interested',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      PopupMenuDivider(height: 1),
                      PopupMenuItem<String>(
                        value: 'restrict',
                        height: 48,
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          'Restrict',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      final postId = post['id']?.toString() ?? '';
                      final authorId = post['authorId']?.toString() ?? '';
                      final authorName = post['authorName'] as String? ?? 'User';
                      if (value == 'not_interested') {
                        HapticFeedback.mediumImpact();
                        widget.onHide?.call(postId);
                      } else if (value == 'restrict') {
                        _showRestrictConfirmation(context, authorId, authorName);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. SWIPEABLE Product Media Carousel (Photos & Reels)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 240,
              width: double.infinity,
              color: const Color(0xFFF1F5F9),
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: mediaList.isNotEmpty ? mediaList.length : 1,
                    onPageChanged: (idx) {
                      setState(() => _currentMediaIndex = idx);
                      _checkAndInitVideoForSlide(idx);
                    },
                    itemBuilder: (context, index) {
                      if (mediaList.isEmpty) {
                        return Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 40),
                          ),
                        );
                      }
                      final item = mediaList[index];
                      return GestureDetector(
                        onDoubleTap: _triggerDoubleTapHeart,
                        child: _buildMediaSlide(item, index),
                      );
                    },
                  ),

                  // Animated Double-Tap Heart Burst
                  if (_showHeartBurst)
                    Positioned.fill(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _heartAnimController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _heartOpacityAnim.value,
                              child: Transform.scale(
                                scale: _heartScaleAnim.value,
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  color: Colors.white,
                                  size: 88,
                                  shadows: [
                                    Shadow(color: Colors.black45, blurRadius: 16),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Top-Left Badge: DIRECT BUY (Teal) or BIDDING (Red)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isAuction ? const Color(0xFFEF4444) : const Color(0xFF004E54),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAuction) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            isAuction ? 'BIDDING' : 'DIRECT BUY',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom-Left Badge: 📍 Location / Distance
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            _formatLocationBadge(post),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Watch Reel Button (If current slide is Video or post has reel)
                  if (currentIsVideo || post['videoUrl'] != null || post['reelUrl'] != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: _openFullReelScreen,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.ondemand_video_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Play Reel',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Multiple Media Page Indicator Dots / Pill
                  if (mediaList.length > 1)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_currentMediaIndex + 1}/${mediaList.length}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. Product Info: Title & Description
          const SizedBox(height: 14),
          if (title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              description,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // 4. Dark Auction Card or Direct Buy Card
          if (isAuction)
            _buildAuctionInfoCard()
          else
            _buildDirectBuyInfoCard(),

          // 5. Action Buttons (Gated ONLY for Joined Members)
          if (widget.isJoined)
            Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: Row(
                children: [
                  // View Details (Outlined Button)
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () async {
                          _videoController?.pause();
                          if (mounted) setState(() {});
                          final listingId = post['listingId'] as String?;
                          if (listingId != null && listingId.isNotEmpty) {
                            await context.push('/listing/$listingId');
                          } else {
                            widget.onContact(post['authorName'] as String? ?? 'Seller', title);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Make offer / Bid Now (Filled Primary Button)
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () async {
                          _videoController?.pause();
                          if (mounted) setState(() {});
                          final listingId = post['listingId'] as String?;
                          if (listingId != null && listingId.isNotEmpty) {
                            await context.push('/listing/$listingId');
                          } else {
                            widget.onContact(post['authorName'] as String? ?? 'Seller', title);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004E54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          isAuction ? 'Bid Now' : 'Make offer',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _videoController?.pause();
                    if (mounted) setState(() {});
                    widget.onJoinPrompt();
                  },
                  icon: const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF004E54)),
                  label: const Text(
                    'Join Community to Bid / Buy',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF004E54),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF004E54), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: const Color(0xFFE6F4F1),
                  ),
                ),
              ),
            ),

          // 6. Real-time Likes & Shares Footer
          Padding(
            padding: const EdgeInsets.only(top: 14.0),
            child: Row(
              children: [
                // Like Button with Bouncy Spring Scale
                GestureDetector(
                  onTap: _handleLikeTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _likeButtonScaleAnim,
                        child: Icon(
                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isLiked ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        likesCount.toString(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 22),

                // Share Button
                GestureDetector(
                  onTap: () async {
                    final newCount = await widget.onShare(post['id'] as String);
                    if (newCount != null && mounted) {
                      setState(() {
                        post['sharesCount'] = newCount;
                      });
                    }
                    final shareText = priceText.isNotEmpty
                        ? '$title — $priceText on Bidly Community'
                        : '$title on Bidly Community';
                    Share.share(shareText);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.share_outlined, color: Color(0xFF64748B), size: 19),
                      const SizedBox(width: 5),
                      Text(
                        sharesCount > 0 ? sharesCount.toString() : 'Share',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRestrictConfirmation(BuildContext context, String authorId, String authorName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Restrict $authorName?',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'You won\'t see posts from $authorName in your feed anymore.',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Color(0xFF64748B),
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              HapticFeedback.heavyImpact();
              widget.onRestrict?.call(authorId, authorName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Restrict',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


