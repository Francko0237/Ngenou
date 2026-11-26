import 'lexer.dart';
import 'debugger.dart';

abstract class ASTNode {}

// === Expressions ===
abstract class Expr extends ASTNode {
  final int line;
  Expr(this.line);
}

class BinaryExpr extends Expr {
  final Expr left;
  final Token op;
  final Expr right;
  BinaryExpr(this.left, this.op, this.right, int line) : super(line);
}

class UnaryExpr extends Expr {
  final Token op;
  final Expr expr;
  UnaryExpr(this.op, this.expr, int line) : super(line);
}

class LiteralExpr extends Expr {
  final dynamic value;
  LiteralExpr(this.value, int line) : super(line);
}

class VarExpr extends Expr {
  final String name;
  final Expr? indexExpr; // for arrays
  VarExpr(this.name, this.indexExpr, int line) : super(line);
}

class CallExpr extends Expr {
  final String name;
  final List<Expr> args;
  CallExpr(this.name, this.args, int line) : super(line);
}

// === Statements ===
abstract class Stmt extends ASTNode {
  final int line;
  Stmt(this.line);
}

class AssignStmt extends Stmt {
  final String name;
  final Expr? indexExpr;
  final Expr value;
  AssignStmt(this.name, this.indexExpr, this.value, int line) : super(line);
}

class ReadStmt extends Stmt {
  final String name;
  final Expr? indexExpr;
  ReadStmt(this.name, this.indexExpr, int line) : super(line);
}

// Permet lire(a, b, c) — génère plusieurs ReadStmt en un coup
class MultiReadStmt extends Stmt {
  final List<ReadStmt> reads;
  MultiReadStmt(this.reads, int line) : super(line);
}

class WriteStmt extends Stmt {
  final List<Expr> args;
  WriteStmt(this.args, int line) : super(line);
}

class IfStmt extends Stmt {
  final Expr condition;
  final List<Stmt> thenBranch;
  final List<Stmt> elseBranch;
  IfStmt(this.condition, this.thenBranch, this.elseBranch, int line)
    : super(line);
}

class WhileStmt extends Stmt {
  final Expr condition;
  final List<Stmt> body;
  WhileStmt(this.condition, this.body, int line) : super(line);
}

class ForStmt extends Stmt {
  final String varName;
  final Expr start;
  final Expr end;
  final List<Stmt> body;
  ForStmt(this.varName, this.start, this.end, this.body, int line)
    : super(line);
}

class RepeatStmt extends Stmt {
  final List<Stmt> body;
  final Expr condition;
  RepeatStmt(this.body, this.condition, int line) : super(line);
}

class ReturnStmt extends Stmt {
  final Expr? value;
  ReturnStmt(this.value, int line) : super(line);
}

class CallStmt extends Stmt {
  final CallExpr call;
  CallStmt(this.call, int line) : super(line);
}

// === Instructions & Expressions Fichiers ===
class OpenFileStmt extends Stmt {
  final Expr pathExpr;
  final Expr channelExpr;
  final String mode; // 'lecture', 'ecriture', 'ajout'
  OpenFileStmt(this.pathExpr, this.channelExpr, this.mode, int line)
      : super(line);
}

class ReadFileStmt extends Stmt {
  final Expr channelExpr;
  final String varName;
  final Expr? indexExpr;
  ReadFileStmt(this.channelExpr, this.varName, this.indexExpr, int line)
      : super(line);
}

class WriteFileStmt extends Stmt {
  final Expr channelExpr;
  final Expr valueExpr;
  WriteFileStmt(this.channelExpr, this.valueExpr, int line) : super(line);
}

class SeekFileStmt extends Stmt {
  final Expr channelExpr;
  final Expr lineExpr;
  SeekFileStmt(this.channelExpr, this.lineExpr, int line) : super(line);
}

class CloseFileStmt extends Stmt {
  final Expr channelExpr;
  CloseFileStmt(this.channelExpr, int line) : super(line);
}

class EofExpr extends Expr {
  final Expr channelExpr;
  EofExpr(this.channelExpr, int line) : super(line);
}

