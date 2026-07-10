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

class FuncDecl {
  final String name;
  final List<VarDecl> params;
  final String? returnType; // null for procedure
  final List<VarDecl> localVars;
  final List<Stmt> body;
  FuncDecl(this.name, this.params, this.returnType, this.localVars, this.body);
}

class ASTProgram extends ASTNode {
  final String name;
  final List<VarDecl> globalVars;
  final List<FuncDecl> functions;
  final List<Stmt> mainBody;
  ASTProgram(this.name, this.globalVars, this.functions, this.mainBody);
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
      while (match(TokenType.punctuation, ';')) {}

      List<VarDecl> globalVars = [];
      if (match(TokenType.keyword, 'var')) {
        globalVars.addAll(parseVarDecls());
      } else if (match(TokenType.keyword, 'variables')) {
        globalVars.addAll(parseVarDecls()); // accept both var and variables
      }

      // Functions/Procedures (Simplified unsupported here to save space, assuming flat program or basic functions)
      List<FuncDecl> functions = [];
      while (current.value.toLowerCase() == 'fonction' ||
          current.value.toLowerCase() == 'procédure') {
        functions.add(parseFuncDecl());
      }

      if (current.value.toLowerCase() == 'début' ||
          current.value.toLowerCase() == 'debut') {
        advance();
      } else {
        consume('debut', "Le bloc principal doit commencer par 'Debut'");
      }
      List<Stmt> mainBody = parseBlock('fin');
      consume('fin', "Le bloc principal doit se terminer par 'Fin'");

      return ASTProgram(algoName, globalVars, functions, mainBody);
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

  List<VarDecl> parseVarDecls() {
    List<VarDecl> vars = [];
    while (current.type == TokenType.identifier) {
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
      consume(';', "Attendu ';' à la fin de la déclaration de variable");
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
    List<VarDecl> params = [];
    if (match(TokenType.punctuation, '(')) {
      if (!match(TokenType.punctuation, ')')) {
        params = parseVarDecls(); // Very simplified
        consume(')', "Attendu ')'");
      }
    }

    String? retType;
    if (isFunc) {
      consume(':', "Attendu ':' pour le type de retour");
      retType = current.value;
      advance();
    }

    List<VarDecl> locals = [];
    if (match(TokenType.keyword, 'var')) locals.addAll(parseVarDecls());
    while (match(TokenType.punctuation, ';')) {}

    if (current.value.toLowerCase() == 'début' ||
        current.value.toLowerCase() == 'debut') {
      advance();
    } else {
      consume('debut', "Attendu 'Debut' pour la fonction/procédure");
    }
    List<Stmt> body = parseBlock('fin');
    consume('fin', "Attendu 'Fin' pour la fonction/procédure");

    return FuncDecl(name, params, retType, locals, body);
  }

  List<Stmt> parseBlock(String endKeyword) {
    List<Stmt> stmts = [];
    while (current.type != TokenType.eof &&
        current.value.toLowerCase() != endKeyword.toLowerCase() &&
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
      List<Stmt> body = parseBlock('fintantque');
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

      List<Stmt> body = parseBlock('finpour');
      consume('finpour', "Attendu 'FinPour'");
      return ForStmt(id, start, end, body, previous.line);
    } else if (match(TokenType.keyword, 'répéter')) {
      List<Stmt> body = parseBlock("jusqu'à");
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
      consume(';', "Attendu ';' à la fin de l'instruction 'Lire'");
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
      consume(';', "Attendu ';' à la fin de l'instruction 'Ecrire'");
      return WriteStmt(args, previous.line);
    } else if (match(TokenType.keyword, 'retourner')) {
      Expr? e;
      if (current.type != TokenType.keyword && current.type != TokenType.eof) {
        e = parseExpr();
      }
      consume(';', "Attendu ';' à la fin de l'instruction 'Retourner'");
      return ReturnStmt(e, previous.line);
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
        consume(';', "Attendu ';' à la fin de l'appel de fonction");
        return CallStmt(CallExpr(id, args, previous.line), previous.line);
      }

      Expr? idx;
      if (match(TokenType.punctuation, '[')) {
        idx = parseExpr();
        consume(']', "Attendu ']'");
      }
      if (match(TokenType.operator, '←') || match(TokenType.operator, '<-')) {
        Expr val = parseExpr();
        consume(';', "Attendu ';' à la fin de l'affectation");
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
    if (match(TokenType.identifier)) {
      String id = previous.value;
      if (match(TokenType.punctuation, '(')) {
        List<Expr> args = [];
        if (!match(TokenType.punctuation, ')')) {
          args.add(parseExpr());
          while (match(TokenType.punctuation, ',')) {
            args.add(parseExpr());
          }
          consume(')', "Attendu ')'");
        }
        return CallExpr(id, args, previous.line);
      }
      Expr? idx;
      if (match(TokenType.punctuation, '[')) {
        idx = parseExpr();
        consume(']', "Attendu ']'");
      }
      return VarExpr(id, idx, previous.line);
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
