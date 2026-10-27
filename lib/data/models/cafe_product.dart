import 'package:flutter/material.dart';

class CafeProduct {
  const CafeProduct(
    this.name,
    this.category,
    this.price,
    this.icon, {
    this.stockUnits,
    this.unitsPerCarton,
    this.purchasePricePerCarton,
  });
  final String name;
  final String category;
  final double price;
  final IconData icon;

  /// Null means this is a regular menu product without tracked stock.
  final int? stockUnits;
  final int? unitsPerCarton;
  final double? purchasePricePerCarton;

  bool get tracksStock => stockUnits != null;
}