// === Declarations ===
class VarDecl {
  final String name;
  final String type;
  final bool isArray;
  final int arrayStart;
  final int arrayEnd;
  VarDecl(
    this.name,
    this.type, {
    this.isArray = false,
    this.arrayStart = 1,
    this.arrayEnd = 10,
  });
}

// === Structures ===
class StructField {
  final String name;
  final String type;
  final int? length; // ex. "chaîne * 25"
  StructField(this.name, this.type, this.length);
}

class StructDecl {
  final String name;
  final List<StructField> fields;
  StructDecl(this.name, this.fields);
}

// === Paramètres de fonction/procédure ===
// Entrée = valeur (copie) ; Entrée/Sortie & Sortie = référence (variable modifiable)
enum ParamMode { value, reference }

class ParamDecl {
  final String name;
  final String type;
  final ParamMode mode;
  final bool isArray;
  final int arrayStart;
  final int arrayEnd;
  ParamDecl(
    this.name,
    this.type,
    this.mode, {
    this.isArray = false,
    this.arrayStart = 1,
    this.arrayEnd = 10,
  });
}

// Accès à un champ d'une structure (lecture, dans une expression).
// base peut être une variable, un élément de tableau (T[1]) ou un appel (F().x).
class FieldExpr extends Expr {
  final Expr base;
  final String field;
  FieldExpr(this.base, this.field, int line) : super(line);
}

// Affectation d'un champ : var.champ <- valeur  (ou var[i].champ <- valeur)
class FieldAssignStmt extends Stmt {
  final Expr base;
  final String field;
  final Expr value;
  FieldAssignStmt(this.base, this.field, this.value, int line) : super(line);
}

class FuncDecl {
  final String name;
  final List<ParamDecl> params;
  final String? returnType; // null pour une procédure
  final List<VarDecl> localVars;
  final List<Stmt> body;
  FuncDecl(this.name, this.params, this.returnType, this.localVars, this.body);
}

class ASTProgram extends ASTNode {
  final String name;
  final List<VarDecl> globalVars;
  final List<FuncDecl> functions;
  final List<StructDecl> structTypes;
  final List<Stmt> mainBody;
  ASTProgram(
    this.name,
    this.globalVars,
    this.functions,
    this.structTypes,
    this.mainBody,
  );
}

// === Parser ===
class Parser {
  final List<Token> tokens;
  final Debugger debugger;
  int position = 0;

  Parser(this.tokens, this.debugger);

  Token get current {
    if (position >= tokens.length) return tokens.last;
    return tokens[position];
  }

  Token get previous {
    if (position == 0) return tokens[0];
    return tokens[position - 1];
  }

  void advance() {
    if (position < tokens.length) position++;
  }

  /// Jeton en avance (sans consommer), ou null hors limite.
  Token? peek(int offset) {
    final i = position + offset;
    if (i < 0 || i >= tokens.length) return null;
    return tokens[i];
  }

  bool match(TokenType type, [String? val]) {
    if (current.type == type) {
      if (val == null || current.value.toLowerCase() == val.toLowerCase()) {
        advance();
        return true;
      }
    }
    return false;
  }

  void consume(String expected, String message) {
    if (current.value.toLowerCase() == expected.toLowerCase() ||
        (expected == '<type>' &&
            [
              'entier',
              'réel',
              'chaîne',
              'caractère',
              'booléen',
            ].contains(current.value.toLowerCase()))) {
      advance();
    } else {
      debugger.reportError(message, current.line, current.column);
    }
  }

