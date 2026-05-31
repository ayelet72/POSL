import 'translator.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('No .vm files were found in the folder:\n${dir.path}');
    return;
  }

  translatePath(args[0]);
}