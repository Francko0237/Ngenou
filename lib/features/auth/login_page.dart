import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/providers/custom_courses_provider.dart';
import '../../core/providers/projets_provider.dart';
import '../../core/providers/schedule_provider.dart';
import '../../core/providers/progression_provider.dart';
import '../../core/providers/defis_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../app.dart' show rootNavigatorKey;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isPhoneMode = true;
  bool _isLoading = false;
  bool _showPassword = false;
  String? _errorMessage;
  String _selectedRole = 'student'; // 'student' ou 'teacher'
  String _selectedLevel = 'secondaire'; // 'primaire', 'secondaire', 'superieur'

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _performSyncAndRedirect(BuildContext context, String successMsg) async {
    if (mounted) setState(() => _isLoading = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(ctx).primaryColor)),
              const SizedBox(height: 20),
              Text(
                "Synchronisation en cours",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Theme.of(ctx).colorScheme.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                "Récupération de vos cours et progression...",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    try {
      await SyncService.instance.syncAll().timeout(
        const Duration(seconds: 30),
        onTimeout: () => debugPrint("Sync timeout — on continue"),
      );
    } catch (e) {
      debugPrint("Erreur sync : $e");
    } finally {
      try {
        final navContext = Navigator.of(rootNavigatorKey.currentContext!, rootNavigator: true);
        if (navContext.canPop()) navContext.pop();
      } catch (_) {}

      if (context.mounted) {
        await context.read<CustomCoursesProvider>().loadCustomCourses();
        await context.read<ProjetsProvider>().loadProjets();
        await context.read<ScheduleProvider>().load();
        if (context.mounted) {
          context.read<ProgressionProvider>().loadAllProgressions();
          context.read<DefisProvider>().loadTodaySession();
        }
      }

      if (context.mounted) {
        context.go('/');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final connectivity = Provider.of<ConnectivityService>(context, listen: false);
    if (!connectivity.hasConnection) {
      setState(() => _errorMessage = "Connexion impossible. Vérifiez votre connexion Internet.");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (_isPhoneMode) {
        final phone = _phoneController.text.trim();
        final password = _passwordController.text;
        if (_isSignUp) {
          await AuthService.signUpWithPhone(
            phone: phone,
            password: password,
            username: _usernameController.text.trim(),
            role: _selectedRole,
            schoolLevel: _selectedRole == 'student' ? _selectedLevel : null,
          );
        } else {
          await AuthService.signInWithPhone(phone: phone, password: password);
        }
      } else {
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        if (_isSignUp) {
          await AuthService.signUpWithEmail(
            email: email,
            password: password,
            username: _usernameController.text.trim(),
            role: _selectedRole,
            schoolLevel: _selectedRole == 'student' ? _selectedLevel : null,
          );
        } else {
          await AuthService.signInWithEmail(email: email, password: password);
        }
      }
      if (mounted) {
        await _performSyncAndRedirect(context, _isSignUp ? "Compte créé !" : "Connexion réussie !");
      }
    } catch (e) {
      debugPrint("Auth error: $e");
      setState(() => _errorMessage = _friendlyAuthError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyAuthError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('user already registered') || msg.contains('already registered')) {
      return "Ce compte existe déjà. Connectez-vous à la place.";
    }
    if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
      return "Numéro/e-mail ou mot de passe incorrect.";
    }
    if (msg.contains('email not confirmed') || msg.contains('email_not_confirmed')) {
      return "Confirmez votre adresse e-mail via le lien reçu.";
    }
    if (msg.contains('password should be at least') || msg.contains('weak_password')) {
      return "Le mot de passe doit faire au moins 6 caractères.";
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('timeout') ||
        msg.contains('unreachable')) {
      return "Connexion impossible. Vérifiez votre connexion Internet et réessayez.";
    }
    if (msg.contains('too many requests') || msg.contains('rate_limit')) {
      return "Trop de tentatives. Attendez quelques minutes et réessayez.";
    }
    if (msg.contains('user not found') || msg.contains('no user')) {
      return "Aucun compte trouvé avec ces identifiants.";
    }
    if (msg.contains('phone') && msg.contains('invalid')) {
      return "Numéro invalide. Utilisez le format international (+237...).";
    }
    return raw.replaceAll("Exception:", "").replaceAll("AuthException:", "").trim();
  }

  Future<void> _handleGoogleSignIn() async {
    final connectivity = Provider.of<ConnectivityService>(context, listen: false);
    if (!connectivity.hasConnection) {
      setState(() => _errorMessage = "Connexion impossible. Vérifiez votre connexion Internet.");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final success = await AuthService.signInWithGoogle();
      if (success) {
        if (mounted) setState(() => _isLoading = false);
        SyncService.instance
            .syncAll()
            .then((_) {
              final ctx = rootNavigatorKey.currentContext;
              if (ctx != null) {
                ctx.read<CustomCoursesProvider>().loadCustomCourses();
                ctx.read<ProjetsProvider>().loadProjets();
                ctx.read<ScheduleProvider>().load();
                ctx.read<ProgressionProvider>().loadAllProgressions();
                ctx.read<DefisProvider>().loadTodaySession();
              }
            })
            .catchError((Object e) {
              debugPrint("Sync Google error: $e");
              return null;
            });
      } else {
        setState(() => _errorMessage = "Connexion Google Echoué, veuillez Réessayer .");
      }
    } catch (e) {
      debugPrint("Google Sign-In error: $e");
      String message = _friendlyAuthError(e.toString());
      if (e.toString().contains("ApiException: 10") || e.toString().contains("DEVELOPER_ERROR")) {
        message = "Erreur de configuration Google. Contactez le support.";
      }
      setState(() => _errorMessage = message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final isDesktop = size.width >= 900;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Stack(
        children: [
          _buildBackground(isDark, primary),

          if (Navigator.of(context).canPop())
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: isDark ? Colors.white70 : AppColors.textLight,
                    size: 20,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),

          if (isDesktop) _buildDesktopLayout(isDark, primary) else _buildMobileTabletLayout(isDark, primary, isTablet),
        ],
      ),
    );
  }

  // ── Layout PC : deux colonnes ──────────────────────────────────────────────
  Widget _buildDesktopLayout(bool isDark, Color primary) {
    return SafeArea(
      child: Row(
        children: [
          // Colonne gauche — branding
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary.withValues(alpha: isDark ? 0.12 : 0.08),
                        border: Border.all(color: primary.withValues(alpha: isDark ? 0.2 : 0.15), width: 1.5),
                      ),
                      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Ngenou",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textLight,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Apprenez. Progressez. Réussissez.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: isDark ? Colors.white.withValues(alpha: 0.45) : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Divider vertical
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 40),
            color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06),
          ),
          // Colonne droite — formulaire (sans header, déjà dans la colonne gauche)
          Expanded(
            flex: 5,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _buildFormContent(isDark, primary, showHeader: false),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Layout Mobile / Tablette ───────────────────────────────────────────────
  Widget _buildMobileTabletLayout(bool isDark, Color primary, bool isTablet) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 48 : 20, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 480 : double.infinity),
            child: _buildFormContent(isDark, primary),
          ),
        ),
      ),
    );
  }

  // ── Contenu du formulaire (partagé) ───────────────────────────────────────
  Widget _buildFormContent(bool isDark, Color primary, {bool showHeader = true}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            _buildHeader(isDark, primary),
            const SizedBox(height: 28),
          ],
          // Card principale qui regroupe tout
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSignUp) ...[_buildRoleSelector(isDark, primary), const SizedBox(height: 20)],
                _buildModeSelector(isDark, primary),
                const SizedBox(height: 20),
                _buildFormFields(isDark, primary),
                const SizedBox(height: 20),
                _buildSubmitButton(isDark, primary),
                const SizedBox(height: 20),
                _buildDivider(isDark),
                const SizedBox(height: 20),
                _buildGoogleButton(isDark, primary),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildToggleLink(isDark, primary),
          const SizedBox(height: 8),
          _buildFooterText(isDark),
        ],
      ),
    );
  }

  // ── Champs du formulaire ───────────────────────────────────────────────────
  Widget _buildFormFields(bool isDark, Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isSignUp) ...[
          _buildFieldLabel("NOM D'UTILISATEUR", isDark),
          const SizedBox(height: 6),
          _buildInput(
            controller: _usernameController,
            hint: "Votre nom d'utilisateur",
            icon: Icons.person_rounded,
            isDark: isDark,
            primary: primary,
            validator: (v) => (v == null || v.trim().isEmpty) ? "Champ requis." : null,
          ),
          const SizedBox(height: 18),
        ],
        _buildFieldLabel(_isPhoneMode ? "NUMÉRO DE TÉLÉPHONE" : "ADRESSE E-MAIL", isDark),
        const SizedBox(height: 6),
        if (_isPhoneMode)
          _buildInput(
            controller: _phoneController,
            hint: "+237  6XX XX XX XX",
            icon: Icons.phone_rounded,
            isDark: isDark,
            primary: primary,
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().isEmpty) ? "Champ requis." : null,
          )
        else
          _buildInput(
            controller: _emailController,
            hint: "exemple@email.com",
            icon: Icons.email_outlined,
            isDark: isDark,
            primary: primary,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return "Champ requis.";
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                return "E-mail invalide.";
              }
              return null;
            },
          ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFieldLabel("MOT DE PASSE", isDark),
            if (!_isSignUp)
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  "Mot de passe oublié ?",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : AppColors.textSecondaryLight),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _buildInput(
          controller: _passwordController,
          hint: "••••••••••",
          icon: Icons.lock_outline_rounded,
          isDark: isDark,
          primary: primary,
          obscure: !_showPassword,
          suffix: IconButton(
            icon: Icon(
              _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return "Champ requis.";
            if (v.length < 6) return "6 caractères minimum.";
            return null;
          },
        ),
        if (_isSignUp && _selectedRole == 'student') ...[
          const SizedBox(height: 18),
          _buildSchoolLevelSelector(isDark, primary),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? Colors.white.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildFooterText(bool isDark) {
    return Text(
      "En continuant, vous acceptez les Conditions et la Confidentialité de NGENOU",
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        height: 1.5,
        color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildBackground(bool isDark, Color primary) {
    if (isDark) {
      return Stack(
        children: [
          Container(color: AppColors.backgroundDark),
          // Aura violet en haut à droite
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.primaryDark.withValues(alpha: 0.18), Colors.transparent]),
              ),
            ),
          ),
          // Aura bleu en bas à gauche
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.primaryLight.withValues(alpha: 0.12), Colors.transparent]),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: const SizedBox.shrink()),
          ),
        ],
      );
    } else {
      // Mode clair : dégradé doux en haut
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primary.withValues(alpha: 0.06), AppColors.backgroundLight, AppColors.backgroundLight],
            stops: const [0.0, 0.35, 1.0],
          ),
        ),
      );
    }
  }

  Widget _buildHeader(bool isDark, Color primary) {
    return Column(
      children: [
        // Logo avec halo coloré
        Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary.withValues(alpha: isDark ? 0.12 : 0.08),
            border: Border.all(color: primary.withValues(alpha: isDark ? 0.2 : 0.15), width: 1.5),
          ),
          padding: const EdgeInsets.all(0),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 20),
        Text(
          _isSignUp ? "Créer un compte" : "Bon retour !",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textLight,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isSignUp
              ? "Rejoignez Ngenou pour sauvegarder votre progression."
              : "Connectez-vous pour retrouver vos cours.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: isDark ? Colors.white.withValues(alpha: 0.5) : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector(bool isDark, Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Vous êtes :",
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _roleCard(
                label: "Élève / Étudiant",
                icon: Icons.school_rounded,
                selected: _selectedRole == 'student',
                isDark: isDark,
                primary: primary,
                onTap: () => setState(() => _selectedRole = 'student'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _roleCard(
                label: "Enseignant",
                icon: Icons.person_pin_rounded,
                selected: _selectedRole == 'teacher',
                isDark: isDark,
                primary: primary,
                onTap: () => setState(() => _selectedRole = 'teacher'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _roleCard({
    required String label,
    required IconData icon,
    required bool selected,
    required bool isDark,
    required Color primary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? primary
                : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06)),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? primary : (isDark ? Colors.white54 : Colors.black54), size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? (isDark ? Colors.white : primary) : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolLevelSelector(bool isDark, Color primary) {
    final levels = [
      {'key': 'primaire', 'label': 'Primaire'},
      {'key': 'secondaire', 'label': 'Secondaire'},
      {'key': 'superieur', 'label': 'Supérieur'},
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "Niveau :",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: levels.map((lvl) {
              final isSelected = _selectedLevel == lvl['key'];
              return GestureDetector(
                onTap: () => setState(() => _selectedLevel = lvl['key']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary
                        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? primary
                          : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
                    ),
                  ),
                  child: Text(
                    lvl['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector(bool isDark, Color primary) {
    // Style pill sans bordure bleue — indicateur discret sous le texte actif
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _modeTab("Téléphone", _isPhoneMode, isDark, primary, () => setState(() => _isPhoneMode = true)),
          _modeTab("E-mail", !_isPhoneMode, isDark, primary, () => setState(() => _isPhoneMode = false)),
        ],
      ),
    );
  }

  Widget _modeTab(String label, bool selected, bool isDark, Color primary, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            // Fond blanc en mode clair, blanc très transparent en sombre
            color: selected ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            // Ombre légère uniquement en mode clair pour l'effet "pill soulevé"
            boxShadow: selected && !isDark
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? (isDark ? Colors.white : AppColors.textLight)
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color primary,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    final hintColor = isDark ? Colors.white38 : Colors.black26;
    final iconColor = isDark ? Colors.white54 : Colors.black38;
    final textColor = isDark ? Colors.white : AppColors.textLight;
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.1);

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor, fontSize: 15),
        prefixIcon: Icon(icon, size: 22, color: iconColor),
        suffixIcon: suffix,
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
      validator: validator,
    );
  }

  Widget _buildSubmitButton(bool isDark, Color primary) {
    final gradientColors = isDark
        ? [AppColors.primaryDark, const Color(0xFF9B8FFF)]
        : [AppColors.primaryLight, const Color(0xFF2980B9)];

    return GestureDetector(
      onTap: _isLoading ? null : _submit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: _isLoading ? [Colors.grey.shade400, Colors.grey.shade500] : gradientColors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: _isLoading
              ? []
              : [BoxShadow(color: primary.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp ? "Créer mon compte" : "Se connecter",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Row(
      children: [
        Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            "ou",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ),
        ),
        Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12, thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton(bool isDark, Color primary) {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.1)),
        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textLight,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/google G .png',
            height: 28,
            width: 28,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, size: 28, color: Colors.redAccent),
          ),
          const SizedBox(width: 10),
          Text(
            "Continuer avec Google",
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleLink(bool isDark, Color primary) {
    return TextButton(
      onPressed: () => setState(() {
        _isSignUp = !_isSignUp;
        _errorMessage = null;
      }),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white38 : Colors.black38),
          children: [
            TextSpan(text: _isSignUp ? "Déjà un compte ? " : "Nouveau sur Ngenou ? "),
            TextSpan(
              text: _isSignUp ? "Se connecter" : "Créer un compte",
              style: TextStyle(color: primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