  ASTProgram? parse() {
    try {
      while (match(TokenType.punctuation, ';')) {}
      if (!match(TokenType.keyword, 'algorithme')) {
        debugger.reportError(
          "Le programme doit commencer par 'Algorithme [Nom]'",
          current.line,
          current.column,
        );
        return null;
      }
      String algoName = "Main";
      if (current.type == TokenType.identifier) {
        algoName = current.value;
        advance();
      }
      if (current.type == TokenType.punctuation && current.value == ';') {
        debugger.reportError(
          "Le point-virgule n'est pas autorisé après le nom de l'algorithme",
          current.line,
          current.column,
        );
        while (match(TokenType.punctuation, ';')) {}
      }

      List<VarDecl> globalVars = [];
      List<FuncDecl> functions = [];
      List<StructDecl> structTypes = [];
      // Avant 'Debut' : ordre libre de Var/Variables (globales), Type Structure,
      // Fonction/Procédure.
      while (current.type != TokenType.eof &&
          current.value.toLowerCase() != 'debut' &&
          current.value.toLowerCase() != 'début') {
        if (match(TokenType.punctuation, ';')) continue;
        final v = current.value.toLowerCase();
        if (match(TokenType.keyword, 'var') ||
            match(TokenType.keyword, 'variables')) {
          globalVars.addAll(parseVarDecls());
        } else if (v == 'type') {
          structTypes.add(parseStructDecl());
        } else if (v == 'fonction' || v == 'procédure' || v == 'procedure') {
          functions.add(parseFuncDecl());
        } else {
          break;
        }
      }

      if (current.value.toLowerCase() == 'début' ||
          current.value.toLowerCase() == 'debut') {
        advance();
      } else {
        consume('debut', "Le bloc principal doit commencer par 'Debut'");
      }
      List<Stmt> mainBody = parseBlock({'fin'});
      consume('fin', "Le bloc principal doit se terminer par 'Fin'");

      // Déclarations de haut niveau autorisées aussi APRÈS le programme
      while (match(TokenType.punctuation, ';')) {}
      _parseTopLevelDeclarations(functions, structTypes);

      return ASTProgram(algoName, globalVars, functions, structTypes, mainBody);
    } catch (e) {
      if (!debugger.hasErrors) {
        debugger.reportError(
          "Erreur de parsing fatale: $e",
          current.line,
          current.column,
        );
      }
      return null;
    }
  }

  /// Parse les déclarations de fonctions/procédures et de structures tant que
  /// le jeton courant correspond à l'un de ces éléments de haut niveau.
  void _parseTopLevelDeclarations(
    List<FuncDecl> functions,
    List<StructDecl> structTypes,
  ) {
    while (true) {
      final v = current.value.toLowerCase();
      if (v == 'fonction' ||
          v == 'procédure' ||
          v == 'procedure') {
        functions.add(parseFuncDecl());
      } else if (v == 'type') {
        structTypes.add(parseStructDecl());
      } else {
        break;
      }
      while (match(TokenType.punctuation, ';')) {}
    }
  }

  List<VarDecl> parseVarDecls() {
    List<VarDecl> vars = [];
    while (current.type == TokenType.identifier &&
        current.value.toLowerCase() != 'type') {
      List<String> names = [];
      names.add(current.value);
      advance();
      while (match(TokenType.punctuation, ',')) {
        if (current.type == TokenType.identifier) {
          names.add(current.value);
          advance();
        }
      }
      consume(':', "Attendu ':' après les noms de variables");

      bool isArray = false;
      int start = 1, end = 10;
      if (match(TokenType.keyword, 'tableau')) {
        isArray = true;
        if (match(TokenType.punctuation, '[')) {
          start = int.parse(current.value);
          advance();
          consume('..', "Attendu '..'");
          end = int.parse(current.value);
          advance();
          consume(']', "Attendu ']'");
        }
        consume('de', "Attendu 'de' après la déclaration de tableau");
      }

      String type = current.value;
      advance(); // consume type
      // ';' optionnel (style ligne-par-ligne)
      match(TokenType.punctuation, ';');
      while (match(TokenType.punctuation, ';')) {}

      for (var name in names) {
        vars.add(
          VarDecl(
            name,
            type,
            isArray: isArray,
            arrayStart: start,
            arrayEnd: end,
          ),
        );
      }
    }
    return vars;
  }

