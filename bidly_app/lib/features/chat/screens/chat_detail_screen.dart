import '../../profile/screens/report_problem_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import 'messages_list_screen.dart';
import 'offer_chat_screen.dart';

class ChatMessageItem {
  final String id;
  final String text;
  final String time;
  final bool isMe;
  final bool isShipmentCard;
  final Map<String, String>? shipmentData;

  const ChatMessageItem({
    required this.id,
    required this.text,
    required this.time,
    required this.isMe,
    this.isShipmentCard = false,
    this.shipmentData,
  });
}

class ChatDetailScreen extends ConsumerStatefulWidget {
  final ChatThreadModel thread;
  final bool isSellerView;

  const ChatDetailScreen({
    super.key,
    required this.thread,
    this.isSellerView = false,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null && mounted) {
        await ref.read(chatRoomNotifierProvider.notifier).initRoomById(
          widget.thread.id,
          listingId: widget.thread.listingId,
        );
        await ref.read(chatRoomNotifierProvider.notifier).sendImageMessage(
          filePath: picked.path,
        );
        _fetchMessages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select image: $e')),
        );
      }
    }
  }
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ChatMessageItem> _messages;

  final List<String> _quickSuggestions = [
    'Thanks for the update!',
    'Looks good!',
    'When will it...',
    'Can you share photos?',
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages = [];
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/chat/rooms/${widget.thread.id}/messages');
      if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
        final currentUserId = ref.read(authProvider).user?.id;
        final list = (res.data['data'] as List).map((m) {
          final isMe = currentUserId != null && m['senderId']?.toString() == currentUserId;
          DateTime? created;
          if (m['createdAt'] != null) {
            created = DateTime.tryParse(m['createdAt'].toString());
          }
          final timeStr = created != null
              ? '${created.hour > 12 ? created.hour - 12 : (created.hour == 0 ? 12 : created.hour)}:${created.minute.toString().padLeft(2, '0')} ${created.hour >= 12 ? 'PM' : 'AM'}'
              : '';

          final isShipment = m['type'] == 'COURIER_DISPATCHED' || m['type'] == 'SHIPMENT_UPDATE';
          return ChatMessageItem(
            id: m['id']?.toString() ?? '',
            text: m['content']?.toString() ?? '',
            time: timeStr,
            isMe: isMe,
            isShipmentCard: isShipment,
            shipmentData: isShipment && m['metadata'] != null
                ? Map<String, String>.from((m['metadata'] as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
                : null,
          );
        }).toList();

        if (mounted) {
          setState(() {
            _messages = list;
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

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    final timeStr = '${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    _textController.clear();
    setState(() {
      _messages.add(
        ChatMessageItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: trimmed,
          time: timeStr,
          isMe: true,
        ),
      );
    });

    try {
      await ref.read(apiClientProvider).post('/chat/rooms/${widget.thread.id}/messages', data: {
        'content': trimmed,
        'type': 'TEXT',
      });
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.thread.listingId.isNotEmpty) {
      return OfferChatScreen(
        listingId: widget.thread.listingId,
        roomId: widget.thread.id,
        buyerId: widget.thread.buyerId,
        sellerId: widget.thread.sellerId,
        isSellerView: widget.isSellerView,
        buyerName: widget.thread.userName,
        productTitle: widget.thread.productTitle,
        productPrice: widget.thread.productPrice,
        listingImageUrl: widget.thread.listingImageUrl,
      );
    }

    final displayName = widget.thread.userName.isNotEmpty
        ? widget.thread.userName
        : (widget.isSellerView ? 'Buyer' : 'Seller');
    final roleLabel = widget.isSellerView ? 'Buyer' : 'Seller';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF005459),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  displayName.isNotEmpty
                      ? (displayName.trim().split(' ').length > 1
                          ? (displayName.trim().split(' ')[0][0] + displayName.trim().split(' ')[1][0]).toUpperCase()
                          : displayName.substring(0, displayName.length >= 2 ? 2 : 1).toUpperCase())
                      : '?',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Online now · $roleLabel',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w500,
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
            icon: const Icon(Icons.call_outlined, color: AppTheme.textPrimary, size: 22),
            onPressed: () async {
              final uri = Uri.parse('tel:');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textPrimary, size: 22),
            onSelected: (val) {
              if (val == 'listing' && widget.thread.listingId.isNotEmpty) {
                context.push('/listing/${widget.thread.listingId}');
              } else if (val == 'report') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportProblemScreen()));
              } else if (val == 'safety') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Safety Guidelines', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                    content: const Text(
                      '• Meet in a public, well-lit place.\n'
                      '• Inspect the item thoroughly before sharing delivery OTP.\n'
                      '• Never pay outside the Bidly escrow system.',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.5),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (ctx) => [
              if (widget.thread.listingId.isNotEmpty)
                const PopupMenuItem(value: 'listing', child: Text('View Item Listing')),
              const PopupMenuItem(value: 'report', child: Text('Report User')),
              const PopupMenuItem(value: 'safety', child: Text('Safety Guidelines')),
            ],
          ),
        ],
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
            // ── Dynamic Product Preview Card ────────────────────
            if (widget.thread.productTitle.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.shopping_bag_outlined, color: Color(0xFF004E54), size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.thread.productTitle,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (widget.thread.productPrice > 0 || widget.thread.deliveryType.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (widget.thread.productPrice > 0)
                                  Text(
                                    '₹${widget.thread.productPrice.toInt()}',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                if (widget.thread.productPrice > 0 && widget.thread.deliveryType.isNotEmpty)
                                  const SizedBox(width: 8),
                                if (widget.thread.deliveryType.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      widget.thread.deliveryType,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 9.5,
                                        color: AppTheme.textSecondary,
                                      ),
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
              ),

            // ── Messages Stream ────────────────────────────────
            Expanded(
              child: _isLoading && _messages.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF004E54)))
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        // System Notice: Buyer Protection
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F6F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFB8E0DC)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 16, color: Color(0xFF007A87)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'BIDLY Buyer Protection is active for this transaction',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF004E54),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Render Message Bubbles & Shipment Cards
                  ..._messages.map((m) {
                    if (m.isShipmentCard) {
                      return _buildShipmentCard(m);
                    }
                    return _buildMessageBubble(m);
                  }),
                ],
              ),
            ),

            // ── Quick Suggestion Chips ──────────────────────────
            Container(
              height: 38,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _quickSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final text = _quickSuggestions[idx];
                  return GestureDetector(
                    onTap: () => _sendMessage(text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF007A87).withValues(alpha: 0.5)),
                      ),
                      child: Center(
                        child: Text(
                          text,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF004E54),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Message Input Bar ──────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppTheme.border.withValues(alpha: 0.8)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: AppTheme.textSecondary, size: 24),
                    onPressed: _pickAndSendImage,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppTheme.textHint,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _sendMessage(_textController.text),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5E7EB),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.send_rounded, color: Color(0xFF004E54), size: 18),
                      ),
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

  Widget _buildMessageBubble(ChatMessageItem m) {
    return Align(
      alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: m.isMe ? const Color(0xFF004E54) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: m.isMe ? null : Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.text,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: m.isMe ? Colors.white : AppTheme.textPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              m.time,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9.5,
                color: m.isMe ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentCard(ChatMessageItem m) {
    final tracking = m.shipmentData?['trackingNo']?.toString() ?? 'N/A';
    final courier = m.shipmentData?['courier']?.toString() ?? 'Courier';
    final estDelivery = m.shipmentData?['estDelivery']?.toString() ?? 'Estimated delivery TBD';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF004E54),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Shipment Dispatched',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tracking No.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Colors.white70),
              ),
              Text(
                tracking,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Courier',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Colors.white70),
              ),
              Text(
                courier,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Est. Delivery',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Colors.white70),
              ),
              Text(
                estDelivery,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: () {
                context.push(AppRoutes.orderTrackByListing.replaceFirst(':listingId', '11111111-1111-1111-1111-111111111111'));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00383D),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Track My Order',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
