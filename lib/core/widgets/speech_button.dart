import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Bouton microphone réutilisable avec animation de pulsation.
/// Appelle [onResult] quand une phrase est reconnue.
/// Appelle [onPartialResult] à chaque mot reconnu (optionnel, pour affichage live).
class SpeechButton extends StatefulWidget {
  final void Function(String text) onResult;
  final void Function(String partial)? onPartialResult;
  final Color primary;
  final bool isDark;
  final double size;

  const SpeechButton({
    super.key,
    required this.onResult,
    required this.primary,
    required this.isDark,
    this.onPartialResult,
    this.size = 36,
  });

  @override
  State<SpeechButton> createState() => _SpeechButtonState();
}

class _SpeechButtonState extends State<SpeechButton>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _available = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (_) => _stopListening(),
      onStatus: (status) {
        if (status == stt.SpeechToText.doneStatus ||
            status == stt.SpeechToText.notListeningStatus) {
          if (mounted && _isListening) _stopListening();
        }
      },
    );
    if (mounted) setState(() => _available = available);
  }

  Future<void> _toggle() async {
    if (!_available) {
      // Tentative de re-init si pas disponible
      await _initSpeech();
      if (!_available) {
        _showUnavailableSnack();
        return;
      }
    }

    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    setState(() => _isListening = true);
    _pulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final text = result.recognizedWords.trim();
        if (result.finalResult && text.isNotEmpty) {
          widget.onResult(text);
          _stopListening();
        } else if (!result.finalResult && text.isNotEmpty) {
          widget.onPartialResult?.call(text);
        }
      },
      localeId: 'fr_FR',
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 60),
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _showUnavailableSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'La reconnaissance vocale n\'est pas disponible sur cet appareil.',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    if (_isListening) {
      return GestureDetector(
        onTap: _toggle,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            width: s * _pulseAnim.value,
            height: s * _pulseAnim.value,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.mic_rounded,
              color: Colors.red,
              size: s * 0.48,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mic_none_rounded,
          color: widget.isDark ? Colors.white54 : Colors.black45,
          size: s * 0.50,
        ),
      ),
    );
  }
}