  FuncDecl parseFuncDecl() {
    bool isFunc = current.value.toLowerCase() == 'fonction';
    advance();

    String name = current.value;
    advance();
    List<ParamDecl> params = parseParams();

    String? retType;
    if (isFunc) {
      consume(':', "Attendu ':' pour le type de retour");
      retType = current.value;
      advance();
    }

    List<VarDecl> locals = [];
    // "Var" / "Variables" / "Variable" / "Variable locale"
    if (match(TokenType.keyword, 'var')) {
      locals.addAll(parseVarDecls());
    } else if (match(TokenType.keyword, 'variables')) {
      locals.addAll(parseVarDecls());
    } else if (current.type == TokenType.identifier &&
        current.value.toLowerCase() == 'variable') {
      advance();
      final v = current.value.toLowerCase();
      if (v == 'locale' || v == 'locales' || v == 'locaux' || v == 'local') {
        advance();
      }
      locals.addAll(parseVarDecls());
    }
    while (match(TokenType.punctuation, ';')) {}

    if (current.value.toLowerCase() == 'début' ||
        current.value.toLowerCase() == 'debut') {
      advance();
    } else {
      consume('debut', "Attendu 'Debut' pour la fonction/procédure");
    }
    List<Stmt> body = parseBlock({
      'fin',
      'finproc',
      'finprocédure',
      'finprocedure',
      'finfonction',
    });
    // Terminateur : Fin / FinProc / FinProcédure / FinFonction
    final term = current.value.toLowerCase();
    if (term == 'fin' ||
        term == 'finproc' ||
        term == 'finprocédure' ||
        term == 'finprocedure' ||
        term == 'finfonction') {
      advance();
    } else {
      debugger.reportError(
        "Attendu 'Fin', 'FinProcédure', 'FinProc' ou 'FinFonction'",
        current.line,
        current.column,
      );
    }

    return FuncDecl(name, params, retType, locals, body);
  }

  /// Analyse la liste des paramètres entre parenthèses, avec modes.
  /// Accepte : "Entrée a : entier, Entrée/Sortie b : réel, Sortie c : entier"
  /// ainsi que "a, b : entier" (plusieurs noms partageant le même mode/type).
  List<ParamDecl> parseParams() {
    List<ParamDecl> params = [];
    if (!match(TokenType.punctuation, '(')) {
      debugger.reportError(
        "Attendu '(' après le nom de la fonction/procédure",
        current.line,
        current.column,
      );
      return params;
    }
    if (match(TokenType.punctuation, ')')) return params;

    while (true) {
      ParamMode mode = ParamMode.value;
      // Mode optionnel : Entrée / Sortie / Entrée/Sortie
      if (current.type == TokenType.identifier) {
        final v = current.value.toLowerCase();
        if (v == 'entrée' || v == 'entree') {
          advance();
          if (match(TokenType.operator, '/')) {
            // "Entrée/Sortie"
            if (current.value.toLowerCase() == 'sortie') {
              advance();
              mode = ParamMode.reference;
            } else {
              debugger.reportError(
                "Attendu 'Sortie' après 'Entrée/'",
                current.line,
                current.column,
              );
            }
          }
          // "Entrée" seule => valeur
        } else if (v == 'sortie') {
          advance();
          mode = ParamMode.reference;
        }
      }

      // Un ou plusieurs noms : type
      List<String> names = [];
      if (current.type != TokenType.identifier) {
        debugger.reportError(
          "Attendu un nom de paramètre",
          current.line,
          current.column,
        );
        break;
      }
      names.add(current.value);
      advance();
      // Noms supplémentaires séparés par ',' tant que le jeton suivant n'est pas
      // un mode (auquel cas c'est une nouvelle section avec son propre mode).
      while (current.type == TokenType.punctuation && current.value == ',') {
        final next = peek(1);
        final nextLower = next?.value.toLowerCase() ?? '';
        if (nextLower == 'entrée' ||
            nextLower == 'entree' ||
            nextLower == 'sortie') {
          break; // nouvelle section
        }
        advance(); // consomme ','
        if (current.type == TokenType.identifier) {
          names.add(current.value);
          advance();
        } else {
          break;
        }
      }
      consume(':', "Attendu ':' après le(s) nom(s) de paramètre");

      // Type (avec tableau optionnel)
      bool isArray = false;
      int aStart = 1, aEnd = 10;
      if (match(TokenType.keyword, 'tableau')) {
        isArray = true;
        if (match(TokenType.punctuation, '[')) {
          aStart = int.parse(current.value);
          advance();
          consume('..', "Attendu '..'");
          aEnd = int.parse(current.value);
          advance();
          consume(']', "Attendu ']'");
        }
        consume('de', "Attendu 'de' après la déclaration de tableau");
      }
      String type = current.value;
      advance();

      for (var n in names) {
        params.add(
          ParamDecl(
            n,
            type,
            mode,
            isArray: isArray,
            arrayStart: aStart,
            arrayEnd: aEnd,
          ),
        );
      }

      if (match(TokenType.punctuation, ')')) break;
      if (!match(TokenType.punctuation, ',')) {
        debugger.reportError(
          "Attendu ',' ou ')' dans la liste des paramètres",
          current.line,
          current.column,
        );
        break;
      }
    }
    return params;
  }

