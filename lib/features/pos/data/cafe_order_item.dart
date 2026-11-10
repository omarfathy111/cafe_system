class CafeOrderItem {
  CafeOrderItem({
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
  String get displayName => productName;

  CafeOrderItem copyWith({int? quantity, double? discountPerUnit}) =>
      CafeOrderItem(
        productName: productName,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice,
        discountPerUnit: discountPerUnit ?? this.discountPerUnit,
      );

  bool sameVariant(CafeOrderItem other) => productName == other.productName;
}
