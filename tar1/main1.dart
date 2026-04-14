import 'dart:io';

double totalBuy = 0;
double totalSell = 0;

void add(String product, int amount, double price, File outputFile) {
  double sum = amount * price;
  totalBuy += sum;

  outputFile.writeAsStringSync(
    "### BUY $product ###\n$sum\n",
    mode: FileMode.append,
  );
}

void sub(String product, int amount, double price, File outputFile) {
  double sum = amount * price;
  totalSell += sum;

  outputFile.writeAsStringSync(
    "\$\$\$ CELL $product \$\$\$\n$sum\n",
    mode: FileMode.append,
  );
}

void or(String product, int amount, double price, File outputFile) {
  double sum = amount * price;
  totalSell += sum;

  outputFile.writeAsStringSync(
    "\$\$\$ CELL $product \$\$\$\n$sum\n",
    mode: FileMode.append,
  );
}

void handleVmFile(File vmFile, File outputFile) {
  String fileName = vmFile.uri.pathSegments.last.replaceAll('.vm', '');

  outputFile.writeAsStringSync("$fileName\n", mode: FileMode.append);

  List<String> lines = vmFile.readAsLinesSync();

  for (String line in lines) {
    List<String> parts = line.split(" ");

    String command = parts[0];
    String product = parts[1];
    int amount = int.parse(parts[2]);
    double price = double.parse(parts[3]);

    if (command == "buy") {
      handleBuy(product, amount, price, outputFile);
    } else if (command == "cell") {
      handleSell(product, amount, price, outputFile);
    }
  }
}

void main() {
  String dirPath = r"C:\dart\dart-projects\POSL\tar0"; // תשני לפי המחשב שלך
  Directory dir = Directory(dirPath);

  if (!dir.existsSync()) {
    print("Directory not found!");
    return;
  }

  //output file:
  String folderName = dir.uri.pathSegments[dir.uri.pathSegments.length - 2];
  File outputFile = File('$dirPath\\$folderName.asm');
  outputFile.writeAsStringSync("");

  //handle VM files:
  List<FileSystemEntity> files = dir.listSync();

  for (var file in files) {
    if (file is File && file.path.endsWith('.vm')) {
      handleVmFile(file, outputFile);
    }
  }

  outputFile.writeAsStringSync(
    "TOTAL BUY: $totalBuy\nTOTAL SELL: $totalSell\n",
    mode: FileMode.append,
  );

  print("TOTAL BUY: $totalBuy");
  print("TOTAL SELL: $totalSell");
}
