import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import '../../core/models/score.dart';

class ResultatPage extends StatefulWidget {
  final Score score;

  const ResultatPage({super.key, required this.score});

  @override
  _ResultatPageState createState() => _ResultatPageState();
}

class _ResultatPageState extends State<ResultatPage> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    if (widget.score.pourcentage >= 80) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String mention;
    final Color mentionColor;
    if (widget.score.pourcentage >= 80) {
      mention = "Excellent !";
      mentionColor = Colors.green;
    } else if (widget.score.pourcentage >= 50) {
      mention = "Bien joué !";
      mentionColor = Colors.orange;
    } else {
      mention = "À revoir";
      mentionColor = Colors.red;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultats'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(mention, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: mentionColor)),
                  const SizedBox(height: 32),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: widget.score.pourcentage / 100),
                    duration: const Duration(seconds: 1),
                    builder: (context, value, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 150,
                            height: 150,
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 12,
                              backgroundColor: Colors.grey[800]?.withOpacity(0.1),
                              color: mentionColor,
                            ),
                          ),
                          Text(
                            "${widget.score.score}/${widget.score.total}",
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                          )
                        ],
                      );
                    }
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton.icon(
                    onPressed: () => context.pushReplacement('/exercice/${widget.score.matiereId}/${widget.score.notionId}/0'),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recommencer'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.menu_book),
                    label: const Text('Retour aux cours'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home),
                    label: const Text('Retour à l\'accueil'),
                  )
                ],
              ),
            ),
          )
        ],
      )
    );
  }
}
