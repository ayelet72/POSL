import 'dart:io';

/// Unique counter for comparison labels.
int labelCounter = 0;

/// Unique counter for return labels.
int callCounter = 0;

/// Name of the current function.
String currentFunctionName = '';

/// Name of the current VM file.
String currentFileName = '';

/// write all lines into the output file
void writeLines(File outputFile, List<String> lines) {
  for (final line in lines) {
    outputFile.writeAsStringSync('$line\n', mode: FileMode.append);
  }
}

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

/// remove comments and extra spaces
String cleanLine(String line) {
  if (line.contains('//')) {
    line = line.split('//')[0];
  }
  return line.trim();
}

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

    // Reposition LCL = SP
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

/// translate one cleaned VM command into Hack assembly
void translateCommand(String line, File outputFile) {
  final parts = line.split(RegExp(r'\s+'));

  if (parts.isEmpty) {
    return;
  }

  final command = parts[0];

  switch (command) {
    case 'push':
      final segment = parts[1];
      final index = int.parse(parts[2]);

      if (segment == 'constant') {
        writePushConstant(index, outputFile);
      } else {
        writePushSegment(segment, index, outputFile);
      }
      break;

    case 'pop':
      final segment = parts[1];
      final index = int.parse(parts[2]);
      writePopSegment(segment, index, outputFile);
      break;

    case 'add':
      writeBinaryCommand('M=M+D', outputFile);
      break;

    case 'sub':
      writeBinaryCommand('M=M-D', outputFile);
      break;

    case 'and':
      writeBinaryCommand('M=M&D', outputFile);
      break;

    case 'or':
      writeBinaryCommand('M=M|D', outputFile);
      break;

    case 'neg':
      writeUnaryCommand('M=-M', outputFile);
      break;

    case 'not':
      writeUnaryCommand('M=!M', outputFile);
      break;

    case 'eq':
      writeComparison('JEQ', outputFile);
      break;

    case 'gt':
      writeComparison('JGT', outputFile);
      break;

    case 'lt':
      writeComparison('JLT', outputFile);
      break;

    case 'label':
      writeLabel(parts[1], outputFile);
      break;

    case 'goto':
      writeGoto(parts[1], outputFile);
      break;

    case 'if-goto':
      writeIf(parts[1], outputFile);
      break;

    case 'function':
      final functionName = parts[1];
      final nVars = int.parse(parts[2]);
      writeFunction(functionName, nVars, outputFile);
      break;

    case 'call':
      final functionName = parts[1];
      final nArgs = int.parse(parts[2]);
      writeCall(functionName, nArgs, outputFile);
      break;

    case 'return':
      writeReturn(outputFile);
      break;

    default:
      throw UnsupportedError('Unsupported VM command: $line');
  }
}

/// translate one VM file into the output file
void translateSingleFile(File inputFile, File outputFile) {
  currentFileName = inputFile.uri.pathSegments.last.replaceAll('.vm', '');

  final lines = inputFile.readAsLinesSync();

  for (final rawLine in lines) {
    final line = cleanLine(rawLine);

    if (line.isEmpty) {
      continue;
    }

    translateCommand(line, outputFile);
  }
}

/// return all .vm files inside a directory
List<File> getVmFiles(Directory dir) {
  final vmFiles = dir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.vm'))
      .toList();

  vmFiles.sort((a, b) => a.path.compareTo(b.path));
  return vmFiles;
}

/// translate one file or a whole folder
void translatePath(String inputPath) {
  final type = FileSystemEntity.typeSync(inputPath);

  if (type == FileSystemEntityType.file) {
    final inputFile = File(inputPath);

    final outputPath =
        inputFile.path.replaceAll(RegExp(r'\.vm$'), '.asm');
    final outputFile = File(outputPath);

    // clear old output
    outputFile.writeAsStringSync('');

    translateSingleFile(inputFile, outputFile);

    print('Translation completed: $outputPath');
    return;
  }

  if (type == FileSystemEntityType.directory) {
    final dir = Directory(inputPath);
    final vmFiles = getVmFiles(dir);

    if (vmFiles.isEmpty) {
      print('No .vm files found in directory.');
      return;
    }

    final folderName =
        dir.uri.pathSegments.where((s) => s.isNotEmpty).last;

    final outputPath =
        '${dir.path}${Platform.pathSeparator}$folderName.asm';
    final outputFile = File(outputPath);

    // clear old output
    outputFile.writeAsStringSync('');

    // if there are multiple VM files => write bootstrap
    if (vmFiles.length > 1) {
      writeInit(outputFile);
    }

    for (final vmFile in vmFiles) {
      translateSingleFile(vmFile, outputFile);
    }

    print('Translation completed: $outputPath');
    return;
  }

  print('Invalid input path.');
}

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run main.dart <input .vm file or folder>');
    return;
  }

  translatePath(args[0]);
}