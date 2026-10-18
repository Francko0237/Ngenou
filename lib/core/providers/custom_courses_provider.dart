import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/custom_course_package.dart';
import '../../modules/custom_course_module.dart';
import '../../modules/modules_registry.dart';
import '../../app.dart';
import '../services/badge_service.dart';
import '../services/teacher_courses_service.dart';

class CustomCoursesProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final List<CustomCourseModule> _modules = [];
  bool _loaded = false;

  List<CustomCourseModule> get modules => List.unmodifiable(_modules);
  bool get isLoaded => _loaded;

  Future<void> loadCustomCourses() async {
    await TeacherCoursesService.loadPublicMatiereIds();
    final packages = await _db.getAllCustomCourses();
    final newModules = <CustomCourseModule>[];
    for (final pkg in packages) {
      var actualPkg = pkg;
      if (TeacherCoursesService.isPublicMatiere(pkg.matiere.id) && !pkg.meta.isPublic) {
        actualPkg = CustomCoursePackage(
          schemaVersionValue: pkg.schemaVersionValue,
          meta: pkg.meta.copyWith(isPublic: true),
          matiere: pkg.matiere,
          notions: pkg.notions,
          lecons: pkg.lecons,
          exercices: pkg.exercices,
        );
        _db.insertCustomCourse(actualPkg);
      }
      newModules.add(CustomCourseModule(actualPkg));
    }
    _modules
      ..clear()
      ..addAll(newModules);
    ModulesRegistry.clearCustomModules();
    for (final m in newModules) {
      ModulesRegistry.registerCustomModule(m);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<String?> importCourse(CustomCoursePackage package, {bool triggerBadges = true}) async {
    if (_modules.any((m) => m.matiere.id == package.matiere.id)) {
      return 'Un cours avec cet identifiant existe déjà.';
    }
    if (package.meta.isPublic) {
      TeacherCoursesService.markAsPublic(package.matiere.id);
    }
    await _db.insertCustomCourse(package);
    final module = CustomCourseModule(package);
    _modules.add(module);
    ModulesRegistry.registerCustomModule(module);
    notifyListeners();

    if (triggerBadges) {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        Future.microtask(() {
          if (context.mounted) {
            BadgeService.instance.checkAndUnlock(context);
          }
        });
      }
    }

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
