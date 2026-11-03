import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/pricing/mobile_conditional_pricing_client.dart';

void main() {
  group('MobileConditionalPricingClient Tests (P153)', () {
    late MobileConditionalPricingClient client;

    setUp(() {
      client = MobileConditionalPricingClient();
    });

    test('P153-MOB-01: Valid price calculations across pack, strip, and piece', () {
      final result = client.calculateDerivedPricing(
        packToStripMultiplier: 10,
        stripToPieceMultiplier: 10,
        explicitTotalUnits: 100,
        costPerPieceBdt: 2.0,
        mrpPerPieceBdt: 3.0,
      );

      expect(result.isValid, isTrue);
      expect(result.errorCode, isNull);
      expect(result.totalBaseUnitsPerPack, 100);
      expect(result.stripCostBdt, 20.0);
      expect(result.stripMrpBdt, 30.0);
      expect(result.packCostBdt, 200.0);
      expect(result.packMrpBdt, 300.0);
    });

    test('P153-MOB-02: Packaging dimension mismatch triggers ERR_DIMENSION_MISMATCH', () {
      final result = client.calculateDerivedPricing(
        packToStripMultiplier: 5,
        stripToPieceMultiplier: 10,
        explicitTotalUnits: 60, // 5 * 10 = 50 != 60
        costPerPieceBdt: 2.0,
        mrpPerPieceBdt: 3.0,
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_DIMENSION_MISMATCH');
    });

    test('P153-MOB-03: Zero or negative multiplier triggers ERR_INVALID_MULTIPLIER', () {
      final result = client.calculateDerivedPricing(
        packToStripMultiplier: 0,
        stripToPieceMultiplier: 10,
        costPerPieceBdt: 2.0,
        mrpPerPieceBdt: 3.0,
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_INVALID_MULTIPLIER');
    });

    test('P153-MOB-04: Non-positive piece price triggers ERR_INVALID_PRICE', () {
      final result = client.calculateDerivedPricing(
        packToStripMultiplier: 10,
        stripToPieceMultiplier: 10,
        costPerPieceBdt: 0.0,
        mrpPerPieceBdt: 3.0,
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_INVALID_PRICE');
    });

    test('P153-MOB-05: Multi-unit pack with both strip & piece disabled triggers ERR_INVALID_BREAK_BULK_POLICY', () {
      final result = client.calculateDerivedPricing(
        packToStripMultiplier: 10,
        stripToPieceMultiplier: 10,
        costPerPieceBdt: 2.0,
        mrpPerPieceBdt: 3.0,
        allowStripSale: false,
        allowPieceSale: false,
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_INVALID_BREAK_BULK_POLICY');
    });

    test('P153-MOB-06: Single unit device or bottle allows pack-only sales without break bulk', () {
      final result = client.calculateDerivedPricing(
        packToStripMultiplier: 1,
        stripToPieceMultiplier: 1,
        costPerPieceBdt: 120.0,
        mrpPerPieceBdt: 150.0,
        allowStripSale: false,
        allowPieceSale: false,
      );

      expect(result.isValid, isTrue);
      expect(result.totalBaseUnitsPerPack, 1);
      expect(result.packMrpBdt, 150.0);
    });

    test('P153-MOB-07: Cashier role is restricted from editing pricing', () {
      expect(client.canEditPricing('STAFF_PHARMACIST'), isTrue);
      expect(client.canEditPricing('PHARMACY_OWNER'), isTrue);
      expect(client.canEditPricing('SUPERADMIN'), isTrue);
      expect(client.canEditPricing('CASHIER'), isFalse);
      expect(client.canEditPricing(null), isFalse);
    });

    test('P153-MOB-08: Unit display returns correct Bengali and English localized text', () {
      expect(client.getUnitDisplay('TABLET', locale: 'bn'), 'ট্যাবলেট');
      expect(client.getUnitDisplay('TABLET', locale: 'en'), 'Tablet');
      expect(client.getUnitDisplay('DEVICE', locale: 'bn'), 'ডিভাইস');
      expect(client.getUnitDisplay('DEVICE', locale: 'en'), 'Device');
      expect(client.getUnitDisplay('CUSTOM_UNIT', locale: 'bn'), 'CUSTOM_UNIT');
    });

    test('P153-MOB-09: Build pricing payload matches canonical schema format', () {
      final payload = client.buildPricingPayload(
        productId: 'prod-test-01',
        baseDispensingUnit: 'CAPSULE',
        packToStripMultiplier: 5,
        stripToPieceMultiplier: 10,
        costPerPieceBdt: 5.0,
        mrpPerPieceBdt: 7.0,
        allowStripSale: true,
        allowPieceSale: false,
      );

      expect(payload['product_id'], 'prod-test-01');
      expect(payload['base_dispensing_unit'], 'CAPSULE');
      expect(payload['total_base_units_per_pack'], 50);
      expect(payload['strip_mrp_bdt'], 70.0);
      expect(payload['pack_mrp_bdt'], 350.0);
      expect(payload['allow_piece_sale'], isFalse);
    });
  });
}
