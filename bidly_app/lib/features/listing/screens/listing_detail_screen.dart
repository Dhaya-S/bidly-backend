import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/bidly_loading_indicator.dart';
import '../../auction/models/auction_model.dart';
import '../../auction/providers/auction_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../explore/models/listing_model.dart';
import '../../profile/providers/my_listings_provider.dart';
import '../../home/services/reels_controller_manager.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;
  final ListingModel? initialListing;

  const ListingDetailScreen({
    super.key,
    required this.listingId,
    this.initialListing,
  });

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> with WidgetsBindingObserver {
  ListingModel? _listing;
  bool _isLoading = false;
  int _currentImageIndex = 0;
  bool _isWishlisted = false;
  final PageController _pageController = PageController();

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;
  bool _isVideoMuted = false;
  bool _isVideoBuffering = false;
  int _activeVideoIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReelsControllerManager().pauseAll();
    _listing = widget.initialListing;
    _isWishlisted = widget.initialListing?.isWishlisted ?? false;
    if (widget.initialListing?.isAuction == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(auctionProvider.notifier).initAuctionSilent(widget.listingId);
      });
    }
    _fetchListingDetails();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _videoController?.pause();
      if (mounted) {
        setState(() => _isVideoPlaying = false);
      }
    }
  }

  void _onMediaPageChanged(int index, List<MediaItemModel> mediaList) {
    setState(() => _currentImageIndex = index);
    if (index >= 0 && index < mediaList.length) {
      final item = mediaList[index];
      if (item.isVideo) {
        _initializeVideoForIndex(index, item.url);
      } else {
        _disposeVideoController();
      }
    }
  }

  Future<void> _initializeVideoForIndex(int index, String rawUrl) async {
    if (_activeVideoIndex == index && _videoController != null) return;
    _disposeVideoController();
    _activeVideoIndex = index;
    _isVideoPlaying = true;
    final resolvedUrl = ApiClient.resolveMediaUrl(rawUrl);
    final uri = Uri.parse(resolvedUrl);
    final controller = VideoPlayerController.networkUrl(uri);
    _videoController = controller;
    setState(() {
      _isVideoInitialized = false;
      _isVideoBuffering = true;
    });

    try {
      await controller.initialize();
      if (!mounted || _activeVideoIndex != index) {
        controller.dispose();
        return;
      }
      controller.setLooping(true);
      controller.setVolume(_isVideoMuted ? 0.0 : 1.0);
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent == true;
      if (isCurrentRoute && _isVideoPlaying) {
        controller.play();
      } else {
        controller.pause();
      }
      setState(() {
        _isVideoInitialized = true;
        _isVideoPlaying = isCurrentRoute && _isVideoPlaying;
        _isVideoBuffering = false;
      });
    } catch (e) {
      if (mounted && _activeVideoIndex == index) {
        setState(() {
          _isVideoInitialized = false;
          _isVideoBuffering = false;
        });
      }
    }
  }

  void _disposeVideoController() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    _isVideoPlaying = false;
    _isVideoBuffering = false;
    _activeVideoIndex = -1;
  }

  Future<void> _fetchListingDetails() async {
    if (_listing == null) {
      setState(() => _isLoading = true);
    }
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get('/listings/${widget.listingId}');
      if (res.data != null && res.data['success'] == true) {
        final data = res.data['data'] as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _listing = ListingModel.fromJson(data);
            _isWishlisted = _listing?.isWishlisted ?? false;
            _isLoading = false;
          });
          if (_listing?.isAuction == true) {
            ref.read(auctionProvider.notifier).initAuctionSilent(widget.listingId);
          }
          // If first item is video, initialize it
          if (_listing != null && _listing!.mediaItems.isNotEmpty && _listing!.mediaItems.first.isVideo) {
            _initializeVideoForIndex(0, _listing!.mediaItems.first.url);
          }
        }
      }
    } catch (_) {
      if (mounted && _listing == null) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onMakeOffer() async {
    if (_listing == null) return;
    _videoController?.pause();
    if (mounted) setState(() => _isVideoPlaying = false);
    final isDirectSale = _listing!.sellingMethod.toUpperCase() != 'AUCTION';
    if (isDirectSale) {
      await context.push(
        '/chat/offer/${_listing!.id}',
        extra: _listing,
      );
    } else {
      await context.push('/auction/${_listing!.id}/bid');
    }
  }

  void _shareListing() {
    if (_listing == null) return;
    _videoController?.pause();
    if (mounted) setState(() => _isVideoPlaying = false);
    Share.share('Check out "${_listing!.title}" on Bidly for ${_listing!.formattedPrice}!');
  }

  void _showDeleteConfirmationDialog(ListingModel listing) {
    _videoController?.pause();
    if (mounted) setState(() => _isVideoPlaying = false);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Red trash icon in light red circle (Matching design Frame 3)
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              const Text(
                'Delete permanently?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E232A),
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle / message
              const Text(
                'This item will be deleted and can\'t be recovered. Are you sure you want to continue?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(dialogCtx).pop();
                          final success = await ref
                              .read(myListingsProvider.notifier)
                              .deleteListing(listing.id);

                          if (!mounted) return;
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Post deleted successfully'),
                                backgroundColor: Color(0xFF004E54),
                              ),
                            );
                            context.pop(true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to delete post. Please try again.'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeVideoController();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _listing == null) {
      return const BidlyLoadingScreen(
        message: 'Loading listing details...',
        appBarTitle: 'Product Details',
        showBackButton: true,
      );
    }

    final listing = _listing;
    if (listing == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Product Details'),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 12),
              const Text('Listing not found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                child: const Text('Go Back', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final images = listing.imageUrls.isNotEmpty
        ? listing.imageUrls
        : (listing.primaryImageUrl != null && listing.primaryImageUrl!.isNotEmpty
            ? [listing.primaryImageUrl!]
            : <String>[]);

    final mediaList = listing.mediaItems.isNotEmpty
        ? listing.mediaItems
        : (images.map((img) => MediaItemModel(url: img, type: 'IMAGE')).toList());

    final isDirectSale = !listing.isAuction;
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final currentUserId = ref.watch(authProvider).user?.id;
    final isOwner = currentUserId != null && (listing.sellerId == currentUserId);

    final auctionState = ref.watch(auctionProvider);
    final auctionDetails = auctionState.auctionDetails;
    final liveStatus = auctionState.liveStatus;

    final currentHighestBid = liveStatus?.currentHighestBid ??
        auctionDetails?.currentHighestBid ??
        listing.currentBid ??
        listing.startingBid ??
        listing.price;
    final minNextBid = liveStatus?.minNextBid ??
        auctionDetails?.minNextBid ??
        (currentHighestBid + 500);
    final totalBids = liveStatus?.totalBids ?? auctionDetails?.totalBids ?? listing.bidsCount;
    final watching = liveStatus?.watchingCount ?? auctionDetails?.watchingCount ?? 0;
    String computeTimeLeft() {
      if (auctionState.timeLeftFormatted.isNotEmpty && auctionState.timeLeftFormatted != '--:--') {
        return auctionState.timeLeftFormatted;
      }
      final dtTime = auctionDetails?.timeLeftFormatted;
      if (dtTime != null && dtTime.isNotEmpty) {
        return dtTime;
      }
      if (listing.auctionEndTime != null) {
        final diff = listing.auctionEndTime!.difference(DateTime.now());
        if (diff.isNegative) return 'Ended';
        if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
        if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
        if (diff.inMinutes > 0) return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
        return '${diff.inSeconds}s';
      }
      return 'Ending soon';
    }
    final timeLeft = computeTimeLeft();
    final recentBids = (liveStatus?.liveBidFeed.isNotEmpty == true)
        ? liveStatus!.liveBidFeed
        : (auctionDetails?.recentBids.isNotEmpty == true
            ? auctionDetails!.recentBids
            : <BidHistoryItemModel>[]);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            _videoController?.pause();
            context.pop();
          },
        ),
        title: const Text(
          'Product Details',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              _isWishlisted ? Icons.favorite : Icons.favorite_border,
              color: _isWishlisted ? Colors.red : AppTheme.textPrimary,
              size: 22,
            ),
            onPressed: () {
              setState(() => _isWishlisted = !_isWishlisted);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppTheme.textPrimary, size: 22),
            onPressed: _shareListing,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Top Min Next Bid Bar (Only for Live Auction and Buyers)
          if (!isDirectSale && !isOwner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Min next bid: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        currencyFormatter.format(minNextBid),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () async {
                        _videoController?.pause();
                        if (mounted) setState(() => _isVideoPlaying = false);
                        await context.push('/auction/${listing.id}/bid');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text(
                        'Place Bid',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // Hero Image / Video Carousel
                Container(
                  height: 320,
                  width: double.infinity,
                  color: const Color(0xFFEDF5F5),
                  child: Stack(
                    children: [
                      if (mediaList.isNotEmpty)
                        PageView.builder(
                          controller: _pageController,
                          itemCount: mediaList.length,
                          onPageChanged: (idx) => _onMediaPageChanged(idx, mediaList),
                          itemBuilder: (ctx, i) {
                            final item = mediaList[i];
                            if (item.isVideo) {
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (_isVideoInitialized && !_isVideoBuffering && _videoController != null && _activeVideoIndex == i)
                                    Center(
                                      child: AspectRatio(
                                        aspectRatio: _videoController!.value.aspectRatio > 0
                                            ? _videoController!.value.aspectRatio
                                            : 16 / 9,
                                        child: VideoPlayer(_videoController!),
                                      ),
                                    )
                                  else
                                    Container(
                                      color: Colors.black87,
                                      child: const Center(
                                        child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
                                      ),
                                    ),
                                  // Play/Pause tap overlay
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        if (_videoController != null && _isVideoInitialized) {
                                          setState(() {
                                            if (_videoController!.value.isPlaying) {
                                              _videoController!.pause();
                                              _isVideoPlaying = false;
                                            } else {
                                              _videoController!.play();
                                              _isVideoPlaying = true;
                                            }
                                          });
                                        }
                                      },
                                      child: Center(
                                        child: !_isVideoPlaying && _isVideoInitialized
                                            ? Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                  // Video Type Indicator Badge (Bottom Left)
                                  Positioned(
                                    bottom: 14,
                                    left: 14,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            'VIDEO',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Mute/Unmute button
                                  if (_isVideoInitialized)
                                    Positioned(
                                      top: 14,
                                      right: 14,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isVideoMuted = !_isVideoMuted;
                                            _videoController?.setVolume(_isVideoMuted ? 0.0 : 1.0);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.65),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _isVideoMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }

                            // Image item with CachedNetworkImage
                            final resolved = ApiClient.resolveMediaUrl(item.url);
                            return CachedNetworkImage(
                              imageUrl: resolved,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              memCacheWidth: 1080,
                              maxWidthDiskCache: 1920,
                              placeholder: (_, __) => Container(
                                color: const Color(0xFFF1F5F9),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFFEDF5F5),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 36),
                                      const SizedBox(height: 6),
                                      ElevatedButton.icon(
                                        onPressed: () => setState(() {}),
                                        icon: const Icon(Icons.refresh, size: 14),
                                        label: const Text('Retry', style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: Size.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        _buildImagePlaceholder(),

                      // Top Badges
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDirectSale ? AppTheme.primary : const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isDirectSale) ...[
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                isDirectSale ? 'Direct' : 'LIVE AUCTION',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F8F0),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Color(0xFF10B981), size: 7),
                              SizedBox(width: 5),
                              Text(
                                'Active',
                                style: TextStyle(
                                  color: Color(0xFF047857),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Carousel Indicator Dots
                      if (mediaList.length > 1)
                        Positioned(
                          bottom: 14,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(mediaList.length, (index) {
                              final isSelected = index == _currentImageIndex;
                              final isVid = mediaList[index].isVideo;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: isSelected ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isVid ? const Color(0xFF2DD4BF) : AppTheme.primary)
                                      : AppTheme.primary.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ),

                      // Floating Watch Reel Button
                      if (listing.reelUrl != null && listing.reelUrl!.trim().isNotEmpty)
                        Positioned(
                          bottom: 12,
                          right: 14,
                          child: GestureDetector(
                            onTap: () {
                              _videoController?.pause();
                              if (mounted) setState(() => _isVideoPlaying = false);
                              context.push('/home?tab=0');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_circle_fill_rounded, color: Color(0xFF2DD4BF), size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Watch Reel',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Thumbnail Selector Strip (Image 1 Screen 2)
                if (mediaList.length > 1)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: mediaList.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final isSelected = i == _currentImageIndex;
                          final item = mediaList[i];
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: ApiClient.resolveMediaUrl(item.url),
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: const Color(0xFFF1F5F9)),
                                      errorWidget: (_, __, ___) => const Icon(Icons.image, size: 20, color: Colors.grey),
                                    ),
                                    if (item.isVideo)
                                      Container(
                                        color: Colors.black38,
                                        child: const Center(
                                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Teal Live Auction Card (Image 1 Screen 2)
                if (!isDirectSale)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D3B3F),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D3B3F).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CURRENT HIGHEST BID',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF99F6E4),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormatter.format(currentHighestBid),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$totalBids bids · $watching watching',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFCCFBF1),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                timeLeft,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main Info Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              listing.title,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (isOwner) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                _videoController?.pause();
                                if (mounted) setState(() => _isVideoPlaying = false);
                                final updated = await context.push(
                                  AppRoutes.editListing,
                                  extra: listing,
                                );
                                if (updated == true && mounted) {
                                  _fetchListingDetails();
                                  ref.read(myListingsProvider.notifier).fetchMyListings();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isDirectSale) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              listing.formattedPrice,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              currencyFormatter.format(listing.price * 1.35),
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppTheme.textSecondary,
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              listing.formattedCondition,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              listing.formattedLocation,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Key Specs Chips
                      Builder(
                        builder: (context) {
                          final chips = <String>[];
                          if (listing.subcategory != null && listing.subcategory!.trim().isNotEmpty) {
                            chips.add(listing.subcategory!.trim());
                          } else if (listing.categoryName != null && listing.categoryName!.trim().isNotEmpty) {
                            chips.add(listing.categoryName!.trim());
                          }
                          chips.add(listing.formattedCondition);
                          if (!listing.hasDamage) {
                            chips.add('Flawless Condition');
                          } else if (listing.damageDetails != null && listing.damageDetails!.trim().isNotEmpty) {
                            chips.add(listing.damageDetails!.trim());
                          }
                          if (listing.locality != null && listing.locality!.trim().isNotEmpty) {
                            chips.add(listing.locality!.trim());
                          } else if (listing.city != null && listing.city!.trim().isNotEmpty) {
                            chips.add(listing.city!.trim());
                          }
                          if (!isDirectSale) {
                            chips.add('Verified Auction');
                          } else {
                            chips.add('Instant Buy');
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: chips.map((c) => _buildSpecChip(c)).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Description Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
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
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          listing.description?.isNotEmpty == true
                              ? listing.description!
                              : 'High-quality item in great condition. Verified by local community members. Includes all original accessories.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Details / Specs Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
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
                          'Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildDetailRow('Category', listing.categoryName ?? 'Electronics'),
                        if (listing.subcategory != null)
                          _buildDetailRow('Subcategory', listing.subcategory!),
                        _buildDetailRow('Condition', listing.formattedCondition),
                        if (listing.purchaseDate != null)
                          _buildDetailRow('Purchased', listing.purchaseDate!),
                        _buildDetailRow('Damage / Wear', listing.hasDamage ? (listing.damageDetails ?? 'Minor wear') : 'None (Flawless)'),
                        _buildDetailRow('Selling Method', isDirectSale ? 'Direct Buy & Chat' : 'Auction Bid'),

                        const SizedBox(height: 16),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildTagChip('Local Pickup'),
                            _buildTagChip('Verified Item'),
                            _buildTagChip('Original Accessories'),
                            _buildTagChip('Negotiable'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (isOwner) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => _showDeleteConfirmationDialog(listing),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Delete Post',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ] else ...[
                  const SizedBox(height: 12),

                  // Seller Card
                  Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
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
                          'Seller',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.primary,
                              child: Text(
                                (listing.sellerName != null && listing.sellerName!.isNotEmpty)
                                    ? listing.sellerName![0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          listing.sellerName ?? 'Verified Seller',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified, color: AppTheme.primary, size: 16),
                                      const SizedBox(width: 2),
                                      const Text(
                                        'Verified',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        listing.rating > 0
                                            ? listing.rating.toStringAsFixed(1)
                                            : 'New Seller',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bid History Card (Image 1 Screen 2)
                if (!isDirectSale) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
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
                              Text(
                                'Bid History (${recentBids.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (recentBids.isNotEmpty)
                                const Text(
                                  'Live',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (recentBids.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.gavel_outlined, size: 36, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No bids placed yet',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blueGrey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Be the first to place a bid on this item!',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...recentBids.take(6).map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: b.isHighest ? const Color(0xFF004E54) : const Color(0xFFF1F5F9),
                                    child: Text(
                                      b.bidderInitials,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: b.isHighest ? Colors.white : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              b.isCurrentUser ? 'You' : b.bidderName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: b.isCurrentUser ? const Color(0xFF004E54) : AppTheme.textPrimary,
                                              ),
                                            ),
                                            if (b.isHighest) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDCFCE7),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'HIGHEST',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF15803D),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          b.relativeTime,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    currencyFormatter.format(b.amount),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: b.isHighest ? const Color(0xFFEF4444) : AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        ],
                      ),
                    ),
                  ),
                ],
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),

          // Sticky Bottom Bar (Only for buyers)
          if (!isOwner)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary),
                        onPressed: _onMakeOffer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _onMakeOffer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDirectSale ? AppTheme.primary : const Color(0xFFEF4444),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isDirectSale ? 'Make Offer' : 'Place Bid',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ],
),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF15803D),
        ),
      ),
    );
  }

  Widget _buildSpecChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF15803D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFFEDF5F5),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 72,
          color: AppTheme.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
