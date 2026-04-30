import 'dart:io';

/// Unique counter for comparison labels.
int labelCounter = 0;

/// Unique counter for return labels.
int callCounter = 0;

/// Name of the current function.
String currentFunctionName = '';

/// Name of the current VM file.
String currentFileName = '';

/// Writes multiple assembly lines to the output file.
void writeLines(File outputFile, List<String> lines) {
  for (final line in lines) {
    outputFile.writeAsStringSync('$line\n', mode: FileMode.append);
  }
}

/// push constant x
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

/// Translates binary commands:
/// add / sub / and / or
void writeBinaryCommand(String op, File outputFile) {
  writeLines(outputFile, ['@SP', 'AM=M-1', 'D=M', 'A=A-1', op]);
}

/// Translates unary commands:
/// neg / not
void writeUnaryCommand(String op, File outputFile) {
  writeLines(outputFile, ['@SP', 'A=M-1', op]);
}

/// Translates comparison commands:
/// eq / gt / lt
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

//fix: when there are 2 labels with the same name:
//prevent crosing names  - cannot happend in assembly
String scopedLabel(String label) {
  if (currentFunctionName.isEmpty) {
    return label;
  }
  return '$currentFunctionName\$$label';
}

void writeLabel(String label, File outputFile) {
  final fullLabel = scopedLabel(label);

  writeLines(outputFile, ['($fullLabel)']);
}

void writeGoto(String label, File outputFile) {
  final fullLabel = scopedLabel(label);

  writeLines(outputFile, ['@$fullLabel', '0;JMP']);
}

void writeIf(String label, File outputFile) {
  final fullLabel = scopedLabel(label);

  writeLines(outputFile, ['@SP', 'AM=M-1', 'D=M', '@$fullLabel', 'D;JNE']);
}

/// Removes comments and extra spaces from a VM line.
String cleanLine(String line) {
  if (line.contains('//')) {
    line = line.split('//')[0];
  }
  return line.trim();
}

/// Translates one cleaned VM command into Hack assembly.
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

/// Returns all .vm files inside a directory, sorted by file name.
List<File> getVmFiles(Directory dir) {
  final vmFiles = dir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.vm'))
      .toList();
  return vmFiles;
}

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

void writeInit(File outputFile) {
  // SP = 256
  writeLines(outputFile, ['@256', 'D=A', '@SP', 'M=D']);

  // Call Sys.init
  writeCall('Sys.init', 0, outputFile);
}

// func in vm : function funcName  k-number of local variables
void writeFunction(String functionName, int nVars, File outputFile) {
  currentFunctionName = functionName;

  // the label of the func
  writeLines(outputFile, ['($functionName)']);

  // initialize locals to 0
  for (int i = 0; i < nVars; i++) {
    writePushConstant(0, outputFile);
  }
}

// push argument i  => argument i = RAM[LCL|ARG + 2]
///=> push this element to the stack
void writePushSegment(String segment, int index, File outputFile) {
  String base;

  if (segment == 'local') {
    base = 'LCL';
  } else if (segment == 'argument') {
    base = 'ARG';
  } else {
    throw UnsupportedError('Segment not supported yet');
  }

  writeLines(outputFile, [
    '@$base',
    'D=M',
    '@$index',
    'A=D+A', //base+i
    'D=M',
    '@SP',
    'A=M',
    'M=D',
    '@SP',
    'M=M+1',
  ]);
}

//pop local 2 =>
//pop from the stack and save it in : local[i] = RAM[LCL + i]
//
void writePopSegment(String segment, int index, File outputFile) {
  String base;

  if (segment == 'local') {
    base = 'LCL';
  } else if (segment == 'argument') {
    base = 'ARG';
  } else {
    throw UnsupportedError('Segment not supported yet');
  }

  writeLines(outputFile, [
    '@$base',
    'D=M',
    '@$index',
    'D=D+A',
    '@R13', // using arg to help us save the data  before poping
    'M=D', //saving the address : LCL + i

    '@SP',
    'AM=M-1',
    'D=M', // saving the value in D

    '@R13',
    'A=M',
    'M=D',
  ]);
}

/// Translates either one .vm file or a whole folder containing multiple .vm files
void translatePath(String inputPath) {
  final type = FileSystemEntity.typeSync(inputPath);

  if (type == FileSystemEntityType.file) {
    final inputFile = File(inputPath);

    final outputPath = inputFile.path.replaceAll(RegExp(r'\.vm$'), '.asm');
    final outputFile = File(outputPath);

    // Clear old output before writing new content.
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

    final folderName = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;

    final outputPath = '${dir.path}${Platform.pathSeparator}$folderName.asm';
    final outputFile = File(outputPath);

    // Clear old output before writing new content.
    outputFile.writeAsStringSync('');

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
