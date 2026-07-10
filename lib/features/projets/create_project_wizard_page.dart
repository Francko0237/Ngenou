import 'dart:convert';
import "../../core/widgets/premium_loader.dart";
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/projet.dart';
import '../../core/models/deep_seek_model.dart';
import '../../core/providers/projets_provider.dart';
import '../../core/providers/custom_courses_provider.dart';
import '../../core/providers/progression_provider.dart';
import '../../core/services/project_prompt_builder.dart';
import '../../core/services/course_import_validator.dart';
import '../../core/services/deep_seek_service.dart';
import '../../core/services/quota_guard.dart';
import '../../core/utils/error_formatter.dart';
import '../../core/utils/duration_utils.dart';

class CreateProjectWizardPage extends StatefulWidget {
  const CreateProjectWizardPage({super.key});

  @override
  State<CreateProjectWizardPage> createState() =>
      _CreateProjectWizardPageState();
}

class _CreateProjectWizardPageState extends State<CreateProjectWizardPage> {
  final _pageCtrl = PageController();
  int _step = 0;

  // Étape 1 — Infos
  final _nomCtrl = TextEditingController();
  final _objectifCtrl = TextEditingController();
  String _langue = 'fr';
  DeepSeekModel _selectedModel = DeepSeekModel.flash;

  // Étape 2 — Programme
  bool _isGeneratingProgram = false;
  String? _programError;
  List<ProgramSubject> _subjects = [];
  String _selectedIcone = 'spark';
  String _selectedCouleur = '#6C63FF';
  final _subjectCtrl = TextEditingController();
  final _subjectDescCtrl = TextEditingController();

  // Étape 3 — Génération des cours
  int _generationIndex = 0;
  bool _isGeneratingCourses = false;
  List<String> _generatedMatiereIds = [];
  String? _createdProjetId;
  String? _generationError;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nomCtrl.dispose();
    _objectifCtrl.dispose();
    _subjectCtrl.dispose();
    _subjectDescCtrl.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  // ─── ÉTAPE 1 → 2 : Générer le programme ────────────────────────────────────

