import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/widgets/premium_loader.dart';
import '../../core/models/custom_course_package.dart';
import '../../core/models/deep_seek_model.dart';
import '../../core/services/course_prompt_builder.dart';
import 'package:provider/provider.dart';
import '../../core/services/deep_seek_service.dart';
import '../../core/services/course_import_validator.dart';
import '../../core/services/quota_guard.dart';
import '../../core/providers/custom_courses_provider.dart';
import '../../core/providers/progression_provider.dart';
import '../../core/providers/projets_provider.dart';
import '../../core/utils/error_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/ocr_service.dart';
import 'course_import_page.dart';
import '../../core/services/teacher_courses_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/image_compression_helper.dart';
import '../../core/models/ngenou_extension.dart';
import '../../core/services/extensions_service.dart';
import 'course_studio_page.dart';

// ── Constantes visuelles ──────────────────────────────────────────────────────
const _kSurface = Color(0xFF1E1E26);
const _kBg = Color(0xFF121216);
const _kBgLight = Color(0xFFF7F8FA);

class CourseBuilderWizardPage extends StatefulWidget {
  final String? projetId;
  const CourseBuilderWizardPage({super.key, this.projetId});

  @override
  State<CourseBuilderWizardPage> createState() =>
      _CourseBuilderWizardPageState();
}

