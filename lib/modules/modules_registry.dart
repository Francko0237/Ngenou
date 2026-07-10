import '../core/models/matiere.dart';
import '../core/models/notion.dart';
import '../core/models/lecon.dart';
import '../core/models/exercice.dart';
import 'algorithmique/algo_module.dart';
import 'micro_ordi/micro_ordi_module_data.dart';
import 'custom_course_module.dart';

class ModulesRegistry {
  static final List<Matiere> _builtinMatieres = [
    AlgoModule.matiere,
    MicroOrdiModuleData.matiere,
  ];

  static final Map<String, CustomCourseModule> _customModules = {};

  static List<Matiere> get matieres => [
    ..._builtinMatieres,
    ..._customModules.values.map((m) => m.matiere),
  ];

  static void registerCustomModule(CustomCourseModule module) {
    _customModules[module.matiere.id] = module;
  }

  static void unregisterCustomModule(String matiereId) {
    _customModules.remove(matiereId);
  }

  static void clearCustomModules() {
    _customModules.clear();
  }

  static bool isCustomMatiere(String matiereId) =>
      _customModules.containsKey(matiereId);

  static bool hasTerminal(String matiereId) {
    if (matiereId == 'algo') return true;
    return _customModules[matiereId]?.hasTerminal ?? false;
  }

  static Matiere? getMatiere(String matiereId) {
    if (_customModules.containsKey(matiereId)) {
      return _customModules[matiereId]!.matiere;
    }
    try {
      return _builtinMatieres.firstWhere((m) => m.id == matiereId);
    } catch (_) {
      return null;
    }
  }

  static List<Notion> getNotions(String matiereId) {
    if (_customModules.containsKey(matiereId)) {
      return _customModules[matiereId]!.notions;
    }
    if (matiereId == 'algo') return AlgoModule.notions;
    if (matiereId == 'micro_ordi') return MicroOrdiModuleData.notions;
    return [];
  }

  static List<Lecon> getLeconsByNotion(String matiereId, String notionId) {
    if (_customModules.containsKey(matiereId)) {
      return _customModules[matiereId]!.getLeconsByNotion(notionId);
    }
    if (matiereId == 'algo') return AlgoModule.getLeconsByNotion(notionId);
    if (matiereId == 'micro_ordi') {
      return MicroOrdiModuleData.getLeconsByNotion(notionId);
    }
    return [];
  }

  static List<Exercice> getExercicesByNotion(
    String matiereId,
    String notionId,
  ) {
    if (_customModules.containsKey(matiereId)) {
      return _customModules[matiereId]!.getExercicesByNotion(notionId);
    }
    if (matiereId == 'algo') return AlgoModule.getExercicesByNotion(notionId);
    if (matiereId == 'micro_ordi') {
      return MicroOrdiModuleData.getExercicesByNotion(notionId);
    }
    return [];
  }

  static int getTotalExercices(String matiereId) {
    if (_customModules.containsKey(matiereId)) {
      return _customModules[matiereId]!.totalExercices;
    }
    if (matiereId == 'algo') {
      return AlgoModule.notions.fold(
        0,
        (sum, n) => sum + AlgoModule.getExercicesByNotion(n.id).length,
      );
    }
    if (matiereId == 'micro_ordi') {
      return MicroOrdiModuleData.notions.fold(
        0,
        (sum, n) => sum + MicroOrdiModuleData.getExercicesByNotion(n.id).length,
      );
    }
    return 1;
  }
}
