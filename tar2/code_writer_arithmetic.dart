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
    // SP--, A = top stack cell, D = y
    '@SP',
    'AM=M-1',
    'D=M',
    // move to x, then D = x - y
    'A=A-1',
    'D=M-D',
    // if condition is true => jump to TRUE label
    '@$trueLabel',
    'D;$jumpType',
    // false case => write 0 on the stack
    '@SP',
    'A=M-1',
    'M=0',
    // skip the true case
    '@$endLabel',
    '0;JMP',
    // true case => write -1 on the stack
    '($trueLabel)',
    '@SP',
    'A=M-1',
    'M=-1',
    // end of comparison
    '($endLabel)',
  ]);
}