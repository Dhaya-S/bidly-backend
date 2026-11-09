import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chat_event_model.dart';
import '../models/chat_room_model.dart';
import '../providers/chat_provider.dart';
import '../services/chat_websocket_service.dart';
import '../widgets/in_app_message_banner.dart';
import 'chat_detail_screen.dart';
import 'offer_chat_screen.dart';

class ChatThreadModel {
  final String id;
  final String userName;
  final String userRole; // 'Seller' | 'Buyer'
  final String productSubject;
  final String lastMessage;
  final String timeAgo;
  final int unreadCount;
  final String userInitials;
  final String productTitle;
  final double productPrice;
  final String deliveryType;
  final String trackingNumber;
  final String courierName;
  final String listingId;
  final String? buyerId;
  final String? sellerId;
  final String? listingImageUrl;

  const ChatThreadModel({
    required this.id,
    required this.userName,
    required this.userRole,
    required this.productSubject,
    required this.lastMessage,
    required this.timeAgo,
    this.unreadCount = 0,
    required this.userInitials,
    this.productTitle = '',
    this.productPrice = 0.0,
    this.deliveryType = 'Courier',
    this.trackingNumber = '',
    this.courierName = '',
    this.listingId = '',
    this.buyerId,
    this.sellerId,
    this.listingImageUrl,
  });
}

class MessagesListScreen extends ConsumerStatefulWidget {
  const MessagesListScreen({super.key});

