import 'package:flutter_test/flutter_test.dart';
import 'package:ngenou/algo_interpreter/interpreter.dart';
import 'package:ngenou/algo_interpreter/debugger.dart';

/// Exécute `code` et vérifie la sortie / les erreurs attendues.
/// `inputs` sert aux éventuelles instructions `Lire` (dans l'ordre).
Future<void> _run(
  String code, {
  String? expectedOutput,
  bool expectErrors = false,
  String? errorContains,
  List<String> inputs = const [],
  int maxCallDepth = 100,
}) async {
  final buf = StringBuffer();
  final errors = <AlgoError>[];
  int i = 0;
  await Interpreter.runCode(
    code,
    (out) => buf.writeln(out),
    (_) async => i < inputs.length ? inputs[i++] : '0',
    (e) => errors.addAll(e),
    maxCallDepth: maxCallDepth,
  );
  final out = buf.toString().trim();

  if (expectErrors || errorContains != null) {
    expect(
      errors,
      isNotEmpty,
      reason: 'Des erreurs étaient attendues pour:\n$code',
    );
    if (errorContains != null) {
      final found = errors.any(
        (e) => e.message.toLowerCase().contains(errorContains.toLowerCase()),
      );
      expect(
        found,
        isTrue,
        reason:
            'Erreur attendue contenant "$errorContains", mais reçu: '
            '${errors.map((e) => e.message)}',
      );
    }
  } else {
    expect(
      errors,
      isEmpty,
      reason: 'Erreurs inattendues: ${errors.map((e) => e.message)}',
    );
    if (expectedOutput != null) {
      expect(
        out,
        equals(expectedOutput.trim()),
        reason: 'Sortie attendue "${expectedOutput.trim()}" mais reçu "$out"',
      );
    }
  }
}

void main() {
  // ---------- PARTIE 1 : Fonctions & Procédures ----------

  test('fonction simple (par valeur)', () async {
    await _run(
      '''
Algorithme TestDouble
Fonction Double(Entrée x : entier) : entier
  Variable locale r : entier
Debut
  r ← x * 2
  Retourner(r)
FinFonction
Debut
  Ecrire(Double(5))
Fin''',
      expectedOutput: '10',
    );
  });

  test('fonction sans paramètre', () async {
    await _run(
      '''
Algorithme TestUn
Fonction Un() : entier
Debut
  Retourner(42)
FinFonction
Debut
  Ecrire(Un())
Fin''',
      expectedOutput: '42',
    );
  });

  test('fonction récursive (factorielle)', () async {
    await _run(
      '''
Algorithme TestFact
Fonction Fact(Entrée n : entier) : entier
Debut
  Si n <= 1 Alors
    Retourner(1)
  Sinon
    Retourner(n * Fact(n - 1))
  FinSi
FinFonction
Debut
  Ecrire(Fact(5))
Fin''',
      expectedOutput: '120',
    );
  });

  test('procédure par référence (Entrée/Sortie modifie la variable)', () async {
    await _run(
      '''
Algorithme TestRef
Var
  y : entier
Procédure Inc(Entrée/Sortie x : entier)
Debut
  x ← x + 1
FinProc
Debut
  y ← 10
  Inc(y)
  Ecrire(y)
Fin''',
      expectedOutput: '11',
    );
  });

  test('fonction utilisée dans une expression (z <- f(3) + 1)', () async {
    await _run(
      '''
Algorithme TestExpr
Fonction Carre(Entrée x : entier) : entier
Debut
  Retourner(x * x)
FinFonction
Var
  z : entier
Debut
  z ← Carre(3) + 1
  Ecrire(z)
Fin''',
      expectedOutput: '10',
    );
  });

  test('structure : affectation et lecture de champs', () async {
    await _run(
      '''
Algorithme TestStruct
Type Structure point
  x : entier
  y : entier
FinStruct
Var
  p : point
Debut
  p.x ← 3
  p.y ← 4
  Ecrire(p.x, ",", p.y)
Fin''',
      expectedOutput: '3,4',
    );
  });

  test('fonction avec paramètre structure (par valeur)', () async {
    await _run(
      '''
Algorithme TestStructParam
Type Structure point
  x : entier
  y : entier
FinStruct
Fonction Norme(Entrée p : point) : entier
Debut
  Retourner(p.x * p.x + p.y * p.y)
FinFonction
Var
  a : point
Debut
  a.x ← 3
  a.y ← 4
  Ecrire(Norme(a))
Fin''',
      expectedOutput: '25',
    );
  });

  test('fonction déclarée APRÈS le programme principal', () async {
    await _run(
      '''
Algorithme TestApres
Debut
  Ecrire(Triple(4))
Fin
Fonction Triple(Entrée x : entier) : entier
Debut
  Retourner(x * 3)
FinFonction''',
      expectedOutput: '12',
    );
  });

  test('erreur : fonction inconnue', () async {
    await _run(
      '''
Algorithme TestInconnue
Debut
  Ecrire(Inconnue(3))
Fin''',
      errorContains: 'non définie',
    );
  });

  test('erreur : mauvais nombre d\'arguments', () async {
    await _run(
      '''
Algorithme TestArgs
Fonction F(Entrée a : entier, Entrée b : entier) : entier
Debut
  Retourner(a + b)
FinFonction
Debut
  Ecrire(F(1))
Fin''',
      errorContains: 'attend 2 argument',
    );
  });

  test('erreur : procédure utilisée dans une expression', () async {
    await _run(
      '''
Algorithme TestProcExpr
Procédure P()
Debut
  Ecrire("hi")
FinProc
Debut
  Ecrire(P())
Fin''',
      errorContains: 'expression',
    );
  });

  test('erreur : récursion infinie (limite de profondeur)', () async {
    await _run(
      '''
Algorithme TestDeep
Fonction Boucle(Entrée n : entier) : entier
Debut
  Retourner(Boucle(n))
FinFonction
Debut
  Ecrire(Boucle(1))
Fin''',
      errorContains: 'récursivité',
    );
  });

  test('erreur : Retourner manquant dans une fonction', () async {
    await _run(
      '''
Algorithme TestNoReturn
Fonction SansRetour(Entrée x : entier) : entier
Debut
  Ecrire(x)
FinFonction
Debut
  Ecrire(SansRetour(5))
Fin''',
      errorContains: 'Retourner',
    );
  });

  // ---------- Non-régression : algorithmes existants ----------

  test('non-régression : factorielle impérative', () async {
    await _run(
      '''
Algorithme Factorielle;
Var
   n, i, resultat : Entier;
Debut
   resultat ← 1;
   n ← 5;
   Pour i ← 1 a n Faire
      resultat ← resultat * i;
   FinPour;
   Ecrire(resultat);
Fin''',
      expectedOutput: '120',
    );
  });

  test('non-régression : tri à bulles (tableau)', () async {
    await _run(
      '''
Algorithme TriBulles;
Var
   T : Tableau[1..5] de Entier;
   i, j, temp : Entier;
Debut
   T[1] ← 64;
   T[2] ← 25;
   T[3] ← 12;
   T[4] ← 22;
   T[5] ← 11;
   Pour i ← 1 a 4 Faire
      Pour j ← 1 a 5-i Faire
         Si (T[j] > T[j+1]) Alors
            temp ← T[j];
            T[j] ← T[j+1];
            T[j+1] ← temp;
         FinSi;
      FinPour;
   FinPour;
   Ecrire(T[1], ",", T[2], ",", T[3], ",", T[4], ",", T[5]);
Fin''',
      expectedOutput: '11,12,22,25,64',
    );
  });
}
