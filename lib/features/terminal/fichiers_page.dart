import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/fichiers_provider.dart';
import '../../core/theme/app_colors.dart';

/// Page « Gestionnaire de Fichiers Algorithmiques » (/fichiers)
/// Accessible via le bouton dédié dans la barre du terminal.
class FichiersPage extends StatefulWidget {
  const FichiersPage({super.key});

  @override
  State<FichiersPage> createState() => _FichiersPageState();
}

class _FichiersPageState extends State<FichiersPage> {
  // Index du fichier actuellement ouvert dans l'éditeur tableau (-1 = liste)
  int _openFileIndex = -1;
  String? _openFileName;
  List<AlgoFileRecord> _records = [];
  bool _loadingRecords = false;

  // Pour le FAB speed-dial
  bool _fabOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FichiersProvider>().loadFiles();
    });
  }

  // ── Navigation interne ────────────────────────────────────────────────────

  Future<void> _openFile(int index, String name) async {
    setState(() {
      _openFileIndex = index;
      _openFileName = name;
      _loadingRecords = true;
      _fabOpen = false;
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
      _openFileIndex = -1;
      _openFileName = null;
      _records = [];
      _fabOpen = false;
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
    final error =
        await context.read<FichiersProvider>().createFile(ctrl.text.trim());
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, error: true);
    } else {
      _showSnack('Fichier « ${ctrl.text.trim()} » créé.');
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
    final error = await context
        .read<FichiersProvider>()
        .renameFile(oldName, ctrl.text.trim());
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, error: true);
    } else {
      _showSnack('Renommé en « ${ctrl.text.trim()} ».');
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
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      final err = await context
          .read<FichiersProvider>()
          .importFile(result.files.single.path!);
      if (!mounted) return;
      if (err != null) {
        _showSnack(err, error: true);
      } else {
        _showSnack('Fichier « ${result.files.single.name} » importé.');
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: template.keys.map((k) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[k],
                    decoration: InputDecoration(
                      labelText: k,
                    ),
                  ),
                );
              }).toList(),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: '{"Nom":"Dupont","Prenom":"Jean"} ou "texte"',
            ),
            maxLines: 4,
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
    final inFile = _openFileIndex >= 0;
    final accent = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        leading: inFile
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Retour à la liste',
                onPressed: _closeFile,
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              inFile ? Icons.table_chart_rounded : Icons.folder_rounded,
              size: 20,
              color: accent,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                inFile ? (_openFileName ?? '') : 'Mes Fichiers',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        actions: inFile
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
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualiser la liste',
                  onPressed: () =>
                      context.read<FichiersProvider>().loadFiles(),
                ),
              ],
      ),
      body: Stack(
        children: [
          inFile ? _buildTableEditor() : _buildFileList(),
          if (_fabOpen && !inFile)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _fabOpen = false),
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFab(inFile),
    );
  }

  // ── Liste des fichiers ────────────────────────────────────────────────────

  Widget _buildFileList() {
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
        if (provider.files.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
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
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.folder_open_rounded,
                          size: 38,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucun fichier enregistré',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Utilisez Ouvrir "nom.txt" en 1 en Ecriture dans le terminal, ou créez un fichier avec le bouton ci-dessous.',
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
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
          itemCount: provider.files.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final f = provider.files[i];
            return _FileCard(
              file: f,
              onTap: () => _openFile(i, f.name),
              onRename: () => _showRenameDialog(f.name),
              onDelete: () => _confirmDelete(f.name),
              onExport: () => _exportFile(f.name),
            );
          },
        );
      },
    );
  }

  // ── Éditeur tableau ───────────────────────────────────────────────────────

  Widget _buildTableEditor() {
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

    if (_records.isEmpty) {
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            child: Row(
              children: [
                Icon(Icons.table_rows_rounded, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_records.length} enregistrement${_records.length > 1 ? 's' : ''} · ${columns.length} colonne${columns.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Touchez une cellule pour éditer',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      accent.withValues(alpha: isDark ? 0.16 : 0.08),
                    ),
                    columns: [
                      const DataColumn(
                        label: Text(
                          '#',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...columns.map(
                        (c) => DataColumn(
                          label: Text(
                            c,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          'Actions',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: List.generate(_records.length, (i) {
                      final rec = _records[i];
                      final isActive = activeRowIndex == i;
                      return DataRow(
                        color: WidgetStateProperty.all(
                          isActive
                              ? AppColors.success.withValues(alpha: 0.2)
                              : (i.isOdd
                                  ? (isDark
                                      ? Colors.white.withValues(alpha: 0.025)
                                      : Colors.black.withValues(alpha: 0.02))
                                  : null),
                        ),
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isActive) ...[
                                  const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 16,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 2),
                                ],
                                Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...columns.map(
                            (c) => DataCell(
                              Text('${rec.fields[c] ?? ''}'),
                              onTap: () => _showRecordEditDialog(
                                i,
                                rec.fields,
                                isScalar: rec.isScalar,
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: accent,
                                  ),
                                  tooltip: 'Modifier',
                                  onPressed: () => _showRecordEditDialog(
                                    i,
                                    rec.fields,
                                    isScalar: rec.isScalar,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  tooltip: 'Supprimer',
                                  onPressed: () => _confirmDeleteRecord(i),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── FAB speed-dial ────────────────────────────────────────────────────────

  Widget _buildFab(bool inFile) {
    final accent = Theme.of(context).primaryColor;

    if (inFile) {
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
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _FileCard({
    required this.file,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).primaryColor;

    return Material(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
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
                  border: Border.all(
                    color: accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
                        Icon(
                          Icons.ios_share_rounded,
                          size: 18,
                          color: accent,
                        ),
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
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Ex: clients.txt',
        ),
        onSubmitted: (_) => Navigator.pop(context, true),
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
