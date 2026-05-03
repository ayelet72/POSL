part of 'code_writer.dart';

// prevent crossing names between labels in different functions
String scopedLabel(String label) {
  if (currentFunctionName.isEmpty) {
    return label;
  }
  return '$currentFunctionName\$$label';
}

/// label X
/// => create a label in assembly
void writeLabel(String label, File outputFile) {
  final fullLabel = scopedLabel(label);

  writeLines(outputFile, [
    '($fullLabel)',
  ]);
}

/// goto X
/// => jump to label X
void writeGoto(String label, File outputFile) {
  final fullLabel = scopedLabel(label);

  writeLines(outputFile, [
    '@$fullLabel',
    '0;JMP',
  ]);
}

/// if-goto X
/// => pop top stack value
/// => if value != 0 jump to label X
void writeIf(String label, File outputFile) {
  final fullLabel = scopedLabel(label);

  writeLines(outputFile, [
    '@SP',
    'AM=M-1',
    'D=M',
    '@$fullLabel',
    'D;JNE',
  ]);
}