  Future<void> _generateProgram() async {
    setState(() {
      _isGeneratingProgram = true;
      _programError = null;
    });
    try {
      final prompt = ProjectPromptBuilder.buildProgramPrompt(
        nom: _nomCtrl.text.trim(),
        objectif: _objectifCtrl.text.trim().isEmpty
            ? null
            : _objectifCtrl.text.trim(),
        langue: _langue,
      );
      final result = await DeepSeekService.generateProgram(
        prompt,
        model: _selectedModel,
      );

      // Afficher le message de fallback Pro → Flash si applicable
      if (result.fallbackMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.fallbackMessage!),
            duration: const Duration(seconds: 4),
            backgroundColor: const Color(0xFF3498DB),
          ),
        );
      }

      final data = jsonDecode(result.content) as Map<String, dynamic>;

      final matieres = (data['matieres'] as List<dynamic>)
          .map((e) => ProgramSubject.fromJson(e as Map<String, dynamic>))
          .toList();
      matieres.sort((a, b) => a.ordre.compareTo(b.ordre));

      setState(() {
        _subjects = matieres;
        _selectedIcone = data['icone'] as String? ?? 'spark';
        _selectedCouleur = data['couleur'] as String? ?? '#6C63FF';
      });
      _goToStep(1);
    } on QuotaExceededException catch (e) {
      // Quota Pro bloqué → message clair, aucun appel API
      setState(() => _programError = e.message);
    } catch (e) {
      setState(() => _programError = formatUserError(e));
    } finally {
      setState(() => _isGeneratingProgram = false);
    }
  }

  // ─── ÉTAPE 2 → 3 : Générer tous les cours ──────────────────────────────────

  Future<void> _generateAllCourses() async {
    if (_subjects.isEmpty) return;
    setState(() {
      _isGeneratingCourses = true;
      _generationIndex = 0;
      _generationError = null;
      _generatedMatiereIds = [];
    });

    // Créer le projet d'abord
    final projetId = 'project_${DateTime.now().millisecondsSinceEpoch}';
    final projet = Projet(
      id: projetId,
      nom: _nomCtrl.text.trim(),
      description: _objectifCtrl.text.trim().isEmpty
          ? null
          : _objectifCtrl.text.trim(),
      objectif: _objectifCtrl.text.trim().isEmpty
          ? null
          : _objectifCtrl.text.trim(),
      couleur: _selectedCouleur,
      icone: _selectedIcone,
      matiereIds: const [],
      dateCreation: DateTime.now(),
    );
    await context.read<ProjetsProvider>().createProjet(projet);
    _createdProjetId = projetId;
    _goToStep(2);

    for (int i = 0; i < _subjects.length; i++) {
      if (!mounted) break;
      setState(() => _generationIndex = i);
      final subject = _subjects[i];
      final matiereId = 'custom_${DateTime.now().millisecondsSinceEpoch}_$i';

      try {
        final prompt = ProjectPromptBuilder.buildCourseFromSubjectPrompt(
          sujetNom: subject.nom,
          sujetDescription: subject.description,
          projetObjectif: _objectifCtrl.text.trim().isEmpty
              ? null
              : _objectifCtrl.text.trim(),
          projetNom: _nomCtrl.text.trim(),
          matiereId: matiereId,
          langue: _langue,
          durationMinutes: subject.durationMinutes,
        );
        final result = await DeepSeekService.generateCourse(
          prompt,
          model: _selectedModel,
        );
        // Note : le fallback du projet a déjà été affiché lors de generateProgram.
        // On utilise le modèle effectif retourné (peut être Flash si fallback).
        String cleanJson = result.content.trim();
        if (cleanJson.startsWith('```')) {
          final end = cleanJson.indexOf('\n');
          if (end != -1) cleanJson = cleanJson.substring(end).trim();
          if (cleanJson.endsWith('```')) {
            cleanJson = cleanJson.substring(0, cleanJson.length - 3).trim();
          }
        }
        final validation = CourseImportValidator.validate(cleanJson);
        if (!validation.isValid || validation.package == null) continue;

        final pkg = validation.package!;
        final err = await context.read<CustomCoursesProvider>().importCourse(
          pkg,
        );
        if (err != null) continue;

        await context.read<ProgressionProvider>().loadProgression(
          pkg.matiere.id,
        );
        await context.read<ProjetsProvider>().addMatiereToProjet(
          projetId,
          pkg.matiere.id,
        );

        if (mounted) {
          setState(() => _generatedMatiereIds.add(pkg.matiere.id));
        }
      } catch (e) {
        // On continue même si un cours échoue
        debugPrint('Erreur génération cours "${subject.nom}": $e');
      }
    }

    if (mounted) setState(() => _isGeneratingCourses = false);
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titles = ['Nouveau projet', 'Programme', 'Génération'];

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(titles[_step]),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step > 0 && !_isGeneratingCourses) {
              _goToStep(_step - 1);
            } else if (_step == 0) {
              Navigator.pop(context);
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / titles.length,
            minHeight: 4,
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _stepInfo(isDark),
          _stepProgram(isDark),
          _stepGeneration(isDark),
        ],
      ),
    );
  }

  // ─── ÉTAPE 1 : Informations ─────────────────────────────────────────────────

  Widget _stepInfo(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Quel est votre projet ?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'L\'IA générera un programme complet de cours adapté à votre projet.',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _nomCtrl,
          decoration: const InputDecoration(
            labelText: 'Nom du projet *',
            hintText: 'Ex : Réseau & Télécom',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.folder_rounded),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _objectifCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Objectif / Description (facultatif)',
            hintText:
                'Ex : Maîtriser les fondamentaux des réseaux informatiques',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.flag_outlined),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Langue du contenu',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _langChip('fr', 'Français', isDark),
            const SizedBox(width: 10),
            _langChip('en', 'English', isDark),
          ],
        ),
        const SizedBox(height: 20),
        // ── Sélecteur de modèle ──────────────────────────────────────────
        _buildProjectModelSelector(isDark),
        const SizedBox(height: 28),
        if (_programError != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _programError!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ListenableBuilder(
          listenable: _nomCtrl,
          builder: (context, _) {
            final isEmpty = _nomCtrl.text.trim().isEmpty;
            return ElevatedButton.icon(
              onPressed: _isGeneratingProgram || isEmpty
                  ? null
                  : _generateProgram,
              icon: _isGeneratingProgram
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                _isGeneratingProgram
                    ? 'Génération du programme...'
                    : 'Générer le programme IA',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProjectModelSelector(bool isDark) {
    final isPro = _selectedModel == DeepSeekModel.pro;
    return Container(
      decoration: BoxDecoration(
        color: isPro
            ? const Color(0xFF6C3FE8).withValues(alpha: 0.07)
            : (isDark ? const Color(0xFF1E1E1E) : Colors.grey[50]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPro
              ? const Color(0xFF6C3FE8).withValues(alpha: 0.35)
              : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_rounded,
                color: isPro ? const Color(0xFF6C3FE8) : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Modèle d\'IA',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _modelChip(
                DeepSeekModel.flash,
                Icons.bolt_rounded,
                const Color(0xFF3498DB),
                isDark,
              ),
              const SizedBox(width: 10),
              _modelChip(
                DeepSeekModel.pro,
                Icons.auto_awesome,
                const Color(0xFF6C3FE8),
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _selectedModel.description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modelChip(
    DeepSeekModel model,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final selected = _selectedModel == model;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedModel = model),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.6)
                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? color : Colors.grey),
              const SizedBox(width: 6),
              Text(
                model.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? color
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langChip(String value, String label, bool isDark) {
    final selected = _langue == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _langue = value),
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  // ─── ÉTAPE 2 : Programme ────────────────────────────────────────────────────

  Widget _stepProgram(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Programme généré',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Modifiez le programme avant de lancer la génération des cours.',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 20),

        // Icône & Couleur suggérées
        _buildIconColorRow(isDark),
        const SizedBox(height: 20),

        // Liste des matières
        Text(
          'Matières (${_subjects.length})',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _subjects.length,
          onReorder: (oldIdx, newIdx) {
            if (newIdx > oldIdx) newIdx--;
            setState(() {
              final item = _subjects.removeAt(oldIdx);
              _subjects.insert(newIdx, item);
              for (int i = 0; i < _subjects.length; i++) {
                _subjects[i].ordre = i + 1;
              }
            });
          },
          itemBuilder: (_, i) {
            final s = _subjects[i];
            final color = Projet.colorFromHex(_selectedCouleur);
            return Card(
              key: ValueKey(i),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  s.nom,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.description.isNotEmpty)
                      Text(
                        s.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 13, color: color),
                        const SizedBox(width: 4),
                        Text(
                          DurationUtils.format(s.durationMinutes),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                isThreeLine: s.description.isNotEmpty,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.red,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _subjects.removeAt(i)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Ajouter manuellement
        const SizedBox(height: 12),
        _buildAddSubjectTile(isDark),
        const SizedBox(height: 28),

        ElevatedButton.icon(
          onPressed: _subjects.isEmpty ? null : _generateAllCourses,
          icon: const Icon(Icons.rocket_launch_rounded),
          label: Text('Générer ${_subjects.length} cours avec l\'IA'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: Projet.colorFromHex(_selectedCouleur),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildIconColorRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Projet.colorFromHex(_selectedCouleur).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Projet.colorFromHex(
                    _selectedCouleur,
                  ).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Projet.iconFromKey(_selectedIcone),
                  color: Projet.colorFromHex(_selectedCouleur),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nomCtrl.text.trim(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '${Projet.iconLabel(_selectedIcone)} · $_selectedCouleur',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _showPickerSheet(),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Modifier'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddSubjectTile(bool isDark) {
    return ExpansionTile(
      title: const Text('Ajouter une matière manuellement'),
      leading: const Icon(Icons.add_circle_outline_rounded),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              TextField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom de la matière',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _subjectDescCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (facultatif)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    final nom = _subjectCtrl.text.trim();
                    if (nom.isEmpty) return;
                    setState(() {
                      _subjects.add(
                        ProgramSubject(
                          nom: nom,
                          description: _subjectDescCtrl.text.trim(),
                          ordre: _subjects.length + 1,
                        ),
                      );
                      _subjectCtrl.clear();
                      _subjectDescCtrl.clear();
                    });
                  },
                  child: const Text('Ajouter'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPickerSheet() {
    String tmpIcone = _selectedIcone;
    String tmpCouleur = _selectedCouleur;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (_, ss) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, ctrl) => Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              controller: ctrl,
              children: [
                const Text(
                  'Icône',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: Projet.iconPalette.map((key) {
                    final sel = key == tmpIcone;
                    return GestureDetector(
                      onTap: () => ss(() => tmpIcone = key),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: sel
                              ? Projet.colorFromHex(
                                  tmpCouleur,
                                ).withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                          border: sel
                              ? Border.all(
                                  color: Projet.colorFromHex(tmpCouleur),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Icon(
                          Projet.iconFromKey(key),
                          color: sel
                              ? Projet.colorFromHex(tmpCouleur)
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
                    final sel = hex == tmpCouleur;
                    return GestureDetector(
                      onTap: () => ss(() => tmpCouleur = hex),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Projet.colorFromHex(hex),
                          shape: BoxShape.circle,
                          border: sel
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                    color: Projet.colorFromHex(
                                      hex,
                                    ).withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: sel
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedIcone = tmpIcone;
                      _selectedCouleur = tmpCouleur;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Appliquer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── ÉTAPE 3 : Génération des cours ─────────────────────────────────────────

  Widget _stepGeneration(bool isDark) {
    final done = !_isGeneratingCourses;
    final color = Projet.colorFromHex(_selectedCouleur);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!done) ...[
              PremiumLoader(
                customText: 'Génération en cours...',
                customLoadingTexts: _subjects.isNotEmpty
                    ? [
                        "Cours ${_generationIndex + 1} / ${_subjects.length} : ${_subjects[_generationIndex.clamp(0, _subjects.length - 1)].nom}",
                        "Rédaction du contenu pédagogique...",
                        "Préparation des exercices interactifs...",
                        "${_generatedMatiereIds.length} cours terminé${_generatedMatiereIds.length > 1 ? 's' : ''} sur ${_subjects.length}",
                      ]
                    : null,
              ),
              const SizedBox(height: 24),
              if (_subjects.isNotEmpty)
                LinearProgressIndicator(
                  value: _subjects.isEmpty
                      ? 0
                      : _generatedMatiereIds.length / _subjects.length,
                  backgroundColor: color.withValues(alpha: 0.2),
                  color: color,
                ),
              const SizedBox(height: 16),
              Text(
                _generatedMatiereIds.isEmpty
                    ? 'Génération du cours ${_generationIndex + 1} sur ${_subjects.length}...'
                    : '${_generatedMatiereIds.length} / ${_subjects.length} cours générés',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: color, size: 60),
              ),
              const SizedBox(height: 24),
              Text(
                'Projet créé avec succès !',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${_generatedMatiereIds.length} cours générés sur ${_subjects.length} matières.',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _createdProjetId),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Ouvrir le projet'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
