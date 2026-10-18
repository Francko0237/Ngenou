import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/ngenou_extension.dart';
import '../../core/services/extensions_service.dart';
import '../../core/widgets/connection_status_indicator.dart';

class ExtensionsManagerPage extends StatefulWidget {
  const ExtensionsManagerPage({super.key});

  @override
  State<ExtensionsManagerPage> createState() => _ExtensionsManagerPageState();
}

class _ExtensionsManagerPageState extends State<ExtensionsManagerPage> {
  String _selectedCategory = 'Tous';
  String _searchQuery = '';
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

  Future<void> _handleInstall(NgenouExtension ext) async {
    setState(() => _pendingActions.add(ext.id));
    final service = context.read<ExtensionsService>();
    final success = await service.installExtension(ext);
    if (mounted) {
      setState(() => _pendingActions.remove(ext.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Extension "${ext.nom}" installée avec succès !'
                : 'Échec de l\'installation de "${ext.nom}".',
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Désinstaller l\'extension'),
        content: Text('Voulez-vous vraiment désinstaller "${ext.nom}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Désinstaller'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _pendingActions.add(ext.id));
    final service = context.read<ExtensionsService>();
    final success = await service.uninstallExtension(ext.id);
    if (mounted) {
      setState(() => _pendingActions.remove(ext.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Extension "${ext.nom}" désinstallée.'
                : 'Erreur lors de la désinstallation.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final service = context.watch<ExtensionsService>();

    final categories = ['Tous'];
    for (final ext in service.extensions) {
      if (!categories.contains(ext.categorie)) {
        categories.add(ext.categorie);
      }
    }

    final filtered = service.extensions.where((ext) {
      final matchCat =
          _selectedCategory == 'Tous' || ext.categorie == _selectedCategory;
      final matchSearch =
          _searchQuery.isEmpty ||
          ext.nom.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          ext.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0E0E12)
          : const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Ngenou Assets',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        centerTitle: false,
        actions: [
          // Point de connexion + bouton actualiser
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ConnectionStatusIndicator(),
              IconButton(
                tooltip: 'Actualiser depuis GitHub',
                icon: service.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                onPressed: service.isLoading
                    ? null
                    : () => service.loadExtensions(forceRefresh: true),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16161E) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Rechercher une extension, un simulateur...',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.35),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF0F1F5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filtres de catégories
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white,
                    selectedColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.08)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Liste des extensions
          Expanded(
            child: service.isLoading && service.extensions.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.extension_off_rounded,
                          size: 56,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Aucune extension trouvée',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Essayez de modifier vos filtres ou de rafraîchir',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => service.loadExtensions(forceRefresh: true),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ext = filtered[index];
                        final isPending = _pendingActions.contains(ext.id);
                        return _ExtensionCard(
                          extension: ext,
                          isPending: isPending,
                          onInstall: () => _handleInstall(ext),
                          onUninstall: () => _handleUninstall(ext),
                          onOpen: () => context.push('/extensions/host/${ext.id}'),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionCard extends StatelessWidget {
  final NgenouExtension extension;
  final bool isPending;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;
  final VoidCallback onOpen;

  const _ExtensionCard({
    required this.extension,
    required this.isPending,
    required this.onInstall,
    required this.onUninstall,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final extColor = extension.color;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181820) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: extension.isInstalled
              ? const Color(0xFF2ECC71).withValues(alpha: 0.4)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.06)),
          width: extension.isInstalled ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre et icône
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      extColor.withValues(alpha: 0.2),
                      extColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: extColor.withValues(alpha: 0.35)),
                ),
                child: Icon(extension.icon, color: extColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            extension.nom,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (extension.isInstalled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2ECC71,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 13,
                                  color: Color(0xFF2ECC71),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Installée',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF2ECC71),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v${extension.version} • ${extension.taille}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            extension.description,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.black.withValues(alpha: 0.75),
            ),
          ),

          const SizedBox(height: 14),

          // Badges de niveaux et catégorie
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  extension.categorie,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              ...extension.niveaux.map((lvl) {
                final displayLvl = lvl == 'primaire'
                    ? 'Primaire'
                    : lvl == 'secondaire'
                    ? 'Secondaire'
                    : 'Supérieur';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    displayLvl,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 14),

          // Bas de carte : Auteur à gauche et Actions à droite
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 15,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        extension.auteur,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (extension.isInstalled) ...[
                OutlinedButton.icon(
                  onPressed: isPending ? null : onUninstall,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: Color(0xFFE74C3C),
                  ),
                  label: const Text(
                    'Désinstaller',
                    style: TextStyle(color: Color(0xFFE74C3C), fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE74C3C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.launch_rounded, size: 16),
                  label: const Text('Ouvrir', style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: isPending ? null : onInstall,
                  icon: isPending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    isPending ? 'Installation...' : 'Installer',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
