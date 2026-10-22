import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Barre de saisie avec Speech-to-Text style Gemini.
///
/// Usage :
///   SpeechInputBar(
///     controller: _input,
///     isDark: isDark,
///     primary: primary,
///     isLoading: _isLoading,
///     onSend: (text) => _send(text),
///     onStop: _stop,
///   )
class SpeechInputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isDark;
  final Color primary;
  final bool isLoading;
  final void Function(String text) onSend;
  final VoidCallback onStop;
  final String hintText;
  final int? maxLines;

  const SpeechInputBar({
    super.key,
    required this.controller,
    required this.isDark,
    required this.primary,
    required this.isLoading,
    required this.onSend,
    required this.onStop,
    this.hintText = 'Pose ta question à Ngenou…',
    this.maxLines,
  });

  @override
  State<SpeechInputBar> createState() => _SpeechInputBarState();
}

class _SpeechInputBarState extends State<SpeechInputBar>
    with TickerProviderStateMixin {
  final SpeechToText _stt = SpeechToText();
  bool _sttAvailable = false;
  bool _isListening = false;
  String _spokenText = '';
  String _partialText = '';

  // Animation des ondes (style Gemini)
  late AnimationController _waveController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initStt();
  }

  Future<void> _initStt() async {
    final available = await _stt.initialize(
      onError: (e) {
        debugPrint('STT error: ${e.errorMsg}');
        if (mounted) _stopListening();
      },
      onStatus: (status) {
        debugPrint('STT status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted) _onSpeechDone();
        }
      },
    );
    if (mounted) setState(() => _sttAvailable = available);
  }

  Future<void> _startListening() async {
    if (!_sttAvailable || _isListening) return;
    setState(() {
      _isListening = true;
      _spokenText = '';
      _partialText = '';
    });
    _waveController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);

    await _stt.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            if (result.finalResult) {
              _spokenText = result.recognizedWords;
              _partialText = '';
            } else {
              _partialText = result.recognizedWords;
            }
          });
        }
      },
      localeId: 'fr_FR',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
      cancelOnError: true,
    );
  }

  void _stopListening() {
    _stt.stop();
    _waveController.stop();
    _pulseController.stop();
    if (mounted) setState(() => _isListening = false);
  }

  void _onSpeechDone() {
    _waveController.stop();
    _pulseController.stop();
    final recognized = _spokenText.isNotEmpty ? _spokenText : _partialText;
    if (mounted) {
      setState(() => _isListening = false);
      if (recognized.isNotEmpty) {
        widget.controller.text = recognized;
        widget.controller.selection = TextSelection.collapsed(
            offset: recognized.length);
      }
    }
  }

  void _cancelListening() {
    _stt.cancel();
    _waveController.stop();
    _pulseController.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _spokenText = '';
        _partialText = '';
      });
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _stt.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputBg = widget.isDark
        ? const Color(0xFF222222)
        : const Color(0xFFF3F4F6);

    // ── Mode écoute : overlay style Gemini ──────────────────────────────────
    if (_isListening) {
      return _buildListeningBar(inputBg);
    }

    // ── Mode normal ──────────────────────────────────────────────────────────
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.isDark ? Colors.grey[800]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: TextField(
              controller: widget.controller,
              maxLines: widget.maxLines,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: widget.isDark ? Colors.grey[500] : Colors.grey[500],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              onSubmitted: widget.isLoading ? null : widget.onSend,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Bouton micro (visible seulement si STT dispo et champ vide)
        if (_sttAvailable)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (_, value, __) {
              final empty = value.text.trim().isEmpty;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: empty && !widget.isLoading
                    ? GestureDetector(
                        key: const ValueKey('mic'),
                        onTap: _startListening,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.mic_rounded,
                            color: widget.isDark
                                ? Colors.white60
                                : Colors.black54,
                            size: 22,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('no_mic')),
              );
            },
          ),
        if (_sttAvailable) const SizedBox(width: 8),

        // Bouton envoyer / stop
        GestureDetector(
          onTap: widget.isLoading
              ? widget.onStop
              : () => widget.onSend(widget.controller.text),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  widget.isLoading ? Colors.red.shade400 : widget.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.isLoading
                  ? Icons.stop_rounded
                  : Icons.send_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  /// Barre d'écoute style Gemini
  Widget _buildListeningBar(Color inputBg) {
    final currentText = _partialText.isNotEmpty ? _partialText : _spokenText;
    final isEmpty = currentText.isEmpty;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: widget.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),

          // Ondes animées à gauche
          SizedBox(
            width: 36,
            height: 36,
            child: _SoundWaves(
              controller: _waveController,
              color: widget.primary,
            ),
          ),
          const SizedBox(width: 12),

          // Texte reconnu (ou placeholder pulsant)
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isEmpty
                  ? _PulsingDots(
                      key: const ValueKey('dots'),
                      color: widget.primary,
                    )
                  : Text(
                      currentText,
                      key: const ValueKey('text'),
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
          const SizedBox(width: 8),

          // Bouton annuler
          GestureDetector(
            onTap: _cancelListening,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: widget.isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Bouton envoyer (actif seulement si texte reconnu)
          GestureDetector(
            onTap: currentText.isNotEmpty
                ? () {
                    _stopListening();
                    widget.controller.text = currentText;
                    widget.controller.selection = TextSelection.collapsed(
                        offset: currentText.length);
                    Future.microtask(
                        () => widget.onSend(currentText));
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: currentText.isNotEmpty
                    ? widget.primary
                    : widget.primary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ondes sonores animées ─────────────────────────────────────────────────────

class _SoundWaves extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _SoundWaves({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(5, (i) {
            // Chaque barre a une phase différente pour l'effet de vague
            final phase = (controller.value + i * 0.2) % 1.0;
            final heightFactor = 0.3 + 0.7 * math.sin(phase * math.pi);
            return Container(
              width: 3,
              height: 28 * heightFactor,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.7 + 0.3 * heightFactor),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Points pulsants (état "en attente de parole") ─────────────────────────────

class _PulsingDots extends StatefulWidget {
  final Color color;
  const _PulsingDots({super.key, required this.color});

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i / 3.0;
          final phase = ((_ctrl.value + delay) % 1.0);
          final scale = 0.6 + 0.4 * math.sin(phase * math.pi);
          return Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: scale.clamp(0.3, 1.0)),
              shape: BoxShape.circle,
            ),
            transform: Matrix4.diagonal3Values(scale, scale, 1),
            transformAlignment: Alignment.center,
          );
        }),
      ),
    );
  }
}
