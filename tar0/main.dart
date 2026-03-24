import 'dart:io';

/// Path to the folder that contains the VM files.
String dirPath = r"C:\Users\mazuz\Documents\POSL\POSL\tar0";

/// Total value of all buy operations.
double totalBuy = 0;

/// Total value of all sell operations.
double totalSell = 0;

/// Handles a buy command.
///
/// Input:
/// - [product]: product name
/// - [amount]: number of units
/// - [price]: price per unit
/// - [outputFile]: destination file
///
/// Output:
/// - Appends the formatted buy result to [outputFile]
/// - Updates [totalBuy]
void handleBuy(String product, int amount, double price, File outputFile) {
  double sum = amount * price;
  totalBuy += sum;

  outputFile.writeAsStringSync(
    "### BUY $product ###\n$sum\n",
    mode: FileMode.append,
  );
}

/// Handles a sell command.
///
/// Input:
/// - [product]: product name
/// - [amount]: number of units
/// - [price]: price per unit
/// - [outputFile]: destination file
///
/// Output:
/// - Appends the formatted sell result to [outputFile]
/// - Updates [totalSell]
void handleSell(String product, int amount, double price, File outputFile) {
  double sum = amount * price;
  totalSell += sum;

  outputFile.writeAsStringSync(
    "\$\$\$ CELL $product \$\$\$\n$sum\n",
    mode: FileMode.append,
  );
}

/// Processes one VM file.
///
/// Input:
/// - [vmFile]: source VM file
/// - [outputFile]: output ASM file
///
/// Output:
/// - Writes the file name and translated commands to [outputFile]
/// - Calls the relevant handler for each command
void handleVmFile(File vmFile, File outputFile) {
  // Extract the current file name without the ".vm" extension.
  String fileName = vmFile.uri.pathSegments.last.replaceAll('.vm', '');

  // Write the file name to the output file before processing its commands.
  outputFile.writeAsStringSync("$fileName\n", mode: FileMode.append);

  // Read all lines from the current VM file.
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

/// Runs the program.
///
/// Input:
/// - Reads all `.vm` files from [dirPath]
///
/// Output:
/// - Creates an `.asm` file in the same folder
/// - Writes all translated results into the file
/// - Prints the final totals to the console
void main() {
  // Open the directory that contains the input VM files.
  Directory dir = Directory(dirPath);

  if (!dir.existsSync()) {
    print("Directory not found!");
    return;
  }

  // Create the output file in the same folder, using the folder name.
  String folderName = dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
  File outputFile = File('$dirPath\\$folderName.asm');

  // Clear previous output content before writing new results.
  outputFile.writeAsStringSync("");

  // Read all files from the input directory.
  List<FileSystemEntity> files = dir.listSync();

  // Process only files with the ".vm" extension.
  for (var file in files) {
    if (file is File && file.path.endsWith('.vm')) {
      handleVmFile(file, outputFile);
    }
  }

  // Append the final totals to the output file.
  outputFile.writeAsStringSync(
    "TOTAL BUY: $totalBuy\nTOTAL SELL: $totalSell\n",
    mode: FileMode.append,
  );

  // Print the final totals to the console.
  print("TOTAL BUY: $totalBuy");
  print("TOTAL SELL: $totalSell");
}