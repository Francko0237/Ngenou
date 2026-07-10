import 'dart:async';
import 'parser.dart';
import 'debugger.dart';
import 'lexer.dart';

class AlgoEnvironment {
  final Map<String, dynamic> variables = {};
  final AlgoEnvironment? outer;

  AlgoEnvironment([this.outer]);

  void define(String name, dynamic value) {
    variables[name.toLowerCase()] = value;
  }

  void assign(String name, dynamic value, int line, Debugger debugger) {
    if (variables.containsKey(name.toLowerCase())) {
      variables[name.toLowerCase()] = value;
      return;
    }
    if (outer != null) {
      outer!.assign(name, value, line, debugger);
      return;
    }
    debugger.reportError("Variable '$name' non déclarée", line, 0);
  }

  dynamic get(String name, int line, Debugger debugger) {
    if (variables.containsKey(name.toLowerCase())) {
      return variables[name.toLowerCase()];
    }
    if (outer != null) return outer!.get(name, line, debugger);

    debugger.reportError("Variable '$name' non déclarée", line, 0);
    return null;
  }
}

class Interpreter {
  final Debugger debugger;
  final Function(String) onOutput;
  final Future<String> Function(String?) onInput;

  int _loopCount = 0;
  int _instructionCount = 0;
  static const int _maxLoops = 10000;

  final Map<String, String> variableTypes = {};
  String? _lastWriteOutput;

  AlgoEnvironment globals = AlgoEnvironment();
  late AlgoEnvironment environment;

  Interpreter({
    required this.debugger,
    required this.onOutput,
    required this.onInput,
  }) {
    environment = globals;
  }

  Future<void> _loadFuncLocalVars(FuncDecl func) async {
    for (var decl in func.localVars) {
      variableTypes[decl.name.toLowerCase()] = decl.type.toLowerCase();
    }
    for (var decl in func.params) {
      variableTypes[decl.name.toLowerCase()] = decl.type.toLowerCase();
    }
  }

  Future<void> execute(ASTProgram program) async {
    globals.variables.clear();
    variableTypes.clear();
    _lastWriteOutput = null;
    _loopCount = 0;

    // Load vars
    for (var decl in program.globalVars) {
      variableTypes[decl.name.toLowerCase()] = decl.type.toLowerCase();
      if (decl.isArray) {
        // init array with nulls
        globals.define(
          decl.name,
          List<dynamic>.filled(
            (decl.arrayEnd - decl.arrayStart + 1),
            null,
            growable: true,
          ),
        );
        // store metadata
        globals.define(
          "\$arr_start_${decl.name.toLowerCase()}",
          decl.arrayStart,
        );
      } else {
        globals.define(decl.name, null);
      }
    }

    // Since we don't fully support functions in this minimal interpreter, we'll just run mainBody.
    try {
      await executeBlock(program.mainBody, globals);
    } catch (e) {
      if (e is ReturnException) {
        // Returned from main
      } else {
        debugger.reportError("Erreur d'exécution: $e", 0, 0);
      }
    }
  }

  Future<void> executeBlock(List<Stmt> statements, AlgoEnvironment env) async {
    AlgoEnvironment previous = environment;
    try {
      environment = env;
      for (var stmt in statements) {
        if (debugger.hasErrors) throw Exception("Arrêt");
        await executeStmt(stmt);
      }
    } finally {
      environment = previous;
    }
  }

  Future<void> executeStmt(Stmt stmt) async {
    // Rend la main au thread UI tous les 50 instructions pour éviter le freeze sur mobile
    _instructionCount++;
    if (_instructionCount % 50 == 0) {
      await Future.delayed(Duration.zero);
    }

    if (stmt is AssignStmt) {
      var val = evaluate(stmt.value);
      if (stmt.indexExpr != null) {
        var idx = evaluate(stmt.indexExpr!);
        var arr = environment.get(stmt.name, stmt.line, debugger);
        var startOffset =
            environment.get(
              "\$arr_start_${stmt.name.toLowerCase()}",
              stmt.line,
              debugger,
            ) ??
            1;
        if (arr is List && idx is int) {
          int realIdx = idx - (startOffset as int);
          if (realIdx >= 0 && realIdx < arr.length) {
            arr[realIdx] = val;
          } else {
            debugger.reportError("Index hors tableau ($idx)", stmt.line, 0);
          }
        }
      } else {
        environment.assign(stmt.name, val, stmt.line, debugger);
      }
    } else if (stmt is ReadStmt) {
      await _executeRead(stmt);
    } else if (stmt is MultiReadStmt) {
      for (var read in stmt.reads) {
        await _executeRead(read);
      }
    } else if (stmt is WriteStmt) {
      String out = "";
      for (var a in stmt.args) {
        out += evaluate(a).toString();
      }
      _lastWriteOutput = out;
      onOutput(out);
    } else if (stmt is IfStmt) {
      if (isTruthy(evaluate(stmt.condition))) {
        await executeBlock(stmt.thenBranch, environment);
      } else {
        await executeBlock(stmt.elseBranch, environment);
      }
    } else if (stmt is WhileStmt) {
      while (isTruthy(evaluate(stmt.condition))) {
        checkLoop();
        await executeBlock(stmt.body, environment);
      }
    } else if (stmt is RepeatStmt) {
      do {
        checkLoop();
        await executeBlock(stmt.body, environment);
      } while (!isTruthy(evaluate(stmt.condition)));
    } else if (stmt is ForStmt) {
      int start = evaluate(stmt.start) as int;
      int end = evaluate(stmt.end) as int;
      environment.assign(
        stmt.varName,
        start,
        stmt.line,
        debugger,
      ); // Assuming already declared

      if (start <= end) {
        for (int i = start; i <= end; i++) {
          checkLoop();
          environment.assign(stmt.varName, i, stmt.line, debugger);
          await executeBlock(stmt.body, environment);
        }
      } else {
        for (int i = start; i >= end; i--) {
          // Inverse
          checkLoop();
          environment.assign(stmt.varName, i, stmt.line, debugger);
          await executeBlock(stmt.body, environment);
        }
      }
    } else if (stmt is ReturnStmt) {
      dynamic val;
      if (stmt.value != null) val = evaluate(stmt.value!);
      throw ReturnException(val);
    }
  }

