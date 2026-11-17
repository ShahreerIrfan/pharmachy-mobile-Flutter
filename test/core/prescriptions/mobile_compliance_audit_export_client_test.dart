import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_compliance_audit_export_client.dart';

void main() {
  group('P258: Mobile Compliance Audit Export Client Tests', () {
    test('Role authorization gates for audit package export', () {
      expect(MobileComplianceAuditExportClient.canExportAuditPackage('STAFF_PHARMACIST'), isTrue);
      expect(MobileComplianceAuditExportClient.canExportAuditPackage('BRANCH_MANAGER'), isTrue);
      expect(MobileComplianceAuditExportClient.canExportAuditPackage('PHARMACY_OWNER'), isTrue);
      expect(MobileComplianceAuditExportClient.canExportAuditPackage('SUPERADMIN'), isTrue);

      expect(MobileComplianceAuditExportClient.canExportAuditPackage('CASHIER'), isFalse);
      expect(MobileComplianceAuditExportClient.canExportAuditPackage(null), isFalse);
    });

    test('Patient privacy redaction properly masks names and phone numbers', () {
      expect(MobileComplianceAuditExportClient.maskPatientName('Mohammad Rahim'), equals('M*** R***'));
      expect(MobileComplianceAuditExportClient.maskPatientName(null), equals('P-ANONYMOUS'));

      expect(
        MobileComplianceAuditExportClient.maskPhoneNumber('+8801712345678'),
        equals('+88017****5678'),
      );
      expect(MobileComplianceAuditExportClient.maskPhoneNumber(null), equals('N/A'));
    });

    test('Date range validation correctly enforces start <= end', () {
      expect(
        () => MobileComplianceAuditExportClient.validateDateRange('2026-01-01', '2026-01-31'),
        returnsNormally,
      );
      expect(
        () => MobileComplianceAuditExportClient.validateDateRange('2026-02-01', '2026-01-01'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Scope localization and display formatting', () {
      expect(
        MobileComplianceAuditExportClient.formatScopeDisplay('ANTIBIOTIC_STEWARDSHIP', lang: 'en'),
        equals('Antibiotic Register Audit'),
      );
      expect(
        MobileComplianceAuditExportClient.formatScopeDisplay('ANTIBIOTIC_STEWARDSHIP', lang: 'bn'),
        equals('অ্যান্টিবায়োটিক রেজিস্টার অডিট'),
      );
    });
  });
}
