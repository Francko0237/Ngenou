import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/focus_mode_service.dart';
import '../services/schedule_notification_service.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isFocusMode = false;
  bool _notificationsSilenced = false;
  String _alarmSound = 'alarm_classic';

  ThemeMode get themeMode => _themeMode;
  bool get isFocusMode => _isFocusMode;
  bool get notificationsSilenced => _notificationsSilenced;
  String get alarmSound => _alarmSound;

  /// Compatibilité ascendante (ancien nom).
  bool get isImmersiveMode => _isFocusMode;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _alarmSound = prefs.getString('alarmSound') ?? 'alarm_classic';
    final themeStr = prefs.getString('themeMode');
    if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    _isFocusMode =
        prefs.getBool('focusMode') ?? prefs.getBool('immersiveMode') ?? false;
    if (_isFocusMode) {
      final result = await FocusModeService.enable();
      _notificationsSilenced = result.notificationsBlocked;
    }

    notifyListeners();
  }

  Future<void> toggleTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    notifyListeners();
  }

  Future<FocusModeApplyResult> toggleFocusMode(bool enabled) async {
    _isFocusMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('focusMode', enabled);
    await prefs.remove('immersiveMode');

    FocusModeApplyResult result;
    if (enabled) {
      result = await FocusModeService.enable();
      _notificationsSilenced = result.notificationsBlocked;
    } else {
      await FocusModeService.disable();
      _notificationsSilenced = false;
      result = const FocusModeApplyResult(
        notificationsBlocked: false,
        needsPermission: false,
      );
    }

    notifyListeners();
    return result;
  }

  /// Réapplique le silence des notifications si le mode Focus est actif
  /// (ex. après retour des paramètres Android).
  Future<void> refreshNotificationSilence() async {
    if (!_isFocusMode) return;
    final result = await FocusModeService.enable();
    _notificationsSilenced = result.notificationsBlocked;
    notifyListeners();
  }

  /// Compatibilité ascendante (ancien nom).
  Future<FocusModeApplyResult> toggleImmersiveMode(bool enabled) =>
      toggleFocusMode(enabled);

  Future<void> setAlarmSound(String sound) async {
    _alarmSound = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarmSound', sound);

    // Incrémente la version du son pour forcer un ID de canal unique
    final currentVer = prefs.getInt('alarmSoundVersion') ?? 0;
    await prefs.setInt('alarmSoundVersion', currentVer + 1);

    // Notifie le service de notification du changement de son
    if (!kIsWeb) {
      try {
        await ScheduleNotificationService.onSoundChanged(sound);
      } catch (_) {}
    }
    notifyListeners();
  }
}
