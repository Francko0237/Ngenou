import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/app_release.dart';
import '../../../core/models/release_feature.dart';
import '../../../core/supabase/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/responsive_layout.dart';

/// Formulaire de création / modification d'une version Ngenou (/admin/releases/new et /edit)
class AdminReleaseFormPage extends ConsumerStatefulWidget {
  final String? releaseId;

  const AdminReleaseFormPage({super.key, this.releaseId});

  @override
  ConsumerState<AdminReleaseFormPage> createState() =>
      _AdminReleaseFormPageState();
}

class _AdminReleaseFormPageState extends ConsumerState<AdminReleaseFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _versionNameController = TextEditingController();
  final _versionCodeController = TextEditingController();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _apkUrlController = TextEditingController();

  bool _forceUpdate = false;
  bool _isPublished = false;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  bool _isUploadingApk = false;

  int _highestExistingVersionCode = 0;
  List<ReleaseFeature> _features = [];

  bool get isEditing => widget.releaseId != null && widget.releaseId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _versionNameController.dispose();
    _versionCodeController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _apkUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final repo = ref.read(releaseRepositoryProvider);

    try {
      // Récupérer le code de version maximal pour la validation
      final all = await repo.getAllReleasesAdmin();
      if (all.isNotEmpty) {
        _highestExistingVersionCode =
            all.map((r) => r.versionCode).reduce((a, b) => a > b ? a : b);
      }

      if (isEditing) {
        final release = await repo.getReleaseById(widget.releaseId!);
        if (release != null) {
          _versionNameController.text = release.versionName;
          _versionCodeController.text = release.versionCode.toString();
          _titleController.text = release.title;
          _notesController.text = release.notes;
          _apkUrlController.text = release.apkUrl ?? '';
          _forceUpdate = release.forceUpdate;
          _isPublished = release.isPublished;
          _features = List.from(release.features);
        }
      } else {
        // Préremplir avec le code suivant
        final nextCode = _highestExistingVersionCode + 1;
        _versionCodeController.text = nextCode > 1 ? nextCode.toString() : '1';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des données : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  Future<void> _pickAndUploadApk() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _isUploadingApk = true);

    try {
      final repo = ref.read(releaseRepositoryProvider);
      final publicUrl = await repo.uploadApk(
        bytes: file.bytes!,
        fileName: file.name,
      );

      setState(() {
        _apkUrlController.text = publicUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fichier APK téléversé avec succès dans le bucket apks !'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec du téléversement de l\'APK : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingApk = false);
      }
    }
  }

  Future<void> _openFeatureEditorDialog([ReleaseFeature? existing, int? index]) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    String? imageUrl = existing?.imageUrl;
    Uint8List? localPreviewBytes;
    bool isUploadingImage = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            title: Text(
              existing == null
                  ? 'Ajouter une fonctionnalité'
                  : 'Modifier la fonctionnalité',
              style: GoogleFonts.fraunces(
                fontSize: 20,
                color: AppColors.text,
              ),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Titre de la fonctionnalité *',
                        style: TextStyle(fontSize: 13, color: AppColors.text)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ex: Tuteur conversationnel vocal',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Description détaillée *',
                        style: TextStyle(fontSize: 13, color: AppColors.text)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Expliquez ce qu\'apporte cette nouveauté...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Image d\'illustration (optionnelle - max 1 Mo)',
                        style: TextStyle(fontSize: 13, color: AppColors.text)),
                    const SizedBox(height: 8),

                    // Aperçu de l'image
                    if (localPreviewBytes != null ||
                        (imageUrl != null && imageUrl!.isNotEmpty)) ...[
                      Center(
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFF070E20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: localPreviewBytes != null
                                ? Image.memory(localPreviewBytes!, fit: BoxFit.contain)
                                : Image.network(
                                    imageUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image_rounded,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: isUploadingImage
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final result =
                                      await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
                                    withData: true,
                                  );

                                  if (result == null || result.files.isEmpty) return;
                                  final file = result.files.first;
                                  if (file.bytes == null) return;

                                  if (file.bytes!.lengthInBytes > 1024 * 1024) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'L\'image dépasse 1 Mo. Veuillez choisir une image compressée.',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() {
                                    localPreviewBytes = file.bytes;
                                    isUploadingImage = true;
                                  });

                                  try {
                                    final repo = ref.read(releaseRepositoryProvider);
                                    final uploadedUrl = await repo.uploadMedia(
                                      bytes: file.bytes!,
                                      fileName: file.name,
                                    );
                                    setDialogState(() {
                                      imageUrl = uploadedUrl;
                                      isUploadingImage = false;
                                    });
                                  } catch (e) {
                                    setDialogState(() => isUploadingImage = false);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Erreur upload : $e'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                },
                          icon: isUploadingImage
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cloud_upload_outlined, size: 18),
                          label: Text(
                            imageUrl != null ? 'Changer l\'image' : 'Téléverser image',
                          ),
                        ),
                        if (imageUrl != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Supprimer l\'image',
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.error, size: 20),
                            onPressed: () {
                              setDialogState(() {
                                imageUrl = null;
                                localPreviewBytes = null;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Annuler',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: isUploadingImage
                    ? null
                    : () {
                        if (titleCtrl.text.trim().isEmpty ||
                            bodyCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Veuillez renseigner le titre et la description.'),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                          return;
                        }

                        final newFeature = ReleaseFeature(
                          id: existing?.id ?? '',
                          releaseId: widget.releaseId ?? '',
                          title: titleCtrl.text.trim(),
                          body: bodyCtrl.text.trim(),
                          imageUrl: imageUrl,
                          sortOrder: index ?? _features.length,
                        );

                        setState(() {
                          if (index != null) {
                            _features[index] = newFeature;
                          } else {
                            _features.add(newFeature);
                          }
                        });

                        Navigator.pop(dialogCtx);
                      },
                child: const Text('Enregistrer la fonctionnalité'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final code = int.tryParse(_versionCodeController.text.trim()) ?? 0;

    // Vérifier que le versionCode est supérieur pour une nouvelle version
    if (!isEditing && code <= _highestExistingVersionCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Le code de version ($code) doit être strictement supérieur au précédent ($_highestExistingVersionCode).',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(releaseRepositoryProvider);

      final release = AppRelease(
        id: widget.releaseId ?? '',
        versionName: _versionNameController.text.trim(),
        versionCode: code,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        apkUrl: _apkUrlController.text.trim().isNotEmpty
            ? _apkUrlController.text.trim()
            : null,
        forceUpdate: _forceUpdate,
        isPublished: _isPublished,
        publishedAt: _isPublished ? DateTime.now() : null,
      );

      final saved = await repo.saveRelease(release);

      // Enregistrer les fonctionnalités avec le releaseId
      await repo.saveFeatures(saved.id, _features);

      // Invalider les caches Riverpod
      ref.invalidate(adminReleasesProvider);
      ref.invalidate(publishedReleasesProvider);
      ref.invalidate(latestReleaseProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Version ${saved.versionName} mise à jour avec succès.'
                  : 'Nouvelle version ${saved.versionName} créée avec succès !',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/admin');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.cyan),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: Text(
          isEditing ? 'Modifier la version' : 'Créer une nouvelle version',
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.horizontalPadding(context),
          vertical: 36,
        ),
        child: ResponsiveContainer(
          maxWidth: 900,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bloc Informations Générales
                _buildCardSection(
                  title: 'Informations de la version',
                  icon: Icons.info_outline_rounded,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nom de version (version_name) *',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _versionNameController,
                                decoration: const InputDecoration(
                                  hintText: 'Ex: 1.2.0',
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Renseignez un nom de version (ex: 1.2.0)';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Code de build (version_code) *',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _versionCodeController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Ex: 12',
                                  helperText: 'Dernier existant : $_highestExistingVersionCode',
                                ),
                                validator: (val) {
                                  final num = int.tryParse(val ?? '');
                                  if (num == null) {
                                    return 'Entier requis';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Titre de la mise à jour *',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Ex: Mise à jour majeure : Ngenou Assets & Mode Hors-Ligne',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Renseignez un titre pour cette mise à jour';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Notes de version / Changelog global *',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Décrivez les nouveautés clés de cette version...',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Renseignez les notes de version';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Bloc Fichier APK & Téléchargement
                _buildCardSection(
                  title: 'Fichier APK & Téléchargement',
                  icon: Icons.android_rounded,
                  children: [
                    const Text('Lien du fichier APK (URL externe ou upload dans le bucket "apks")',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _apkUrlController,
                            decoration: const InputDecoration(
                              hintText: 'https://ngenou.top/Ngenou.apk',
                              prefixIcon: Icon(Icons.link_rounded, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isUploadingApk ? null : _pickAndUploadApk,
                          icon: _isUploadingApk
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file_rounded),
                          label: const Text('Uploader APK'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Switches Force update & Publier
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.error,
                      title: const Text(
                        'Mise à jour obligatoire (force_update)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Si activé, l\'application mobile affichera un dialogue bloquant non-fermable invitant à mettre à jour.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      value: _forceUpdate,
                      onChanged: (val) => setState(() => _forceUpdate = val),
                    ),
                    const Divider(height: 32),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.cyan,
                      title: const Text(
                        'Publier immédiatement en ligne (is_published)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Si désactivé, la version sera conservée en brouillon et invisible pour le grand public.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      value: _isPublished,
                      onChanged: (val) => setState(() => _isPublished = val),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Bloc Fonctionnalités de cette version
                _buildCardSection(
                  title: 'Fonctionnalités de cette version (${_features.length})',
                  icon: Icons.auto_awesome_rounded,
                  action: ElevatedButton.icon(
                    onPressed: () => _openFeatureEditorDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Ajouter'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                  children: [
                    if (_features.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF070E20),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: const Center(
                          child: Text(
                            'Aucune fonctionnalité ajoutée. Cliquez sur "Ajouter" pour illustrer cette version.',
                            style: TextStyle(color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _features.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _features.removeAt(oldIndex);
                            _features.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (ctx, index) {
                          final feat = _features[index];
                          return Container(
                            key: ValueKey('feat_${feat.title}_$index'),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF070E20),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.drag_indicator_rounded,
                                    color: AppColors.textMuted),
                                const SizedBox(width: 12),
                                if (feat.imageUrl != null && feat.imageUrl!.isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      feat.imageUrl!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.image_not_supported_rounded,
                                        size: 32,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        feat.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        feat.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: AppColors.cyan, size: 20),
                                  onPressed: () =>
                                      _openFeatureEditorDialog(feat, index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.error, size: 20),
                                  onPressed: () {
                                    setState(() => _features.removeAt(index));
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 36),

                // Boutons d'action
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go('/admin'),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 18),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.background,
                              ),
                            )
                          : Text(
                              isEditing
                                  ? 'Mettre à jour la version'
                                  : 'Enregistrer la version',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? action,
  }) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.cyan, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}
