import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'sync_service.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _hasConnection = true;
  StreamSubscription? _subscription;

  // Debounce pour éviter les flaps (ex. passage WiFi → données)
  Timer? _debounce;

  ConnectivityService() {
    _initConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        // Debounce 800 ms : attend que l'interface soit stable
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 800), () {
          _updateConnectionStatus(results);
        });
      },
    );
  }

  bool get hasConnection => _hasConnection;

  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _updateConnectionStatus(results);
    } catch (e) {
      debugPrint("Erreur initialisation connectivité: $e");
    }
  }

  /// Vérifie si on a un accès internet réel en tentant une connexion TCP
  /// sur le DNS de Cloudflare (1.1.1.1:80) — rapide et sans dépendance HTTP.
  Future<bool> _checkRealInternet() async {
    // Sur Web, on ne peut pas ouvrir de socket — on suppose connecté si
    // connectivity_plus dit oui
    if (kIsWeb) return true;
    try {
      final socket = await Socket.connect(
        '1.1.1.1',
        80,
        timeout: const Duration(seconds: 4),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    final hasInterface =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);

    // Pas d'interface réseau → hors-ligne immédiatement, pas besoin de ping
    if (!hasInterface) {
      _setStatus(false);
      return;
    }

    // Interface dispo → on vérifie qu'on atteint vraiment internet
    final reachable = await _checkRealInternet();
    _setStatus(reachable);
  }

  void _setStatus(bool online) {
    if (_hasConnection == online) return;
    _hasConnection = online;
    notifyListeners();
    debugPrint("Connectivité : ${online ? 'ONLINE' : 'OFFLINE'}");

    if (online && AuthService.isAuthenticated) {
      SyncService.instance.syncAll();
    }
  }

  /// Permet de forcer un re-check depuis l'UI (ex. bouton "Réessayer").
  Future<void> recheck() async {
    final results = await _connectivity.checkConnectivity();
    await _updateConnectionStatus(results);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
