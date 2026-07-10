import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Gère les actions déclenchées depuis les widgets natifs (bureau Android/iOS).
///
/// - [getInitialAction] : action lue au démarrage à froid (app fermée)
/// - [onAction] : stream pour recevoir les actions en temps réel (app déjà ouverte)
class WidgetIntentService {
  WidgetIntentService._();
  static final instance = WidgetIntentService._();

  static const _channel = MethodChannel('com.ngenou.app/widget');
  static const _eventChannel = EventChannel('com.ngenou.app/widget_events');

  Stream<String>? _actionStream;

  /// Stream d'actions widget reçues pendant que l'app est ouverte.
  Stream<String> get onAction {
    _actionStream ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is String)
        .cast<String>();
    return _actionStream!;
  }

  /// Retourne l'action initiale si l'app a été ouverte depuis un widget (démarrage à froid) :
  /// - `"open_tasks"` : naviguer vers /taches
  /// - `"add_task"`   : naviguer vers /taches et ouvrir le sheet d'ajout
  /// - `"open_defis"` : naviguer vers /defis
  /// - `null`         : démarrage normal
  Future<String?> getInitialAction() async {
    if (!Platform.isAndroid) return null;
    try {
      final action = await _channel.invokeMethod<String?>('getInitialAction');
      return action;
    } catch (e) {
      debugPrint('WidgetIntentService.getInitialAction error (non-fatal): $e');
      return null;
    }
  }
}
