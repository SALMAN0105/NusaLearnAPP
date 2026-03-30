import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // static const String baseUrl = 'http://10.0.2.2:8000/api';
  // static const String baseUrl = 'http://127.0.0.1:8000/api';
  static const String baseUrl =
      'https://prediction-acquisition-repository-usgs.trycloudflare.com//api/';

  static Dio getClient() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          print("API Error: ${e.response?.statusCode} - ${e.message}");
          return handler.next(e);
        },
      ),
    );

    return dio;
  }

  // --- [KODE TAMBAHAN: DEFENSIVE CODING & SYSTEM STABILITY] ---

  // 1. Singleton Instance: Mengubah alokasi memori dari O(n) menjadi O(1)
  static Dio? _secureInstance;

  // Gunakan metode ini di seluruh aplikasi Anda mulai sekarang (bukan getClient)
  static Dio getDefensiveClient() {
    if (_secureInstance == null) {
      // Panggil getClient() legacy HANYA SATU KALI seumur hidup aplikasi
      _secureInstance = getClient();

      // 2. Layer Pertahanan Tambahan: Fault Tolerance & Edge Case Handling
      _secureInstance!.interceptors.add(
        InterceptorsWrapper(
          onError: (DioException e, handler) {
            // Evaluasi tipe kegagalan jaringan secara presisi
            bool isNetworkFault =
                e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.unknown;

            if (isNetworkFault) {
              print(
                "[DEFENSIVE ALERT] Kegagalan Jaringan / Tunnel Terputus. Node tidak dapat dijangkau.",
              );
              // Jika Anda menggunakan Cloudflare Tunnel nanti, error ini yang akan menangkap
              // kegagalan saat tunnel mati atau berganti URL.
            }

            // Mencegah Null Pointer Exception (NPE) jika server mati total (Dead Node)
            if (e.response == null) {
              print(
                "[DEFENSIVE ALERT] Server backend (Laravel) tidak memberikan response apa pun.",
              );
            } else if (e.response?.statusCode == 401) {
              // Token kedaluwarsa: Praktik standar arsitektur keamanan
              print(
                "[DEFENSIVE ALERT] Sesi tidak valid / Token Expired. Harap paksa user Logout.",
              );
              // TODO: Integrasikan logika penghapusan SharedPreferences di sini
            } else if (e.response?.statusCode == 500) {
              print(
                "[DEFENSIVE ALERT] Internal Server Error di sisi Backend (Laravel Crash).",
              );
            }

            return handler.next(e);
          },
        ),
      );
    }

    // Kembalikan instans yang sudah aman dan berada di RAM
    return _secureInstance!;
  }
}
