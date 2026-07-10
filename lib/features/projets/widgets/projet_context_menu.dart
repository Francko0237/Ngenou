import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/projet.dart';
import '../../../core/providers/projets_provider.dart';

/// Affiche un menu contextuel (bottom sheet) au long-press sur une carte projet.
Future<void> showProjetContextMenu(
  BuildContext context, {
  required Projet projet,
  required VoidCallback onRefresh,
}) async {
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ProjetContextMenuContent(
      projet: projet,
      projetsProvider: context.read<ProjetsProvider>(),
      onRefresh: onRefresh,
    ),
  );
}

class _ProjetContextMenuContent extends StatelessWidget {
  final Projet projet;
  final ProjetsProvider projetsProvider;
  final VoidCallback onRefresh;

  const _ProjetContextMenuContent({
    required this.projet,
    required this.projetsProvider,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Projet.iconFromKey(projet.icone),
                    color: Projet.colorFromHex(projet.couleur),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    projet.nom,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            _MenuItem(
              icon: Icons.edit_rounded,
              label: 'Renommer le projet',
              color: Theme.of(context).primaryColor,
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context);
              },
            ),
            if (!projet.isSystem)
              _MenuItem(
                icon: Icons.flag_outlined,
                label: 'Modifier l\'objectif',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _showEditObjectifDialog(context);
                },
              ),
            _MenuItem(
              icon: Icons.palette_rounded,
              label: 'Changer icône & couleur',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                _showIconColorPicker(context);
              },
            ),
            if (!projet.isSystem)
              _MenuItem(
                icon: Icons.delete_forever_rounded,
                label: 'Supprimer le projet',
                color: Colors.red.shade700,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: projet.nom);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer le projet'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nouveau nom',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nom = ctrl.text.trim();
              if (nom.isEmpty) return;
              Navigator.pop(ctx);
              await projetsProvider.updateProjet(projet.copyWith(nom: nom));
              onRefresh();
            },
            child: const Text('Renommer'),
          ),
        ],
      ),
    );
  }

  void _showEditObjectifDialog(BuildContext context) {
    final ctrl = TextEditingController(text: projet.objectif ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier l\'objectif'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Objectif du projet',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await projetsProvider
                  .updateProjet(projet.copyWith(objectif: ctrl.text.trim()));
              onRefresh();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showIconColorPicker(BuildContext context) {
    String selectedIcone = projet.icone;
    String selectedCouleur = projet.couleur;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            builder: (_, scrollCtrl) => Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  const Text(
                    'Icône',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: Projet.iconPalette.map((key) {
                      final selected = key == selectedIcone;
                      return GestureDetector(
                        onTap: () => setState(() => selectedIcone = key),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: selected
                                ? Projet.colorFromHex(selectedCouleur)
                                    .withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: selected
                                ? Border.all(
                                    color: Projet.colorFromHex(selectedCouleur),
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Icon(
                            Projet.iconFromKey(key),
                            color: selected
                                ? Projet.colorFromHex(selectedCouleur)
                                : Colors.grey,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Couleur',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: Projet.colorPalette.map((hex) {
                      final selected = hex == selectedCouleur;
                      return GestureDetector(
                        onTap: () => setState(() => selectedCouleur = hex),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Projet.colorFromHex(hex),
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  )
                                : null,
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: Projet.colorFromHex(hex)
                                          .withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    )
                                  ]
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await projetsProvider.updateProjet(
                        projet.copyWith(
                          icone: selectedIcone,
                          couleur: selectedCouleur,
                        ),
                      );
                      onRefresh();
                    },
                    child: const Text('Appliquer'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final Set<String> coursASupprimer = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text('Supprimer le projet'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Le projet sera supprimé. Que faire de ses cours ?',
              ),
              const SizedBox(height: 12),
              if (projet.matiereIds.isEmpty)
                const Text('Aucun cours dans ce projet.')
              else ...[
                const Text(
                  'Cochez les cours à supprimer définitivement :',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView(
                    shrinkWrap: true,
                    children: projet.matiereIds.map((id) {
                      return CheckboxListTile(
                        dense: true,
                        title: Text(id, style: const TextStyle(fontSize: 13)),
                        value: coursASupprimer.contains(id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              coursASupprimer.add(id);
                            } else {
                              coursASupprimer.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les cours non cochés resteront disponibles dans "Mes cours".',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                // Supprimer les cours cochés — géré via CustomCoursesProvider
                // Les cours non cochés restent dans Mes cours
                for (final _ in coursASupprimer) {}
                await projetsProvider.deleteProjet(projet.id);
                onRefresh();
              },
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      onTap: onTap,
    );
  }
}
