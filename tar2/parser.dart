import 'dart:io';
import 'code_writer.dart';

/// remove comments and extra spaces
String cleanLine(String line) {
  if (line.contains('//')) {
    line = line.split('//')[0];
  }
  return line.trim();
}

/// translate one cleaned VM command into Hack assembly
void translateCommand(String line, File outputFile) {
  //slipts wherever there is a space or few spaces
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
        // local \ argument \ this \ that \ temp\ pointer \ static
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