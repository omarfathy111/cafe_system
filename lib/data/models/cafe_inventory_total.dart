class CafeInventoryTotal {
  const CafeInventoryTotal({
    required this.quantity,
    required this.amount,
    this.unitsPerCarton,
  });

  final int quantity;
  final double amount;
  final int? unitsPerCarton;
}
