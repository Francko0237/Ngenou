import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/study_task.dart';
import '../../../modules/modules_registry.dart';

// ─── Widget principal ────────────────────────────────────────────────────────

class TaskAlarmDialog extends StatefulWidget {
  final StudyTask task;

  const TaskAlarmDialog({super.key, required this.task});

  static Future<void> show(BuildContext context, StudyTask task) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TaskAlarmDialog(task: task),
    );
  }

  @override
  State<TaskAlarmDialog> createState() => _TaskAlarmDialogState();
}

class _TaskAlarmDialogState extends State<TaskAlarmDialog>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _volumeTimer;
  Timer? _tickTimer; // 1 tick/s — pilote volume ET vibration
  double _currentVolume = 0.15;
  int _elapsedSecs = 0;
  bool _stopped = false; // garde-fou pour les Future.delayed en vol

  // Animation pour le pulsating du titre
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Pulsating animation sur l'icône alarme
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Démarre le son + vibration
    _startAlarm();
  }

  Future<void> _startAlarm() async {
    // ── Son ────────────────────────────────────────────────────────────────
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundName = prefs.getString('alarmSound') ?? 'alarm_classic';

      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      // Force le stream ALARM sur Android (STREAM_ALARM = 4).
      // Sans ça, audioplayers joue sur STREAM_MUSIC et le son peut être
      // inaudible si le volume musique est bas, même avec usage: alarm dans
      // l'audio session.
      if (Platform.isAndroid) {
        await _audioPlayer.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              audioFocus: AndroidAudioFocus.gain,
              isSpeakerphoneOn: false,
              stayAwake: true,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.alarm,
              audioMode: AndroidAudioMode.normal,
            ),
          ),
        );
      }

      // Crescendo : démarre à 30% et monte jusqu'à 100%
      _currentVolume = 0.30;
      await _audioPlayer.setVolume(_currentVolume);

      if (soundName == 'system' || soundName == 'alarm_classic') {
        // Son par défaut (system = pas de fichier custom, on utilise alarm_classic)
        await _audioPlayer.play(AssetSource('audio/alarm_classic.wav'));
      } else if (soundName.startsWith('/') || soundName.startsWith('file://')) {
        // Fichier audio personnalisé
        final filePath = soundName.startsWith('file://')
            ? Uri.parse(soundName).toFilePath()
            : soundName;
        final file = File(filePath);
        if (await file.exists()) {
          await _audioPlayer.play(DeviceFileSource(filePath));
        } else {
          debugPrint(
            'Custom alarm sound not found: $filePath, falling back to default',
          );
          await _audioPlayer.play(AssetSource('audio/alarm_classic.wav'));
        }
      } else {
        // Son intégré (alarm_digital, alarm_gentle, etc.)
        await _audioPlayer.play(AssetSource('audio/$soundName.wav'));
      }

      // Crescendo : +15% toutes les 3 s jusqu'à 100%
      _volumeTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
        if (!mounted) return;
        if (_currentVolume < 1.0) {
          _currentVolume = (_currentVolume + 0.15).clamp(0.0, 1.0);
          await _audioPlayer.setVolume(_currentVolume);
        } else {
          _volumeTimer?.cancel();
        }
      });
    } catch (e) {
      debugPrint('AlarmDialog sound error: $e');
    }

    // ── Vibration crescendo ────────────────────────────────────────────────
    // Utilise HapticFeedback + vibration native Android en fallback.
    // HapticFeedback peut être muet si le téléphone est en silencieux total.
    HapticFeedback.lightImpact();

    _tickTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted || _stopped) return;
      _elapsedSecs++;

      if (_elapsedSecs < 10) {
        if (_elapsedSecs % 4 == 0) {
          HapticFeedback.lightImpact();
          _vibrateNative(100);
        }
      } else if (_elapsedSecs < 20) {
        if (_elapsedSecs % 2 == 0) {
          HapticFeedback.mediumImpact();
          _vibrateNative(300);
        }
      } else if (_elapsedSecs < 30) {
        HapticFeedback.heavyImpact();
        _vibrateNative(500);
      } else {
        HapticFeedback.heavyImpact();
        _vibrateNative(700);
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted && !_stopped) {
            HapticFeedback.heavyImpact();
            _vibrateNative(300);
          }
        });
      }
    });
  }

  void _stopAlarm() {
    _stopped = true;
    _volumeTimer?.cancel();
    _tickTimer?.cancel();
    _volumeTimer = null;
    _tickTimer = null;
    _audioPlayer.stop();
    _audioPlayer.dispose();
  }

  /// Vibration native via Kotlin VibrationEffect — bypass le mode sonore.
  void _vibrateNative(int durationMs) {
    if (!Platform.isAndroid) return;
    try {
      const MethodChannel(
        'com.ngenou.app/sdk_version',
      ).invokeMethod<void>('triggerVibration', durationMs);
    } catch (_) {
      // Fallback HapticFeedback si le channel échoue
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _stopAlarm();
    super.dispose();
  }

  // ─── Construction du dialog ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final time =
        '${widget.task.scheduledAt.hour.toString().padLeft(2, '0')}:${widget.task.scheduledAt.minute.toString().padLeft(2, '0')}';

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icône animée ──────────────────────────────────────────────
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primary.withValues(alpha: 0.3),
                        primary.withValues(alpha: 0.0),
                      ],
                    ),
                    border: Border.all(color: primary, width: 2.5),
                  ),
                  child: Icon(Icons.alarm_rounded, color: primary, size: 40),
                ),
              ),
              const SizedBox(height: 20),

              // ── Titre ─────────────────────────────────────────────────────
              Text(
                'Heure de réviser !',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // ── Matière ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.task.matiereNom,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),

              // ── Créneau ───────────────────────────────────────────────────
              Text(
                '$time · ${widget.task.durationMinutes} min',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'La tâche reste en attente tant que vous ne l\'avez pas cochée.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // ── Actions ───────────────────────────────────────────────────
              Row(
                children: [
                  // Annuler
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'dismiss'),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 4),
                  // +5 min
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, 'snooze'),
                    icon: const Icon(Icons.snooze_rounded, size: 16),
                    label: const Text('+5 min'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primary.withValues(alpha: 0.6)),
                    ),
                  ),
                  const Spacer(),
                  // Aller réviser
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, 'revise'),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: const Text('Réviser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers (inchangés) ─────────────────────────────────────────────────────

void handleTaskAlarmAction(
  BuildContext context,
  StudyTask task,
  String action,
) {
  switch (action) {
    case 'revise':
      _navigateToTaskCourseFromDialog(context, task);
      break;
    case 'snooze':
    case 'dismiss':
    case 'cancel':
    case 'manage':
      break;
  }
}

/// Navigue vers le cours de la tâche si le module existe,
/// sinon affiche un dialog de sélection de cours.
Future<void> _navigateToTaskCourseFromDialog(
  BuildContext context,
  StudyTask task,
) async {
  const noCoursIds = {'manual', 'life_rhythm', ''};
  final matiereId = task.matiereId;

  final hasModule =
      !noCoursIds.contains(matiereId) &&
      ModulesRegistry.getNotions(matiereId).isNotEmpty;

  if (hasModule) {
    context.push('/cours/$matiereId');
    return;
  }

  final allMatieres = ModulesRegistry.matieres;
  if (allMatieres.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aucun cours disponible. Importez un cours d\'abord.'),
        duration: Duration(seconds: 3),
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Choisir un cours à réviser'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: allMatieres.length,
          itemBuilder: (_, i) {
            final m = allMatieres[i];
            return ListTile(
              leading: const Icon(Icons.menu_book_rounded),
              title: Text(m.nom),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/cours/${m.id}');
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
      ],
    ),
  );
}

Future<String?> showTaskAlarmDialog(
  BuildContext context,
  StudyTask task,
) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TaskAlarmDialog(task: task),
  );
}
