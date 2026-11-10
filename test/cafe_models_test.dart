import 'package:cafe_system/models/cafe_note.dart';
import 'package:cafe_system/models/cafe_order.dart';
import 'package:cafe_system/models/cafe_product.dart';
import 'package:cafe_system/models/cafe_sale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CafeOrderItem', () {
    test('calculates total using quantity and per-unit discount', () {
      final item = CafeOrderItem(
        productName: 'قهوة',
        quantity: 3,
        unitPrice: 25,
        discountPerUnit: 5,
      );

      expect(item.total, 60);
    });

    test('copyWith preserves product and price while updating quantity', () {
      final item = CafeOrderItem(
        productName: 'بيبسي',
        quantity: 1,
        unitPrice: 20,
        discountPerUnit: 2,
      );

      final updated = item.copyWith(quantity: 4);

      expect(updated.productName, 'بيبسي');
      expect(updated.unitPrice, 20);
      expect(updated.discountPerUnit, 2);
      expect(updated.quantity, 4);
      expect(updated.total, 72);
    });
  });

  group('CafeRoomSession', () {
    final startedAt = DateTime(2026, 10, 30, 12);

    test('calculates elapsed time and hourly charge', () {
      final session = CafeRoomSession(
        id: 'room-1',
        mode: 'single',
        hourlyRate: 40,
        startedAt: startedAt,
      );

      expect(
        session.durationMinutesAt(startedAt.add(const Duration(minutes: 45))),
        45,
      );
      expect(session.chargeAt(startedAt.add(const Duration(minutes: 45))), 30);
    });

    test('stops accumulating time after the session ended', () {
      final session = CafeRoomSession(
        id: 'room-1',
        mode: 'multi',
        hourlyRate: 60,
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 30)),
      );

      expect(session.isActive, isFalse);
      expect(
        session.durationMinutesAt(startedAt.add(const Duration(hours: 2))),
        30,
      );
      expect(session.chargeAt(startedAt.add(const Duration(hours: 2))), 30);
    });

    test('does not produce negative time when queried before start', () {
      final session = CafeRoomSession(
        id: 'room-1',
        mode: 'single',
        hourlyRate: 40,
        startedAt: startedAt,
      );

      expect(
        session.durationAt(startedAt.subtract(const Duration(minutes: 1))),
        Duration.zero,
      );
      expect(
        session.chargeAt(startedAt.subtract(const Duration(minutes: 1))),
        0,
      );
    });

    test('applies discount without allowing a negative room charge', () {
      final session = CafeRoomSession(
        id: 'room-1',
        mode: 'single',
        hourlyRate: 40,
        startedAt: startedAt,
        discount: 50,
      );

      expect(session.chargeAt(startedAt.add(const Duration(minutes: 30))), 0);
    });

    test('keeps legacy fixed charges stable', () {
      final session = CafeRoomSession(
        id: 'room-1',
        mode: 'single',
        hourlyRate: 40,
        startedAt: startedAt,
        legacyFixedCharge: 75,
        discount: 5,
      );

      expect(session.chargeAt(startedAt.add(const Duration(hours: 3))), 70);
    });

    test(
      'copyWith updates the start time for retroactive session correction',
      () {
        final session = CafeRoomSession(
          id: 'room-1',
          mode: 'single',
          hourlyRate: 40,
          startedAt: startedAt,
        );
        final correctedStart = startedAt.subtract(const Duration(minutes: 30));

        final corrected = session.copyWith(startedAt: correctedStart);

        expect(corrected.startedAt, correctedStart);
        expect(corrected.chargeAt(startedAt), 20);
      },
    );
  });

  test('CafeOrder total combines discounted products and room sessions', () {
    final startedAt = DateTime(2026, 10, 30, 12);
    final order = CafeOrder(
      id: 'table-1',
      label: 'ترابيزة 1',
      items: [
        CafeOrderItem(
          productName: 'قهوة',
          quantity: 2,
          unitPrice: 30,
          discountPerUnit: 5,
        ),
      ],
      roomSessions: [
        CafeRoomSession(
          id: 'room-1',
          mode: 'single',
          hourlyRate: 40,
          startedAt: startedAt,
          endedAt: startedAt.add(const Duration(minutes: 30)),
        ),
      ],
    );

    expect(order.total, 70);
  });

  test('order note is retained on the paid sale', () {
    final order = CafeOrder(
      id: 'table-2',
      label: 'ترابيزة 2',
      note: 'العميل دفع جزء من الحساب',
    );
    final sale = CafeSale.fromOrder(
      id: 1,
      order: order,
      time: DateTime(2026, 11, 8, 12),
    );

    expect(sale.note, 'العميل دفع جزء من الحساب');
    expect(order.copyWith(note: 'ملاحظة محدثة').note, 'ملاحظة محدثة');
  });

  test('CafeNote maps stored text and timestamp', () {
    final createdAt = DateTime(2026, 11, 8, 9, 30);
    final note = CafeNote.fromMap({
      'id': 7,
      'note_text': 'تذكير بإغلاق اليومية',
      'created_at': createdAt.toIso8601String(),
    });

    expect(note.id, 7);
    expect(note.text, 'تذكير بإغلاق اليومية');
    expect(note.createdAt, createdAt);
  });

  test('CafeProduct identifies carton-tracked products by stock data', () {
    const stocked = CafeProduct(
      'بيبسي',
      'مشروبات باردة',
      15,
      Icons.local_drink,
      stockUnits: 24,
      unitsPerCarton: 24,
      purchasePricePerCarton: 180,
    );
    const regular = CafeProduct('قهوة', 'قهوة', 20, Icons.coffee);

    expect(stocked.tracksStock, isTrue);
    expect(regular.tracksStock, isFalse);
  });
}
