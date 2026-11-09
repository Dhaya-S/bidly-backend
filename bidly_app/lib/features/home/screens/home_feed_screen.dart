import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/bidly_loading_indicator.dart';
import '../../auth/models/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../posts/providers/posts_provider.dart';
import '../../posts/widgets/post_card.dart';
import '../../profile/providers/notifications_provider.dart';
import '../providers/reels_provider.dart';
import '../widgets/reel_player_card.dart';

import '../../../core/providers/live_location_provider.dart';
import '../services/reels_controller_manager.dart';
import 'main_shell_screen.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> with WidgetsBindingObserver {
  final ValueNotifier<int> _activeReelNotifier = ValueNotifier<int>(0);
  final PageController _pageController = PageController();
  late final PageController _horizontalTabController;
  double _horizontalScrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialTab = ref.read(reelsProvider).activeTab;
    _horizontalTabController = PageController(initialPage: initialTab);
    _horizontalScrollOffset = initialTab.toDouble();
    _horizontalTabController.addListener(_onHorizontalScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reelsProvider.notifier).fetchReels();
    });
  }

  void _onHorizontalScroll() {
    if (!_horizontalTabController.hasClients || _horizontalTabController.page == null) return;
    final page = _horizontalTabController.page!;
    if ((page - _horizontalScrollOffset).abs() > 0.005) {
      setState(() {
        _horizontalScrollOffset = page.clamp(0.0, 1.0);
      });
    }
    // Instantly pause video reels when swiping away from Feed towards Posts (> 0.05)
    if (page > 0.05) {
      if (!ReelsControllerManager().isPaused) {
        ReelsControllerManager().pauseAll();
      }
    } else if (page <= 0.02 && ref.read(reelsProvider).activeTab == 0) {
      final selectedNavIndex = ref.read(selectedNavIndexProvider);
      if (selectedNavIndex == 0 && ModalRoute.of(context)?.isCurrent == true) {
        if (ReelsControllerManager().isPaused) {
          ReelsControllerManager().resumeCurrent();
        }
      }
    }
  }

  void _onHorizontalPageChanged(int index) {
    if (index == 0) {
      ref.read(reelsProvider.notifier).setActiveTab(0);
      ref.read(postsProvider.notifier).setActiveTab(0);
      final selectedNavIndex = ref.read(selectedNavIndexProvider);
      if (selectedNavIndex == 0 && ModalRoute.of(context)?.isCurrent == true) {
        if (ReelsControllerManager().isPaused) {
          ReelsControllerManager().resumeCurrent();
        }
      }
    } else {
      ref.read(reelsProvider.notifier).setActiveTab(1);
      ref.read(postsProvider.notifier).setActiveTab(1);
      if (!ReelsControllerManager().isPaused) {
        ReelsControllerManager().pauseAll();
      }
    }
  }

  void _switchToTab(int index) {
    if (!_horizontalTabController.hasClients) return;
    ref.read(reelsProvider.notifier).setActiveTab(index);
    ref.read(postsProvider.notifier).setActiveTab(index);
    if (index == 1) {
      if (!ReelsControllerManager().isPaused) {
        ReelsControllerManager().pauseAll();
      }
    } else {
      if (ReelsControllerManager().isPaused) {
        ReelsControllerManager().resumeCurrent();
      }
    }
    _horizontalTabController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      ReelsControllerManager().pauseAll();
    } else {
      final selectedNavIndex = ref.read(selectedNavIndexProvider);
      final isFeedTab = ref.read(reelsProvider).activeTab == 0;
      if (selectedNavIndex == 0 && isFeedTab && ModalRoute.of(context)?.isCurrent == true) {
        ReelsControllerManager().resumeCurrent();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _horizontalTabController.removeListener(_onHorizontalScroll);
    _horizontalTabController.dispose();
    _pageController.dispose();
    _activeReelNotifier.dispose();
    ReelsControllerManager().disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status != next.status && next.status == AuthStatus.authenticated) {
        ref.read(reelsProvider.notifier).fetchReels(isRefresh: true);
      }
    });

    ref.listen<ReelsState>(reelsProvider, (previous, next) {
      if (previous?.activeTab != next.activeTab) {
        if (_horizontalTabController.hasClients &&
            _horizontalTabController.page?.round() != next.activeTab) {
          _horizontalTabController.animateToPage(
            next.activeTab,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      }
      if (next.reelListings.isNotEmpty &&
          (previous == null ||
              previous.reelListings.length != next.reelListings.length ||
              (previous.reelListings.isNotEmpty &&
                  previous.reelListings.first.id != next.reelListings.first.id))) {
        final reelIds = next.reelListings.map((r) => r.id).toList();
        final currentIdx = _pageController.hasClients && _pageController.page != null
            ? _pageController.page!.round()
            : 0;
        ReelsControllerManager().setActiveIndex(currentIdx, reelIds);
      }
    });

    final reelsState = ref.watch(reelsProvider);
    final postsState = ref.watch(postsProvider);
    final selectedNavIndex = ref.watch(selectedNavIndexProvider);
    final isHomeVisible = selectedNavIndex == 0;
    final liveLocation = ref.watch(liveLocationProvider);
    final locationText = liveLocation.displayText;
    final notifState = ref.watch(notificationsProvider);

    final t = _horizontalScrollOffset;
    final isMostlyFeed = t < 0.5;

    final systemOverlay = isMostlyFeed
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          );

    final logoColor = Color.lerp(Colors.white, AppTheme.primary, t) ?? Colors.white;
    final locationBgColor = Color.lerp(
      const Color(0xFF1E232A).withValues(alpha: 0.85),
      AppTheme.primarySoft,
      t,
    ) ?? AppTheme.primarySoft;
    final locationTextColor = Color.lerp(Colors.white, AppTheme.primary, t) ?? Colors.white;
    final notifBgColor = Color.lerp(
      const Color(0xFF1E232A).withValues(alpha: 0.85),
      AppTheme.surfaceVariant,
      t,
    ) ?? AppTheme.surfaceVariant;
    final notifIconColor = Color.lerp(Colors.white, AppTheme.textPrimary, t) ?? Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlay,
      child: Scaffold(
        backgroundColor: isMostlyFeed ? Colors.black : Colors.white,
        body: Stack(
          children: [
            // ─── HORIZONTAL PAGEVIEW: SWIPE BETWEEN FEED (REELS) & POSTS ────────
            PageView(
              controller: _horizontalTabController,
              physics: const ClampingScrollPhysics(),
              onPageChanged: _onHorizontalPageChanged,
              children: [
                // ─── PAGE 0: VIDEO REEL FEED ─────────────────────────────────────
                _KeepAlivePage(
                  child: Container(
                    color: Colors.black,
                    child: reelsState.isLoading && reelsState.reelListings.isEmpty
                        ? _buildShimmerPlaceholder()
                        : reelsState.reelListings.isEmpty
                            ? _buildEmptyReelsState()
                            : PageView.builder(
                                controller: _pageController,
                                scrollDirection: Axis.vertical,
                                padEnds: false,
                                physics: const ClampingScrollPhysics(),
                                itemCount: reelsState.reelListings.length,
                                onPageChanged: (idx) {
                                  _activeReelNotifier.value = idx;
                                  final reelIds = reelsState.reelListings.map((r) => r.id).toList();
                                  ReelsControllerManager().setActiveIndex(idx, reelIds);
                                  // Trigger background pre-fetch when approaching the end of the loaded reels
                                  if (idx >= reelsState.reelListings.length - 3 &&
                                      reelsState.hasMore &&
                                      !reelsState.isLoadingMore) {
                                    ref.read(reelsProvider.notifier).fetchNextPage();
                                  }
                                },
                                itemBuilder: (context, index) {
                                  return ReelPlayerCard(
                                    key: ValueKey(reelsState.reelListings[index].id),
                                    listing: reelsState.reelListings[index],
                                    itemIndex: index,
                                    activeNotifier: _activeReelNotifier,
                                    isHomeVisible: isHomeVisible && t < 0.5,
                                  );
                                },
                              ),
                  ),
                ),

                // ─── PAGE 1: POSTS FEED ──────────────────────────────────────────
                _KeepAlivePage(
                  child: Container(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 110),
                      child: RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: () => ref.read(postsProvider.notifier).fetchFeed(isRefresh: true),
                        child: postsState.isLoading && postsState.posts.isEmpty
                            ? const Center(child: BidlyLoadingIndicator(message: 'Loading community feed...'))
                            : postsState.posts.isEmpty
                                ? _buildEmptyPostsState()
                                : NotificationListener<ScrollNotification>(
                                    onNotification: (notification) {
                                      if (notification.metrics.extentAfter < 500) {
                                        ref.read(postsProvider.notifier).fetchNextPage();
                                      }
                                      return false;
                                    },
                                    child: ListView.builder(
                                      padding: const EdgeInsets.only(bottom: 90),
                                      itemCount: postsState.posts.length + (postsState.isLoadingMore ? 1 : 0),
                                      itemBuilder: (context, index) {
                                        if (index >= postsState.posts.length) {
                                          return const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 20),
                                            child: Center(
                                              child: SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return PostCard(
                                          key: ValueKey(postsState.posts[index].id),
                                          post: postsState.posts[index],
                                        );
                                      },
                                    ),
                                  ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ─── FLOATING TOP HEADER OVERLAY (BIDLY | Location | Notifications | Tabs) ─
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: t),
                  gradient: t < 0.99
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.85 * (1.0 - t)),
                            Colors.transparent,
                          ],
                        )
                      : null,
                  border: t > 0.1
                      ? Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.7 * t)))
                      : null,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Row: BIDLY Logo | Location Pill | Notification Bell
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            // BIDLY Logo
                            Text(
                              'BIDLY',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: logoColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Center Location Pill (Flexibly bounded to prevent overflow on narrow screens)
                            Expanded(
                              child: Center(
                                child: GestureDetector(
                                  onTap: () => _showLocationPicker(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    constraints: const BoxConstraints(maxWidth: 180),
                                    decoration: BoxDecoration(
                                      color: locationBgColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: t < 0.9
                                          ? Border.all(color: Colors.white.withValues(alpha: 0.15 * (1.0 - t)))
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 14,
                                          color: locationTextColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            locationText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: locationTextColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: locationTextColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Notification Bell with dynamic badge and navigation
                            GestureDetector(
                              onTap: () async {
                                ReelsControllerManager().pauseAll();
                                await context.push(AppRoutes.notifications);
                                if (context.mounted) {
                                  final isFeedTab = ref.read(reelsProvider).activeTab == 0;
                                  final selectedNavIndex = ref.read(selectedNavIndexProvider);
                                  if (selectedNavIndex == 0 && isFeedTab && ModalRoute.of(context)?.isCurrent == true) {
                                    ReelsControllerManager().resumeCurrent();
                                  }
                                }
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: notifBgColor,
                                      shape: BoxShape.circle,
                                      border: t < 0.9
                                          ? Border.all(color: Colors.white.withValues(alpha: 0.15 * (1.0 - t)))
                                          : null,
                                    ),
                                    child: Icon(
                                      Icons.notifications_none_rounded,
                                      color: notifIconColor,
                                      size: 20,
                                    ),
                                  ),
                                  if (notifState.unreadCount > 0)
                                    Positioned(
                                      top: -2,
                                      right: -2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Center(
                                          child: Text(
                                            notifState.unreadCount > 99
                                                ? '99+'
                                                : '${notifState.unreadCount}',
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              color: Colors.white,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              height: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Sub-tabs: [ Feed ]  [ Posts ] with Instagram-style gliding indicator
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final totalWidth = constraints.maxWidth;
                          final tabWidth = totalWidth / 2;
                          const indicatorWidth = 44.0;
                          final indicatorLeft = (tabWidth * (0.5 + t)) - (indicatorWidth / 2);
                          final indicatorColor = Color.lerp(Colors.white, AppTheme.primary, t) ?? Colors.white;

                          return Stack(
                            children: [
                              Row(
                                children: [
                                  // Feed Tab (Video Reels)
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _switchToTab(0),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Feed',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14.5,
                                            fontWeight: t < 0.5 ? FontWeight.w800 : FontWeight.w500,
                                            color: Color.lerp(
                                              Colors.white,
                                              const Color(0xFF94A3B8),
                                              t,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Posts Tab (Community Discussion)
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _switchToTab(1),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Posts',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14.5,
                                            fontWeight: t >= 0.5 ? FontWeight.w800 : FontWeight.w500,
                                            color: Color.lerp(
                                              const Color(0xFF94A3B8),
                                              AppTheme.primary,
                                              t,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Sliding active indicator bar
                              Positioned(
                                bottom: 0,
                                left: indicatorLeft.clamp(0.0, totalWidth - indicatorWidth),
                                child: Container(
                                  height: 2.5,
                                  width: indicatorWidth,
                                  decoration: BoxDecoration(
                                    color: indicatorColor,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: t < 0.4
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.35),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyReelsState([String? errorMessage]) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFF1E232A),
                shape: BoxShape.circle,
              ),
              child: Icon(
                errorMessage != null ? Icons.cloud_off_rounded : Icons.video_library_outlined,
                size: 36,
                color: errorMessage != null ? const Color(0xFFEF4444) : const Color(0xFF004E54),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              errorMessage != null ? 'Unable to Load Feed' : 'No Video Reels Available',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'When users list products with reels or videos, they appear here!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => ref.read(reelsProvider.notifier).fetchReels(isRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh Feed', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004E54),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPostsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.dynamic_feed_rounded,
              size: 56,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No posts yet in your community',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Be the first to list an item or start a discussion!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => ref.read(postsProvider.notifier).fetchFeed(isRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(140, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationPicker(BuildContext context) async {
    ReelsControllerManager().pauseAll();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Real-Time Live Location',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
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
              const SizedBox(height: 6),
              const Text(
                'High-precision live GPS feed. Automatically matches your nearby hyperlocal marketplace items.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              // Current Live GPS card
              Consumer(
                builder: (context, ref, _) {
                  final liveLoc = ref.watch(liveLocationProvider);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: Color(0xFF16A34A),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current GPS Location',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              Text(
                                liveLoc.displayText,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF14532D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Refresh GPS CTA
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(liveLocationProvider.notifier).fetchLiveLocation();
                    ref.read(reelsProvider.notifier).fetchReels(isRefresh: true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Live GPS location refreshed!'),
                          backgroundColor: AppTheme.primary,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Refresh Live Location via GPS',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (context.mounted) {
      final selectedNavIndex = ref.read(selectedNavIndexProvider);
      final isFeedTab = ref.read(reelsProvider).activeTab == 0;
      if (selectedNavIndex == 0 && isFeedTab && ModalRoute.of(context)?.isCurrent == true) {
        ReelsControllerManager().resumeCurrent();
      }
    }
  }

  Widget _buildShimmerPlaceholder() {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle dark gradient placeholder
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF020617)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Centered delicate branding loader
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF004E54).withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Loading Feed...',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
