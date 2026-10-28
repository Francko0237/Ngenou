import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/custom_courses_provider.dart';
import '../../core/providers/defis_provider.dart';
import '../../core/providers/progression_provider.dart';
import '../../core/providers/projets_provider.dart';
import '../../core/providers/schedule_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/teacher_courses_service.dart';

/// Vérifie si la synchronisation initiale bloquante doit être affichée pour l'utilisateur actuel.
Future<bool> shouldShowInitialSync() async {
  if (!AuthService.isAuthenticated) return false;
  final user = AuthService.currentUser;
  if (user == null) return false;
  final prefs = await SharedPreferences.getInstance();
  final key = 'ngenou_initial_sync_done_${user.id}';
  return !(prefs.getBool(key) ?? false);
}

/// Marque la synchronisation initiale comme effectuée avec succès pour cet utilisateur.
Future<void> markInitialSyncDone() async {
  final user = AuthService.currentUser;
  if (user == null) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('ngenou_initial_sync_done_${user.id}', true);
}

/// Réinitialise l'état de synchronisation initiale (ex. à la déconnexion ou pour un test).
Future<void> resetInitialSync([String? userId]) async {
  final prefs = await SharedPreferences.getInstance();
  final uid = userId ?? AuthService.currentUser?.id;
  if (uid != null) {
    await prefs.remove('ngenou_initial_sync_done_$uid');
  }
}

/// Écran de séquestration bloquant pendant la synchronisation initiale.
/// Empêche l'accès à l'application tant que les données du compte n'ont pas été
/// rapatriées depuis le cloud Supabase vers la base locale SQLite.
class InitialSyncOverlay extends StatefulWidget {
  final Future<void> Function()? onDone;

  const InitialSyncOverlay({super.key, this.onDone});

  @override
  State<InitialSyncOverlay> createState() => _InitialSyncOverlayState();
}

class _InitialSyncOverlayState extends State<InitialSyncOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  int _currentStep = 0;
  String _statusMessage = 'Connexion à votre compte cloud...';
  bool _canSkipOffline = false;
  Timer? _offlineTimer;
  Timer? _stepTimer;
  bool _isCompleted = false;

  final List<String> _steps = [
    'Connexion sécurisée à Supabase',
    'Récupération de vos cours & projets',
    'Synchronisation de vos progressions & scores',
    'Restauration de vos messages & discussions',
    'Finalisation de votre espace personnel',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Après 8 secondes, permettre de continuer hors-ligne si le réseau est lent
    _offlineTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_isCompleted) {
        setState(() => _canSkipOffline = true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInitialSync();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _offlineTimer?.cancel();
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<void> _startInitialSync() async {
    try {
      _advanceStep(0, 'Connexion à votre compte Supabase...');

      _stepTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted && !_isCompleted) {
          _advanceStep(1, 'Téléchargement de vos cours & projets...');
        }
      });

      // Lancement de la synchronisation complète
      await SyncService.instance.syncAll().timeout(
        const Duration(seconds: 25),
        onTimeout: () => debugPrint('Initial sync timeout — poursuite'),
      );

      if (!mounted) return;
      _advanceStep(2, 'Mise à jour des progressions & défis...');
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;
      _advanceStep(3, 'Restauration des messages & tâches...');

      // Rechargement immédiat des providers avec les données fraîches
      if (mounted) {
        try {
          await TeacherCoursesService.syncPublicCourseIds();
          if (mounted) await context.read<CustomCoursesProvider>().loadCustomCourses();
          if (mounted) await context.read<ProjetsProvider>().loadProjets();
          if (mounted) await context.read<ScheduleProvider>().load();
          if (mounted) context.read<ScheduleProvider>().rescheduleAllTasks();
          if (mounted) await context.read<ProgressionProvider>().loadAllProgressions();
          if (mounted) await context.read<DefisProvider>().loadTodaySession();
        } catch (e) {
          debugPrint('Erreur reload providers sync : $e');
        }
      }

      if (!mounted) return;
      _advanceStep(4, 'Votre espace est prêt !');
      await Future.delayed(const Duration(milliseconds: 600));

      // Marquer la sync initiale comme achevée
      await markInitialSyncDone();

      if (mounted) {
        setState(() => _isCompleted = true);
        await Future.delayed(const Duration(milliseconds: 300));
        if (widget.onDone != null) {
          await widget.onDone!();
        }
      }
    } catch (e) {
      debugPrint('Erreur dans _startInitialSync : $e');
      if (mounted) {
        setState(() => _canSkipOffline = true);
      }
    }
  }

  void _advanceStep(int stepIndex, String message) {
    if (mounted) {
      setState(() {
        _currentStep = stepIndex;
        _statusMessage = message;
      });
    }
  }

  Future<void> _skipOffline() async {
    await markInitialSyncDone();
    if (widget.onDone != null) {
      await widget.onDone!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final bgColor = isDark ? const Color(0xFF0C0D14) : const Color(0xFFF6F8FC);
    final cardBg = isDark ? const Color(0xFF161822) : Colors.white;

    return PopScope(
      canPop: false, // Bloquer le bouton retour physique pendant la synchronisation
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Halo & Icône animée ──────────────────────────────────
                    ScaleTransition(
                      scale: _pulseScale,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              primary,
                              primary.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.35),
                              blurRadius: 28,
                              spreadRadius: 4,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.cloud_sync_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Titre & Explication ──────────────────────────────────
                    Text(
                      _isCompleted ? 'Synchronisation réussie !' : 'Synchronisation de votre compte',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : const Color(0xFF14151F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Veuillez patienter quelques instants pendant que nous rapatrions vos données pour configurer votre appareil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Carte des étapes ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _statusMessage,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (_currentStep + 1) / _steps.length,
                              minHeight: 6,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _isCompleted ? const Color(0xFF2ECC71) : primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Divider(height: 1),
                          const SizedBox(height: 14),

                          // Liste des étapes avec check
                          ...List.generate(_steps.length, (index) {
                            final isDone = _currentStep > index || _isCompleted;
                            final isCurrent = _currentStep == index && !_isCompleted;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    isDone
                                        ? Icons.check_circle_rounded
                                        : (isCurrent
                                            ? Icons.radio_button_checked_rounded
                                            : Icons.radio_button_off_rounded),
                                    size: 18,
                                    color: isDone
                                        ? const Color(0xFF2ECC71)
                                        : (isCurrent
                                            ? primary
                                            : (isDark ? Colors.grey[700] : Colors.grey[400])),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _steps[index],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                        color: isDone
                                            ? (isDark ? Colors.grey[300] : Colors.grey[800])
                                            : (isCurrent
                                                ? (isDark ? Colors.white : Colors.black)
                                                : (isDark ? Colors.grey[600] : Colors.grey[500])),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // ── Bouton de secours (hors-ligne) ───────────────────────
                    if (_canSkipOffline && !_isCompleted) ...[
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: _skipOffline,
                        icon: const Icon(Icons.offline_bolt_rounded, size: 18),
                        label: const Text(
                          'Continuer en mode hors-ligne',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
