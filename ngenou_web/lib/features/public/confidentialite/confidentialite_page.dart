import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/site_footer.dart';
import '../../../core/widgets/site_navbar.dart';

/// Page légale : Politique de confidentialité & CGU (/confidentialite)
class ConfidentialitePage extends StatefulWidget {
  const ConfidentialitePage({super.key});

  @override
  State<ConfidentialitePage> createState() => _ConfidentialitePageState();
}

class _ConfidentialitePageState extends State<ConfidentialitePage> {
  final GlobalKey _privacyKey = GlobalKey();
  final GlobalKey _dataKey = GlobalKey();
  final GlobalKey _syncKey = GlobalKey();
  final GlobalKey _deletionKey = GlobalKey();
  final GlobalKey _cguKey = GlobalKey();

  int _activeSectionIndex = 0;

  void _scrollTo(GlobalKey key, int index) {
    setState(() => _activeSectionIndex = index);
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _openEmail() async {
    final uri = Uri.parse('mailto:ngenou.support@gmail.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SiteNavbar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero légal
            Container(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 40 : 64,
                horizontal: Responsive.horizontalPadding(context),
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF070E20),
                border: Border(
                  bottom: BorderSide(color: AppColors.cardBorder, width: 1),
                ),
              ),
              child: ResponsiveContainer(
                child: Column(
                  children: [
                    Text(
                      'Politique de confidentialité et CGU',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fraunces(
                        fontSize: isMobile ? 30 : 44,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Dernière mise à jour : 28 octobre 2026. Application Ngenou, version 1.1.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Contenu principal avec sommaire
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 56),
              child: ResponsiveContainer(
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sommaire latéral collant
                          SizedBox(
                            width: 280,
                            child: _buildSidebar(),
                          ),
                          const SizedBox(width: 48),
                          // Articles
                          Expanded(
                            child: _buildArticlesList(),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildSidebarHorizontal(),
                          const SizedBox(height: 36),
                          _buildArticlesList(),
                        ],
                      ),
              ),
            ),

            const SiteFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SOMMAIRE',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          _TocButton(
            title: '1. Responsable du traitement',
            isActive: _activeSectionIndex == 0,
            onTap: () => _scrollTo(_privacyKey, 0),
          ),
          _TocButton(
            title: '2. Données collectées',
            isActive: _activeSectionIndex == 1,
            onTap: () => _scrollTo(_dataKey, 1),
          ),
          _TocButton(
            title: '3. Synchronisation & sécurité',
            isActive: _activeSectionIndex == 2,
            onTap: () => _scrollTo(_syncKey, 2),
          ),
          _TocButton(
            title: '4. Suppression du compte',
            isActive: _activeSectionIndex == 3,
            onTap: () => _scrollTo(_deletionKey, 3),
          ),
          _TocButton(
            title: '5. Conditions d\'utilisation',
            isActive: _activeSectionIndex == 4,
            onTap: () => _scrollTo(_cguKey, 4),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHorizontal() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _TocChip(
            title: '1. Responsable',
            isActive: _activeSectionIndex == 0,
            onTap: () => _scrollTo(_privacyKey, 0),
          ),
          const SizedBox(width: 8),
          _TocChip(
            title: '2. Données',
            isActive: _activeSectionIndex == 1,
            onTap: () => _scrollTo(_dataKey, 1),
          ),
          const SizedBox(width: 8),
          _TocChip(
            title: '3. Sécurité',
            isActive: _activeSectionIndex == 2,
            onTap: () => _scrollTo(_syncKey, 2),
          ),
          const SizedBox(width: 8),
          _TocChip(
            title: '4. Suppression',
            isActive: _activeSectionIndex == 3,
            onTap: () => _scrollTo(_deletionKey, 3),
          ),
          const SizedBox(width: 8),
          _TocChip(
            title: '5. CGU',
            isActive: _activeSectionIndex == 4,
            onTap: () => _scrollTo(_cguKey, 4),
          ),
        ],
      ),
    );
  }

