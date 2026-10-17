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

class CourseBuilderWizardPage extends StatefulWidget {
  /// Si fourni, le cours créé sera automatiquement rattaché à ce projet.
  final String? projetId;

  const CourseBuilderWizardPage({super.key, this.projetId});

  @override
  State<CourseBuilderWizardPage> createState() =>
      _CourseBuilderWizardPageState();
}

class _CourseBuilderWizardPageState extends State<CourseBuilderWizardPage> {
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
  String _schoolLevel = 'secondaire'; // primaire, secondaire, superieur
  String? _coverImageUrl;
  String? _userRole;
  bool _hasDocuments = false;
  bool _enableTerminal = false;
  final List<String> _chapitres = [];
  DeepSeekModel _selectedModel = DeepSeekModel.flash;

  String? _generatedPrompt;
  bool _isGenerating = false;
  bool _isOcrProcessing = false;
  late final String _matiereId =
      'custom_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  Future<void> _loadUserContext() async {
    final role = await AuthService.getUserRole();
    final lvl = await AuthService.getSchoolLevel();
    if (mounted) {
      setState(() {
        _userRole = role;
        if (lvl != null && lvl.isNotEmpty) {
          _schoolLevel = lvl;
          if (_classeCtrl.text.isEmpty) {
            _classeCtrl.text = _getDefaultClasseForLevel(lvl);
          }
        } else if (_classeCtrl.text.isEmpty) {
          _classeCtrl.text = '6ème';
        }
      });
    }
  }

  String _getDefaultClasseForLevel(String lvl) {
    switch (lvl) {
      case 'primaire':
        return 'CM2';
      case 'secondaire':
        return '6ème';
      case 'superieur':
        return 'Licence 1';
      default:
        return '6ème';
    }
  }

  List<String> _getSuggestedClassesForLevel(String lvl) {
    switch (lvl) {
      case 'primaire':
        return ['SIL', 'CP', 'CE1', 'CE2', 'CM1', 'CM2'];
      case 'secondaire':
        return ['6ème', '5ème', '4ème', '3ème', '2nde', '1ère', 'Terminale'];
      case 'superieur':
        return ['Licence 1', 'Licence 2', 'Licence 3', 'Master'];
      default:
        return ['6ème', '5ème', '4ème', '3ème', '2nde', '1ère', 'Terminale'];
    }
  }

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

  Future<void> _pickCoverImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 800,
      imageQuality: 82,
    );
    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        _coverImageUrl = 'data:image/jpeg;base64,$base64String';
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      await _processFileForOcr(File(pickedFile.path), isPdf: false);
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      await _processFileForOcr(File(result.files.single.path!), isPdf: true);
    }
  }

  Future<void> _processFileForOcr(File file, {required bool isPdf}) async {
    setState(() => _isOcrProcessing = true);
    try {
      final text = isPdf
          ? await OcrService.extractTextFromPdf(file)
          : await OcrService.extractTextFromImage(file);

      if (text.isEmpty) {
        throw Exception(
          "Aucun texte exploitable n'a pu être extrait de ce fichier.",
        );
      }

      setState(() {
        final currentText = _docsCtrl.text.trim();
        if (currentText.isEmpty) {
          _docsCtrl.text = text;
        } else {
          _docsCtrl.text = '$currentText\n\n---\n\n$text';
        }
        _hasDocuments = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Texte extrait avec succès ! Vous pouvez le relire et le modifier ci-dessous.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(formatUserError(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _isOcrProcessing = false);
      }
    }
  }

  void _next() {
    final err = _validateCurrentStep();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_step == 5) {
      _buildPrompt();
    }
    if (_step < 6) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  String? _validateCurrentStep() {
    switch (_step) {
      case 0:
        if (_nomCtrl.text.trim().isEmpty) {
          return 'Indiquez le nom du cours.';
        }
        if (_classeCtrl.text.trim().isEmpty) {
          return 'Veuillez préciser la classe ciblée (ex: 3ème, CM2, Terminale...).';
        }
        return null;
      case 1:
        return null;
      case 2:
        return null;
      case 3:
        return null;
      case 4:
        return null;
      default:
        return null;
    }
  }

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
      classe: _classeCtrl.text.trim().isNotEmpty ? _classeCtrl.text.trim() : null,
      coverImageUrl: _coverImageUrl,
      chapitres: List.from(_chapitres),
      enableTerminal: _enableTerminal,
      matiereId: _matiereId,
    );
    setState(() {
      _generatedPrompt = CoursePromptBuilder.build(input);
    });
  }

  void _addChapitre() {
    final t = _chapitreCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _chapitres.add(t);
      _chapitreCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titles = [
      'Informations',
      'Objectif',
      'Langue',
      'Documents',
      'Structure',
      'Options',
      'Génération',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Créer un cours — ${titles[_step]}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / titles.length,
            minHeight: 4,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _stepInfo(isDark),
                _stepObjectif(isDark),
                _stepLangue(isDark),
                _stepDocuments(isDark),
                _stepStructure(isDark),
                _stepOptions(isDark),
                _stepPrompt(isDark),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_step > 0 && !_isGenerating)
                    TextButton(onPressed: _back, child: const Text('Retour')),
                  const Spacer(),
                  if (_step < 6)
                    ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(120, 48),
                      ),
                      child: _step == 5
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, size: 16),
                                SizedBox(width: 8),
                                Text('Générer le cours'),
                              ],
                            )
                          : const Text('Suivant'),
                    )
                  else ...[
                    ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateWithDeepSeek,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Générer le cours'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(160, 48),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepInfo(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          elevation: 0,
          color: Theme.of(context).primaryColor.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).primaryColor.withOpacity(0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.upload_file_rounded,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Importer un cours existant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const CourseImportPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Sélectionner le fichier'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark ? Colors.grey[700] : Colors.grey[400],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'ou assistant',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark ? Colors.grey[700] : Colors.grey[400],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_userRole == 'teacher') ...[
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
                Icon(Icons.verified_user_rounded, color: Color(0xFF6C63FF), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Compte Enseignant : Ce cours sera publié dans les « Cours publics » dès sa création.',
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
        Text(
          'Donnez un titre à votre cours',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ce nom apparaîtra sur l\'écran d\'accueil après import.',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nomCtrl,
          decoration: const InputDecoration(
            labelText: 'Nom du cours *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Description courte',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),

        // Photo de couverture
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Photo de couverture',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (_coverImageUrl != null)
              TextButton.icon(
                onPressed: () => setState(() => _coverImageUrl = null),
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                label: const Text('Supprimer', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCoverImagePicker(isDark),
        const SizedBox(height: 24),

        // Niveau d'enseignement
        Text(
          'Niveau d\'enseignement *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Indique le cycle scolaire du cours.',
          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white54 : Colors.black54),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _schoolLevelChip('primaire', 'Primaire', Icons.child_care_rounded, isDark),
            _schoolLevelChip('secondaire', 'Secondaire', Icons.school_rounded, isDark),
            _schoolLevelChip('superieur', 'Supérieur', Icons.psychology_rounded, isDark),
          ],
        ),
        const SizedBox(height: 22),

        // Classe
        Text(
          'Classe ciblée *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Précisez la classe pour adapter le niveau pédagogique.',
          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white54 : Colors.black54),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _classeCtrl,
          decoration: InputDecoration(
            labelText: 'Classe (ex: 3ème, CM2, Terminale...)',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.class_rounded),
            suffixIcon: _classeCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _classeCtrl.clear()),
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _getSuggestedClassesForLevel(_schoolLevel).map((c) {
            final isSelected = _classeCtrl.text.trim().toLowerCase() == c.toLowerCase();
            return ActionChip(
              avatar: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              label: Text(c),
              backgroundColor: isSelected
                  ? Theme.of(context).primaryColor
                  : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEFF2F7)),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
              onPressed: () {
                setState(() {
                  _classeCtrl.text = c;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _schoolLevelChip(String level, String label, IconData icon, bool isDark) {
    final isSelected = _schoolLevel == level;
    final primary = Theme.of(context).primaryColor;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: primary,
      backgroundColor: isDark ? const Color(0xFF222222) : const Color(0xFFF0F2F5),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _schoolLevel = level;
            final suggestions = _getSuggestedClassesForLevel(level);
            if (suggestions.isNotEmpty && !_classeCtrl.text.contains(level)) {
              _classeCtrl.text = suggestions.last;
            }
          });
        }
      },
    );
  }

  Widget _buildCoverImagePicker(bool isDark) {
    final primary = Theme.of(context).primaryColor;

    if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty) {
      return Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCoverPreviewWidget(_coverImageUrl!),
            Positioned(
              bottom: 8,
              right: 8,
              child: ElevatedButton.icon(
                onPressed: () => _showCoverPickerDialog(isDark),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Changer l\'image', style: TextStyle(fontSize: 11.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showCoverPickerDialog(isDark),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
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
              child: Icon(Icons.add_photo_alternate_rounded, color: primary, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              'Choisir une photo de couverture',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Galerie, appareil photo ou illustration prédéfinie',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPreviewWidget(String url) {
    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        final base64Str = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image, size: 36));
      }
    } else if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 36)),
      );
    } else if (url.startsWith('assets/')) {
      return Image.asset(url, fit: BoxFit.cover);
    } else {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 36)),
      );
    }
  }

  void _showCoverPickerDialog(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Photo de couverture du cours',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF3498DB)),
                title: const Text('Choisir dans la galerie'),
                subtitle: const Text('Importer une image depuis votre appareil'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCoverImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2ECC71)),
                title: const Text('Prendre une photo'),
                subtitle: const Text('Prendre directement une photo avec la caméra'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCoverImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_stories_rounded, color: Color(0xFF9B59B6)),
                title: const Text('Choisir une illustration prédéfinie'),
                subtitle: const Text('Maths, Sciences, Informatique, Littérature...'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPresetIllustrationsDialog(isDark);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded, color: Color(0xFFE67E22)),
                title: const Text('Saisir l\'URL d\'une image web'),
                subtitle: const Text('Coller un lien https vers une image'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showUrlInputDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPresetIllustrationsDialog(bool isDark) {
    final presets = [
      {
        'title': 'Mathématiques',
        'url': 'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=600&auto=format&fit=crop&q=80',
        'icon': Icons.calculate_rounded,
      },
      {
        'title': 'Sciences & Chimie',
        'url': 'https://images.unsplash.com/photo-1532094349884-543bc11b234d?w=600&auto=format&fit=crop&q=80',
        'icon': Icons.biotech_rounded,
      },
      {
        'title': 'Informatique & Code',
        'url': 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=600&auto=format&fit=crop&q=80',
        'icon': Icons.code_rounded,
      },
      {
        'title': 'Littérature & Français',
        'url': 'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?w=600&auto=format&fit=crop&q=80',
        'icon': Icons.menu_book_rounded,
      },
      {
        'title': 'Histoire & Géographie',
        'url': 'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=600&auto=format&fit=crop&q=80',
        'icon': Icons.public_rounded,
      },
      {
        'title': 'Économie & Gestion',
        'url': 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=600&auto=format&fit=crop&q=80',
        'icon': Icons.trending_up_rounded,
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Illustrations prédéfinies'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final p = presets[index];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _coverImageUrl = p['url'] as String);
                  Navigator.pop(ctx);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        p['url'] as String,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(p['icon'] as IconData, color: Colors.white, size: 24),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                p['title'] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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

  void _showUrlInputDialog() {
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('URL de l\'image'),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            labelText: 'https://exemple.com/image.jpg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlCtrl.text.trim();
              if (url.isNotEmpty) {
                setState(() => _coverImageUrl = url);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Widget _stepObjectif(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Quel est votre objectif ?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _objectifTile(
          'revision',
          'Révision',
          'Fiches, rappels, QCM pour préparer un contrôle',
          Icons.schedule_rounded,
        ),
        _objectifTile(
          'comprehension',
          'Comprendre de A à Z',
          'Progression terrain, exemples concrets',
          Icons.school_rounded,
        ),
        _objectifTile(
          'culture',
          'Culture & curiosité',
          'Enrichissement, liens, ton plus narratif',
          Icons.auto_stories_rounded,
        ),
      ],
    );
  }

  Widget _objectifTile(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final selected = _objectif == value;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: selected ? Theme.of(context).primaryColor.withOpacity(0.12) : null,
      child: ListTile(
        leading: Icon(
          icon,
          color: selected ? Theme.of(context).primaryColor : null,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: selected
            ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
            : null,
        onTap: () => setState(() => _objectif = value),
      ),
    );
  }

  Widget _stepLangue(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Langue du contenu généré',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        RadioListTile<String>(
          title: const Text('Français'),
          value: 'fr',
          groupValue: _langue,
          onChanged: (v) => setState(() => _langue = v!),
        ),
        RadioListTile<String>(
          title: const Text('English'),
          value: 'en',
          groupValue: _langue,
          onChanged: (v) => setState(() => _langue = v!),
        ),
      ],
    );
  }

  Widget _stepDocuments(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Documents & Images',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Générez votre cours à partir de vos propres supports .',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isOcrProcessing
                    ? null
                    : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Photo', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isOcrProcessing
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Galerie', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isOcrProcessing ? null : _pickPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Importer un PDF'),
          ),
        ),
        if (_isOcrProcessing) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          const Center(child: Text("Extraction du texte en cours...")),
        ],
        const SizedBox(height: 24),
        TextField(
          controller: _docsCtrl,
          maxLines: 15,
          onChanged: (v) {
            final hasDoc = v.trim().isNotEmpty;
            if (hasDoc != _hasDocuments) {
              setState(() {
                _hasDocuments = hasDoc;
              });
            }
          },
          decoration: const InputDecoration(
            labelText: 'Texte extrait (Modifiable)',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
            hintText:
                'Le texte extrait de vos images ou PDF apparaîtra ici. Vous pouvez le relire et le corriger si nécessaire avant de générer le cours.',
          ),
        ),
      ],
    );
  }

  Widget _stepStructure(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Structure du cours',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chapitres et niveau sont facultatifs. L\'IA les génère automatiquement si vous ne les précisez pas.',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        Text(
          'Chapitres du cours (facultatif)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _chapitres.isEmpty
              ? 'Aucun chapitre ajouté — l\'IA proposera un plan adapté.'
              : '${_chapitres.length} chapitre(s) défini(s)',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chapitreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nouveau chapitre',
                  hintText: 'Ex : Les variables',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addChapitre(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addChapitre,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._chapitres.map(
          (c) => Card(
            child: ListTile(
              title: Text(c),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _chapitres.remove(c)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Niveau du cours (facultatif)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _niveau.isEmpty
              ? 'Non précisé — l\'IA déterminera le niveau adapté.'
              : 'Niveau sélectionné : ${_niveauLabel(_niveau)}',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _niveauChip('', 'Auto', isDark),
            _niveauChip('debutant', 'Débutant', isDark),
            _niveauChip('intermediaire', 'Intermédiaire', isDark),
            _niveauChip('avance', 'Avancé', isDark),
          ],
        ),
      ],
    );
  }

  String _niveauLabel(String value) => switch (value) {
    'debutant' => 'Débutant',
    'intermediaire' => 'Intermédiaire',
    'avance' => 'Avancé',
    _ => 'Auto',
  };

  Widget _niveauChip(String value, String label, bool isDark) {
    final selected = _niveau == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _niveau = value),
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
      side: BorderSide(
        color: selected
            ? Theme.of(context).primaryColor
            : (isDark ? Colors.grey[700]! : Colors.grey[400]!),
      ),
    );
  }

  Widget _stepOptions(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Options avancées',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        // ── Sélecteur de modèle ──────────────────────────────────────────
        _buildModelSelectorTile(isDark),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text(
            'Exercices avec terminal pour les cours d\'algorithmique)',
          ),
          subtitle: const Text(
            'Autorise les exercices "editeur" avec pseudo-code exécutable',
          ),
          value: _enableTerminal,
          onChanged: (v) => setState(() => _enableTerminal = v),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.tag),
          title: const Text('Identifiant du cours'),
          subtitle: Text(
            _matiereId,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  Widget _buildModelSelectorTile(bool isDark) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
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
          ),
          Row(
            children: [
              _modelChip(
                DeepSeekModel.flash,
                Icons.bolt_rounded,
                const Color(0xFF3498DB),
                isDark,
              ),
              _modelChip(
                DeepSeekModel.pro,
                Icons.auto_awesome,
                const Color(0xFF6C3FE8),
                isDark,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Text(
              _selectedModel.description,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
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
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  void _generateWithDeepSeek() async {
    if (_generatedPrompt == null) {
      _buildPrompt();
    }
    if (_generatedPrompt == null) return;

    setState(() => _isGenerating = true);

    try {
      final result = await DeepSeekService.generateCourse(
        _generatedPrompt!,
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

      // Clean potential JSON markdown blocks if any
      String cleanJson = result.content.trim();
      if (cleanJson.startsWith("```")) {
        final firstLineEnd = cleanJson.indexOf('\n');
        if (firstLineEnd != -1) {
          cleanJson = cleanJson.substring(firstLineEnd).trim();
        }
        if (cleanJson.endsWith("```")) {
          cleanJson = cleanJson.substring(0, cleanJson.length - 3).trim();
        }
      }

      final validation = CourseImportValidator.validate(cleanJson);
      if (!validation.isValid) {
        throw Exception(
          "Le cours généré n'est pas valide :\n${validation.errors.join("\n")}",
        );
      }

      final pkg = validation.package!;
      final customProvider = context.read<CustomCoursesProvider>();
      final err = await customProvider.importCourse(pkg);
      if (err != null) {
        throw Exception(err);
      }

      await context.read<ProgressionProvider>().loadProgression(pkg.matiere.id);

      // Si un projetId est fourni, rattacher le cours au projet
      if (widget.projetId != null && mounted) {
        await context.read<ProjetsProvider>().addMatiereToProjet(
          widget.projetId!,
          pkg.matiere.id,
        );
      }
      // Si le créateur est un enseignant, publier également dans le catalogue public
      final userRole = await AuthService.getUserRole();
      if (userRole == 'teacher') {
        try {
          await TeacherCoursesService.publishCourse(
            package: pkg,
            schoolLevel: _schoolLevel,
            classe: _classeCtrl.text.trim().isNotEmpty ? _classeCtrl.text.trim() : null,
            coverImageUrl: _coverImageUrl,
            isPublished: true,
          );
        } catch (e) {
          debugPrint('Erreur publication catalogue enseignant : $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userRole == 'teacher'
                  ? 'Cours « ${pkg.matiere.nom} » créé et publié sur le catalogue !'
                  : 'Cours « ${pkg.matiere.nom} » généré et importé avec succès !',
            ),
          ),
        );
        Navigator.pop(context, pkg.matiere.id); // retourne l'ID du cours créé
      }
    } on QuotaExceededException catch (e) {
      // Quota Pro bloqué → dialog clair, aucun appel API n'a été fait
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Mode Pro indisponible'),
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
      debugPrint('Erreur génération cours : $e\n$stack');
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text('Génération interrompue'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatUserError(e),
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: const Text(
                        'Détails techniques',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      tilePadding: EdgeInsets.zero,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            e.toString(),
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
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
              ElevatedButton.icon(
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
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Widget _stepPrompt(bool isDark) {
    if (_isGenerating) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: PremiumLoader()),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Prêt pour la génération',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'L\'intelligence artificielle va structurer votre cours, rédiger les leçons et concevoir les exercices d\'entraînement adaptés.',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Récapitulatif de la configuration :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _summaryRow(Icons.title, 'Nom :', _nomCtrl.text),
                _summaryRow(
                  Icons.flag_outlined,
                  'Objectif :',
                  _objectif == 'revision'
                      ? 'Révision'
                      : (_objectif == 'culture'
                            ? 'Culture'
                            : 'Compréhension terrain'),
                ),
                _summaryRow(
                  Icons.language,
                  'Langue :',
                  _langue == 'fr' ? 'Français' : 'Anglais',
                ),
                _summaryRow(
                  Icons.format_list_bulleted,
                  'Structure :',
                  _chapitres.isEmpty
                      ? 'Chapitres auto-générés'
                      : '${_chapitres.length} chapitre(s)',
                ),
                _summaryRow(
                  Icons.trending_up,
                  'Cycle & Classe :',
                  '${_schoolLevel.toUpperCase()} — ${_classeCtrl.text.trim().isNotEmpty ? _classeCtrl.text.trim() : "Non précisée"}',
                ),
                _summaryRow(
                  Icons.image_outlined,
                  'Couverture :',
                  _coverImageUrl != null ? 'Personnalisée' : 'Standard / Par défaut',
                ),
                _summaryRow(
                  Icons.terminal,
                  'Terminal :',
                  _enableTerminal
                      ? 'Activé (exercices d\'algorithmique)'
                      : 'Désactivé (QCM uniquement)',
                ),
                _summaryRow(
                  _selectedModel == DeepSeekModel.pro
                      ? Icons.auto_awesome
                      : Icons.bolt_rounded,
                  'Modèle IA :',
                  'Ngenou ${_selectedModel.label} — ${_selectedModel.description}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          color: Theme.of(context).primaryColor.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cliquez sur le bouton ci-dessous pour lancer la création par l\'IA.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
