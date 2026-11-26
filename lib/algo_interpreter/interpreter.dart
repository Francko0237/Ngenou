import 'dart:async';
import 'dart:convert';
import 'parser.dart';
import 'debugger.dart';
import 'lexer.dart';
import 'file_storage.dart';

// === Environnements et portée des variables ===
class AlgoEnvironment {
  final Map<String, dynamic> variables = {};
  final Map<String, String> types = {};
  final AlgoEnvironment? outer;

  AlgoEnvironment([this.outer]);

  void define(String name, dynamic value) {
    variables[name.toLowerCase()] = value;
  }

  void defineType(String name, String type) {
    types[name.toLowerCase()] = type.toLowerCase();
  }

  String? getType(String name) {
    final key = name.toLowerCase();
    if (types.containsKey(key)) return types[key];
    return outer?.getType(name);
  }

  void assign(String name, dynamic value, int line, Debugger debugger) {
    final key = name.toLowerCase();
    if (variables.containsKey(key)) {
      final slot = variables[key];
      if (slot is Ref) {
        slot.set(value, debugger, line);
        return;
      }
      variables[key] = value;
      return;
    }
    if (outer != null) {
      outer!.assign(name, value, line, debugger);
      return;
    }
    debugger.reportError("Variable '$name' non déclarée", line, 0);
  }

  dynamic get(String name, int line, Debugger debugger) {
    final key = name.toLowerCase();
    if (variables.containsKey(key)) {
      final slot = variables[key];
      if (slot is Ref) return slot.get(debugger, line);
      return slot;
    }
    if (outer != null) return outer!.get(name, line, debugger);
    debugger.reportError("Variable '$name' non déclarée", line, 0);
    return null;
  }
}

// === Références (passage par Entrée/Sortie & Sortie) ===
// Un paramètre par référence est lié à l'emplacement mémoire de l'argument
// côté appelant : toute lecture/écriture traverse la référence.
abstract class Ref {
  dynamic get(Debugger dbg, int line);
  void set(dynamic value, Debugger dbg, int line);
}

class VarRef extends Ref {
  final AlgoEnvironment env;
  final String name;
  VarRef(this.env, this.name);

  @override
  dynamic get(Debugger dbg, int line) => env.get(name, line, dbg);

  @override
  void set(dynamic value, Debugger dbg, int line) =>
      env.assign(name, value, line, dbg);
}

class ArrayElemRef extends Ref {
  final List<dynamic> arr;
  final int realIndex; // index déjà corrigé de l'offset de départ
  ArrayElemRef(this.arr, this.realIndex);

  @override
  dynamic get(Debugger dbg, int line) {
    if (realIndex < 0 || realIndex >= arr.length) {
      dbg.reportError("Index hors tableau", line, 0);
      return null;
    }
    return arr[realIndex];
  }

  @override
  void set(dynamic value, Debugger dbg, int line) {
    if (realIndex < 0 || realIndex >= arr.length) {
      dbg.reportError("Index hors tableau", line, 0);
      return;
    }
    arr[realIndex] = value;
  }
}

class StructFieldRef extends Ref {
  final StructValue sv;
  final String field;
  StructFieldRef(this.sv, this.field);

  @override
  dynamic get(Debugger dbg, int line) => sv.getField(field);

  @override
  void set(dynamic value, Debugger dbg, int line) => sv.setField(field, value);
}

// === Valeurs structure ===
class StructValue {
  final StructDecl decl;
  final Map<String, dynamic> _fields = {};

  StructValue(this.decl) {
    for (final f in decl.fields) {
      _fields[f.name.toLowerCase()] = null;
    }
  }

  dynamic getField(String name) => _fields[name.toLowerCase()];

  void setField(String name, dynamic value) {
    _fields[name.toLowerCase()] = value;
  }

  /// Copie indépendante (profonde) : utilisée pour le passage par valeur.
  StructValue copy() {
    final c = StructValue(decl);
    for (final f in decl.fields) {
      c._fields[f.name.toLowerCase()] = _deepCopyValue(
        _fields[f.name.toLowerCase()],
      );
    }
    return c;
  }

  @override
  String toString() {
    final parts = decl.fields.map((f) {
      final v = _fields[f.name.toLowerCase()];
      return '${f.name}=${v == null ? '' : (v is StructValue ? v.toString() : v)}';
    });
    return '${decl.name}(${parts.join(', ')})';
  }
}

/// Copie profonde d'une valeur (scalaire, liste ou structure).
dynamic _deepCopyValue(dynamic v) {
  if (v is StructValue) return v.copy();
  if (v is List) return v.map(_deepCopyValue).toList();
  return v; // scalaires immuables
}

class Interpreter {
  final Debugger debugger;
  final Function(String) onOutput;
  final Future<String> Function(String?) onInput;
  final FileStorage fileStorage;
  final void Function(FileEvent)? onFileEvent;

