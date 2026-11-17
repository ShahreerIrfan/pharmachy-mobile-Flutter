import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_regulatory_reference_client.dart';

void main() {
  group('MobileRegulatoryReferenceClient Tests', () {
    test('enforces role authorization for reference management and reading', () {
      expect(MobileRegulatoryReferenceClient.canManageReference('SUPERADMIN'), isTrue);
      expect(MobileRegulatoryReferenceClient.canManageReference('PHARMACY_OWNER'), isTrue);
      expect(MobileRegulatoryReferenceClient.canManageReference('BRANCH_MANAGER'), isTrue);
      expect(MobileRegulatoryReferenceClient.canManageReference('STAFF_PHARMACIST'), isTrue);
      expect(MobileRegulatoryReferenceClient.canManageReference('CASHIER'), isFalse);
      expect(MobileRegulatoryReferenceClient.canManageReference(null), isFalse);

      expect(MobileRegulatoryReferenceClient.canViewReference('CASHIER'), isTrue);
      expect(MobileRegulatoryReferenceClient.canViewReference('GUEST'), isFalse);
    });

    test('validates regulatory reference input attributes correctly', () {
      expect(
        () => MobileRegulatoryReferenceClient.validateReferenceData(
          title: 'DGDA PMS Guideline',
          sourceUri: 'https://dgda.gov.bd/pms.pdf',
          version: '2024.1',
          effectiveDate: '2024-01-01',
          nextReviewDate: '2025-01-01',
        ),
        returnsNormally,
      );

      // Short title
      expect(
        () => MobileRegulatoryReferenceClient.validateReferenceData(
          title: 'DG',
          sourceUri: 'https://dgda.gov.bd/pms.pdf',
          version: '2024.1',
          effectiveDate: '2024-01-01',
          nextReviewDate: '2025-01-01',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Invalid URI
      expect(
        () => MobileRegulatoryReferenceClient.validateReferenceData(
          title: 'DGDA PMS Guideline',
          sourceUri: 'ftp-not-valid://dgda.gov.bd',
          version: '2024.1',
          effectiveDate: '2024-01-01',
          nextReviewDate: '2025-01-01',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Inverted review dates
      expect(
        () => MobileRegulatoryReferenceClient.validateReferenceData(
          title: 'DGDA PMS Guideline',
          sourceUri: 'https://dgda.gov.bd/pms.pdf',
          version: '2024.1',
          effectiveDate: '2025-05-01',
          nextReviewDate: '2025-01-01',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('evaluates overdue review status accurately', () {
      expect(
        MobileRegulatoryReferenceClient.isReviewOverdue('2024-06-01', '2024-11-01'),
        isTrue,
      );
      expect(
        MobileRegulatoryReferenceClient.isReviewOverdue('2025-06-01', '2024-11-01'),
        isFalse,
      );
    });

    test('formats bilingual badges and jurisdiction displays', () {
      final badgeBn = MobileRegulatoryReferenceClient.formatStatusBadge(
        jurisdiction: 'DGDA_BANGLADESH',
        version: '1.2',
        status: 'ACTIVE',
        isOverdue: true,
        lang: 'bn',
      );
      expect(badgeBn, contains('মেয়াদোত্তীর্ণ পর্যালোচনা'));
      expect(badgeBn, contains('ডিজিডিএ (বাংলাদেশ)'));

      final badgeEn = MobileRegulatoryReferenceClient.formatStatusBadge(
        jurisdiction: 'DGDA_BANGLADESH',
        version: '1.2',
        status: 'ACTIVE',
        isOverdue: false,
        lang: 'en',
      );
      expect(badgeEn, contains('[ACTIVE]'));
      expect(badgeEn, contains('DGDA (Bangladesh)'));
    });
  });
}
