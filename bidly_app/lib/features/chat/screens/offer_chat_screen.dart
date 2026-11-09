import '../../profile/screens/report_problem_screen.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../explore/models/listing_model.dart';
import '../models/chat_message_model.dart';
import '../models/chat_room_model.dart';
import '../models/offer_model.dart';
import '../providers/chat_provider.dart';
import '../providers/offer_provider.dart';
import '../widgets/reject_offer_bottom_sheet.dart';
import '../widgets/schedule_meetup_bottom_sheet.dart';
import '../widgets/buyer_show_otp_modal.dart';
import 'seller_otp_verification_screen.dart';
import '../../auction/models/auction_model.dart';
import '../../auction/providers/order_provider.dart';
import '../../auction/widgets/choose_delivery_method_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class OfferChatScreen extends ConsumerStatefulWidget {
  final String listingId;
  final ListingModel? listing;
  final String? buyerId;
  final String? sellerId;
  final bool? isSellerView;
  final String? offerId;
  final String? orderId;
  final String? buyerName;
  final String? roomId;
  final String? productTitle;
  final double? productPrice;
  final String? listingImageUrl;

  const OfferChatScreen({
    super.key,
    required this.listingId,
    this.listing,
    this.buyerId,
    this.sellerId,
    this.isSellerView,
    this.offerId,
    this.orderId,
    this.buyerName,
    this.roomId,
    this.productTitle,
    this.productPrice,
    this.listingImageUrl,
  });

  @override
  ConsumerState<OfferChatScreen> createState() => _OfferChatScreenState();
}

