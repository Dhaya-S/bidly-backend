import '../../auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class MyListingItemModel {
  final String id;
  final String title;
  final double price;
  final String status; // ACTIVE, SHIPPING, COMPLETED, CANCELLED
  final String sellingMethod; // AUCTION, DIRECT_BUY
  final String? timeLeft;
  final int bidsCount;
  final String? subtext; // e.g. "In Transit" or "12 bids"
  final String? imageUrl;
  final String locality;
  final DateTime? auctionEndTime;

  const MyListingItemModel({
    required this.id,
    required this.title,
    required this.price,
    required this.status,
    required this.sellingMethod,
    this.timeLeft,
    this.bidsCount = 0,
    this.subtext,
    this.imageUrl,
    this.locality = 'Chennai',
    this.auctionEndTime,
  });

  factory MyListingItemModel.fromJson(Map<String, dynamic> json) {
    final method = json['sellingMethod']?.toString().toUpperCase() ?? 'AUCTION';
    final isAuction = method == 'AUCTION';

    final currentBid = (json['currentBid'] is num)
        ? (json['currentBid'] as num).toDouble()
        : double.tryParse(json['currentBid']?.toString() ?? '');
    final startingBid = (json['startingBid'] is num)
        ? (json['startingBid'] as num).toDouble()
        : double.tryParse(json['startingBid']?.toString() ?? '');
    final basePrice = (json['price'] is num)
        ? (json['price'] as num).toDouble()
        : (double.tryParse(json['price']?.toString() ?? '0') ?? 0.0);

    double displayPrice;
    if (isAuction) {
      if (currentBid != null && currentBid > 0) {
        displayPrice = currentBid;
      } else if (startingBid != null && startingBid > 0) {
        displayPrice = startingBid;
      } else {
        displayPrice = basePrice;
      }
    } else {
      displayPrice = basePrice;
    }

    // Determine normalized status
    String rawStatus = json['status']?.toString().toUpperCase() ?? 'ACTIVE';
    if (rawStatus == 'SOLD') {
      rawStatus = 'COMPLETED';
    }

    // Calculate real-time timeLeft
    String? calculatedTimeLeft;
    DateTime? endTime;
    if (json['auctionEndTime'] != null) {
      try {
        endTime = DateTime.parse(json['auctionEndTime'].toString()).toLocal();
        final diff = endTime.difference(DateTime.now());
        if (diff.isNegative) {
          calculatedTimeLeft = 'Ended';
        } else if (diff.inDays > 0) {
          calculatedTimeLeft = '${diff.inDays}d ${diff.inHours % 24}h';
        } else if (diff.inHours > 0) {
          calculatedTimeLeft = '${diff.inHours}h ${diff.inMinutes % 60}m';
        } else if (diff.inMinutes > 0) {
          calculatedTimeLeft = '${diff.inMinutes}m';
        } else {
          calculatedTimeLeft = '${diff.inSeconds}s';
        }
      } catch (_) {}
    }

    return MyListingItemModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Listing',
      price: displayPrice,
      status: rawStatus,
      sellingMethod: method,
      timeLeft: calculatedTimeLeft ?? json['timeLeft']?.toString(),
      bidsCount: (json['bidsCount'] is num) ? (json['bidsCount'] as num).toInt() : 0,
      subtext: json['subtext']?.toString(),
      imageUrl: json['primaryImageUrl']?.toString(),
      locality: json['locality']?.toString() ?? 'Chennai',
      auctionEndTime: endTime,
    );
  }
}

class MyListingsState {
  final List<MyListingItemModel> auctionListings;
  final List<MyListingItemModel> directListings;
  final bool isLoading;
  final String selectedTab; // 'AUCTION' | 'DIRECT'
  final String selectedFilter; // 'ALL', 'ACTIVE', 'SHIPPING', 'COMPLETED', 'CANCELLED'

  const MyListingsState({
    this.auctionListings = const [],
    this.directListings = const [],
    this.isLoading = false,
    this.selectedTab = 'AUCTION',
    this.selectedFilter = 'ALL',
  });

  MyListingsState copyWith({
    List<MyListingItemModel>? auctionListings,
    List<MyListingItemModel>? directListings,
    bool? isLoading,
    String? selectedTab,
    String? selectedFilter,
  }) {
    return MyListingsState(
      auctionListings: auctionListings ?? this.auctionListings,
      directListings: directListings ?? this.directListings,
      isLoading: isLoading ?? this.isLoading,
      selectedTab: selectedTab ?? this.selectedTab,
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }
}

class MyListingsNotifier extends StateNotifier<MyListingsState> {
  final ApiClient _apiClient;
  final String? _userId;

  MyListingsNotifier(this._apiClient, this._userId) : super(const MyListingsState()) {
    if (_userId != null && _userId.isNotEmpty) {
      fetchMyListings();
    }
  }

  Future<void> fetchMyListings() async {
    final token = await _apiClient.getToken();
    if (token == null || token.isEmpty || _userId == null || _userId.isEmpty) {
      state = const MyListingsState();
      return;
    }
    state = state.copyWith(isLoading: true);
    try {
      final res = await _apiClient.get('/listings/my');
      if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
        final list = (res.data['data'] as List)
            .map((item) => MyListingItemModel.fromJson(item as Map<String, dynamic>))
            .toList();

        final auctions = list.where((l) => l.sellingMethod == 'AUCTION').toList();
        final directs = list.where((l) => l.sellingMethod != 'AUCTION').toList();

        state = state.copyWith(
          auctionListings: auctions,
          directListings: directs,
          isLoading: false,
        );
        return;
      }
    } catch (_) {}

    state = state.copyWith(
      auctionListings: [],
      directListings: [],
      isLoading: false,
    );
  }

  Future<bool> deleteListing(String listingId) async {
    try {
      final res = await _apiClient.delete('/listings/$listingId');
      if (res.data != null && res.data['success'] == true) {
        state = state.copyWith(
          auctionListings: state.auctionListings.where((item) => item.id != listingId).toList(),
          directListings: state.directListings.where((item) => item.id != listingId).toList(),
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  void setTab(String tab) {
    state = state.copyWith(selectedTab: tab, selectedFilter: 'ALL');
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void clear() {
    state = const MyListingsState();
  }
}

final myListingsProvider =
    StateNotifierProvider<MyListingsNotifier, MyListingsState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final userId = ref.watch(authProvider.select((s) => s.user?.id));
  return MyListingsNotifier(apiClient, userId);
});