  /// Analyse une déclaration de structure :
  /// "Type Structure Nom \n champ : type [* longueur] ; \n ... FinStruct"
  StructDecl parseStructDecl() {
    advance(); // consomme 'type'
    if (current.value.toLowerCase() != 'structure') {
      debugger.reportError(
        "Attendu 'Structure' après 'Type'",
        current.line,
        current.column,
      );
    } else {
      advance();
    }
    String name = current.value;
    advance();

    List<StructField> fields = [];
    while (current.type != TokenType.eof &&
        current.value.toLowerCase() != 'finstruct' &&
        current.value.toLowerCase() != 'fin') {
      if (match(TokenType.punctuation, ';')) continue;
      String fname = current.value;
      advance();
      consume(':', "Attendu ':' après le nom du champ");
      String ftype = current.value;
      advance();
      int? length;
      if (match(TokenType.operator, '*')) {
        length = int.tryParse(current.value) ?? 0;
        advance();
      }
      // ';' optionnel (style ligne-par-ligne)
      match(TokenType.punctuation, ';');
      fields.add(StructField(fname, ftype, length));
    }
    final term = current.value.toLowerCase();
    if (term == 'finstruct' || term == 'fin') {
      advance();
    } else {
      debugger.reportError(
        "Attendu 'FinStruct'",
        current.line,
        current.column,
      );
    }
    return StructDecl(name, fields);
  }

  List<Stmt> parseBlock(Set<String> endKeywords) {
    List<Stmt> stmts = [];
    while (current.type != TokenType.eof &&
        !endKeywords.contains(current.value.toLowerCase()) &&
        current.value.toLowerCase() != 'sinon') {
      if (match(TokenType.punctuation, ';')) continue;
      stmts.add(parseStmt());
      // On accepte un point-virgule optionnel après les blocs (FinPour, FinSi, etc.)
      match(TokenType.punctuation, ';');
    }
    return stmts;
  }

