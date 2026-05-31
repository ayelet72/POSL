import 'dart:io';

enum TokenType {
  keyword,
  symbol,
  identifier,
  integerConstant,
  stringConstant,
}

class JackTokenizer {
  static const Set<String> keywords = {
    'class',
    'constructor',
    'function',
    'method',
    'field',
    'static',
    'var',
    'int',
    'char',
    'boolean',
    'void',
    'true',
    'false',
    'null',
    'this',
    'let',
    'do',
    'if',
    'else',
    'while',
    'return',
  };

  static const Set<String> symbols = {
    '{',
    '}',
    '(',
    ')',
    '[',
    ']',
    '.',
    ',',
    ';',
    '+',
    '-',
    '*',
    '/',
    '&',
    '|',
    '<',
    '>',
    '=',
    '~',
  };

  final String _input;
  int _index = 0;

  String? _currentToken;
  TokenType? _currentType;

  JackTokenizer(String input) : _input = input;

  bool hasMoreTokens() {
    int tempIndex = _index;
    tempIndex = _skipWhitespaceAndComments(tempIndex);
    return tempIndex < _input.length;
  }

  void advance() {
    _index = _skipWhitespaceAndComments(_index);

    if (_index >= _input.length) {
      _currentToken = null;
      _currentType = null;
      return;
    }

    final ch = _input[_index];

    if (ch == '"') {
      _readStringConstant();
      return;
    }

    if (_isSymbol(ch)) {
      _currentToken = ch;
      _currentType = TokenType.symbol;
      _index++;
      return;
    }

    if (_isDigit(ch)) {
      _readIntegerConstant();
      return;
    }

    if (_isIdentifierStart(ch)) {
      _readIdentifierOrKeyword();
      return;
    }

    throw FormatException('Unexpected character "$ch" at index $_index');
  }

  TokenType tokenType() {
    if (_currentType == null) {
      throw StateError('No current token. Did you call advance()?');
    }
    return _currentType!;
  }

  String token() {
    if (_currentToken == null) {
      throw StateError('No current token. Did you call advance()?');
    }
    return _currentToken!;
  }

  int _skipWhitespaceAndComments(int startIndex) {
    int i = startIndex;

    while (i < _input.length) {
      if (_isWhitespace(_input[i])) {
        i++;
        continue;
      }

      if (_startsWithAt(i, '//')) {
        i += 2;
        while (i < _input.length && _input[i] != '\n') {
          i++;
        }
        continue;
      }

      if (_startsWithAt(i, '/*')) {
        i += 2;
        while (i + 1 < _input.length && !_startsWithAt(i, '*/')) {
          i++;
        }

        if (i + 1 >= _input.length) {
          throw FormatException('Unterminated block comment');
        }

        i += 2;
        continue;
      }

      break;
    }

    return i;
  }

  void _readStringConstant() {
    _index++; // skip opening "
    final start = _index;

    while (_index < _input.length && _input[_index] != '"') {
      if (_input[_index] == '\n' || _input[_index] == '\r') {
        throw FormatException('String constant cannot contain a newline');
      }
      _index++;
    }

    if (_index >= _input.length) {
      throw FormatException('Unterminated string constant');
    }

    _currentToken = _input.substring(start, _index);
    _currentType = TokenType.stringConstant;

    _index++; // skip closing "
  }

  void _readIntegerConstant() {
    final start = _index;

    while (_index < _input.length && _isDigit(_input[_index])) {
      _index++;
    }

    final value = _input.substring(start, _index);
    final number = int.parse(value);

    if (number < 0 || number > 32767) {
      throw FormatException(
        'Integer constant out of range (0..32767): $value',
      );
    }

    _currentToken = value;
    _currentType = TokenType.integerConstant;
  }

  void _readIdentifierOrKeyword() {
    final start = _index;

    while (_index < _input.length && _isIdentifierPart(_input[_index])) {
      _index++;
    }

    final value = _input.substring(start, _index);

    _currentToken = value;
    _currentType =
        keywords.contains(value) ? TokenType.keyword : TokenType.identifier;
  }

  bool _startsWithAt(int index, String pattern) {
    if (index + pattern.length > _input.length) {
      return false;
    }
    return _input.substring(index, index + pattern.length) == pattern;
  }

  bool _isWhitespace(String ch) {
    return ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t';
  }

  bool _isSymbol(String ch) {
    return symbols.contains(ch);
  }

  bool _isDigit(String ch) {
    final code = ch.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  bool _isLetter(String ch) {
    final code = ch.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  bool _isIdentifierStart(String ch) {
    return _isLetter(ch) || ch == '_';
  }

  bool _isIdentifierPart(String ch) {
    return _isLetter(ch) || _isDigit(ch) || ch == '_';
  }
}

void tokenizeFile(File inputFile, File outputFile) {
  final content = inputFile.readAsStringSync();
  final tokenizer = JackTokenizer(content);
  final buffer = StringBuffer();

  buffer.writeln('<tokens>');

  while (tokenizer.hasMoreTokens()) {
    tokenizer.advance();

    final type = tokenizer.tokenType();
    final token = tokenizer.token();
    final tag = _tagName(type);
    final escapedToken = _escapeXml(token);

    buffer.writeln('<$tag> $escapedToken </$tag>');
  }

  buffer.writeln('</tokens>');
  outputFile.writeAsStringSync(buffer.toString());
}

String _tagName(TokenType type) {
  switch (type) {
    case TokenType.keyword:
      return 'keyword';
    case TokenType.symbol:
      return 'symbol';
    case TokenType.identifier:
      return 'identifier';
    case TokenType.integerConstant:
      return 'integerConstant';
    case TokenType.stringConstant:
      return 'stringConstant';
  }
}

String _escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