class _CourseBuilderWizardPageState extends State<CourseBuilderWizardPage>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _step = 0;

  final _nomCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _docsCtrl = TextEditingController();
  final _chapitreCtrl = TextEditingController();
  final _classeCtrl = TextEditingController();

  String _objectif = 'comprehension';
  String _langue = 'fr';
  String _niveau = '';
  String _schoolLevel = 'secondaire';
  String? _coverImageUrl;
  String? _userRole;
  bool _hasDocuments = false;
  bool _enableTerminal = false;
  final List<String> _chapitres = [];
  DeepSeekModel _selectedModel = DeepSeekModel.flash;
  NgenouExtension? _selectedExtension;

  String? _generatedPrompt;
  bool _isGenerating = false;
  bool _isOcrProcessing = false;
  late final String _matiereId =
      'custom_${DateTime.now().millisecondsSinceEpoch}';

  // Étapes : 0 Infos · 1 Objectif · 2 Langue · 3 Documents · 4 Structure · 5 Génération
  static const _stepLabels = [
    'Infos',
    'Objectif',
    'Langue',
    'Documents',
    'Structure',
    'Générer',
  ];
  static const int _totalSteps = 6;

  @override
  void initState() {
    super.initState();
    _loadUserContext();
    ExtensionsService.instance.init();
  }

  Future<void> _loadUserContext() async {
    final role = await AuthService.getUserRole();
    final lvl = await AuthService.getSchoolLevel();
    if (mounted) {
      setState(() {
        _userRole = role;
        if (lvl != null && lvl.isNotEmpty) {
          _schoolLevel = lvl;
          if (_classeCtrl.text.isEmpty) _classeCtrl.text = _defaultClasse(lvl);
        } else if (_classeCtrl.text.isEmpty) {
          _classeCtrl.text = '6ème';
        }
      });
    }
  }

  String _defaultClasse(String lvl) => switch (lvl) {
    'primaire' => 'CM2',
    'superieur' => 'Licence 1',
    _ => '6ème',
  };

  List<String> _suggestedClasses(String lvl) => switch (lvl) {
    'primaire' => ['SIL', 'CP', 'CE1', 'CE2', 'CM1', 'CM2'],
    'superieur' => ['Licence 1', 'Licence 2', 'Licence 3', 'Master'],
    _ => ['6ème', '5ème', '4ème', '3ème', '2nde', '1ère', 'Terminale'],
  };

  @override
  void dispose() {
    _pageController.dispose();
    _nomCtrl.dispose();
    _descCtrl.dispose();
    _docsCtrl.dispose();
    _chapitreCtrl.dispose();
    _classeCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _next() {
    final err = _validate();
    if (err != null) {
      _snack(err);
      return;
    }
    if (_step == _totalSteps - 2) _buildPrompt();
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      _generateWithDeepSeek();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  String? _validate() {
    if (_step == 0) {
      if (_nomCtrl.text.trim().isEmpty) return 'Indiquez le nom du cours.';
      if (_classeCtrl.text.trim().isEmpty) return 'Précisez la classe ciblée.';
    }
    return null;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  void _buildPrompt() {
    final input = CourseWizardInput(
      nom: _nomCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      objectif: _objectif,
      langue: _langue,
      hasDocuments: _hasDocuments,
      documentsText: _docsCtrl.text.trim(),
      niveau: _niveau,
      schoolLevel: _schoolLevel,
      classe: _classeCtrl.text.trim().isNotEmpty
          ? _classeCtrl.text.trim()
          : null,
      coverImageUrl: _coverImageUrl,
      chapitres: List.from(_chapitres),
      enableTerminal: _enableTerminal,
      matiereId: _matiereId,
      selectedExtensionId: _selectedExtension?.id,
      selectedExtensionName: _selectedExtension?.nom,
      selectedExtensionPrompt: _selectedExtension?.aiPrompt,
    );
    setState(() => _generatedPrompt = CoursePromptBuilder.build(input));
  }

  void _addChapitre() {
    final t = _chapitreCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _chapitres.add(t);
      _chapitreCtrl.clear();
    });
  }

  // ── OCR ─────────────────────────────────────────────────────────────────────

  Future<void> _pickCoverImage(ImageSource source) async {
    final b64 = await ImageCompressionHelper.pickAndCompressCoverImage(source);
    if (b64 != null) setState(() => _coverImageUrl = b64);
  }

  Future<void> _pickImage(ImageSource source) async {
    final f = await ImagePicker().pickImage(source: source);
    if (f != null) await _ocrFile(File(f.path), isPdf: false);
  }

  Future<void> _pickPdf() async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (r?.files.single.path != null)
      await _ocrFile(File(r!.files.single.path!), isPdf: true);
  }

  Future<void> _ocrFile(File f, {required bool isPdf}) async {
    setState(() => _isOcrProcessing = true);
    try {
      final text = isPdf
          ? await OcrService.extractTextFromPdf(f)
          : await OcrService.extractTextFromImage(f);
      if (text.isEmpty) throw Exception("Aucun texte exploitable extrait.");
      setState(() {
        final cur = _docsCtrl.text.trim();
        _docsCtrl.text = cur.isEmpty ? text : '$cur\n\n---\n\n$text';
        _hasDocuments = true;
      });
      if (mounted) _snack('Texte extrait avec succès !');
    } catch (e) {
      if (mounted) _snack(formatUserError(e));
    } finally {
      if (mounted) setState(() => _isOcrProcessing = false);
    }
  }

  // ── Build principal ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final bgColor = isDark ? _kBg : _kBgLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final hPad = w > 1200
                ? w * 0.12
                : w > 800
                ? w * 0.07
                : 16.0;

            return Column(
              children: [
                // ── Header + stepper ──────────────────────────────────────
                _WizardHeader(
                  step: _step,
                  totalSteps: _totalSteps,
                  labels: _stepLabels,
                  primary: primary,
                  isDark: isDark,
                  onBack: _back,
                ),

                // ── Pages ─────────────────────────────────────────────────
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StepInfos(
                        nomCtrl: _nomCtrl,
                        descCtrl: _descCtrl,
                        classeCtrl: _classeCtrl,
                        schoolLevel: _schoolLevel,
                        userRole: _userRole,
                        coverImageUrl: _coverImageUrl,
                        isDark: isDark,
                        primary: primary,
                        hPad: hPad,
                        onSchoolLevelChanged: (v) {
                          setState(() {
                            _schoolLevel = v;
                            _classeCtrl.text = _suggestedClasses(v).last;
                          });
                        },
                        onClasseChanged: () => setState(() {}),
                        suggestedClasses: _suggestedClasses(_schoolLevel),
                        onCoverPick: _pickCoverImage,
                        onCoverDelete: () =>
                            setState(() => _coverImageUrl = null),
                        onImport: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CourseImportPage(),
                          ),
                        ),
                      ),
                      _StepObjectif(
                        objectif: _objectif,
                        isDark: isDark,
                        primary: primary,
                        hPad: hPad,
                        onChanged: (v) => setState(() => _objectif = v),
                      ),
                      _StepLangue(
                        langue: _langue,
                        isDark: isDark,
                        primary: primary,
                        hPad: hPad,
                        onChanged: (v) => setState(() => _langue = v),
                      ),
                      _StepDocuments(
                        docsCtrl: _docsCtrl,
                        isOcrProcessing: _isOcrProcessing,
                        isDark: isDark,
                        primary: primary,
                        hPad: hPad,
                        onPickCamera: () => _pickImage(ImageSource.camera),
                        onPickGallery: () => _pickImage(ImageSource.gallery),
                        onPickPdf: _pickPdf,
                        onTextChanged: (v) {
                          final has = v.trim().isNotEmpty;
                          if (has != _hasDocuments)
                            setState(() => _hasDocuments = has);
                        },
                      ),
                      _StepStructure(
                        chapitres: _chapitres,
                        chapitreCtrl: _chapitreCtrl,
                        niveau: _niveau,
                        enableTerminal: _enableTerminal,
                        selectedModel: _selectedModel,
                        selectedExtension: _selectedExtension,
                        isDark: isDark,
                        primary: primary,
                        hPad: hPad,
                        onAddChapitre: _addChapitre,
                        onRemoveChapitre: (c) =>
                            setState(() => _chapitres.remove(c)),
                        onNiveauChanged: (v) => setState(() => _niveau = v),
                        onTerminalChanged: (v) =>
                            setState(() => _enableTerminal = v),
                        onModelChanged: (v) =>
                            setState(() => _selectedModel = v),
                        onOpenExtensionPicker: () =>
                            _openExtensionPicker(isDark),
                        onRemoveExtension: () =>
                            setState(() => _selectedExtension = null),
                      ),
                      _StepGeneration(
                        isGenerating: _isGenerating,
                        nomCtrl: _nomCtrl,
                        classeCtrl: _classeCtrl,
                        objectif: _objectif,
                        langue: _langue,
                        chapitres: _chapitres,
                        schoolLevel: _schoolLevel,
                        coverImageUrl: _coverImageUrl,
                        enableTerminal: _enableTerminal,
                        selectedModel: _selectedModel,
                        isDark: isDark,
                        primary: primary,
                        hPad: hPad,
                      ),
                    ],
                  ),
                ),

                // ── Footer navigation ─────────────────────────────────────
                if (!_isGenerating)
                  _WizardFooter(
                    step: _step,
                    totalSteps: _totalSteps,
                    primary: primary,
                    isDark: isDark,
                    onBack: _back,
                    onNext: _next,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Extension picker ─────────────────────────────────────────────────────────

  void _openExtensionPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String? tempId = _selectedExtension?.id;
        final pending = <String>{};
        return StatefulBuilder(
          builder: (mCtx, setModal) {
            final svc = ExtensionsService.instance;
            final exts = svc.extensions;
            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181820) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Handle + titre
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE67E22,
                            ).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.extension_rounded,
                            color: Color(0xFFE67E22),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Extensions disponibles',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A2E),
                                ),
                              ),
                              Text(
                                'Choisissez une extension pour ce cours',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(mCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: exts.isEmpty
                        ? Center(
                            child: svc.isLoading
                                ? const CircularProgressIndicator()
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.extension_off_rounded,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 10),
                                      const Text('Aucune extension disponible'),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () async {
                                          await svc.loadExtensions(
                                            forceRefresh: true,
                                          );
                                          setModal(() {});
                                        },
                                        child: const Text('Actualiser'),
                                      ),
                                    ],
                                  ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: exts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final ext = exts[i];
                              final installed = svc.isInstalled(ext.id);
                              final isSelected = tempId == ext.id;
                              final isDown = pending.contains(ext.id);
                              return GestureDetector(
                                onTap: installed
                                    ? () => setModal(() => tempId = ext.id)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? ext.color.withValues(
                                            alpha: isDark ? 0.18 : 0.08,
                                          )
                                        : (isDark
                                              ? const Color(0xFF22222E)
                                              : Colors.grey[50]),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? ext.color
                                          : (isDark
                                                ? Colors.grey[800]!
                                                : Colors.grey[200]!),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: ext.color.withValues(
                                            alpha: 0.15,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          ext.icon,
                                          color: ext.color,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ext.nom,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              ext.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white38
                                                    : Colors.black38,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (!installed)
                                        FilledButton.tonal(
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          onPressed: isDown
                                              ? null
                                              : () async {
                                                  setModal(
                                                    () => pending.add(ext.id),
                                                  );
                                                  final ok = await svc
                                                      .installExtension(ext);
                                                  if (mCtx.mounted) {
                                                    setModal(() {
                                                      pending.remove(ext.id);
                                                      if (ok) tempId = ext.id;
                                                    });
                                                  }
                                                },
                                          child: isDown
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.download_rounded,
                                                  size: 16,
                                                ),
                                        )
                                      else
                                        Radio<String>(
                                          value: ext.id,
                                          groupValue: tempId,
                                          activeColor: ext.color,
                                          onChanged: (v) =>
                                              setModal(() => tempId = v),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(mCtx),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE67E22),
                              ),
                              onPressed: () {
                                if (tempId != null) {
                                  final chosen = exts.firstWhere(
                                    (e) => e.id == tempId,
                                  );
                                  setState(() => _selectedExtension = chosen);
                                }
                                Navigator.pop(mCtx);
                              },
                              child: const Text('Confirmer'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Génération ───────────────────────────────────────────────────────────────

  void _generateWithDeepSeek() async {
    if (_generatedPrompt == null) _buildPrompt();
    if (_generatedPrompt == null) return;
    setState(() => _isGenerating = true);
    try {
      final result = await DeepSeekService.generateCourse(
        _generatedPrompt!,
        model: _selectedModel,
      );

      if (result.fallbackMessage != null && mounted) {
        _snack(result.fallbackMessage!);
      }

      String clean = result.content.trim();
      if (clean.startsWith('```')) {
        final i = clean.indexOf('\n');
        if (i != -1) clean = clean.substring(i).trim();
        if (clean.endsWith('```'))
          clean = clean.substring(0, clean.length - 3).trim();
      }

      final v = CourseImportValidator.validate(clean);
      if (!v.isValid) throw Exception(v.errors.join('\n'));

      var pkg = v.package!;
      var meta = pkg.meta;
      if (_selectedExtension != null) {
        meta = meta.copyWith(requiredExtension: _selectedExtension!.id);
      }
      var matiere = pkg.matiere;
      if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty) {
        matiere = matiere.copyWith(coverImageUrl: _coverImageUrl);
      }
      pkg = CustomCoursePackage(
        schemaVersionValue: pkg.schemaVersionValue,
        meta: meta,
        matiere: matiere,
        notions: pkg.notions,
        lecons: pkg.lecons,
        exercices: pkg.exercices,
      );

      final err = await context.read<CustomCoursesProvider>().importCourse(pkg);
      if (err != null) throw Exception(err);

      await context.read<ProgressionProvider>().loadProgression(pkg.matiere.id);

      if (widget.projetId != null && mounted) {
        await context.read<ProjetsProvider>().addMatiereToProjet(
          widget.projetId!,
          pkg.matiere.id,
        );
      }

      final role = await AuthService.getUserRole();
      if (role == 'teacher') {
        try {
          await TeacherCoursesService.publishCourse(
            package: pkg,
            schoolLevel: _schoolLevel,
            classe: _classeCtrl.text.trim().isNotEmpty
                ? _classeCtrl.text.trim()
                : null,
            coverImageUrl: _coverImageUrl,
            isPublished: true,
          );
        } catch (e) {
          debugPrint('Erreur publication : $e');
        }
      }

      if (mounted) {
        final goStudio = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _CourseCreatedDialog(
            courseName: pkg.matiere.nom,
            isTeacher: role == 'teacher',
          ),
        );
        if (!mounted) return;
        if (goStudio == true) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseStudioPage(matiereId: pkg.matiere.id),
              fullscreenDialog: true,
            ),
          );
          if (mounted) Navigator.pop(context, pkg.matiere.id);
        } else {
          Navigator.pop(context, pkg.matiere.id);
        }
      }
    } on QuotaExceededException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Mode Pro indisponible',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: Text(e.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('Erreur génération : $e\n$stack');
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Génération interrompue',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatUserError(e)),
                  const SizedBox(height: 12),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: const Text(
                        'Détails',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      tilePadding: EdgeInsets.zero,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2C2C2C)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            e.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _generateWithDeepSeek();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}

