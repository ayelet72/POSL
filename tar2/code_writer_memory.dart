part of 'code_writer.dart';

// push local i / argument i / this i / that i
// => read RAM[base + i]
// => push this element to the stack
//
// push temp i
// => read RAM[5 + i]
// => push it to the stack
//
// push pointer 0/1
// => push THIS / THAT
//
// push static i
// => push FileName.i
void writePushSegment(String segment, int index, File outputFile) {
  final bases = {
    'local': 'LCL',
    'argument': 'ARG',
    'this': 'THIS',
    'that': 'THAT',
  };

  if (bases.containsKey(segment)) {
    String base = bases[segment]!;

    writeLines(outputFile, [
      '@$base',
      'D=M',
      '@$index',
      'A=D+A',
      'D=M',
      '@SP',
      'A=M',
      'M=D',
      '@SP',
      'M=M+1',
    ]);
    return;
  }

  if (segment == 'temp') {
    final address = 5 + index;

    writeLines(outputFile, [
      '@$address',
      'D=M',
      '@SP',
      'A=M',
      'M=D',
      '@SP',
      'M=M+1',
    ]);
    return;
  }

  if (segment == 'pointer') {
    if (index != 0 && index != 1) {
      throw UnsupportedError('pointer index must be 0 or 1');
    }

    final pointerName = (index == 0) ? 'THIS' : 'THAT';

    writeLines(outputFile, [
      '@$pointerName',
      'D=M',
      '@SP',
      'A=M',
      'M=D',
      '@SP',
      'M=M+1',
    ]);
    return;
  }

  if (segment == 'static') {
    final staticName = '$currentFileName.$index';

    writeLines(outputFile, [
      '@$staticName',
      'D=M',
      '@SP',
      'A=M',
      'M=D',
      '@SP',
      'M=M+1',
    ]);
    return;
  }

  throw UnsupportedError('Unsupported segment: $segment');
}

// pop local i / argument i / this i / that i
// => pop from stack
// => save into RAM[base + i]
//
// pop temp i
// => pop from stack
// => save into RAM[5 + i]
//
// pop pointer 0/1
// => pop from stack
// => save into THIS / THAT
//
// pop static i
// => pop from stack
// => save into FileName.i
void writePopSegment(String segment, int index, File outputFile) {
  final bases = {
    'local': 'LCL',
    'argument': 'ARG',
    'this': 'THIS',
    'that': 'THAT',
  };

  if (bases.containsKey(segment)) {
    String base = bases[segment]!;

    writeLines(outputFile, [
      '@$base',
      'D=M',
      '@$index',
      'D=D+A',
      '@R13',
      'M=D',
      '@SP',
      'AM=M-1',
      'D=M',
      '@R13',
      'A=M',
      'M=D',
    ]);
    return;
  }

  if (segment == 'temp') {
    final address = 5 + index;

    writeLines(outputFile, [
      '@SP',
      'AM=M-1',
      'D=M',
      '@$address',
      'M=D',
    ]);
    return;
  }

  if (segment == 'pointer') {
    if (index != 0 && index != 1) {
      throw UnsupportedError('pointer index must be 0 or 1');
    }

    final pointerName = (index == 0) ? 'THIS' : 'THAT';

    writeLines(outputFile, [
      '@SP',
      'AM=M-1',
      'D=M',
      '@$pointerName',
      'M=D',
    ]);
    return;
  }

  if (segment == 'static') {
    final staticName = '$currentFileName.$index';

    writeLines(outputFile, [
      '@SP',
      'AM=M-1',
      'D=M',
      '@$staticName',
      'M=D',
    ]);
    return;
  }

  throw UnsupportedError('Unsupported segment: $segment');
}