import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/projet.dart';
import '../../../core/models/matiere.dart';
import '../../../core/providers/projets_provider.dart';
import '../../../core/providers/custom_courses_provider.dart';
import '../../../modules/modules_registry.dart';

/// Affiche un menu contextuel (bottom sheet) au long-press sur un cours dans un projet.
Future<void> showCoursContextMenu(
  BuildContext context, {
  required String matiereId,
  required String projetId,
  required VoidCallback onRefresh,
}) async {
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CoursContextMenuContent(
      matiereId: matiereId,
      projetId: projetId,
      onRefresh: onRefresh,
    ),
  );
}

class _CoursContextMenuContent extends StatelessWidget {
  final String matiereId;
  final String projetId;
  final VoidCallback onRefresh;

  const _CoursContextMenuContent({
    required this.matiereId,
    required this.projetId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final customProvider = context.read<CustomCoursesProvider>();
    final projetsProvider = context.read<ProjetsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final matiere = ModulesRegistry.getMatiere(matiereId);
    if (matiere == null) {
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
              const ListTile(
                leading: Icon(Icons.help_rounded),
                title: Text('Inconnue'),
              ),
            ],
          ),
        ),
      );
    }
    final isCustom = customProvider.isCustomMatiere(matiereId);

    // Projet actuel (pour récupérer sa couleur)
    final projetActuel = projetsProvider.getProjetById(projetId);
    final color = projetActuel != null 
        ? Projet.colorFromHex(projetActuel.couleur)
        : Theme.of(context).primaryColor;

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
                    matiere.icone,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      matiere.nom,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (isCustom) ...[
              _MenuItem(
                icon: Icons.edit_rounded,
                label: 'Renommer le cours',
                color: Theme.of(context).primaryColor,
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context, matiere, customProvider);
                },
              ),
              _MenuItem(
                icon: Icons.description_rounded,
                label: 'Modifier la description',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _showEditDescriptionDialog(context, matiere, customProvider);
                },
              ),
            ],
            _MenuItem(
              icon: Icons.add_circle_outline_rounded,
              label: 'Ajouter à un autre projet',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _showAddToProjectDialog(context, projetsProvider);
              },
            ),
            _MenuItem(
              icon: Icons.swap_horiz_rounded,
              label: 'Transférer vers un autre projet',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _showTransferProjectDialog(context, projetsProvider);
              },
            ),
            _MenuItem(
              icon: Icons.remove_circle_outline_rounded,
              label: 'Retirer de ce projet',
              color: Colors.redAccent,
              onTap: () async {
                Navigator.pop(context);
                await projetsProvider.removeMatiereFromProjet(projetId, matiereId);
                onRefresh();
              },
            ),
            if (isCustom)
              _MenuItem(
                icon: Icons.delete_forever_rounded,
                label: 'Supprimer définitivement',
                color: Colors.red.shade700,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog(context, customProvider);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    Matiere matiere,
    CustomCoursesProvider customProvider,
  ) {
    final ctrl = TextEditingController(text: matiere.nom);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer le cours'),
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
              await customProvider.updateCourseInfo(
                matiereId,
                nom,
                matiere.description,
              );
              onRefresh();
            },
            child: const Text('Renommer'),
          ),
        ],
      ),
    );
  }

  void _showEditDescriptionDialog(
    BuildContext context,
    Matiere matiere,
    CustomCoursesProvider customProvider,
  ) {
    final ctrl = TextEditingController(text: matiere.description);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier la description'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Description',
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
              await customProvider.updateCourseInfo(
                matiereId,
                matiere.nom,
                ctrl.text.trim(),
              );
              onRefresh();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showAddToProjectDialog(
    BuildContext context,
    ProjetsProvider projetsProvider,
  ) {
    final projetsCibles = projetsProvider.projets
        .where((p) => !p.matiereIds.contains(matiereId))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter à un projet'),
        content: projetsCibles.isEmpty
            ? const Text('Ce cours appartient déjà à tous vos projets.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: projetsCibles.length,
                  itemBuilder: (context, index) {
                    final p = projetsCibles[index];
                    return ListTile(
                      leading: Icon(
                        Projet.iconFromKey(p.icone),
                        color: Projet.colorFromHex(p.couleur),
                      ),
                      title: Text(p.nom),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await projetsProvider.addMatiereToProjet(p.id, matiereId);
                        onRefresh();
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showTransferProjectDialog(
    BuildContext context,
    ProjetsProvider projetsProvider,
  ) {
    final projetsCibles = projetsProvider.projets
        .where((p) => p.id != projetId && !p.matiereIds.contains(matiereId))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transférer vers un projet'),
        content: projetsCibles.isEmpty
            ? const Text('Aucun autre projet disponible pour le transfert.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: projetsCibles.length,
                  itemBuilder: (context, index) {
                    final p = projetsCibles[index];
                    return ListTile(
                      leading: Icon(
                        Projet.iconFromKey(p.icone),
                        color: Projet.colorFromHex(p.couleur),
                      ),
                      title: Text(p.nom),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await projetsProvider.transfererMatiere(
                          projetId,
                          p.id,
                          matiereId,
                        );
                        onRefresh();
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    CustomCoursesProvider customProvider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Supprimer définitivement'),
          ],
        ),
        content: const Text(
          'Ce cours et sa progression seront supprimés de tous les projets et de votre bibliothèque. Cette action est irréversible.',
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
              await customProvider.deleteCourse(matiereId);
              onRefresh();
            },
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
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