  Stmt parseStmt() {
    if (match(TokenType.keyword, 'si')) {
      Expr cond = parseExpr();
      consume('alors', "Attendu 'Alors' après la condition");
      List<Stmt> thenB = [];
      List<Stmt> elseB = [];

      while (current.type != TokenType.eof &&
          current.value.toLowerCase() != 'sinon' &&
          current.value.toLowerCase() != 'finsi') {
        if (match(TokenType.punctuation, ';')) continue;
        thenB.add(parseStmt());
        match(TokenType.punctuation, ';');
      }

      if (match(TokenType.keyword, 'sinon')) {
        while (current.type != TokenType.eof &&
            current.value.toLowerCase() != 'finsi') {
          if (match(TokenType.punctuation, ';')) continue;
          elseB.add(parseStmt());
          match(TokenType.punctuation, ';');
        }
      }
      consume('finsi', "Attendu 'FinSi'");
      return IfStmt(cond, thenB, elseB, previous.line);
    } else if (match(TokenType.keyword, 'tant que')) {
      Expr cond = parseExpr();
      consume('faire', "Attendu 'Faire'");
      List<Stmt> body = parseBlock({'fintantque'});
      consume('fintantque', "Attendu 'FinTantQue'");
      return WhileStmt(cond, body, previous.line);
    } else if (match(TokenType.keyword, 'pour')) {
      String id = current.value;
      advance();
      match(TokenType.operator, '←') ||
          match(TokenType.operator, '<-') ||
          match(TokenType.keyword, 'de');
      Expr start = parseExpr();
      if (current.value.toLowerCase() == 'à' ||
          current.value.toLowerCase() == 'a') {
        advance();
      } else {
        consume('a', "Attendu 'a' ('à')");
      }
      Expr end = parseExpr();

      // On rend le 'faire' optionnel pour supporter "pour i de 1 a n"
      if (current.value.toLowerCase() == 'faire') {
        advance();
      }

      List<Stmt> body = parseBlock({'finpour'});
      consume('finpour', "Attendu 'FinPour'");
      return ForStmt(id, start, end, body, previous.line);
    } else if (match(TokenType.keyword, 'répéter')) {
      List<Stmt> body = parseBlock({"jusqu'à"});
      consume("jusqu'à", "Attendu 'Jusqu''à'");
      Expr cond = parseExpr();
      // On tolère 'jusqu'a' comme fin de bloc, mais ce n'est pas une instruction simple, donc on ne force pas ';' ici
      return RepeatStmt(body, cond, previous.line);
    } else if (match(TokenType.keyword, 'lire')) {
      consume('(', "Attendu '('");
      List<ReadStmt> reads = [];
      // première variable
      String id = current.value;
      advance();
      Expr? idx;
      if (match(TokenType.punctuation, '[')) {
        idx = parseExpr();
        consume(']', "Attendu ']'");
      }
      reads.add(ReadStmt(id, idx, current.line));
      // variables supplémentaires séparées par ','
      while (match(TokenType.punctuation, ',')) {
        String nextId = current.value;
        advance();
        Expr? nextIdx;
        if (match(TokenType.punctuation, '[')) {
          nextIdx = parseExpr();
          consume(']', "Attendu ']'");
        }
        reads.add(ReadStmt(nextId, nextIdx, current.line));
      }
      consume(')', "Attendu ')'");
      // ';' optionnel (style ligne-par-ligne)
      match(TokenType.punctuation, ';');
      if (reads.length == 1) return reads.first;
      return MultiReadStmt(reads, previous.line);
    } else if (match(TokenType.keyword, 'ecrire')) {
      consume('(', "Attendu '('");
      List<Expr> args = [];
      args.add(parseExpr());
      while (match(TokenType.punctuation, ',')) {
        args.add(parseExpr());
      }
      consume(')', "Attendu ')'");
      // ';' optionnel (style ligne-par-ligne)
      match(TokenType.punctuation, ';');
      return WriteStmt(args, previous.line);
    } else if (match(TokenType.keyword, 'retourner')) {
      Expr? e;
      if (current.type == TokenType.punctuation &&
          current.value == '(' &&
          peek(1)?.type == TokenType.punctuation &&
          peek(1)?.value == ')') {
        advance(); // '('
        advance(); // ')'
      } else if (current.type != TokenType.keyword &&
          current.type != TokenType.eof &&
          !(current.type == TokenType.punctuation && current.value == ';')) {
        e = parseExpr();
      }
      // ';' optionnel (style ligne-par-ligne)
      match(TokenType.punctuation, ';');
      return ReturnStmt(e, previous.line);
    } else if (match(TokenType.keyword, 'ouvrir')) {
      final lineNum = previous.line;
      final pathExpr = parseExpr();
      if (current.value.toLowerCase() == 'en') {
        advance();
      } else {
        debugger.reportError(
          "Attendu 'en' après le nom du fichier dans Ouvrir",
          current.line,
          current.column,
        );
      }
      final channelExpr = parseExpr();
      if (current.value.toLowerCase() == 'en') {
        advance();
      } else {
        debugger.reportError(
          "Attendu 'en' avant le mode d'ouverture (Lecture, Ecriture ou Ajout)",
          current.line,
          current.column,
        );
      }
      final mode = current.value.toLowerCase();
      if (mode == 'lecture' ||
          mode == 'ecriture' ||
          mode == 'écriture' ||
          mode == 'ajout') {
        advance();
      } else {
        debugger.reportError(
          "Mode d'ouverture invalide '${current.value}' (attendu : Lecture, Ecriture ou Ajout)",
          current.line,
          current.column,
        );
      }
      match(TokenType.punctuation, ';');
      return OpenFileStmt(pathExpr, channelExpr, mode, lineNum);
    } else if (match(TokenType.keyword, 'lirefichier')) {
      final lineNum = previous.line;
      final hasParens = match(TokenType.punctuation, '(');
      final channelExpr = parseExpr();
      consume(',', "Attendu ',' après le numéro de canal dans LireFichier");
      if (current.type != TokenType.identifier) {
        debugger.reportError(
          "Attendu un nom de variable après ',' dans LireFichier",
          current.line,
          current.column,
        );
      }
      final varName = current.value;
      advance();
      Expr? idx;
      if (match(TokenType.punctuation, '[')) {
        idx = parseExpr();
        consume(']', "Attendu ']'");
      }
      if (hasParens) {
        consume(')', "Attendu ')'");
      }
      match(TokenType.punctuation, ';');
      return ReadFileStmt(channelExpr, varName, idx, lineNum);
    } else if (match(TokenType.keyword, 'ecrirefichier')) {
      final lineNum = previous.line;
      final hasParens = match(TokenType.punctuation, '(');
      final channelExpr = parseExpr();
      consume(',', "Attendu ',' après le numéro de canal dans EcrireFichier");
      final valueExpr = parseExpr();
      if (hasParens) {
        consume(')', "Attendu ')'");
      }
      match(TokenType.punctuation, ';');
      return WriteFileStmt(channelExpr, valueExpr, lineNum);
    } else if (match(TokenType.keyword, 'positionnerfichier')) {
      final lineNum = previous.line;
      final hasParens = match(TokenType.punctuation, '(');
      final channelExpr = parseExpr();
      consume(',', "Attendu ',' après le numéro de canal dans PositionnerFichier");
      final targetLineExpr = parseExpr();
      if (hasParens) {
        consume(')', "Attendu ')'");
      }
      match(TokenType.punctuation, ';');
      return SeekFileStmt(channelExpr, targetLineExpr, lineNum);
    } else if (match(TokenType.keyword, 'fermer')) {
      final lineNum = previous.line;
      final hasParens = match(TokenType.punctuation, '(');
      final channelExpr = parseExpr();
      if (hasParens) {
        consume(')', "Attendu ')'");
      }
      match(TokenType.punctuation, ';');
      return CloseFileStmt(channelExpr, lineNum);
    } else if (current.type == TokenType.identifier) {
      String id = current.value;
      advance();

      if (match(TokenType.punctuation, '(')) {
        List<Expr> args = [];
        if (!match(TokenType.punctuation, ')')) {
          args.add(parseExpr());
          while (match(TokenType.punctuation, ',')) {
            args.add(parseExpr());
          }
          consume(')', "Attendu ')'");
        }
        // ';' optionnel (style ligne-par-ligne)
        match(TokenType.punctuation, ';');
        return CallStmt(CallExpr(id, args, previous.line), previous.line);
      }

      Expr? idx;
      if (match(TokenType.punctuation, '[')) {
        idx = parseExpr();
        consume(']', "Attendu ']'");
      }
      // Affectation d'un champ : var.champ <- valeur  (ou var[i].champ <- valeur)
      if (match(TokenType.punctuation, '.')) {
        String field = current.value;
        advance();
        if (match(TokenType.operator, '←') ||
            match(TokenType.operator, '<-')) {
          Expr val = parseExpr();
          // ';' optionnel (style ligne-par-ligne)
          match(TokenType.punctuation, ';');
          return FieldAssignStmt(
            VarExpr(id, idx, previous.line),
            field,
            val,
            previous.line,
          );
        }
        debugger.reportError(
          "Attendu '←' après '$id.$field'",
          current.line,
          current.column,
        );
      }
      if (match(TokenType.operator, '←') || match(TokenType.operator, '<-')) {
        Expr val = parseExpr();
        // ';' optionnel (style ligne-par-ligne)
        match(TokenType.punctuation, ';');
        return AssignStmt(id, idx, val, previous.line);
      }
    }

    // Fallback if unknown
    debugger.reportError(
      "Instruction non reconnue: ${current.value}",
      current.line,
      current.column,
    );
    advance();
    return AssignStmt('error', null, LiteralExpr(0, 0), current.line);
  }

