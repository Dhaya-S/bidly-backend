import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8081/api', // Local development (ADB reverse / localhost:8081)
);

const String _tokenKey = 'bidly_jwt';
const String _userDataKey = 'bidly_user_data';

/// Dio HTTP client with JWT injection and token refresh on 401.
class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiClient(this._storage) : _dio = _createDio() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
            options.contentType = null; // Let Dio generate boundary automatically
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 || error.response?.statusCode == 403) {
            // Token expired or access revoked — clear invalid session
            await clearToken();
          }
          handler.next(error);
        },
      ),
    );

    // Add PrettyDioLogger AFTER auth interceptor so Authorization header is visible in debug logs
    assert(() {
      _dio.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
      ));
      return true;
    }());
  }

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 3),
      ),
    );
  }

  Dio get dio => _dio;
  String get baseUrl => _baseUrl;
  String get wsUrl => '${_baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://')}/ws';

  /// Save JWT after login.
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  /// Get stored JWT.
  Future<String?> getToken() => _storage.read(key: _tokenKey);

  /// Save cached user data JSON string.
  Future<void> saveUserData(String userJson) =>
      _storage.write(key: _userDataKey, value: userJson);

  /// Get cached user data JSON string.
  Future<String?> getUserData() => _storage.read(key: _userDataKey);

  /// Clear JWT and user data on logout.
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userDataKey);
  }

  /// Check if user is authenticated.
  Future<bool> get isAuthenticated async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.trim().isNotEmpty;
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) =>
      _dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> put<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      _dio.put<T>(path, data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      _dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options);

  /// Resolves any media URL for display or video streaming.
  /// Direct HTTP/HTTPS URLs (e.g. presigned Cloudflare R2 URLs) stream directly from CDN.
  /// Relative paths fallback to backend media endpoints.
  static String resolveMediaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();

    // Local file paths
    if (trimmed.startsWith('/data/') ||
        trimmed.startsWith('/storage/') ||
        trimmed.startsWith('file://') ||
        trimmed.contains(r':\') ||
        (trimmed.length > 2 && trimmed[1] == ':' && (trimmed[2] == '/' || trimmed[2] == '\\'))) {
      return trimmed;
    }

    // Rewrite Cloudflare r2.cloudflarestorage.com or r2.dev URLs to use the backend streaming endpoint
    if (trimmed.contains('r2.cloudflarestorage.com') || trimmed.contains('.r2.dev')) {
      try {
        final uri = Uri.parse(trimmed);
        var path = uri.path;
        while (path.startsWith('/')) {
          path = path.substring(1);
        }
        // If path begins with bucket name (e.g. bidly-media/...), strip it
        if (path.startsWith('bidly-media/')) {
          path = path.substring('bidly-media/'.length);
        }
        return '$_baseUrl/media/file/$path';
      } catch (_) {
        var cleanPath = trimmed;
        if (cleanPath.contains('?')) {
          cleanPath = cleanPath.substring(0, cleanPath.indexOf('?'));
        }
        if (cleanPath.contains('.r2.dev/')) {
          cleanPath = cleanPath.substring(cleanPath.indexOf('.r2.dev/') + 8);
        } else if (cleanPath.contains('r2.cloudflarestorage.com/')) {
          cleanPath = cleanPath.substring(cleanPath.indexOf('r2.cloudflarestorage.com/') + 25);
        }
        while (cleanPath.startsWith('/')) {
          cleanPath = cleanPath.substring(1);
        }
        if (cleanPath.startsWith('bidly-media/')) {
          cleanPath = cleanPath.substring('bidly-media/'.length);
        }
        return '$_baseUrl/media/file/$cleanPath';
      }
    }

    // Direct HTTP/HTTPS URLs (including external CDNs that are not R2)
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // Relative paths
    if (trimmed.startsWith('/api/')) {
      final baseWithoutApi = _baseUrl.endsWith('/api')
          ? _baseUrl.substring(0, _baseUrl.length - 4)
          : _baseUrl;
      return '$baseWithoutApi$trimmed';
    }
    if (trimmed.startsWith('/media/file/')) {
      return '$_baseUrl$trimmed';
    }
    if (trimmed.startsWith('/media/')) {
      return '$_baseUrl$trimmed';
    }
    if (trimmed.startsWith('media/file/')) {
      return '$_baseUrl/$trimmed';
    }
    if (trimmed.startsWith('/')) {
      return '$_baseUrl/media/file$trimmed';
    }

    return '$_baseUrl/media/file/$trimmed';
  }
}

// ── Riverpod Providers ────────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(secureStorageProvider)),
);
