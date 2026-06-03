import 'dart:io';

//thats how the token looks like
class TokenData {
  final String type;
  final String value;

  TokenData(this.type, this.value);
}

void parseTokenFile(File tokenFile, File outputFile) {
  final tokens = _readTokensFromXml(tokenFile);
  final engine = CompilationEngine(tokens);

  engine.compileClass();

  outputFile.writeAsStringSync(engine.getOutput());
}

List<TokenData> _readTokensFromXml(File tokenFile) {
  final lines = tokenFile.readAsLinesSync();
  final tokens = <TokenData>[];

  final tokenRegex = RegExp(r'^<([^>]+)>\s(.*)\s</\1>$');

  for (final rawLine in lines) {
    final line = rawLine.trim();

    if (line.isEmpty || line == '<tokens>' || line == '</tokens>') {
      continue;
    }

    final match = tokenRegex.firstMatch(line);
    if (match == null) {
      continue;
    }

    final type = match.group(1)!;
    final value = match.group(2)!;

    tokens.add(TokenData(type, value));
  }

  return tokens;
}

class CompilationEngine {
  final List<TokenData> tokens;
  final StringBuffer _buffer = StringBuffer();

  int _index = 0;
  int _indentLevel = 0;

  CompilationEngine(this.tokens);

  String getOutput() => _buffer.toString();

  void compileClass() {
    _openTag('class');

    _process('class');
    _writeAndAdvance(); // className
    _process('{');

    while (_currentValue() == 'static' || _currentValue() == 'field') {
      compileClassVarDec();
    }

    while (_currentValue() == 'constructor' ||
        _currentValue() == 'function' ||
        _currentValue() == 'method') {
      compileSubroutine();
    }

    _process('}');
    _closeTag('class');
  }

  void compileClassVarDec() {
    _openTag('classVarDec');

    _writeAndAdvance(); // static | field
    _writeAndAdvance(); // type
    _writeAndAdvance(); // varName

    while (_currentValue() == ',') {
      _process(',');
      _writeAndAdvance(); // varName
    }

    _process(';');
    _closeTag('classVarDec');
  }

  void compileSubroutine() {
    _openTag('subroutineDec');

    _writeAndAdvance(); // constructor | function | method
    _writeAndAdvance(); // void | type
    _writeAndAdvance(); // subroutineName
    _process('(');

    compileParameterList();

    _process(')');
    compileSubroutineBody();

    _closeTag('subroutineDec');
  }

  void compileParameterList() {
    _openTag('parameterList');

    if (_currentValue() != ')') {
      _writeAndAdvance(); // type
      _writeAndAdvance(); // varName

      while (_currentValue() == ',') {
        _process(',');
        _writeAndAdvance(); // type
        _writeAndAdvance(); // varName
      }
    }

    _closeTag('parameterList');
  }

  void compileSubroutineBody() {
    _openTag('subroutineBody');

    _process('{');

    while (_currentValue() == 'var') {
      compileVarDec();
    }

    compileStatements();

    _process('}');
    _closeTag('subroutineBody');
  }

  void compileVarDec() {
    _openTag('varDec');

    _process('var');
    _writeAndAdvance(); // type
    _writeAndAdvance(); // varName

    while (_currentValue() == ',') {
      _process(',');
      _writeAndAdvance(); // varName
    }

    _process(';');
    _closeTag('varDec');
  }

  void compileStatements() {
    _openTag('statements');

    while (true) {
      final value = _currentValue();

      if (value == 'let') {
        compileLet();
      } else if (value == 'if') {
        compileIf();
      } else if (value == 'while') {
        compileWhile();
      } else if (value == 'do') {
        compileDo();
      } else if (value == 'return') {
        compileReturn();
      } else {
        break;
      }
    }

    _closeTag('statements');
  }

  void compileLet() {
    _openTag('letStatement');

    _process('let');
    _writeAndAdvance(); // varName

    if (_currentValue() == '[') {
      _process('[');
      compileExpression();
      _process(']');
    }

    _process('=');
    compileExpression();
    _process(';');

    _closeTag('letStatement');
  }

