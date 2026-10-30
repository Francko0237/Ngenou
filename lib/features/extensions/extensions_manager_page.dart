import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/ngenou_extension.dart';
import '../../core/services/extensions_service.dart';
import '../../core/widgets/connection_status_indicator.dart';

// ── Constantes visuelles harmonisées avec le design system Ngenou ────────────
const _kBgDark = Color(0xFF121216);
const _kBgLight = Color(0xFFF7F8FA);
const _kSurfaceDark = Color(0xFF1E1E26);

class ExtensionsManagerPage extends StatefulWidget {
  const ExtensionsManagerPage({super.key});

  @override
  State<ExtensionsManagerPage> createState() => _ExtensionsManagerPageState();
}

class _ExtensionsManagerPageState extends State<ExtensionsManagerPage> {
  String _selectedFilter = 'all'; // 'all', 'installed', or category name
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _pendingActions = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<ExtensionsService>();
      if (!service.isInitialized) {
        service.init();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleInstall(NgenouExtension ext) async {
    setState(() => _pendingActions.add(ext.id));
    final service = context.read<ExtensionsService>();
    final success = await service.installExtension(ext);
    if (mounted) {
      setState(() => _pendingActions.remove(ext.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  success
                      ? 'Simulateur "${ext.nom}" installé avec succès !'
                      : 'Échec du téléchargement de "${ext.nom}".',
                ),
              ),
            ],
          ),
          backgroundColor: success
              ? const Color(0xFF2ECC71)
              : const Color(0xFFE74C3C),
        ),
      );
    }
  }

  Future<void> _handleUninstall(NgenouExtension ext) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? _kSurfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Désinstaller',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            'Voulez-vous supprimer "${ext.nom}" de la mémoire locale de votre appareil ? Vous pourrez le réinstaller à tout moment.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Désinstaller', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() => _pendingActions.add(ext.id));
    final service = context.read<ExtensionsService>();
    final success = await service.uninstallExtension(ext.id);
    if (mounted) {
      setState(() => _pendingActions.remove(ext.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            success
                ? 'Atelier "${ext.nom}" désinstallé.'
                : 'Erreur lors de la désinstallation.',
          ),
        ),
      );
    }
  }

  void _showToolDetailsSheet(BuildContext context, NgenouExtension ext) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final isPending = _pendingActions.contains(ext.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? _kSurfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            16,
            22,
            MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poignée de glissement
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // En-tête avec icône gradient et titre
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ExtensionSquircleIcon(
                    extension: ext,
                    size: 54,
                    iconSize: 26,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ext.nom,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : const Color(0xFF15151C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ext.categorie} • v${ext.version}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Description complète
              Text(
                'Description & Objectif pédagogique',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ext.description,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Niveaux académiques
              Text(
                'Niveaux recommandés',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: primary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: ext.niveaux.map((lvl) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _formatNiveau(lvl),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Informations techniques (auteur, poids, mode hors-ligne)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoColumn(
                      icon: Icons.person_outline_rounded,
                      label: 'Auteur',
                      value: ext.auteur,
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildInfoColumn(
                      icon: Icons.data_usage_rounded,
                      label: 'Taille',
                      value: ext.taille,
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildInfoColumn(
                      icon: Icons.offline_bolt_rounded,
                      label: 'Exécution',
                      value: '100% Hors-ligne',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Boutons d'action
              Row(
                children: [
                  if (ext.isInstalled) ...[
                    IconButton.filledTonal(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleUninstall(ext);
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                        foregroundColor: Colors.redAccent,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Désinstaller',
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/extensions/host/${ext.id}');
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text(
                          'Lancer l\'atelier',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isPending
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _handleInstall(ext);
                              },
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: Text(
                          'Installer le simulateur (${ext.taille})',
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 32,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }

  static Widget _buildInfoColumn({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF15151C),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final service = context.watch<ExtensionsService>();

    final query = _searchController.text.trim().toLowerCase();
    final installedCount = service.extensions.where((e) => e.isInstalled).length;

    // Collecter les catégories uniques
    final categories = <String>[];
    for (final ext in service.extensions) {
      if (!categories.contains(ext.categorie)) {
        categories.add(ext.categorie);
      }
    }

    // Filtrer les extensions
    final filtered = service.extensions.where((ext) {
      final matchesFilter = switch (_selectedFilter) {
        'all' => true,
        'installed' => ext.isInstalled,
        _ => ext.categorie == _selectedFilter,
      };

      final matchesQuery = query.isEmpty ||
          ext.nom.toLowerCase().contains(query) ||
          ext.description.toLowerCase().contains(query) ||
          ext.categorie.toLowerCase().contains(query);

      return matchesFilter && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? _kBgDark : _kBgLight,
      appBar: AppBar(
        title: const Text(
          'Boîte à outils',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          const ConnectionStatusIndicator(),
          const SizedBox(width: 4),
          IconButton(
            onPressed: service.isLoading
                ? null
                : () => service.loadExtensions(forceRefresh: true),
            icon: service.isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Recherche & Filtres (Sleek & Moderne) ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Column(
                children: [
                  // Barre de recherche épurée
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFF1F3F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        fontSize: 13.5,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Rechercher un outil, un concept…',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: isDark ? Colors.white38 : Colors.black45,
                          size: 18,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  size: 16,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Filtres pills épurés
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildFilterPill(
                          id: 'all',
                          label: 'Tous (${service.extensions.length})',
                          isDark: isDark,
                          primary: primary,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          id: 'installed',
                          label: 'Installés ($installedCount)',
                          isDark: isDark,
                          primary: primary,
                        ),
                        for (final cat in categories) ...[
                          const SizedBox(width: 8),
                          _buildFilterPill(
                            id: cat,
                            label: _formatCategoryName(cat),
                            isDark: isDark,
                            primary: primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Liste / Grille des simulateurs & ateliers ───────────────────
            Expanded(
              child: service.isLoading && service.extensions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? _buildEmptyState(isDark, primary)
                      : RefreshIndicator(
                          onRefresh: () => service.loadExtensions(forceRefresh: true),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.maxWidth;
                              final isGrid = w > 820;
                              final hPad = w > 1200
                                  ? w * 0.08
                                  : w > 820
                                      ? w * 0.04
                                      : 16.0;

                              if (!isGrid) {
                                return ListView.builder(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: hPad,
                                    vertical: 6,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final ext = filtered[index];
                                    final isPending = _pendingActions.contains(ext.id);
                                    return _ToolCard(
                                      extension: ext,
                                      isPending: isPending,
                                      isDark: isDark,
                                      primary: primary,
                                      onInstall: () => _handleInstall(ext),
                                      onUninstall: () => _handleUninstall(ext),
                                      onOpen: () => context.push('/extensions/host/${ext.id}'),
                                      onShowDetails: () => _showToolDetailsSheet(context, ext),
                                    );
                                  },
                                );
                              }

                              return GridView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: hPad,
                                  vertical: 6,
                                ),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 1.62,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final ext = filtered[index];
                                  final isPending = _pendingActions.contains(ext.id);
                                  return _ToolCard(
                                    extension: ext,
                                    isPending: isPending,
                                    isDark: isDark,
                                    primary: primary,
                                    onInstall: () => _handleInstall(ext),
                                    onUninstall: () => _handleUninstall(ext),
                                    onOpen: () => context.push('/extensions/host/${ext.id}'),
                                    onShowDetails: () => _showToolDetailsSheet(context, ext),
                                  );
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCategoryName(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('développement') ||
        lower.contains('informatique') ||
        lower.contains('algo')) {
      return 'Algorithme';
    }
    if (lower.contains('math') || lower.contains('science')) {
      return 'Maths';
    }
    return cat;
  }

  Widget _buildFilterPill({
    required String id,
    required String label,
    required bool isDark,
    required Color primary,
  }) {
    final isSelected = _selectedFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF1F3F6)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04)),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF4A5568)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color primary) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.extension_off_rounded,
                size: 34,
                color: primary.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun outil trouvé',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Modifiez votre recherche ou sélectionnez une autre catégorie.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                _searchController.clear();
                setState(() => _selectedFilter = 'all');
              },
              child: const Text('Réinitialiser les filtres'),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Carte d'un outil / simulateur (Pro, épurée, intégrée au thème) ───────────

class _ToolCard extends StatelessWidget {
  final NgenouExtension extension;
  final bool isPending;
  final bool isDark;
  final Color primary;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;
  final VoidCallback onOpen;
  final VoidCallback onShowDetails;

  const _ToolCard({
    required this.extension,
    required this.isPending,
    required this.isDark,
    required this.primary,
    required this.onInstall,
    required this.onUninstall,
    required this.onOpen,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    final isInstalled = extension.isInstalled;
    final highlights = _getHighlights(extension.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? _kSurfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isInstalled
              ? primary.withValues(alpha: isDark ? 0.28 : 0.2)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.05)),
          width: isInstalled ? 1.3 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isInstalled ? onOpen : (isPending ? null : onInstall),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── En-tête : Icône squircle + Titre + Badges + Statut ───────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ExtensionSquircleIcon(
                      extension: extension,
                      size: 46,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 12),

                    // Titre, catégorie et état
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Badge de catégorie
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: isDark ? 0.16 : 0.09),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  extension.categorie,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: primary,
                                  ),
                                ),
                              ),
                              const Spacer(),

                              // Badge état : Installé ou taille
                              if (isInstalled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2ECC71).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 11,
                                        color: Color(0xFF2ECC71),
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Prêt',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2ECC71),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.black.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    extension.taille,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Nom du simulateur
                          Text(
                            extension.nom,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: isDark ? Colors.white : const Color(0xFF15151C),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // ── Description pédagogique ──────────────────────────────────
                Text(
                  extension.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.38,
                    color: isDark ? Colors.white60 : const Color(0xFF555566),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Points forts interactifs de l'atelier ────────────────────
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: highlights.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.035),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),

                // ── Bas de carte : Niveaux + Bouton d'action + Menu Détails ──
                Row(
                  children: [
                    // Niveaux d'étude
                    Text(
                      extension.niveaux.map(_formatNiveau).join(' • '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const Spacer(),

                    // Bouton Menu Plus d'options (remplace la corbeille brute)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: isDark ? Colors.white54 : Colors.black45,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 160),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      color: isDark ? _kSurfaceDark : Colors.white,
                      onSelected: (value) {
                        if (value == 'details') {
                          onShowDetails();
                        } else if (value == 'uninstall') {
                          onUninstall();
                        } else if (value == 'reinstall') {
                          onInstall();
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'details',
                          height: 38,
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16),
                              SizedBox(width: 8),
                              Text('Détails & Auteur', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        if (isInstalled) ...[
                          const PopupMenuItem(
                            value: 'reinstall',
                            height: 38,
                            child: Row(
                              children: [
                                Icon(Icons.sync_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Réinstaller', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(height: 8),
                          PopupMenuItem(
                            value: 'uninstall',
                            height: 38,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: Colors.redAccent.shade200,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Désinstaller',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.redAccent.shade200,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 4),

                    // Bouton d'action principal
                    if (isInstalled) ...[
                      FilledButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: const Text(
                          'Lancer',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ] else ...[
                      FilledButton.icon(
                        onPressed: isPending ? null : onInstall,
                        icon: isPending
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 15),
                        label: Text(
                          isPending ? 'En cours…' : 'Installer',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<String> _getHighlights(String id) {
    switch (id) {
      case 'algo_interpreter':
        return ['Console interactive', 'Pas-à-pas', 'Variables'];
      case 'math_fractions_visualizer':
        return ['Disques & Réglettes', 'Équivalences', 'Calculs visuels'];
      case 'math_nombres_relatifs':
        return ['Droite graduée', 'Thermomètre', 'Opérations guidées'];
      case 'math_conversion_unites':
        return ['Longueurs & Masses', 'Aires & Capacités', 'Puissances de 10'];
      default:
        return ['Simulateur interactif', 'Pratique autonome'];
    }
  }
}

// ── Icône Squircle à gradient harmonieux ──────────────────────────────────────

class _ExtensionSquircleIcon extends StatelessWidget {
  final NgenouExtension extension;
  final double size;
  final double iconSize;

  const _ExtensionSquircleIcon({
    required this.extension,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = _getCuratedGradient(extension.id);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          extension.icon,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }

  static List<Color> _getCuratedGradient(String id) {
    switch (id) {
      case 'algo_interpreter':
        return const [Color(0xFF059669), Color(0xFF10B981)]; // Emerald / Teal
      case 'math_fractions_visualizer':
        return const [Color(0xFFD97706), Color(0xFFF59E0B)]; // Warm Amber
      case 'math_nombres_relatifs':
        return const [Color(0xFF2563EB), Color(0xFF3B82F6)]; // Royal Blue
      case 'math_conversion_unites':
        return const [Color(0xFF0D9488), Color(0xFF14B8A6)]; // Modern Cyan
      default:
        return const [Color(0xFF6366F1), Color(0xFF8B5CF6)]; // Violet
    }
  }
}

String _formatNiveau(String lvl) {
  return switch (lvl.toLowerCase()) {
    'primaire' => 'Primaire',
    'college' => 'Collège',
    'lycee' => 'Lycée',
    'superieur' => 'Supérieur',
    'secondaire' => 'Secondaire',
    _ => lvl,
  };
}
