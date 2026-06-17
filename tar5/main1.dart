import 'driver.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Missing input path.');
    print('Please provide a .jack file or a folder path.');
    return;
  }

  if (args.length > 1) {
    print('Too many arguments.');
    print('Please provide only one path.');
    return;
  }

  processPath(args[0]);
}
