import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_inspection_evidence_client.dart';

void main() {
  group('P254: Mobile Inspection Evidence Client Tests', () {
    test('Role management and audit package export gates', () {
      expect(MobileInspectionEvidenceClient.canManageEvidence('SUPERADMIN'), isTrue);
      expect(MobileInspectionEvidenceClient.canManageEvidence('PHARMACY_OWNER'), isTrue);
      expect(MobileInspectionEvidenceClient.canManageEvidence('BRANCH_MANAGER'), isTrue);
      expect(MobileInspectionEvidenceClient.canManageEvidence('STAFF_PHARMACIST'), isTrue);
      expect(MobileInspectionEvidenceClient.canManageEvidence('CASHIER'), isFalse);

      expect(MobileInspectionEvidenceClient.canExportAuditPackage('PHARMACY_OWNER'), isTrue);
      expect(MobileInspectionEvidenceClient.canExportAuditPackage('BRANCH_MANAGER'), isTrue);
      expect(MobileInspectionEvidenceClient.canExportAuditPackage('STAFF_PHARMACIST'), isFalse);
      expect(MobileInspectionEvidenceClient.canExportAuditPackage('CASHIER'), isFalse);
    });

    test('Document access classification and tenant/branch boundaries', () {
      // Owner has access everywhere
      expect(
        MobileInspectionEvidenceClient.canAccessDocument(
          role: 'PHARMACY_OWNER',
          accessLevel: 'RESTRICTED',
          userBranchId: 'br-1',
          recordBranchId: 'br-2',
        ),
        isTrue,
      );

      // Manager has access in their own branch
      expect(
        MobileInspectionEvidenceClient.canAccessDocument(
          role: 'BRANCH_MANAGER',
          accessLevel: 'RESTRICTED',
          userBranchId: 'br-1',
          recordBranchId: 'br-1',
        ),
        isTrue,
      );
      expect(
        MobileInspectionEvidenceClient.canAccessDocument(
          role: 'BRANCH_MANAGER',
          accessLevel: 'RESTRICTED',
          userBranchId: 'br-1',
          recordBranchId: 'br-2',
        ),
        isFalse,
      );

      // Pharmacist can view CONFIDENTIAL in their branch, but not RESTRICTED
      expect(
        MobileInspectionEvidenceClient.canAccessDocument(
          role: 'STAFF_PHARMACIST',
          accessLevel: 'CONFIDENTIAL',
          userBranchId: 'br-1',
          recordBranchId: 'br-1',
        ),
        isTrue,
      );
      expect(
        MobileInspectionEvidenceClient.canAccessDocument(
          role: 'STAFF_PHARMACIST',
          accessLevel: 'RESTRICTED',
          userBranchId: 'br-1',
          recordBranchId: 'br-1',
        ),
        isFalse,
      );

      // Cashier can only view PUBLIC
      expect(
        MobileInspectionEvidenceClient.canAccessDocument(
          role: 'CASHIER',
          accessLevel: 'PUBLIC',
          userBranchId: 'br-1',
          recordBranchId: 'br-1',
        ),
        isTrue,
      );
      expect(
        MobileInspectionEvidenceClient.canAccessDocument(
          role: 'CASHIER',
          accessLevel: 'CONFIDENTIAL',
          userBranchId: 'br-1',
          recordBranchId: 'br-1',
        ),
        isFalse,
      );
    });

    test('Cold-chain temperature excursion logic (2°C - 8°C)', () {
      expect(
        MobileInspectionEvidenceClient.isColdChainExcursion(
          minTempCelsius: 3.5,
          maxTempCelsius: 6.2,
        ),
        isFalse,
      );
      expect(
        MobileInspectionEvidenceClient.isColdChainExcursion(
          minTempCelsius: 2.0,
          maxTempCelsius: 8.0,
        ),
        isFalse,
      );

      // Excursions
      expect(
        MobileInspectionEvidenceClient.isColdChainExcursion(
          minTempCelsius: 1.5,
          maxTempCelsius: 5.0,
        ),
        isTrue,
      );
      expect(
        MobileInspectionEvidenceClient.isColdChainExcursion(
          minTempCelsius: 4.0,
          maxTempCelsius: 9.2,
        ),
        isTrue,
      );
    });

    test('Preflight validation rules', () {
      final today = DateTime.now();
      const validHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

      expect(
        () => MobileInspectionEvidenceClient.validatePreflight(
          title: 'Daily Fridge Log',
          evidenceType: 'REFRIGERATOR_TEMPERATURE_LOG',
          logDate: today,
          documentUri: '/vault/evidence.pdf',
          sha256Hash: validHash,
        ),
        returnsNormally,
      );

      // Short title
      expect(
        () => MobileInspectionEvidenceClient.validatePreflight(
          title: 'AB',
          evidenceType: 'REFRIGERATOR_TEMPERATURE_LOG',
          logDate: today,
          documentUri: '/vault/evidence.pdf',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Future date
      expect(
        () => MobileInspectionEvidenceClient.validatePreflight(
          title: 'GPP Training',
          evidenceType: 'STAFF_TRAINING_PROOF',
          logDate: today.add(const Duration(days: 3)),
          documentUri: '/vault/evidence.pdf',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Localization and summary formatting', () {
      expect(
        MobileInspectionEvidenceClient.getEvidenceTypeDisplay(
          'REFRIGERATOR_TEMPERATURE_LOG',
          lang: 'bn',
        ),
        'রেফ্রিজারেটর তাপমাত্রা লগ (কোল্ড-চেইন)',
      );
      expect(
        MobileInspectionEvidenceClient.getEvidenceTypeDisplay(
          'STAFF_TRAINING_PROOF',
          lang: 'en',
        ),
        'Staff Training Proof / Certification',
      );

      final summary = MobileInspectionEvidenceClient.formatAuditPackageSummary(
        totalRecords: 12,
        excursionCount: 1,
        disposalBdt: '8400.00',
        lang: 'en',
      );
      expect(summary, contains('12 records'));
      expect(summary, contains('1 cold-chain excursions'));
      expect(summary, contains('8400.00'));
    });
  });
}

