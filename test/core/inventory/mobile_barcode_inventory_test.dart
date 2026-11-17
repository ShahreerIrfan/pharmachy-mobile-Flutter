import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_barcode_inventory_client.dart';

void main() {
  group('P218: MobileBarcodeInventoryClient Tests', () {
    late MobileBarcodeInventoryClient client;

    setUp(() {
      client = MobileBarcodeInventoryClient();
    });

    test('1. Receive workflow prompts for ambient and cold-chain items', () {
      final ambient = client.receive(
        productName: 'Napa Extra 500mg',
        barcode: '89411001',
        isColdChain: false,
      );
      expect(ambient.isSuccess, isTrue);
      expect(ambient.operatorPromptEn, contains('Scan destination storage'));
      expect(ambient.operatorPromptBn, contains('স্টোরেজ'));

      final coldChain = client.receive(
        productName: 'Mixtard 30 100IU',
        barcode: '89422001',
        isColdChain: true,
      );
      expect(coldChain.isSuccess, isTrue);
      expect(coldChain.operatorPromptEn, contains('Cold-Chain'));
      expect(coldChain.operatorPromptBn, contains('রেফ্রিজারেটরে'));
    });

    test('2. Put-away storage policy enforcement', () {
      // Placing cold chain in ambient zone -> rejected
      final failResult = client.putAway(
        batchNumber: 'INS-001',
        destinationLocation: 'SHELF-A1',
        isColdChain: true,
        enforceColdChain: true,
      );
      expect(failResult.isSuccess, isFalse);
      expect(failResult.errorCode, 'ERR_STORAGE_POLICY_VIOLATION');
      expect(failResult.operatorPromptEn, contains('Storage policy violation'));

      // Placing cold chain in fridge -> accepted
      final okResult = client.putAway(
        batchNumber: 'INS-001',
        destinationLocation: 'LOC-FRIDGE-01',
        isColdChain: true,
        enforceColdChain: true,
      );
      expect(okResult.isSuccess, isTrue);
      expect(okResult.destinationLocation, 'LOC-FRIDGE-01');
    });

    test('3. Move and Cycle Count workflows', () {
      final moveResult = client.move(
        batchNumber: 'NAP-001',
        fromLocation: 'SHELF-A1',
        toLocation: 'SHELF-B2',
      );
      expect(moveResult.isSuccess, isTrue);
      expect(moveResult.destinationLocation, 'SHELF-B2');

      // Count with zero discrepancy
      final countMatch = client.count(
        batchNumber: 'NAP-001',
        location: 'SHELF-B2',
        countedQty: 50,
        systemQty: 50,
      );
      expect(countMatch.discrepancy, 0);
      expect(countMatch.operatorPromptEn, contains('Zero discrepancy'));

      // Count with shortage discrepancy (-5)
      final countDiff = client.count(
        batchNumber: 'NAP-001',
        location: 'SHELF-B2',
        countedQty: 45,
        systemQty: 50,
      );
      expect(countDiff.discrepancy, -5);
      expect(countDiff.operatorPromptEn, contains('Discrepancy detected'));
    });

    test('4. Verify workflow flags expired and quarantined lots', () {
      final expired = client.verify(
        productName: 'Napa Extra 500mg',
        batchNumber: 'NAP-EXP',
        quantity: 10,
        isExpired: true,
        isQuarantined: false,
      );
      expect(expired.operatorPromptEn, contains('EXPIRED LOT ALERT'));

      final quarantined = client.verify(
        productName: 'Mixtard 30',
        batchNumber: 'INS-QUR',
        quantity: 20,
        isExpired: false,
        isQuarantined: true,
      );
      expect(quarantined.operatorPromptEn, contains('QUARANTINE ALERT'));
    });
  });
}
