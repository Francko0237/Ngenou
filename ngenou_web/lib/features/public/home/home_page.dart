import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/download_button.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/phone_mockup.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/site_footer.dart';
import '../../../core/widgets/site_navbar.dart';

/// Page d'accueil vitrine de Ngenou
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _showcaseKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  int _selectedTabIndex = 0;

  void _scrollToSection(String section) {
    GlobalKey? key;
    if (section == 'showcase') key = _showcaseKey;
    if (section == 'features') key = _featuresKey;
    if (section == 'faq') key = _faqKey;

    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SiteNavbar(
        onSectionSelected: _scrollToSection,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _HeroSection(
              onExplorePressed: () => _scrollToSection('showcase'),
              disableAnimations: disableAnimations,
            ),
            _ShowcaseSection(
              key: _showcaseKey,
              selectedIndex: _selectedTabIndex,
              onTabChanged: (index) => setState(() => _selectedTabIndex = index),
              disableAnimations: disableAnimations,
            ),
            _BentoFeaturesSection(
              key: _featuresKey,
              disableAnimations: disableAnimations,
            ),
            _DownloadCtaSection(
              disableAnimations: disableAnimations,
            ),
            _FaqSection(
              key: _faqKey,
              disableAnimations: disableAnimations,
            ),
            const SiteFooter(),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HERO SECTION
// =============================================================================
class _HeroSection extends StatelessWidget {
  final VoidCallback onExplorePressed;
  final bool disableAnimations;

  const _HeroSection({
    required this.onExplorePressed,
    required this.disableAnimations,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isDesktop = Responsive.isDesktop(context);

    Widget content = ResponsiveContainer(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: isMobile ? 36 : 64,
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: _buildCopy(context)),
                const SizedBox(width: 48),
                Expanded(flex: 5, child: _buildVisual(context)),
              ],
            )
          : Column(
              children: [
                _buildCopy(context),
                const SizedBox(height: 48),
                _buildVisual(context),
              ],
            ),
    );

    if (disableAnimations) return content;

    return content
        .animate()
        .fadeIn(duration: 600.ms, curve: Curves.easeOut)
        .slideY(begin: 0.05, end: 0, duration: 600.ms);
  }

  Widget _buildCopy(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        RichText(
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          text: TextSpan(
            style: GoogleFonts.fraunces(
              fontSize: isMobile ? 34 : 52,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              height: 1.15,
              letterSpacing: -1,
            ),
            children: const [
              TextSpan(text: 'L\'apprentissage intelligent dont '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GradientText(
                  'vous êtes le maître',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Votre tuteur IA personnel, vos fiches de cours, vos défis quotidiens et des extensions pédagogiques à installer selon vos besoins. Vos cours et votre planning restent disponibles hors-ligne et synchronisés sur tous vos appareils.',
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.manrope(
            fontSize: isMobile ? 15 : 17,
            color: AppColors.textMuted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const DownloadButton(),
            OutlinedButton.icon(
              onPressed: onExplorePressed,
              icon: const Text('Voir l\'application'),
              label: const Icon(Icons.arrow_forward_rounded, size: 16),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Wrap(
          spacing: 20,
          runSpacing: 12,
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          children: const [
            _HeroSpec(
              icon: Icons.wifi_off_rounded,
              text: 'Cours et planning hors-ligne',
            ),
            _HeroSpec(
              icon: Icons.shield_outlined,
              text: 'Données sauvegardées en sécurité',
            ),
            _HeroSpec(
              icon: Icons.school_outlined,
              text: 'Du primaire au supérieur',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVisual(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo de lumière
          Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.cyan.withValues(alpha: 0.25),
                  AppColors.gold.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Logo en arrière plan subtil
          Opacity(
            opacity: 0.12,
            child: Image.asset(
              'assets/images/logo.png',
              width: 320,
              height: 320,
            ),
          ),
          // Smartphone avec capture
          const PhoneMockup(
            imagePath: 'assets/screenshots/tuteur_chat.png',
            width: 270,
          ),
        ],
      ),
    );
  }
}

class _HeroSpec extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroSpec({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.cyan, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SHOWCASE SECTION (Onglets avec Phone Preview)
// =============================================================================
class _ShowcaseSection extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final bool disableAnimations;

  const _ShowcaseSection({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.disableAnimations,
  });

  static const List<_ShowcaseTab> tabs = [
    _ShowcaseTab(
      title: 'Tuteur IA conversationnel',
      icon: Icons.chat_bubble_outline_rounded,
      accent: AppColors.cyan,
      description:
          'Le tuteur décompose vos exercices de maths, physique et informatique et vous guide pas à pas jusqu\'à comprendre le raisonnement par vous-même.',
      features: [
        'Dictée vocale pour poser vos questions à l\'oral',
        'Synthèse vocale pour écouter les explications',
        'Quiz rapides et historique des discussions sauvegardé',
        'Nécessite une connexion Internet',
      ],
      screenshot: 'assets/screenshots/tuteur_chat.png',
      caption: 'Ngenou Assistant propose un quiz rapide en algorithmique',
    ),
    _ShowcaseTab(
      title: 'Défis quotidiens et quiz',
      icon: Icons.emoji_events_outlined,
      accent: AppColors.gold,
      description:
          'Chaque jour, des QCM ciblés sur vos matières pour entretenir votre série de jours consécutifs et débloquer des trophées.',
      features: [
        'Série de jours pour garder le rythme',
        'QCM interactifs avec explication immédiate',
        'Badges et points d\'expérience (XP)',
      ],
      screenshot: 'assets/screenshots/defis_quiz.png',
      caption: 'Défi du jour : QCM d\'algorithmique avec score immédiat',
    ),
    _ShowcaseTab(
      title: 'Extensions Ngenou Assets',
      icon: Icons.extension_outlined,
      accent: AppColors.cyan,
      description:
          'Ngenou Assets est le catalogue d\'extensions de l\'application : installez uniquement les outils pédagogiques dont vous avez besoin, et retirez-les quand vous n\'en avez plus l\'usage.',
      features: [
        'Extensions légères, à installer ou désinstaller à la demande',
        'Des outils pour le primaire, le secondaire et le supérieur',
        'Classées par catégorie : outils de développement, sciences et maths',
      ],
      screenshot: 'assets/screenshots/extensions_assets.png',
      caption: 'Catalogue d\'extensions légères installables en un clic',
    ),
    _ShowcaseTab(
      title: 'Emploi du temps, alarmes et tâches',
      icon: Icons.calendar_today_outlined,
      accent: AppColors.gold,
      description:
          'Organisez vos révisions semaine par semaine, cochez vos tâches et recevez un rappel au bon moment.',
      features: [
        'Planning en grille de 7 jours, lisible d\'un coup d\'œil',
        'Alarmes et notifications d\'étude à l\'heure prévue',
        'Export et impression en PDF en un clic',
      ],
      screenshot: 'assets/screenshots/planning_emploi_du_temps.png',
      caption: 'Emploi du temps 7 jours & gestion des créneaux',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final activeTab = tabs[selectedIndex];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 72),
      decoration: const BoxDecoration(
        color: Color(0xFF070E20),
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      child: ResponsiveContainer(
        child: Column(
          children: [
            // Titre de section
            Text(
              'Quatre outils, une seule application.',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choisissez un module pour voir comment il se présente sur votre téléphone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),

            // Contenu
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: List.generate(tabs.length, (i) {
                        return _buildTabItem(context, tabs[i], i);
                      }),
                    ),
                  ),
                  const SizedBox(width: 48),
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: PhoneMockup(
                          key: ValueKey(activeTab.screenshot),
                          imagePath: activeTab.screenshot,
                          caption: activeTab.caption,
                          width: 280,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  // Onglets en accordéon / liste
                  ...List.generate(tabs.length, (i) {
                    final tab = tabs[i];
                    final isSelected = selectedIndex == i;
                    return Column(
                      children: [
                        _buildTabItem(context, tab, i),
                        if (isSelected) ...[
                          const SizedBox(height: 24),
                          Center(
                            child: PhoneMockup(
                              imagePath: tab.screenshot,
                              caption: tab.caption,
                              width: 250,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ],
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, _ShowcaseTab tab, int index) {
    final isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => onTabChanged(index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.cardHover : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? tab.accent : AppColors.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: tab.accent.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tab.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(tab.icon, color: tab.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      tab.title,
                      style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.text : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(height: 16),
                Text(
                  tab.description,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                ...tab.features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: tab.accent, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowcaseTab {
  final String title;
  final IconData icon;
  final Color accent;
  final String description;
  final List<String> features;
  final String screenshot;
  final String caption;

  const _ShowcaseTab({
    required this.title,
    required this.icon,
    required this.accent,
    required this.description,
    required this.features,
    required this.screenshot,
    required this.caption,
  });
}

// =============================================================================
// BENTO FEATURES SECTION
// =============================================================================
class _BentoFeaturesSection extends StatelessWidget {
  final bool disableAnimations;

  const _BentoFeaturesSection({
    super.key,
    required this.disableAnimations,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: ResponsiveContainer(
        child: Column(
          children: [
            Text(
              'Pensé pour réviser partout, même quand le réseau lâche.',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Vos cours et votre planning vous suivent partout. Le tuteur vous rejoint dès que vous êtes en ligne.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 54),

            // Bento Layout
            if (isDesktop)
              Column(
                children: [
                  Row(
                    children: const [
                      Expanded(
                        flex: 6,
                        child: _BentoCard(
                          icon: Icons.bolt_rounded,
                          accent: AppColors.cyan,
                          title: 'Vos cours restent avec vous',
                          body:
                              'Cours, synthèses, planning et tâches sont enregistrés sur votre téléphone. Révisez dans le bus ou en coupure de réseau : seul le tuteur IA a besoin d\'une connexion.',
                          extraWidget: _SyncNodeVisual(),
                        ),
                      ),
                      SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: _BentoCard(
                          icon: Icons.shield_rounded,
                          accent: AppColors.cyan,
                          title: 'Vos données restent les vôtres',
                          body:
                              'Dès que vous êtes en ligne, vos données sont sauvegardées de façon chiffrée et rattachées à votre seul compte. Vous pouvez les supprimer à tout moment.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      Expanded(
                        flex: 4,
                        child: _BentoCard(
                          icon: Icons.lightbulb_rounded,
                          accent: AppColors.gold,
                          title: 'Il questionne, vous trouvez',
                          body:
                              'Le tuteur ne fait pas vos devoirs : il pose les questions qui font venir le déclic.',
                          quote: '« C\'est en se trompant qu\'on apprend ! »',
                        ),
                      ),
                      SizedBox(width: 24),
                      Expanded(
                        flex: 6,
                        child: _BentoCard(
                          icon: Icons.phone_android_rounded,
                          accent: AppColors.gold,
                          title: 'Une interface claire, des premiers pas guidés',
                          body:
                              'Mode sombre, badges de progression et bulles d\'aide que vous pouvez relancer à tout moment pour découvrir l\'application sans stress.',
                          screenshot: 'assets/screenshots/defis_quiz.png',
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                children: const [
                  _BentoCard(
                    icon: Icons.bolt_rounded,
                    accent: AppColors.cyan,
                    title: 'Vos cours restent avec vous',
                    body:
                        'Cours, synthèses, planning et tâches sont enregistrés sur votre téléphone. Révisez dans le bus ou en coupure de réseau : seul le tuteur IA a besoin d\'une connexion.',
                    extraWidget: _SyncNodeVisual(),
                  ),
                  SizedBox(height: 20),
                  _BentoCard(
                    icon: Icons.shield_rounded,
                    accent: AppColors.cyan,
                    title: 'Vos données restent les vôtres',
                    body:
                        'Dès que vous êtes en ligne, vos données sont sauvegardées de façon chiffrée et rattachées à votre seul compte. Vous pouvez les supprimer à tout moment.',
                  ),
                  SizedBox(height: 20),
                  _BentoCard(
                    icon: Icons.lightbulb_rounded,
                    accent: AppColors.gold,
                    title: 'Il questionne, vous trouvez',
                    body:
                        'Le tuteur ne fait pas vos devoirs : il pose les questions qui font venir le déclic.',
                    quote: '« C\'est en se trompant qu\'on apprend ! »',
                  ),
                  SizedBox(height: 20),
                  _BentoCard(
                    icon: Icons.phone_android_rounded,
                    accent: AppColors.gold,
                    title: 'Une interface claire, des premiers pas guidés',
                    body:
                        'Mode sombre, badges de progression et bulles d\'aide que vous pouvez relancer à tout moment pour découvrir l\'application sans stress.',
                    screenshot: 'assets/screenshots/defis_quiz.png',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final String? quote;
  final String? screenshot;
  final Widget? extraWidget;

  const _BentoCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    this.quote,
    this.screenshot,
    this.extraWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.fraunces(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          if (quote != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: accent, width: 3),
                ),
              ),
              child: Text(
                quote!,
                style: TextStyle(
                  color: accent,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (extraWidget != null) ...[
            const SizedBox(height: 24),
            extraWidget!,
          ],
          if (screenshot != null) ...[
            const SizedBox(height: 24),
            Center(
              child: PhoneMockup(
                imagePath: screenshot!,
                width: 220,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncNodeVisual extends StatelessWidget {
  const _SyncNodeVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF070E20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.phone_android_rounded, color: AppColors.cyan, size: 18),
              SizedBox(width: 8),
              Text(
                'Téléphone',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 32,
                height: 1.5,
                color: AppColors.cyan.withValues(alpha: 0.5),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'sync auto',
                  style: TextStyle(color: AppColors.cyan, fontSize: 11),
                ),
              ),
              Container(
                width: 32,
                height: 1.5,
                color: AppColors.cyan.withValues(alpha: 0.5),
              ),
            ],
          ),
          Row(
            children: const [
              Icon(Icons.cloud_done_rounded, color: AppColors.gold, size: 18),
              SizedBox(width: 8),
              Text(
                'Compte sécurisé',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DOWNLOAD CTA SECTION
// =============================================================================
class _DownloadCtaSection extends StatelessWidget {
  final bool disableAnimations;

  const _DownloadCtaSection({
    required this.disableAnimations,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: ResponsiveContainer(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 56 : 28,
            vertical: isDesktop ? 48 : 36,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F1E3D), Color(0xFF0B1428)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withValues(alpha: 0.08),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: isDesktop
              ? Row(
                  children: [
                    Image.asset(
                      'assets/images/logo_full.png',
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 48),
                    Expanded(child: _buildCtaContent()),
                  ],
                )
              : Column(
                  children: [
                    Image.asset(
                      'assets/images/logo_full.png',
                      width: 180,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 24),
                    _buildCtaContent(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCtaContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gardez vos révisions dans votre poche.',
          style: GoogleFonts.fraunces(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Créez votre profil, choisissez votre niveau et lancez votre premier quiz en quelques minutes.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 15,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        const DownloadButton(),
      ],
    );
  }
}

// =============================================================================
// FAQ SECTION (Accordéon)
// =============================================================================
class _FaqSection extends StatefulWidget {
  final bool disableAnimations;

  const _FaqSection({
    super.key,
    required this.disableAnimations,
  });

  @override
  State<_FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<_FaqSection> {
  final Set<int> _expandedIndices = {0};

  static const List<_FaqItem> items = [
    _FaqItem(
      question: 'Puis-je utiliser Ngenou sans connexion Internet ?',
      answer:
          'En grande partie. Vos fiches de cours, vos extensions installées, votre planning et vos tâches restent accessibles sans connexion. Seul le tuteur IA a besoin d\'Internet. Dès que vous retrouvez du réseau, vos données sont sauvegardées automatiquement.',
    ),
    _FaqItem(
      question: 'Comment sont traitées mes questions posées au tuteur IA ?',
      answer:
          'Vos questions sont envoyées de façon sécurisée à nos modèles pédagogiques, ce qui demande une connexion Internet. Vos échanges ne sont jamais utilisés pour entraîner des modèles publics et vous pouvez effacer votre historique de discussion à tout instant.',
    ),
    _FaqItem(
      question: 'Comment puis-je supprimer définitivement mon compte et mes données ?',
      answer:
          'Un bouton « Supprimer définitivement mon compte » est disponible dans les Paramètres de l\'application. Il efface immédiatement vos données sur votre téléphone ainsi que toutes vos données sauvegardées en ligne.',
    ),
    _FaqItem(
      question: 'Quels niveaux scolaires sont pris en charge ?',
      answer:
          'Ngenou s\'adapte au niveau défini dans votre profil : primaire, secondaire (collège et lycée) et enseignement supérieur / universitaire. Le ton, les exemples et la profondeur des explications du tuteur sont automatiquement ajustés.',
    ),
  ];

  void _toggle(int index) {
    setState(() {
      if (_expandedIndices.contains(index)) {
        _expandedIndices.remove(index);
      } else {
        _expandedIndices.add(index);
      }
    });
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri.parse('mailto:ngenou.support@gmail.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: ResponsiveContainer(
        child: Column(
          children: [
            Text(
              'Questions fréquentes',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Une autre question ? Écrivez-nous à ',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
                InkWell(
                  onTap: _openSupportEmail,
                  child: const Text(
                    'ngenou.support@gmail.com',
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Liste de questions
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  final isExpanded = _expandedIndices.contains(i);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isExpanded
                              ? AppColors.cyan.withValues(alpha: 0.5)
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ExpansionTile(
                          key: Key('faq_$i'),
                          initiallyExpanded: isExpanded,
                          onExpansionChanged: (_) => _toggle(i),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          iconColor: AppColors.cyan,
                          collapsedIconColor: AppColors.textMuted,
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 8,
                          ),
                          title: Text(
                            item.question,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                              child: Text(
                                item.answer,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 14,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}
