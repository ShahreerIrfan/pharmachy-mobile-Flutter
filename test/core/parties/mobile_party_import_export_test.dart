// mobile_party_import_export_test.dart
// Architecture Decision: ADR-0278 (P278).
// Phase 14: Customers, Suppliers, Dues & Payments.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/parties/mobile_party_import_export_client.dart';

void main() {
  group('MobilePartyImportExportClient Tests (P278)', () {
    const tenantId = 'ten-dhk-01';
    const branchId = 'br-dhanmondi-01';

    late MobilePartyImportExportClient ownerClient;
    late MobilePartyImportExportClient managerClient;
    late MobilePartyImportExportClient cashierClient;

    setUp(() {
      ownerClient = MobilePartyImportExportClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'owner_01',
      );

      managerClient = MobilePartyImportExportClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'mgr_01',
      );

      cashierClient = MobilePartyImportExportClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'csh_01',
      );
    });

    test('1. Manager export applies privacy masking to customer PII', () {
      managerClient.seedCustomer({
        'customer_id': 'cust-01',
        'full_name': 'Rafiqul Islam',
        'phone': '01711223344',
        'email': 'rafiq@pharma.com',
        'address': 'House 12, Road 4, Dhanmondi',
        'credit_limit_bdt': '5000.00',
      });

      final exported = managerClient.exportParties(partyType: 'CUSTOMER');
      expect(exported.length, equals(1));
      final c = exported.first;
      expect(c['phone'], equals('017****3344'));
      expect(c['email'], equals('r***@pharma.com'));
      expect(c['address'], equals('[REDACTED]'));
      expect(c['credit_limit_bdt'], equals('[RESTRICTED]'));
    });

    test('2. Owner export with includeSensitive=true provides unmasked records', () {
      ownerClient.seedCustomer({
        'customer_id': 'cust-02',
        'full_name': 'Karim Ahmed',
        'phone': '01811556677',
        'email': 'karim@gmail.com',
        'address': 'Gulshan 2',
        'credit_limit_bdt': '10000.00',
      });

      final exported = ownerClient.exportParties(
        partyType: 'CUSTOMER',
        includeSensitive: true,
      );
      expect(exported.length, equals(1));
      final c = exported.first;
      expect(c['phone'], equals('01811556677'));
      expect(c['email'], equals('karim@gmail.com'));
      expect(c['address'], equals('Gulshan 2'));
      expect(c['credit_limit_bdt'], equals('10000.00'));
    });

    test('3. Import preview identifies valid records and duplicate entries', () {
      ownerClient.seedCustomer({
        'customer_id': 'cust-03',
        'full_name': 'Existing Customer',
        'phone': '01700112233',
      });

      final batch = [
        {'full_name': 'New Customer A', 'phone': '01799887766'},
        {'full_name': 'Duplicate Person', 'phone': '01700112233'},
        {'full_name': '', 'phone': '01755443322'}, // Invalid (missing name)
      ];

      final preview = ownerClient.previewImport(partyType: 'CUSTOMER', records: batch);
      expect(preview.totalRecords, equals(3));
      expect(preview.validCount, equals(1));
      expect(preview.duplicateCount, equals(1));
      expect(preview.invalidCount, equals(1));
      expect(preview.previewItems[1].isDuplicate, isTrue);
      expect(preview.previewItems[2].isValid, isFalse);
    });

    test('4. Commit import with SKIP vs UPDATE resolution', () {
      ownerClient.seedCustomer({
        'customer_id': 'cust-04',
        'full_name': 'Original Name',
        'phone': '01712345678',
      });

      final batch = [
        {'full_name': 'New Guy', 'phone': '01912345678'},
        {'full_name': 'Updated Name', 'phone': '01712345678'},
      ];

      // Test SKIP
      final resSkip = ownerClient.commitImport(
        partyType: 'CUSTOMER',
        records: batch,
        duplicateResolution: 'SKIP',
      );
      expect(resSkip.createdCount, equals(1));
      expect(resSkip.skippedCount, equals(1));
      expect(resSkip.updatedCount, equals(0));

      // Test UPDATE
      final resUpdate = ownerClient.commitImport(
        partyType: 'CUSTOMER',
        records: batch,
        duplicateResolution: 'UPDATE',
      );
      expect(resUpdate.createdCount, equals(1));
      expect(resUpdate.updatedCount, equals(1));
      expect(resUpdate.skippedCount, equals(0));
    });

    test('5. Role enforcement: Cashier is strictly denied import/export', () {
      expect(
        () => cashierClient.exportParties(partyType: 'CUSTOMER'),
        throwsA(isA<PartyPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );

      expect(
        () => cashierClient.previewImport(
          partyType: 'CUSTOMER',
          records: [
            {'full_name': 'Test', 'phone': '01700000000'}
          ],
        ),
        throwsA(isA<PartyPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });
  });
}
