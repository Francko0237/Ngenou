import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service TTS singleton multiplateforme :
/// - Android / iOS / Windows : moteur natif via `flutter_tts`
/// - Linux (Ubuntu / Fedora) : `spd-say` (speech-dispatcher) avec fallback `espeak-ng` / `espeak`
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();

  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier(false);
  final ValueNotifier<String?> currentMsgId = ValueNotifier(null);

  bool _initialized = false;
  Process? _linuxProcess;

  bool get _useLinuxCli => !kIsWeb && Platform.isLinux;

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    if (_useLinuxCli) return;

    await _tts.setLanguage('fr-FR');
    // Sur Windows (SAPI), 1.0 est nettement plus rapide qu'Android : 0.6 offre
    // un débit naturel confortable.
    await _tts.setSpeechRate(!kIsWeb && Platform.isWindows ? 0.6 : 1.0);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _tts.setEngine('com.google.android.tts');
      } catch (_) {}
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

  Future<void> speak(String text, {required String msgId}) async {
    await _init();

    if (currentMsgId.value == msgId && isSpeakingNotifier.value) {
      await stop();
      return;
    }

    if (isSpeakingNotifier.value) await stop();

    currentMsgId.value = msgId;
    isSpeakingNotifier.value = true;

    final clean = _cleanForSpeech(text);
    if (clean.isEmpty) {
      isSpeakingNotifier.value = false;
      currentMsgId.value = null;
      return;
    }

    if (_useLinuxCli) {
      await _speakLinux(clean, msgId);
      return;
    }

    await _tts.speak(clean);
  }

  Future<void> _speakLinux(String cleanText, String msgId) async {
    final candidates = <({String cmd, List<String> args})>[
      (cmd: 'spd-say', args: ['-l', 'fr', '-r', '-10', '-w', cleanText]),
      (cmd: 'espeak-ng', args: ['-v', 'fr', '-s', '145', cleanText]),
      (cmd: 'espeak', args: ['-v', 'fr', '-s', '145', cleanText]),
    ];

    for (final c in candidates) {
      try {
        final proc = await Process.start(c.cmd, c.args);
        _linuxProcess = proc;
        final exitCode = await proc.exitCode;
        if (identical(_linuxProcess, proc)) {
          _linuxProcess = null;
          if (currentMsgId.value == msgId) {
            isSpeakingNotifier.value = false;
            currentMsgId.value = null;
          }
        }
        if (exitCode == 0 || exitCode < 0) return;
      } catch (_) {
        // Binaire absent, on tente le suivant
      }
    }

    isSpeakingNotifier.value = false;
    currentMsgId.value = null;
  }

  Future<void> stop() async {
    if (_useLinuxCli) {
      final proc = _linuxProcess;
      _linuxProcess = null;
      proc?.kill();
      try {
        await Process.run('spd-say', ['-C']);
      } catch (_) {}
      isSpeakingNotifier.value = false;
      currentMsgId.value = null;
      return;
    }

    try {
      await _tts.stop();
    } catch (_) {}
    isSpeakingNotifier.value = false;
    currentMsgId.value = null;
  }

  /// Nettoie le texte pour une lecture naturelle :
  /// - Supprime les emojis (range Unicode standard + supplementary)
  /// - Supprime les marqueurs markdown en gardant uniquement le texte
  /// - Normalise la ponctuation et les sauts de ligne
  String _cleanForSpeech(String text) {
    var s = text;

    // 1. Blocs de code (``` ... ```) — on les supprime entièrement
    //    (le contenu technique n'est pas lisible à voix haute)
    s = s.replaceAll(RegExp(r'```[\s\S]*?```'), '.');

    // 2. Code inline (`...`) — supprimé
    s = s.replaceAll(RegExp(r'`[^`]+`'), '');

    // 3. Titres markdown (# Titre → "Titre")
    s = s.replaceAllMapped(
      RegExp(r'^#{1,6}\s+(.+)$', multiLine: true),
      (m) => '${m.group(1)}.',
    );

    // 4. Gras et italique (**texte** → "texte", *texte* → "texte")
    //    Utilisation de replaceAllMapped pour les backreferences
    s = s.replaceAllMapped(
      RegExp(r'\*\*\*(.+?)\*\*\*'),
      (m) => m.group(1) ?? '',
    );
    s = s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(RegExp(r'_(.+?)_'), (m) => m.group(1) ?? '');

    // 5. Liens markdown ([texte](url) → "texte")
    s = s.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1) ?? '',
    );

    // 6. Images markdown (![alt](url) → supprimé)
    s = s.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '');

    // 7. Citations (> texte → texte)
    s = s.replaceAllMapped(
      RegExp(r'^>\s+(.*)$', multiLine: true),
      (m) => m.group(1) ?? '',
    );

    // 8. Listes (- item / * item / 1. item → "item,")
    s = s.replaceAllMapped(
      RegExp(r'^\s*[-*+]\s+(.+)$', multiLine: true),
      (m) => '${m.group(1)},',
    );
    s = s.replaceAllMapped(
      RegExp(r'^\s*\d+\.\s+(.+)$', multiLine: true),
      (m) => '${m.group(1)},',
    );

    // 9. Tableaux markdown — supprimés
    s = s.replaceAll(RegExp(r'^\|.*\|$', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^[-|: ]+$', multiLine: true), '');

    // 10. Séparateurs horizontaux (--- / ***)
    s = s.replaceAll(RegExp(r'^[-*_]{3,}$', multiLine: true), '.');

    // 11. Emojis — on les supprime entièrement pour éviter "coeur", "feu" etc.
    //     Couvre les blocs Unicode emoji principaux
    s = s.replaceAll(
      RegExp(
        r'[\u{1F300}-\u{1FAFF}' // Misc symbols, dingbats, transport, faces
        r'\u{2600}-\u{26FF}' // Misc symbols
        r'\u{2700}-\u{27BF}' // Dingbats
        r'\u{FE00}-\u{FE0F}' // Variation selectors
        r'\u{1F900}-\u{1F9FF}' // Supplemental symbols
        r'\u{1FA00}-\u{1FA6F}' // Chess symbols etc
        r'\u{200D}' // Zero-width joiner
        r'\u{20E3}' // Combining enclosing keycap
        r']+',
        unicode: true,
      ),
      ' ',
    );

    // 12. Caractères spéciaux isolés résiduels (|, ~, ^, =)
    s = s.replaceAll(RegExp(r'[|~^=]{2,}'), '');
    s = s.replaceAll('~~', '');
    s = s.replaceAll('==', '');

    // 13. Normalisation des sauts de ligne
    //     Paragraphe double → pause (point)
    s = s.replaceAll(RegExp(r'\n{2,}'), '. ');
    //     Saut simple → espace
    s = s.replaceAll('\n', ' ');

    // 14. Espaces multiples → un seul
    s = s.replaceAll(RegExp(r'  +'), ' ');

    // 15. Points répétés (ex: ".. .") → un seul
    s = s.replaceAll(RegExp(r'\.{2,}'), '.');
    s = s.replaceAll(RegExp(r'\.\s+\.'), '.');

    return s.trim();
  }
}
