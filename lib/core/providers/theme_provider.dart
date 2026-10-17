import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/focus_mode_service.dart';
import '../services/schedule_notification_service.dart';

/// Couleurs d'accent disponibles dans le sélecteur de thème.
class AppAccentColors {
  static const List<_AccentOption> options = [
    _AccentOption('Violet',  Color(0xFF6C63FF), Color(0xFF8B82FF)),
    _AccentOption('Bleu',    Color(0xFF4A90D9), Color(0xFF64A9F0)),
    _AccentOption('Indigo',  Color(0xFF3F51B5), Color(0xFF5C6BC0)),
    _AccentOption('Vert',    Color(0xFF27AE60), Color(0xFF2ECC71)),
    _AccentOption('Rose',    Color(0xFFE91E8B), Color(0xFFF06292)),
    _AccentOption('Orange',  Color(0xFFE67E22), Color(0xFFFF9800)),
    _AccentOption('Rouge',   Color(0xFFE74C3C), Color(0xFFEF5350)),
    _AccentOption('Cyan',    Color(0xFF00BCD4), Color(0xFF26C6DA)),
  ];

  static Color defaultLight = options[1].light; // Bleu
  static Color defaultDark  = options[0].dark;  // Violet
}

class _AccentOption {
  final String label;
  final Color light;
  final Color dark;
  const _AccentOption(this.label, this.light, this.dark);
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isFocusMode = false;
  bool _notificationsSilenced = false;
  String _alarmSound = 'alarm_classic';
  Color _accentLight = AppAccentColors.defaultLight;
  Color _accentDark  = AppAccentColors.defaultDark;

  ThemeMode get themeMode => _themeMode;
  bool get isFocusMode => _isFocusMode;
  bool get notificationsSilenced => _notificationsSilenced;
  String get alarmSound => _alarmSound;
  Color get accentLight => _accentLight;
  Color get accentDark  => _accentDark;

  /// Couleur active selon le brightness actuel du système / choix utilisateur.
  Color accentFor(Brightness brightness) =>
      brightness == Brightness.dark ? _accentDark : _accentLight;

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

    // Restaure la couleur d'accent
    final lightHex = prefs.getInt('accentLight');
    final darkHex  = prefs.getInt('accentDark');
    if (lightHex != null) _accentLight = Color(lightHex);
    if (darkHex  != null) _accentDark  = Color(darkHex);

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

  /// Change la couleur d'accent pour les deux modes (light et dark).
  Future<void> setAccentColor(Color lightColor, Color darkColor) async {
    _accentLight = lightColor;
    _accentDark  = darkColor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentLight', lightColor.value);
    await prefs.setInt('accentDark',  darkColor.value);
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
