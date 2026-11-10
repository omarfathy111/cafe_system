class CafeSaleItem {
  const CafeSaleItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discountPerUnit = 0,
  });

  final String productName;
  final int quantity;
  final double unitPrice;
  final double discountPerUnit;

  double get total => quantity * (unitPrice - discountPerUnit);

  CafeSaleItem copyWith({int? quantity, double? unitPrice}) => CafeSaleItem(
    productName: productName,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    discountPerUnit: discountPerUnit,
  );
}