// ── Header avec stepper ───────────────────────────────────────────────────────

class _WizardHeader extends StatelessWidget {
  final int step, totalSteps;
  final List<String> labels;
  final Color primary;
  final bool isDark;
  final VoidCallback onBack;

  const _WizardHeader({
    required this.step,
    required this.totalSteps,
    required this.labels,
    required this.primary,
    required this.isDark,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step < labels.length ? labels[step] : 'Créer un cours',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              Text(
                '${step + 1}/$totalSteps',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stepper
          Row(
            children: List.generate(totalSteps * 2 - 1, (i) {
              if (i.isOdd) {
                final done = i ~/ 2 < step;
                return Expanded(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: done
                          ? primary
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }
              final idx = i ~/ 2;
              final active = idx == step;
              final done = idx < step;
              return _StepDot(
                index: idx,
                active: active,
                done: done,
                primary: primary,
                isDark: isDark,
                label: labels[idx],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final bool active, done;
  final Color primary;
  final bool isDark;
  final String label;

  const _StepDot({
    required this.index,
    required this.active,
    required this.done,
    required this.primary,
    required this.isDark,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: active ? 30 : 26,
          height: active ? 30 : 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active
                ? primary
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active || done
                          ? Colors.white
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? primary
                : (isDark ? Colors.white38 : Colors.black38),
          ),
        ),
      ],
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _WizardFooter extends StatelessWidget {
  final int step, totalSteps;
  final Color primary;
  final bool isDark;
  final VoidCallback onBack, onNext;

  const _WizardFooter({
    required this.step,
    required this.totalSteps,
    required this.primary,
    required this.isDark,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = step == totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (step > 0) ...[
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.12),
                  ),
                  foregroundColor: isDark ? Colors.white70 : Colors.black54,
                ),
                child: const Text(
                  'Retour',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 3,
            child: FilledButton.icon(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                isLast
                    ? Icons.auto_awesome_rounded
                    : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(
                isLast ? 'Générer le cours' : 'Suivant',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets utilitaires partagés ──────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _SectionCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? _kSurface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: isDark ? Colors.white38 : Colors.black38,
    ),
  );
}

// ── Étape 1 : Informations ────────────────────────────────────────────────────

class _StepInfos extends StatelessWidget {
  final TextEditingController nomCtrl, descCtrl, classeCtrl;
  final String schoolLevel;
  final String? userRole, coverImageUrl;
  final bool isDark;
  final Color primary;
  final double hPad;
  final void Function(String) onSchoolLevelChanged;
  final VoidCallback onClasseChanged;
  final List<String> suggestedClasses;
  final Future<void> Function(ImageSource) onCoverPick;
  final VoidCallback onCoverDelete;
  final VoidCallback onImport;

  const _StepInfos({
    required this.nomCtrl,
    required this.descCtrl,
    required this.classeCtrl,
    required this.schoolLevel,
    required this.userRole,
    required this.coverImageUrl,
    required this.isDark,
    required this.primary,
    required this.hPad,
    required this.onSchoolLevelChanged,
    required this.onClasseChanged,
    required this.suggestedClasses,
    required this.onCoverPick,
    required this.onCoverDelete,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.1),
      ),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: primary, width: 1.8),
    );
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);

    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
      children: [
        // Importer un cours existant
        _SectionCard(
          isDark: isDark,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.upload_file_rounded,
                  color: primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Importer un cours existant',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: onImport,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Importer',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Séparateur
        Row(
          children: [
            Expanded(
              child: Divider(color: isDark ? Colors.white12 : Colors.black12),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'ou créer avec l\'IA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            Expanded(
              child: Divider(color: isDark ? Colors.white12 : Colors.black12),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Badge enseignant
        if (userRole == 'teacher') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF6C63FF),
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Compte Enseignant — Ce cours sera publié dans les cours publics.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        _SectionLabel(label: 'Nom du cours', isDark: isDark),
        const SizedBox(height: 8),
        TextFormField(
          controller: nomCtrl,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Ex : Mathématiques 3ème',
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.black26,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(Icons.title_rounded, color: primary, size: 20),
            filled: true,
            fillColor: fillColor,
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: focusBorder,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SectionLabel(label: 'Description courte (optionnel)', isDark: isDark),
        const SizedBox(height: 8),
        TextFormField(
          controller: descCtrl,
          maxLines: 3,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'Décrivez brièvement ce cours…',
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            filled: true,
            fillColor: fillColor,
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: focusBorder,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Photo de couverture
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionLabel(label: 'Photo de couverture', isDark: isDark),
            if (coverImageUrl != null)
              GestureDetector(
                onTap: onCoverDelete,
                child: Text(
                  'Supprimer',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _CoverPicker(
          coverImageUrl: coverImageUrl,
          isDark: isDark,
          primary: primary,
          onPick: onCoverPick,
        ),
        const SizedBox(height: 18),

        // Niveau scolaire
        _SectionLabel(label: "Niveau d'enseignement", isDark: isDark),
        const SizedBox(height: 8),
        Row(
          children: [
            _LevelChip(
              level: 'primaire',
              label: 'Primaire',
              icon: Icons.child_care_rounded,
              current: schoolLevel,
              primary: primary,
              isDark: isDark,
              onTap: onSchoolLevelChanged,
            ),
            const SizedBox(width: 8),
            _LevelChip(
              level: 'secondaire',
              label: 'Secondaire',
              icon: Icons.school_rounded,
              current: schoolLevel,
              primary: primary,
              isDark: isDark,
              onTap: onSchoolLevelChanged,
            ),
            const SizedBox(width: 8),
            _LevelChip(
              level: 'superieur',
              label: 'Supérieur',
              icon: Icons.psychology_rounded,
              current: schoolLevel,
              primary: primary,
              isDark: isDark,
              onTap: onSchoolLevelChanged,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Classe
        _SectionLabel(label: 'Classe ciblée', isDark: isDark),
        const SizedBox(height: 8),
        TextFormField(
          controller: classeCtrl,
          onChanged: (_) => onClasseChanged(),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Ex : 3ème, CM2, Terminale…',
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            prefixIcon: Icon(Icons.class_rounded, color: primary, size: 20),
            filled: true,
            fillColor: fillColor,
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: focusBorder,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestedClasses.map((c) {
            final sel = classeCtrl.text.trim().toLowerCase() == c.toLowerCase();
            return GestureDetector(
              onTap: () {
                classeCtrl.text = c;
                onClasseChanged();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: sel
                      ? primary
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel
                        ? primary
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
                child: Text(
                  c,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String level, label;
  final IconData icon;
  final String current;
  final Color primary;
  final bool isDark;
  final void Function(String) onTap;

  const _LevelChip({
    required this.level,
    required this.label,
    required this.icon,
    required this.current,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = current == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(level),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel
                ? primary.withValues(alpha: isDark ? 0.2 : 0.1)
                : (isDark ? _kSurface : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? primary : (isDark ? Colors.white12 : Colors.black12),
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: sel
                    ? primary
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel
                      ? (isDark ? Colors.white : primary)
                      : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  final String? coverImageUrl;
  final bool isDark;
  final Color primary;
  final Future<void> Function(ImageSource) onPick;

  const _CoverPicker({
    required this.coverImageUrl,
    required this.isDark,
    required this.primary,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (coverImageUrl != null && coverImageUrl!.isNotEmpty) {
      return Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _coverWidget(coverImageUrl!),
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _showPicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Changer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? _kSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_rounded,
                color: primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajouter une couverture',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Galerie ou appareil photo',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? _kSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Photo de couverture',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: Color(0xFF3498DB),
              ),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                onPick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFF2ECC71),
              ),
              title: const Text('Appareil photo'),
              onTap: () {
                Navigator.pop(context);
                onPick(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverWidget(String url) {
    if (url.startsWith('data:image')) {
      try {
        final ci = url.indexOf(',');
        return Image.memory(
          base64Decode(ci != -1 ? url.substring(ci + 1) : url),
          fit: BoxFit.cover,
        );
      } catch (_) {
        return const Icon(Icons.broken_image);
      }
    }
    if (url.startsWith('http'))
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      );
    if (url.startsWith('assets/')) return Image.asset(url, fit: BoxFit.cover);
    return Image.file(
      File(url),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
    );
  }
}

// ── Étape 2 : Objectif ────────────────────────────────────────────────────────

class _StepObjectif extends StatelessWidget {
  final String objectif;
  final bool isDark;
  final Color primary;
  final double hPad;
  final void Function(String) onChanged;

  const _StepObjectif({
    required this.objectif,
    required this.isDark,
    required this.primary,
    required this.hPad,
    required this.onChanged,
  });

  static const _opts = [
    (
      'revision',
      Icons.schedule_rounded,
      'Révision',
      'Fiches, rappels, QCM — préparer un contrôle rapidement.',
    ),
    (
      'comprehension',
      Icons.school_rounded,
      'Comprendre de A à Z',
      'Progression terrain, exemples concrets, notions claires.',
    ),
    (
      'culture',
      Icons.auto_stories_rounded,
      'Culture & curiosité',
      'Enrichissement, liens, ton narratif et stimulant.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
      children: [
        Text(
          'Quel est votre objectif ?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "L'IA adaptera le style pédagogique en conséquence.",
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 20),
        ..._opts.map((o) {
          final sel = objectif == o.$1;
          return GestureDetector(
            onTap: () => onChanged(o.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sel
                    ? primary.withValues(alpha: isDark ? 0.18 : 0.08)
                    : (isDark ? _kSurface : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: sel
                      ? primary.withValues(alpha: 0.6)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06)),
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sel
                          ? primary.withValues(alpha: 0.15)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      o.$2,
                      size: 20,
                      color: sel
                          ? primary
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.$3,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          o.$4,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel ? primary : Colors.transparent,
                      border: Border.all(
                        color: sel
                            ? primary
                            : (isDark ? Colors.white24 : Colors.black26),
                        width: 1.5,
                      ),
                    ),
                    child: sel
                        ? const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Étape 3 : Langue ──────────────────────────────────────────────────────────

class _StepLangue extends StatelessWidget {
  final String langue;
  final bool isDark;
  final Color primary;
  final double hPad;
  final void Function(String) onChanged;

  const _StepLangue({
    required this.langue,
    required this.isDark,
    required this.primary,
    required this.hPad,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
      children: [
        Text(
          'Langue du contenu',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Dans quelle langue voulez-vous que l'IA génère les leçons ?",
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 20),
        _LangTile(
          value: 'fr',
          label: 'Français',
          flag: '🇫🇷',
          current: langue,
          primary: primary,
          isDark: isDark,
          onTap: onChanged,
        ),
        const SizedBox(height: 12),
        _LangTile(
          value: 'en',
          label: 'English',
          flag: '🇬🇧',
          current: langue,
          primary: primary,
          isDark: isDark,
          onTap: onChanged,
        ),
      ],
    );
  }
}

class _LangTile extends StatelessWidget {
  final String value, label, flag, current;
  final Color primary;
  final bool isDark;
  final void Function(String) onTap;

  const _LangTile({
    required this.value,
    required this.label,
    required this.flag,
    required this.current,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: sel
              ? primary.withValues(alpha: isDark ? 0.18 : 0.08)
              : (isDark ? _kSurface : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sel
                ? primary.withValues(alpha: 0.6)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06)),
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sel ? primary : Colors.transparent,
                border: Border.all(
                  color: sel
                      ? primary
                      : (isDark ? Colors.white24 : Colors.black26),
                  width: 1.5,
                ),
              ),
              child: sel
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Étape 4 : Documents ───────────────────────────────────────────────────────

class _StepDocuments extends StatelessWidget {
  final TextEditingController docsCtrl;
  final bool isOcrProcessing, isDark;
  final Color primary;
  final double hPad;
  final VoidCallback onPickCamera, onPickGallery, onPickPdf;
  final void Function(String) onTextChanged;

  const _StepDocuments({
    required this.docsCtrl,
    required this.isOcrProcessing,
    required this.isDark,
    required this.primary,
    required this.hPad,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onPickPdf,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
      children: [
        Text(
          'Documents & Images',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Optionnel — basez le cours sur vos propres supports.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _DocButton(
                icon: Icons.camera_alt_rounded,
                label: 'Photo',
                isDark: isDark,
                primary: primary,
                onTap: isOcrProcessing ? null : onPickCamera,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DocButton(
                icon: Icons.photo_library_rounded,
                label: 'Galerie',
                isDark: isDark,
                primary: primary,
                onTap: isOcrProcessing ? null : onPickGallery,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DocButton(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF',
                isDark: isDark,
                primary: primary,
                onTap: isOcrProcessing ? null : onPickPdf,
              ),
            ),
          ],
        ),
        if (isOcrProcessing) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Extraction en cours…',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _SectionLabel(label: 'Texte extrait ou saisi', isDark: isDark),
        const SizedBox(height: 8),
        TextField(
          controller: docsCtrl,
          maxLines: 14,
          onChanged: onTextChanged,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText:
                'Le texte extrait apparaîtra ici. Vous pouvez aussi saisir directement…',
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.black26,
              fontSize: 13,
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primary, width: 1.8),
            ),
            contentPadding: const EdgeInsets.all(16),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _DocButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color primary;
  final VoidCallback? onTap;

  const _DocButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? _kSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: onTap == null ? Colors.grey : primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: onTap == null
                    ? Colors.grey
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Étape 5 : Structure + Options ─────────────────────────────────────────────

class _StepStructure extends StatelessWidget {
  final List<String> chapitres;
  final TextEditingController chapitreCtrl;
  final String niveau;
  final bool enableTerminal, isDark;
  final DeepSeekModel selectedModel;
  final NgenouExtension? selectedExtension;
  final Color primary;
  final double hPad;
  final VoidCallback onAddChapitre;
  final void Function(String) onRemoveChapitre;
  final void Function(String) onNiveauChanged;
  final void Function(bool) onTerminalChanged;
  final void Function(DeepSeekModel) onModelChanged;
  final VoidCallback onOpenExtensionPicker, onRemoveExtension;

  const _StepStructure({
    required this.chapitres,
    required this.chapitreCtrl,
    required this.niveau,
    required this.enableTerminal,
    required this.isDark,
    required this.selectedModel,
    required this.selectedExtension,
    required this.primary,
    required this.hPad,
    required this.onAddChapitre,
    required this.onRemoveChapitre,
    required this.onNiveauChanged,
    required this.onTerminalChanged,
    required this.onModelChanged,
    required this.onOpenExtensionPicker,
    required this.onRemoveExtension,
  });

  static const _niveaux = [
    ('', 'Auto'),
    ('debutant', 'Débutant'),
    ('intermediaire', 'Intermédiaire'),
    ('avance', 'Avancé'),
  ];

  static const _models = [
    (DeepSeekModel.flash, Icons.bolt_rounded, Color(0xFF3498DB), 'Flash'),
    (DeepSeekModel.pro, Icons.auto_awesome, Color(0xFF6C3FE8), 'Pro'),
  ];

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.1),
      ),
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
      children: [
        Text(
          'Structure & Options',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tout est facultatif — l\'IA génère automatiquement si non précisé.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 18),

        // Chapitres
        _SectionLabel(label: 'Chapitres (facultatif)', isDark: isDark),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: chapitreCtrl,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Ex : Les fonctions',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: primary, width: 1.8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => onAddChapitre(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onAddChapitre,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ],
        ),
        if (chapitres.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...chapitres.map(
            (c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? _kSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.drag_indicator_rounded,
                    size: 16,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onRemoveChapitre(c),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),

        // Niveau
        _SectionLabel(label: 'Niveau (facultatif)', isDark: isDark),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _niveaux.map((n) {
            final sel = niveau == n.$1;
            return GestureDetector(
              onTap: () => onNiveauChanged(n.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: sel ? primary : (isDark ? _kSurface : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel
                        ? primary
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
                child: Text(
                  n.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // Modèle IA
        _SectionLabel(label: "Modèle d'IA", isDark: isDark),
        const SizedBox(height: 8),
        Row(
          children: _models.map((m) {
            final sel = selectedModel == m.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => onModelChanged(m.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                    right: m.$1 == DeepSeekModel.flash ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: sel
                        ? m.$3.withValues(alpha: isDark ? 0.15 : 0.08)
                        : (isDark ? _kSurface : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sel
                          ? m.$3
                          : (isDark ? Colors.white12 : Colors.black12),
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        m.$2,
                        size: 20,
                        color: sel
                            ? m.$3
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        m.$4,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel
                              ? m.$3
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // Terminal algorithmique
        _SectionCard(
          isDark: isDark,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.terminal_rounded,
                  color: Colors.orange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terminal algorithmique',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      'Exercices avec pseudo-code exécutable',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: enableTerminal,
                onChanged: onTerminalChanged,
                activeColor: primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Extension
        _SectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE67E22).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.extension_rounded,
                      color: Color(0xFFE67E22),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Extension pédagogique',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
                          selectedExtension != null
                              ? 'Active : ${selectedExtension!.nom}'
                              : 'Associez un outil interactif (optionnel)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedExtension != null)
                    GestureDetector(
                      onTap: onRemoveExtension,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenExtensionPicker,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE67E22),
                    side: const BorderSide(color: Color(0xFFE67E22)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(
                    selectedExtension != null
                        ? 'Changer l\'extension'
                        : 'Choisir une extension',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Étape 6 : Génération ──────────────────────────────────────────────────────

class _StepGeneration extends StatelessWidget {
  final bool isGenerating, isDark;
  final TextEditingController nomCtrl, classeCtrl;
  final String objectif, langue, schoolLevel;
  final List<String> chapitres;
  final String? coverImageUrl;
  final bool enableTerminal;
  final DeepSeekModel selectedModel;
  final Color primary;
  final double hPad;

  const _StepGeneration({
    required this.isGenerating,
    required this.isDark,
    required this.nomCtrl,
    required this.classeCtrl,
    required this.objectif,
    required this.langue,
    required this.schoolLevel,
    required this.chapitres,
    required this.coverImageUrl,
    required this.enableTerminal,
    required this.selectedModel,
    required this.primary,
    required this.hPad,
  });

  @override
  Widget build(BuildContext context) {
    if (isGenerating) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: PremiumLoader()),
      );
    }

    String _objLabel() => switch (objectif) {
      'revision' => 'Révision',
      'culture' => 'Culture',
      _ => 'Compréhension',
    };

    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
      children: [
        Text(
          'Prêt à générer !',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "L'IA va créer les leçons, structurer les notions et concevoir les exercices.",
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 20),

        // Récapitulatif
        _SectionCard(
          isDark: isDark,
          child: Column(
            children: [
              _RecapRow(
                icon: Icons.title_rounded,
                label: 'Nom',
                value: nomCtrl.text,
                primary: primary,
                isDark: isDark,
              ),
              _Divider(isDark: isDark),
              _RecapRow(
                icon: Icons.flag_outlined,
                label: 'Objectif',
                value: _objLabel(),
                primary: primary,
                isDark: isDark,
              ),
              _Divider(isDark: isDark),
              _RecapRow(
                icon: Icons.language_rounded,
                label: 'Langue',
                value: langue == 'fr' ? 'Français' : 'English',
                primary: primary,
                isDark: isDark,
              ),
              _Divider(isDark: isDark),
              _RecapRow(
                icon: Icons.school_rounded,
                label: 'Cycle & Classe',
                value:
                    '${schoolLevel.toUpperCase()} — ${classeCtrl.text.trim().isNotEmpty ? classeCtrl.text.trim() : "Non précisée"}',
                primary: primary,
                isDark: isDark,
              ),
              _Divider(isDark: isDark),
              _RecapRow(
                icon: Icons.format_list_bulleted_rounded,
                label: 'Structure',
                value: chapitres.isEmpty
                    ? 'Auto-générée'
                    : '${chapitres.length} chapitre(s)',
                primary: primary,
                isDark: isDark,
              ),
              _Divider(isDark: isDark),
              _RecapRow(
                icon: Icons.image_outlined,
                label: 'Couverture',
                value: coverImageUrl != null ? 'Personnalisée' : 'Par défaut',
                primary: primary,
                isDark: isDark,
              ),
              _Divider(isDark: isDark),
              _RecapRow(
                icon: selectedModel == DeepSeekModel.pro
                    ? Icons.auto_awesome
                    : Icons.bolt_rounded,
                label: 'Modèle IA',
                value: 'Ngenou ${selectedModel.label}',
                primary: primary,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Appuyez sur "Générer le cours" pour lancer la création. '
                  'L\'opération prend 15 à 45 secondes selon le modèle choisi.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecapRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color primary;
  final bool isDark;

  const _RecapRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(icon, size: 15, color: primary),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    color: isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06),
  );
}

// ── Dialog succès ─────────────────────────────────────────────────────────────

class _CourseCreatedDialog extends StatelessWidget {
  final String courseName;
  final bool isTeacher;

  const _CourseCreatedDialog({
    required this.courseName,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C28) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.2),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [const Color(0xFF2ECC71), primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Cours créé avec succès !',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '«\u00a0$courseName\u00a0»',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
            if (isTeacher) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '✅ Publié sur le catalogue',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2ECC71),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text(
                  'Ouvrir dans le Studio',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.12),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  foregroundColor: isDark ? Colors.white70 : Colors.black54,
                ),
                child: const Text(
                  'Terminer',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
