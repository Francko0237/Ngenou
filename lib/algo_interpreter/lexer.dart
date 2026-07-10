enum TokenType {
  keyword,
  identifier,
  number,
  string,
  operator,
  punctuation,
  eof,
  error,
}

class Token {
  final TokenType type;
  final String value;
  final int line;
  final int column;

  Token(this.type, this.value, this.line, this.column);

  @override
  String toString() => 'Token($type, "$value", line: $line, col: $column)';
}

class Lexer {
  final String source;
  int position = 0;
  int line = 1;
  int column = 1;

  static final List<String> keywords = [
    'algorithme',
    'var',
    'variables',
    'const',
    'début',
    'debut',
    'fin',
    'entier',
    'réel',
    'reel',
    'chaîne',
    'chaine',
    'caractère',
    'caractere',
    'booléen',
    'booleen',
    'tableau',
    'de',
    'lire',
    'ecrire',
    'si',
    'alors',
    'sinon',
    'finsi',
    'tant',
    'que',
    'faire',
    'fintantque',
    'pour',
    'à',
    'finpour',
    'répéter',
    'repeter',
    'jusqu',
    'et',
    'ou',
    'non',
    'mod',
    'div',
    'fonction',
    'procédure',
    'procedure',
    'retourner',
    'vrai',
    'faux',
  ];

  static final List<String> symbols = [
    '←',
    '<-',
    '+',
    '-',
    '*',
    '/',
    '^',
    '**',
    '=',
    '<',
    '>'
    '≠',
    '<',
    '>',
    '<=',
    '>=',
    '≤',
    '≥',
    '(',
    ')',
    '[',
    ']',
    ':',
    ';',
    ',',
    '.',
    '..',
  ];

  Lexer(this.source);

  List<Token> tokenize() {
    List<Token> tokens = [];
    while (position < source.length) {
      skipWhitespace();
      if (position >= source.length) break;

      final char = source[position];

      // Comments
      if (char == '/' && position + 1 < source.length) {
        if (source[position + 1] == '/') {
          skipSingleLineComment();
          continue;
        } else if (source[position + 1] == '*') {
          skipMultiLineComment();
          continue;
        }
      }

      if (isDigit(char)) {
        tokens.add(readNumber());
      } else if (isAlpha(char) || char == '_') {
        tokens.add(readIdentifierOrKeyword());
      } else if (char == '"' || char == "'") {
        tokens.add(readString());
      } else {
        Token? op = readSymbol();
        if (op != null) {
          tokens.add(op);
        } else {
          tokens.add(Token(TokenType.error, char, line, column));
          advance();
        }
      }
    }
    tokens.add(Token(TokenType.eof, '', line, column));
    return _filterCombinedTokens(tokens);
  }

  List<Token> _filterCombinedTokens(List<Token> input) {
    List<Token> output = [];
    for (int i = 0; i < input.length; i++) {
      String val = input[i].value.toLowerCase();
      // Combine "Tant que"
      if (i + 1 < input.length &&
          val == 'tant' &&
          input[i + 1].value.toLowerCase() == 'que') {
        output.add(
          Token(TokenType.keyword, 'tant que', input[i].line, input[i].column),
        );
        i++;
      }
      // Combine "Jusqu'à"
      else if (i + 2 < input.length &&
          val == 'jusqu' &&
          input[i + 1].value == "'" &&
          input[i + 2].value.toLowerCase() == 'à') {
        output.add(
          Token(TokenType.keyword, "jusqu'à", input[i].line, input[i].column),
        );
        i += 2;
      } else {
        output.add(input[i]);
      }
    }
    return output;
  }

  bool isDigit(String c) => RegExp(r'[0-9]').hasMatch(c);
  bool isAlpha(String c) => RegExp(r'[a-zA-ZÀ-ÿ]').hasMatch(c);

  void skipWhitespace() {
    while (position < source.length) {
      final char = source[position];
      if (char == ' ' || char == '\t') {
        advance();
      } else if (char == '\n' || char == '\r') {
        if (char == '\n') {
          line++;
          column = 1;
        }
        position++;
      } else {
        break;
      }
    }
  }

  void skipSingleLineComment() {
    while (position < source.length && source[position] != '\n') {
      advance();
    }
  }

  void skipMultiLineComment() {
    position += 2;
    column += 2;
    while (position < source.length) {
      if (source[position] == '*' &&
          position + 1 < source.length &&
          source[position + 1] == '/') {
        position += 2;
        column += 2;
        break;
      }
      if (source[position] == '\n') {
        line++;
        column = 1;
        position++;
      } else {
        advance();
      }
    }
  }

  Token readNumber() {
    int startLine = line;
    int startCol = column;
    String result = '';
    bool hasDot = false;
    while (position < source.length) {
      String c = source[position];
      if (isDigit(c)) {
        result += c;
        advance();
      } else if (c == '.') {
        if (position + 1 < source.length && source[position + 1] == '.') {
          break; // Stop at '..'
        }
        if (hasDot) break;
        hasDot = true;
        result += c;
        advance();
      } else {
        break;
      }
    }
    return Token(TokenType.number, result, startLine, startCol);
  }

  Token readIdentifierOrKeyword() {
    int startLine = line;
    int startCol = column;
    String result = '';
    while (position < source.length &&
        (isAlpha(source[position]) ||
            isDigit(source[position]) ||
            source[position] == '_')) {
      result += source[position];
      advance();
    }

    String lower = result.toLowerCase();
    if (keywords.contains(lower)) {
      return Token(TokenType.keyword, result, startLine, startCol);
    }

    return Token(TokenType.identifier, result, startLine, startCol);
  }

  Token readString() {
    int startLine = line;
    int startCol = column;
    String quote = source[position];
    advance();
    String result = '';
    while (position < source.length && source[position] != quote) {
      if (source[position] == '\n') {
        line++;
        column = 1;
      }
      result += source[position];
      advance();
    }
    if (position < source.length) {
      advance();
    }
    return Token(TokenType.string, result, startLine, startCol);
  }

  Token? readSymbol() {
    int startLine = line;
    int startCol = column;

    // Check ' for jusqu'à compatibility
    if (source[position] == "'") {
      advance();
      return Token(TokenType.punctuation, "'", startLine, startCol);
    }

    if (position + 1 < source.length) {
      String twoChar = source.substring(position, position + 2);
      if (symbols.contains(twoChar)) {
        advance();
        advance();
        if (twoChar == '..') {
          return Token(TokenType.punctuation, twoChar, startLine, startCol);
        }
        return Token(TokenType.operator, twoChar, startLine, startCol);
      }
    }

    String oneChar = source[position];
    if (symbols.contains(oneChar)) {
      advance();
      if (['(', ')', '[', ']', ':', ';', ',', '.'].contains(oneChar)) {
        return Token(TokenType.punctuation, oneChar, startLine, startCol);
      }
      return Token(TokenType.operator, oneChar, startLine, startCol);
    }

    return null;
  }

  void advance() {
    position++;
    column++;
  }
}