  void compileIf() {
    _openTag('ifStatement');

    _process('if');
    _process('(');
    compileExpression();
    _process(')');
    _process('{');
    compileStatements();
    _process('}');

    if (_currentValue() == 'else') {
      _process('else');
      _process('{');
      compileStatements();
      _process('}');
    }

    _closeTag('ifStatement');
  }

  void compileWhile() {
    _openTag('whileStatement');

    _process('while');
    _process('(');
    compileExpression();
    _process(')');
    _process('{');
    compileStatements();
    _process('}');

    _closeTag('whileStatement');
  }

  void compileDo() {
    _openTag('doStatement');

    _process('do');
    _compileSubroutineCall();
    _process(';');

    _closeTag('doStatement');
  }

  void compileReturn() {
    _openTag('returnStatement');

    _process('return');

    if (_currentValue() != ';') {
      compileExpression();
    }

    _process(';');

    _closeTag('returnStatement');
  }

  void compileExpression() {
    _openTag('expression');

    compileTerm();

    while (_isOp(_currentValue())) {
      _writeAndAdvance(); // op
      compileTerm();
    }

    _closeTag('expression');
  }

  void compileTerm() {
    _openTag('term');

    final current = _currentValue();
    final next = _peekValue();

    if (current == '(') {
      _process('(');
      compileExpression();
      _process(')');
    } else if (current == '-' || current == '~') {
      _writeAndAdvance(); // unaryOp
      compileTerm();
    } else if (_isKeywordConstant(current)) {
      _writeAndAdvance();
    } else if (_currentType() == 'integerConstant' ||
        _currentType() == 'stringConstant') {
      _writeAndAdvance();
    } else if (_currentType() == 'identifier') {
      if (next == '[') {
        _writeAndAdvance(); // varName
        _process('[');
        compileExpression();
        _process(']');
      } else if (next == '(' || next == '.') {
        _compileSubroutineCall();
      } else {
        _writeAndAdvance(); // varName
      }
    } else {
      throw StateError('Unexpected term: ${_currentValue()}');
    }

    _closeTag('term');
  }

  void compileExpressionList() {
    _openTag('expressionList');

    if (_currentValue() != ')') {
      compileExpression();

      while (_currentValue() == ',') {
        _process(',');
        compileExpression();
      }
    }

    _closeTag('expressionList');
  }

  void _compileSubroutineCall() {
    _writeAndAdvance(); // subroutineName | className | varName

    if (_currentValue() == '.') {
      _process('.');
      _writeAndAdvance(); // subroutineName
    }

    _process('(');
    compileExpressionList();
    _process(')');
  }

  bool _isKeywordConstant(String value) {
    return value == 'true' ||
        value == 'false' ||
        value == 'null' ||
        value == 'this';
  }

  bool _isOp(String value) {
    return value == '+' ||
        value == '-' ||
        value == '*' ||
        value == '/' ||
        value == '&amp;' ||
        value == '|' ||
        value == '&lt;' ||
        value == '&gt;' ||
        value == '=';
  }

  void _process(String expectedValue) {
    if (_currentValue() != expectedValue) {
      throw StateError(
        'Expected "$expectedValue" but found "${_currentValue()}" at token index $_index',
      );
    }

    _writeAndAdvance();
  }

  void _writeAndAdvance() {
    final token = tokens[_index];
    _writeLine('<${token.type}> ${token.value} </${token.type}>');
    _index++;
  }

  String _currentValue() {
    if (_index >= tokens.length) {
      return '';
    }
    return tokens[_index].value;
  }

  String _currentType() {
    if (_index >= tokens.length) {
      return '';
    }
    return tokens[_index].type;
  }

  String _peekValue() {
    if (_index + 1 >= tokens.length) {
      return '';
    }
    return tokens[_index + 1].value;
  }

  void _openTag(String tag) {
    _writeLine('<$tag>');
    _indentLevel++;
  }

  void _closeTag(String tag) {
    _indentLevel--;
    _writeLine('</$tag>');
  }

  void _writeLine(String line) {
    _buffer.writeln('${'  ' * _indentLevel}$line');
  }
}
