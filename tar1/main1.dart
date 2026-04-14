import 'dart:io';

/// Counts unique labels for eq / gt / lt commands.
int labelCounter = 0;

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
    'D=M',    // D = y
    'A=A-1',  // A = SP-1 => x
    op,       // perform x op y into M
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
    'AM=M-1',   // SP--, A=SP
    'D=M',      // D = y
    'A=A-1',    // A = SP-1 => x
    'D=M-D',    // x - y
    '@$trueLabel',
    'D;$jumpType',
    '@SP',
    'A=M-1',
    'M=0',      // false
    '@$endLabel',
    '0;JMP',
    '($trueLabel)',
    '@SP',
    'A=M-1',
    'M=-1',     // true
    '($endLabel)',
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
      if (parts.length == 3 && parts[1] == 'constant') {
        final value = int.parse(parts[2]);
        writePushConstant(value, outputFile);
      } else {
        throw UnsupportedError(
          'Stage I currently supports only: push constant x',
        );
      }
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

/// Translates one .vm file into one .asm file.
void translateFile(String inputPath) {
  final inputFile = File(inputPath);

  if (!inputFile.existsSync()) {
    print('Input file not found!');
    return;
  }

  if (!inputFile.path.endsWith('.vm')) {
    print('Input must be a .vm file');
    return;
  }

  final outputPath = inputFile.path.replaceAll(RegExp(r'\.vm$'), '.asm');
  final outputFile = File(outputPath);

  // Clear old output
  outputFile.writeAsStringSync('');

  final lines = inputFile.readAsLinesSync();

  for (final rawLine in lines) {
    final line = cleanLine(rawLine);

    if (line.isEmpty) {
      continue;
    }

    translateCommand(line, outputFile);
  }

  print('Translation completed: $outputPath');
}

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run main.dart <inputFile.vm>');
    return;
  }

  translateFile(args[0]);
}