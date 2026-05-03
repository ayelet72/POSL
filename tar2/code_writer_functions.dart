part of 'code_writer.dart';

/// function f k
/// => create function label
/// => initialize k local variables to 0
void writeFunction(String functionName, int nVars, File outputFile) {
  currentFunctionName = functionName;

  // the label of the func
  writeLines(outputFile, [
    '($functionName)',
  ]);

  // initialize locals to 0
  for (int i = 0; i < nVars; i++) {
    writePushConstant(0, outputFile);
  }
}

/// call f n
/// => save current frame
/// => reposition ARG and LCL
/// => jump to function
/// => create return label
void writeCall(String functionName, int nArgs, File outputFile) {
  final returnLabel = 'RETURN_$callCounter';
  callCounter++;

  writeLines(outputFile, [
    // Push return address
    '@$returnLabel',
    'D=A',
    '@SP',
    'A=M',
    'M=D',
    '@SP',
    'M=M+1',

    // Save caller frame
    '@LCL',
    'D=M',
    '@SP',
    'A=M',
    'M=D',
    '@SP',
    'M=M+1',

    '@ARG',
    'D=M',
    '@SP',
    'A=M',
    'M=D',
    '@SP',
    'M=M+1',

    '@THIS',
    'D=M',
    '@SP',
    'A=M',
    'M=D',
    '@SP',
    'M=M+1',

    '@THAT',
    'D=M',
    '@SP',
    'A=M',
    'M=D',
    '@SP',
    'M=M+1',

    // Reposition ARG = SP - 5 - nArgs
    '@SP',
    'D=M',
    '@5',
    'D=D-A',
    '@$nArgs',
    'D=D-A',
    '@ARG',
    'M=D',

    // LCL = SP
    '@SP',
    'D=M',
    '@LCL',
    'M=D',

    // Jump to called function
    '@$functionName',
    '0;JMP',

    // Return address label
    '($returnLabel)',
  ]);
}

/// return
/// => restore the caller frame
/// => put return value in *ARG
/// => jump back to return address
void writeReturn(File outputFile) {
  writeLines(outputFile, [
    // R13 = LCL
    '@LCL',
    'D=M',
    '@R13',
    'M=D',

    // R14 = *(FRAME - 5)
    '@5',
    'A=D-A',
    'D=M',
    '@R14',
    'M=D',

    // *ARG = pop()
    '@SP',
    'AM=M-1',
    'D=M',
    '@ARG',
    'A=M',
    'M=D',

    // SP = ARG + 1
    '@ARG',
    'D=M+1',
    '@SP',
    'M=D',

    // THAT = *(FRAME - 1)
    '@R13',
    'AM=M-1',
    'D=M',
    '@THAT',
    'M=D',

    // THIS = *(FRAME - 2)
    '@R13',
    'AM=M-1',
    'D=M',
    '@THIS',
    'M=D',

    // ARG = *(FRAME - 3)
    '@R13',
    'AM=M-1',
    'D=M',
    '@ARG',
    'M=D',

    // LCL = *(FRAME - 4)
    '@R13',
    'AM=M-1',
    'D=M',
    '@LCL',
    'M=D',

    // goto RET
    '@R14',
    'A=M',
    '0;JMP',
  ]);
}

/// bootstrap
/// => SP = 256
/// => call Sys.init
void writeInit(File outputFile) {
  // SP = 256
  writeLines(outputFile, [
    '@256',
    'D=A',
    '@SP',
    'M=D',
  ]);

  // Call Sys.init
  writeCall('Sys.init', 0, outputFile);
}