  @override
  ConsumerState<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends ConsumerState<MessagesListScreen> {
  int _selectedTab = 0; // 0 = Buyer, 1 = Seller
  bool _isLoading = true;
  ChatWebSocketService? _webSocketService;

  static String _formatTimeAgo(dynamic raw) {
    if (raw == null) return '';
    final str = raw.toString().trim();
    if (str.isEmpty) return '';
    DateTime? dt;
    if (str.contains('T') || (str.length >= 19 && str[10] == ' ')) {
      final isoStr = str.contains('T') ? str : str.replaceFirst(' ', 'T');
      final hasTz = isoStr.endsWith('Z') || isoStr.contains('+') || RegExp(r'-\d{2}:\d{2}$').hasMatch(isoStr);
      final normalized = hasTz ? isoStr : '${isoStr}Z';
      dt = DateTime.tryParse(normalized)?.toLocal();
    } else {
      dt = DateTime.tryParse(str)?.toLocal();
    }
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24 && dt.day == now.day) return '${diff.inHours}h';
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return '1d';
    }
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('d MMM').format(dt);
  }

  List<ChatThreadModel> _buyerThreads = [];
  List<ChatThreadModel> _sellerThreads = [];

  void _populateFromCache() {
    final chatState = ref.read(chatRoomListProvider);
    if (chatState.rooms.isNotEmpty) {
      final currentUserId = ref.read(authProvider).user?.id;
      final List<ChatThreadModel> buyers = [];
      final List<ChatThreadModel> sellers = [];

      for (final room in chatState.rooms) {
        final otherName = room.otherUserName ?? (currentUserId == room.buyerId ? (room.sellerName ?? 'Seller') : (room.buyerName ?? 'Buyer'));
        final otherRole = room.otherUserRole ?? (currentUserId == room.buyerId ? 'Seller' : 'Buyer');
        final initials = otherName.isNotEmpty
            ? otherName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase()
            : 'U';

        final thread = ChatThreadModel(
          id: room.id,
          userName: otherName,
          userRole: otherRole,
          productSubject: 're: ${room.listingTitle ?? 'Listing'}',
          lastMessage: room.lastMessagePreview ?? 'Tap to view conversation',
          timeAgo: _formatTimeAgo(room.lastMessageAt ?? room.createdAt),
          unreadCount: room.unreadCount,
          userInitials: initials,
          productTitle: room.listingTitle ?? 'Listing',
          productPrice: room.listingPrice,
          deliveryType: 'Meetup',
          listingId: room.listingId,
          buyerId: room.buyerId,
          sellerId: room.sellerId,
          listingImageUrl: room.listingImageUrl,
        );

        if (currentUserId != null && currentUserId == room.buyerId) {
          buyers.add(thread);
        } else if (currentUserId != null && currentUserId == room.sellerId) {
          sellers.add(thread);
        } else {
          if (otherRole.toLowerCase() == 'seller') {
            buyers.add(thread);
          } else {
            sellers.add(thread);
          }
        }
      }

      _buyerThreads = buyers;
      _sellerThreads = sellers;
    }
  }

  @override
  void initState() {
    super.initState();
    _populateFromCache();
    final hasCache = _buyerThreads.isNotEmpty || _sellerThreads.isNotEmpty;
    _isLoading = !hasCache;
    _fetchRooms(isSilent: hasCache);
    _initWebSocket();
  }

  @override
  void dispose() {
    _webSocketService?.disconnect();
    _webSocketService = null;
    InAppMessageBanner.dismiss();
    super.dispose();
  }

  Future<void> _initWebSocket() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final currentUserId = ref.read(authProvider).user?.id;
      final token = await apiClient.getToken();

      _webSocketService = ChatWebSocketService(
        onEvent: _handleIncomingEvent,
        onNotification: (notifJson) {
          // Trigger room sync when a general notification is received
          _fetchRooms(isSilent: true);
        },
        onResyncRequired: () {
          _fetchRooms(isSilent: true);
        },
      );

      _webSocketService?.connect(
        wsUrl: apiClient.wsUrl,
        userId: currentUserId,
        token: token,
      );
    } catch (e) {
      debugPrint('[MESSAGES_SCREEN] Failed to init WebSocket: $e');
    }
  }

  void _handleIncomingEvent(ChatEventModel event) {
    if (!mounted) return;

    if (event.eventType == 'NEW_MESSAGE' ||
        event.eventType == 'OFFER_UPDATED' ||
        event.eventType == 'MEETUP_SCHEDULED' ||
        event.eventType == 'MEETUP_ACCEPTED' ||
        event.eventType == 'MEETUP_CONFIRMED') {
      
      final roomId = event.roomId;
      final msg = event.message;
      final preview = msg?.content ??
          (event.eventType == 'OFFER_UPDATED'
              ? 'Offer updated: ₹${event.offerAmount?.toInt() ?? ''}'
              : (event.eventType == 'MEETUP_SCHEDULED'
                  ? 'Meetup scheduled'
                  : 'New update'));

      bool found = false;
      ChatThreadModel? matchedThread;

      void updateList(List<ChatThreadModel> list) {
        final idx = list.indexWhere((t) => t.id == roomId);
        if (idx != -1) {
          final old = list[idx];
          final isIncoming = msg != null && !msg.isMine;
          final updated = ChatThreadModel(
            id: old.id,
            userName: old.userName,
            userRole: old.userRole,
            productSubject: old.productSubject,
            lastMessage: preview,
            timeAgo: 'Just now',
            unreadCount: isIncoming ? old.unreadCount + 1 : old.unreadCount,
            userInitials: old.userInitials,
            productTitle: old.productTitle,
            productPrice: old.productPrice,
            deliveryType: old.deliveryType,
            trackingNumber: old.trackingNumber,
            courierName: old.courierName,
            listingId: old.listingId,
            buyerId: old.buyerId,
            sellerId: old.sellerId,
            listingImageUrl: old.listingImageUrl,
          );
          list.removeAt(idx);
          list.insert(0, updated);
          matchedThread = updated;
          found = true;
        }
      }

      setState(() {
        updateList(_buyerThreads);
        updateList(_sellerThreads);
      });

      // If room was not present in memory, silently refetch
      if (!found) {
        _fetchRooms(isSilent: true);
      }

      // Instagram-style In-App notification banner
      if (msg != null && !msg.isMine && mounted) {
        final senderName = (msg.senderName != null && msg.senderName!.isNotEmpty)
            ? msg.senderName!
            : (matchedThread?.userName ?? 'New message');
        final productTitle = matchedThread?.productTitle;

        InAppMessageBanner.show(
          context: context,
          senderName: senderName,
          message: preview,
          productTitle: productTitle,
          onTap: () {
            if (matchedThread != null) {
              _openChatThread(matchedThread!);
            } else {
              _fetchRooms(isSilent: true);
            }
          },
        );
      }
    }
  }

  Future<void> _fetchRooms({bool isSilent = false}) async {
    if (!isSilent && _buyerThreads.isEmpty && _sellerThreads.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
    }
    try {
      final apiClient = ref.read(apiClientProvider);
      final currentUserId = ref.read(authProvider).user?.id;
      final res = await apiClient.get('/chat/rooms');

      if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
        final List roomsJson = res.data['data'] as List;
        final List<ChatThreadModel> buyers = [];
        final List<ChatThreadModel> sellers = [];

        for (final item in roomsJson) {
          final map = item as Map<String, dynamic>;
          final id = map['id']?.toString() ?? '';
          final buyerId = map['buyerId']?.toString();
          final sellerId = map['sellerId']?.toString();
          final otherName = map['otherUserName']?.toString() ?? 'User';
          final otherRole = map['otherUserRole']?.toString() ?? 'Buyer';
          final listingTitle = map['listingTitle']?.toString() ?? 'Listing';
          final listingPrice = (map['listingPrice'] is num) ? (map['listingPrice'] as num).toDouble() : 0.0;
          final lastMsg = map['lastMessagePreview']?.toString() ?? 'Tap to view conversation';
          final unread = (map['unreadCount'] is int) ? map['unreadCount'] as int : 0;
          final initials = otherName.isNotEmpty
              ? otherName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase()
              : 'U';

          final listingId = map['listingId']?.toString() ?? '';
          final listingImg = map['listingImageUrl']?.toString();

          final isAuction = map['sellingMethod']?.toString().toUpperCase() == 'AUCTION' ||
              map['orderSource']?.toString().toUpperCase() == 'AUCTION';
          final effDeliveryType = isAuction
              ? (map['orderDeliveryType'] == 'IN_PERSON_MEETUP' ? 'Meetup' : 'Courier')
              : 'Meetup';

          final thread = ChatThreadModel(
            id: id,
            userName: otherName,
            userRole: otherRole,
            productSubject: 're: $listingTitle',
            lastMessage: lastMsg,
            timeAgo: _formatTimeAgo(map['lastMessageAt'] ?? map['createdAt']),
            unreadCount: unread,
            userInitials: initials,
            productTitle: listingTitle,
            productPrice: listingPrice,
            deliveryType: effDeliveryType,
            listingId: listingId,
            buyerId: buyerId,
            sellerId: sellerId,
            listingImageUrl: listingImg,
          );

          if (currentUserId != null && currentUserId == buyerId) {
            buyers.add(thread);
          } else if (currentUserId != null && currentUserId == sellerId) {
            sellers.add(thread);
          } else {
            if (otherRole.toLowerCase() == 'seller') {
              buyers.add(thread);
            } else {
              sellers.add(thread);
            }
          }
        }

        final roomsList = roomsJson
            .map((r) => ChatRoomModel.fromJson(r as Map<String, dynamic>))
            .toList();
        ref.read(chatRoomListProvider.notifier).updateRooms(roomsList);

        if (mounted) {
          setState(() {
            _buyerThreads = buyers;
            _sellerThreads = sellers;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _openChatThread(ChatThreadModel thread) {
    // Clear unread count locally immediately for fast visual feedback
    setState(() {
      void clearCount(List<ChatThreadModel> list) {
        final idx = list.indexWhere((t) => t.id == thread.id);
        if (idx != -1) {
          final old = list[idx];
          list[idx] = ChatThreadModel(
            id: old.id,
            userName: old.userName,
            userRole: old.userRole,
            productSubject: old.productSubject,
            lastMessage: old.lastMessage,
            timeAgo: old.timeAgo,
            unreadCount: 0,
            userInitials: old.userInitials,
            productTitle: old.productTitle,
            productPrice: old.productPrice,
            deliveryType: old.deliveryType,
            trackingNumber: old.trackingNumber,
            courierName: old.courierName,
            listingId: old.listingId,
            buyerId: old.buyerId,
            sellerId: old.sellerId,
            listingImageUrl: old.listingImageUrl,
          );
        }
      }
      clearCount(_buyerThreads);
      clearCount(_sellerThreads);
    });

    final isSellerTab = _selectedTab == 1;
    final currentUserId = ref.read(authProvider).user?.id ?? '';
    final isUserSeller = isSellerTab ||
        (thread.sellerId != null && thread.sellerId!.isNotEmpty && thread.sellerId == currentUserId);

    if (thread.listingId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OfferChatScreen(
            listingId: thread.listingId,
            roomId: thread.id,
            buyerId: thread.buyerId,
            sellerId: thread.sellerId,
            isSellerView: isUserSeller,
            buyerName: thread.userName,
            productTitle: thread.productTitle,
            productPrice: thread.productPrice,
            listingImageUrl: thread.listingImageUrl,
          ),
        ),
      ).then((_) => _fetchRooms(isSilent: true));
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            thread: thread,
            isSellerView: _selectedTab == 1,
          ),
        ),
      ).then((_) => _fetchRooms(isSilent: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentList = _selectedTab == 0 ? _buyerThreads : _sellerThreads;
    final int buyerUnreadTotal = _buyerThreads.fold(0, (acc, t) => acc + t.unreadCount);
    final int sellerUnreadTotal = _sellerThreads.fold(0, (acc, t) => acc + t.unreadCount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22, color: Color(0xFF0F172A)),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: const Text(
          'Messages',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),

            // ── Tab Bar (Buyer vs Seller Segmented Pill) ──────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _selectedTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Buyer',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: _selectedTab == 0 ? FontWeight.w700 : FontWeight.w500,
                                    color: _selectedTab == 0 ? const Color(0xFF005459) : const Color(0xFF64748B),
                                  ),
                                ),
                                if (buyerUnreadTotal > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF005459),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$buyerUnreadTotal',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _selectedTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Seller',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: _selectedTab == 1 ? FontWeight.w700 : FontWeight.w500,
                                    color: _selectedTab == 1 ? const Color(0xFF005459) : const Color(0xFF64748B),
                                  ),
                                ),
                                if (sellerUnreadTotal > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF005459),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$sellerUnreadTotal',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ],
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
            const SizedBox(height: 14),

            // ── Card Container with Conversation Items ────────
            Expanded(
              child: _isLoading
                  ? _buildLoadingSkeleton()
                  : RefreshIndicator(
                      onRefresh: _fetchRooms,
                      color: const Color(0xFF005459),
                      child: currentList.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFE2F3F4),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 34,
                                            color: Color(0xFF005459),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _selectedTab == 0
                                            ? 'No buyer conversations yet'
                                            : 'No seller conversations yet',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _selectedTab == 0
                                            ? 'Offers you make or buy direct will appear here.'
                                            : 'Offers you receive will appear here.',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(19),
                                  child: ListView.separated(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    itemCount: currentList.length,
                                    separatorBuilder: (_, __) => const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Color(0xFFF1F5F9),
                                    ),
                                    itemBuilder: (ctx, idx) {
                                      final thread = currentList[idx];
                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _openChatThread(thread),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                              horizontal: 16,
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                // Circular Avatar with subtle teal tint
                                                Container(
                                                  width: 50,
                                                  height: 50,
                                                  decoration: const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Color(0xFFE2F3F4),
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.person_rounded,
                                                      color: Color(0xFF0F172A),
                                                      size: 28,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 14),

                                                // Name, re: Listing, Last message, and Unread badge
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      // Name and Time
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            thread.userName,
                                                            style: const TextStyle(
                                                              fontFamily: 'Poppins',
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.w700,
                                                              color: Color(0xFF0F172A),
                                                            ),
                                                          ),
                                                          Text(
                                                            thread.timeAgo,
                                                            style: const TextStyle(
                                                              fontFamily: 'Poppins',
                                                              fontSize: 12.5,
                                                              color: Color(0xFF94A3B8),
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),

                                                      // re: Subject
                                                      Text(
                                                        thread.productSubject,
                                                        style: const TextStyle(
                                                          fontFamily: 'Poppins',
                                                          fontSize: 12.5,
                                                          fontStyle: FontStyle.italic,
                                                          color: Color(0xFF94A3B8),
                                                          fontWeight: FontWeight.w400,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 3),

                                                      // Message preview and Badge
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              thread.lastMessage,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                fontFamily: 'Poppins',
                                                                fontSize: 13,
                                                                color: thread.unreadCount > 0
                                                                    ? const Color(0xFF0F172A)
                                                                    : const Color(0xFF64748B),
                                                                fontWeight: thread.unreadCount > 0
                                                                    ? FontWeight.w600
                                                                    : FontWeight.w400,
                                                              ),
                                                            ),
                                                          ),
                                                          if (thread.unreadCount > 0) ...[
                                                            const SizedBox(width: 8),
                                                            Container(
                                                              width: 22,
                                                              height: 22,
                                                              decoration: const BoxDecoration(
                                                                color: Color(0xFF005459),
                                                                shape: BoxShape.circle,
                                                              ),
                                                              child: Center(
                                                                child: Text(
                                                                  thread.unreadCount.toString(),
                                                                  style: const TextStyle(
                                                                    fontFamily: 'Poppins',
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w700,
                                                                    color: Colors.white,
                                                                    height: 1.0,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ],
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
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 130,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
