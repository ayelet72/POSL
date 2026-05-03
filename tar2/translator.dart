import 'dart:io';
import 'parser.dart';
import 'code_writer.dart';

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