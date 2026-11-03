import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/stock/mobile_expiry_manufacturing_client.dart';

void main() {
  group('MobileExpiryManufacturingClient Tests (P154)', () {
    late MobileExpiryManufacturingClient client;
    final today = DateTime(2026, 11, 3);

    setUp(() {
      client = MobileExpiryManufacturingClient();
    });

    test('P154-MOB-01: Valid stock intake validation succeeds with accurate shelf life', () {
      final mfg = today.subtract(const Duration(days: 90));
      final exp = today.add(const Duration(days: 500));

      final result = client.validateStockIntake(
        lotReference: 'LOT-BEX-2026',
        manufacturingDate: mfg,
        expiryDate: exp,
        currentDate: today,
      );

      expect(result.isValid, isTrue);
      expect(result.errorCode, isNull);
      expect(result.shelfLifeDays, 590);
      expect(result.isAutoQuarantined, isFalse);
    });

    test('P154-MOB-02: Future manufacturing date triggers ERR_FUTURE_MANUFACTURING_DATE', () {
      final mfg = today.add(const Duration(days: 5));
      final exp = today.add(const Duration(days: 400));

      final result = client.validateStockIntake(
        lotReference: 'LOT-FUT-01',
        manufacturingDate: mfg,
        expiryDate: exp,
        currentDate: today,
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_FUTURE_MANUFACTURING_DATE');
    });

    test('P154-MOB-03: Expiry before manufacturing triggers ERR_EXPIRY_BEFORE_MANUFACTURING', () {
      final mfg = today.subtract(const Duration(days: 30));
      final exp = today.subtract(const Duration(days: 40));

      final result = client.validateStockIntake(
        lotReference: 'LOT-INV-01',
        manufacturingDate: mfg,
        expiryDate: exp,
        currentDate: today,
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_EXPIRY_BEFORE_MANUFACTURING');
    });

    test('P154-MOB-04: Expired stock intake into active stock triggers ERR_STOCK_ALREADY_EXPIRED', () {
      final mfg = today.subtract(const Duration(days: 400));
      final exp = today.subtract(const Duration(days: 10));

      final result = client.validateStockIntake(
        lotReference: 'LOT-EXP-01',
        manufacturingDate: mfg,
        expiryDate: exp,
        currentDate: today,
        isQuarantined: false,
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_STOCK_ALREADY_EXPIRED');
    });

    test('P154-MOB-05: Expired stock intake explicitly quarantined is permitted', () {
      final mfg = today.subtract(const Duration(days: 400));
      final exp = today.subtract(const Duration(days: 10));

      final result = client.validateStockIntake(
        lotReference: 'LOT-EXP-02',
        manufacturingDate: mfg,
        expiryDate: exp,
        currentDate: today,
        isQuarantined: true,
      );

      expect(result.isValid, isTrue);
      expect(result.isAutoQuarantined, isTrue);
    });

    test('P154-MOB-06: Near-expiry stock is automatically flagged quarantined', () {
      final mfg = today.subtract(const Duration(days: 180));
      final exp = today.add(const Duration(days: 15)); // 15 <= 30 lead

      final result = client.validateStockIntake(
        lotReference: 'LOT-NEAR-01',
        manufacturingDate: mfg,
        expiryDate: exp,
        currentDate: today,
        quarantineLeadDays: 30,
        isQuarantined: false,
      );

      expect(result.isValid, isTrue);
      expect(result.isAutoQuarantined, isTrue);
    });

    test('P154-MOB-07: Invalid lot reference format triggers ERR_INVALID_LOT_FORMAT', () {
      final mfg = today.subtract(const Duration(days: 30));
      final exp = today.add(const Duration(days: 300));

      final result = client.validateStockIntake(
        lotReference: 'LOT*BAD@CHARS!',
        manufacturingDate: mfg,
        expiryDate: exp,
        currentDate: today,
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_INVALID_LOT_FORMAT');
    });

    test('P154-MOB-08: Cashier role is restricted from stock intake mutations', () {
      expect(client.canMutateStock('STAFF_PHARMACIST'), isTrue);
      expect(client.canMutateStock('PHARMACY_OWNER'), isTrue);
      expect(client.canMutateStock('SUPERADMIN'), isTrue);
      expect(client.canMutateStock('CASHIER'), isFalse);
      expect(client.canMutateStock(null), isFalse);
    });

    test('P154-MOB-09: Storage condition display returns localized text in Bengali and English', () {
      expect(
        client.getStorageConditionDisplay('COLD_CHAIN_2_8C', locale: 'bn'),
        'কোল্ড চেইন রেফ্রিজারেশন (২°সে - ৮°সে)',
      );
      expect(
        client.getStorageConditionDisplay('COLD_CHAIN_2_8C', locale: 'en'),
        'Cold Chain (2°C - 8°C)',
      );
      expect(
        client.getStorageConditionDisplay('ROOM_TEMPERATURE_15_25C', locale: 'bn'),
        'স্বাভাবিক তাপমাত্রা (১৫°সে - ২৫°সে)',
      );
    });

    test('P154-MOB-10: Build stock entry payload produces canonical DRF format', () {
      final mfg = today.subtract(const Duration(days: 60));
      final exp = today.add(const Duration(days: 500));

      final payload = client.buildStockEntryPayload(
        productId: 'prod-test-01',
        lotReference: 'LOT-PAYLOAD-01',
        manufacturingDate: mfg,
        expiryDate: exp,
        quantityReceived: 100,
        unitCostBdt: 5.50,
        storageCondition: 'COOL_8_15C',
      );

      expect(payload['product_id'], 'prod-test-01');
      expect(payload['lot_reference'], 'LOT-PAYLOAD-01');
      expect(payload['quantity_received'], 100);
      expect(payload['unit_cost_bdt'], 5.50);
      expect(payload['storage_condition'], 'COOL_8_15C');
      expect(payload['is_quarantined'], isFalse);
    });
  });
}

