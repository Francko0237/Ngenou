import 'package:flutter/material.dart';
import '../../../core/models/exercice.dart';

class QcmWidget extends StatefulWidget {
  final Exercice exercice;
  final Function(bool) onValidate;

  const QcmWidget({super.key, required this.exercice, required this.onValidate});

  @override
  State<QcmWidget> createState() => _QcmWidgetState();
}

class _QcmWidgetState extends State<QcmWidget> {
  int? _selectedIndex;
  bool _hasValidated = false;

  @override
  void didUpdateWidget(QcmWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercice.id != widget.exercice.id) {
      _selectedIndex = null;
      _hasValidated = false;
    }
  }

  void _onPressed() {
    if (_selectedIndex == null) return;
    if (!_hasValidated) {
      setState(() => _hasValidated = true);
      return;
    }
    // Évite que le relâchement du tap sur « Continuer » touche le QCM suivant.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onValidate(_selectedIndex == widget.exercice.bonneReponseIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.exercice.options;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.exercice.question,
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(options.length, (index) {
          final choix = options[index];
          final isCorrect = index == widget.exercice.bonneReponseIndex;
          final isSelected = _selectedIndex == index;

          Color cardBgColor = Colors.transparent;
          Color borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
          Color prefixBgColor = isDark ? const Color(0xFF2E2E2E) : Colors.grey[200]!;
          Color prefixTextColor = isDark ? Colors.grey[300]! : Colors.grey[700]!;
          Widget? suffixIcon;

          if (_hasValidated) {
            if (isCorrect) {
              cardBgColor = Colors.green.withOpacity(isDark ? 0.15 : 0.08);
              borderColor = Colors.green;
              prefixBgColor = Colors.green;
              prefixTextColor = Colors.white;
              suffixIcon = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22);
            } else if (isSelected && !isCorrect) {
              cardBgColor = Colors.red.withOpacity(isDark ? 0.15 : 0.08);
              borderColor = Colors.redAccent;
              prefixBgColor = Colors.redAccent;
              prefixTextColor = Colors.white;
              suffixIcon = const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 22);
            }
          } else if (isSelected) {
            cardBgColor = Theme.of(context).primaryColor.withOpacity(isDark ? 0.15 : 0.08);
            borderColor = Theme.of(context).primaryColor;
            prefixBgColor = Theme.of(context).primaryColor;
            prefixTextColor = Colors.white;
          }

          final prefixLetter = String.fromCharCode(65 + index); // A, B, C, D...

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: InkWell(
              onTap: _hasValidated
                  ? null
                  : () => setState(() => _selectedIndex = index),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardBgColor.value == 0 ? (isDark ? const Color(0xFF1E1E1E) : Colors.white) : cardBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected || (_hasValidated && isCorrect) ? 2 : 1,
                  ),
                  boxShadow: [
                    if (isSelected && !_hasValidated)
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: prefixBgColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        prefixLetter,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: prefixTextColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        choix,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    if (suffixIcon != null) ...[
                      const SizedBox(width: 8),
                      suffixIcon,
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
        const Spacer(),
        if (_hasValidated && widget.exercice.explication != null && widget.exercice.explication!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(isDark ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Explication",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.exercice.explication!,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _selectedIndex == null ? null : _onPressed,
            icon: Icon(_hasValidated ? Icons.arrow_forward_rounded : Icons.check_circle_outline_rounded),
            label: Text(
              _hasValidated ? 'Continuer' : 'Valider la réponse',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark ? Colors.grey[850] : Colors.grey[200],
              disabledForegroundColor: Colors.grey[500],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: _selectedIndex == null ? 0 : 2,
            ),
          ),
        ),
      ],
    );
  }
}
