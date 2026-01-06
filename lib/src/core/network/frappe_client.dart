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
    await _dio.post(
      '/api/method/login',
      data: FormData.fromMap({'usr': usernameOrEmail, 'pwd': password}),
    );
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

