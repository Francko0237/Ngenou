/// Utilitaire pour manipuler, formater et parser les durées dans Ngenou.
class DurationUtils {
  /// Formate un nombre de minutes en chaîne lisible (ex: 90 -> "1h30", 45 -> "45 min", 120 -> "2h")
  static String format(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (remainder == 0) return '${hours}h';
    return '${hours}h${remainder.toString().padLeft(2, '0')}';
  }

  /// Décode de façon robuste une valeur dynamique (int ou String comme "1h30", "45min", "2 h", "90")
  /// et retourne le nombre de minutes sous forme d'entier.
  static int parse(dynamic value, {int defaultValue = 120}) {
    if (value == null) return defaultValue;
    if (value is num) return value.toInt();
    
    final str = value.toString().trim().toLowerCase();
    if (str.isEmpty) return defaultValue;

    // Reconnaît les chiffres suivis d'une unité facultative (h, min, m),
    // puis un éventuel second bloc de chiffres et de minutes.
    // Exemples : "1h30", "1h 30", "45min", "2 h", "90", "1 h 30 min"
    final regex = RegExp(r'^(\d+)\s*(h|min|m)?\s*(\d+)?\s*(min|m)?$');
    final match = regex.firstMatch(str);
    if (match != null) {
      final val1 = int.parse(match.group(1)!);
      final unit = match.group(2);
      final val2Str = match.group(3);

      if (unit == 'min' || unit == 'm') {
        return val1;
      } else if (unit == 'h') {
        final hours = val1;
        final minutes = val2Str != null ? int.tryParse(val2Str) ?? 0 : 0;
        return hours * 60 + minutes;
      } else {
        // Nombre brut sans unité, traité comme des minutes
        return val1;
      }
    }
    
    return int.tryParse(str) ?? defaultValue;
  }
}
