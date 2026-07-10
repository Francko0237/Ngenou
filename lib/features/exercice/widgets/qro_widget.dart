import 'package:flutter/material.dart';
import '../../../core/models/exercice.dart';

class QroWidget extends StatefulWidget {
  final Exercice exercice;
  final Function(bool) onValidate;

  const QroWidget({super.key, required this.exercice, required this.onValidate});

  @override
  State<QroWidget> createState() => _QroWidgetState();
}

class _QroWidgetState extends State<QroWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _hasValidated = false;
  bool _isCorrect = false;

  String get _expectedAnswer {
    if (widget.exercice.reponseAttendue != null &&
        widget.exercice.reponseAttendue!.isNotEmpty) {
      return widget.exercice.reponseAttendue!;
    }
    if (widget.exercice.options.isNotEmpty) {
      return widget.exercice.options.first;
    }
    return '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        TextField(
          controller: _controller,
          enabled: !_hasValidated,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Saisissez votre réponse ici...',
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
        const Spacer(),
        if (_hasValidated) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isCorrect
                  ? Colors.green.withOpacity(isDark ? 0.15 : 0.08)
                  : Colors.red.withOpacity(isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isCorrect ? Colors.green : Colors.redAccent,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: _isCorrect ? Colors.green : Colors.redAccent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCorrect ? 'Excellent travail !' : 'Oups, ce n\'est pas tout à fait ça...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isCorrect ? Colors.green : Colors.redAccent,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          text: 'Réponse attendue : ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: _expectedAnswer,
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.exercice.explication != null && widget.exercice.explication!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.exercice.explication!,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _controller.text.trim().isEmpty && !_hasValidated
                ? null
                : () {
                    if (!_hasValidated) {
                      setState(() {
                        _hasValidated = true;
                        final typed = _controller.text.toLowerCase().trim();
                        final expected = _expectedAnswer.toLowerCase();
                        if (expected.contains('non applicable')) {
                          _isCorrect = true;
                        } else {
                          final firstWord = expected.split(' ').first;
                          _isCorrect =
                              typed.contains(firstWord) || typed == expected;
                        }
                      });
                    } else {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        widget.onValidate(_isCorrect);
                      });
                    }
                  },
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
              elevation: _controller.text.trim().isEmpty && !_hasValidated ? 0 : 2,
            ),
          ),
        ),
      ],
    );
  }
}
