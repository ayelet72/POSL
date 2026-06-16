enum Kind { staticVar, field, argument, local, none }

class Symbol {
  final String type;
  final Kind kind;
  final int index;

  Symbol(this.type, this.kind, this.index);
}

class SymbolTable {
  final Map<String, Symbol> _classScope = {};
  final Map<String, Symbol> _subroutineScope = {};

  int _staticCount = 0;
  int _fieldCount = 0;
  int _argumentCount = 0;
  int _localCount = 0;

  void startSubroutine() {
    _subroutineScope.clear();

    _argumentCount = 0;
    _localCount = 0;
  }

  void define(String name, String type, Kind kind) {
    int index;

    switch (kind) {
      case Kind.staticVar:
        index = _staticCount++;
        _classScope[name] = Symbol(type, kind, index);
        break;

      case Kind.field:
        index = _fieldCount++;
        _classScope[name] = Symbol(type, kind, index);
        break;

      case Kind.argument:
        index = _argumentCount++;
        _subroutineScope[name] = Symbol(type, kind, index);
        break;

      case Kind.local:
        index = _localCount++;
        _subroutineScope[name] = Symbol(type, kind, index);
        break;

      case Kind.none:
        return;
    }
  }

  int varCount(Kind kind) {
    switch (kind) {
      case Kind.staticVar:
        return _staticCount;

      case Kind.field:
        return _fieldCount;

      case Kind.argument:
        return _argumentCount;

      case Kind.local:
        return _localCount;

      case Kind.none:
        return 0;
    }
  }

  Kind kindOf(String name) {
    if (_subroutineScope.containsKey(name)) {
      return _subroutineScope[name]!.kind;
    }

    if (_classScope.containsKey(name)) {
      return _classScope[name]!.kind;
    }

    return Kind.none;
  }

  String? typeOf(String name) {
    if (_subroutineScope.containsKey(name)) {
      return _subroutineScope[name]!.type;
    }

    if (_classScope.containsKey(name)) {
      return _classScope[name]!.type;
    }

    return null;
  }

  int? indexOf(String name) {
    if (_subroutineScope.containsKey(name)) {
      return _subroutineScope[name]!.index;
    }

    if (_classScope.containsKey(name)) {
      return _classScope[name]!.index;
    }

    return null;
  }

  bool contains(String name) {
    return _subroutineScope.containsKey(name) || _classScope.containsKey(name);
  }
}
