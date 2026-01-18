import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

class FrappeClient {
  FrappeClient._(this._dio);

  final Dio _dio;

  Dio get dio => _dio;

  static Future<FrappeClient> create({String? baseUrl}) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/$'), ''),
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: {
          HttpHeaders.acceptHeader: 'application/json',
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final cookieDir = Directory('${dir.path}/.cookies');
    if (!cookieDir.existsSync()) cookieDir.createSync(recursive: true);

    final jar = PersistCookieJar(storage: FileStorage(cookieDir.path));
    dio.interceptors.add(CookieManager(jar));
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) {
          // Normalize common Frappe error shapes.
          handler.next(e);
        },
      ),
    );

    return FrappeClient._(dio);
  }

  Future<void> login({required String usernameOrEmail, required String password}) async {
    // Frappe expects x-www-form-urlencoded for /api/method/login
    final response = await _dio.post(
      '/api/method/login',
      data: FormData.fromMap({'usr': usernameOrEmail, 'pwd': password}),
    );
    
    // ERPNext returns 200 even on failed login, so we need to check the response
    if (response.data is Map) {
      final data = response.data as Map;
      final message = data['message']?.toString() ?? '';
      final exc = data['exc']?.toString() ?? '';
      final excType = data['exc_type']?.toString() ?? '';
      
      // Check for login failure indicators - ERPNext returns error messages on failure
      // Success is indicated by "Logged In" or empty exc/exc_type
      final messageLower = message.toLowerCase();
      final excLower = exc.toLowerCase();
      final excTypeLower = excType.toLowerCase();
      
      final hasError = messageLower.contains('incorrect') || 
          messageLower.contains('invalid') || 
          messageLower.contains('not found') ||
          messageLower.contains('no such user') ||
          messageLower.contains('authentication failed') ||
          messageLower.contains('wrong') ||
          messageLower.contains('failed') ||
          excLower.contains('invalid') ||
          excLower.contains('incorrect') ||
          excTypeLower.contains('invalid') ||
          excTypeLower.contains('authentication') ||
          excTypeLower.contains('notfound') ||
          (exc.isNotEmpty && !excLower.contains('none'));
      
      // If there's an error indicator, throw exception
      if (hasError) {
        // Store the original message in the error for better error handling
        final errorMessage = message.isNotEmpty 
            ? message 
            : (exc.isNotEmpty ? exc : 'Invalid credentials');
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: errorMessage,
        );
      }
    }
  }

  Future<void> logout() async {
    try {
      await _dio.get('/api/method/logout');
    } catch (_) {
      // ignore
    }
  }

  Future<String> getLoggedUser() async {
    final res = await _dio.get('/api/method/frappe.auth.get_logged_user');
    final msg = res.data is Map ? (res.data['message'] as String?) : null;
    if (msg == null || msg.isEmpty) {
      throw StateError('Unable to read logged user');
    }
    return msg;
  }
}

