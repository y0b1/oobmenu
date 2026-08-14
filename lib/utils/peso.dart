String formatPeso(int amount, {bool withDecimals = false}) {
  if (withDecimals) {
    return '₱ ${amount.toStringAsFixed(0)}.00';
  }
  return '₱ $amount';
}

String formatPesoAdd(int amount) {
  return '+₱ $amount';
}
