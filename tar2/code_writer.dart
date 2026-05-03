import 'dart:io';

part 'code_writer_arithmetic.dart';
part 'code_writer_branching.dart';
part 'code_writer_functions.dart';
part 'code_writer_memory.dart';

int labelCounter = 0;
int callCounter = 0;
String currentFunctionName = '';
String currentFileName = '';

void writeLines(File outputFile, List<String> lines) {
  for (final line in lines) {
    outputFile.writeAsStringSync('$line\n', mode: FileMode.append);
  }
}