class _OfferChatScreenState extends ConsumerState<OfferChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _confirmedMeetupOrderIds = {};
  bool _isConfirmingMeetup = false;
  double _offerAmount = 0.0;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _offerAmount = widget.productPrice ?? widget.listing?.price ?? 0.0;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Trigger loading older messages when scrolled near the top
    if (currentScroll <= 100) {
      ref.read(chatRoomNotifierProvider.notifier).loadOlderMessages();
    }

    // Toggle "Scroll to Bottom" button
    final isAwayFromBottom = maxScroll - currentScroll > 200;
    if (isAwayFromBottom != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = isAwayFromBottom;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final chatNotifier = ref.read(chatRoomNotifierProvider.notifier);
    final offerNotifier = ref.read(offerProvider.notifier);

    final Future<ChatRoomModel?> roomFuture = (widget.roomId != null && widget.roomId!.isNotEmpty)
        ? chatNotifier.initRoomById(
            widget.roomId!,
            listingId: widget.listingId,
            initialPrice: _offerAmount,
            buyerId: widget.buyerId,
            buyerName: widget.buyerName,
            sellerId: widget.sellerId ?? widget.listing?.sellerId,
            sellerName: widget.listing?.sellerName,
            offerId: widget.offerId,
            listingTitle: widget.productTitle,
            listingPrice: widget.productPrice,
            listingImageUrl: widget.listingImageUrl,
          )
        : chatNotifier.initRoomForListing(
            widget.listingId,
            _offerAmount,
            buyerId: widget.buyerId,
            offerId: widget.offerId,
          );

    final Future<void> offerFuture = offerNotifier.fetchLatestOffer(
      widget.listingId,
      buyerId: widget.buyerId,
    );

    final Future<void> orderFuture = (widget.orderId != null && widget.orderId!.isNotEmpty)
        ? ref.read(orderProvider.notifier).fetchOrder(widget.orderId!)
        : ref.read(orderProvider.notifier).fetchOrderByListing(widget.listingId);

    final results = await Future.wait([roomFuture, offerFuture, orderFuture]);
    final room = results[0] as ChatRoomModel?;

    if ((_offerAmount == 0.0 || _offerAmount == 100.0) && room != null && room.listingPrice > 0) {
      if (mounted) {
        setState(() {
          _offerAmount = room.listingPrice;
        });
      }
    }
    if (mounted) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmMeetupAction([String? targetOrderId]) async {
    if (_isConfirmingMeetup) return;
    final messenger = ScaffoldMessenger.of(context);

    var effectiveOrderId = targetOrderId ?? widget.orderId ?? ref.read(orderProvider).order?.id;
    if (effectiveOrderId == null || effectiveOrderId.isEmpty) {
      setState(() => _isConfirmingMeetup = true);
      await ref.read(orderProvider.notifier).fetchOrderByListing(widget.listingId);
      effectiveOrderId = ref.read(orderProvider).order?.id;
      if (mounted) setState(() => _isConfirmingMeetup = false);
    }

    if (effectiveOrderId == null || effectiveOrderId.isEmpty) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Order details could not be found. Please try again.')),
        );
      }
      return;
    }

    setState(() => _isConfirmingMeetup = true);
    final ok = await ref.read(orderProvider.notifier).confirmMeetup(effectiveOrderId);
    if (!mounted) return;
    setState(() => _isConfirmingMeetup = false);

    if (ok) {
      setState(() {
        _confirmedMeetupOrderIds.add(effectiveOrderId!);
      });
      // Refresh order and room messages so all UI states sync immediately
      await ref.read(orderProvider.notifier).fetchOrderByListing(widget.listingId);
      final roomId = ref.read(chatRoomNotifierProvider).room?.id ?? widget.roomId;
      if (roomId != null) {
        ref.read(chatRoomNotifierProvider.notifier).loadMessages(roomId, isSilent: true);
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Meetup confirmed! Tap "Show OTP" when you meet the seller.'),
          backgroundColor: Color(0xFF004E54),
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      final err = ref.read(orderProvider).errorMessage ?? 'Failed to confirm meetup. Please try again.';
      messenger.showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _confirmBuyerDelivery(String orderId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF004E54), size: 26),
            SizedBox(width: 10),
            Text(
              'Confirm Delivery',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Have you received your item in good condition?\n\nOnce confirmed, the escrow payment will be released to the seller and the listing will be permanently marked as Sold Out.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Yet', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004E54),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Yes, Received', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ok = await ref.read(orderProvider.notifier).confirmDelivery(orderId);
    if (!mounted) return;

    if (ok) {
      await ref.read(orderProvider.notifier).fetchOrderByListing(widget.listingId);
      final roomId = ref.read(chatRoomNotifierProvider).room?.id ?? widget.roomId;
      if (roomId != null) {
        await ref.read(chatRoomNotifierProvider.notifier).loadMessages(roomId, isSilent: true);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Delivery confirmed! Payment released to seller & order completed.'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      if (!mounted) return;
      final err = ref.read(orderProvider).errorMessage ?? 'Failed to confirm delivery. Please try again.';
      messenger.showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _openSellerDeliverySelector() {
    final order = ref.read(orderProvider).order;
    final room = ref.read(chatRoomNotifierProvider).room;

    final winner = AuctionWinnerModel(
      orderId: order?.id ?? widget.orderId,
      listingId: widget.listingId,
      listingTitle: order?.productTitle ?? room?.listingTitle ?? widget.productTitle ?? 'Auction Item',
      listingImageUrl: order?.primaryImageUrl ?? room?.listingImageUrl ?? widget.listingImageUrl,
      winnerId: order?.buyerId ?? room?.buyerId ?? widget.buyerId,
      winnerName: order?.buyerName ?? room?.buyerName ?? widget.buyerName ?? 'Auction Winner',
      winnerLocality: (order != null && order.deliveryAddressCity.isNotEmpty)
          ? order.deliveryAddressCity
          : 'Verified Buyer',
      winningAmount: order?.totalAmount ?? order?.wonAmount ?? room?.listingPrice ?? 0.0,
      orderStatus: order?.status ?? 'AUCTION_WON',
      paymentSecuredInEscrow: true,
    );

    ChooseDeliveryMethodBottomSheet.show(
      context,
      winner: winner,
      listingId: widget.listingId,
    );
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    final notifier = ref.read(chatRoomNotifierProvider.notifier);
    final ok = await notifier.sendTextMessage(text);
    if (ok) _scrollToBottom();
  }

  Future<void> _sendQuickReply(String reply) async {
    final notifier = ref.read(chatRoomNotifierProvider.notifier);
    final ok = await notifier.sendQuickReply(reply);
    if (ok) _scrollToBottom();
  }

  Future<void> _submitNewOffer() async {
    final offerNotifier = ref.read(offerProvider.notifier);
    final chatNotifier = ref.read(chatRoomNotifierProvider.notifier);

    final success = await offerNotifier.submitOffer(
      listingId: widget.listingId,
      amount: _offerAmount,
      message: 'Submitted offer of ₹${_offerAmount.toInt()}',
    );

    if (success) {
      final roomId = ref.read(chatRoomNotifierProvider).room?.id;
      if (roomId != null) {
        await chatNotifier.loadMessages(roomId, isSilent: true);
      }
      _scrollToBottom();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offer of ₹${_offerAmount.toInt()} submitted successfully!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } else {
      if (mounted) {
        final err = ref.read(offerProvider).errorMessage ?? 'Failed to submit offer';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showCounterDialog(OfferModel offer) {
    double counterVal = offer.currentEffectiveAmount;
    final textCtrl = TextEditingController(text: counterVal.toInt().toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Counter Offer',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Current offer: ₹${offer.currentEffectiveAmount.toInt()}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primary),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primary),
                labelText: 'Your Counter Price',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final parsed = double.tryParse(textCtrl.text.replaceAll(',', '').trim());
                  if (parsed != null && parsed > 0) {
                    Navigator.pop(ctx);
                    final ok = await ref.read(offerProvider.notifier).counterOffer(
                          offerId: offer.id,
                          counterAmount: parsed,
                          message: 'Counter offer of ₹${parsed.toInt()}',
                        );
                    if (ok && mounted) {
                      _scrollToBottom();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit Counter Offer', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAcceptDialog(OfferModel offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Accept Offer',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Accept offer of ₹${offer.currentEffectiveAmount.toInt()} from ${offer.buyerName} and continue chat?',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004E54),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Accept',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final defaultLocation = offer.meetupLocation ??
        (widget.listing?.locality?.isNotEmpty == true ? widget.listing!.locality! : 'Agreed Meeting Point');

    final orderId = await ref.read(offerProvider.notifier).acceptOffer(
          offerId: offer.id,
          deliveryType: 'IN_PERSON_MEETUP',
          meetupLocation: defaultLocation,
        );

    if (!mounted) return;

    if (orderId != null) {
      await ref.read(chatRoomNotifierProvider.notifier).sendTextMessage(
            '🎉 Offer accepted! Let\'s chat and meetup.',
          );
      await ref.read(offerProvider.notifier).fetchLatestOffer(widget.listingId, buyerId: widget.buyerId ?? offer.buyerId);
      await ref.read(orderProvider.notifier).fetchOrderByListing(widget.listingId);
      final roomId = ref.read(chatRoomNotifierProvider).room?.id;
      if (roomId != null) {
        await ref.read(chatRoomNotifierProvider.notifier).loadMessages(roomId, isSilent: true);
      }
      _scrollToBottom();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offer accepted! You can continue chatting or tap [Schedule] anytime.'),
          backgroundColor: Color(0xFF004E54),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not accept offer. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  void _showScheduleDialog() {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 16, minute: 30);
    final locationCtrl = TextEditingController(text: 'T. Nagar, Chennai');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Schedule In-Person Meetup',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Propose a date, time, and location to inspect the product in person.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // Date & Time pickers
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 14)),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month, color: AppTheme.primary, size: 18),
                      label: Text(DateFormat('EEE, d MMM').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setSheetState(() => selectedTime = picked);
                        }
                      },
                      icon: const Icon(Icons.access_time, color: AppTheme.primary, size: 18),
                      label: Text(selectedTime.format(ctx)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              const Text(
                'Meetup Location:',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: locationCtrl,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.primary, size: 18),
                  hintText: 'e.g. Metro Station, Coffee Shop, Mall',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),

              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final finalDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    await ref.read(chatRoomNotifierProvider.notifier).sendMeetupRequest(
                          meetupTime: finalDateTime,
                          location: locationCtrl.text.trim(),
                        );
                    _scrollToBottom();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Send Meetup Request', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _computeIsSeller({
    required String currentUserId,
    required ChatRoomModel? room,
    required OfferModel? activeOffer,
  }) {
    // 1. Explicit override passed from caller (e.g. MessagesListScreen tab)
    if (widget.isSellerView != null) {
      return widget.isSellerView!;
    }
    // 2. Explicit sellerId passed from caller
    if (widget.sellerId != null && widget.sellerId!.isNotEmpty && currentUserId.isNotEmpty) {
      if (widget.sellerId == currentUserId) return true;
    }
    // 3. Explicit buyerId passed from caller
    if (widget.buyerId != null && widget.buyerId!.isNotEmpty && currentUserId.isNotEmpty) {
      if (widget.buyerId == currentUserId) return false;
      // In a 1-on-1 direct buy chat, if buyer is someone else, the viewer is the seller!
      return true;
    }
    // 4. Listing sellerId
    final listingSellerId = widget.listing?.sellerId;
    if (listingSellerId != null && listingSellerId.isNotEmpty && currentUserId.isNotEmpty) {
      if (listingSellerId == currentUserId) return true;
      return false;
    }
    // 5. Room sellerId / buyerId
    if (room != null && currentUserId.isNotEmpty) {
      if (room.sellerId.isNotEmpty && room.sellerId == currentUserId) return true;
      if (room.buyerId.isNotEmpty && room.buyerId == currentUserId) return false;
    }
    // 6. Active offer (strictly verified for this listingId)
    if (activeOffer != null && activeOffer.listingId == widget.listingId) {
      return activeOffer.isSeller;
    }
    // Fallback default
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatRoomNotifierProvider);
    final offerState = ref.watch(offerProvider);
    final activeOffer = (offerState.activeOffer?.listingId == widget.listingId)
        ? offerState.activeOffer
        : null;
    final currentUserId = ref.watch(authProvider).user?.id ?? '';
    final orderState = ref.watch(orderProvider);
    final order = (orderState.order?.listingId == widget.listingId)
        ? orderState.order
        : null;
    final room = chatState.room;
    final listing = widget.listing;

    final isAuction = (listing?.sellingMethod.toUpperCase() == 'AUCTION') ||
        (order != null && order.orderSource.toUpperCase() == 'AUCTION');

    final isSeller = _computeIsSeller(
      currentUserId: currentUserId,
      room: room,
      activeOffer: activeOffer,
    );

    final peerName = isSeller
        ? (room?.buyerName ?? widget.buyerName ?? activeOffer?.buyerName ?? 'Buyer')
        : (room?.sellerName ?? listing?.sellerName ?? 'Seller');
    final peerInitials = peerName.isNotEmpty
        ? peerName.substring(0, peerName.length > 2 ? 2 : peerName.length).toUpperCase()
        : (isSeller ? 'BU' : 'SE');
    final listingTitle = room?.listingTitle ?? widget.productTitle ?? listing?.title ?? 'Product';
    final listingPrice = (room?.listingPrice != null && room!.listingPrice > 0)
        ? room.listingPrice
        : ((widget.productPrice != null && widget.productPrice! > 0)
            ? widget.productPrice!
            : (listing?.price ?? 0.0));
    final listingImg = room?.listingImageUrl ?? widget.listingImageUrl ?? listing?.primaryImageUrl;

    final effOrderId = activeOffer?.orderId ?? order?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F7),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + ((isAuction || (order != null && order.orderSource == 'AUCTION')) ? 38.0 : 0.0)),
        child: Column(
          children: [
            if (isAuction || (order != null && order.orderSource == 'AUCTION'))
              Container(
                color: const Color(0xFF004E54),
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.emoji_events_outlined, color: Color(0xFF5EEAD4), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Auction Won · ₹${listingPrice.toInt()} · $listingTitle',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (effOrderId != null)
                          GestureDetector(
                            onTap: () => context.push('/orders/$effOrderId/track'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.inventory_2_outlined, color: Colors.white, size: 11),
                                  SizedBox(width: 4),
                                  Text(
                                    'Track',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            AppBar(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0.5,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, size: 18, color: AppTheme.textPrimary),
                  onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
                  padding: EdgeInsets.zero,
                ),
              ),
              titleSpacing: 0,
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xFF004E54),
                    child: Text(
                      peerInitials,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          peerName,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              color: Color(0xFF10B981),
                              size: 7,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Online now · ${isSeller ? "Buyer" : "Seller"}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.phone_outlined, color: Color(0xFF004E54), size: 21),
                  onPressed: () async {
                    final uri = Uri.parse('tel:');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF64748B), size: 21),
                  onSelected: (val) {
                    if (val == 'listing' && widget.listingId.isNotEmpty) {
                      context.push('/listing/${widget.listingId}');
                    } else if (val == 'report') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportProblemScreen()));
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (widget.listingId.isNotEmpty)
                      const PopupMenuItem(value: 'listing', child: Text('View Listing')),
                    const PopupMenuItem(value: 'report', child: Text('Report User')),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Mini Product Card (Matching Image 1 & Image 2)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFEBF1F5))),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: const Color(0xFFEDF5F5),
                        child: listingImg != null && listingImg.isNotEmpty
                            ? Image.network(
                                ApiClient.resolveMediaUrl(listingImg),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Color(0xFF004E54), size: 24),
                              )
                            : const Icon(Icons.image, color: Color(0xFF004E54), size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listingTitle,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF004E54),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isAuction
                                      ? 'WON'
                                      : ((activeOffer?.isAccepted ?? false) || order != null)
                                          ? 'ACCEPTED'
                                          : 'OFFER',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                '₹${(order?.totalAmount ?? order?.wonAmount ?? activeOffer?.currentEffectiveAmount ?? (listingPrice > 0 ? listingPrice : (room?.listingPrice ?? 0.0))).toInt()}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F7F8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF004E54)),
                                    SizedBox(width: 2),
                                    Text(
                                      'Meetup',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF004E54),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Mini Product Action Button:
                    // For Direct Buy: Always [ Schedule ] meetup
                    // For Auction: [ Delivery ] if method not chosen, [ Track ] if courier, [ Schedule ] if meetup
                    _buildMiniProductActionButton(
                      isAuction: isAuction,
                      isSeller: isSeller,
                      order: order,
                      effOrderId: effOrderId,
                      activeOffer: activeOffer,
                      room: room,
                    ),
                  ],
                ),
              ),

              // Notice Banners
              _buildBuyerProtectionBanner(
                isSeller: isSeller,
                order: order,
                isAuction: isAuction,
                activeOffer: activeOffer,
              ),

              // Message List
              Expanded(
                child: chatState.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : chatState.messages.isEmpty
                        ? _buildEmptyState(peerName)
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: chatState.messages.length + (chatState.isLoadingOlder ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (chatState.isLoadingOlder && index == 0) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                    ),
                                  ),
                                );
                              }

                              final actualIndex = chatState.isLoadingOlder ? index - 1 : index;
                              final msg = chatState.messages[actualIndex];
                              final isMe = msg.senderId == currentUserId || msg.isMine;

                              // Check if date header should be shown
                              bool showDateHeader = false;
                              if (actualIndex == 0) {
                                showDateHeader = true;
                              } else {
                                final prevMsg = chatState.messages[actualIndex - 1];
                                showDateHeader = !msg.isSameDay(prevMsg);
                              }

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showDateHeader) _buildDateHeader(msg.formattedDateHeader),
                                  _buildMessageItem(msg, isMe, peerInitials, activeOffer),
                                ],
                              );
                            },
                          ),
              ),

              // Ephemeral Typing Indicator Banner
              if (chatState.typingUser != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${chatState.typingUser} is typing...',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

              // Quick Replies (Image 1 & 2)
              Builder(
                builder: (context) {
                  final replies = isSeller
                      ? [
                          "Thanks for the update!",
                          "Looks good!",
                          "When will you pick it up?",
                          "Item is packed and ready",
                        ]
                      : [
                          "Great! I'm available today",
                          "Can we meet tomorrow?",
                          "Is the price negotiable?",
                          "Where can we meet for pickup?",
                        ];

                  return Container(
                    height: 38,
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: replies.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(
                              replies[index],
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Color(0xFF004E54),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: const Color(0xFFE8F6F6),
                            side: const BorderSide(color: Color(0xFFC4E8E8), width: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            onPressed: () => _sendQuickReply(replies[index]),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

              // Bottom Action / Negotiation Bar (Matching Image 1 Screen 2 & Image 3 Screen 4 & Screen 5)
              _buildBottomOfferBar(activeOffer, listingPrice, offerState),

              // Text Input Bar (Matching Image 1 & Image 2)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showAttachmentOptions(effOrderId, activeOffer, isAuction),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: Color(0xFF004E54),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                            onChanged: (text) {
                              setState(() {});
                              ref.read(chatRoomNotifierProvider.notifier).onTextChanged(text);
                            },
                            onSubmitted: (_) => _sendText(),
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _sendText,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _textController.text.trim().isNotEmpty
                                ? const Color(0xFF004E54)
                                : const Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            color: _textController.text.trim().isNotEmpty
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Floating "New Messages" / Scroll-to-Bottom Pill
          if (_showScrollToBottom)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: _scrollToBottom,
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                elevation: 3,
                icon: const Icon(Icons.arrow_downward, size: 16),
                label: const Text(
                  'Latest',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniProductActionButton({
    required bool isAuction,
    required bool isSeller,
    required OrderModel? order,
    required String? effOrderId,
    required OfferModel? activeOffer,
    required ChatRoomModel? room,
  }) {
    // For Direct Buy: Schedule option ONLY for seller; Show OTP for buyer ONLY after meetup is confirmed
    if (!isAuction) {
      if (isSeller) {
        return Container(
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEDF7F7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC4E8E8), width: 1.2),
          ),
          child: TextButton.icon(
            onPressed: () {
              if (effOrderId != null) {
                ScheduleMeetupBottomSheet.show(
                  context,
                  orderId: effOrderId,
                  initialLocation: activeOffer?.meetupLocation,
                  onMeetupScheduled: () {
                    ref.read(offerProvider.notifier).fetchLatestOffer(widget.listingId, buyerId: widget.buyerId ?? room?.buyerId);
                    ref.read(orderProvider.notifier).fetchOrderByListing(widget.listingId);
                    final rId = ref.read(chatRoomNotifierProvider).room?.id;
                    if (rId != null) {
                      ref.read(chatRoomNotifierProvider.notifier).loadMessages(rId, isSilent: true);
                    }
                  },
                );
              } else if (activeOffer != null && activeOffer.isPending) {
                _showAcceptDialog(activeOffer);
              } else {
                _showScheduleDialog();
              }
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF004E54)),
            label: const Text(
              'Schedule',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF004E54),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      } else {
        // Buyer chat screen: Show OTP button ONLY when meetup is confirmed!
        final isConfirmed = order?.isMeetupConfirmed == true ||
            (effOrderId != null && _confirmedMeetupOrderIds.contains(effOrderId));
        final isMeetupScheduled = (order?.meetupTime != null && order?.meetupLocation != null) ||
            (activeOffer?.meetupTime != null && activeOffer?.meetupLocation != null) ||
            ref.watch(chatRoomNotifierProvider).messages.any((m) =>
                m.type == 'MEETUP_REQUEST' ||
                m.content?.toLowerCase().contains('meeting scheduled') == true);

        if (effOrderId != null && isConfirmed) {
          return Container(
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF004E54),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004E54).withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextButton.icon(
              onPressed: () {
                BuyerShowOtpModal.show(context, orderId: effOrderId);
              },
              icon: const Icon(Icons.key_rounded, size: 14, color: Colors.white),
              label: const Text(
                'Show OTP',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          );
        } else if (effOrderId != null && isMeetupScheduled && !isConfirmed) {
          return Container(
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF004E54),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004E54).withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextButton(
              onPressed: _isConfirmingMeetup ? null : () => _confirmMeetupAction(effOrderId),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _isConfirmingMeetup
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Confirm Meetup',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          );
        }
        return const SizedBox.shrink();
      }
    }

    // For Auction: Check delivery method status
    final isDelivered = order?.status.toUpperCase() == 'DELIVERED' ||
        order?.status.toUpperCase() == 'COMPLETED';
    final isShipped = order?.status.toUpperCase() == 'SHIPPED' ||
        (order?.trackingNumber != null && order!.trackingNumber!.isNotEmpty);
    final hasMeetup = order != null && order.isMeetup;
    final hasCourier = isShipped || (order != null && order.deliveryAddressLine.isNotEmpty && !order.isMeetup);

    if (isDelivered) {
      return Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
            SizedBox(width: 4),
            Text(
              'Sold Out',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF16A34A),
              ),
            ),
          ],
        ),
      );
    }

    if (hasMeetup) {
      if (isSeller) {
        return Container(
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEDF7F7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC4E8E8), width: 1.2),
          ),
          child: TextButton.icon(
            onPressed: () {
              ScheduleMeetupBottomSheet.show(
                context,
                orderId: order.id,
                initialLocation: order.meetupLocation,
                onMeetupScheduled: () {
                  ref.read(orderProvider.notifier).fetchOrderByListing(widget.listingId);
                  final rId = ref.read(chatRoomNotifierProvider).room?.id;
                  if (rId != null) {
                    ref.read(chatRoomNotifierProvider.notifier).loadMessages(rId, isSilent: true);
                  }
                },
              );
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF004E54)),
            label: const Text(
              'Schedule',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF004E54),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      } else {
        // Buyer for auction meetup: Single-tap Confirm Received (No OTP needed for auctions)
        return Container(
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF004E54),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextButton.icon(
            onPressed: () => _confirmBuyerDelivery(order.id),
            icon: const Icon(Icons.check_circle_outline, size: 14, color: Colors.white),
            label: const Text(
              'Confirm Received',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      }
    }

    if (hasCourier) {
      if (isSeller) {
        return Container(
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
          ),
          child: TextButton.icon(
            onPressed: () {
              context.push('/orders/${order!.id}/track');
            },
            icon: const Icon(Icons.local_shipping_outlined, size: 14, color: Color(0xFF0284C7)),
            label: const Text(
              'Track',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      } else {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
              ),
              child: TextButton.icon(
                onPressed: () {
                  context.push('/orders/${order!.id}/track');
                },
                icon: const Icon(Icons.local_shipping_outlined, size: 13, color: Color(0xFF0284C7)),
                label: const Text(
                  'Track',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF004E54),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton(
                onPressed: () => _confirmBuyerDelivery(order!.id),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Received?',
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
        );
      }
    }

    // Delivery method not selected yet for auction: Seller chooses delivery method
    if (isSeller) {
      return Container(
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF004E54),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextButton.icon(
          onPressed: _openSellerDeliverySelector,
          icon: const Icon(Icons.local_shipping_outlined, size: 14, color: Colors.white),
          label: const Text(
            'Delivery',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    // Buyer view awaiting seller's dispatch
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty_rounded, size: 14, color: Color(0xFF64748B)),
            SizedBox(width: 4),
            Text(
              'Awaiting Seller',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyerProtectionBanner({
    required bool isSeller,
    required OrderModel? order,
    required bool isAuction,
    required OfferModel? activeOffer,
  }) {
    final bool isDirectBuy = !isAuction;
    final bool hasMeetupScheduled = order?.meetupTime != null ||
        (activeOffer?.meetupLocation != null && activeOffer!.meetupLocation!.isNotEmpty);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F6F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC4E8E8), width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF004E54)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isDirectBuy
                      ? 'Direct Buy • In-person meetup only with OTP verification.'
                      : 'BIDLY Buyer Protection is active for this auction.',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF004E54),
                  ),
                ),
              ),
            ],
          ),
        ),

        // For Direct Buy: Informative status only (NEVER the auction banner!)
        if (isDirectBuy && (activeOffer?.isAccepted == true || order != null))
          Container(
            margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasMeetupScheduled
                        ? 'Meetup scheduled! Meet at agreed spot and verify visual OTP.'
                        : 'Offer accepted! Tap [Schedule] to set meetup location and time.',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // For Auction: Delivery method selection notices
        if (isAuction) ...[
          if (isSeller && (order == null || (!order.isMeetup && order.deliveryAddressLine.isEmpty)))
            Container(
              margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE2ECED),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'BIDLY has notified the buyer they won the auction. Delivery method selection in progress.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF004E54),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (!isSeller && (order == null || (!order.isMeetup && order.deliveryAddressLine.isEmpty)))
            Container(
              margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: Color(0xFF1D4ED8), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You Won! Select Delivery Method',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        Text(
                          'Choose Courier Delivery or In-Person Meetup',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _showAuctionDeliveryMethodSelector(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Choose',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  void _showAuctionDeliveryMethodSelector(OrderModel? order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Delivery Method',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose how you would like to receive your won auction item:',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),

              // Option 1: Doorstep Courier Delivery
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeliveryAddressModal(order);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF0284C7), size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Doorstep Courier Delivery',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Provide address. Seller ships via courier with live tracking.',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Option 2: In-Person Meetup
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  final effOrderId = order?.id ?? ref.read(orderProvider).order?.id;
                  if (effOrderId != null) {
                    ScheduleMeetupBottomSheet.show(
                      context,
                      orderId: effOrderId,
                      onMeetupScheduled: () {
                        ref.read(orderProvider.notifier).fetchOrderByListing(widget.listingId);
                        final rId = ref.read(chatRoomNotifierProvider).room?.id;
                        if (rId != null) {
                          ref.read(chatRoomNotifierProvider.notifier).loadMessages(rId, isSilent: true);
                        }
                      },
                    );
                  } else {
                    _showScheduleDialog();
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F6F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.handshake_outlined, color: Color(0xFF004E54), size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'In-Person Meetup',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Inspect item face-to-face. Verified via 6-digit visual OTP handover.',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeliveryAddressModal(OrderModel? order) {
    final effOrder = order ?? ref.read(orderProvider).order;
    if (effOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order not ready yet. Please wait a moment.')),
      );
      return;
    }
    final nameCtrl = TextEditingController(text: effOrder.deliveryAddressFullName);
    final phoneCtrl = TextEditingController(text: effOrder.deliveryAddressPhone);
    final addressCtrl = TextEditingController(text: effOrder.deliveryAddressLine);
    final cityCtrl = TextEditingController(text: effOrder.deliveryAddressCity);
    final pincodeCtrl = TextEditingController(text: effOrder.deliveryAddressPincode);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
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
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Courier Delivery Address',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Seller will ship your won auction item to this address.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Recipient Full Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Contact Phone Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Street / Flat / Locality',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cityCtrl,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: pincodeCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'PIN Code',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (addressCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    final success = await ref.read(orderProvider.notifier).updateDeliveryAddress(
                          effOrder.id,
                          fullName: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          addressLine: addressCtrl.text.trim(),
                          city: cityCtrl.text.trim(),
                          pincode: pincodeCtrl.text.trim(),
                        );
                    if (success) {
                      await ref.read(orderProvider.notifier).fetchOrderByListing(widget.listingId);
                      final rId = ref.read(chatRoomNotifierProvider).room?.id;
                      if (rId != null) {
                        await ref.read(chatRoomNotifierProvider.notifier).loadMessages(rId, isSilent: true);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Delivery address saved and shared with seller!'),
                            backgroundColor: Color(0xFF004E54),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save & Confirm Courier', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttachmentOptions(String? effOrderId, OfferModel? activeOffer, bool isAuction) {
    final currentUserId = ref.read(authProvider).user?.id ?? '';
    final room = ref.read(chatRoomNotifierProvider).room;
    final isSeller = _computeIsSeller(
      currentUserId: currentUserId,
      room: room,
      activeOffer: activeOffer,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSeller)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F6F6),
                    child: Icon(Icons.calendar_today_outlined, color: Color(0xFF004E54)),
                  ),
                  title: const Text('Schedule Meetup', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  subtitle: const Text('Pick meetup time and map location', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (effOrderId != null) {
                      ScheduleMeetupBottomSheet.show(
                        context,
                        orderId: effOrderId,
                        initialLocation: activeOffer?.meetupLocation,
                        onMeetupScheduled: () {
                          final currentRoom = ref.read(chatRoomNotifierProvider).room;
                          ref.read(offerProvider.notifier).fetchLatestOffer(widget.listingId, buyerId: widget.buyerId ?? currentRoom?.buyerId);
                          ref.read(orderProvider.notifier).fetchOrderByListing(widget.listingId);
                          final rId = currentRoom?.id;
                          if (rId != null) {
                            ref.read(chatRoomNotifierProvider.notifier).loadMessages(rId, isSilent: true);
                          }
                        },
                      );
                    } else if (activeOffer != null && activeOffer.isPending) {
                      _showAcceptDialog(activeOffer);
                    } else {
                      _showScheduleDialog();
                    }
                  },
                ),
              if (isAuction) // ONLY for Auctions! Never for Direct Buy!
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F6F6),
                    child: Icon(Icons.local_shipping_outlined, color: Color(0xFF004E54)),
                  ),
                  title: const Text('Select Delivery Method', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  subtitle: const Text('Choose Courier delivery or In-Person Meetup', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    final currentOrder = ref.read(orderProvider).order;
                    _showAuctionDeliveryMethodSelector(currentOrder);
                  },
                ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F6F6),
                  child: Icon(Icons.photo_library_outlined, color: Color(0xFF004E54)),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                subtitle: const Text('Send photo from your library', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F6F6),
                  child: Icon(Icons.camera_alt_outlined, color: Color(0xFF004E54)),
                ),
                title: const Text('Take Photo', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                subtitle: const Text('Capture and send photo using camera', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile == null) return;

      final notifier = ref.read(chatRoomNotifierProvider.notifier);
      await notifier.sendImageMessage(filePath: pickedFile.path);
      _scrollToBottom();
    } catch (e) {
      debugPrint('[CHAT] Error picking/sending image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Widget _buildBottomOfferBar(
      OfferModel? activeOffer, double listingPrice, OfferState offerState) {
    final currentUserId = ref.watch(authProvider).user?.id ?? '';
    final room = ref.watch(chatRoomNotifierProvider).room;
    final order = ref.watch(orderProvider).order;
    final isSeller = _computeIsSeller(
      currentUserId: currentUserId,
      room: room,
      activeOffer: activeOffer,
    );
    final isBuyer = !isSeller;

    final listing = widget.listing;
    final isAuction = (listing?.sellingMethod.toUpperCase() == 'AUCTION') ||
        (order != null && order.orderSource.toUpperCase() == 'AUCTION');
    final effOrderId = activeOffer?.orderId ?? order?.id;

    if (isAuction) {
      final isDelivered = order?.status.toUpperCase() == 'DELIVERED' ||
          order?.status.toUpperCase() == 'COMPLETED';
      final isShipped = order?.status.toUpperCase() == 'SHIPPED' ||
          (order?.trackingNumber != null && order!.trackingNumber!.isNotEmpty);
      final hasMeetup = order != null && order.isMeetup;

      if (isDelivered) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isSeller
                        ? 'Order Completed · Escrow Released to Wallet'
                        : 'Order Completed · Delivered & Sold Out',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF166534),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      if (isBuyer) {
        if (isShipped || hasMeetup) {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: Color(0xFF004E54), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasMeetup
                              ? 'Meetup arranged! Received the item?'
                              : 'Package in transit. Received your item?',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final targetId = effOrderId ?? order?.id;
                        if (targetId != null) {
                          _confirmBuyerDelivery(targetId);
                        }
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text(
                        'Confirm Delivery Received',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004E54),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Buyer awaiting seller to dispatch/schedule
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Color(0xFF004E54), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Awaiting Seller to Dispatch / Schedule Delivery',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // isSeller for Auction
        if (!isShipped && !hasMeetup) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _openSellerDeliverySelector,
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text(
                    'Choose Delivery Method',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          );
        }

        // Seller has shipped / scheduled
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_rounded, color: Color(0xFF004E54), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Dispatched · Waiting for buyer to confirm receipt',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF004E54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    // Seller view: ONLY show seller actions if an active offer is pending or accepted
    if (isSeller) {
      // Case 1: Seller with pending offer (Image 3 Screen 4)
      if (activeOffer != null && activeOffer.isPending) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => RejectOfferBottomSheet.show(
                      context,
                      offerId: activeOffer.id,
                      onRejected: () => ref
                          .read(offerProvider.notifier)
                          .fetchLatestOffer(widget.listingId, buyerId: widget.buyerId ?? room?.buyerId),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      backgroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Reject Offer',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _showAcceptDialog(activeOffer),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004E54),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Accept Offer',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Case 2: Seller with accepted offer
      if (activeOffer != null && activeOffer.isAccepted) {
        final isConfirmed = order?.isMeetupConfirmed == true ||
            (activeOffer.orderId != null && _confirmedMeetupOrderIds.contains(activeOffer.orderId));

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => RejectOfferBottomSheet.show(
                      context,
                      offerId: activeOffer.id,
                      onRejected: () => ref
                          .read(offerProvider.notifier)
                          .fetchLatestOffer(widget.listingId, buyerId: widget.buyerId ?? room?.buyerId),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      backgroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Reject Offer',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!isConfirmed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Awaiting buyer to confirm meetup before marking as sold.'),
                            backgroundColor: Color(0xFF004E54),
                          ),
                        );
                        return;
                      }
                      final effectiveOrderId = activeOffer.orderId ?? order?.id;
                      if (effectiveOrderId != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => SellerOtpVerificationScreen(
                              orderId: effectiveOrderId,
                              buyerName: activeOffer.buyerName,
                              meetupLocation: activeOffer.meetupLocation,
                              productTitle: activeOffer.listingTitle ?? 'Product',
                              productPrice: activeOffer.currentEffectiveAmount,
                              productImageUrl: activeOffer.listingImageUrl,
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConfirmed ? const Color(0xFF004E54) : const Color(0xFFCBD5E1),
                      foregroundColor: isConfirmed ? Colors.white : const Color(0xFF64748B),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Mark as sold',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Seller NEVER sees "Make Offer" or buyer increment pills!
      return const SizedBox.shrink();
    }

    // Buyer view before offer accepted (Image 1)
    if (isBuyer &&
        (activeOffer == null ||
            activeOffer.isPending ||
            activeOffer.isRejected ||
            activeOffer.isCancelled)) {
      final increments = [500, 1000, 2000, 4000, 6000];

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Increment Pills ($ 500, $ 1,000, $ 2,000... - Image 1)
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: increments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final inc = increments[i];
                  final formattedInc = NumberFormat('#,###').format(inc);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _offerAmount = (_offerAmount + inc);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      child: Text(
                        '\$ $formattedInc',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Stepper box: [ ₹ 43500    ▲ ▼ ] and [ Make Offer ] button (Image 1)
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹ ${_offerAmount.toInt()}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF004E54),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _offerAmount = (_offerAmount + 500);
                                });
                              },
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF004E54),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _offerAmount = (_offerAmount - 500).clamp(100.0, 10000000.0);
                                });
                              },
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE2E8F0),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: offerState.isSubmitting ? null : _submitNewOffer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004E54),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF004E54),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: offerState.isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Make Offer',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15.5,
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
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMeetingScheduledCard(
      ChatMessageModel msg, OfferModel? activeOffer, bool isMe, String timeStr, String peerInitials) {
    final currentUserId = ref.watch(authProvider).user?.id ?? '';
    final room = ref.watch(chatRoomNotifierProvider).room;
    final order = ref.watch(orderProvider).order;
    final isSeller = _computeIsSeller(
      currentUserId: currentUserId,
      room: room,
      activeOffer: activeOffer,
    );

    String date = '';
    String time = '';
    String location = '';
    final lines = (msg.content ?? '').split('\n');
    for (final line in lines) {
      if (line.toLowerCase().startsWith('date:')) date = line.substring(5).trim();
      if (line.toLowerCase().startsWith('time:')) time = line.substring(5).trim();
      if (line.toLowerCase().startsWith('location:')) location = line.substring(9).trim();
    }
    final meta = msg.parsedMetadata ?? {};
    if (date.isEmpty && meta['meetupDate'] != null) {
      date = meta['meetupDate'].toString();
    }
    if (time.isEmpty && meta['meetupTime'] != null) {
      time = meta['meetupTime'].toString();
    }
    if (location.isEmpty && meta['meetupLocation'] != null) {
      location = meta['meetupLocation'].toString();
    }
    if (date.isEmpty && activeOffer?.meetupTime != null) {
      date = DateFormat('dd/MM/yy').format(activeOffer!.meetupTime!);
    }
    if (time.isEmpty && activeOffer?.meetupTime != null) {
      time = DateFormat('hh.mma').format(activeOffer!.meetupTime!);
    }
    if (location.isEmpty && (activeOffer?.meetupLocation?.isNotEmpty ?? false)) {
      location = activeOffer!.meetupLocation!;
    }
    if (date.isEmpty) {
      date = DateFormat('dd/MM/yy').format(msg.createdAt);
    }
    if (time.isEmpty) {
      time = DateFormat('hh.mma').format(msg.createdAt);
    }
    if (location.isEmpty) {
      location = order?.meetupLocation ?? (widget.listing?.locality?.isNotEmpty == true ? widget.listing!.locality! : 'Agreed Meeting Point');
    }

    final orderId = activeOffer?.orderId ?? order?.id ?? meta['orderId']?.toString() ?? widget.orderId;
    final hasMeetupAccepted = ref.watch(chatRoomNotifierProvider).messages.any(
      (m) => m.type == 'MEETUP_ACCEPTED' ||
             (m.parsedMetadata?['eventType'] == 'MEETUP_CONFIRMED')
    );
    final isConfirmed = order?.isMeetupConfirmed == true ||
        (orderId != null && _confirmedMeetupOrderIds.contains(orderId)) ||
        msg.type == 'MEETUP_ACCEPTED' ||
        hasMeetupAccepted;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.centerLeft, // Left aligned matching Image 2
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF004E54), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dark Teal Header: Meeting Scheduled / Confirmed
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF004E54),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isConfirmed ? Icons.check_circle_rounded : Icons.event_available_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isConfirmed ? 'Meeting Confirmed' : 'Meeting Scheduled',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Date Row with dark teal badge (Image 1 & 2)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              date,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Time Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Time',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            time,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Location Row (Touch to navigate in Google Maps!)
                      InkWell(
                        onTap: () async {
                          if (location.isNotEmpty && location != 'Agreed Meeting Point') {
                            final query = Uri.encodeComponent(location);
                            final mapUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                            try {
                              if (await canLaunchUrl(mapUrl)) {
                                await launchUrl(mapUrl, mode: LaunchMode.externalApplication);
                              } else {
                                await launchUrl(mapUrl);
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not open map: $e')),
                                );
                              }
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'Location',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF004E54)),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  location,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF004E54),
                                    decoration: TextDecoration.underline,
                                    decorationColor: Color(0xFF004E54),
                                  ),
                                  textAlign: TextAlign.end,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action Button:
                      // For Seller: [ Mark As Sold ] (Enabled only after Buyer confirms meetup!)
                      // For Buyer: [ Confirm Meetup ] -> when clicked switches to [ Show OTP ]!
                      if (isSeller) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: isConfirmed
                                ? () {
                                    final effectiveOrderId = orderId ?? ref.read(orderProvider).order?.id;
                                    if (effectiveOrderId == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Loading order details... Please tap again.')),
                                      );
                                      ref.read(orderProvider.notifier).fetchOrderByListing(widget.listingId);
                                      return;
                                    }

                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (ctx) => SellerOtpVerificationScreen(
                                          orderId: effectiveOrderId,
                                          buyerName: activeOffer?.buyerName ?? widget.buyerName ?? room?.buyerName ?? 'Buyer',
                                          meetupTime: time,
                                          meetupLocation: location,
                                          productTitle: activeOffer?.listingTitle ?? room?.listingTitle ?? widget.listing?.title ?? 'Product',
                                          productPrice: activeOffer?.currentEffectiveAmount ?? (room?.listingPrice != 0.0 ? room?.listingPrice : null) ?? widget.listing?.price ?? 0.0,
                                          productImageUrl: activeOffer?.listingImageUrl ?? room?.listingImageUrl ?? widget.listing?.primaryImageUrl,
                                        ),
                                      ),
                                    );
                                  }
                                : null, // Disabled until buyer confirms!
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004E54),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFCBD5E1),
                              disabledForegroundColor: const Color(0xFF64748B),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isConfirmed ? 'Mark As Sold' : 'Mark As Sold (Awaiting Confirmation)',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ] else if (!isConfirmed) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _isConfirmingMeetup
                                ? null
                                : () => _confirmMeetupAction(orderId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004E54),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF004E54),
                              disabledForegroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isConfirmingMeetup
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'Confirm Meetup',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              var effectiveOrderId = orderId ?? widget.orderId ?? ref.read(orderProvider).order?.id;
                              if (effectiveOrderId == null) {
                                await ref.read(orderProvider.notifier).fetchOrderByListing(widget.listingId);
                                effectiveOrderId = ref.read(orderProvider).order?.id;
                              }
                              if (!mounted) return;
                              if (effectiveOrderId != null) {
                                BuyerShowOtpModal.show(context, orderId: effectiveOrderId);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Order details could not be found. Please try again.')),
                                );
                              }
                            },
                            icon: const Icon(Icons.lock_open_rounded, size: 16, color: Colors.white),
                            label: const Text(
                              'Show OTP',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004E54),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // TD avatar + Timestamp below the card (Image 2)
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF004E54),
                child: Text(
                  peerInitials,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                timeStr,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String dateText) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        dateText,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildOfferNegotiationBanner(OfferModel offer) {
    if (offer.isAccepted) {
      final isBuyer = offer.isBuyer;
      final isSeller = offer.isSeller;
      final order = ref.watch(orderProvider).order;

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.celebration_rounded, color: Color(0xFF15803D), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Offer Accepted!',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                      ),
                      Text(
                        'Agreed Price: ₹${offer.currentEffectiveAmount.toInt()}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
                if (offer.orderId != null && isBuyer) ...[
                  if (order?.isMeetupConfirmed == true || _confirmedMeetupOrderIds.contains(offer.orderId!))
                    ElevatedButton.icon(
                      onPressed: () => BuyerShowOtpModal.show(context, orderId: offer.orderId!),
                      icon: const Icon(Icons.lock_open_rounded, size: 13, color: Colors.white),
                      label: const Text('Show OTP', style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004E54),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else if ((order?.meetupTime != null && order?.meetupLocation != null) ||
                           (offer.meetupTime != null && offer.meetupLocation != null))
                    ElevatedButton(
                      onPressed: _isConfirmingMeetup ? null : () => _confirmMeetupAction(offer.orderId!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004E54),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF004E54),
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _isConfirmingMeetup
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Confirm Meetup', style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                ],
              ],
            ),
            if (offer.orderId != null && isSeller) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ScheduleMeetupBottomSheet.show(context, orderId: offer.orderId!),
                      icon: const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF004E54)),
                      label: const Text('Schedule', style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF004E54))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF004E54)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => SellerOtpVerificationScreen(
                              orderId: offer.orderId!,
                              buyerName: offer.buyerName,
                              productTitle: offer.listingTitle ?? 'Product',
                              productPrice: offer.currentEffectiveAmount,
                              productImageUrl: offer.listingImageUrl,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 12, color: Colors.white),
                      label: const Text('Verify OTP', style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004E54),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    if (offer.isPending) {
      final isSeller = offer.isSeller;
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_offer, color: Color(0xFF1D4ED8), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      isSeller ? 'Offer Received:' : 'Your Offer:',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                    ),
                  ],
                ),
                Text(
                  '₹${offer.amount.toInt()}',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8)),
                ),
              ],
            ),
            if (isSeller) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => RejectOfferBottomSheet.show(
                        context,
                        offerId: offer.id,
                        onRejected: () => ref.read(offerProvider.notifier).fetchLatestOffer(widget.listingId),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Decline', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showCounterDialog(offer),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Counter', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showAcceptDialog(offer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Accept', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Awaiting seller response...',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (offer.isCountered) {
      final isBuyer = offer.isBuyer;
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sync_alt_rounded, color: Color(0xFFB45309), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      isBuyer ? 'Seller Countered:' : 'Your Counter Offer:',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
                Text(
                  '₹${offer.counterAmount?.toInt() ?? 0}',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                ),
              ],
            ),
            if (isBuyer) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref.read(offerProvider.notifier).rejectOffer(offer.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Decline', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showCounterDialog(offer),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Counter Back', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showAcceptDialog(offer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Accept', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyState(String sellerName) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xFFE0F2F1),
              child: Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary, size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              'Start Negotiation with $sellerName',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Discuss product condition, delivery methods, or submit a direct offer below.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessageModel msg, bool isMe, String peerInitials, OfferModel? activeOffer) {
    final timeStr = msg.formattedTime;
    final order = ref.watch(orderProvider).order;
    final currentUserId = ref.watch(authProvider).user?.id ?? '';
    final room = ref.watch(chatRoomNotifierProvider).room;
    final isSeller = _computeIsSeller(
      currentUserId: currentUserId,
      room: room,
      activeOffer: activeOffer,
    );
    final effOrderId = activeOffer?.orderId ?? order?.id;

    if (msg.isDeliveryAddressShared) {
      final meta = msg.parsedMetadata;
      final recipient = meta?['recipientName']?.toString() ?? '';
      final phone = meta?['phone']?.toString() ?? '';
      final addressLine = meta?['addressLine']?.toString() ?? '';
      final city = meta?['city']?.toString() ?? '';
      final pincode = meta?['pincode']?.toString() ?? '';

      final fullAddress = addressLine.isNotEmpty
          ? '$addressLine, $city - $pincode'
          : (msg.content?.replaceFirst(RegExp(r'Delivery Address:\s*', caseSensitive: false), '') ?? '');

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 290,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF004E54).withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF004E54),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: Color(0xFF5EEAD4), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Delivery Address Shared',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recipient.isNotEmpty) ...[
                      Text(
                        recipient + (phone.isNotEmpty ? ' ($phone)' : ''),
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      fullAddress,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Seller can courier product to this address.',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        timeStr,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (msg.isShipmentDispatched) {
      final meta = msg.parsedMetadata;
      final trackingNum = meta?['trackingNumber']?.toString() ?? 'N/A';
      final courierPartner = meta?['courierPartner']?.toString() ?? 'Courier';
      final estDelivery = meta?['estimatedDeliveryDate']?.toString() ?? 'Estimated delivery TBD';
      final orderId = meta?['orderId']?.toString();

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 290,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF004E54).withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF004E54),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, color: Color(0xFF5EEAD4), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Shipment Dispatched',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tracking No:',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Text(
                          trackingNum,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Courier:',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Text(
                          courierPartner,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Est. Delivery:',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Text(
                          estDelivery,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (orderId != null) {
                            context.push('/orders/$orderId/track');
                          } else {
                            context.push('/orders/listing/${widget.listingId}/track');
                          }
                        },
                        icon: const Icon(Icons.gps_fixed_rounded, size: 16),
                        label: const Text(
                          'Track My Order',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004E54),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    // For Buyer: Confirm Delivery Received button
                    if (!isSeller) ...[
                      const SizedBox(height: 8),
                      if (order != null && (order.status.toUpperCase() == 'DELIVERED' || order.status.toUpperCase() == 'COMPLETED'))
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Delivery Confirmed',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final effectiveId = orderId ?? effOrderId ?? order?.id;
                              if (effectiveId != null) {
                                _confirmBuyerDelivery(effectiveId);
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text(
                              'Confirm Delivery Received',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        timeStr,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (msg.isTransactionCompleted) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Transaction Completed!',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF166534),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                msg.content ??
                    'Delivery confirmed by buyer! Escrow funds released to seller and product marked Sold Out.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Color(0xFF15803D),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (msg.isOfferAccepted ||
        msg.type == 'OFFER_ACCEPTED' ||
        (msg.content != null && (msg.content!.contains("Offer accepted") || msg.content!.contains("ACCEPTED!")))) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F6F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF004E54).withValues(alpha: 0.2), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎉', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  "Offer accepted! Let's chat and meetup.",
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
      );
    }

    if (msg.isOffer && (msg.offerAmount ?? 0) > 0) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFE8F5F5) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF004E54).withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_offer, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    isMe ? 'You made an offer' : 'Offer received',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '₹${msg.offerAmount?.toInt() ?? 0}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(msg),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (msg.isMeetup || (msg.content != null && msg.content!.contains('Meeting Scheduled'))) {
      return _buildMeetingScheduledCard(msg, activeOffer, isMe, timeStr, peerInitials);
    }

    if (msg.isMeetupAccepted || (msg.content != null && msg.content!.contains('Meetup confirmed! Show OTP'))) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 16),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  '🤝 Meetup confirmed! Tap "Show OTP" on the card above upon meeting.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (msg.isImage || (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty)) {
      return _buildImageBubble(msg, isMe, peerInitials);
    }

    if (isMe) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: const BoxConstraints(maxWidth: 290),
              decoration: BoxDecoration(
                color: const Color(0xFF004E54),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                msg.content ?? '',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                _buildStatusIcon(msg),
              ],
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: const BoxConstraints(maxWidth: 290),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.content ?? '',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF1E293B),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF004E54),
                  child: Text(
                    peerInitials,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  bool _isLocalFile(String path) {
    if (path.isEmpty) return false;
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('chat/') ||
        trimmed.startsWith('listings/') ||
        trimmed.startsWith('users/') ||
        trimmed.startsWith('reviews/') ||
        trimmed.startsWith('media/')) {
      return false;
    }
    try {
      return File(trimmed).existsSync();
    } catch (_) {
      return false;
    }
  }

  Widget _buildImageBubble(ChatMessageModel msg, bool isMe, String peerInitials) {
    final timeStr = msg.formattedTime;
    final mediaUrl = msg.mediaUrl ?? '';
    final localPath = (msg.localPath != null && _isLocalFile(msg.localPath!))
        ? msg.localPath!
        : (_isLocalFile(mediaUrl) ? mediaUrl : null);
    final isLocal = localPath != null;
    final resolvedUrl = isLocal ? localPath : ApiClient.resolveMediaUrl(mediaUrl);

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (msg.isFailed) {
                if (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) {
                  ref.read(chatRoomNotifierProvider.notifier).sendImageMessage(
                        filePath: msg.mediaUrl!,
                        caption: msg.content,
                        retryClientMessageId: msg.clientMessageId,
                      );
                }
              } else if (mediaUrl.isNotEmpty) {
                _openFullScreenViewer(msg);
              }
            },
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Container(
                width: 250,
                height: 280,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image rendering (Local instant file or Cached Remote CDN)
                    if (isLocal)
                      Image.file(
                        File(localPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildImageErrorWidget(),
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: resolvedUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFFEDF2F7),
                          child: const Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF004E54),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => _buildImageErrorWidget(),
                      ),

                    // Optimistic uploading progress overlay (Instagram-style)
                    if (msg.isSending)
                      Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Sending...',
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
                      ),

                    // Failed overlay with retry
                    if (msg.isFailed)
                      Container(
                        color: Colors.black.withValues(alpha: 0.55),
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Upload failed\nTap to retry',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Gradient overlay with timestamp and ticks
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.72),
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (msg.content != null &&
                                msg.content!.isNotEmpty &&
                                msg.content != 'Sent an image')
                              Expanded(
                                child: Text(
                                  msg.content!,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            else
                              const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  _buildImageStatusIcon(msg),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isMe) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFF004E54),
                  child: Text(
                    peerInitials,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageStatusIcon(ChatMessageModel msg) {
    if (msg.isSending) {
      return const SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
      );
    }
    if (msg.isFailed) {
      return const Icon(Icons.error_outline, size: 13, color: Color(0xFFEF4444));
    }
    if (msg.isRead) {
      return const Icon(Icons.done_all, size: 14, color: Color(0xFF5EEAD4));
    }
    if (msg.status.toUpperCase() == 'DELIVERED') {
      return const Icon(Icons.done_all, size: 14, color: Colors.white70);
    }
    return const Icon(Icons.done, size: 13, color: Colors.white70);
  }

  Widget _buildImageErrorWidget() {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 36),
            SizedBox(height: 4),
            Text(
              'Image unavailable',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenViewer(ChatMessageModel msg) {
    final mediaUrl = msg.mediaUrl ?? '';
    final localPath = (msg.localPath != null && _isLocalFile(msg.localPath!))
        ? msg.localPath!
        : (_isLocalFile(mediaUrl) ? mediaUrl : null);
    final isLocal = localPath != null;
    final resolvedUrl = isLocal ? localPath : ApiClient.resolveMediaUrl(mediaUrl);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.7),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
              ),
              title: Text(
                msg.senderName ?? 'Photo',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      msg.formattedTime,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Center(
              child: PhotoView(
                imageProvider: isLocal
                    ? FileImage(File(resolvedUrl)) as ImageProvider
                    : CachedNetworkImageProvider(resolvedUrl),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2.5,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                loadingBuilder: (context, event) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white54, size: 48),
                      SizedBox(height: 8),
                      Text('Failed to load image', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusIcon(ChatMessageModel msg) {
    if (msg.isSending) {
      return const SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF94A3B8)),
      );
    }
    if (msg.isFailed) {
      return GestureDetector(
        onTap: () {
          if (msg.isImage && msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) {
            ref.read(chatRoomNotifierProvider.notifier).sendImageMessage(
                  filePath: msg.mediaUrl!,
                  caption: msg.content,
                  retryClientMessageId: msg.clientMessageId,
                );
          } else if (msg.content != null) {
            ref.read(chatRoomNotifierProvider.notifier).sendTextMessage(
                  msg.content!,
                  retryClientMessageId: msg.clientMessageId,
                );
          }
        },
        child: const Icon(Icons.error_outline, size: 13, color: Color(0xFFEF4444)),
      );
    }
    if (msg.isRead) {
      return const Icon(Icons.done_all, size: 14, color: AppTheme.primary);
    }
    if (msg.status.toUpperCase() == 'DELIVERED') {
      return const Icon(Icons.done_all, size: 14, color: Color(0xFF94A3B8));
    }
    return const Icon(Icons.done, size: 13, color: Color(0xFF94A3B8));
  }
}
