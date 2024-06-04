List<int> intListDiff(List<int> input) {
  List<int> differences = [];
  for (int i = 0; i < input.length - 1; i++) {
    differences.add(input[i + 1] - input[i]);
  }
  return differences;
}

int intListSum(List<int> input) => input.reduce((a, b) => a + b);
