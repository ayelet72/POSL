int tailSum(int n, int acc) {
  if (n == 0) return acc;
  return tailSum(n - 1, acc + n); // tail call
}

void main() {
  for (var n in [10000, 50000, 100000, 500000, 1000000]) {
    try {
      print("n=$n -> ${tailSum(n, 0)}");
    } on StackOverflowError {
      print("n=$n -> Stack overflow");
      break;
    }
  }
}
