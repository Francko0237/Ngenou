import 'package:flutter/material.dart';
import '../../../core/models/daily_challenge.dart';

/// Widget interactif permettant à l'utilisateur de répondre à un défi QCM.
/// Affiche la question, les 4 options (A/B/C/D), valide la réponse avec retour
/// visuel coloré (vert = correct, rouge = incorrect), et affiche l'explication.
class QcmSolveWidget extends StatefulWidget {
  final DailyChallenge challenge;
  final int challengeIndex;
  final void Function(int optionIndex) onAnswer;
  final VoidCallback onNext;

  const QcmSolveWidget({
    super.key,
    required this.challenge,
    required this.challengeIndex,
    required this.onAnswer,
    required this.onNext,
  });

  @override
  State<QcmSolveWidget> createState() => _QcmSolveWidgetState();
}

class _QcmSolveWidgetState extends State<QcmSolveWidget>
    with TickerProviderStateMixin {
  int? _selectedIndex;
  bool _revealed = false;
  late AnimationController _revealCtrl;
  late Animation<double> _revealAnim;

  @override
  void initState() {
    super.initState();
    // Si déjà répondu (session rechargée), on affiche directement la correction.
    if (widget.challenge.userAnswerIndex != null) {
      _selectedIndex = widget.challenge.userAnswerIndex;
      _revealed = true;
    }
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _revealAnim = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOut);
    if (_revealed) _revealCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    super.dispose();
  }

  void _handleOptionTap(int index) {
    if (_revealed) return;
    setState(() {
      _selectedIndex = index;
      _revealed = true;
    });
    _revealCtrl.forward();
    widget.onAnswer(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final challenge = widget.challenge;
    final labels = ['A', 'B', 'C', 'D'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Matière tag ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            challenge.matiereNom,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── Question ────────────────────────────────────────────────────────
        Text(
          challenge.question,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),

        // ── Options ─────────────────────────────────────────────────────────
        ...List.generate(challenge.options.length, (i) {
          final isCorrect = i == challenge.bonneReponseIndex;
          final isSelected = i == _selectedIndex;

          Color? bgColor;
          Color borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
          Color labelColor = primary;
          Color textColor = isDark ? Colors.white70 : Colors.black87;

          if (_revealed) {
            if (isCorrect) {
              bgColor = Colors.green.withOpacity(0.15);
              borderColor = Colors.green;
              labelColor = Colors.green;
              textColor = isDark ? Colors.green[200]! : Colors.green[800]!;
            } else if (isSelected && !isCorrect) {
              bgColor = Colors.red.withOpacity(0.12);
              borderColor = Colors.red;
              labelColor = Colors.red;
              textColor = isDark ? Colors.red[200]! : Colors.red[800]!;
            }
          } else if (isSelected) {
            bgColor = primary.withOpacity(0.1);
            borderColor = primary;
          }

          return GestureDetector(
            onTap: () => _handleOptionTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: bgColor ?? (isDark ? const Color(0xFF2A2A2A) : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: labelColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: labelColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      challenge.options[i],
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: isCorrect && _revealed
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (_revealed && isCorrect)
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  if (_revealed && isSelected && !isCorrect)
                    const Icon(Icons.cancel, color: Colors.red, size: 20),
                ],
              ),
            ),
          );
        }),

        // ── Explication (animée à l'apparition) ─────────────────────────────
        FadeTransition(
          opacity: _revealAnim,
          child: _revealed
              ? Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blueGrey[900]!.withOpacity(0.6)
                        : Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.blueGrey[700]! : Colors.blue[200]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: isDark ? Colors.amber[300] : Colors.amber[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Explication',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        challenge.explication,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // ── Bouton Suivant ───────────────────────────────────────────────────
        if (_revealed) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'Défi suivant',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: widget.onNext,
            ),
          ),
        ],
      ],
    );
  }
}
