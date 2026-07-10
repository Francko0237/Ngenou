import 'dart:convert';
import 'defi.dart';

class DailyChallengeAlgoTest {
  final List<String> inputs;
  final String expectedOutput;

  DailyChallengeAlgoTest({required this.inputs, required this.expectedOutput});

  Map<String, dynamic> toJson() => {
    'inputs': inputs,
    'expectedOutput': expectedOutput,
  };

  factory DailyChallengeAlgoTest.fromJson(Map<String, dynamic> json) {
    return DailyChallengeAlgoTest(
      inputs: List<String>.from(json['inputs'] ?? []),
      expectedOutput: json['expectedOutput'] as String? ?? '',
    );
  }
}

class DailyChallenge {
  final String id;
  final String type; // 'qcm' ou 'algo'
  final String matiereId;
  final String matiereNom;
  final String
  question; // Pour QCM: l'énoncé. Pour Algo: le titre de l'exercice.
  final List<String> options; // Pour QCM (options de réponse).
  final int bonneReponseIndex; // Pour QCM (index correct 0-3).
  final String
  explication; // Pour QCM: l'explication. Pour Algo: les consignes/contexte.
  int?
  userAnswerIndex; // Pour QCM: choix de l'utilisateur (null si non répondu).

  // Spécifique aux défis algorithmiques
  bool isSolved;
  bool isFailed;
  final String? codeInitial;
  final String? codeSolution; // Solution correcte — affichée après échec
  final List<DailyChallengeAlgoTest>? algoTests;

  DailyChallenge({
    required this.id,
    required this.type,
    required this.matiereId,
    required this.matiereNom,
    required this.question,
    required this.options,
    required this.bonneReponseIndex,
    required this.explication,
    this.userAnswerIndex,
    this.isSolved = false,
    this.isFailed = false,
    this.codeInitial,
    this.codeSolution,
    this.algoTests,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'matiereId': matiereId,
    'matiereNom': matiereNom,
    'question': question,
    'options': options,
    'bonneReponseIndex': bonneReponseIndex,
    'explication': explication,
    'userAnswerIndex': userAnswerIndex,
    'isSolved': isSolved,
    'isFailed': isFailed,
    'codeInitial': codeInitial,
    'codeSolution': codeSolution,
    'algoTests': algoTests?.map((t) => t.toJson()).toList(),
  };

  factory DailyChallenge.fromJson(Map<String, dynamic> json) {
    final testsRaw = json['algoTests'] as List?;
    return DailyChallenge(
      id: json['id'] as String,
      type: json['type'] as String,
      matiereId: json['matiereId'] as String,
      matiereNom: json['matiereNom'] as String,
      question: json['question'] as String,
      options: List<String>.from(json['options'] ?? []),
      bonneReponseIndex: json['bonneReponseIndex'] as int? ?? 0,
      explication: json['explication'] as String? ?? '',
      userAnswerIndex: json['userAnswerIndex'] as int?,
      isSolved: json['isSolved'] as bool? ?? false,
      isFailed: json['isFailed'] as bool? ?? false,
      codeInitial: json['codeInitial'] as String?,
      codeSolution: json['codeSolution'] as String?,
      algoTests: testsRaw
          ?.map((t) => DailyChallengeAlgoTest.fromJson(t))
          .toList(),
    );
  }

  /// Convertit ce défi algorithmique généré par l'IA au format static Defi
  /// requis par l'éditeur de code et l'interpréteur de terminal.
  Defi toDefi() {
    return Defi(
      id: id,
      matiereId: matiereId,
      titre: question,
      description: explication,
      codeInitial: codeInitial ?? '',
      tests: (algoTests ?? [])
          .map(
            (t) => DefiTest(inputs: t.inputs, expectedOutput: t.expectedOutput),
          )
          .toList(),
    );
  }
}

class DailyChallengeSession {
  final int? id;
  final String date; // format YYYY-MM-DD
  final int score;
  final int total;
  final bool inclutAlgo;
  final List<DailyChallenge> challenges;
  final bool completed;

  DailyChallengeSession({
    this.id,
    required this.date,
    required this.score,
    required this.total,
    required this.inclutAlgo,
    required this.challenges,
    required this.completed,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'score': score,
      'total': total,
      'inclut_algo': inclutAlgo ? 1 : 0,
      'challenges_json': jsonEncode(challenges.map((c) => c.toJson()).toList()),
      'completed': completed ? 1 : 0,
    };
  }

  factory DailyChallengeSession.fromMap(Map<String, dynamic> map) {
    final challengesJsonStr = map['challenges_json'] as String;
    final List<dynamic> list = jsonDecode(challengesJsonStr);
    final challenges = list.map((c) => DailyChallenge.fromJson(c)).toList();
    return DailyChallengeSession(
      id: map['id'] as int?,
      date: map['date'] as String,
      score: map['score'] as int,
      total: map['total'] as int,
      inclutAlgo: (map['inclut_algo'] as int) == 1,
      challenges: challenges,
      completed: (map['completed'] as int) == 1,
    );
  }

  DailyChallengeSession copyWith({
    int? score,
    List<DailyChallenge>? challenges,
    bool? completed,
  }) {
    return DailyChallengeSession(
      id: id,
      date: date,
      score: score ?? this.score,
      total: total,
      inclutAlgo: inclutAlgo,
      challenges: challenges ?? this.challenges,
      completed: completed ?? this.completed,
    );
  }
}
