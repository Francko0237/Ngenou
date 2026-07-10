import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/custom_course_package.dart';
import '../../modules/custom_course_module.dart';
import '../../modules/modules_registry.dart';

class CustomCoursesProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final List<CustomCourseModule> _modules = [];
  bool _loaded = false;

  List<CustomCourseModule> get modules => List.unmodifiable(_modules);
  bool get isLoaded => _loaded;

  Future<void> loadCustomCourses() async {
    final packages = await _db.getAllCustomCourses();
    _modules.clear();
    ModulesRegistry.clearCustomModules();
    for (final pkg in packages) {
      final module = CustomCourseModule(pkg);
      _modules.add(module);
      ModulesRegistry.registerCustomModule(module);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<String?> importCourse(CustomCoursePackage package) async {
    if (_modules.any((m) => m.matiere.id == package.matiere.id)) {
      return 'Un cours avec cet identifiant existe déjà.';
    }
    await _db.insertCustomCourse(package);
    final module = CustomCourseModule(package);
    _modules.add(module);
    ModulesRegistry.registerCustomModule(module);
    notifyListeners();
    return null;
  }

  Future<void> deleteCourse(String matiereId) async {
    await _db.deleteCustomCourse(matiereId);
    _modules.removeWhere((m) => m.matiere.id == matiereId);
    ModulesRegistry.unregisterCustomModule(matiereId);
    notifyListeners();
  }

  Future<void> updateCourseInfo(
    String matiereId,
    String nom,
    String description,
  ) async {
    await _db.updateCustomCourseMeta(matiereId, nom, description);
    await loadCustomCourses();
  }

  bool isCustomMatiere(String matiereId) =>
      matiereId.startsWith('custom_') ||
      _modules.any((m) => m.matiere.id == matiereId);
}