  Future<void> _executeRead(ReadStmt stmt) async {
    String basePrompt = "Saisie attendue pour ${stmt.name}";
    if (_lastWriteOutput != null && _lastWriteOutput!.trim().isNotEmpty) {
      basePrompt = _lastWriteOutput!.trim();
      _lastWriteOutput = null; // consommer
    }

    String type = variableTypes[stmt.name.toLowerCase()] ?? "texte";

    String input = await onInput("$basePrompt|$type");
    dynamic val;
    if (type == "entier") {
      val = int.tryParse(input) ?? 0;
    } else if (type == "réel" || type == "reel") {
      val = double.tryParse(input) ?? 0.0;
    } else if (type == "booléen" || type == "booleen") {
      val = input.toLowerCase() == "vrai" || input.toLowerCase() == "true";
    } else {
      val = input;
    }

    if (stmt.indexExpr != null) {
      var idx = evaluate(stmt.indexExpr!);
      var arr = environment.get(stmt.name, stmt.line, debugger);
      var startOffset =
          environment.get(
            "\$arr_start_${stmt.name.toLowerCase()}",
            stmt.line,
            debugger,
          ) ??
          1;
      if (arr is List && idx is int) {
        int realIdx = idx - (startOffset as int);
        if (realIdx >= 0 && realIdx < arr.length) {
          arr[realIdx] = val;
        }
      }
    } else {
      environment.assign(stmt.name, val, stmt.line, debugger);
    }
  }

  void checkLoop() {
    _loopCount++;
    if (_loopCount > _maxLoops) {
      debugger.reportError(
        "Boucle potentiellement infinie (limite dépasse $_maxLoops)",
        0,
        0,
      );
      throw Exception("Infinite loop");
    }
  }

  dynamic evaluate(Expr expr) {
    if (expr is LiteralExpr) return expr.value;
    if (expr is VarExpr) {
      if (expr.indexExpr != null) {
        var idx = evaluate(expr.indexExpr!);
        var arr = environment.get(expr.name, expr.line, debugger);
        var startOffset =
            environment.get(
              "\$arr_start_${expr.name.toLowerCase()}",
              expr.line,
              debugger,
            ) ??
            1;
        if (arr is List && idx is int) {
          int realIdx = idx - (startOffset as int);
          if (realIdx >= 0 && realIdx < arr.length) return arr[realIdx];
        }
        debugger.reportError("Index invalide ou hors tableau", expr.line, 0);
        return null;
      }
      return environment.get(expr.name, expr.line, debugger);
    }
    if (expr is UnaryExpr) {
      var right = evaluate(expr.expr);
      if (expr.op.value == '-') return -right;
      if (expr.op.value.toLowerCase() == 'non') return !isTruthy(right);
    }
    if (expr is BinaryExpr) {
      var left = evaluate(expr.left);
      var right = evaluate(expr.right);
      String op = expr.op.value.toLowerCase();

      switch (op) {
        case '+':
          return left +
              right; // allow string concat automatically if dart handles it
        case '-':
          return left - right;
        case '*':
          return left * right;
        case '/':
          if (right == 0) {
            debugger.reportError("Division par zéro", expr.line, 0);
            return 0;
          }
          return left / right;
        case 'div':
          if (right == 0) {
            debugger.reportError("Division par zéro", expr.line, 0);
            return 0;
          }
          return (left as int) ~/ (right as int);
        case 'mod':
          return (left as int) % (right as int);
        case '>':
          return left > right;
        case '>=':
        case '≥':
          return left >= right;
        case '<':
          return left < right;
        case '<=':
        case '≤':
          return left <= right;
        case '=':
          return left == right;
        case '<>':
        case '≠':
          return left != right;
        case 'et':
          return isTruthy(left) && isTruthy(right);
        case 'ou':
          return isTruthy(left) || isTruthy(right);
      }
    }
    return null;
  }

  bool isTruthy(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    return true; // Simple truthful
  }

  // To easily run from external code
  static Future<void> runCode(
    String code,
    Function(String) onOutput,
    Future<String> Function(String?) onInput,
    Function(List<AlgoError>) onErrors,
  ) async {
    final debugger = Debugger();
    final lexer = Lexer(code);
    final tokens = lexer.tokenize();
    final parser = Parser(tokens, debugger);
    final program = parser.parse();

    if (debugger.hasErrors || program == null) {
      onErrors(debugger.errors);
      return;
    }

    final interpreter = Interpreter(
      debugger: debugger,
      onOutput: onOutput,
      onInput: onInput,
    );
    await interpreter.execute(program);

    if (debugger.hasErrors) {
      onErrors(debugger.errors);
    }
  }
}

class ReturnException implements Exception {
  final dynamic value;
  ReturnException(this.value);
}
