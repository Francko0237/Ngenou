import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service TTS singleton qui utilise le moteur natif Android.
/// Appelle [speak] pour lire un texte, [stop] pour arrêter.
/// Écoute [isSpeakingNotifier] pour l'état en cours.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();

  /// Notifier réactif : true = lecture en cours
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier(false);

  /// Identifiant du message en cours de lecture (null si aucun)
  final ValueNotifier<String?> currentMsgId = ValueNotifier(null);

  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.52);   // légèrement plus lent que défaut pour clarté
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Sur Android : préférer le moteur Google TTS natif si disponible
    if (!kIsWeb) {
      try {
        await _tts.setEngine('com.google.android.tts');
      } catch (_) {
        // Moteur par défaut si Google TTS absent
      }
    }

    _tts.setStartHandler(() {
      isSpeakingNotifier.value = true;
    });
    _tts.setCompletionHandler(() {
      isSpeakingNotifier.value = false;
      currentMsgId.value = null;
    });
    _tts.setCancelHandler(() {
      isSpeakingNotifier.value = false;
      currentMsgId.value = null;
    });
    _tts.setErrorHandler((_) {
      isSpeakingNotifier.value = false;
      currentMsgId.value = null;
    });
  }

  /// Lit [text] à voix haute. [msgId] identifie le message pour l'UI.
  /// Si le même message est déjà en lecture, coupe la lecture (toggle).
  Future<void> speak(String text, {required String msgId}) async {
    await _init();

    // Toggle : si ce message est déjà en cours, on coupe
    if (currentMsgId.value == msgId && isSpeakingNotifier.value) {
      await stop();
      return;
    }

    // Arrêt d'une lecture précédente avant d'en démarrer une nouvelle
    if (isSpeakingNotifier.value) await _tts.stop();

    currentMsgId.value = msgId;
    isSpeakingNotifier.value = true;

    // Nettoyage du markdown avant lecture (supprime ** # ` etc.)
    final clean = _stripMarkdown(text);
    await _tts.speak(clean);
  }

  Future<void> stop() async {
    await _tts.stop();
    isSpeakingNotifier.value = false;
    currentMsgId.value = null;
  }

  /// Supprime les marqueurs markdown courants pour une lecture plus naturelle
  String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')   // gras
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')        // italique
        .replaceAll(RegExp(r'`{1,3}[^`]*`{1,3}'), '')  // code inline/bloc
        .replaceAll(RegExp(r'#{1,6}\s'), '')             // titres
        .replaceAll(RegExp(r'\[(.+?)\]\(.+?\)'), r'$1') // liens
        .replaceAll(RegExp(r'>\s'), '')                  // citations
        .replaceAll(RegExp(r'[-*+]\s'), '')              // listes
        .replaceAll(RegExp(r'\n{2,}'), '. ')             // sauts de paragraphe
        .replaceAll('\n', ' ')
        .trim();
  }
}
