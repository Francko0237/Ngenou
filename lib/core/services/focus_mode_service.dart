import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:do_not_disturb/do_not_disturb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

/// Gère le mode Focus : plein écran + silence des notifications (Android DND).
class FocusModeService {
  static final DoNotDisturbPlugin _dnd = DoNotDisturbPlugin();
  static const _savedFilterKey = 'focusMode_savedDndFilter';

  static Future<FocusModeApplyResult> enable() async {
    await _applyFullscreenUi(true);

    if (!Platform.isAndroid) {
      return FocusModeApplyResult(
        notificationsBlocked: false,
        needsPermission: false,
        message: Platform.isIOS
            ? 'Mode Focus actif. Activez le mode Concentration iOS pour bloquer les notifications.'
            : null,
      );
    }

    final hasAccess = await _dnd.isNotificationPolicyAccessGranted();
    if (!hasAccess) {
      return const FocusModeApplyResult(
        notificationsBlocked: false,
        needsPermission: true,
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_savedFilterKey)) {
        final previous = await _dnd.getDNDStatus();
        if (previous != InterruptionFilter.none) {
          await prefs.setInt(_savedFilterKey, previous.value);
        }
      }

      await _dnd.setInterruptionFilter(InterruptionFilter.none);
      return const FocusModeApplyResult(
        notificationsBlocked: true,
        needsPermission: false,
      );
    } catch (e) {
      debugPrint('FocusModeService enable DND error: $e');
      return const FocusModeApplyResult(
        notificationsBlocked: false,
        needsPermission: false,
        message: 'Mode Focus actif, mais le silence des notifications a échoué.',
      );
    }
  }

  static Future<void> disable() async {
    await _applyFullscreenUi(false);

    if (!Platform.isAndroid) return;

    final hasAccess = await _dnd.isNotificationPolicyAccessGranted();
    if (!hasAccess) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_savedFilterKey);
      if (saved != null) {
        final filter = InterruptionFilter.fromValue(saved);
        if (filter != InterruptionFilter.unknown) {
          await _dnd.setInterruptionFilter(filter);
        }
      } else {
        await _dnd.setInterruptionFilter(InterruptionFilter.all);
      }
      await prefs.remove(_savedFilterKey);
    } catch (e) {
      debugPrint('FocusModeService disable DND error: $e');
    }
  }

  static Future<bool> hasNotificationPermission() async {
    if (!Platform.isAndroid) return false;
    return _dnd.isNotificationPolicyAccessGranted();
  }

  static Future<void> openNotificationPermissionSettings() async {
    if (!Platform.isAndroid) return;
    await _dnd.openNotificationPolicyAccessSettings();
  }

  static Future<void> _applyFullscreenUi(bool enabled) async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (enabled) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        await windowManager.setFullScreen(enabled);
      } catch (e) {
        debugPrint('FocusModeService windowManager error: $e');
      }
    }
  }
}

class FocusModeApplyResult {
  final bool notificationsBlocked;
  final bool needsPermission;
  final String? message;

  const FocusModeApplyResult({
    required this.notificationsBlocked,
    required this.needsPermission,
    this.message,
  });
}
