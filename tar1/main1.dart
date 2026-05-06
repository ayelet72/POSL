import 'dart:io';

/// Counts unique labels for eq / gt / lt commands.
int labelCounter = 0;

/// Keeps the current VM file name.
/// Used for static variables.
String currentFileName = '';

/// Writes one assembly line to the output file.
void writeLine(File outputFile, String line) {
  outputFile.writeAsStringSync('$line\n', mode: FileMode.append);
}

/// Writes multiple assembly lines to the output file.
void writeLines(File outputFile, List<String> lines) {
  for (final line in lines) {
    writeLine(outputFile, line);
  }
}

/// Translates: push constant x
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

/// Translates binary commands like add, sub, and, or.
/// Stack effect:
/// y = pop(), x = pop(), push(x op y)
void writeBinaryCommand(String op, File outputFile) {
  writeLines(outputFile, [
    '@SP',
    'AM=M-1', // SP--, A=SP
    'D=M', // D = y
    'A=A-1', // A = SP-1 => x
    op, // perform x op y into M
  ]);
}

/// Translates unary commands like neg, not.
/// Stack effect:
/// y = top(), replace with op(y)
void writeUnaryCommand(String op, File outputFile) {
  writeLines(outputFile, [
    '@SP',
    'A=M-1',
    op,
  ]);
}

/// Translates comparison commands: eq, gt, lt
void writeComparison(String jumpType, File outputFile) {
  final trueLabel = 'TRUE_$labelCounter';
  final endLabel = 'END_$labelCounter';
  labelCounter++;

  writeLines(outputFile, [
    '@SP',
    'AM=M-1', // SP--, A=SP
    'D=M', // D = y
    'A=A-1', // A = SP-1 => x
    'D=M-D', // x - y
    '@$trueLabel',
    'D;$jumpType',
    '@SP',
    'A=M-1',
    'M=0', // false
    '@$endLabel',
    '0;JMP',
    '($trueLabel)',
    '@SP',
    'A=M-1',
    'M=-1', // true
    '($endLabel)',
  ]);
}

void writePushPop(
  String command,
  String segment,
  int index,
  File outputFile,
) {
  switch (command) {
    case 'push':
      switch (segment) {
        case 'constant':
          writePushConstant(index, outputFile);
          break;

        case 'local':
        case 'argument':
        case 'this':
        case 'that':
          String base;
          if (segment == 'local') {
            base = 'LCL';
          } else if (segment == 'argument') {
            base = 'ARG';
          } else if (segment == 'this') {
            base = 'THIS';
          } else {
            base = 'THAT';
          }

          writeLines(outputFile, [
            '@$base',
            'D=M', // base address
            '@$index',
            'A=D+A', // target address = base + index
            'D=M', // D = RAM[base + index]
            '@SP',
            'A=M',
            'M=D',
            '@SP',
            'M=M+1',
          ]);
          break;

        case 'temp':
          // temp = R5-R12
          writeLines(outputFile, [
            '@${5 + index}',
            'D=M',
            '@SP',
            'A=M',
            'M=D',
            '@SP',
            'M=M+1',
          ]);
          break;

        case 'pointer':
          // pointer 0 = THIS, pointer 1 = THAT
          String ptr = (index == 0) ? 'THIS' : 'THAT';
          writeLines(outputFile, [
            '@$ptr',
            'D=M',
            '@SP',
            'A=M',
            'M=D',
            '@SP',
            'M=M+1',
          ]);
          break;

        case 'static':
          // static i = FileName.i
          writeLines(outputFile, [
            '@${currentFileName}.$index',
            'D=M',
            '@SP',
            'A=M',
            'M=D',
            '@SP',
            'M=M+1',
          ]);
          break;

        default:
          throw UnsupportedError('Unknown segment: $segment');
      }
      break;

    case 'pop':
      switch (segment) {
        case 'local':
        case 'argument':
        case 'this':
        case 'that':
          String base;
          if (segment == 'local') {
            base = 'LCL';
          } else if (segment == 'argument') {
            base = 'ARG';
          } else if (segment == 'this') {
            base = 'THIS';
          } else {
            base = 'THAT';
          }

          writeLines(outputFile, [
            '@$base',
            'D=M',
            '@$index',
            'D=D+A',
            '@R13',
            'M=D', // R13 = target address
            '@SP',
            'AM=M-1',
            'D=M',
            '@R13',
            'A=M',
            'M=D',
          ]);
          break;

        case 'temp':
          writeLines(outputFile, [
            '@SP',
            'AM=M-1',
            'D=M',
            '@${5 + index}',
            'M=D',
          ]);
          break;

        case 'pointer':
          String ptr = (index == 0) ? 'THIS' : 'THAT';
          writeLines(outputFile, [
            '@SP',
            'AM=M-1',
            'D=M',
            '@$ptr',
            'M=D',
          ]);
          break;

        case 'static':
          writeLines(outputFile, [
            '@SP',
            'AM=M-1',
            'D=M',
            '@${currentFileName}.$index',
            'M=D',
          ]);
          break;

        default:
          throw UnsupportedError('Unknown segment: $segment');
      }
      break;

    default:
      throw UnsupportedError('Unknown command: $command');
  }
}

void writeXor(File outputFile) {
  writeLines(outputFile, [
    // R13 = y
    '@SP',
    'AM=M-1',
    'D=M',
    '@R13',
    'M=D',

    // R14 = x
    '@SP',
    'AM=M-1',
    'D=M',
    '@R14',
    'M=D',

    // x | y
    '@R14',
    'D=M',
    '@R13',
    'D=D|M',
    '@R15',
    'M=D',

    // !(x & y)
    '@R14',
    'D=M',
    '@R13',
    'D=D&M',
    'D=!D',

    // (x | y) & !(x & y)
    '@R15',
    'D=D&M',

    // push result
    '@SP',
    'A=M',
    'M=D',
    '@SP',
    'M=M+1',
  ]);
}

/// Handles one parsed VM command.
void translateCommand(String line, File outputFile) {
  final parts = line.split(RegExp(r'\s+'));

  if (parts.isEmpty) {
    return;
  }

  final command = parts[0];

  switch (command) {
    case 'push':
    case 'pop':
      final segment = parts[1];
      final index = int.parse(parts[2]);
      writePushPop(command, segment, index, outputFile);
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

    case 'xor':
      writeXor(outputFile);
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

    default:
      throw UnsupportedError('Unsupported VM command: $line');
  }
}

/// Removes comments and extra spaces from one VM line.
String cleanLine(String line) {
  if (line.contains('//')) {
    line = line.split('//')[0];
  }
  return line.trim();
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

/// Returns all .vm files inside a directory.
List<File> getVmFiles(Directory dir) {
  final vmFiles = dir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.vm'))
      .toList();

  vmFiles.sort((a, b) => a.path.compareTo(b.path));
  return vmFiles;
}

/// Translates one file or a whole folder.
/// If a folder is given, all .vm files are merged into one .asm file.
/// No bootstrap is added.
void translatePath(String inputPath) {
  final type = FileSystemEntity.typeSync(inputPath);

  if (type == FileSystemEntityType.file) {
    final inputFile = File(inputPath);

    final outputPath = inputFile.path.replaceAll(RegExp(r'\.vm$'), '.asm');
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

    final folderName = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final outputPath = '${dir.path}${Platform.pathSeparator}$folderName.asm';
    final outputFile = File(outputPath);

    // clear old output
    outputFile.writeAsStringSync('');

    // translate all VM files into one ASM file
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