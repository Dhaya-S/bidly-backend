import '../../profile/providers/wishlist_provider.dart';
import '../../profile/providers/orders_provider.dart';
import '../../profile/providers/my_listings_provider.dart';
import '../../profile/providers/wallet_provider.dart';
import '../../profile/providers/notifications_provider.dart';
import '../../chat/providers/chat_provider.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/auth_state.dart';
import '../models/user_model.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final Ref _ref;

  AuthNotifier(this._apiClient, this._ref) : super(const AuthState()) {
    checkAuthStatus();
  }

  /// Check existing session from stored JWT & cached profile
  Future<void> checkAuthStatus() async {
    final token = await _apiClient.getToken();
    if (token == null || token.trim().isEmpty) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    // Restore cached user profile immediately for instant UI load
    UserModel? cachedUser;
    final cachedJson = await _apiClient.getUserData();
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final map = jsonDecode(cachedJson) as Map<String, dynamic>;
        cachedUser = UserModel.fromJson(map);
      } catch (_) {}
    }

    // Set authenticated state right away
    state = state.copyWith(
      status: AuthStatus.authenticated,
      token: token,
      user: cachedUser,
    );

    // Refresh profile from server in background
    try {
      final response = await _apiClient.dio.get('/auth/me');
      if (response.data != null && response.data['success'] == true) {
        final userData = response.data['data'] as Map<String, dynamic>;
        final user = UserModel.fromJson(userData);
        await _apiClient.saveUserData(jsonEncode(userData));
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        // Token is explicitly expired or invalid
        await _apiClient.clearToken();
        state = const AuthState(status: AuthStatus.unauthenticated);
        _invalidateUserData();
      }
      // On network timeout or connection issues, keep user logged in with cached session
    } catch (_) {
      // Keep existing authenticated state
    }
  }

  /// Sends OTP via Fast2SMS
  Future<bool> sendOtp({
    required String mobile,
    String? name,
    required bool isSignUp,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
      final normalizedPhone = cleanMobile.length > 10
          ? cleanMobile.substring(cleanMobile.length - 10)
          : cleanMobile;

      final response = await _apiClient.dio.post(
        '/auth/send-otp',
        data: {
          'mobile': normalizedPhone,
          'name': name?.trim(),
          'signUp': isSignUp,
          'isSignUp': isSignUp,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>?;
        final requestId = data?['requestId'] as String?;

        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          pendingMobile: normalizedPhone,
          pendingName: name?.trim(),
          pendingRequestId: requestId,
        );
        return true;
      } else {
        final msg = response.data?['message'] as String? ?? 'Failed to send OTP';
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: msg,
        );
        return false;
      }
    } on DioException catch (e) {
      final errorMsg = _extractErrorMessage(e, 'Failed to send OTP');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: errorMsg,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An unexpected error occurred',
      );
      return false;
    }
  }

  /// Verifies OTP and completes authentication
  Future<bool> verifyOtp({required String otp}) async {
    final mobile = state.pendingMobile;
    if (mobile == null || mobile.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Mobile number missing. Please start again.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final response = await _apiClient.dio.post(
        '/auth/verify-otp',
        data: {
          'mobile': mobile,
          'otp': otp.trim(),
          'requestId': state.pendingRequestId,
          'name': state.pendingName,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        final token = data['token'] as String;
        final userData = data['user'] as Map<String, dynamic>;
        final user = UserModel.fromJson(userData);

        await _apiClient.saveToken(token);
        await _apiClient.saveUserData(jsonEncode(userData));

        state = state.copyWith(
          status: AuthStatus.authenticated,
          token: token,
          user: user,
          pendingMobile: null,
          pendingName: null,
          pendingRequestId: null,
        );
        _invalidateUserData();
        return true;
      } else {
        final msg = response.data?['message'] as String? ?? 'Invalid OTP code';
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: msg,
        );
        return false;
      }
    } on DioException catch (e) {
      final errorMsg = _extractErrorMessage(e, 'Invalid OTP verification code');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: errorMsg,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to verify OTP',
      );
      return false;
    }
  }

  /// Resends OTP to pending phone number
  Future<bool> resendOtp() async {
    final mobile = state.pendingMobile;
    if (mobile == null) return false;

    try {
      final response = await _apiClient.dio.post(
        '/auth/resend-otp',
        queryParameters: {'mobile': mobile},
      );
      if (response.data != null && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>?;
        final requestId = data?['requestId'] as String?;
        state = state.copyWith(pendingRequestId: requestId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Sets pending phone number if navigated manually
  void setPendingMobile(String mobile, {String? name}) {
    state = state.copyWith(
      pendingMobile: mobile,
      pendingName: name,
    );
  }

  /// Logout user completely
  Future<void> logout() async {
    await _apiClient.clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
    _invalidateUserData();
  }

  void _invalidateUserData() {
    try {
      _ref.invalidate(wishlistProvider);
      _ref.invalidate(chatRoomListProvider);
      _ref.invalidate(ordersProvider);
      _ref.invalidate(myListingsProvider);
      _ref.invalidate(walletProvider);
      _ref.invalidate(notificationsProvider);
    } catch (_) {}
  }

  String _extractErrorMessage(DioException e, String fallback) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map && data.containsKey('message')) {
        return data['message'].toString();
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Cannot connect to backend server. Please ensure the backend is running and reachable.';
    }
    return e.message ?? fallback;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient, ref);
});
