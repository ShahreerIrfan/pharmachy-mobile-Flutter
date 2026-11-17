import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_recall_dispensing_client.dart';

void main() {
  group('P256: Mobile Recall Dispensing Client Tests', () {
    test('Role authorization gates for recall management', () {
      expect(MobileRecallDispensingClient.canManageRecall('SUPERADMIN'), isTrue);
      expect(MobileRecallDispensingClient.canManageRecall('PHARMACY_OWNER'), isTrue);
      expect(MobileRecallDispensingClient.canManageRecall('BRANCH_MANAGER'), isTrue);
      expect(MobileRecallDispensingClient.canManageRecall('STAFF_PHARMACIST'), isTrue);
      expect(MobileRecallDispensingClient.canManageRecall('CASHIER'), isFalse);
    });

    test('Dispensing lock gate blocks recalled or non-active batches', () {
      expect(
        MobileRecallDispensingClient.canDispenseBatch(isRecalled: false, status: 'ACTIVE'),
        isTrue,
      );
      expect(
        MobileRecallDispensingClient.canDispenseBatch(isRecalled: true, status: 'ACTIVE'),
        isFalse,
      );
      expect(
        MobileRecallDispensingClient.canDispenseBatch(isRecalled: false, status: 'QUARANTINED'),
        isFalse,
      );
      expect(
        MobileRecallDispensingClient.canDispenseBatch(isRecalled: false, status: 'EXPIRED'),
        isFalse,
      );
    });

    test('Preflight validation rules', () {
      expect(
        () => MobileRecallDispensingClient.validatePreflight(
          batchNumber: 'BATCH-77',
          productName: 'Cefixime 200mg',
          recallReason: 'Impurity exceeded specification',
          recallClass: 'CLASS_I',
        ),
        returnsNormally,
      );

      // Short batch
      expect(
        () => MobileRecallDispensingClient.validatePreflight(
          batchNumber: 'B',
          productName: 'Product',
          recallReason: 'Reason',
          recallClass: 'CLASS_I',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Empty reason
      expect(
        () => MobileRecallDispensingClient.validatePreflight(
          batchNumber: 'BATCH-77',
          productName: 'Product',
          recallReason: '',
          recallClass: 'CLASS_I',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Localization and historical impact summary formatting', () {
      expect(
        MobileRecallDispensingClient.getRecallClassDisplay('CLASS_I', lang: 'bn'),
        'ক্লাস ১ (মারাত্মক / জীবন বিপন্নকারী ঝুঁকি)',
      );
      expect(
        MobileRecallDispensingClient.getRecallClassDisplay('CLASS_II', lang: 'en'),
        'Class II (Temporary / Reversible defect)',
      );

      final summary = MobileRecallDispensingClient.formatHistoricalImpactSummary(
        totalInvoices: 12,
        totalUnitsSold: '240.00',
        totalValueBdt: '18500.00',
        lang: 'en',
      );
      expect(summary, contains('12 invoices impacted'));
      expect(summary, contains('240.00 units sold'));
      expect(summary, contains('18500.00'));
      expect(summary, contains('Past sales history unmodified'));
    });
  });
}

