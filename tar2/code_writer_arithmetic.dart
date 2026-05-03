part of 'code_writer.dart';

/// push constant x
/// => put x on the stack
void writePushConstant(int value, File outputFile) {
  writeLines(outputFile, [
    '@$value',
    'D=A',
    '@SP',
    'A=M',
    'M=D',
    '@SP',
    'M=M+1',
  ]);
}

/// add / sub / and / or
/// => take the top 2 stack values and apply the operation
void writeBinaryCommand(String op, File outputFile) {
  writeLines(outputFile, [
    '@SP',
    'AM=M-1',
    'D=M',
    'A=A-1',
    op,
  ]);
}

/// neg / not
/// => apply unary operation on the top stack value
void writeUnaryCommand(String op, File outputFile) {
  writeLines(outputFile, [
    '@SP',
    'A=M-1',
    op,
  ]);
}

/// eq / gt / lt
/// => compare the top 2 stack values
/// => push true (-1) or false (0)
void writeComparison(String jumpType, File outputFile) {
  final trueLabel = 'TRUE_$labelCounter';
  final endLabel = 'END_$labelCounter';
  labelCounter++;

  writeLines(outputFile, [
    '@SP',
    'AM=M-1',
    'D=M',
    'A=A-1',
    'D=M-D',
    '@$trueLabel',
    'D;$jumpType',
    '@SP',
    'A=M-1',
    'M=0',
    '@$endLabel',
    '0;JMP',
    '($trueLabel)',
    '@SP',
    'A=M-1',
    'M=-1',
    '($endLabel)',
  ]);
}