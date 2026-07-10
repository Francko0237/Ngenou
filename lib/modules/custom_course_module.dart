import '../core/models/custom_course_package.dart';
import '../core/models/matiere.dart';
import '../core/models/notion.dart';
import '../core/models/lecon.dart';
import '../core/models/exercice.dart';

class CustomCourseModule {
  final CustomCoursePackage package;

  CustomCourseModule(this.package);

  Matiere get matiere => package.matiere;
  bool get hasTerminal => package.hasTerminal;

  List<Notion> get notions => package.notions;

  List<Lecon> getLeconsByNotion(String notionId) =>
      package.lecons.where((l) => l.notionId == notionId).toList();

  List<Exercice> getExercicesByNotion(String notionId) =>
      package.exercices.where((e) => e.notionId == notionId).toList();

  int get totalExercices => package.exercices.length;
}