  int _loopCount = 0;
  int _instructionCount = 0;
  int _callDepth = 0;
  static const int _maxLoops = 10000;
  final int maxCallDepth;

  String? _lastWriteOutput;

  final Map<String, FuncDecl> _functions = {};
  final Map<String, StructDecl> _structTypes = {};
  final Map<int, _OpenFileChannel> _openChannels = {};

  AlgoEnvironment globals = AlgoEnvironment();
  late AlgoEnvironment environment;

  Interpreter({
    required this.debugger,
    required this.onOutput,
    required this.onInput,
    this.maxCallDepth = 100,
    FileStorage? fileStorage,
    this.onFileEvent,
  }) : fileStorage = fileStorage ?? InMemoryFileStorage() {
    environment = globals;
  }

  Future<void> execute(ASTProgram program) async {
    globals = AlgoEnvironment();
    environment = globals;
    _lastWriteOutput = null;
    _loopCount = 0;
    _callDepth = 0;

    _functions.clear();
    _structTypes.clear();
    _openChannels.clear();
    for (final f in program.functions) {
      _functions[f.name.toLowerCase()] = f;
    }
    for (final s in program.structTypes) {
      _structTypes[s.name.toLowerCase()] = s;
    }

    // Variables globales
    for (final decl in program.globalVars) {
      _declareVar(globals, decl);
    }

    try {
      await executeBlock(program.mainBody, globals);
    } on _StopException {
      // Exécution interrompue suite à une erreur (déjà présente dans debugger.errors)
    } on ReturnException {
      // Retour depuis le programme principal : ignoré
    } catch (e) {
      debugger.reportError("Erreur d'exécution: $e", 0, 0);
    } finally {
      if (_openChannels.isNotEmpty && !debugger.hasErrors) {
        for (final entry in _openChannels.entries) {
          onOutput(
            "⚠️ Avertissement : le canal ${entry.key} ('${entry.value.fileName}') n'a pas été fermé avant la fin de l'algorithme.",
          );
          onFileEvent?.call(
            FileEvent(
              channel: entry.key,
              fileName: entry.value.fileName,
              mode: entry.value.mode,
              type: FileEventType.close,
              linePosition: entry.value.cursor + 1,
              totalLines: entry.value.lines.length,
              isEof: entry.value.isEof,
            ),
          );
        }
      }
      _openChannels.clear();
    }
  }

  /// Déclare une variable dans un environnement (scalaire, tableau ou structure).
  void _declareVar(AlgoEnvironment env, VarDecl decl) {
    env.defineType(decl.name, decl.type);
    if (decl.isArray) {
      final len = decl.arrayEnd - decl.arrayStart + 1;
      final list = List<dynamic>.filled(
        len,
        _structTypes.containsKey(decl.type.toLowerCase())
            ? _defaultStruct(decl.type)
            : null,
        growable: true,
      );
      env.define(decl.name, list);
      env.define('\$arr_start_${decl.name.toLowerCase()}', decl.arrayStart);
    } else if (_structTypes.containsKey(decl.type.toLowerCase())) {
      env.define(decl.name, _defaultStruct(decl.type));
    } else {
      env.define(decl.name, _defaultScalar(decl.type));
    }
  }

  StructValue _defaultStruct(String typeName) {
    final decl = _structTypes[typeName.toLowerCase()]!;
    final sv = StructValue(decl);
    for (final f in decl.fields) {
      final ft = f.type.toLowerCase();
      if (_structTypes.containsKey(ft)) {
        sv.setField(f.name, _defaultStruct(ft));
      } else {
        sv.setField(f.name, _defaultScalar(ft));
      }
    }
    return sv;
  }

  dynamic _defaultScalar(String type) {
    switch (type.toLowerCase()) {
      case 'entier':
        return 0;
      case 'réel':
      case 'reel':
        return 0.0;
      case 'booléen':
      case 'booleen':
        return false;
      case 'chaîne':
      case 'chaine':
      case 'caractère':
      case 'caractere':
        return '';
      default:
        return null;
    }
  }

  Future<void> executeBlock(List<Stmt> statements, AlgoEnvironment env) async {
    final previous = environment;
    try {
      environment = env;
      for (final stmt in statements) {
        if (debugger.hasErrors) throw _StopException();
        await executeStmt(stmt);
      }
    } finally {
      environment = previous;
    }
  }

