import 'package:flutter_test/flutter_test.dart';
import 'package:ngenou/algo_interpreter/lexer.dart';
import 'package:ngenou/algo_interpreter/parser.dart';
import 'package:ngenou/algo_interpreter/interpreter.dart';
import 'package:ngenou/algo_interpreter/debugger.dart';

void main() {
  group('Lexer Tests', () {
    test('Tokenize basic keywords and identifiers', () {
      const code = 'Algorithme Test\nVariables\n x : entier\nDébut\n x <- 10\nFin';
      final lexer = Lexer(code);
      final tokens = lexer.tokenize();

      expect(tokens.isNotEmpty, isTrue);
      expect(tokens.any((t) => t.type == TokenType.keyword && t.value.toLowerCase() == 'algorithme'), isTrue);
      expect(tokens.any((t) => t.type == TokenType.keyword && t.value.toLowerCase() == 'entier'), isTrue);
      expect(tokens.any((t) => t.type == TokenType.operator && t.value == '<-'), isTrue);
    });

    test('Tokenize numbers and arithmetic operators', () {
      const code = 'a <- 42 + 3.14 * 2';
      final lexer = Lexer(code);
      final tokens = lexer.tokenize();

      final numbers = tokens.where((t) => t.type == TokenType.number).map((t) => t.value).toList();
      expect(numbers, containsAll(['42', '3.14', '2']));
    });

    test('Tokenize string literals', () {
      const code = 'Ecrire("Bonjour tout le monde!")';
      final lexer = Lexer(code);
      final tokens = lexer.tokenize();

      final strings = tokens.where((t) => t.type == TokenType.string).map((t) => t.value).toList();
      expect(strings, contains('Bonjour tout le monde!'));
    });
  });

  group('Parser & Interpreter Execution Tests', () {
    Future<List<String>> runAlgo(String code, {Map<String, String>? inputs}) async {
      final outputs = <String>[];
      final lexer = Lexer(code);
      final tokens = lexer.tokenize();
      final debugger = Debugger();
      final parser = Parser(tokens, debugger);
      final program = parser.parse();
      expect(program, isNotNull);
      if (program != null) {
        final interpreter = Interpreter(
          debugger: debugger,
          onOutput: (text) => outputs.add(text),
          onInput: (prompt) async => inputs?[prompt] ?? '0',
        );

        await interpreter.execute(program);
      }
      return outputs;
    }

    test('Simple assignment and Ecrire statement', () async {
      const code = '''
Algorithme TestSimple
Variables
  x : entier;
Début
  x <- 25 + 17;
  Ecrire(x);
Fin
''';
      final outputs = await runAlgo(code);
      expect(outputs, contains('42'));
    });

    test('Conditional IF/ELSE execution', () async {
      const code = '''
Algorithme TestCondition
Variables
  note : entier;
Début
  note <- 14;
  Si note >= 10 Alors
    Ecrire("Admis");
  Sinon
    Ecrire("Ajourné");
  FinSi
Fin
''';
      final outputs = await runAlgo(code);
      expect(outputs, contains('Admis'));
      expect(outputs, isNot(contains('Ajourné')));
    });

    test('Loop POUR (for loop)', () async {
      const code = '''
Algorithme TestPour
Variables
  i : entier;
  somme : entier;
Début
  somme <- 0;
  Pour i de 1 à 4 Faire
    somme <- somme + i;
  FinPour
  Ecrire(somme);
Fin
''';
      final outputs = await runAlgo(code);
      // 1 + 2 + 3 + 4 = 10
      expect(outputs, contains('10'));
    });

    test('Loop TANT QUE (while loop)', () async {
      const code = '''
Algorithme TestTantQue
Variables
  cpt : entier;
Début
  cpt <- 3;
  Tant que cpt > 0 Faire
    cpt <- cpt - 1;
  FinTantQue
  Ecrire(cpt);
Fin
''';
      final outputs = await runAlgo(code);
      expect(outputs, contains('0'));
    });
  });
}
