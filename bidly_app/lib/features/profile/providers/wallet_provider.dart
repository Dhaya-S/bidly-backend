import '../../auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class WalletTransaction {
  final String transactionId;
  final double amountAdded;
  final double updatedBalance;
  final String status;
  final DateTime timestamp;
  final String paymentMethod;

  const WalletTransaction({
    required this.transactionId,
    required this.amountAdded,
    required this.updatedBalance,
    required this.status,
    required this.timestamp,
    required this.paymentMethod,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      transactionId: json['transactionId']?.toString() ?? '',
      amountAdded: (json['amountAdded'] is num)
          ? (json['amountAdded'] as num).toDouble()
          : (double.tryParse(json['amountAdded']?.toString() ?? '0') ?? 0.0),
      updatedBalance: (json['updatedBalance'] is num)
          ? (json['updatedBalance'] as num).toDouble()
          : (double.tryParse(json['updatedBalance']?.toString() ?? '0') ?? 0.0),
      status: json['status']?.toString() ?? 'SUCCESS',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      paymentMethod: json['paymentMethod']?.toString() ?? 'UPI',
    );
  }
}

class WalletState {
  final double balance;
  final double reservedBalance;
  final bool isLoading;
  final bool isAdding;
  final String? errorMessage;
  final WalletTransaction? lastTransaction;

  const WalletState({
    this.balance = 0.0,
    this.reservedBalance = 0.0,
    this.isLoading = false,
    this.isAdding = false,
    this.errorMessage,
    this.lastTransaction,
  });

  WalletState copyWith({
    double? balance,
    double? reservedBalance,
    bool? isLoading,
    bool? isAdding,
    String? errorMessage,
    WalletTransaction? lastTransaction,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      reservedBalance: reservedBalance ?? this.reservedBalance,
      isLoading: isLoading ?? this.isLoading,
      isAdding: isAdding ?? this.isAdding,
      errorMessage: errorMessage,
      lastTransaction: lastTransaction ?? this.lastTransaction,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final ApiClient _apiClient;
  final String? _userId;

  WalletNotifier(this._apiClient, this._userId) : super(const WalletState()) {
    if (_userId != null && _userId.isNotEmpty) {
      fetchWallet();
    }
  }

  Future<void> fetchWallet() async {
    final token = await _apiClient.getToken();
    if (token == null || token.isEmpty || _userId == null || _userId.isEmpty) {
      state = const WalletState();
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _apiClient.get('/wallet');
      if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
        final data = res.data['data'];
        final bal = (data['balance'] is num)
            ? (data['balance'] as num).toDouble()
            : (double.tryParse(data['balance']?.toString() ?? '0') ?? 0.0);
        final resBal = (data['reservedBalance'] is num)
            ? (data['reservedBalance'] as num).toDouble()
            : (double.tryParse(data['reservedBalance']?.toString() ?? '0') ?? 0.0);
        state = state.copyWith(balance: bal, reservedBalance: resBal, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<WalletTransaction?> topUp({
    required double amount,
    required String paymentMethod,
  }) async {
    state = state.copyWith(isAdding: true, errorMessage: null);
    try {
      final res = await _apiClient.post('/wallet/top-up', data: {
        'amount': amount,
        'paymentMethod': paymentMethod,
        'description': 'Top up via $paymentMethod',
      });

      if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
        final data = res.data['data'] as Map<String, dynamic>;
        final txn = WalletTransaction.fromJson(data);
        state = state.copyWith(
          balance: txn.updatedBalance,
          isAdding: false,
          lastTransaction: txn,
        );
        return txn;
      }
      state = state.copyWith(isAdding: false, errorMessage: 'Top-up failed. Please try again.');
      return null;
    } catch (e) {
      state = state.copyWith(isAdding: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> createRazorpayOrder(double amount) async {
    try {
      final res = await _apiClient.post('/wallet/razorpay/create-order', data: {
        'amount': amount,
      });
      if (res.data != null && res.data['success'] == true) {
        return res.data['data'] as Map<String, dynamic>?;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
    return null;
  }

  Future<WalletTransaction?> verifyRazorpayPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required double amount,
  }) async {
    state = state.copyWith(isAdding: true, errorMessage: null);
    try {
      final res = await _apiClient.post('/wallet/razorpay/verify-payment', data: {
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
        'amount': amount,
      });
      if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
        final data = res.data['data'] as Map<String, dynamic>;
        final txn = WalletTransaction.fromJson(data);
        state = state.copyWith(
          balance: txn.updatedBalance,
          isAdding: false,
          lastTransaction: txn,
        );
        return txn;
      }
      state = state.copyWith(isAdding: false, errorMessage: 'Payment verification failed.');
      return null;
    } catch (e) {
      state = state.copyWith(isAdding: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> createRazorpayPaymentLink(double amount, {String? name, String? phone}) async {
    state = state.copyWith(isAdding: true, errorMessage: null);
    try {
      final res = await _apiClient.post('/wallet/razorpay/create-payment-link', data: {
        'amount': amount,
        'name': name,
        'phone': phone,
      });
      if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
        return res.data['data'] as Map<String, dynamic>;
      }
      state = state.copyWith(
        isAdding: false,
        errorMessage: res.data?['message']?.toString() ?? 'Failed to generate Razorpay payment link.',
      );
    } catch (e) {
      state = state.copyWith(isAdding: false, errorMessage: e.toString());
    }
    return null;
  }

  Future<WalletTransaction?> checkRazorpayPaymentLinkStatus(String paymentLinkId) async {
    try {
      final res = await _apiClient.post('/wallet/razorpay/check-payment-link', data: {
        'paymentLinkId': paymentLinkId,
      });
      if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
        final data = res.data['data'] as Map<String, dynamic>;
        if (data['status'] == 'SUCCESS') {
          final txn = WalletTransaction.fromJson(data);
          state = state.copyWith(
            balance: txn.updatedBalance,
            isAdding: false,
            lastTransaction: txn,
          );
          return txn;
        }
      }
    } catch (_) {
      // Periodic check, ignore transient network drops
    }
    return null;
  }

  void resetAddingState() {
    state = state.copyWith(isAdding: false);
  }

  void clear() {
    state = const WalletState();
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final userId = ref.watch(authProvider.select((s) => s.user?.id));
  return WalletNotifier(apiClient, userId);
});
