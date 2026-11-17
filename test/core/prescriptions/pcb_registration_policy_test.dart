import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/pcb_registration_policy.dart';

void main() {
  group('P252: PCB Registration Policy Flutter Mobile Tests', () {
    test('Translates qualification grades to English and Bengali correctly', () {
      expect(
        PcbRegistrationPolicy.getGradeDisplay('GRADE_A', lang: 'en'),
        'Grade A (Graduate Pharmacist)',
      );
      expect(
        PcbRegistrationPolicy.getGradeDisplay('GRADE_A', lang: 'bn'),
        'এ-গ্রেড (গ্র্যাজুয়েট ফার্মাসিস্ট)',
      );

      expect(
        PcbRegistrationPolicy.getGradeDisplay('GRADE_B', lang: 'en'),
        'Grade B (Diploma Pharmacist)',
      );
      expect(
        PcbRegistrationPolicy.getGradeDisplay('GRADE_B', lang: 'bn'),
        'বি-গ্রেড (ডিপ্লোমা ফার্মাসিস্ট)',
      );

      expect(
        PcbRegistrationPolicy.getGradeDisplay('GRADE_C', lang: 'en'),
        'Grade C (Pharmacy Technician)',
      );
      expect(
        PcbRegistrationPolicy.getGradeDisplay('GRADE_C', lang: 'bn'),
        'সি-গ্রেড (ফার্মাসি টেকনিশিয়ান)',
      );
    });

    test('Translates status to localized strings correctly', () {
      expect(
        PcbRegistrationPolicy.getStatusDisplay('ACTIVE', lang: 'en'),
        'Active Valid',
      );
      expect(
        PcbRegistrationPolicy.getStatusDisplay('ACTIVE', lang: 'bn'),
        'সক্রিয় ও বৈধ',
      );

      expect(
        PcbRegistrationPolicy.getStatusDisplay('PENDING_RENEWAL', lang: 'en'),
        'Renewal Pending',
      );
      expect(
        PcbRegistrationPolicy.getStatusDisplay('PENDING_RENEWAL', lang: 'bn'),
        'নবায়ন প্রক্রিয়াধীন',
      );

      expect(
        PcbRegistrationPolicy.getStatusDisplay('EXPIRED', lang: 'en'),
        'Expired',
      );
      expect(
        PcbRegistrationPolicy.getStatusDisplay('EXPIRED', lang: 'bn'),
        'মেয়াদ উত্তীর্ণ',
      );
    });

    test('Restricts confidential evidence access to authorized roles or credential holder', () {
      // Superadmin and Owner have global access
      expect(
        PcbRegistrationPolicy.canAccessEvidence(
          userRole: 'SUPERADMIN',
          isSelf: false,
          isOwnBranch: false,
        ),
        isTrue,
      );
      expect(
        PcbRegistrationPolicy.canAccessEvidence(
          userRole: 'PHARMACY_OWNER',
          isSelf: false,
          isOwnBranch: false,
        ),
        isTrue,
      );

      // Branch Manager has access only for their branch
      expect(
        PcbRegistrationPolicy.canAccessEvidence(
          userRole: 'BRANCH_MANAGER',
          isSelf: false,
          isOwnBranch: true,
        ),
        isTrue,
      );
      expect(
        PcbRegistrationPolicy.canAccessEvidence(
          userRole: 'BRANCH_MANAGER',
          isSelf: false,
          isOwnBranch: false,
        ),
        isFalse,
      );

      // Credential holder always has access
      expect(
        PcbRegistrationPolicy.canAccessEvidence(
          userRole: 'STAFF_PHARMACIST',
          isSelf: true,
          isOwnBranch: false,
        ),
        isTrue,
      );

      // Cashier and other non-manager staff are denied
      expect(
        PcbRegistrationPolicy.canAccessEvidence(
          userRole: 'CASHIER',
          isSelf: false,
          isOwnBranch: true,
        ),
        isFalse,
      );
      expect(
        PcbRegistrationPolicy.canAccessEvidence(
          userRole: 'STAFF_PHARMACIST',
          isSelf: false,
          isOwnBranch: true,
        ),
        isFalse,
      );
    });

    test('Validates Grade A active credential requirement for clinical overrides', () {
      expect(
        PcbRegistrationPolicy.isAuthorizedForClinicalOverrides(
          grade: 'GRADE_A',
          status: 'ACTIVE',
        ),
        isTrue,
      );
      expect(
        PcbRegistrationPolicy.isAuthorizedForClinicalOverrides(
          grade: 'GRADE_A',
          status: 'PENDING_RENEWAL',
        ),
        isTrue,
      );

      expect(
        PcbRegistrationPolicy.isAuthorizedForClinicalOverrides(
          grade: 'GRADE_A',
          status: 'EXPIRED',
        ),
        isFalse,
      );
      expect(
        PcbRegistrationPolicy.isAuthorizedForClinicalOverrides(
          grade: 'GRADE_B',
          status: 'ACTIVE',
        ),
        isFalse,
      );
    });

    test('Accurately computes days until expiry and urgent renewal flags', () {
      final today = DateTime(2026, 11, 17);
      final validFuture = DateTime(2026, 11, 27); // 10 days
      final expiredPast = DateTime(2026, 11, 10); // -7 days

      final daysLeft = PcbRegistrationPolicy.daysUntilExpiry(validFuture, today);
      expect(daysLeft, 10);
      expect(PcbRegistrationPolicy.isExpiringSoon(daysLeft), isTrue);

      final daysExpired = PcbRegistrationPolicy.daysUntilExpiry(expiredPast, today);
      expect(daysExpired, -7);
      expect(PcbRegistrationPolicy.isExpiringSoon(daysExpired), isFalse);
    });
  });
}

