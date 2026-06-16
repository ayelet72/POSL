import 'dart:io';
import 'symbol_table.dart';
import 'vm_writer.dart';

// Reads tokens from the T.xml file produced by the tokenizer
class TokenData {
  final String type;
  final String value;

  TokenData(this.type, this.value);
}

void compileFile(File tokenFile, File outputFile) {
  final tokens = _readTokensFromXml(tokenFile);
  final engine = CompilationEngine(tokens);

  engine.compileClass();

  outputFile.writeAsStringSync(engine.getOutput());
}

// Keep old name as alias so driver.dart doesn't break
void parseTokenFile(File tokenFile, File outputFile) =>
    compileFile(tokenFile, outputFile);

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
    if (match == null) continue;

    final type = match.group(1)!;
    var value = match.group(2)!;

    // Unescape XML entities back to real characters
    value = value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    tokens.add(TokenData(type, value));
  }

  return tokens;
}

// ---------------------------------------------------------------------------

class CompilationEngine {
  final List<TokenData> _tokens;
  final SymbolTable _symbolTable = SymbolTable();
  final VMWriter _vm = VMWriter();

  int _index = 0;
  int _labelCounter = 0;

  String _className = '';
  String _subroutineName = '';
  String _subroutineKind = ''; // 'constructor' | 'function' | 'method'

  CompilationEngine(this._tokens);

  String getOutput() => _vm.output();

  // -------------------------------------------------------------------------
  // Label helper
  // -------------------------------------------------------------------------

  String _newLabel(String base) => '${_className}_${base}_${_labelCounter++}';

  // -------------------------------------------------------------------------
  // compileClass
  // -------------------------------------------------------------------------

  void compileClass() {
    _eat('class');
    _className = _currentValue();
    _advance(); // className
    _eat('{');

    while (_currentValue() == 'static' || _currentValue() == 'field') {
      compileClassVarDec();
    }

    while (_currentValue() == 'constructor' ||
        _currentValue() == 'function' ||
        _currentValue() == 'method') {
      compileSubroutine();
    }

    _eat('}');
  }

  // -------------------------------------------------------------------------
  // compileClassVarDec  — only updates symbol table, emits nothing
  // -------------------------------------------------------------------------

  void compileClassVarDec() {
    final kindToken = _currentValue(); // 'static' | 'field'
    _advance();

    final kind = kindToken == 'static' ? Kind.staticVar : Kind.field;
    final type = _currentValue();
    _advance(); // type

    // first variable name
    _symbolTable.define(_currentValue(), type, kind);
    _advance();

    while (_currentValue() == ',') {
      _advance(); // ','
      _symbolTable.define(_currentValue(), type, kind);
      _advance();
    }

    _eat(';');
  }

  // -------------------------------------------------------------------------
  // compileSubroutine
  // -------------------------------------------------------------------------

  void compileSubroutine() {
    _subroutineKind = _currentValue(); // constructor | function | method
    _advance();

    _advance(); // void | type (return type – ignored for code gen)

    _subroutineName = _currentValue();
    _advance(); // subroutineName

    // Reset subroutine-level scope
    _symbolTable.startSubroutine();

    // For methods, 'this' is argument 0
    if (_subroutineKind == 'method') {
      _symbolTable.define('this', _className, Kind.argument);
    }

    _eat('(');
    compileParameterList();
    _eat(')');

    compileSubroutineBody();
  }

  // -------------------------------------------------------------------------
  // compileParameterList
  // -------------------------------------------------------------------------

  void compileParameterList() {
    if (_currentValue() == ')') return;

    final type = _currentValue();
    _advance();
    _symbolTable.define(_currentValue(), type, Kind.argument);
    _advance();

    while (_currentValue() == ',') {
      _advance(); // ','
      final t = _currentValue();
      _advance();
      _symbolTable.define(_currentValue(), t, Kind.argument);
      _advance();
    }
  }

