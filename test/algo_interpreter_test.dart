import 'package:flutter_test/flutter_test.dart';
import 'package:ngenou/algo_interpreter/interpreter.dart';
import 'package:ngenou/algo_interpreter/debugger.dart';
import 'package:ngenou/algo_interpreter/file_storage.dart';

/// Exécute `code` et vérifie la sortie / les erreurs attendues.
/// `inputs` sert aux éventuelles instructions `Lire` (dans l'ordre).
Future<void> _run(
  String code, {
  String? expectedOutput,
  bool expectErrors = false,
  String? errorContains,
  List<String> inputs = const [],
  int maxCallDepth = 100,
  FileStorage? fileStorage,
  List<FileEvent>? eventsOut,
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
    fileStorage: fileStorage,
    onFileEvent: eventsOut == null ? null : (ev) => eventsOut.add(ev),
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
    await _run('''
Algorithme TestDouble
Fonction Double(Entrée x : entier) : entier
  Variable locale r : entier;
Debut
  r ← x * 2;
  Retourner(r);
FinFonction
Debut
  Ecrire(Double(5));
Fin''', expectedOutput: '10');
  });

  test('fonction sans paramètre', () async {
    await _run('''
Algorithme TestUn
Fonction Un() : entier
Debut
  Retourner(42);
FinFonction
Debut
  Ecrire(Un());
Fin''', expectedOutput: '42');
  });

  test('fonction récursive (factorielle)', () async {
    await _run('''
Algorithme TestFact
Fonction Fact(Entrée n : entier) : entier
Debut
  Si n <= 1 Alors
    Retourner(1);
  Sinon
    Retourner(n * Fact(n - 1));
  FinSi
FinFonction
Debut
  Ecrire(Fact(5));
Fin''', expectedOutput: '120');
  });

  test('procédure par référence (Entrée/Sortie modifie la variable)', () async {
    await _run('''
Algorithme TestRef
Var
  y : entier;
Procédure Inc(Entrée/Sortie x : entier)
Debut
  x ← x + 1;
FinProc
Debut
  y ← 10;
  Inc(y);
  Ecrire(y);
Fin''', expectedOutput: '11');
  });

  test('fonction utilisée dans une expression (z <- f(3) + 1)', () async {
    await _run('''
Algorithme TestExpr
Fonction Carre(Entrée x : entier) : entier
Debut
  Retourner(x * x);
FinFonction
Var
  z : entier;
Debut
  z ← Carre(3) + 1;
  Ecrire(z);
Fin''', expectedOutput: '10');
  });

  test('structure : affectation et lecture de champs', () async {
    await _run('''
Algorithme TestStruct
Type Structure point
  x : entier;
  y : entier;
FinStruct
Var
  p : point;
Debut
  p.x ← 3;
  p.y ← 4;
  Ecrire(p.x, ",", p.y);
Fin''', expectedOutput: '3,4');
  });

  test('fonction avec paramètre structure (par valeur)', () async {
    await _run('''
Algorithme TestStructParam
Type Structure point
  x : entier;
  y : entier;
FinStruct
Fonction Norme(Entrée p : point) : entier
Debut
  Retourner(p.x * p.x + p.y * p.y);
FinFonction
Var
  a : point;
Debut
  a.x ← 3;
  a.y ← 4;
  Ecrire(Norme(a));
Fin''', expectedOutput: '25');
  });

  test('fonction déclarée APRÈS le programme principal', () async {
    await _run('''
Algorithme TestApres
Debut
  Ecrire(Triple(4));
Fin
Fonction Triple(Entrée x : entier) : entier
Debut
  Retourner(x * 3);
FinFonction''', expectedOutput: '12');
  });

  test('erreur : fonction inconnue', () async {
    await _run('''
Algorithme TestInconnue
Debut
  Ecrire(Inconnue(3));
Fin''', errorContains: 'non définie');
  });

  test('erreur : mauvais nombre d\'arguments', () async {
    await _run('''
Algorithme TestArgs
Fonction F(Entrée a : entier, Entrée b : entier) : entier
Debut
  Retourner(a + b);
FinFonction
Debut
  Ecrire(F(1));
Fin''', errorContains: 'attend 2 argument');
  });

  test('erreur : procédure utilisée dans une expression', () async {
    await _run('''
Algorithme TestProcExpr
Procédure P()
Debut
  Ecrire("hi");
FinProc
Debut
  Ecrire(P());
Fin''', errorContains: 'expression');
  });

  test('erreur : récursion infinie (limite de profondeur)', () async {
    await _run('''
Algorithme TestDeep
Fonction Boucle(Entrée n : entier) : entier
Debut
  Retourner(Boucle(n));
FinFonction
Debut
  Ecrire(Boucle(1));
Fin''', errorContains: 'récursivité');
  });

  test('erreur : Retourner manquant dans une fonction', () async {
    await _run('''
Algorithme TestNoReturn
Fonction SansRetour(Entrée x : entier) : entier
Debut
  Ecrire(x);
FinFonction
Debut
  Ecrire(SansRetour(5));
Fin''', errorContains: 'Retourner');
  });

  test(
    'procédure avec Variables locales, FinProcédure et Retourner()',
    () async {
      await _run('''
Algorithme TestFinProcedure
Procédure AfficherPositif(x : entier)
Variables
  msg : chaîne;
Début
  Si x <= 0 Alors
    Retourner();
  FinSi
  msg ← "OK";
  Ecrire(msg);
FinProcédure
Debut
  AfficherPositif(-2);
  AfficherPositif(5);
Fin''', expectedOutput: 'OK');
    },
  );

  test('paramètre tableau et paramètre Sortie', () async {
    await _run('''
Algorithme TestTableauParam
Var
  T : Tableau[1..3] de Entier;
  res : Entier;
Procédure SommeTab(Entrée A : Tableau[1..3] de Entier, Sortie total : Entier)
Variables
  i : Entier;
Début
  total ← 0;
  Pour i ← 1 a 3 Faire
    total ← total + A[i];
  FinPour
FinProcédure
Debut
  T[1] ← 2; T[2] ← 4; T[3] ← 6;
  SommeTab(T, res);
  Ecrire(res);
Fin''', expectedOutput: '12');
  });

  test('erreur : type d\'argument scalaire incompatible', () async {
    await _run('''
Algorithme TestTypeArg
Fonction Doubler(x : entier) : entier
Debut
  Retourner(x * 2);
FinFonction
Debut
  Ecrire(Doubler("bonjour"));
Fin''', errorContains: 'Type incompatible');
  });

  // ---------- Étape 0 : Syntaxe en-tête Algorithme ----------

  test('refuse le point-virgule après le nom de l\'algorithme', () async {
    await _run('''
Algorithme MonAlgo;
Debut
   Ecrire("Bonjour")
Fin''', errorContains: 'point-virgule');
  });

  test('accepte Algorithme sans point-virgule après le nom', () async {
    await _run('''
Algorithme MonAlgo
Debut
   Ecrire("Bonjour");
Fin''', expectedOutput: 'Bonjour');
  });

  // ---------- Non-régression : algorithmes existants ----------

  test('non-régression : factorielle impérative', () async {
    await _run('''
Algorithme Factorielle
Var
   n, i, resultat : Entier;
Debut
   resultat ← 1;
   n ← 5;
   Pour i ← 1 a n Faire
      resultat ← resultat * i;
   FinPour
   Ecrire(resultat);
Fin''', expectedOutput: '120');
  });

  test('non-régression : tri à bulles (tableau)', () async {
    await _run('''
Algorithme TriBulles
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
         FinSi
      FinPour
   FinPour
   Ecrire(T[1], ",", T[2], ",", T[3], ",", T[4], ",", T[5]);
Fin''', expectedOutput: '11,12,22,25,64');
  });

  // ---------- Étape 2 : Gestion des fichiers ----------

  test(
    'fichier : création (Ecriture), ajout (Ajout), lecture et parcours EOF',
    () async {
      final storage = InMemoryFileStorage();
      final events = <FileEvent>[];
      await _run(
        '''
Algorithme TestFichierComplet
Type Structure Client
  Nom : chaîne * 25;
  Prenom : chaîne * 25;
FinStruct
Var
  clt : Client;
Début
  Ouvrir "clients.txt" en 1 en Ecriture;
  clt.Nom ← "Dupont";
  clt.Prenom ← "Jean";
  EcrireFichier 1, clt;
  Fermer(1);

  Ouvrir "clients.txt" en 1 en Ajout;
  clt.Nom ← "Martin";
  clt.Prenom ← "Alice";
  EcrireFichier 1, clt;
  Fermer(1);

  Ouvrir "clients.txt" en 2 en Lecture;
  TantQue Non EOF(2) Faire
    LireFichier 2, clt;
    Ecrire(clt.Nom, " ", clt.Prenom);
  FinTantQue
  Fermer(2);
Fin''',
        expectedOutput: 'Dupont Jean\nMartin Alice',
        fileStorage: storage,
        eventsOut: events,
      );
      expect(events.any((e) => e.type == FileEventType.open), isTrue);
      expect(events.any((e) => e.type == FileEventType.write), isTrue);
      expect(events.any((e) => e.type == FileEventType.read), isTrue);
      expect(events.any((e) => e.type == FileEventType.close), isTrue);
    },
  );

  test(
    'fichier : PositionnerFichier (numérotation à partir de 1) et variables simples',
    () async {
      final storage = InMemoryFileStorage();
      await _run(
        '''
Algorithme TestSeekEtScalaires
Var
  n : entier;
  mot : chaîne;
Début
  Ouvrir "nums.txt" en 1 en Ecriture;
  EcrireFichier 1, 10;
  EcrireFichier 1, 20;
  EcrireFichier 1, 30;
  Fermer(1);

  Ouvrir "nums.txt" en 1 en Lecture;
  PositionnerFichier(1, 2);
  LireFichier 1, n;
  Ecrire(n);
  PositionnerFichier(1, 1);
  LireFichier 1, n;
  Ecrire(n);
  Fermer(1);

  Ouvrir "mots.txt" en 3 en Ecriture;
  EcrireFichier 3, "Ngenou";
  Fermer(3);
  Ouvrir "mots.txt" en 3 en Lecture;
  LireFichier 3, mot;
  Ecrire(mot);
  Fermer(3);
Fin''',
        expectedOutput: '20\n10\nNgenou',
        fileStorage: storage,
      );
    },
  );

  test('fichier : lecture depuis une fonction (avec FinFichier)', () async {
    final storage = InMemoryFileStorage();
    await _run(
      '''
Algorithme TestFichierDansFonction
Var
  total : entier;
Fonction CompterLignes(nom : chaîne) : entier
Variables
  c, val : entier;
Début
  c ← 0;
  Ouvrir nom en 1 en Lecture;
  TantQue Non FinFichier(1) Faire
    LireFichier 1, val;
    c ← c + 1;
  FinTantQue
  Fermer(1);
  Retourner(c);
FinFonction
Début
  Ouvrir "notes.txt" en 1 en Ecriture;
  EcrireFichier 1, 12;
  EcrireFichier 1, 15;
  Fermer(1);
  total ← CompterLignes("notes.txt");
  Ecrire(total);
Fin''',
      expectedOutput: '2',
      fileStorage: storage,
    );
  });

  test(
    'fichier : troncature chaîne * N avec avertissement dans le terminal',
    () async {
      final storage = InMemoryFileStorage();
      await _run(
        '''
Algorithme TestTroncature
Type Structure Personne
  Nom : chaîne * 5;
FinStruct
Var
  p : Personne;
Début
  Ouvrir "p.txt" en 1 en Ecriture;
  p.Nom ← "Alexandre";
  EcrireFichier 1, p;
  Fermer(1);
  Ouvrir "p.txt" en 1 en Lecture;
  LireFichier 1, p;
  Ecrire(p.Nom);
  Fermer(1);
Fin''',
        expectedOutput:
            '⚠️ Avertissement ligne 9 : le texte du champ \'Nom\' dépasse 5 caractères et a été tronqué.\nAlexa',
        fileStorage: storage,
      );
    },
  );

  test('fichier : avertissement si un canal reste ouvert à la fin', () async {
    final storage = InMemoryFileStorage();
    await _run(
      '''
Algorithme TestCanalOuvert
Début
  Ouvrir "oubli.txt" en 1 en Ecriture;
  EcrireFichier 1, 99;
Fin''',
      expectedOutput:
          '⚠️ Avertissement : le canal 1 (\'oubli.txt\') n\'a pas été fermé avant la fin de l\'algorithme.',
      fileStorage: storage,
    );
  });

  test(
    'fichier (piège) : lecture d\'un fichier vide -> EOF immédiat, erreur si LireFichier',
    () async {
      final storage = InMemoryFileStorage();
      await _run(
        '''
Algorithme TestFichierVide
Var
  x : entier;
Début
  Ouvrir "vide.txt" en 1 en Ecriture;
  Fermer(1);
  Ouvrir "vide.txt" en 1 en Lecture;
  LireFichier 1, x;
  Fermer(1);
Fin''',
        errorContains: 'EOF',
        fileStorage: storage,
      );
    },
  );

  test('fichier (piège) : fichier introuvable en Lecture', () async {
    await _run(
      '''
Algorithme TestIntrouvable
Var
  x : entier;
Début
  Ouvrir "inexistant.txt" en 1 en Lecture;
Fin''',
      errorContains: 'introuvable',
      fileStorage: InMemoryFileStorage(),
    );
  });

  test(
    'fichier (piège) : mauvais numéro de canal ou canal fermé ou écriture en Lecture',
    () async {
      await _run(
        '''
Algorithme TestMauvaisCanal
Début
  Ouvrir "a.txt" en 0 en Ecriture;
Fin''',
        errorContains: 'canal invalide',
        fileStorage: InMemoryFileStorage(),
      );

      await _run(
        '''
Algorithme TestCanalFerme
Var
  x : entier;
Début
  LireFichier 2, x;
Fin''',
        errorContains: 'canal fermé ou non ouvert',
        fileStorage: InMemoryFileStorage(),
      );

      final storage = InMemoryFileStorage();
      await _run(
        '''
Algorithme TestEcrireEnLecture
Début
  Ouvrir "ro.txt" en 1 en Ecriture;
  Fermer(1);
  Ouvrir "ro.txt" en 1 en Lecture;
  EcrireFichier 1, 5;
  Fermer(1);
Fin''',
        errorContains: 'Lecture uniquement',
        fileStorage: storage,
      );
    },
  );
}