  Future<void> executeStmt(Stmt stmt) async {
    // Rend la main au thread UI tous les 50 instructions pour éviter le freeze
    _instructionCount++;
    if (_instructionCount % 50 == 0) {
      await Future.delayed(Duration.zero);
    }

    if (stmt is AssignStmt) {
      final val = await evaluate(stmt.value);
      if (stmt.indexExpr != null) {
        final idx = await evaluate(stmt.indexExpr!);
        final arr = environment.get(stmt.name, stmt.line, debugger);
        final startOffset =
            environment.get(
              '\$arr_start_${stmt.name.toLowerCase()}',
              stmt.line,
              debugger,
            ) ??
            1;
        if (arr is List && idx is int) {
          final realIdx = idx - (startOffset as int);
          if (realIdx >= 0 && realIdx < arr.length) {
            arr[realIdx] = val;
          } else {
            debugger.reportError("Index hors tableau ($idx)", stmt.line, 0);
          }
        } else {
          debugger.reportError("'$stmt.name' n'est pas un tableau", stmt.line, 0);
        }
      } else {
        environment.assign(stmt.name, val, stmt.line, debugger);
      }
    } else if (stmt is FieldAssignStmt) {
      final base = await evaluate(stmt.base);
      var val = await evaluate(stmt.value);
      if (base is StructValue) {
        val = _truncateStructFieldIfNeeded(base.decl, stmt.field, val, stmt.line);
        base.setField(stmt.field, val);
      } else {
        debugger.reportError(
          "Accès au champ '${stmt.field}' sur une non-structure",
          stmt.line,
          0,
        );
      }
    } else if (stmt is ReadStmt) {
      await _executeRead(stmt);
    } else if (stmt is MultiReadStmt) {
      for (final read in stmt.reads) {
        await _executeRead(read);
      }
    } else if (stmt is WriteStmt) {
      String out = "";
      for (final a in stmt.args) {
        out += _formatOutput(await evaluate(a));
      }
      _lastWriteOutput = out;
      onOutput(out);
    } else if (stmt is IfStmt) {
      if (isTruthy(await evaluate(stmt.condition))) {
        await executeBlock(stmt.thenBranch, environment);
      } else {
        await executeBlock(stmt.elseBranch, environment);
      }
    } else if (stmt is WhileStmt) {
      while (isTruthy(await evaluate(stmt.condition))) {
        checkLoop();
        await executeBlock(stmt.body, environment);
      }
    } else if (stmt is RepeatStmt) {
      do {
        checkLoop();
        await executeBlock(stmt.body, environment);
      } while (!isTruthy(await evaluate(stmt.condition)));
    } else if (stmt is ForStmt) {
      final start = await evaluate(stmt.start);
      final end = await evaluate(stmt.end);
      if (start is! int || end is! int) {
        debugger.reportError(
          "Les bornes d'un 'Pour' doivent être entières",
          stmt.line,
          0,
        );
        return;
      }
      environment.assign(stmt.varName, start, stmt.line, debugger);
      if (start <= end) {
        for (int i = start; i <= end; i++) {
          checkLoop();
          environment.assign(stmt.varName, i, stmt.line, debugger);
          await executeBlock(stmt.body, environment);
        }
      } else {
        for (int i = start; i >= end; i--) {
          checkLoop();
          environment.assign(stmt.varName, i, stmt.line, debugger);
          await executeBlock(stmt.body, environment);
        }
      }
    } else if (stmt is ReturnStmt) {
      dynamic val;
      if (stmt.value != null) val = await evaluate(stmt.value!);
      throw ReturnException(val);
    } else if (stmt is CallStmt) {
      await _callFunction(stmt.call.name, stmt.call.args, stmt.line);
    } else if (stmt is OpenFileStmt) {
      await _executeOpenFile(stmt);
    } else if (stmt is ReadFileStmt) {
      await _executeReadFile(stmt);
    } else if (stmt is WriteFileStmt) {
      await _executeWriteFile(stmt);
    } else if (stmt is SeekFileStmt) {
      await _executeSeekFile(stmt);
    } else if (stmt is CloseFileStmt) {
      await _executeCloseFile(stmt);
    }
  }

  Future<void> _executeRead(ReadStmt stmt) async {
    String basePrompt = "Saisie attendue pour ${stmt.name}";
    if (_lastWriteOutput != null && _lastWriteOutput!.trim().isNotEmpty) {
      basePrompt = _lastWriteOutput!.trim();
      _lastWriteOutput = null; // consommer
    }

    final type = (environment.getType(stmt.name) ?? "texte").toLowerCase();

    final input = await onInput("$basePrompt|$type");
    dynamic val;
    if (type == "entier") {
      val = int.tryParse(input) ?? 0;
    } else if (type == "réel" || type == "reel") {
      val = double.tryParse(input) ?? 0.0;
    } else if (type == "booléen" || type == "booleen") {
      val = (input.toLowerCase() == "vrai" || input.toLowerCase() == "true");
    } else {
      val = input;
    }

    if (stmt.indexExpr != null) {
      final idx = await evaluate(stmt.indexExpr!);
      final arr = environment.get(stmt.name, stmt.line, debugger);
      final startOffset =
          environment.get(
            '\$arr_start_${stmt.name.toLowerCase()}',
            stmt.line,
            debugger,
          ) ??
          1;
      if (arr is List && idx is int) {
        final realIdx = idx - (startOffset as int);
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
        "Boucle potentiellement infinie (limite dépassée $_maxLoops)",
        0,
        0,
      );
      throw _StopException();
    }
  }