  // -------------------------------------------------------------------------
  // compileSubroutineBody
  // -------------------------------------------------------------------------

  void compileSubroutineBody() {
    _eat('{');

    // Collect all var declarations first (we need nLocals for function decl)
    while (_currentValue() == 'var') {
      compileVarDec();
    }

    final nLocals = _symbolTable.varCount(Kind.local);
    _vm.writeFunction('$_className.$_subroutineName', nLocals);

    // --- Subroutine-kind preamble ---
    if (_subroutineKind == 'constructor') {
      // Allocate memory for the object fields
      final nFields = _symbolTable.varCount(Kind.field);
      _vm.writePush('constant', nFields);
      _vm.writeCall('Memory.alloc', 1);
      _vm.writePop('pointer', 0); // anchor THIS
    } else if (_subroutineKind == 'method') {
      // argument 0 is 'this'
      _vm.writePush('argument', 0);
      _vm.writePop('pointer', 0); // anchor THIS
    }
    // function: nothing extra

    compileStatements();

    _eat('}');
  }

  // -------------------------------------------------------------------------
  // compileVarDec
  // -------------------------------------------------------------------------

  void compileVarDec() {
    _eat('var');

    final type = _currentValue();
    _advance(); // type

    _symbolTable.define(_currentValue(), type, Kind.local);
    _advance(); // varName

    while (_currentValue() == ',') {
      _advance(); // ','
      _symbolTable.define(_currentValue(), type, Kind.local);
      _advance();
    }

    _eat(';');
  }

  // -------------------------------------------------------------------------
  // compileStatements
  // -------------------------------------------------------------------------

  void compileStatements() {
    while (true) {
      switch (_currentValue()) {
        case 'let':
          compileLet();
        case 'if':
          compileIf();
        case 'while':
          compileWhile();
        case 'do':
          compileDo();
        case 'return':
          compileReturn();
        default:
          return;
      }
    }
  }

  // -------------------------------------------------------------------------
  // compileLet
  // -------------------------------------------------------------------------

  void compileLet() {
    _eat('let');

    final varName = _currentValue();
    _advance(); // varName

    final isArray = _currentValue() == '[';

    if (isArray) {
      // Push base address of array
      _pushVariable(varName);
      _eat('[');
      compileExpression(); // index
      _eat(']');
      _vm.writeArithmetic('add'); // base + index → address on stack
    }

    _eat('=');
    compileExpression(); // RHS value
    _eat(';');

    if (isArray) {
      // Stack: ..., address, value
      // We need to store value at address.
      // Technique: pop value to temp 0, set THAT to address, pop into that 0
      _vm.writePop('temp', 0); // save value
      _vm.writePop('pointer', 1); // THAT = address
      _vm.writePush('temp', 0); // restore value
      _vm.writePop('that', 0); // RAM[THAT] = value
    } else {
      _popVariable(varName);
    }
  }

  // -------------------------------------------------------------------------
  // compileIf
  // -------------------------------------------------------------------------

  void compileIf() {
    final labelTrue = _newLabel('IF_TRUE');
    final labelFalse = _newLabel('IF_FALSE');
    final labelEnd = _newLabel('IF_END');

    _eat('if');
    _eat('(');
    compileExpression();
    _eat(')');

    _vm.writeIf(labelTrue); // if-goto TRUE
    _vm.writeGoto(labelFalse); // goto FALSE

    _vm.writeLabel(labelTrue);
    _eat('{');
    compileStatements();
    _eat('}');

    if (_currentValue() == 'else') {
      _vm.writeGoto(labelEnd);
      _vm.writeLabel(labelFalse);
      _advance(); // 'else'
      _eat('{');
      compileStatements();
      _eat('}');
      _vm.writeLabel(labelEnd);
    } else {
      _vm.writeLabel(labelFalse);
    }
  }

  // -------------------------------------------------------------------------
  // compileWhile
  // -------------------------------------------------------------------------

