import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/fichiers_provider.dart';
import '../../core/theme/app_colors.dart';

/// Page « Gestionnaire de Fichiers Algorithmiques » (/fichiers)
/// Design adaptatif PC (Master-Detail Split) et Mobile (Liste -> Tableau),
/// aligné avec AppTheme et doté d'un FAB ergonomique.
class FichiersPage extends StatefulWidget {
  const FichiersPage({super.key});

  @override
  State<FichiersPage> createState() => _FichiersPageState();
}

class _FichiersPageState extends State<FichiersPage> {
  String? _openFileName;
  List<AlgoFileRecord> _records = [];
  bool _loadingRecords = false;

  // Recherche & filtres
  final TextEditingController _fileSearchCtrl = TextEditingController();
  final TextEditingController _recordSearchCtrl = TextEditingController();
  String _fileQuery = '';
  String _recordQuery = '';

  // Pour le FAB speed-dial
  bool _fabOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<FichiersProvider>();
      await provider.loadFiles();
      if (!mounted) return;
      // Sur PC, sélectionner automatiquement le premier fichier s'il existe
      if (MediaQuery.of(context).size.width >= 900 &&
          provider.files.isNotEmpty &&
          _openFileName == null) {
        _openFile(provider.files.first.name);
      }
    });
  }

  @override
  void dispose() {
    _fileSearchCtrl.dispose();
    _recordSearchCtrl.dispose();
    super.dispose();
  }

  // ── Navigation interne ────────────────────────────────────────────────────

  Future<void> _openFile(String name) async {
    setState(() {
      _openFileName = name;
      _loadingRecords = true;
      _fabOpen = false;
      _recordQuery = '';
      _recordSearchCtrl.clear();
    });
    final provider = context.read<FichiersProvider>();
    final records = await provider.readRecords(name);
    if (mounted) {
      setState(() {
        _records = records;
        _loadingRecords = false;
      });
    }
  }

  void _closeFile() {
    setState(() {
      _openFileName = null;
      _records = [];
      _fabOpen = false;
      _recordQuery = '';
      _recordSearchCtrl.clear();
    });
  }

  Future<void> _reloadRecords() async {
    if (_openFileName == null) return;
    final provider = context.read<FichiersProvider>();
    final records = await provider.readRecords(_openFileName!);
    if (mounted) setState(() => _records = records);
  }

  // ── Dialogues & actions ───────────────────────────────────────────────────

  Future<void> _showCreateDialog() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _NomFichierDialog(
        title: 'Créer un fichier',
        confirmLabel: 'Créer',
        icon: Icons.create_new_folder_rounded,
        controller: ctrl,
      ),
    );
    if (confirmed != true || !mounted) return;
    final newName = ctrl.text.trim();
    final error = await context.read<FichiersProvider>().createFile(newName);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, error: true);
    } else {
      _showSnack('Fichier « $newName » créé.');
      if (MediaQuery.of(context).size.width >= 900) {
        _openFile(newName);
      }
    }
  }

  Future<void> _showRenameDialog(String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _NomFichierDialog(
        title: 'Renommer le fichier',
        confirmLabel: 'Renommer',
        icon: Icons.drive_file_rename_outline_rounded,
        controller: ctrl,
      ),
    );
    if (confirmed != true || !mounted) return;
    final newName = ctrl.text.trim();
    final error = await context
        .read<FichiersProvider>()
        .renameFile(oldName, newName);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, error: true);
    } else {
      if (_openFileName == oldName) {
        setState(() => _openFileName = newName);
      }
      _showSnack('Renommé en « $newName ».');
    }
  }

  Future<void> _confirmDelete(String name) async {
    final ok = await _showDeleteConfirmDialog(
      title: 'Supprimer ce fichier ?',
      message:
          'Le fichier « $name » sera définitivement supprimé. Cette action est irréversible.',
    );
    if (ok != true || !mounted) return;
    final error = await context.read<FichiersProvider>().deleteFile(name);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, error: true);
    } else {
      if (_openFileName == name) {
        _closeFile();
      }
      _showSnack('Fichier « $name » supprimé.');
    }
  }

  Future<bool?> _showDeleteConfirmDialog({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor:
              isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null || !mounted) {
        return;
      }
      final importedName = result.files.single.name;
      final err = await context
          .read<FichiersProvider>()
          .importFile(result.files.single.path!);
      if (!mounted) return;
      if (err != null) {
        _showSnack(err, error: true);
      } else {
        _showSnack('Fichier « $importedName » importé.');
        if (MediaQuery.of(context).size.width >= 900) {
          _openFile(importedName);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur d\'import : $e', error: true);
    }
  }

  Future<void> _exportFile(String name) async {
    try {
      final path = await context.read<FichiersProvider>().getFilePath(name);
      if (path == null || !mounted) {
        _showSnack('Fichier introuvable sur le disque.', error: true);
        return;
      }

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final savePath = await FilePicker.saveFile(
          dialogTitle: 'Exporter $name',
          fileName: name,
        );
        if (savePath != null) {
          await File(path).copy(savePath);
          if (mounted) _showSnack('Exporté vers $savePath');
        }
      } else {
        await Share.shareXFiles(
          [XFile(path)],
          text: 'Fichier algorithmique Ngenou : $name',
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur d\'export : $e', error: true);
    }
  }

  dynamic _parseCellValue(String raw, dynamic originalValue) {
    final trimmed = raw.trim();
    if (originalValue is int) {
      return int.tryParse(trimmed) ?? raw;
    }
    if (originalValue is double) {
      return double.tryParse(trimmed) ?? raw;
    }
    if (originalValue is bool) {
      final lower = trimmed.toLowerCase();
      if (lower == 'true' || lower == 'vrai') return true;
      if (lower == 'false' || lower == 'faux') return false;
    }
    return raw;
  }

  Future<void> _showAddRecordDialog() async {
    if (_records.isEmpty) {
      await _showRawRecordDialog(null);
      return;
    }
    final first = _records.first;
    final template = first.fields.map((k, v) {
      if (v is int) return MapEntry(k, 0);
      if (v is double) return MapEntry(k, 0.0);
      if (v is bool) return MapEntry(k, false);
      return MapEntry(k, '');
    });
    await _showRecordEditDialog(null, template, isScalar: first.isScalar);
  }

  Future<void> _showRecordEditDialog(
    int? index,
    Map<String, dynamic> template, {
    bool isScalar = false,
  }) async {
    final controllers = {
      for (final e in template.entries)
        e.key: TextEditingController(text: '${e.value ?? ''}'),
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final accent = Theme.of(ctx).primaryColor;
        return AlertDialog(
          backgroundColor:
              isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  index == null
                      ? Icons.add_circle_outline_rounded
                      : Icons.edit_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  index == null
                      ? 'Nouvel enregistrement'
                      : 'Modifier l\'enregistrement',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 320, maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: template.keys.map((k) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controllers[k],
                      decoration: InputDecoration(labelText: k),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
    if (saved != true || !mounted) return;

    final edited = <String, dynamic>{};
    for (final e in controllers.entries) {
      edited[e.key] = _parseCellValue(e.value.text, template[e.key]);
    }

    final provider = context.read<FichiersProvider>();
    final String? err;
    if (index == null) {
      err = await provider.appendRecord(
        _openFileName!,
        edited,
        isScalar: isScalar,
      );
    } else {
      err = await provider.updateRecord(
        _openFileName!,
        index,
        edited,
        isScalar: isScalar,
      );
    }
    if (!mounted) return;
    if (err != null) {
      _showSnack(err, error: true);
    } else {
      await _reloadRecords();
    }
  }

  Future<void> _showRawRecordDialog(int? index) async {
    final initialText = index != null
        ? jsonEncode(
            _records[index].isScalar
                ? _records[index].fields['valeur']
                : _records[index].fields,
          )
        : '';
    final ctrl = TextEditingController(text: initialText);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final accent = Theme.of(ctx).primaryColor;
        return AlertDialog(
          backgroundColor:
              isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.data_object_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  index == null ? 'Ajouter (JSON)' : 'Modifier (JSON)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 320, maxWidth: 440),
            child: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: '{"Nom":"Dupont","Prenom":"Jean"} ou "texte"',
              ),
              maxLines: 4,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
    if (saved != true || !mounted) return;
    try {
      final raw = ctrl.text.trim();
      if (raw.isEmpty) {
        _showSnack('Le contenu ne peut pas être vide.', error: true);
        return;
      }
      final decoded = jsonDecode(raw);
      final Map<String, dynamic> fields;
      final bool isScalar;
      if (decoded is Map) {
        fields = decoded.map((k, v) => MapEntry(k.toString(), v));
        isScalar = false;
      } else {
        fields = {'valeur': decoded};
        isScalar = true;
      }

      final provider = context.read<FichiersProvider>();
      if (index == null) {
        await provider.appendRecord(_openFileName!, fields, isScalar: isScalar);
      } else {
        await provider.updateRecord(
          _openFileName!,
          index,
          fields,
          isScalar: isScalar,
        );
      }
      await _reloadRecords();
    } catch (_) {
      _showSnack('Format JSON invalide.', error: true);
    }
  }

  Future<void> _confirmDeleteRecord(int index) async {
    final ok = await _showDeleteConfirmDialog(
      title: 'Supprimer cet enregistrement ?',
      message: 'La ligne ${index + 1} sera retirée du fichier.',
    );
    if (ok != true || !mounted) return;
    final error = await context
        .read<FichiersProvider>()
        .deleteRecord(_openFileName!, index);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, error: true);
    } else {
      await _reloadRecords();
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: error ? AppColors.error : AppColors.success,
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final inMobileFile = !isWide && _openFileName != null;
    final accent = Theme.of(context).primaryColor;
    final fileCount = context.watch<FichiersProvider>().files.length;

    return Scaffold(
      appBar: AppBar(
        leading: inMobileFile
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Retour à la liste',
                onPressed: _closeFile,
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                inMobileFile
                    ? Icons.table_chart_rounded
                    : Icons.folder_copy_rounded,
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                inMobileFile
                    ? (_openFileName ?? '')
                    : 'Gestionnaire de fichiers',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        actions: inMobileFile
            ? [
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded),
                  tooltip: 'Exporter ce fichier',
                  onPressed: () {
                    if (_openFileName != null) _exportFile(_openFileName!);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Rafraîchir',
                  onPressed: _reloadRecords,
                ),
                const SizedBox(width: 4),
              ]
            : [
                if (isWide)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$fileCount fichier${fileCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualiser la liste',
                  onPressed: () async {
                    await context.read<FichiersProvider>().loadFiles();
                    await _reloadRecords();
                  },
                ),
                const SizedBox(width: 6),
              ],
      ),
      body: Stack(
        children: [
          if (isWide)
            _buildDesktopMasterDetail()
          else
            (inMobileFile ? _buildTableEditor(isWide: false) : _buildFileList(isWide: false)),
          if (_fabOpen && !inMobileFile)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _fabOpen = false),
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFab(inMobileFile: inMobileFile, isWide: isWide),
    );
  }

  // ── Layout Desktop Master-Detail ──────────────────────────────────────────

  Widget _buildDesktopMasterDetail() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 360,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: borderColor)),
          ),
          child: _buildFileList(isWide: true),
        ),
        Expanded(
          child: _openFileName == null
              ? _buildSelectFilePlaceholder(isDark)
              : _buildTableEditor(isWide: true),
        ),
      ],
    );
  }

  Widget _buildSelectFilePlaceholder(bool isDark) {
    final accent = Theme.of(context).primaryColor;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.table_view_rounded, size: 36, color: accent),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sélectionnez un fichier',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Choisissez un fichier à gauche pour inspecter et modifier ses enregistrements sous forme de tableau.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Liste des fichiers ────────────────────────────────────────────────────

  Widget _buildFileList({required bool isWide}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).primaryColor;

    return Consumer<FichiersProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return Center(child: CircularProgressIndicator(color: accent));
        }
        if (provider.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 36,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(provider.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: provider.loadFiles,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        final filteredFiles = _fileQuery.isEmpty
            ? provider.files
            : provider.files
                  .where(
                    (f) => f.name.toLowerCase().contains(
                      _fileQuery.toLowerCase(),
                    ),
                  )
                  .toList();

        final totalRecords = provider.files.fold<int>(
          0,
          (sum, f) => sum + f.recordCount,
        );

        Widget content = Column(
          children: [
            // Barre résumé + recherche
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                provider.files.isEmpty ? 8 : 10,
              ),
              child: Column(
                children: [
                  if (!isWide && provider.files.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.analytics_outlined,
                              size: 18,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${provider.files.length} fichier${provider.files.length > 1 ? 's' : ''} · $totalRecords enregistrement${totalRecords > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (provider.files.isNotEmpty)
                    TextField(
                      controller: _fileSearchCtrl,
                      onChanged: (v) => setState(() => _fileQuery = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un fichier...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _fileQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _fileSearchCtrl.clear();
                                  setState(() => _fileQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: provider.files.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.surfaceDark
                                  : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.folder_open_rounded,
                                    size: 36,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Aucun fichier enregistré',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Exécutez un algorithme avec Ouvrir "nom.txt" en 1 en Ecriture, ou créez un fichier ci-dessous.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : filteredFiles.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun fichier ne correspond à « $_fileQuery ».',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 108),
                      itemCount: filteredFiles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final f = filteredFiles[i];
                        return _FileCard(
                          file: f,
                          isSelected: isWide && _openFileName == f.name,
                          onTap: () => _openFile(f.name),
                          onRename: () => _showRenameDialog(f.name),
                          onDelete: () => _confirmDelete(f.name),
                          onExport: () => _exportFile(f.name),
                        );
                      },
                    ),
            ),
          ],
        );

        if (!isWide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: content,
            ),
          );
        }
        return content;
      },
    );
  }

  // ── Éditeur tableau ───────────────────────────────────────────────────────

  Widget _buildTableEditor({required bool isWide}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).primaryColor;

    if (_loadingRecords) {
      return Center(child: CircularProgressIndicator(color: accent));
    }

    final liveEvent = context.watch<FichiersProvider>().liveEvent;
    final int? activeRowIndex =
        (liveEvent != null &&
            liveEvent.fileName == _openFileName &&
            liveEvent.linePosition > 0)
        ? liveEvent.linePosition - 1
        : null;

    final Set<String> keySet = {};
    for (final r in _records) {
      keySet.addAll(r.fields.keys);
    }
    final columns = keySet.toList();

    final indexedRecords = List.generate(_records.length, (i) => (i, _records[i]));
    final filteredRecords = _recordQuery.isEmpty
        ? indexedRecords
        : indexedRecords.where((entry) {
            final q = _recordQuery.toLowerCase();
            return entry.$2.fields.values.any(
              (v) => '$v'.toLowerCase().contains(q),
            );
          }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isWide ? 20 : 12,
        14,
        isWide ? 20 : 12,
        isWide ? 20 : 88,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête éditeur tableau (stats + actions PC + filtre)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_rows_rounded, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isWide && _openFileName != null)
                          Text(
                            _openFileName!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        Text(
                          '${_records.length} enregistrement${_records.length > 1 ? 's' : ''} · ${columns.length} colonne${columns.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isWide && _openFileName != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showAddRecordDialog,
                        icon: const Icon(Icons.add_rounded, size: 17),
                        label: const Text('Ajouter une ligne'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: BorderSide(color: accent.withValues(alpha: 0.45)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.drive_file_rename_outline_rounded,
                          color: accent,
                          size: 20,
                        ),
                        tooltip: 'Renommer',
                        onPressed: () => _showRenameDialog(_openFileName!),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.ios_share_rounded,
                          color: accent,
                          size: 20,
                        ),
                        tooltip: 'Exporter',
                        onPressed: () => _exportFile(_openFileName!),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        tooltip: 'Supprimer le fichier',
                        onPressed: () => _confirmDelete(_openFileName!),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_records.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _recordSearchCtrl,
              onChanged: (v) => setState(() => _recordQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Filtrer les enregistrements...',
                prefixIcon: const Icon(Icons.filter_list_rounded, size: 20),
                suffixIcon: _recordQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _recordSearchCtrl.clear();
                          setState(() => _recordQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: _records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.table_chart_outlined,
                            size: 36,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Ce fichier est vide',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ajoutez un premier enregistrement manuellement.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddRecordDialog,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Ajouter un enregistrement'),
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: filteredRecords.isEmpty
                        ? Center(
                            child: Text(
                              'Aucun enregistrement ne correspond à « $_recordQuery ».',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) =>
                                SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth,
                                      ),
                                      child: DataTable(
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                              accent.withValues(
                                                alpha: isDark ? 0.16 : 0.08,
                                              ),
                                            ),
                                        dividerThickness: 0.6,
                                        columns: [
                                          const DataColumn(
                                            label: Text(
                                              '#',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          ...columns.map(
                                            (c) => DataColumn(
                                              label: Text(
                                                c,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const DataColumn(
                                            label: Text(
                                              'Actions',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                        rows: filteredRecords.map((entry) {
                                          final origIdx = entry.$1;
                                          final rec = entry.$2;
                                          final isActive =
                                              activeRowIndex == origIdx;
                                          return DataRow(
                                            color: WidgetStateProperty.all(
                                              isActive
                                                  ? AppColors.success.withValues(
                                                      alpha: 0.2,
                                                    )
                                                  : (origIdx.isOdd
                                                        ? (isDark
                                                              ? Colors.white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.025,
                                                                    )
                                                              : Colors.black
                                                                    .withValues(
                                                                      alpha:
                                                                          0.02,
                                                                    ))
                                                        : null),
                                            ),
                                            cells: [
                                              DataCell(
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (isActive) ...[
                                                      const Icon(
                                                        Icons
                                                            .play_arrow_rounded,
                                                        size: 16,
                                                        color:
                                                            AppColors.success,
                                                      ),
                                                      const SizedBox(width: 2),
                                                    ],
                                                    Text(
                                                      '${origIdx + 1}',
                                                      style: const TextStyle(
                                                        fontFamily: 'monospace',
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              ...columns.map(
                                                (c) => DataCell(
                                                  Text('${rec.fields[c] ?? ''}'),
                                                  onTap: () =>
                                                      _showRecordEditDialog(
                                                        origIdx,
                                                        rec.fields,
                                                        isScalar: rec.isScalar,
                                                      ),
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.edit_outlined,
                                                        size: 18,
                                                        color: accent,
                                                      ),
                                                      tooltip: 'Modifier',
                                                      onPressed: () =>
                                                          _showRecordEditDialog(
                                                            origIdx,
                                                            rec.fields,
                                                            isScalar:
                                                                rec.isScalar,
                                                          ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 18,
                                                        color: AppColors.error,
                                                      ),
                                                      tooltip: 'Supprimer',
                                                      onPressed: () =>
                                                          _confirmDeleteRecord(
                                                            origIdx,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── FAB speed-dial ergonomique ────────────────────────────────────────────

  Widget _buildFab({required bool inMobileFile, required bool isWide}) {
    final accent = Theme.of(context).primaryColor;

    if (inMobileFile) {
      return FloatingActionButton.extended(
        onPressed: _showAddRecordDialog,
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Ajouter',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        tooltip: 'Ajouter un enregistrement',
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabOpen) ...[
          _SpeedDialItem(
            icon: Icons.create_new_folder_rounded,
            label: 'Créer un fichier',
            color: accent,
            onTap: () {
              setState(() => _fabOpen = false);
              _showCreateDialog();
            },
          ),
          const SizedBox(height: 10),
          _SpeedDialItem(
            icon: Icons.upload_file_rounded,
            label: 'Importer un fichier',
            color: AppColors.success,
            onTap: () {
              setState(() => _fabOpen = false);
              _importFile();
            },
          ),
          if (isWide && _openFileName != null) ...[
            const SizedBox(height: 10),
            _SpeedDialItem(
              icon: Icons.add_box_rounded,
              label: 'Ajouter une ligne dans $_openFileName',
              color: AppColors.info,
              onTap: () {
                setState(() => _fabOpen = false);
                _showAddRecordDialog();
              },
            ),
          ],
          const SizedBox(height: 14),
        ],
        FloatingActionButton.extended(
          onPressed: () => setState(() => _fabOpen = !_fabOpen),
          tooltip: _fabOpen ? 'Fermer' : 'Gérer les fichiers',
          backgroundColor: _fabOpen ? AppColors.error : accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: AnimatedRotation(
            turns: _fabOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add_rounded),
          ),
          label: Text(
            _fabOpen ? 'Fermer' : 'Nouveau',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// ── Widgets auxiliaires ───────────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  final AlgoFileInfo file;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _FileCard({
    required this.file,
    required this.isSelected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onExport,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    return '${(bytes / 1024).toStringAsFixed(1)} Ko';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _extensionBadge(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return 'DATA';
    return name.substring(dot + 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).primaryColor;

    return Material(
      color: isSelected
          ? accent.withValues(alpha: isDark ? 0.14 : 0.08)
          : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: isSelected ? 1.5 : 1,
              color: isSelected
                  ? accent
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_rounded, color: accent, size: 20),
                    Text(
                      _extensionBadge(file.name),
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.list_alt_rounded,
                          size: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${file.recordCount} enreg. · ${_formatSize(file.sizeBytes)} · ${_formatDate(file.lastModified)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                tooltip: 'Options',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'delete') onDelete();
                  if (v == 'export') onExport();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(
                          Icons.drive_file_rename_outline_rounded,
                          size: 18,
                          color: accent,
                        ),
                        const SizedBox(width: 10),
                        const Text('Renommer'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.ios_share_rounded, size: 18, color: accent),
                        const SizedBox(width: 10),
                        const Text('Exporter'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Supprimer',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedDialItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SpeedDialItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.small(
            heroTag: label,
            onPressed: onTap,
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20),
          ),
        ],
      ),
    );
  }
}

class _NomFichierDialog extends StatelessWidget {
  final String title;
  final String confirmLabel;
  final IconData icon;
  final TextEditingController controller;

  const _NomFichierDialog({
    required this.title,
    required this.confirmLabel,
    required this.icon,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).primaryColor;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 300, maxWidth: 420),
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex: clients.txt'),
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
