import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/schedule_provider.dart';
import '../../core/services/focus_mode_service.dart';
import '../../core/services/schedule_notification_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/connectivity_service.dart';
import 'package:go_router/go_router.dart';
import '../auth/login_page.dart';

class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key});

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage>
    with WidgetsBindingObserver {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _playingSound;
  bool _batteryExempted = false;
  String _username = 'Ami';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUsername();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playingSound = null;
        });
      }
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      debugPrint('AudioPlayer state: $state');
    });
    if (Platform.isAndroid) {
      _checkBatteryExemption();
    }
  }

  Future<void> _loadUsername() async {
    final name = await AuthService.getUsername();
    if (mounted) {
      setState(() => _username = name);
    }
  }

  Future<void> _editUsername() async {
    final controller = TextEditingController(text: _username);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          "Modifier mon nom d'utilisateur",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Entrez votre nom",
            labelText: "Nom d'utilisateur",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          autofocus: true,
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              Navigator.pop(ctx, val.isNotEmpty ? val : null);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      await AuthService.updateUsername(newName.trim());
      await _loadUsername();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nom d'utilisateur mis à jour !"),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
      }
    }
  }

  Future<void> _checkBatteryExemption() async {
    final exempted =
        await ScheduleNotificationService.isBatteryOptimizationExempted();
    if (mounted) setState(() => _batteryExempted = exempted);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<ThemeProvider>().refreshNotificationSilence();
      if (Platform.isAndroid) _checkBatteryExemption();
    }
  }

  Future<void> _togglePreview(String soundName) async {
    if (_isPlaying && _playingSound == soundName) {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _playingSound = null;
      });
      return;
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);

      // Force le stream ALARM sur Android pour que la preview soit
      // représentative du vrai comportement de l'alarme.
      if (Platform.isAndroid) {
        await _audioPlayer.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              audioFocus: AndroidAudioFocus.gain,
              isSpeakerphoneOn: false,
              stayAwake: false,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.alarm,
              audioMode: AndroidAudioMode.normal,
            ),
          ),
        );
      }

      // Petit délai pour éviter les conflits avec le stop précédent
      await Future.delayed(const Duration(milliseconds: 100));

      if (soundName == 'system') {
        await _audioPlayer.play(AssetSource('audio/alarm_classic.wav'));
      } else if (soundName.startsWith('/') || soundName.startsWith('file://')) {
        final path = soundName.startsWith('file://')
            ? Uri.parse(soundName).toFilePath()
            : soundName;
        final file = File(path);
        if (!await file.exists()) {
          debugPrint('Sound file does not exist: $path');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Fichier audio introuvable. Sélectionnez un autre son.',
                ),
              ),
            );
          }
          return;
        }
        await _audioPlayer.play(DeviceFileSource(path));
      } else {
        await _audioPlayer.play(AssetSource('audio/$soundName.wav'));
      }
      setState(() {
        _isPlaying = true;
        _playingSound = soundName;
      });
    } catch (e) {
      debugPrint('Error playing preview: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de lire ce fichier audio : $e')),
        );
      }
    }
  }

  Future<void> _pickCustomSound(ThemeProvider themeProvider) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final pickedPath = result.files.single.path!;
        final pickedFile = File(pickedPath);

        if (!await pickedFile.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Le fichier sélectionné est inaccessible.'),
              ),
            );
          }
          return;
        }

        Directory appDir;
        if (Platform.isAndroid) {
          final extDirs = await getExternalStorageDirectories(
            type: StorageDirectory.music,
          );
          appDir = extDirs != null && extDirs.isNotEmpty
              ? extDirs.first
              : await getApplicationDocumentsDirectory();
        } else {
          appDir = await getApplicationDocumentsDirectory();
        }

        final fileName = path_helper.basename(pickedPath);
        final savedFile = await pickedFile.copy(
          path_helper.join(appDir.path, fileName),
        );

        if (!await savedFile.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erreur lors de la copie du fichier audio.'),
              ),
            );
          }
          return;
        }

        await themeProvider.setAlarmSound(savedFile.path);
        if (mounted) {
          final scheduleProvider = context.read<ScheduleProvider>();
          await scheduleProvider.rescheduleAllTasks();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sonnerie définie : ${path_helper.basename(savedFile.path)}',
              ),
            ),
          );
        }

        await _togglePreview(savedFile.path);
      }
    } catch (e) {
      debugPrint('Error picking sound: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de charger ce fichier audio : $e'),
          ),
        );
      }
    }
  }

  String _getSoundDisplayName(String soundPath) {
    if (soundPath == 'alarm_classic') return 'Classique (Bip bip)';
    if (soundPath == 'alarm_digital') return 'Numérique (Rapide)';
    if (soundPath == 'alarm_gentle') return 'Doux (Mélodie)';
    if (soundPath == 'system') return 'Sonnerie système par défaut';
    if (soundPath.startsWith('/') || soundPath.startsWith('file://')) {
      return 'Perso : ${path_helper.basename(soundPath)}';
    }
    return soundPath;
  }

  void _showSoundSelectorDialog(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentSound = themeProvider.alarmSound;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Choisir une sonnerie',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSoundOption(
                      ctx,
                      themeProvider,
                      'alarm_classic',
                      '🔔 Classique (Bip bip)',
                      currentSound,
                      setDialogState,
                    ),
                    _buildSoundOption(
                      ctx,
                      themeProvider,
                      'alarm_digital',
                      '⚡ Numérique (Rapide)',
                      currentSound,
                      setDialogState,
                    ),
                    _buildSoundOption(
                      ctx,
                      themeProvider,
                      'alarm_gentle',
                      '🍃 Doux (Mélodie)',
                      currentSound,
                      setDialogState,
                    ),
                    _buildSoundOption(
                      ctx,
                      themeProvider,
                      'system',
                      '🎵 Par défaut du système',
                      currentSound,
                      setDialogState,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.file_open_rounded),
                      title: const Text('Choisir un fichier (.mp3, .wav)...'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickCustomSound(themeProvider);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _audioPlayer.stop();
                    setState(() {
                      _isPlaying = false;
                      _playingSound = null;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Fermer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSoundOption(
    BuildContext dialogContext,
    ThemeProvider themeProvider,
    String value,
    String label,
    String currentValue,
    StateSetter setDialogState,
  ) {
    final isOptionPlaying = _isPlaying && _playingSound == value;
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: currentValue,
      secondary: IconButton(
        icon: Icon(
          isOptionPlaying
              ? Icons.stop_circle_outlined
              : Icons.play_circle_outline,
          color: Theme.of(dialogContext).primaryColor,
        ),
        onPressed: () async {
          if (isOptionPlaying) {
            await _audioPlayer.stop();
            setState(() {
              _isPlaying = false;
              _playingSound = null;
            });
            setDialogState(() {});
          } else {
            await _togglePreview(value);
            setDialogState(() {});
          }
        },
      ),
      onChanged: (val) async {
        if (val != null) {
          await themeProvider.setAlarmSound(val);
          if (dialogContext.mounted) {
            final scheduleProvider = dialogContext.read<ScheduleProvider>();
            await scheduleProvider.rescheduleAllTasks();
          }
          Navigator.pop(dialogContext);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final syncService = context.watch<SyncService>();
    final connectivity = context.watch<ConnectivityService>();
    final user = AuthService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    final bgColor = isDark ? const Color(0xFF0E0E12) : const Color(0xFFF4F5F7);
    final cardColor = isDark ? const Color(0xFF1A1A20) : Colors.white;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.45);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Text(
          'Paramètres',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : const Color(0xFF15151C),
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: dividerColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        children: [
          _sectionLabel('Compte', isDark),
          _card(
            isDark: isDark,
            cardColor: cardColor,
            dividerColor: dividerColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  primary,
                                  primary.withValues(alpha: 0.65),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _username.isNotEmpty
                                  ? _username[0].toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (user != null)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 15,
                                height: 15,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2ECC71),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cardColor,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _username,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF15151C),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              user != null
                                  ? (user.phone ?? user.email ?? 'Connecté')
                                  : 'Non connecté',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: primary.withValues(alpha: 0.1),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: _editUsername,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (user != null) ...[
                  Divider(height: 1, color: dividerColor),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            label: syncService.isSyncing
                                ? 'Sync...'
                                : 'Synchroniser',
                            icon: syncService.isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.sync_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                            color: const Color(0xFF2ECC71),
                            onPressed:
                                syncService.isSyncing ||
                                    !connectivity.hasConnection
                                ? null
                                : () async {
                                    await SyncService.instance.syncAll();
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Synchronisation terminée !',
                                          ),
                                          backgroundColor: Color(0xFF2ECC71),
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _actionButton(
                            label: 'Déconnexion',
                            icon: const Icon(
                              Icons.logout_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            color: const Color(0xFFE74C3C),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  title: const Text(
                                    'Se déconnecter ?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                  content: const Text(
                                    'Vos données locales seront effacées. Elles seront restaurées à la prochaine connexion.',
                                    style: TextStyle(height: 1.4),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Annuler'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFE74C3C,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Déconnecter'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await AuthService.signOut();
                                await _loadUsername();
                                if (mounted) context.go('/login');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Divider(height: 1, color: dividerColor),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Créez un compte pour synchroniser vos cours et votre progression.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: _actionButton(
                            label: 'Se connecter / Créer un compte',
                            icon: const Icon(
                              Icons.login_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            color: primary,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            ).then((_) => _loadUsername()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Apparence', isDark),
          _card(
            isDark: isDark,
            cardColor: cardColor,
            dividerColor: dividerColor,
            child: _settingsTile(
              icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              iconColor: isDark
                  ? const Color(0xFF6C63FF)
                  : const Color(0xFFF39C12),
              title: 'Thème',
              subtitle: isDark ? 'Mode sombre' : 'Mode clair',
              isDark: isDark,
              trailing: Switch(
                value: isDark,
                activeThumbColor: Colors.white,
                activeTrackColor: primary,
                inactiveThumbColor: isDark ? Colors.grey[400] : Colors.grey[600],
                inactiveTrackColor: isDark ? const Color(0xFF2C2C35) : const Color(0xFFE2E8F0),
                trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.transparent;
                  }
                  return isDark ? Colors.grey[700] : Colors.grey[400];
                }),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (val) => themeProvider.toggleTheme(
                  val ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Concentration', isDark),
          _card(
            isDark: isDark,
            cardColor: cardColor,
            dividerColor: dividerColor,
            child: Column(
              children: [
                _settingsTile(
                  icon: Icons.center_focus_strong_rounded,
                  iconColor: const Color(0xFF3498DB),
                  title: 'Mode Focus',
                  subtitle: themeProvider.isFocusMode
                      ? (themeProvider.notificationsSilenced
                            ? 'Actif — notifications silencieuses'
                            : 'Actif — accordez "Ne pas déranger"')
                      : 'Plein écran + silence des distractions',
                  isDark: isDark,
                  trailing: Switch(
                    value: themeProvider.isFocusMode,
                    activeThumbColor: Colors.white,
                    activeTrackColor: primary,
                    inactiveThumbColor: isDark ? Colors.grey[400] : Colors.grey[600],
                    inactiveTrackColor: isDark ? const Color(0xFF2C2C35) : const Color(0xFFE2E8F0),
                    trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.transparent;
                      }
                      return isDark ? Colors.grey[700] : Colors.grey[400];
                    }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) =>
                        _onFocusModeChanged(context, themeProvider, val),
                  ),
                ),
                if (Platform.isAndroid &&
                    themeProvider.isFocusMode &&
                    !themeProvider.notificationsSilenced) ...[
                  Divider(height: 1, color: dividerColor),
                  _settingsTile(
                    icon: Icons.notifications_off_outlined,
                    iconColor: const Color(0xFFE67E22),
                    title: 'Autoriser le silence',
                    subtitle: 'Accès "Ne pas déranger" requis',
                    isDark: isDark,
                    onTap: () => _openNotificationPermissionSettings(context),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Alarmes', isDark),
          _card(
            isDark: isDark,
            cardColor: cardColor,
            dividerColor: dividerColor,
            child: Column(
              children: [
                _settingsTile(
                  icon: Icons.alarm_rounded,
                  iconColor: const Color(0xFF9B59B6),
                  title: 'Sonnerie',
                  subtitle: _getSoundDisplayName(themeProvider.alarmSound),
                  isDark: isDark,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _togglePreview(themeProvider.alarmSound),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlaying &&
                                    _playingSound == themeProvider.alarmSound
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            size: 20,
                            color: primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                  onTap: () => _showSoundSelectorDialog(context, themeProvider),
                ),
                if (Platform.isAndroid) ...[
                  Divider(height: 1, color: dividerColor),
                  _settingsTile(
                    icon: _batteryExempted
                        ? Icons.battery_charging_full_rounded
                        : Icons.battery_alert_rounded,
                    iconColor: _batteryExempted
                        ? const Color(0xFF2ECC71)
                        : const Color(0xFFE74C3C),
                    title: 'Optimisation batterie',
                    subtitle: _batteryExempted
                        ? 'Non bloquée par la batterie ✓'
                        : 'Désactiver pour que les alarmes sonnent',
                    isDark: isDark,
                    trailing: _batteryExempted
                        ? Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2ECC71,
                              ).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF2ECC71),
                              size: 18,
                            ),
                          )
                        : TextButton(
                            onPressed: () =>
                                _showBatteryOptimizationDialog(context),
                            style: TextButton.styleFrom(
                              backgroundColor: primary.withValues(alpha: 0.1),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Configurer',
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                    onTap: _batteryExempted
                        ? null
                        : () => _showBatteryOptimizationDialog(context),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('À propos', isDark),
          _card(
            isDark: isDark,
            cardColor: cardColor,
            dividerColor: dividerColor,
            child: _settingsTile(
              icon: Icons.info_outline_rounded,
              iconColor: const Color(0xFF4A90D9),
              title: 'Ngenou',
              subtitle: 'Version 1.1.1 • Par Yamgai Mokube Francko Daniel',
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.28)
                  : Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.42)
                  : Colors.black.withValues(alpha: 0.38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required bool isDark,
    required Color cardColor,
    required Color dividerColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: iconColor.withValues(alpha: 0.16)),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: isDark ? Colors.white : const Color(0xFF15151C),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Widget icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: disabled ? color.withValues(alpha: 0.35) : color,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: color.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ).copyWith(
        elevation: WidgetStateProperty.resolveWith(
          (states) => disabled ? 0 : (states.contains(WidgetState.pressed) ? 0 : 2),
        ),
      ),
    );
  }

  Future<void> _onFocusModeChanged(
    BuildContext context,
    ThemeProvider provider,
    bool enabled,
  ) async {
    final result = await provider.toggleFocusMode(enabled);

    if (!context.mounted) return;

    if (enabled && result.needsPermission && Platform.isAndroid) {
      final grant = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Silence des notifications',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          content: const Text(
            'Pour bloquer WhatsApp, Facebook et les autres distractions, '
            'autorisez Ngenou à gérer le mode « Ne pas déranger ».\n\n'
            'Votre réglage précédent sera restauré à la désactivation du mode Focus.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Plus tard'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Autoriser'),
            ),
          ],
        ),
      );

      if (grant == true && context.mounted) {
        await _openNotificationPermissionSettings(context);
      }
    } else if (result.message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message!)));
    } else if (enabled && result.notificationsBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mode Focus actif — notifications silencieuses'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openNotificationPermissionSettings(BuildContext context) async {
    await FocusModeService.openNotificationPermissionSettings();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Activez Ngenou dans les paramètres, puis revenez dans l\'app.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  /// Affiche un guide adapté au constructeur pour désactiver l'optimisation
  /// batterie — chaque marque a ses propres menus cachés.
  Future<void> _showBatteryOptimizationDialog(BuildContext context) async {
    final brand = await _getDeviceBrand();
    final guide = _getBrandGuide(brand);

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.battery_alert_rounded,
                color: Theme.of(ctx).colorScheme.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Alarmes bloquées ?',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ton téléphone ($brand) peut bloquer les alarmes pour économiser la batterie.',
                style: const TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 14),
              // Étape 1 : exemption Android standard
              _guideStep(
                '1',
                'Exemption Android',
                'Appuie sur "Désactiver l\'optimisation" ci-dessous pour que Android autorise les alarmes en veille.',
                Theme.of(ctx).primaryColor,
              ),
              if (guide != null) ...[
                const SizedBox(height: 8),
                _guideStep(
                  '2',
                  guide['title']!,
                  guide['steps']!,
                  Theme.of(ctx).colorScheme.error,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.battery_charging_full_rounded, size: 18),
            label: const Text('Désactiver l\'optimisation'),
            onPressed: () async {
              Navigator.pop(ctx);
              await ScheduleNotificationService.requestBatteryOptimizationExemption();
              await Future.delayed(const Duration(milliseconds: 600));
              _checkBatteryExemption();
            },
          ),
        ],
      ),
    );
  }

  Widget _guideStep(String num, String title, String content, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: color,
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(fontSize: 12.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getDeviceBrand() async {
    try {
      final result = await const MethodChannel(
        'com.ngenou.app/sdk_version',
      ).invokeMethod<String>('getDeviceBrand');
      return result?.toLowerCase() ?? 'android';
    } catch (_) {
      return 'android';
    }
  }

  /// Retourne un guide spécifique au constructeur, ou null si non nécessaire.
  Map<String, String>? _getBrandGuide(String brand) {
    if (brand.contains('xiaomi') ||
        brand.contains('redmi') ||
        brand.contains('poco')) {
      return {
        'title': 'Xiaomi / MIUI — Autostart',
        'steps':
            'Paramètres → Applications → Ngenou → Autostart : Activer.\n'
            'Paramètres → Batterie → Économiseur de batterie → Ngenou → Sans restriction.',
      };
    }
    if (brand.contains('samsung')) {
      return {
        'title': 'Samsung — Gestion batterie',
        'steps':
            'Paramètres → Applications → Ngenou → Batterie → Sans restriction.\n'
            'Ou : Paramètres → Maintenance de l\'appareil → Batterie → Ngenou → Sans restriction.',
      };
    }
    if (brand.contains('huawei') || brand.contains('honor')) {
      return {
        'title': 'Huawei / Honor — Lancement appli',
        'steps':
            'Paramètres → Applications → Ngenou → Lancement appli : Désactiver la gestion automatique, puis activer Exécution en arrière-plan + Démarrage automatique.',
      };
    }
    if (brand.contains('oppo') ||
        brand.contains('realme') ||
        brand.contains('oneplus')) {
      return {
        'title': 'OPPO / Realme / OnePlus',
        'steps':
            'Paramètres → Gestion applis → Ngenou → Consommation batterie → Ne pas restreindre.\n'
            'Aussi : Paramètres → Batterie → Optimisation batterie → Ngenou → Non optimisé.',
      };
    }
    if (brand.contains('vivo')) {
      return {
        'title': 'Vivo — Accès arrière-plan',
        'steps':
            'Paramètres iManager → Gestionnaire appli → Consommation batterie → Ngenou → Autoriser l\'exécution en arrière-plan.',
      };
    }
    if (brand.contains('nokia')) {
      return {
        'title': 'Nokia — Économie batterie',
        'steps':
            'Paramètres → Applications → Ngenou → Batterie → Non restreint.',
      };
    }
    // Autres marques : guide générique
    return {
      'title': 'Réglage manuel recommandé',
      'steps':
          'Paramètres → Applications → Ngenou → Batterie → Sélectionner "Sans restriction" ou "Non optimisé".',
    };
  }
}