  void compileWhile() {
    final labelStart = _newLabel('WHILE_START');
    final labelEnd = _newLabel('WHILE_END');

    _vm.writeLabel(labelStart);

    _eat('while');
    _eat('(');
    compileExpression();
    _eat(')');

    _vm.writeArithmetic('not');
    _vm.writeIf(labelEnd);

    _eat('{');
    compileStatements();
    _eat('}');

    _vm.writeGoto(labelStart);
    _vm.writeLabel(labelEnd);
  }

  // -------------------------------------------------------------------------
  // compileDo
  // -------------------------------------------------------------------------

  void compileDo() {
    _eat('do');
    _compileSubroutineCall();
    _eat(';');

    // do statement discards the return value
    _vm.writePop('temp', 0);
  }

  // -------------------------------------------------------------------------
  // compileReturn
  // -------------------------------------------------------------------------

  void compileReturn() {
    _eat('return');

    if (_currentValue() != ';') {
      compileExpression();
    } else {
      // void method — push dummy 0
      _vm.writePush('constant', 0);
    }

    _eat(';');
    _vm.writeReturn();
  }

  // -------------------------------------------------------------------------
  // compileExpression
  // -------------------------------------------------------------------------

  void compileExpression() {
    compileTerm();

    while (_isOp(_currentValue())) {
      final op = _currentValue();
      _advance();
      compileTerm();
      _emitOp(op);
    }
  }

  // -------------------------------------------------------------------------
  // compileTerm
  // -------------------------------------------------------------------------

  void compileTerm() {
    final current = _currentValue();
    final currentType = _currentType();
    final next = _peekValue();

    if (current == '(') {
      _advance(); // '('
      compileExpression();
      _eat(')');
      return;
    }

    if (current == '-' || current == '~') {
      _advance();
      compileTerm();
      _vm.writeArithmetic(current == '-' ? 'neg' : 'not');
      return;
    }

    if (currentType == 'integerConstant') {
      _vm.writePush('constant', int.parse(current));
      _advance();
      return;
    }

    if (currentType == 'stringConstant') {
      // Allocate string and append chars
      _vm.writePush('constant', current.length);
      _vm.writeCall('String.new', 1);
      for (final ch in current.codeUnits) {
        _vm.writePush('constant', ch);
        _vm.writeCall('String.appendChar', 2);
      }
      _advance();
      return;
    }

    if (currentType == 'keyword') {
      // true, false, null, this
      switch (current) {
        case 'true':
          _vm.writePush('constant', 0);
          _vm.writeArithmetic('not'); // -1
        case 'false':
        case 'null':
          _vm.writePush('constant', 0);
        case 'this':
          _vm.writePush('pointer', 0);
      }
      _advance();
      return;
    }

    // identifier — variable, array access, or subroutine call
    if (currentType == 'identifier') {
      if (next == '[') {
        // Array access: varName[expression]
        _pushVariable(current);
        _advance(); // varName
        _eat('[');
        compileExpression();
        _eat(']');
        _vm.writeArithmetic('add'); // base + index
        _vm.writePop('pointer', 1); // THAT = address
        _vm.writePush('that', 0); // value at RAM[THAT]
        return;
      }

      if (next == '(' || next == '.') {
        _compileSubroutineCall();
        return;
      }

      // Plain variable
      _pushVariable(current);
      _advance();
      return;
    }

    throw StateError(
      'Unexpected term: "$current" (type: $currentType) at index $_index',
    );
  }

  // -------------------------------------------------------------------------
  // compileExpressionList — returns number of expressions compiled
  // -------------------------------------------------------------------------

  int compileExpressionList() {
    if (_currentValue() == ')') return 0;

    compileExpression();
    var count = 1;

    while (_currentValue() == ',') {
      _advance(); // ','
      compileExpression();
      count++;
    }

    return count;
  }