  Expr parseExpr() {
    return parseLogicOr();
  }

  Expr parseLogicOr() {
    Expr expr = parseLogicAnd();
    while (match(TokenType.keyword, 'ou')) {
      Token op = previous;
      Expr right = parseLogicAnd();
      expr = BinaryExpr(expr, op, right, op.line);
    }
    return expr;
  }

  Expr parseLogicAnd() {
    Expr expr = parseEquality();
    while (match(TokenType.keyword, 'et')) {
      Token op = previous;
      Expr right = parseEquality();
      expr = BinaryExpr(expr, op, right, op.line);
    }
    return expr;
  }

  Expr parseEquality() {
    Expr expr = parseComparison();
    while (match(TokenType.operator, '=') ||
        match(TokenType.operator, '<>') ||
        match(TokenType.operator, '≠')) {
      Token op = previous;
      Expr right = parseComparison();
      expr = BinaryExpr(expr, op, right, op.line);
    }
    return expr;
  }

  Expr parseComparison() {
    Expr expr = parseTerm();
    while (match(TokenType.operator, '<') ||
        match(TokenType.operator, '<=') ||
        match(TokenType.operator, '≤') ||
        match(TokenType.operator, '>') ||
        match(TokenType.operator, '>=') ||
        match(TokenType.operator, '≥')) {
      Token op = previous;
      Expr right = parseTerm();
      expr = BinaryExpr(expr, op, right, op.line);
    }
    return expr;
  }

