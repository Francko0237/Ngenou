import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_colors.dart';

/// Formatter qui limite le nombre de chiffres saisis (ignore les non-chiffres
/// déjà présents comme le + ou les espaces du préfixe).
class _PhoneDigitsFormatter extends TextInputFormatter {
  final int maxDigits;
  const _PhoneDigitsFormatter({required this.maxDigits});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > maxDigits) return oldValue;
    return newValue;
  }
}

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

  Future<void> _performSyncAndRedirect(
    BuildContext context,
    String successMsg,
  ) async {
    if (mounted) setState(() => _isLoading = false);
    if (context.mounted) {
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final connectivity = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );
    if (!connectivity.hasConnection) {
      setState(
        () => _errorMessage =
            "Connexion impossible. Vérifiez votre connexion Internet.",
      );
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
          final res = await AuthService.signUpWithEmail(
            email: email,
            password: password,
            username: _usernameController.text.trim(),
            role: _selectedRole,
            schoolLevel: _selectedRole == 'student' ? _selectedLevel : null,
          );
          // Si la connexion directe après inscription a échoué (email_not_confirmed),
          // on informe l'utilisateur de confirmer son email
          if (res.session == null) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isSignUp = false;
                _errorMessage =
                    "Votre compte a été créé ! Confirmez votre adresse e-mail ($email) "
                    "puis connectez-vous avec vos identifiants.";
              });
            }
            return;
          }
        } else {
          await AuthService.signInWithEmail(email: email, password: password);
        }
      }
      if (mounted) {
        await _performSyncAndRedirect(
          context,
          _isSignUp ? "Compte créé !" : "Connexion réussie !",
        );
      }
    } catch (e) {
      debugPrint("Auth error: $e");
      setState(() => _errorMessage = _friendlyAuthError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEmailConfirmationDialog(String email) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        bool isResending = false;
        bool resent = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_email_unread_outlined,
                      color: primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Vérifiez votre boîte e-mail",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textLight,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Un e-mail de confirmation a été envoyé à :",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white70
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      email,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Cliquez sur le lien reçu pour activer votre compte Ngenou, puis revenez vous connecter.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  if (resent) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: AppColors.success,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "E-mail renvoyé avec succès !",
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: isResending || resent
                      ? null
                      : () async {
                          setDialogState(() => isResending = true);
                          try {
                            await AuthService.resendVerificationEmail(email);
                            if (context.mounted) {
                              setDialogState(() {
                                isResending = false;
                                resent = true;
                              });
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => isResending = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _friendlyAuthError(e.toString()),
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  child: isResending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          "Renvoyer l'e-mail",
                          style: TextStyle(fontSize: 13),
                        ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text("J'ai compris"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _ForgotPasswordDialog(
        initialEmail: !_isPhoneMode ? _emailController.text.trim() : '',
        isPhoneMode: _isPhoneMode,
        onPasswordResetSuccess: (ctx, msg) async {
          if (mounted) {
            await _performSyncAndRedirect(context, msg);
          }
        },
      ),
    );
  }

  String _friendlyAuthError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('user already registered') ||
        msg.contains('already registered')) {
      return "Ce compte existe déjà. Connectez-vous à la place.";
    }
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return "Numéro/e-mail ou mot de passe incorrect.";
    }
    if (msg.contains('email not confirmed') ||
        msg.contains('email_not_confirmed')) {
      return "Votre adresse e-mail n'est pas encore confirmée. "
          "Vérifiez votre boîte de réception et cliquez sur le lien de confirmation.";
    }
    if (msg.contains('password should be at least') ||
        msg.contains('weak_password')) {
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
    if (msg.contains('profiles_school_level_check')) {
      return "Erreur lors de l'enregistrement du niveau scolaire. Réessayez.";
    }
    return raw
        .replaceAll("Exception:", "")
        .replaceAll("AuthException:", "")
        .trim();
  }

  Future<void> _handleGoogleSignIn() async {
    final connectivity = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );
    if (!connectivity.hasConnection) {
      setState(
        () => _errorMessage =
            "Connexion impossible. Vérifiez votre connexion Internet.",
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final success = await AuthService.signInWithGoogle();
      if (success) {
        if (mounted) {
          await _performSyncAndRedirect(context, "Connexion réussie !");
        }
      } else {
        setState(
          () => _errorMessage = "Connexion Google Échouée, veuillez réessayer.",
        );
      }
    } catch (e) {
      debugPrint("Google Sign-In error: $e");
      String message = _friendlyAuthError(e.toString());
      if (e.toString().contains("ApiException: 10") ||
          e.toString().contains("DEVELOPER_ERROR")) {
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
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

          if (isDesktop)
            _buildDesktopLayout(isDark, primary)
          else
            _buildMobileTabletLayout(isDark, primary, isTablet),

          // ── Toggle thème en haut à droite ──
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 8),
                child: _buildDarkModeToggle(isDark),
              ),
            ),
          ),
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
                  minHeight:
                      MediaQuery.of(context).size.height -
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
                        border: Border.all(
                          color: primary.withValues(alpha: isDark ? 0.2 : 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
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
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : AppColors.textSecondaryLight,
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
          ),
          // Colonne droite — formulaire (sans header, déjà dans la colonne gauche)
          Expanded(
            flex: 5,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 32,
                ),
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
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 48 : 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 480 : double.infinity,
            ),
            child: _buildFormContent(isDark, primary),
          ),
        ),
      ),
    );
  }

  // ── Contenu du formulaire (partagé) ───────────────────────────────────────
  Widget _buildFormContent(
    bool isDark,
    Color primary, {
    bool showHeader = true,
  }) {
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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSignUp) ...[
                  _buildRoleSelector(isDark, primary),
                  const SizedBox(height: 20),
                ],
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
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Champ requis." : null,
          ),
          const SizedBox(height: 18),
        ],
        _buildFieldLabel(
          _isPhoneMode ? "NUMÉRO DE TÉLÉPHONE" : "ADRESSE E-MAIL",
          isDark,
        ),
        const SizedBox(height: 6),
        if (_isPhoneMode)
          _buildInput(
            controller: _phoneController,
            hint: "6XX XX XX XX",
            icon: Icons.phone_rounded,
            isDark: isDark,
            primary: primary,
            keyboardType: TextInputType.phone,
            inputFormatters: [_PhoneDigitsFormatter(maxDigits: 9)],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return "Champ requis.";
              final digits = v.trim().replaceAll(RegExp(r'\D'), '');
              if (digits.length < 9) return "9 chiffres requis.";
              return null;
            },
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
                onPressed: _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  "Mot de passe oublié ?",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white54
                        : AppColors.textSecondaryLight,
                  ),
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
              _showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_errorMessage!.contains('Confirmez votre adresse') &&
                    !_isPhoneMode &&
                    _emailController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _showEmailConfirmationDialog(
                        _emailController.text.trim(),
                      ),
                      icon: const Icon(
                        Icons.mark_email_unread_outlined,
                        size: 14,
                        color: AppColors.error,
                      ),
                      label: const Text(
                        "Renvoyer le lien de confirmation",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
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
        color: isDark
            ? Colors.white.withValues(alpha: 0.45)
            : Colors.black.withValues(alpha: 0.4),
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
        color: isDark
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.3),
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
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryDark.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
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
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: const SizedBox.shrink(),
            ),
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
            colors: [
              primary.withValues(alpha: 0.06),
              AppColors.backgroundLight,
              AppColors.backgroundLight,
            ],
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
            border: Border.all(
              color: primary.withValues(alpha: isDark ? 0.2 : 0.15),
              width: 1.5,
            ),
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : AppColors.textSecondaryLight,
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
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? primary
                : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06)),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected
                  ? primary
                  : (isDark ? Colors.white54 : Colors.black54),
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected
                    ? (isDark ? Colors.white : primary)
                    : (isDark ? Colors.white70 : Colors.black87),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? primary
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.08)),
                    ),
                  ),
                  child: Text(
                    lvl['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
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
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _modeTab(
            "Téléphone",
            _isPhoneMode,
            isDark,
            primary,
            () => setState(() => _isPhoneMode = true),
          ),
          _modeTab(
            "E-mail",
            !_isPhoneMode,
            isDark,
            primary,
            () => setState(() => _isPhoneMode = false),
          ),
        ],
      ),
    );
  }

  Widget _modeTab(
    String label,
    bool selected,
    bool isDark,
    Color primary,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            // Fond blanc en mode clair, blanc très transparent en sombre
            color: selected
                ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            // Ombre légère uniquement en mode clair pour l'effet "pill soulevé"
            boxShadow: selected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
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
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final hintColor = isDark ? Colors.white38 : Colors.black26;
    final iconColor = isDark ? Colors.white54 : Colors.black38;
    final textColor = isDark ? Colors.white : AppColors.textLight;
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.1);

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
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
            colors: _isLoading
                ? [Colors.grey.shade400, Colors.grey.shade500]
                : gradientColors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
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
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: isDark ? Colors.white12 : Colors.black12,
            thickness: 1,
          ),
        ),
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
        Expanded(
          child: Divider(
            color: isDark ? Colors.white12 : Colors.black12,
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(bool isDark, Color primary) {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.1),
        ),
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white,
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
            errorBuilder: (_, __, ___) => const Icon(
              Icons.g_mobiledata_rounded,
              size: 28,
              color: Colors.redAccent,
            ),
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

  Widget _buildDarkModeToggle(bool isDark) {
    return GestureDetector(
      onTap: () => context.read<ThemeProvider>().toggleTheme(
        isDark ? ThemeMode.light : ThemeMode.dark,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 64,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.07),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: Stack(
          children: [
            // Thumb animé
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color.fromARGB(255, 14, 121, 131)
                      : const Color.fromARGB(255, 14, 121, 131),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isDark
                                  ? const Color(0xFF6C63FF)
                                  : const Color.fromARGB(255, 9, 67, 132))
                              .withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
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
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          children: [
            TextSpan(
              text: _isSignUp ? "Déjà un compte ? " : "Nouveau sur Ngenou ? ",
            ),
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

/// Dialogue en 3 étapes pour la réinitialisation de mot de passe par code e-mail
class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;
  final bool isPhoneMode;
  final Future<void> Function(BuildContext, String) onPasswordResetSuccess;

  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.isPhoneMode,
    required this.onPasswordResetSuccess,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  int _currentStep = 0; // 0: email, 1: code OTP, 2: nouveau mot de passe
  late final TextEditingController _emailController;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final _formKeyEmail = GlobalKey<FormState>();
  final _formKeyCode = GlobalKey<FormState>();
  final _formKeyPassword = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _codeResent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    if (!_formKeyEmail.currentState!.validate()) return;
    final email = _emailController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await AuthService.requestPasswordReset(email);
      if (!success) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                "Aucun compte n'est associé à cette adresse e-mail.";
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = 1;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Erreur lors de l'envoi du code : ${e.toString()}";
        });
      }
    }
  }

  Future<void> _handleVerifyCode() async {
    if (!_formKeyCode.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isValid = await AuthService.verifyPasswordResetCode(
        email: email,
        code: code,
      );
      if (isValid) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentStep = 2;
            _errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                "Code incorrect ou expiré. Vérifiez votre boîte de réception.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Erreur de vérification : ${e.toString()}";
        });
      }
    }
  }

  Future<void> _handleUpdatePassword() async {
    if (!_formKeyPassword.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _passwordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await AuthService.completePasswordReset(
        email: email,
        code: code,
        newPassword: newPassword,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        await widget.onPasswordResetSuccess(
          context,
          "Mot de passe réinitialisé avec succès !",
        );
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Erreur lors de la réinitialisation du mot de passe.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Erreur lors de la mise à jour du mot de passe : ${e.toString()}";
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      final clean = data.text!.replaceAll(RegExp(r'\s+'), '').trim();
      _codeController.text = clean;
      setState(() {});
    }
  }

  Future<void> _resendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AuthService.requestPasswordReset(email);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _codeResent = true;
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _codeResent = false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Impossible de renvoyer le code : $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      title: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _currentStep == 0
                  ? Icons.lock_reset_rounded
                  : _currentStep == 1
                      ? Icons.mark_email_read_rounded
                      : Icons.password_rounded,
              color: primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _currentStep == 0
                ? "Mot de passe oublié ?"
                : _currentStep == 1
                    ? "Code de sécurité 🔑"
                    : "Nouveau mot de passe",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textLight,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentStep == 0) _buildStepEmail(isDark, primary),
              if (_currentStep == 1) _buildStepCode(isDark, primary),
              if (_currentStep == 2) _buildStepNewPassword(isDark, primary),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: _buildActions(isDark, primary),
    );
  }

  Widget _buildStepEmail(bool isDark, Color primary) {
    return Form(
      key: _formKeyEmail,
      child: Column(
        children: [
          Text(
            "Entrez votre adresse e-mail pour recevoir votre code de réinitialisation à 6 chiffres.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: "votre-email@exemple.com",
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.email_outlined,
                size: 20,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primary, width: 1.5),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return "L'adresse e-mail est requise.";
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(v.trim())) {
                return "Format d'adresse e-mail invalide.";
              }
              return null;
            },
          ),
          if (widget.isPhoneMode) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Si votre compte a été créé avec un téléphone sans e-mail, contactez l'assistance.",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepCode(bool isDark, Color primary) {
    return Form(
      key: _formKeyCode,
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: "Un code à 6 chiffres a été envoyé à :\n"),
                TextSpan(
                  text: _emailController.text.trim(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => setState(() {
              _currentStep = 0;
              _errorMessage = null;
            }),
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text("Changer d'e-mail",
                style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: primary,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.text,
            textAlign: TextAlign.center,
            maxLength: 8,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
            ),
            decoration: InputDecoration(
              counterText: "",
              hintText: "123456",
              hintStyle: TextStyle(
                color: isDark ? Colors.white24 : Colors.black26,
                letterSpacing: 4,
                fontSize: 18,
              ),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              suffixIcon: IconButton(
                tooltip: "Coller le code",
                icon: Icon(Icons.content_paste_rounded,
                    color: primary, size: 20),
                onPressed: _pasteFromClipboard,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primary, width: 1.5),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return "Veuillez entrer le code de sécurité.";
              }
              if (v.trim().length < 6) {
                return "Le code doit contenir au moins 6 chiffres.";
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Vous n'avez rien reçu ?",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              TextButton(
                onPressed: _isLoading ? null : _resendCode,
                child: Text(
                  _codeResent ? "✅ Renvoyé !" : "Renvoyer",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _codeResent ? AppColors.success : primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNewPassword(bool isDark, Color primary) {
    return Form(
      key: _formKeyPassword,
      child: Column(
        children: [
          Text(
            "Code validé ! ✅\nDéfinissez maintenant votre nouveau mot de passe sécurisé :",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: "Nouveau mot de passe",
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 14,
              ),
              prefixIcon: Icon(Icons.lock_outline_rounded,
                  size: 20, color: isDark ? Colors.white54 : Colors.black45),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primary, width: 1.5),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return "Veuillez entrer un mot de passe.";
              }
              if (v.trim().length < 6) {
                return "Le mot de passe doit comporter au moins 6 caractères.";
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: "Confirmer le mot de passe",
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 14,
              ),
              prefixIcon: Icon(Icons.lock_reset_rounded,
                  size: 20, color: isDark ? Colors.white54 : Colors.black45),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primary, width: 1.5),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return "Veuillez confirmer le mot de passe.";
              }
              if (v != _passwordController.text) {
                return "Les mots de passe ne correspondent pas.";
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(bool isDark, Color primary) {
    return [
      TextButton(
        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        child: Text(
          "Annuler",
          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        ),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _isLoading
            ? null
            : () {
                if (_currentStep == 0) {
                  _handleSendCode();
                } else if (_currentStep == 1) {
                  _handleVerifyCode();
                } else {
                  _handleUpdatePassword();
                }
              },
        child: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _currentStep == 0
                    ? "Envoyer le code"
                    : _currentStep == 1
                        ? "Vérifier le code"
                        : "Enregistrer & Se connecter",
              ),
      ),
    ];
  }
}

