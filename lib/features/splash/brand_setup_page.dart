import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/schedule_notification_service.dart';

const _kBrandSetupDone = 'battery_brand_setup_done';

/// Affiche la page si l'une des permissions nécessaires manque.
/// Vérifié à chaque démarrage — pas juste au premier lancement.
Future<bool> shouldShowBrandSetup() async {
  if (!Platform.isAndroid) return false;
  final batteryOk =
      await ScheduleNotificationService.isBatteryOptimizationExempted();
  if (!batteryOk) return true;
  final notifOk = await ScheduleNotificationService.areNotificationsEnabled();
  if (!notifOk) return true;
  return false;
}

Future<void> markBrandSetupDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kBrandSetupDone, true);
}

// ─────────────────────────────────────────────────────────────────────────────

class BrandSetupPage extends StatefulWidget {
  final VoidCallback onDone;
  const BrandSetupPage({super.key, required this.onDone});

  @override
  State<BrandSetupPage> createState() => _BrandSetupPageState();
}

class _BrandSetupPageState extends State<BrandSetupPage>
    with WidgetsBindingObserver {
  bool _batteryOk = false;
  bool _notifOk = true;
  bool _fadeOut = false; // Déclenche le fondu de sortie

  bool get _allOk => _batteryOk && _notifOk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quand l'utilisateur revient après avoir validé une popup Android
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final battery =
        await ScheduleNotificationService.isBatteryOptimizationExempted();
    final notif = await ScheduleNotificationService.areNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _batteryOk = battery;
      _notifOk = notif;
    });
    // Permissions déjà accordées → fermeture automatique avec fondu
    if (battery && notif) {
      setState(() => _fadeOut = true);
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) _done();
    }
  }

  Future<void> _requestBattery() async {
    await ScheduleNotificationService.requestBatteryOptimizationExemption();
    await Future.delayed(const Duration(milliseconds: 600));
    await _checkPermissions();
  }

  Future<void> _requestNotif() async {
    await ScheduleNotificationService.ensureAllAndroidPermissions();
    await Future.delayed(const Duration(milliseconds: 600));
    await _checkPermissions();
  }

  Future<void> _done() async {
    await markBrandSetupDone();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final bg = isDark ? const Color(0xFF111111) : const Color(0xFFF4F6FA);

    return AnimatedOpacity(
      opacity: _fadeOut ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 250),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(),

                // Icône
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _allOk
                        ? Colors.green.withValues(alpha: 0.12)
                        : primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _allOk
                        ? Icons.check_circle_rounded
                        : Icons.notifications_active_rounded,
                    color: _allOk ? Colors.green : primary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),

                // Titre
                Text(
                  _allOk ? 'Tout est prêt !' : 'Autorisations nécessaires',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Sous-titre
                Text(
                  _allOk
                      ? 'Ngenou peut maintenant vous envoyer des alarmes correctement.'
                      : 'Activez les options ci-dessous pour que vos alarmes sonnent bien.',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.6,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Carte batterie
                if (!_batteryOk) ...[
                  _PermissionCard(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Fonctionnement en arrière-plan',
                    description:
                        'Permet à Ngenou de sonner même quand votre écran est éteint.',
                    buttonLabel: 'Appuyer ici puis "Autoriser"',
                    isDark: isDark,
                    primary: primary,
                    onTap: _requestBattery,
                  ),
                  const SizedBox(height: 12),
                ],

                // Carte notifications
                if (!_notifOk) ...[
                  _PermissionCard(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    description:
                        'Nécessaire pour recevoir les alarmes et rappels de révision.',
                    buttonLabel: 'Activer les notifications',
                    isDark: isDark,
                    primary: primary,
                    onTap: _requestNotif,
                  ),
                  const SizedBox(height: 12),
                ],

                const Spacer(),

                // Bouton terminer
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: Icon(
                      _allOk
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _allOk ? 'C\'est parti !' : 'Continuer quand même',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _allOk
                          ? Colors.green.shade600
                          : Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _done,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ), // Scaffold
    ); // AnimatedOpacity
  }
}

// ─── Widget carte de permission ───────────────────────────────────────────────

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onTap,
            ),
          ),
        ],
      ),
    );
  }
}
