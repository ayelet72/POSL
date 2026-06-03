import 'dart:io';
import 'tokenizer.dart';
import 'compilation_engine.dart'; // ← נוסף

List<File> getJackFiles(Directory dir) {
  final jackFiles = dir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.jack'))
      .toList();

  jackFiles.sort((a, b) => a.path.compareTo(b.path));
  return jackFiles;
}

void processJackFile(File inputFile) {
  final basePath = inputFile.path.replaceFirst(
    RegExp(r'\.jack$', caseSensitive: false),
    '',
  );

  final tokenFile = File('${basePath}T.xml');
  tokenFile.writeAsStringSync('');
  tokenizeFile(inputFile, tokenFile);

  final outputFile = File('$basePath.xml'); // ←
  parseTokenFile(tokenFile, outputFile); // ←

  print('Processed: ${inputFile.path}');
}

void processPath(String inputPath) {
  final type = FileSystemEntity.typeSync(inputPath);

  if (type == FileSystemEntityType.notFound) {
    print('Path not found: $inputPath');
    return;
  }

  if (type == FileSystemEntityType.file) {
    final inputFile = File(inputPath);

    if (!inputFile.path.toLowerCase().endsWith('.jack')) {
      print('The file must be a .jack file.');
      print('Received: ${inputFile.path}');
      return;
    }

    processJackFile(inputFile);
    return;
  }

  if (type == FileSystemEntityType.directory) {
    final dir = Directory(inputPath);
    final jackFiles = getJackFiles(dir);

    if (jackFiles.isEmpty) {
      print('No .jack files found in folder: ${dir.path}');
      return;
    }

    for (final file in jackFiles) {
      processJackFile(file);
    }

    print('Finished processing all .jack files in the folder.');
    return;
  }

  print('Invalid input path.');
}
