import 'package:flutter/material.dart';
import '../services/tts_service.dart';

/// Bouton audio discret pour lire/arrêter la lecture TTS d'un message IA.
/// Paramètres :
///   [msgId]   — identifiant unique du message (ex. son index ou timestamp)
///   [text]    — contenu à lire
///   [isDark]  — thème courant
class TtsButton extends StatelessWidget {
  final String msgId;
  final String text;
  final bool isDark;

  const TtsButton({
    super.key,
    required this.msgId,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tts = TtsService.instance;

    return ValueListenableBuilder<String?>(
      valueListenable: tts.currentMsgId,
      builder: (_, currentId, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: tts.isSpeakingNotifier,
          builder: (_, isSpeaking, __) {
            final isThisMessage = currentId == msgId && isSpeaking;

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => tts.speak(text, msgId: msgId),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isThisMessage
                      ? Icon(
                          Icons.stop_circle_rounded,
                          key: const ValueKey('stop'),
                          size: 15,
                          color: Theme.of(context).primaryColor,
                        )
                      : Icon(
                          Icons.volume_up_rounded,
                          key: const ValueKey('play'),
                          size: 15,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