  Expr parseTerm() {
    Expr expr = parseFactor();
    while (match(TokenType.operator, '+') || match(TokenType.operator, '-')) {
      Token op = previous;
      Expr right = parseFactor();
      expr = BinaryExpr(expr, op, right, op.line);
    }
    return expr;
  }

  Expr parseFactor() {
    Expr expr = parseUnary();
    while (match(TokenType.operator, '*') ||
        match(TokenType.operator, '/') ||
        match(TokenType.keyword, 'mod') ||
        match(TokenType.keyword, 'div')) {
      Token op = previous;
      Expr right = parseUnary();
      expr = BinaryExpr(expr, op, right, op.line);
    }
    return expr;
  }

  Expr parseUnary() {
    if (match(TokenType.operator, '-') || match(TokenType.keyword, 'non')) {
      Token op = previous;
      Expr right = parseUnary();
      return UnaryExpr(op, right, op.line);
    }
    return parsePrimary();
  }

  Expr parsePrimary() {
    if (match(TokenType.number)) {
      if (previous.value.contains('.')) {
        return LiteralExpr(double.parse(previous.value), previous.line);
      }
      return LiteralExpr(int.parse(previous.value), previous.line);
    }
    if (match(TokenType.string)) {
      return LiteralExpr(previous.value, previous.line);
    }
    if (match(TokenType.keyword, 'vrai')) {
      return LiteralExpr(true, previous.line);
    }
    if (match(TokenType.keyword, 'faux')) {
      return LiteralExpr(false, previous.line);
    }
    if (match(TokenType.keyword, 'eof') ||
        match(TokenType.keyword, 'finfichier')) {
      final lineNum = previous.line;
      consume('(', "Attendu '(' après EOF / FinFichier");
      final channelExpr = parseExpr();
      consume(')', "Attendu ')'");
      return EofExpr(channelExpr, lineNum);
    }
    if (match(TokenType.identifier)) {
      String id = previous.value;
      Expr node;
      if (match(TokenType.punctuation, '(')) {
        List<Expr> args = [];
        if (!match(TokenType.punctuation, ')')) {
          args.add(parseExpr());
          while (match(TokenType.punctuation, ',')) {
            args.add(parseExpr());
          }
          consume(')', "Attendu ')'");
        }
        node = CallExpr(id, args, previous.line);
      } else {
        Expr? idx;
        if (match(TokenType.punctuation, '[')) {
          idx = parseExpr();
          consume(']', "Attendu ']'");
        }
        node = VarExpr(id, idx, previous.line);
      }
      // Accès à un ou plusieurs champs : a.b  /  a[i].b  /  f().b  (chaîné)
      while (match(TokenType.punctuation, '.')) {
        String field = current.value;
        advance();
        node = FieldExpr(node, field, previous.line);
      }
      return node;
    }
    if (match(TokenType.punctuation, '(')) {
      Expr e = parseExpr();
      consume(')', "Attendu ')'");
      return e;
    }

    debugger.reportError("Expression invalide", current.line, current.column);
    advance();
    return LiteralExpr(0, current.line);
  }
}
