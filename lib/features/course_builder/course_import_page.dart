import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/course_import_validator.dart';
import '../../core/providers/custom_courses_provider.dart';
import '../../core/providers/progression_provider.dart';

class CourseImportPage extends StatefulWidget {
  final String? expectedMatiereId;

  const CourseImportPage({super.key, this.expectedMatiereId});

  @override
  State<CourseImportPage> createState() => _CourseImportPageState();
}

class _CourseImportPageState extends State<CourseImportPage> {
  final _jsonCtrl = TextEditingController();
  CourseValidationResult? _lastResult;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      String? text;
      if (file.bytes != null) {
        text = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        text = await File(file.path!).readAsString();
      }
      if (text != null) {
        setState(() => _jsonCtrl.text = text!);
        _validate(text);
      }
    }
  }

  void _validate(String raw) {
    setState(() {
      _lastResult = CourseImportValidator.validate(raw);
    });
  }

  Future<void> _import() async {
    final raw = _jsonCtrl.text.trim();
    if (raw.isEmpty) return;

    _validate(raw);
    if (_lastResult == null || !_lastResult!.isValid) return;

    final pkg = _lastResult!.package!;
    if (widget.expectedMatiereId != null &&
        pkg.matiere.id != widget.expectedMatiereId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'L\'ID attendu était ${widget.expectedMatiereId}, reçu ${pkg.matiere.id}. Import annulé.',
          ),
        ),
      );
      return;
    }

    final customProvider = context.read<CustomCoursesProvider>();
    final err = await customProvider.importCourse(pkg);
    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }

    await context.read<ProgressionProvider>().loadProgression(pkg.matiere.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cours « ${pkg.matiere.nom} » importé !')),
      );
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Importer un cours')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Collez le cours fourni par votre IA',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Copiez-collez la réponse complète de l\'IA, l\'application extraira automatiquement le cours.',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _jsonCtrl,
            maxLines: 14,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Collez le contenu du cours ici...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            onChanged: (v) {
              if (v.trim().length > 20) _validate(v);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Fichier de cours'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  final cleaned = _extractJson(_jsonCtrl.text);
                  if (cleaned != null) {
                    setState(() => _jsonCtrl.text = cleaned);
                    _validate(cleaned);
                  }
                },
                child: const Text('Nettoyer le contenu'),
              ),
            ],
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 20),
            if (_lastResult!.isValid)
              const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Structure valide — prêt à importer'),
              )
            else ...[
              Text(
                'Erreurs (${_lastResult!.errors.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              ..._lastResult!.errors.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('⚠ $e', style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _lastResult?.isValid == true ? _import : null,
            icon: const Icon(Icons.check),
            label: const Text('Confirmer l\'import'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ],
      ),
    );
  }

  String? _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return raw.substring(start, end + 1);
    }
    return null;
  }
}
