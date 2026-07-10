import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'sync_service.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _hasConnection = true;
  StreamSubscription? _subscription;

  ConnectivityService() {
    _initConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
  }

  bool get hasConnection => _hasConnection;

  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      print("Erreur initialisation connectivité: $e");
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasNet = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (_hasConnection != hasNet) {
      _hasConnection = hasNet;
      notifyListeners();
      print("Statut de connexion changé: ${hasNet ? 'ONLINE' : 'OFFLINE'}");
      
      if (hasNet && AuthService.isAuthenticated) {
        SyncService.instance.syncAll();
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
