import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class OrderTimelineEvent {
  final String status;
  final String title;
  final String description;
  final String timeFormatted;
  final bool isCompleted;

  const OrderTimelineEvent({
    required this.status,
    required this.title,
    required this.description,
    required this.timeFormatted,
    this.isCompleted = true,
  });

  factory OrderTimelineEvent.fromJson(Map<String, dynamic> json) {
    return OrderTimelineEvent(
      status: json['status']?.toString() ?? 'DELIVERED',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      timeFormatted: json['formattedEventTime']?.toString() ?? '',
      isCompleted: json['isCompleted'] ?? true,
    );
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String title;
  final double price;
  final String date;
  final String sellerName;
  final double sellerRating;
  final String? imageUrl;
  final String status; // Delivered, Shipped, etc.
  final String source; // AUCTION, DIRECT_SALE
  final List<OrderTimelineEvent> timeline;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.title,
    required this.price,
    required this.date,
    required this.sellerName,
    this.sellerRating = 4.7,
    this.imageUrl,
    this.status = 'Delivered',
    this.source = 'AUCTION',
    this.timeline = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawTimeline = (json['trackingTimeline'] as List?) ?? [];
    final timelineEvents = rawTimeline
        .map((e) => OrderTimelineEvent.fromJson(e as Map<String, dynamic>))
        .toList();

    DateTime? parsedDate;
    final dateRaw = json['deliveredAt'] ?? json['createdAt'];
    if (dateRaw != null) {
      parsedDate = DateTime.tryParse(dateRaw.toString());
    }

    final dateStr = parsedDate != null
        ? '${parsedDate.day} ${_monthName(parsedDate.month)} ${parsedDate.year}'
        : '';

    return OrderModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      title: json['productTitle']?.toString() ?? 'Product',
      price: (json['wonAmount'] is num)
          ? (json['wonAmount'] as num).toDouble()
          : (double.tryParse(json['wonAmount']?.toString() ?? '0') ?? 0.0),
      date: dateStr,
      sellerName: json['sellerName']?.toString() ?? 'Seller',
      sellerRating: (json['sellerRating'] is num)
          ? (json['sellerRating'] as num).toDouble()
          : 0.0,
      imageUrl: json['primaryImageUrl']?.toString(),
      status: json['status'] == 'DELIVERED' ? 'Delivered' : (json['status']?.toString() ?? 'Pending'),
      source: json['orderSource']?.toString() ?? 'AUCTION',
      timeline: timelineEvents,
    );
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}

class OrdersState {
  final List<OrderModel> auctionOrders;
  final List<OrderModel> directOrders;
  final bool isLoading;
  final String selectedTab; // 'AUCTION' | 'DIRECT'
  final String selectedFilter; // 'RECENT' | 'LAST_MONTH' | 'LAST_YEAR'
  final OrderModel? selectedOrder;

  const OrdersState({
    this.auctionOrders = const [],
    this.directOrders = const [],
    this.isLoading = false,
    this.selectedTab = 'AUCTION',
    this.selectedFilter = 'RECENT',
    this.selectedOrder,
  });

  int get totalOrdersCount => auctionOrders.length + directOrders.length;

  OrdersState copyWith({
    List<OrderModel>? auctionOrders,
    List<OrderModel>? directOrders,
    bool? isLoading,
    String? selectedTab,
    String? selectedFilter,
    OrderModel? selectedOrder,
  }) {
    return OrdersState(
      auctionOrders: auctionOrders ?? this.auctionOrders,
      directOrders: directOrders ?? this.directOrders,
      isLoading: isLoading ?? this.isLoading,
      selectedTab: selectedTab ?? this.selectedTab,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedOrder: selectedOrder ?? this.selectedOrder,
    );
  }
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  final ApiClient _apiClient;
  final String? _userId;

  OrdersNotifier(this._apiClient, this._userId) : super(const OrdersState()) {
    if (_userId != null && _userId.isNotEmpty) {
      fetchOrders();
    }
  }

  Future<void> fetchOrders({bool isSilent = false}) async {
    final token = await _apiClient.getToken();
    if (token == null || token.isEmpty || _userId == null || _userId.isEmpty) {
      state = const OrdersState();
      return;
    }

    if (!isSilent && state.auctionOrders.isEmpty && state.directOrders.isEmpty) {
      state = state.copyWith(isLoading: true);
    }
    try {
      final res = await _apiClient.get('/orders');
      if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
        final list = (res.data['data'] as List)
            .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
            .toList();

        final auctions = list.where((o) => o.source == 'AUCTION').toList();
        final directs = list.where((o) => o.source != 'AUCTION').toList();

        state = state.copyWith(
          auctionOrders: auctions,
          directOrders: directs,
          isLoading: false,
        );
        return;
      }
    } catch (_) {}

    state = state.copyWith(
      auctionOrders: [],
      directOrders: [],
      isLoading: false,
    );
  }

  void setTab(String tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void selectOrder(OrderModel order) {
    state = state.copyWith(selectedOrder: order);
  }

  void clear() {
    state = const OrdersState();
  }
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final userId = ref.watch(authProvider.select((s) => s.user?.id));
  return OrdersNotifier(apiClient, userId);
});
