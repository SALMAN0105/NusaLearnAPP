import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:nusalearn/core/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NetworkAwareSyncManager {
  // === SINGLETON PATTERN ===
  // Memastikan hanya ada 1 instance di memori (O(1) Space)
  static final NetworkAwareSyncManager _instance =
      NetworkAwareSyncManager._internal();
  factory NetworkAwareSyncManager() => _instance;
  NetworkAwareSyncManager._internal();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  // Defensive flags untuk mencegah Race Condition
  bool _isSyncing = false;
  bool _wasOffline = false;

  void initialize() {
    _checkInitialState();

    // Listener ini berjalan secara global di Main Isolate
    _subscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final isOnline =
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);

      // LOGIKA INTI: Transisi dari Offline ke Online
      if (isOnline && _wasOffline) {
        debugPrint("🌐 [NetworkManager] Koneksi pulih! Memulai Auto-Sync...");
        _executeGlobalSync();
      }

      // Catat status terakhir
      _wasOffline = !isOnline;
      if (!isOnline) {
        debugPrint("🚫 [NetworkManager] Koneksi terputus. Menunggu sinyal...");
      }
    });
  }

  Future<void> _checkInitialState() async {
    final results = await Connectivity().checkConnectivity();
    _wasOffline =
        !(results.contains(ConnectivityResult.mobile) ||
            results.contains(ConnectivityResult.wifi));
  }

  Future<void> _executeGlobalSync() async {
    // 1. Cegah eksekusi ganda jika sync sedang berjalan
    if (_isSyncing) return;

    // 2. Defensive Check: Pastikan user SUDAH LOGIN
    // Kita tidak mau sync berjalan jika siswa baru di halaman Login
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    if (!isLoggedIn) {
      debugPrint("🔒 [NetworkManager] Batal Sync: Siswa belum login.");
      return;
    }

    _isSyncing = true;
    try {
      // 3. Eksekusi Sync Global Anda
      await SyncService().performGlobalSync(force: true);
      debugPrint("✅ [NetworkManager] Sinkronisasi otomatis selesai.");
    } catch (e) {
      debugPrint("❌ [NetworkManager] Sinkronisasi gagal: $e");
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
