import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/bidly_snackbar.dart';
import '../../auth/models/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../explore/models/listing_model.dart';
import '../providers/reels_provider.dart';
import '../services/reels_controller_manager.dart';

class ReelPlayerCard extends ConsumerStatefulWidget {
  final ListingModel listing;
  final int itemIndex;
  final ValueNotifier<int> activeNotifier;
  final bool isHomeVisible;

  const ReelPlayerCard({
    super.key,
    required this.listing,
    required this.itemIndex,
    required this.activeNotifier,
    this.isHomeVisible = true,
  });

  @override
  ConsumerState<ReelPlayerCard> createState() => _ReelPlayerCardState();
}

class _ReelPlayerCardState extends ConsumerState<ReelPlayerCard>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _firstFrameRendered = false;
  bool _isInitializing = false;
  bool _initFailed = false;
  bool _isMuted = false;
  bool _isDescriptionExpanded = false;
  late int _bidsCount;

  // Instagram Heart Animation Controller
  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnim;
  late Animation<double> _heartOpacityAnim;
  bool _showHeartAnim = false;

  // Play/Pause indicator controller
  late AnimationController _playPauseAnimController;
  bool _showPlayPause = false;
  bool _isPlayingState = true;

  // Instagram Like Button Bouncy Spring Animation Controller
  late AnimationController _likeButtonAnimController;
  late Animation<double> _likeButtonScaleAnim;

  @override
  void initState() {
    super.initState();
    _bidsCount = widget.listing.bidsCount;

    // Initialize Heart Animation (Instagram style)
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _heartScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3).chain(CurveTween(curve: Curves.easeOutBack)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 30),
    ]).animate(_heartAnimController);

    _heartOpacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    ]).animate(_heartAnimController);

    // Initialize Play/Pause icon animation
    _playPauseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

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

    widget.activeNotifier.addListener(_onActiveIndexChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkPlaybackState(widget.activeNotifier.value);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ReelPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeNotifier != oldWidget.activeNotifier) {
      oldWidget.activeNotifier.removeListener(_onActiveIndexChanged);
      widget.activeNotifier.addListener(_onActiveIndexChanged);
    }
    if (widget.listing.id != oldWidget.listing.id) {
      _isDescriptionExpanded = false;
    }
    if (widget.listing.id != oldWidget.listing.id || widget.isHomeVisible != oldWidget.isHomeVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkPlaybackState(widget.activeNotifier.value);
        }
      });
    }
  }

  void _onActiveIndexChanged() {
    if (mounted) {
      if (widget.itemIndex != widget.activeNotifier.value && _isDescriptionExpanded) {
        setState(() => _isDescriptionExpanded = false);
      }
      _checkPlaybackState(widget.activeNotifier.value);
    }
  }

  void _checkPlaybackState(int activeIdx) {
    if (!widget.isHomeVisible) {
      if (_videoController != null) {
        _videoController?.pause();
        _detachControllerListener();
      }
      if (mounted && _isPlayingState) {
        setState(() => _isPlayingState = false);
      }
      return;
    }

    final isCurrent = widget.itemIndex == activeIdx;
    final isPreload = widget.itemIndex == activeIdx + 1;
    final isPrevious = widget.itemIndex == activeIdx - 1;
    final isDistant = !isCurrent && !isPreload && !isPrevious;

    if (isCurrent) {
      _acquireVideo(autoPlay: true, activeIndex: activeIdx);
    } else if (isPreload) {
      _acquireVideo(autoPlay: false, activeIndex: activeIdx);
    } else if (isPrevious) {
      final controller = ReelsControllerManager().getController(widget.listing.id);
      if (controller != null && controller.value.isInitialized) {
        _videoController = controller;
        _isVideoInitialized = true;
        controller.pause();
      }
      if (mounted && _isPlayingState) {
        setState(() => _isPlayingState = false);
      }
    } else if (isDistant) {
      if (_videoController != null || _isInitializing) {
        _videoController?.pause();
        _detachControllerListener();
        _videoController = null;
        _isVideoInitialized = false;
        _firstFrameRendered = false;
        _isInitializing = false;
      }
    }
  }

  void _attachControllerListener(VideoPlayerController controller) {
    controller.removeListener(_videoPlayerListener);
    controller.addListener(_videoPlayerListener);
  }

  void _detachControllerListener() {
    _videoController?.removeListener(_videoPlayerListener);
  }

  void _videoPlayerListener() {
    final controller = _videoController;
    if (controller == null || !mounted) return;

    if (controller.value.isInitialized) {
      final isPlaying = controller.value.isPlaying;
      final hasPosition = controller.value.position > Duration.zero;

      if ((isPlaying || hasPosition) && !_firstFrameRendered) {
        final timing = ReelsControllerManager().getTiming(widget.listing.id);
        timing?.markFirstFrame();
        timing?.printSummary();

        setState(() {
          _firstFrameRendered = true;
        });

        // Trigger staged preload for next card once current is actively playing
        if (widget.itemIndex == widget.activeNotifier.value) {
          ReelsControllerManager().notifyCurrentReady(widget.itemIndex);
        }
      }
    }
  }

  void _acquireVideo({bool autoPlay = false, int? activeIndex}) {
    final rawReelUrl = widget.listing.reelUrl;
    if (rawReelUrl == null || rawReelUrl.trim().isEmpty) return;

    // Check if manager already has a ready controller for this listing
    final existing = ReelsControllerManager().getController(widget.listing.id);
    if (existing != null && existing.value.isInitialized) {
      _attachControllerListener(existing);
      final hasPosition = existing.value.position > Duration.zero;
      final isPlaying = existing.value.isPlaying;
      setState(() {
        _videoController = existing;
        _isVideoInitialized = true;
        _isInitializing = false;
        _initFailed = false;
        _isPlayingState = isPlaying;
        if (hasPosition || isPlaying) {
          _firstFrameRendered = true;
        }
      });
      if (autoPlay) {
        existing.setLooping(true);
        existing.play();
        ReelsControllerManager().notifyCurrentReady(widget.itemIndex);
      }
      return;
    }

    if (_isInitializing) return;
    _isInitializing = true;

    final currentActive = activeIndex ?? widget.activeNotifier.value;

    ReelsControllerManager().acquireController(
      listingId: widget.listing.id,
      rawReelUrl: rawReelUrl,
      itemIndex: widget.itemIndex,
      activeIndex: currentActive,
      autoPlay: autoPlay,
      onReady: () {
        if (mounted) {
          final controller = ReelsControllerManager().getController(widget.listing.id);
          if (controller != null) {
            _attachControllerListener(controller);
          }
          setState(() {
            _videoController = controller;
            _isVideoInitialized = controller != null && controller.value.isInitialized;
            _isInitializing = false;
            _initFailed = false;
            _isPlayingState = controller != null && controller.value.isPlaying;
          });
        }
      },
      onError: () {
        if (mounted) {
          _detachControllerListener();
          setState(() {
            _videoController = null;
            _isVideoInitialized = false;
            _firstFrameRendered = false;
            _isInitializing = false;
            _initFailed = true;
          });
        }
      },
    ).then((controller) {
      if (mounted && controller != null) {
        _attachControllerListener(controller);
        setState(() {
          _videoController = controller;
          _isVideoInitialized = controller.value.isInitialized;
          _isInitializing = false;
          _initFailed = false;
          _isPlayingState = controller.value.isPlaying;
        });
      }
    });
  }

  @override
  void dispose() {
    widget.activeNotifier.removeListener(_onActiveIndexChanged);
    _detachControllerListener();
    _isInitializing = false;
    _heartAnimController.dispose();
    _playPauseAnimController.dispose();
    _likeButtonAnimController.dispose();
    _videoController = null;
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoController?.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  bool _ensureAuthenticated() {
    final authState = ref.read(authProvider);
    if (authState.status != AuthStatus.authenticated || authState.user == null) {
      BidlySnackBar.show(
        context: context,
        message: 'Please sign in to like reels',
        icon: Icons.favorite_border_rounded,
      );
      context.push(AppRoutes.login);
      return false;
    }
    return true;
  }

  void _toggleLike() {
    if (!_ensureAuthenticated()) return;
    final reelsState = ref.read(reelsProvider);
    final isCurrentlyLiked = reelsState.isLiked(widget.listing.id, widget.listing.isLikedByMe);
    final nextState = !isCurrentlyLiked;
    if (nextState) {
      HapticFeedback.mediumImpact();
      _triggerHeartBurst();
    } else {
      HapticFeedback.lightImpact();
    }
    _likeButtonAnimController.forward(from: 0.0);
    ref.read(reelsProvider.notifier).toggleLike(
      widget.listing.id,
      widget.listing.likesCount,
      targetLiked: nextState,
      initialLiked: widget.listing.isLikedByMe,
    );
  }

  void _handleDoubleTap() {
    if (!_ensureAuthenticated()) return;
    HapticFeedback.mediumImpact();
    _triggerHeartBurst();
    _likeButtonAnimController.forward(from: 0.0);
    // Double tap = ALWAYS LIKE (never toggle/unlike)
    ref.read(reelsProvider.notifier).toggleLike(
      widget.listing.id,
      widget.listing.likesCount,
      targetLiked: true,
      initialLiked: widget.listing.isLikedByMe,
    );
  }

  void _triggerHeartBurst() {
    setState(() => _showHeartAnim = true);
    _heartAnimController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() => _showHeartAnim = false);
      }
    });
  }

  void _handleSingleTap() {
    if (_videoController != null && _isVideoInitialized) {
      if (_videoController!.value.isPlaying) {
        _videoController?.pause();
        setState(() {
          _isPlayingState = false;
          _showPlayPause = true;
        });
      } else {
        _videoController?.play();
        setState(() {
          _isPlayingState = true;
          _showPlayPause = true;
        });
      }
      _playPauseAnimController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() => _showPlayPause = false);
        }
      });
    }
  }

  String _getSellerName() {
    final name = widget.listing.sellerName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Verified Seller';
  }

  String _getSellerInitials() {
    final name = _getSellerName();
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return 'VS';
  }

  String? _getLocationText() {
    final locality = widget.listing.locality?.trim();
    final city = widget.listing.city?.trim();
    final state = widget.listing.state?.trim();

    // Check if string is raw coordinates like "12.9571, 80.2453"
    final isCoordPattern = RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$');

    if (locality != null && locality.isNotEmpty && !isCoordPattern.hasMatch(locality)) {
      if (city != null && city.isNotEmpty && !isCoordPattern.hasMatch(city) && !locality.toLowerCase().contains(city.toLowerCase())) {
        return '$locality, $city';
      }
      return locality;
    }

    if (city != null && city.isNotEmpty && !isCoordPattern.hasMatch(city)) {
      if (state != null && state.isNotEmpty && !isCoordPattern.hasMatch(state) && !city.toLowerCase().contains(state.toLowerCase())) {
        return '$city, $state';
      }
      return city;
    }

    if (state != null && state.isNotEmpty && !isCoordPattern.hasMatch(state)) {
      return state;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isAuction = widget.listing.isAuction;
    final currentBid = widget.listing.currentBid ?? widget.listing.price;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Video / Media Background with Gesture Detectors (Single Tap Play/Pause + Double Tap Like)
        GestureDetector(
          onTap: _handleSingleTap,
          onDoubleTap: _handleDoubleTap,
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Always show image/placeholder in background (CachedNetworkImage with bounded memory decoding)
                widget.listing.primaryImageUrl != null && widget.listing.primaryImageUrl!.isNotEmpty
                    ? RepaintBoundary(
                        child: CachedNetworkImage(
                          imageUrl: ApiClient.resolveMediaUrl(widget.listing.primaryImageUrl!),
                          fit: BoxFit.cover,
                          memCacheWidth: 720,
                          memCacheHeight: 1280,
                          maxWidthDiskCache: 1080,
                          placeholder: (_, __) => _buildPlaceholderBackground(),
                          errorWidget: (_, __, ___) => _buildPlaceholderBackground(),
                        ),
                      )
                    : _buildPlaceholderBackground(),
                // Show video on top if initialized (isolated with RepaintBoundary for 60fps GPU rendering)
                if (_videoController != null && (_isVideoInitialized || _videoController!.value.isInitialized))
                  AnimatedOpacity(
                    opacity: _firstFrameRendered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeIn,
                    child: RepaintBoundary(
                      child: SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: _videoController!.value.size.width > 0
                                ? _videoController!.value.size.width
                                : 360,
                            height: _videoController!.value.size.height > 0
                                ? _videoController!.value.size.height
                                : 640,
                            child: VideoPlayer(_videoController!),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Smooth loading spinner during initial buffering
                if (_isInitializing && !_isVideoInitialized && !_initFailed)
                  const Center(
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
                      ),
                    ),
                  ),
                // Show retry button if video init failed
                if (_initFailed && widget.listing.reelUrl != null && widget.listing.reelUrl!.isNotEmpty)
                  Center(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _acquireVideo(autoPlay: widget.itemIndex == widget.activeNotifier.value),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.replay_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Retry Video',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 2. Dark Gradient Overlay for readability
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  stops: const [0.0, 0.45, 0.85],
                ),
              ),
            ),
          ),
        ),

        // 3. Instagram-style Double-Tap Heart Burst Animation
        if (_showHeartAnim)
          Center(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _heartAnimController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _heartOpacityAnim.value,
                    child: Transform.scale(
                      scale: _heartScaleAnim.value,
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFEF4444),
                        size: 110,
                        shadows: [
                          Shadow(color: Colors.black45, blurRadius: 15),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // 4. Play / Pause Indicator on Single Tap
        if (_showPlayPause)
          Center(
            child: FadeTransition(
              opacity: _playPauseAnimController,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlayingState ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),

        // 5. Right Action Column (Likes, Share, Mute)
        Positioned(
          right: 16,
          bottom: isAuction ? 275 : 215,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Like Button (Scoped Consumer: ONLY rebuilds when this specific like state changes)
              Consumer(
                builder: (context, ref, _) {
                  final isLiked = ref.watch(reelsProvider.select((s) => s.isLiked(widget.listing.id, widget.listing.isLikedByMe)));
                  final likesCount = ref.watch(reelsProvider.select((s) => s.likesCount(widget.listing.id, widget.listing.likesCount)));
                  return GestureDetector(
                    onTap: _toggleLike,
                    child: Column(
                      children: [
                        ScaleTransition(
                          scale: _likeButtonScaleAnim,
                          child: Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isLiked ? const Color(0xFFEF4444) : Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$likesCount',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),

              // Share Button
              GestureDetector(
                onTap: () {
                  ReelsControllerManager().pauseAll();
                  Share.share('Check out ${widget.listing.title} on Bidly: ₹${widget.listing.price.toStringAsFixed(0)}');
                },
                child: const Column(
                  children: [
                    Icon(
                      Icons.share_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Share',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Mute Toggle Button
              GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 6. Bottom Info Overlay & Action Buttons
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Seller Info Row
              Padding(
                padding: const EdgeInsets.only(right: 64),
                child: GestureDetector(
                  onTap: () async {
                    ReelsControllerManager().pauseAll();
                    await context.push('/listing/${widget.listing.id}', extra: widget.listing);
                    if (context.mounted && widget.isHomeVisible && ModalRoute.of(context)?.isCurrent == true) {
                      ReelsControllerManager().resumeCurrent();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFF004E54),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _getSellerInitials(),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _getSellerName(),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_getLocationText() != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF004E54),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_outlined, color: Colors.white70, size: 11),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    _getLocationText()!,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Title
              Padding(
                padding: const EdgeInsets.only(right: 64),
                child: Text(
                  widget.listing.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 3),

              // Description snippet with "see more" / "show less" option
              if (widget.listing.description != null && widget.listing.description!.trim().isNotEmpty) ...[
                Builder(
                  builder: (context) {
                    final desc = widget.listing.description!.trim();
                    final isLong = desc.length > 45 || desc.contains('\n');

                    if (!isLong) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 64, bottom: 10),
                        child: Text(
                          desc,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 64, bottom: 10),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isDescriptionExpanded = !_isDescriptionExpanded;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          alignment: Alignment.topLeft,
                          child: _isDescriptionExpanded
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 140),
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          desc,
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12.5,
                                            height: 1.35,
                                            color: Colors.white.withValues(alpha: 0.95),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'show less',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2DD4BF),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        desc,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12.5,
                                          color: Colors.white.withValues(alpha: 0.88),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'see more',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2DD4BF),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ] else
                const SizedBox(height: 6),

              // ─── IF AUCTION / BID SALE ─────────────────────────────────────
              if (isAuction) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E232A).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Bid',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '₹${currentBid.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '$_bidsCount bids placed',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.5,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  widget.listing.timeLeft,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'remaining',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                // Direct Buy Price & Condition Row
                Row(
                  children: [
                    Text(
                      '₹${widget.listing.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2DD4BF),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.listing.formattedCondition,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // ─── ACTION BUTTONS (View Details + Make offer / Bid Now) ───────
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () async {
                          ReelsControllerManager().pauseAll();
                          await context.push('/listing/${widget.listing.id}', extra: widget.listing);
                          if (context.mounted && widget.isHomeVisible && ModalRoute.of(context)?.isCurrent == true) {
                            ReelsControllerManager().resumeCurrent();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A2F37),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23),
                          ),
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
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
                          ReelsControllerManager().pauseAll();
                          if (isAuction) {
                            await context.push('/auction/${widget.listing.id}/bid');
                          } else {
                            await context.push('/chat/offer/${widget.listing.id}', extra: widget.listing);
                          }
                          if (context.mounted && widget.isHomeVisible && ModalRoute.of(context)?.isCurrent == true) {
                            ReelsControllerManager().resumeCurrent();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAuction ? const Color(0xFFEF4444) : const Color(0xFF004E54),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23),
                          ),
                        ),
                        child: Text(
                          isAuction ? 'Bid Now' : 'Make offer',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.5,
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

        // 7. Interactive Timeline / Scrubber Progress Bar with Live Seek Preview
        if (_videoController != null && (_isVideoInitialized || _videoController!.value.isInitialized))
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 8,
            child: _InteractiveVideoProgressBar(
              controller: _videoController!,
              onPlayRequested: () {
                if (mounted) {
                  _videoController?.play();
                  setState(() => _isPlayingState = true);
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF020617)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_fill_rounded, color: Colors.white24, size: 70),
      ),
    );
  }
}

class _InteractiveVideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback? onPlayRequested;

  const _InteractiveVideoProgressBar({required this.controller, this.onPlayRequested});

  @override
  State<_InteractiveVideoProgressBar> createState() => _InteractiveVideoProgressBarState();
}

class _InteractiveVideoProgressBarState extends State<_InteractiveVideoProgressBar> {
  bool _isDragging = false;
  double _dragRatio = 0.0;
  Duration _dragPosition = Duration.zero;
  DateTime _lastThrottledSeek = DateTime.now();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(covariant _InteractiveVideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerUpdate);
      widget.controller.addListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted && !_isDragging) {
      setState(() {});
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleSeekUpdate(double localDx, double totalWidth, {bool finalize = false}) {
    if (totalWidth <= 0) return;
    final ratio = (localDx / totalWidth).clamp(0.0, 1.0);
    final totalMs = widget.controller.value.duration.inMilliseconds;
    if (totalMs <= 0) return;

    final targetMs = (totalMs * ratio).round();
    final targetDuration = Duration(milliseconds: targetMs);

    setState(() {
      _dragRatio = ratio;
      _dragPosition = targetDuration;
    });

    if (finalize) {
      widget.controller.seekTo(targetDuration);
      if (widget.onPlayRequested != null) {
        widget.onPlayRequested!();
      } else {
        widget.controller.play();
      }
    } else {
      final now = DateTime.now();
      if (now.difference(_lastThrottledSeek).inMilliseconds > 200) {
        _lastThrottledSeek = now;
        widget.controller.seekTo(targetDuration);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final totalDuration = value.duration;
    if (totalDuration == Duration.zero) {
      return const SizedBox(height: 16);
    }

    final currentPosition = _isDragging ? _dragPosition : value.position;
    final progressRatio = totalDuration.inMilliseconds > 0
        ? (_isDragging ? _dragRatio : (currentPosition.inMilliseconds / totalDuration.inMilliseconds)).clamp(0.0, 1.0)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final playedWidth = totalWidth * progressRatio;

        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Floating Glassmorphic Timestamp Pill Chip while dragging/seeking
            if (_isDragging)
              Positioned(
                bottom: 26,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2DD4BF), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_rounded, color: Color(0xFF2DD4BF), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(currentPosition),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2DD4BF),
                        ),
                      ),
                      Text(
                        ' / ${_formatDuration(totalDuration)}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Interactive Touch Bar (Tap or Drag anywhere along horizontal axis)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                _handleSeekUpdate(details.localPosition.dx, totalWidth, finalize: true);
              },
              onHorizontalDragStart: (details) {
                setState(() => _isDragging = true);
                _handleSeekUpdate(details.localPosition.dx, totalWidth, finalize: false);
              },
              onHorizontalDragUpdate: (details) {
                if (_isDragging) {
                  _handleSeekUpdate(details.localPosition.dx, totalWidth, finalize: false);
                }
              },
              onHorizontalDragEnd: (details) {
                if (_isDragging) {
                  _handleSeekUpdate(playedWidth, totalWidth, finalize: true);
                  setState(() => _isDragging = false);
                }
              },
              onHorizontalDragCancel: () {
                if (_isDragging) {
                  _handleSeekUpdate(playedWidth, totalWidth, finalize: true);
                  setState(() => _isDragging = false);
                }
              },
              child: Container(
                height: 38,
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 8),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    // Background Inactive Track
                    Container(
                      height: _isDragging ? 5.5 : 3.0,
                      width: totalWidth,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    // Buffered/Played Active Track
                    Container(
                      height: _isDragging ? 5.5 : 3.0,
                      width: playedWidth.clamp(0.0, totalWidth),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF004E54), Color(0xFF2DD4BF), Colors.white],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: _isDragging
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.7),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),

                    // Glowing Scrubbing Knob Thumb
                    if (_isDragging)
                      Positioned(
                        left: (playedWidth - 8).clamp(0.0, totalWidth - 16),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF004E54), width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