  String _formatOutput(dynamic v) {
    if (v == null) return '';
    if (v is StructValue) return v.toString();
    return v.toString();
  }

  Future<dynamic> evaluate(Expr expr) async {
    if (expr is LiteralExpr) return expr.value;
    if (expr is VarExpr) {
      if (expr.indexExpr != null) {
        final idx = await evaluate(expr.indexExpr!);
        final arr = environment.get(expr.name, expr.line, debugger);
        final startOffset =
            environment.get(
              '\$arr_start_${expr.name.toLowerCase()}',
              expr.line,
              debugger,
            ) ??
            1;
        if (arr is List && idx is int) {
          final realIdx = idx - (startOffset as int);
          if (realIdx >= 0 && realIdx < arr.length) return arr[realIdx];
        }
        debugger.reportError("Index invalide ou hors tableau", expr.line, 0);
        return null;
      }
      return environment.get(expr.name, expr.line, debugger);
    }
    if (expr is FieldExpr) {
      final base = await evaluate(expr.base);
      if (base is StructValue) return base.getField(expr.field);
      debugger.reportError(
        "Accès au champ '${expr.field}' sur une non-structure",
        expr.line,
        0,
      );
      return null;
    }
    if (expr is CallExpr) {
      return await _callFunction(
        expr.name,
        expr.args,
        expr.line,
        asExpression: true,
      );
    }
    if (expr is EofExpr) {
      return await _evaluateEof(expr);
    }
    if (expr is UnaryExpr) {
      final right = await evaluate(expr.expr);
      if (expr.op.value == '-') {
        if (right is num) return -right;
        debugger.reportError("L'opérateur '-' s'applique à un nombre", expr.line, 0);
        return 0;
      }
      if (expr.op.value.toLowerCase() == 'non') return !isTruthy(right);
    }
    if (expr is BinaryExpr) {
      final left = await evaluate(expr.left);
      final right = await evaluate(expr.right);
      return _applyBinary(expr, left, right);
    }
    return null;
  }

