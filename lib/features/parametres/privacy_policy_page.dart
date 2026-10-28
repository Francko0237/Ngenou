import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyPage extends StatefulWidget {
  final int initialTab;
  const PrivacyPolicyPage({super.key, this.initialTab = 0});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const String publicPolicyUrl = 'https://ngenou.app/privacy';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyPublicUrl() {
    Clipboard.setData(const ClipboardData(text: publicPolicyUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Lien public officiel copié dans le presse-papier !',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFF6C63FF) : const Color(0xFF4A90D9);
    final bg = isDark ? const Color(0xFF101B3A) : const Color(0xFFF8F9FA);
    final cardBg = isDark ? const Color(0xFF162544) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderCol = isDark
        ? const Color(0xFF2A3D66)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mentions légales & Confidentialité',
          style: GoogleFonts.outfit(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Copier le lien public',
            icon: Icon(Icons.share_rounded, color: primary, size: 20),
            onPressed: _copyPublicUrl,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          indicatorWeight: 3,
          labelColor: primary,
          unselectedLabelColor: textSecondary,
          labelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Confidentialité'),
            Tab(text: "Conditions d'usage (CGU)"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrivacyTab(
            isDark: isDark,
            primary: primary,
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderCol: borderCol,
          ),
          _buildTermsTab(
            isDark: isDark,
            primary: primary,
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderCol: borderCol,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyTab({
    required bool isDark,
    required Color primary,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderCol,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      children: [
        _buildHeaderCard(
          isDark: isDark,
          primary: primary,
          cardBg: cardBg,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          title: 'Politique de Confidentialité de Ngenou',
          date: 'Dernière mise à jour : 28 octobre 2026',
          badgeText: 'Conforme RGPD & Exigences Stores (Google & Apple)',
          description:
              'Chez Ngenou, nous accordons une importance primordiale au respect de votre vie privée et de vos données d\'apprentissage. La présente Politique explique de manière transparente quelles données nous collectons, comment nous les protégeons et comment vous pouvez exercer vos droits (y compris la suppression totale et immédiate de votre compte).',
        ),
        const SizedBox(height: 16),
        _buildClauseCard(
          icon: Icons.business_center_rounded,
          iconColor: const Color(0xFF3B82F6),
          title: '1. Éditeur et Responsable de traitement',
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          content:
              'L\'application mobile Ngenou est développée et éditée par :\n\n'
              '• Développeur / Responsable : Yamgai Mokube Franck Daniel\n'
              '• Contact Support & DPO : support@ngenou.app\n'
              '• Site officiel : https://ngenou.app\n\n'
              'Ngenou respecte les réglementations applicables en matière de protection des données personnelles (Règlement Général sur la Protection des Données - RGPD UE 2016/679 et directives de l\'App Store d\'Apple et Google Play).',
        ),
        const SizedBox(height: 14),
        _buildClauseCard(
          icon: Icons.storage_rounded,
          iconColor: const Color(0xFF10B981),
          title: '2. Données collectées et finalités',
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          content:
              'Nous collectons uniquement les informations strictement nécessaires au bon fonctionnement de votre tuteur éducatif :\n\n'
              '• Données de compte : pseudonyme/nom affiché, numéro de téléphone (utilisé sous forme d\'identifiant interne sécurisé), adresse email (si connexion via email ou Google OAuth), rôle (élève, enseignant) et niveau scolaire (primaire, secondaire, supérieur).\n'
              '• Données d\'apprentissage : cours personnalisés créés ou importés, quiz et scores de défis quotidiens, tâches de révision planifiées, historique des projets et codes algorithmiques sauvegardés.\n'
              '• Interactions avec le tuteur IA : questions posées et réponses pédagogiques générées. Ces échanges permettent la continuité pédagogique au fil de vos révisions.\n'
              '• Données techniques & autorisations matérielles :\n'
              '   - Microphone (Speech-to-Text) : uniquement activé lorsque vous appuyez explicitement sur le bouton vocal pour dicter votre question à l\'IA. Aucun enregistrement n\'est conservé après transcription.\n'
              '   - Synthèse vocale & Haut-parleurs (TTS) : pour la lecture audio des explications de cours et le déclenchement des alarmes d\'étude.\n'
              '   - Stockage local (SQLite) : pour garantir un fonctionnement hors-ligne à 100% sans connexion Internet.',
        ),
        const SizedBox(height: 14),
        _buildClauseCard(
          icon: Icons.psychology_rounded,
          iconColor: const Color(0xFF8B5CF6),
          title: '3. Traitement des données par Intelligence Artificielle',
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          content:
              'Les prompts et questions d\'apprentissage que vous soumettez au tuteur IA sont transmis de manière chiffrée (HTTPS/TLS) aux modèles de langage (DeepSeek / Gemini API) via notre passerelle sécurisée.\n\n'
              '• Aucune donnée personnelle d\'identification (votre nom complet ou email) n\'est envoyée aux modèles tiers.\n'
              '• Vos questions et vos cours ne sont PAS utilisés pour entraîner des modèles publics.\n'
              '• Vous pouvez effacer l\'historique de vos conversations avec l\'IA à tout moment depuis les options de discussion ou les paramètres.',
        ),
        const SizedBox(height: 14),
        _buildClauseCard(
          icon: Icons.cloud_sync_rounded,
          iconColor: const Color(0xFFF59E0B),
          title: '4. Hébergement et Synchronisation Cloud',
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          content:
              'Ngenou utilise une architecture "Offline-First" avec synchronisation conditionnelle :\n\n'
              '• En mode déconnecté : toutes vos données sont stockées localement et chiffrées sur votre appareil via SQLite.\n'
              '• En mode connecté : les données sont sauvegardées sur notre infrastructure Supabase hébergée sur des serveurs sécurisés bénéficiant des certifications SOC 2 et ISO 27001.\n'
              '• Isolation absolue : grâce aux politiques de sécurité Row Level Security (RLS) au niveau de la base de données, chaque utilisateur ne peut accéder qu\'à ses propres données.',
        ),
        const SizedBox(height: 14),
        _buildClauseCard(
          icon: Icons.delete_forever_rounded,
          iconColor: const Color(0xFFEF4444),
          title: '5. Suppression définitive du compte et des données',
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          content:
              'Conformément aux exigences strictes de l\'Apple App Store (Directive 5.1.1(v)) et de Google Play Store :\n\n'
              '• Tout utilisateur peut initier la suppression immédiate et définitive de son compte directement depuis l\'application (Paramètres > Supprimer mon compte).\n'
              '• Cette action purge instantanément l\'ensemble de vos données de la base locale et supprime vos enregistrements de nos serveurs distants (historiques de tchat, scores, cours personnalisés, progression, alertes).\n'
              '• Cette opération est irréversible.',
        ),
        const SizedBox(height: 14),
        _buildClauseCard(
          icon: Icons.verified_user_rounded,
          iconColor: const Color(0xFF06B6D4),
          title: '6. Vos droits (RGPD)',
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          content:
              'Vous disposez des droits d\'accès, de rectification, de portabilité et de suppression de vos données personnelles.\n\n'
              'Pour toute question ou demande concernant vos données personnelles, écrivez-nous directement à : support@ngenou.app.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTermsTab({
    required bool isDark,
    required Color primary,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderCol,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      children: [
        _buildHeaderCard(
          isDark: isDark,
          primary: primary,
          cardBg: cardBg,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          title: "Conditions Générales d'Utilisation (CGU)",
          date: 'Applicable au : 28 octobre 2026',
          badgeText: 'Contrat d\'utilisation de l\'application Ngenou',
          description:
              'En installant et en utilisant l\'application mobile Ngenou, vous acceptez sans réserve les présentes Conditions Générales d\'Utilisation.',
        ),
        const SizedBox(height: 16),
        _buildClauseCard(
          icon: Icons.school_rounded,
          iconColor: const Color(0xFF6C63FF),
          title: '1. Objet du service',
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          content:
              'Ngenou est une application d\'apprentissage intelligent conçue pour accompagner les élèves et étudiants dans leurs révisions scolaires et universitaires.\n\n'
              'Elle met à disposition un tuteur d\'intelligence artificielle, des résumés de cours, des défis quotidiens, un simulateur algorithmique et un planificateur d\'emploi du temps.',
        ),
        const SizedBox(height: 14),
        _buildClauseCard(
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFF59E0B),
          title: '2. Responsabilité pédagogique & Décharge IA',
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          content:
              '• Les réponses et explications fournies par le tuteur IA constituent un outil d\'assistance pédagogique d\'appoint.\n'
              '• Bien que notre technologie vise la plus haute exactitude mathématique et méthodologique, l\'utilisateur est encouragé à croiser les réponses avec ses manuels scolaires et les enseignements de ses professeurs officiels.\n'
              '• L\'éditeur ne pourra être tenu responsable des éventuelles erreurs factuelles générées par les modèles d\'IA.',
        ),
        const SizedBox(height: 14),
        _buildClauseCard(
          icon: Icons.shield_rounded,
          iconColor: const Color(0xFF10B981),
          title: '3. Utilisation acceptable',
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          content:
              'L\'utilisateur s\'engage à :\n\n'
              '• Ne pas soumettre de contenu illégal, injurieux ou inapproprié au tuteur d\'IA.\n'
              '• Ne pas tenter de contourner les mécanismes de sécurité, quotas d\'API ou de surcharger les serveurs de synchronisation.\n'
              '• Conserver la confidentialité de ses identifiants de connexion.',
        ),
        const SizedBox(height: 14),
        _buildClauseCard(
          icon: Icons.copyright_rounded,
          iconColor: const Color(0xFF3B82F6),
          title: '4. Propriété intellectuelle',
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          content:
              'Tous les éléments graphiques, marques, logos, algorithmes et architectures applicatives de Ngenou demeurent la propriété exclusive de Yamgai Mokube Franck Daniel.\n\n'
              'Les notes, exercices et synthèses générés par l\'utilisateur lui appartiennent de plein droit.',
        ),
        const SizedBox(height: 14),
        _buildClauseCard(
          icon: Icons.gavel_rounded,
          iconColor: const Color(0xFF8B5CF6),
          title: '5. Loi applicable et juridiction',
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          content:
              'Les présentes CGU sont régies par les lois applicables au territoire de publication et aux règlements internationaux de protection des consommateurs. Tout litige relatif à leur interprétation relèvera des tribunaux compétents.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeaderCard({
    required bool isDark,
    required Color primary,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required String title,
    required String date,
    required String badgeText,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              badgeText,
              style: GoogleFonts.outfit(
                color: primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style: GoogleFonts.outfit(
              color: textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: GoogleFonts.outfit(
              color: textPrimary.withValues(alpha: 0.9),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClauseCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required Color cardBg,
    required Color borderCol,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.outfit(
              color: textSecondary,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
