class AlgoError {
  final String message;
  final int line;
  final int column;

  AlgoError(this.message, this.line, this.column);

  @override
  String toString() {
    return 'Erreur ligne $line : $message';
  }
}

class Debugger {
  final List<AlgoError> errors = [];
  bool get hasErrors => errors.isNotEmpty;
  
  void reportError(String message, int line, int column) {
    errors.add(AlgoError(message, line, column));
  }
  
  void clear() {
    errors.clear();
  }

  String getFormattedErrors() {
    return errors.map((e) => e.toString()).join('\n');
  }
}
