import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/custom_courses_provider.dart';
import '../../modules/modules_registry.dart';

class ManageCustomCoursePage extends StatelessWidget {
  final String matiereId;

  const ManageCustomCoursePage({super.key, required this.matiereId});

  @override
  Widget build(BuildContext context) {
    final matiere = ModulesRegistry.getMatiere(matiereId);
    if (matiere == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: const Center(child: Text('Cours introuvable')),
      );
    }
    final nomCtrl = TextEditingController(text: matiere.nom);
    final descCtrl = TextEditingController(text: matiere.description);

    return Scaffold(
      appBar: AppBar(title: Text('Gérer — ${matiere.nom}')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: nomCtrl,
            decoration: const InputDecoration(
              labelText: 'Nom du cours',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await context.read<CustomCoursesProvider>().updateCourseInfo(
                    matiereId,
                    nomCtrl.text.trim(),
                    descCtrl.text.trim(),
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cours mis à jour')),
                );
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer'),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: const Text(
              'Supprimer ce cours',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le cours ?'),
        content: const Text(
          'Le cours et sa progression seront supprimés. Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<CustomCoursesProvider>().deleteCourse(matiereId);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}
