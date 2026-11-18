// mobile_party_privacy_test.dart
// Architecture Decision: ADR-0279 (P279).
// Phase 14: Customers, Suppliers, Dues & Payments.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/parties/mobile_party_privacy_client.dart';

void main() {
  group('MobilePartyPrivacyClient Tests (P279)', () {
    const tenantId = 'ten-dhk-01';

    late MobilePartyPrivacyClient ownerClient;
    late MobilePartyPrivacyClient managerClient;
    late MobilePartyPrivacyClient cashierClient;

    setUp(() {
      ownerClient = MobilePartyPrivacyClient(
        tenantId: tenantId,
        userRole: 'PHARMACY_OWNER',
        userId: 'owner_01',
      );

      managerClient = MobilePartyPrivacyClient(
        tenantId: tenantId,
        userRole: 'BRANCH_MANAGER',
        userId: 'mgr_01',
      );

      cashierClient = MobilePartyPrivacyClient(
        tenantId: tenantId,
        userRole: 'CASHIER',
        userId: 'csh_01',
      );
    });

    test('1. Manager assesses retention policy detecting 2-yr Rx and 5-yr tax holds', () async {
      final res = await managerClient.assessRetention(
        partyType: 'CUSTOMER',
        partyId: 'cust-101',
        rxCount: 3,
        invoiceCount: 12,
        openDue: 0.0,
      );

      expect(res.partyType, equals('CUSTOMER'));
      expect(res.partyId, equals('cust-101'));
      expect(res.statutoryHoldActive, isTrue);
      expect(res.canPhysicallyErase, isFalse);
      expect(res.conflictsDetected.length, equals(2));
    });

    test('2. Anonymization blocked when open due balance exists', () async {
      expect(
        () => managerClient.anonymizePartyData(
          partyType: 'CUSTOMER',
          partyId: 'cust-102',
          reason: 'Customer requested erasure',
          openDue: 1500.0,
        ),
        throwsA(isA<PartyPrivacyValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_OPEN_DUE_BALANCE_HOLD'),
        )),
      );
    });

    test('3. Demographic correction succeeds with reason and updates phone', () async {
      final res = await managerClient.correctPartyData(
        partyType: 'CUSTOMER',
        partyId: 'cust-103',
        corrections: {
          'full_name': 'Kazi Nazrul Islam',
          'phone': '+8801711998877',
        },
        reason: 'Customer updated official mobile number',
      );

      expect(res.success, isTrue);
      expect(res.fullName, equals('Kazi Nazrul Islam'));
      expect(res.phone, equals('+8801711998877'));
      expect(res.auditId, isNotNull);
    });

    test('4. Audited irreversible anonymization pseudonymizes customer name', () async {
      final res = await ownerClient.anonymizePartyData(
        partyType: 'CUSTOMER',
        partyId: 'cust-104',
        reason: 'Right to be forgotten request under statutory hold',
        openDue: 0.0,
      );

      expect(res.success, isTrue);
      expect(res.isAnonymized, isTrue);
      expect(res.anonymizedName, contains('Anonymized Customer'));
    });

    test('5. Clinical dossier export denied for Manager and allowed for Owner', () async {
      // Manager denied clinical export
      expect(
        () => managerClient.exportRestrictedDossier(
          partyType: 'CUSTOMER',
          partyId: 'cust-105',
          classification: 'RESTRICTED_CLINICAL',
        ),
        throwsA(isA<PartyPrivacyPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_CLINICAL_EXPORT_DENIED'),
        )),
      );

      // Manager allowed standard export
      final stdDossier = await managerClient.exportRestrictedDossier(
        partyType: 'CUSTOMER',
        partyId: 'cust-105',
        classification: 'STANDARD',
      );
      expect(stdDossier.classification, equals('STANDARD'));
      expect(stdDossier.clinicalPrescriptions, isEmpty);

      // Owner allowed clinical export
      final clinicalDossier = await ownerClient.exportRestrictedDossier(
        partyType: 'CUSTOMER',
        partyId: 'cust-105',
        classification: 'RESTRICTED_CLINICAL',
      );
      expect(clinicalDossier.classification, equals('RESTRICTED_CLINICAL'));
      expect(clinicalDossier.clinicalPrescriptions.length, equals(1));
    });

    test('6. Cashier is strictly denied all privacy endpoints', () async {
      expect(
        () => cashierClient.assessRetention(partyType: 'CUSTOMER', partyId: 'cust-106'),
        throwsA(isA<PartyPrivacyPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );

      expect(
        () => cashierClient.correctPartyData(
          partyType: 'CUSTOMER',
          partyId: 'cust-106',
          corrections: {'full_name': 'Hacked'},
          reason: 'Test',
        ),
        throwsA(isA<PartyPrivacyPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });
  });
}
