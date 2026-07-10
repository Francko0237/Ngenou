import 'package:flutter/material.dart';
import '../../core/models/matiere.dart';
import '../../core/models/notion.dart';
import '../../core/models/lecon.dart';
import '../../core/models/exercice.dart';
import 'cours/algo_cours_data.dart';
import 'exercices/algo_exercices_data.dart';

class AlgoModule {
  static final Matiere matiere = Matiere(
    id: 'algo',
    nom: 'Algorithmique',
    description: 'Apprenez les bases de la logique de programmation, des variables aux boucles et conditions.',
    icone: Icons.code_rounded,
    couleur: Colors.blue,
    isAvailable: true,
  );

  static List<Notion> get notions => AlgoCoursData.notions;
  
  static List<Lecon> getLeconsByNotion(String notionId) {
    return AlgoCoursData.lecons.where((l) => l.notionId == notionId).toList();
  }
  
  static List<Exercice> getExercicesByNotion(String notionId) {
    return AlgoExercicesData.exercices.where((e) => e.notionId == notionId).toList();
  }
}
