import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/notifications_provider.dart';

import '../../chat/widgets/new_offer_bottom_sheet.dart';
import '../../chat/widgets/buyer_show_otp_modal.dart';
import '../../auction/providers/order_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _handleNotificationTap(BuildContext context, WidgetRef ref, NotificationItemModel notif) async {
    ref.read(notificationsProvider.notifier).markAsRead(notif.id);

    final currentUserId = ref.read(authProvider).user?.id;
    final listingId = notif.listingId ?? notif.targetId;
    final buyerId = notif.metadata?['buyerId']?.toString();
    final offerId = notif.offerId ?? notif.metadata?['offerId']?.toString() ?? notif.targetId;
    final buyerName = notif.metadata?['buyerName']?.toString();
    final isCurrentUserBuyer = currentUserId != null && buyerId != null && currentUserId == buyerId;

    if (notif.type == 'NEW_OFFER' || notif.type == 'OFFER') {
      // If current user is buyer, route to offer chat (never show seller acceptance bottomsheet to buyer)
      if (isCurrentUserBuyer) {
        if (listingId != null && listingId.isNotEmpty) {
          context.push(
            '/chat/offer/$listingId',
            extra: {
              'buyerId': buyerId,
              'offerId': offerId,
              'buyerName': buyerName,
            },
          );
          return;
        }
        context.push(AppRoutes.chatList);
        return;
      }

      // Current user is seller: open NewOfferBottomSheet
      if (listingId != null && listingId.isNotEmpty) {
        final offerAmount = (notif.metadata?['offerAmount'] != null)
            ? (double.tryParse(notif.metadata!['offerAmount'].toString()) ?? 0.0)
            : 0.0;
        final listingPrice = (notif.metadata?['listingPrice'] != null)
            ? (double.tryParse(notif.metadata!['listingPrice'].toString()) ?? 0.0)
            : 0.0;

        NewOfferBottomSheet.show(
          context,
          offerId: offerId ?? '',
          listingId: listingId,
          buyerId: buyerId,
          buyerName: buyerName ?? 'Buyer',
          offerAmount: offerAmount,
          productTitle: notif.body,
          listingPrice: listingPrice,
        );
        return;
      }
      context.push(AppRoutes.chatList);
    } else if (notif.type == 'OFFER_COUNTERED') {
      // Counter-offer sent by seller to buyer: buyer views counter-offer in offer chat
      if (listingId != null && listingId.isNotEmpty) {
        context.push(
          '/chat/offer/$listingId',
          extra: {
            'buyerId': buyerId,
            'offerId': offerId,
            'buyerName': buyerName,
          },
        );
        return;
      }
      context.push(AppRoutes.chatList);
    } else if (notif.type == 'MEETUP_SCHEDULED') {
      final effectiveOrderId = notif.orderId ?? notif.targetId ?? notif.metadata?['orderId']?.toString();
      if (effectiveOrderId != null && effectiveOrderId.isNotEmpty) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Confirming meetup...'),
            backgroundColor: Color(0xFF004E54),
            duration: Duration(seconds: 2),
          ),
        );
        final ok = await ref.read(orderProvider.notifier).confirmMeetup(effectiveOrderId);
        if (context.mounted) {
          if (ok) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Meetup confirmed! Tap "Show OTP" when you meet the seller.'),
                backgroundColor: Color(0xFF004E54),
                duration: Duration(seconds: 3),
              ),
            );
          }
          if (listingId != null && listingId.isNotEmpty) {
            context.push(
              '/chat/offer/$listingId',
              extra: {
                'buyerId': buyerId,
                'offerId': offerId,
                'buyerName': buyerName,
                'orderId': effectiveOrderId,
              },
            );
            return;
          }
          BuyerShowOtpModal.show(context, orderId: effectiveOrderId);
          return;
        }
      }
      if (!context.mounted) return;
      if (listingId != null && listingId.isNotEmpty) {
        context.push(
          '/chat/offer/$listingId',
          extra: {
            'buyerId': buyerId,
            'offerId': offerId,
            'buyerName': buyerName,
            'orderId': effectiveOrderId,
          },
        );
        return;
      }
      context.push(AppRoutes.orders);
    } else if (notif.type == 'MEETUP_CONFIRMED') {
      final orderId = notif.orderId ?? notif.targetId ?? notif.metadata?['orderId']?.toString();
      if (listingId != null && listingId.isNotEmpty) {
        context.push(
          '/chat/offer/$listingId',
          extra: {
            'buyerId': buyerId,
            'offerId': offerId,
            'buyerName': buyerName,
            'orderId': orderId,
          },
        );
        return;
      }
      if (orderId != null && orderId.isNotEmpty) {
        BuyerShowOtpModal.show(context, orderId: orderId);
        return;
      }
      context.push(AppRoutes.orders);
    } else if (notif.type == 'OTP_READY') {
      final orderId = notif.orderId ?? notif.targetId;
      if (orderId != null && orderId.isNotEmpty) {
        BuyerShowOtpModal.show(context, orderId: orderId);
        return;
      }
      context.push(AppRoutes.orders);
    } else if (notif.type == 'ITEM_SOLD') {
      // ITEM_SOLD notification is sent to BUYER: prompt review/rating
      final orderId = notif.orderId ?? notif.targetId;
      if (orderId != null && orderId.isNotEmpty) {
        context.push('/orders/$orderId/review');
        return;
      }
      context.push(AppRoutes.orders);
    } else if (notif.type == 'TRANSACTION_COMPLETED') {
      // TRANSACTION_COMPLETED notification is sent to SELLER: route to sale summary
      final orderId = notif.orderId ?? notif.targetId;
      if (orderId != null && orderId.isNotEmpty) {
        context.push('/my-listings/sale-summary/$orderId');
        return;
      }
      context.push(AppRoutes.myListings);
    } else if (notif.type == 'REVIEW_RECEIVED') {
      // REVIEW_RECEIVED notification is sent to SELLER when buyer leaves a review
      final orderId = notif.orderId ?? notif.targetId;
      if (orderId != null && orderId.isNotEmpty) {
        context.push('/my-listings/sale-summary/$orderId');
        return;
      }
      context.push(AppRoutes.profile);
    } else if (notif.type == 'OFFER_ACCEPTED' || notif.type == 'OFFER_REJECTED') {
      if (listingId != null && listingId.isNotEmpty) {
        context.push(
          '/chat/offer/$listingId',
          extra: {
            'buyerId': buyerId,
            'offerId': offerId,
            'buyerName': buyerName,
          },
        );
        return;
      }
      context.push(AppRoutes.chatList);
    } else if (notif.type == 'BID') {
      context.push(AppRoutes.home);
    } else if (notif.type == 'SHIPPED' || notif.type == 'DELIVERED') {
      context.push(AppRoutes.orders);
    } else {
      if (notif.targetRoute != null && notif.targetRoute!.isNotEmpty) {
        context.push(notif.targetRoute!);
        return;
      }
      if (listingId != null && listingId.isNotEmpty) {
        context.push(
          '/chat/offer/$listingId',
          extra: {
            'buyerId': buyerId,
            'offerId': offerId,
            'buyerName': buyerName,
          },
        );
        return;
      }
      context.push(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationsProvider);
    final unreadCount = notifState.unreadCount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: const Text(
          'Notification',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(notificationsProvider.notifier).markAllAsRead();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications marked as read'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text(
              'Mark all read',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF004E54),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtitle: "X unread"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Text(
                '$unreadCount unread',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),

            // Notification Cards List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: notifState.notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final notif = notifState.notifications[idx];

                  return InkWell(
                    onTap: () => _handleNotificationTap(context, ref, notif),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon / Thumbnail Box
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F4F2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    notif.type == 'OFFER' || notif.type == 'NEW_OFFER' || notif.type == 'OFFER_COUNTERED'
                                        ? Icons.local_offer_outlined
                                        : (notif.type == 'BID'
                                            ? Icons.gavel_rounded
                                            : (notif.type == 'SHIPPED'
                                                ? Icons.local_shipping_outlined
                                                : (notif.type == 'MEETUP_SCHEDULED' || notif.type == 'MEETUP_CONFIRMED'
                                                    ? Icons.handshake_outlined
                                                    : (notif.type == 'REVIEW_RECEIVED'
                                                        ? Icons.star_outline_rounded
                                                        : Icons.check_circle_outline_rounded)))),
                                    color: const Color(0xFF004E54),
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Title & Body
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notif.title,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      notif.body,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notif.timeAgo,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Unread Dot Indicator
                              if (notif.isUnread)
                                Container(
                                  width: 9,
                                  height: 9,
                                  margin: const EdgeInsets.only(top: 4, left: 4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF004E54),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),

                          // Action Button if present
                          if (notif.actionLabel != null) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: ElevatedButton(
                                onPressed: () => _handleNotificationTap(context, ref, notif),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF004E54),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  notif.actionLabel!,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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
}