  // -------------------------------------------------------------------------
  // _compileSubroutineCall
  //
  // Handles four cases:
  //   Func(...)           → method call on 'this'       → push pointer 0, call ClassName.Func n+1
  //   ClassName.Func(...) → static/constructor call     → call ClassName.Func n
  //   obj.Func(...)       → method call on object       → push obj,         call ObjClass.Func n+1
  // -------------------------------------------------------------------------

  void _compileSubroutineCall() {
    final firstName = _currentValue();
    _advance(); // subroutineName | className | varName

    if (_currentValue() == '.') {
      // obj.method(...)  OR  ClassName.function(...)
      _advance(); // '.'
      final methodName = _currentValue();
      _advance(); // subroutineName

      String callName;
      int extraArgs;

      if (_symbolTable.contains(firstName)) {
        // It's an object variable — method call
        final objType = _symbolTable.typeOf(firstName)!;
        _pushVariable(firstName); // push the object (becomes argument 0)
        callName = '$objType.$methodName';
        extraArgs = 1;
      } else {
        // It's a class name — function or constructor call
        callName = '$firstName.$methodName';
        extraArgs = 0;
      }

      _eat('(');
      final nArgs = compileExpressionList();
      _eat(')');

      _vm.writeCall(callName, nArgs + extraArgs);
    } else {
      // Func(...)  — unqualified call means it's a method on 'this'
      _vm.writePush('pointer', 0); // push this
      _eat('(');
      final nArgs = compileExpressionList();
      _eat(')');
      _vm.writeCall('$_className.$firstName', nArgs + 1);
    }
  }

  // -------------------------------------------------------------------------
  // VM helper: push a variable by looking it up in the symbol table
  // -------------------------------------------------------------------------

  void _pushVariable(String name) {
    final kind = _symbolTable.kindOf(name);
    final index = _symbolTable.indexOf(name) ?? 0;
    _vm.writePush(_kindToSegment(kind), index);
  }

  void _popVariable(String name) {
    final kind = _symbolTable.kindOf(name);
    final index = _symbolTable.indexOf(name) ?? 0;
    _vm.writePop(_kindToSegment(kind), index);
  }

  String _kindToSegment(Kind kind) {
    switch (kind) {
      case Kind.staticVar:
        return 'static';
      case Kind.field:
        return 'this';
      case Kind.argument:
        return 'argument';
      case Kind.local:
        return 'local';
      case Kind.none:
        throw StateError('Unknown variable');
    }
  }

  // -------------------------------------------------------------------------
  // Emit arithmetic / comparison operators
  // -------------------------------------------------------------------------

  void _emitOp(String op) {
    switch (op) {
      case '+':
        _vm.writeArithmetic('add');
      case '-':
        _vm.writeArithmetic('sub');
      case '*':
        _vm.writeCall('Math.multiply', 2);
      case '/':
        _vm.writeCall('Math.divide', 2);
      case '&':
        _vm.writeArithmetic('and');
      case '|':
        _vm.writeArithmetic('or');
      case '<':
        _vm.writeArithmetic('lt');
      case '>':
        _vm.writeArithmetic('gt');
      case '=':
        _vm.writeArithmetic('eq');
    }
  }

  bool _isOp(String value) =>
      const {'+', '-', '*', '/', '&', '|', '<', '>', '='}.contains(value);

  // -------------------------------------------------------------------------
  // Token helpers
  // -------------------------------------------------------------------------

  void _eat(String expected) {
    if (_currentValue() != expected) {
      throw StateError(
        'Expected "$expected" but got "${_currentValue()}" at token index $_index',
      );
    }
    _advance();
  }

  void _advance() {
    _index++;
  }

  String _currentValue() {
    if (_index >= _tokens.length) return '';
    return _tokens[_index].value;
  }

  String _currentType() {
    if (_index >= _tokens.length) return '';
    return _tokens[_index].type;
  }

  String _peekValue() {
    if (_index + 1 >= _tokens.length) return '';
    return _tokens[_index + 1].value;
  }
}