  Widget _buildArticlesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Article 1
        _LegalArticle(
          key: _privacyKey,
          icon: Icons.person_outline_rounded,
          accent: AppColors.cyan,
          number: '1',
          title: 'Responsable du traitement des données',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'L\'application mobile Ngenou est éditée par Yamga Mokube Franck Daniel.',
                style: TextStyle(color: AppColors.text, height: 1.6),
              ),
              const SizedBox(height: 12),
              Wrap(
                children: [
                  const Text(
                    'Pour toute question relative à la protection de votre vie privée ou pour exercer vos droits légaux (accès, rectification, suppression), vous pouvez nous contacter directement par courriel à : ',
                    style: TextStyle(color: AppColors.textMuted, height: 1.6),
                  ),
                  InkWell(
                    onTap: _openEmail,
                    child: const Text(
                      'ngenou.support@gmail.com',
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Text(
                    '.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Article 2
        _LegalArticle(
          key: _dataKey,
          icon: Icons.storage_rounded,
          accent: AppColors.gold,
          number: '2',
          title: 'Données collectées et finalités',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Ngenou collecte et traite uniquement les données strictement nécessaires aux services d\'apprentissage :',
                style: TextStyle(color: AppColors.text, height: 1.6),
              ),
              SizedBox(height: 14),
              _BulletPoint(
                title: 'Données de compte : ',
                body:
                    'Pseudonyme / nom choisi, adresse email (si connexion via email ou Google Sign-In) ou numéro de téléphone (utilisé sous forme d\'identifiant chiffré), rôle (élève, enseignant) et niveau scolaire (primaire, secondaire, supérieur).',
              ),
              _BulletPoint(
                title: 'Contenu éducatif : ',
                body:
                    'Cours personnalisés créés ou importés, défis quotidiens, scores aux quiz, fiches de révision et codes algorithmiques sauvegardés.',
              ),
              _BulletPoint(
                title: 'Interactions avec le tuteur IA : ',
                body:
                    'Les questions et prompts posés au tuteur sont traités pour délivrer des explications pédagogiques socratiques. Ces données restent privées et ne sont jamais vendues ni utilisées pour entraîner des modèles publics tiers.',
              ),
              _BulletPoint(
                title: 'Autorisations matérielles : ',
                body:
                    '• Microphone : Activé exclusivement à la demande de l\'utilisateur pour la saisie vocale (Speech-to-Text). Aucun flux audio continu n\'est enregistré.\n• Haut-parleur et audio : Pour la synthèse vocale (TTS) des cours et les alarmes d\'étude.\n• Stockage local : Base locale chiffrée permettant à l\'application de fonctionner sans connexion Internet.',
              ),
            ],
          ),
        ),

        // Article 3
        _LegalArticle(
          key: _syncKey,
          icon: Icons.cloud_done_outlined,
          accent: AppColors.cyan,
          number: '3',
          title: 'Synchronisation cloud et sécurité',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Ngenou adopte une philosophie Offline-First :',
                style: TextStyle(color: AppColors.text, height: 1.6),
              ),
              SizedBox(height: 14),
              _BulletPoint(
                title: 'Stockage local prioritaire : ',
                body:
                    'Toutes vos données sont prioritairement stockées localement sur votre appareil dans une base de données chiffrée.',
              ),
              _BulletPoint(
                title: 'Chiffrement de bout en bout : ',
                body:
                    'Lorsque vous disposez d\'une connexion Internet et d\'un compte actif, vos données sont synchronisées via notre infrastructure cloud sécurisée avec chiffrement TLS et politiques strictes d\'accès garantissant que seul votre compte a accès à vos données.',
              ),
            ],
          ),
        ),

        // Article 4
        _LegalArticle(
          key: _deletionKey,
          icon: Icons.delete_outline_rounded,
          accent: AppColors.gold,
          number: '4',
          title: 'Droit à l\'effacement et suppression définitive du compte',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Conformément aux directives de l\'Apple App Store (Guideline 5.1.1(v)) et aux standards internationaux de protection de la vie privée :',
                style: TextStyle(color: AppColors.text, height: 1.6),
              ),
              const SizedBox(height: 14),
              const Text(
                'Chaque utilisateur peut à tout moment supprimer l\'intégralité de son compte et de ses données personnelles :',
                style: TextStyle(color: AppColors.textMuted, height: 1.6),
              ),
              const SizedBox(height: 12),
              const _BulletPoint(
                title: 'Directement dans l\'application : ',
                body:
                    'Ouvrez l\'onglet Paramètres > Faites défiler jusqu\'en bas > Cliquez sur « Supprimer définitivement mon compte ».',
              ),
              const _BulletPoint(
                title: 'Effacement immédiat : ',
                body:
                    'Cette action entraîne la suppression instantanée et irréversible de l\'ensemble de vos données locales et de tous vos enregistrements sur les serveurs distants.',
              ),
              Wrap(
                children: [
                  const Text(
                    'Vous pouvez également formuler une demande de suppression par email à ',
                    style: TextStyle(color: AppColors.textMuted, height: 1.6),
                  ),
                  InkWell(
                    onTap: _openEmail,
                    child: const Text(
                      'ngenou.support@gmail.com',
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Text(
                    '. Votre demande sera traitée sous 48 heures ouvrées.',
                    style: TextStyle(color: AppColors.textMuted, height: 1.6),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Article 5
        _LegalArticle(
          key: _cguKey,
          icon: Icons.description_outlined,
          accent: AppColors.cyan,
          number: '5',
          title: 'Conditions Générales d\'Utilisation (CGU)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'L\'utilisation de Ngenou implique l\'acceptation pleine et entière des présentes conditions :',
                style: TextStyle(color: AppColors.text, height: 1.6),
              ),
              SizedBox(height: 14),
              _BulletPoint(
                title: 'Service d\'appoint éducatif : ',
                body:
                    'Le tuteur IA est un compagnon pédagogique destiné à faciliter la compréhension. Bien qu\'optimisé pour une exactitude maximale, l\'utilisateur est invité à vérifier les résultats avec ses supports de cours officiels.',
              ),
              _BulletPoint(
                title: 'Comportement acceptable : ',
                body:
                    'Il est strictement interdit d\'utiliser le tuteur IA à des fins illicites, haineuses ou de tentative d\'exploitation technique des serveurs.',
              ),
              _BulletPoint(
                title: 'Propriété intellectuelle : ',
                body:
                    'L\'architecture, la marque, les logos et les modules logiciels de Ngenou sont la propriété exclusive de Yamga Mokube Franck Daniel.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TocButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _TocButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.cyan.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isActive ? AppColors.cyan : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? AppColors.cyan : AppColors.textMuted,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _TocChip extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _TocChip({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(title),
      backgroundColor: isActive ? AppColors.cyan : AppColors.card,
      labelStyle: TextStyle(
        color: isActive ? AppColors.background : AppColors.text,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      side: const BorderSide(color: AppColors.cardBorder),
      onPressed: onTap,
    );
  }
}

class _LegalArticle extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String number;
  final String title;
  final Widget child;

  const _LegalArticle({
    super.key,
    required this.icon,
    required this.accent,
    required this.number,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '$number. $title',
                  style: GoogleFonts.fraunces(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String title;
  final String body;

  const _BulletPoint({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            height: 1.6,
          ),
          children: [
            TextSpan(
              text: title,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: body),
          ],
        ),
      ),
    );
  }
}
