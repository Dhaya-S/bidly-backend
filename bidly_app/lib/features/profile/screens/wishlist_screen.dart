import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_theme.dart';
import '../providers/wishlist_provider.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wishlistProvider.notifier).fetchWishlist();
    });
  }

  Future<void> _removeItem(String listingId) async {
    final success = await ref.read(wishlistProvider.notifier).removeFromWishlist(listingId);
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from wishlist'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wishlistState = ref.watch(wishlistProvider);
    final items = wishlistState.items;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: Text(
          'Wishlist (${items.length})',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppTheme.border.withValues(alpha: 0.7),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF004E54),
          onRefresh: () => ref.read(wishlistProvider.notifier).fetchWishlist(),
          child: wishlistState.isLoading && items.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF004E54)),
                )
              : items.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.favorite_border_rounded, size: 54, color: AppTheme.textHint),
                              SizedBox(height: 14),
                              Text(
                                'Your wishlist is empty',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Save items you like by tapping the heart icon in Explore or Home',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) {
                        final item = items[idx];
                        final priceFormatted = '₹${item.price.toInt().toString().replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (Match m) => '${m[1]},',
                            )}';

                        return GestureDetector(
                          onTap: () => context.push('/listing/${item.id}', extra: item),
                          child: Container(
                            padding: const EdgeInsets.all(12),
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
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: item.primaryImageUrl != null && item.primaryImageUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: ApiClient.resolveMediaUrl(item.primaryImageUrl!),
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(
                                            width: 64,
                                            height: 64,
                                            color: const Color(0xFFF1F5F9),
                                            child: const Center(
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF004E54)),
                                              ),
                                            ),
                                          ),
                                          errorWidget: (_, __, ___) => Container(
                                            width: 64,
                                            height: 64,
                                            color: const Color(0xFFFFE4E6),
                                            child: const Icon(Icons.favorite_rounded, color: Color(0xFFF43F5E), size: 24),
                                          ),
                                        )
                                      : Container(
                                          width: 64,
                                          height: 64,
                                          color: const Color(0xFFFFE4E6),
                                          child: const Center(
                                            child: Icon(Icons.favorite_rounded, color: Color(0xFFF43F5E), size: 26),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        priceFormatted,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF004E54),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.locality ?? item.city ?? "Chennai"} · ${item.sellingMethod == "AUCTION" ? "Auction" : "Direct Buy"}',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          color: AppTheme.textSecondary.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                                  onPressed: () => _removeItem(item.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
