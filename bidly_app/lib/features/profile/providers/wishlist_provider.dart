import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../explore/models/listing_model.dart';

class WishlistState {
  final List<ListingModel> items;
  final bool isLoading;
  final String? error;

  const WishlistState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  WishlistState copyWith({
    List<ListingModel>? items,
    bool? isLoading,
    String? error,
  }) {
    return WishlistState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class WishlistNotifier extends StateNotifier<WishlistState> {
  final ApiClient _apiClient;
  final String? _userId;

  WishlistNotifier(this._apiClient, this._userId) : super(const WishlistState()) {
    if (_userId != null && _userId.isNotEmpty) {
      fetchWishlist();
    }
  }

  Future<void> fetchWishlist({bool isSilent = false}) async {
    final token = await _apiClient.getToken();
    if (token == null || token.isEmpty || _userId == null || _userId.isEmpty) {
      state = const WishlistState();
      return;
    }

    if (!isSilent && state.items.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final response = await _apiClient.get('/listings/wishlist');
      if (response.data != null && response.data['success'] == true) {
        final rawList = response.data['data'] as List? ?? [];
        final parsed = rawList
            .map((e) => ListingModel.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(items: parsed, isLoading: false);
      } else {
        if (!isSilent) state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      if (!isSilent) state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> removeFromWishlist(String listingId) async {
    final originalItems = List<ListingModel>.from(state.items);
    // Optimistic removal
    state = state.copyWith(
      items: state.items.where((item) => item.id != listingId).toList(),
    );

    try {
      final res = await _apiClient.post('/listings/$listingId/like');
      if (res.data != null && res.data['success'] == true) {
        return true;
      } else {
        state = state.copyWith(items: originalItems);
        return false;
      }
    } catch (_) {
      state = state.copyWith(items: originalItems);
      return false;
    }
  }

  Future<void> toggleWishlist(ListingModel listing) async {
    final isAlreadyWishlisted = state.items.any((i) => i.id == listing.id);
    if (isAlreadyWishlisted) {
      await removeFromWishlist(listing.id);
    } else {
      state = state.copyWith(items: [listing, ...state.items]);
      try {
        await _apiClient.post('/listings/${listing.id}/like');
      } catch (_) {
        state = state.copyWith(
          items: state.items.where((i) => i.id != listing.id).toList(),
        );
      }
    }
  }

  void clear() {
    state = const WishlistState();
  }
}

final wishlistProvider =
    StateNotifierProvider<WishlistNotifier, WishlistState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final userId = ref.watch(authProvider.select((s) => s.user?.id));
  return WishlistNotifier(apiClient, userId);
});
