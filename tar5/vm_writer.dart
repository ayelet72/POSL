import 'dart:io';

class VMWriter {
  final StringBuffer _buffer = StringBuffer();

  void writePush(String segment, int index) {
    _buffer.writeln('push $segment $index');
  }

  void writePop(String segment, int index) {
    _buffer.writeln('pop $segment $index');
  }

  void writeArithmetic(String command) {
    _buffer.writeln(command);
  }

  void writeLabel(String label) {
    _buffer.writeln('label $label');
  }

  void writeGoto(String label) {
    _buffer.writeln('goto $label');
  }

  void writeIf(String label) {
    _buffer.writeln('if-goto $label');
  }

  void writeCall(String name, int nArgs) {
    _buffer.writeln('call $name $nArgs');
  }

  void writeFunction(String name, int nLocals) {
    _buffer.writeln('function $name $nLocals');
  }

  void writeReturn() {
    _buffer.writeln('return');
  }

  void writeRaw(String text) {
    _buffer.writeln(text);
  }

  String output() {
    return _buffer.toString();
  }

  void saveToFile(File file) {
    file.writeAsStringSync(_buffer.toString());
  }
}