  dynamic _applyBinary(BinaryExpr expr, dynamic left, dynamic right) {
    final op = expr.op.value.toLowerCase();
    switch (op) {
      case '+':
        return left + right;
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
    debugger.reportError("Opérateur inconnu '${expr.op.value}'", expr.line, 0);
    return null;
  }

  bool isTruthy(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    return true;
  }

  // === Appels de fonction / procédure ===
  Future<dynamic> _callFunction(
    String name,
    List<Expr> argExprs,
    int callLine, {
    bool asExpression = false,
  }) async {
    final key = name.toLowerCase();
    final func = _functions[key];
    if (func == null) {
      debugger.reportError(
        "Fonction/Procédure '$name' non définie",
        callLine,
        0,
      );
      return null;
    }

    // Une procédure ne peut pas être utilisée dans une expression (pas de valeur)
    if (func.returnType == null && asExpression) {
      debugger.reportError(
        "La procédure '$name' ne retourne pas de valeur et ne peut pas être utilisée dans une expression",
        callLine,
        0,
      );
      return null;
    }

    if (argExprs.length != func.params.length) {
      debugger.reportError(
        "La fonction '$name' attend ${func.params.length} argument(s) mais en a reçu ${argExprs.length}",
        callLine,
        0,
      );
      return null;
    }

    _callDepth++;
    if (_callDepth > maxCallDepth) {
      _callDepth--;
      debugger.reportError(
        "Profondeur de récursivité maximale atteinte ($maxCallDepth) — récursivité infinie ?",
        callLine,
        0,
      );
      throw _StopException();
    }

    final callerEnv = environment;
    // Environnement isolé : seuls les paramètres et les variables locales sont
    // accessibles (pas les variables globales), conformément à l'isolation des appels.
    final callEnv = AlgoEnvironment(null);

    // Paramètres
    for (int i = 0; i < func.params.length; i++) {
      final p = func.params[i];
      final arg = argExprs[i];
      callEnv.defineType(p.name, p.type);
      if (p.isArray) {
        callEnv.define('\$arr_start_${p.name.toLowerCase()}', p.arrayStart);
      }
      if (p.mode == ParamMode.reference) {
        final ref = await _buildRef(arg, callerEnv, callLine);
        if (ref == null) {
          debugger.reportError(
            "Le paramètre '${p.name}' est passé par référence (Entrée/Sortie) mais l'argument n'est pas une variable modifiable",
            callLine,
            0,
          );
          callEnv.define(p.name, null);
        } else {
          _checkArgType(p, ref.get(debugger, callLine), name, callLine);
          callEnv.define(p.name, ref);
        }
      } else {
        var val = await evaluate(arg); // évalué dans l'env de l'appelant
        val = _deepCopyValue(val); // passage par valeur (copie)
        _checkArgType(p, val, name, callLine);
        callEnv.define(p.name, val);
      }
    }

    // Variables locales
    for (final decl in func.localVars) {
      _declareVar(callEnv, decl);
    }

    dynamic returnValue;
    bool returned = false;
    try {
      await executeBlock(func.body, callEnv);
    } on ReturnException catch (e) {
      returnValue = e.value;
      returned = true;
    } finally {
      _callDepth--;
    }

    if (func.returnType != null && !returned) {
      debugger.reportError(
        "La fonction '$name' ne retourne aucune valeur (Retourner manquant)",
        func.body.isNotEmpty ? func.body.first.line : callLine,
        0,
      );
      return null;
    }
    return returnValue;
  }

  /// Construit une référence vers l'argument côté appelant (pour les paramètres
  /// par référence). Retourne null si l'argument n'est pas une variable modifiable.
  Future<Ref?> _buildRef(Expr arg, AlgoEnvironment env, int line) async {
    if (arg is VarExpr && arg.indexExpr != null) {
      // Élément de tableau : T[i] -> ArrayElemRef
      final arr = env.get(arg.name, line, debugger);
      final idx = await evaluate(arg.indexExpr!);
      final startOffset =
          env.get('\$arr_start_${arg.name.toLowerCase()}', line, debugger) ?? 1;
      if (arr is List && idx is int) {
        return ArrayElemRef(arr, idx - (startOffset as int));
      }
      debugger.reportError("'$arg' n'est pas un élément de tableau valide", line, 0);
      return null;
    }
    if (arg is VarExpr) {
      return VarRef(env, arg.name);
    }
    if (arg is FieldExpr) {
      final base = await evaluate(arg.base);
      if (base is StructValue) return StructFieldRef(base, arg.field);
      debugger.reportError("'$arg' n'est pas un champ de structure", line, 0);
      return null;
    }
    return null; // littéral, appel, expression... : pas une lvalue
  }

  void _checkArgType(ParamDecl p, dynamic argVal, String funcName, int line) {
    final ptype = p.type.toLowerCase();
    if (_structTypes.containsKey(ptype)) {
      if (argVal is! StructValue ||
          argVal.decl.name.toLowerCase() != ptype) {
        debugger.reportError(
          "Type incompatible : la fonction '$funcName' attend une structure '${p.type}' pour '${p.name}'",
          line,
          0,
        );
      }
    } else if (p.isArray) {
      if (argVal is! List) {
        debugger.reportError(
          "Type incompatible : la fonction '$funcName' attend un tableau pour '${p.name}'",
          line,
          0,
        );
      }
    } else {
      switch (ptype) {
        case 'entier':
          if (argVal is! int) {
            debugger.reportError(
              "Type incompatible : la fonction '$funcName' attend un Entier pour '${p.name}'",
              line,
              0,
            );
          }
          break;
        case 'réel':
        case 'reel':
          if (argVal is! num) {
            debugger.reportError(
              "Type incompatible : la fonction '$funcName' attend un Réel pour '${p.name}'",
              line,
              0,
            );
          }
          break;
        case 'chaîne':
        case 'chaine':
        case 'caractère':
        case 'caractere':
          if (argVal is! String) {
            debugger.reportError(
              "Type incompatible : la fonction '$funcName' attend une Chaîne pour '${p.name}'",
              line,
              0,
            );
          }
          break;
        case 'booléen':
        case 'booleen':
          if (argVal is! bool) {
            debugger.reportError(
              "Type incompatible : la fonction '$funcName' attend un Booléen pour '${p.name}'",
              line,
              0,
            );
          }
          break;
      }
    }
  }

  // === Gestion des fichiers (JSON Lines + canaux) ===

  dynamic _truncateStructFieldIfNeeded(
    StructDecl decl,
    String fieldName,
    dynamic val,
    int line,
  ) {
    if (val is! String) return val;
    for (final f in decl.fields) {
      if (f.name.toLowerCase() == fieldName.toLowerCase() &&
          f.length != null &&
          f.length! > 0 &&
          val.length > f.length!) {
        final truncated = val.substring(0, f.length!);
        onOutput(
          "⚠️ Avertissement ligne $line : le texte du champ '${f.name}' dépasse ${f.length} caractères et a été tronqué.",
        );
        return truncated;
      }
    }
    return val;
  }

  int? _resolveChannel(Expr channelExpr, int line, dynamic rawVal) {
    if (rawVal is! int || rawVal <= 0) {
      debugger.reportError(
        "Numéro de canal invalide ($rawVal) : doit être un entier positif (>= 1)",
        line,
        0,
      );
      return null;
    }
    return rawVal;
  }

  FileOpenMode _parseOpenMode(String modeStr) {
    switch (modeStr.toLowerCase()) {
      case 'lecture':
        return FileOpenMode.lecture;
      case 'ajout':
        return FileOpenMode.ajout;
      case 'ecriture':
      case 'écriture':
      default:
        return FileOpenMode.ecriture;
    }
  }

  Future<void> _executeOpenFile(OpenFileStmt stmt) async {
    final pathVal = await evaluate(stmt.pathExpr);
    if (pathVal is! String || pathVal.trim().isEmpty) {
      debugger.reportError(
        "Le nom du fichier doit être une chaîne non vide",
        stmt.line,
        0,
      );
      return;
    }
    final chVal = await evaluate(stmt.channelExpr);
    final channel = _resolveChannel(stmt.channelExpr, stmt.line, chVal);
    if (channel == null) return;

    if (_openChannels.containsKey(channel)) {
      debugger.reportError(
        "Le canal $channel est déjà utilisé par '${_openChannels[channel]!.fileName}'",
        stmt.line,
        0,
      );
      return;
    }

    final fileName = pathVal.trim();
    final mode = _parseOpenMode(stmt.mode);
    List<String> lines = [];
    int cursor = 0;

    if (mode == FileOpenMode.lecture) {
      final exists = await fileStorage.exists(fileName);
      if (!exists) {
        debugger.reportError(
          "Fichier introuvable en lecture : '$fileName'",
          stmt.line,
          0,
        );
        return;
      }
      lines = await fileStorage.readLines(fileName);
      cursor = 0;
    } else if (mode == FileOpenMode.ecriture) {
      await fileStorage.writeLines(fileName, []);
      lines = [];
      cursor = 0;
    } else if (mode == FileOpenMode.ajout) {
      if (await fileStorage.exists(fileName)) {
        lines = await fileStorage.readLines(fileName);
      } else {
        await fileStorage.writeLines(fileName, []);
        lines = [];
      }
      cursor = lines.length;
    }

    final chState = _OpenFileChannel(
      channel: channel,
      fileName: fileName,
      mode: mode,
      lines: lines,
      cursor: cursor,
    );
    _openChannels[channel] = chState;

    onFileEvent?.call(
      FileEvent(
        channel: channel,
        fileName: fileName,
        mode: mode,
        type: FileEventType.open,
        linePosition: cursor + 1,
        totalLines: lines.length,
        isEof: chState.isEof,
        algoLine: stmt.line,
      ),
    );
  }

  Future<void> _executeReadFile(ReadFileStmt stmt) async {
    final chVal = await evaluate(stmt.channelExpr);
    final channel = _resolveChannel(stmt.channelExpr, stmt.line, chVal);
    if (channel == null) return;

    final chState = _openChannels[channel];
    if (chState == null) {
      debugger.reportError(
        "Impossible de lire sur le canal $channel : canal fermé ou non ouvert",
        stmt.line,
        0,
      );
      return;
    }

    if (chState.mode != FileOpenMode.lecture) {
      debugger.reportError(
        "Impossible de lire sur le canal $channel : le fichier '${chState.fileName}' n'est pas ouvert en mode Lecture",
        stmt.line,
        0,
      );
      return;
    }

    if (chState.isEof) {
      debugger.reportError(
        "Lecture impossible sur le canal $channel ('${chState.fileName}') : fin de fichier atteinte (EOF)",
        stmt.line,
        0,
      );
      return;
    }

    final rawLine = chState.lines[chState.cursor];
    dynamic decoded;
    try {
      decoded = jsonDecode(rawLine);
    } catch (_) {
      decoded = rawLine;
    }

    // Déterminer la cible (variable ou élément de tableau)
    dynamic currentTarget;
    List<dynamic>? targetArr;
    int? targetRealIdx;

    if (stmt.indexExpr != null) {
      final idx = await evaluate(stmt.indexExpr!);
      final arr = environment.get(stmt.varName, stmt.line, debugger);
      final startOffset =
          environment.get(
            '\$arr_start_${stmt.varName.toLowerCase()}',
            stmt.line,
            debugger,
          ) ??
          1;
      if (arr is List && idx is int) {
        final realIdx = idx - (startOffset as int);
        if (realIdx >= 0 && realIdx < arr.length) {
          targetArr = arr;
          targetRealIdx = realIdx;
          currentTarget = arr[realIdx];
        } else {
          debugger.reportError("Index hors tableau ($idx)", stmt.line, 0);
          return;
        }
      } else {
        debugger.reportError(
          "'${stmt.varName}' n'est pas un tableau",
          stmt.line,
          0,
        );
        return;
      }
    } else {
      currentTarget = environment.get(stmt.varName, stmt.line, debugger);
      if (debugger.hasErrors) return;
    }

    if (currentTarget is StructValue) {
      if (decoded is! Map) {
        debugger.reportError(
          "Format d'enregistrement invalide à la ligne ${chState.cursor + 1} de '${chState.fileName}' pour la structure '${currentTarget.decl.name}'",
          stmt.line,
          0,
        );
        return;
      }
      final newStruct = _defaultStruct(currentTarget.decl.name);
      final lowerMap = <String, dynamic>{};
      decoded.forEach((k, v) {
        lowerMap[k.toString().toLowerCase()] = v;
      });
      for (final f in currentTarget.decl.fields) {
        if (lowerMap.containsKey(f.name.toLowerCase())) {
          var fieldVal = _coerceScalar(lowerMap[f.name.toLowerCase()], f.type);
          fieldVal = _truncateStructFieldIfNeeded(
            currentTarget.decl,
            f.name,
            fieldVal,
            stmt.line,
          );
          newStruct.setField(f.name, fieldVal);
        }
      }
      if (targetArr != null && targetRealIdx != null) {
        targetArr[targetRealIdx] = newStruct;
      } else {
        environment.assign(stmt.varName, newStruct, stmt.line, debugger);
      }
    } else {
      final declaredType = environment.getType(stmt.varName) ?? '';
      final coerced = _coerceScalar(decoded, declaredType);
      if (targetArr != null && targetRealIdx != null) {
        targetArr[targetRealIdx] = coerced;
      } else {
        environment.assign(stmt.varName, coerced, stmt.line, debugger);
      }
    }

    final readPos = chState.cursor + 1;
    chState.cursor++;

    onFileEvent?.call(
      FileEvent(
        channel: channel,
        fileName: chState.fileName,
        mode: chState.mode,
        type: FileEventType.read,
        linePosition: readPos,
        totalLines: chState.lines.length,
        isEof: chState.isEof,
        record: decoded,
        algoLine: stmt.line,
      ),
    );
  }

  dynamic _coerceScalar(dynamic val, String typeName) {
    if (val == null) return _defaultScalar(typeName);
    switch (typeName.toLowerCase()) {
      case 'entier':
        if (val is int) return val;
        if (val is num) return val.toInt();
        return int.tryParse(val.toString()) ?? 0;
      case 'réel':
      case 'reel':
        if (val is num) return val.toDouble();
        return double.tryParse(val.toString()) ?? 0.0;
      case 'booléen':
      case 'booleen':
        if (val is bool) return val;
        final s = val.toString().toLowerCase();
        return s == 'true' || s == 'vrai' || s == '1';
      case 'chaîne':
      case 'chaine':
      case 'caractère':
      case 'caractere':
        return val.toString();
      default:
        return val;
    }
  }

  Future<void> _executeWriteFile(WriteFileStmt stmt) async {
    final chVal = await evaluate(stmt.channelExpr);
    final channel = _resolveChannel(stmt.channelExpr, stmt.line, chVal);
    if (channel == null) return;

    final chState = _openChannels[channel];
    if (chState == null) {
      debugger.reportError(
        "Impossible d'écrire sur le canal $channel : canal fermé ou non ouvert",
        stmt.line,
        0,
      );
      return;
    }

    if (chState.mode == FileOpenMode.lecture) {
      debugger.reportError(
        "Impossible d'écrire sur le canal $channel : '${chState.fileName}' est ouvert en mode Lecture uniquement",
        stmt.line,
        0,
      );
      return;
    }

    final val = await evaluate(stmt.valueExpr);
    dynamic jsonReady;

    if (val is StructValue) {
      final map = <String, dynamic>{};
      for (final f in val.decl.fields) {
        var fVal = val.getField(f.name);
        fVal = _truncateStructFieldIfNeeded(val.decl, f.name, fVal, stmt.line);
        val.setField(f.name, fVal);
        map[f.name] = fVal;
      }
      jsonReady = map;
    } else if (val is int || val is double || val is String || val is bool) {
      jsonReady = val;
    } else {
      debugger.reportError(
        "Type non supporté pour l'écriture dans un fichier (attendu Structure ou variable simple)",
        stmt.line,
        0,
      );
      return;
    }

    final jsonLine = jsonEncode(jsonReady);
    int writtenPos;

    if (chState.cursor >= chState.lines.length) {
      chState.lines.add(jsonLine);
      writtenPos = chState.lines.length;
      chState.cursor = chState.lines.length;
      await fileStorage.appendLine(chState.fileName, jsonLine);
    } else {
      chState.lines[chState.cursor] = jsonLine;
      writtenPos = chState.cursor + 1;
      chState.cursor++;
      await fileStorage.writeLines(chState.fileName, chState.lines);
    }

    onFileEvent?.call(
      FileEvent(
        channel: channel,
        fileName: chState.fileName,
        mode: chState.mode,
        type: FileEventType.write,
        linePosition: writtenPos,
        totalLines: chState.lines.length,
        isEof: chState.isEof,
        record: jsonReady,
        algoLine: stmt.line,
      ),
    );
  }

  Future<void> _executeSeekFile(SeekFileStmt stmt) async {
    final chVal = await evaluate(stmt.channelExpr);
    final channel = _resolveChannel(stmt.channelExpr, stmt.line, chVal);
    if (channel == null) return;

    final chState = _openChannels[channel];
    if (chState == null) {
      debugger.reportError(
        "Impossible de positionner le canal $channel : canal fermé ou non ouvert",
        stmt.line,
        0,
      );
      return;
    }

    final lineVal = await evaluate(stmt.lineExpr);
    if (lineVal is! int || lineVal < 1) {
      debugger.reportError(
        "Numéro de ligne invalide ($lineVal) dans PositionnerFichier : la première ligne est 1",
        stmt.line,
        0,
      );
      return;
    }

    if (lineVal > chState.lines.length + 1) {
      debugger.reportError(
        "Positionnement hors limites (ligne $lineVal) dans '${chState.fileName}' (${chState.lines.length} enregistrement(s))",
        stmt.line,
        0,
      );
      return;
    }

    chState.cursor = lineVal - 1;
    onFileEvent?.call(
      FileEvent(
        channel: channel,
        fileName: chState.fileName,
        mode: chState.mode,
        type: FileEventType.seek,
        linePosition: chState.cursor + 1,
        totalLines: chState.lines.length,
        isEof: chState.isEof,
        algoLine: stmt.line,
      ),
    );
  }

  Future<void> _executeCloseFile(CloseFileStmt stmt) async {
    final chVal = await evaluate(stmt.channelExpr);
    final channel = _resolveChannel(stmt.channelExpr, stmt.line, chVal);
    if (channel == null) return;

    final chState = _openChannels.remove(channel);
    if (chState == null) {
      debugger.reportError(
        "Impossible de fermer le canal $channel : déjà fermé ou non ouvert",
        stmt.line,
        0,
      );
      return;
    }

    onFileEvent?.call(
      FileEvent(
        channel: channel,
        fileName: chState.fileName,
        mode: chState.mode,
        type: FileEventType.close,
        linePosition: chState.cursor + 1,
        totalLines: chState.lines.length,
        isEof: chState.isEof,
        algoLine: stmt.line,
      ),
    );
  }

  Future<bool> _evaluateEof(EofExpr expr) async {
    final chVal = await evaluate(expr.channelExpr);
    final channel = _resolveChannel(expr.channelExpr, expr.line, chVal);
    if (channel == null) return true;

    final chState = _openChannels[channel];
    if (chState == null) {
      debugger.reportError(
        "EOF impossible sur le canal $channel : canal fermé ou non ouvert",
        expr.line,
        0,
      );
      return true;
    }

    onFileEvent?.call(
      FileEvent(
        channel: channel,
        fileName: chState.fileName,
        mode: chState.mode,
        type: FileEventType.eof,
        linePosition: chState.cursor + 1,
        totalLines: chState.lines.length,
        isEof: chState.isEof,
        algoLine: expr.line,
      ),
    );
    return chState.isEof;
  }

  // === Point d'entrée utilitaire ===
  static Future<void> runCode(
    String code,
    Function(String) onOutput,
    Future<String> Function(String?) onInput,
    Function(List<AlgoError>) onErrors, {
    int maxCallDepth = 100,
    FileStorage? fileStorage,
    void Function(FileEvent)? onFileEvent,
  }) async {
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
      maxCallDepth: maxCallDepth,
      fileStorage: fileStorage,
      onFileEvent: onFileEvent,
    );
    await interpreter.execute(program);

    if (debugger.hasErrors) {
      onErrors(debugger.errors);
    }
  }
}

class _OpenFileChannel {
  final int channel;
  final String fileName;
  final FileOpenMode mode;
  final List<String> lines;
  int cursor; // 0-based

  _OpenFileChannel({
    required this.channel,
    required this.fileName,
    required this.mode,
    required this.lines,
    required this.cursor,
  });

  bool get isEof => cursor >= lines.length;
}

class ReturnException implements Exception {
  final dynamic value;
  ReturnException(this.value);
}

/// Signal interne d'arrêt (erreur déjà signalée, ou limite de récursivité).
class _StopException implements Exception {}
