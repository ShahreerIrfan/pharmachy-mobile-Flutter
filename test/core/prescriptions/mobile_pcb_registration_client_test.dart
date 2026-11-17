import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_pcb_registration_client.dart';

void main() {
  group('MobilePcbRegistrationClient Tests (P252)', () {
    test('Role management authorization & evidence access restrictions', () {
      // Manage authorization
      expect(MobilePcbRegistrationClient.isRoleAuthorizedToManage('SUPERADMIN'), isTrue);
      expect(MobilePcbRegistrationClient.isRoleAuthorizedToManage('PHARMACY_OWNER'), isTrue);
      expect(MobilePcbRegistrationClient.isRoleAuthorizedToManage('BRANCH_MANAGER'), isTrue);
      expect(MobilePcbRegistrationClient.isRoleAuthorizedToManage('STAFF_PHARMACIST'), isFalse);
      expect(MobilePcbRegistrationClient.isRoleAuthorizedToManage('CASHIER'), isFalse);
      expect(MobilePcbRegistrationClient.isRoleAuthorizedToManage(null), isFalse);

      // Evidence access clearance
      expect(MobilePcbRegistrationClient.canViewEvidence(userRole: 'SUPERADMIN', isSelf: false), isTrue);
      expect(MobilePcbRegistrationClient.canViewEvidence(userRole: 'PHARMACY_OWNER', isSelf: false), isTrue);
      expect(MobilePcbRegistrationClient.canViewEvidence(userRole: 'BRANCH_MANAGER', isSelf: false), isTrue);
      expect(MobilePcbRegistrationClient.canViewEvidence(userRole: 'CASHIER', isSelf: false), isFalse);
      expect(MobilePcbRegistrationClient.canViewEvidence(userRole: 'STAFF_PHARMACIST', isSelf: false), isFalse);
      expect(MobilePcbRegistrationClient.canViewEvidence(userRole: 'STAFF_PHARMACIST', isSelf: true), isTrue);
    });

    test('Grade hierarchy authorization (Grade A > B > C)', () {
      // Grade A can do Grade A, B, C
      expect(
        MobilePcbRegistrationClient.isGradeAuthorized(
          registrantGrade: PcbGrade.gradeA,
          requiredGrade: PcbGrade.gradeA,
        ),
        isTrue,
      );
      expect(
        MobilePcbRegistrationClient.isGradeAuthorized(
          registrantGrade: PcbGrade.gradeA,
          requiredGrade: PcbGrade.gradeB,
        ),
        isTrue,
      );

      // Grade B cannot do Grade A actions
      expect(
        MobilePcbRegistrationClient.isGradeAuthorized(
          registrantGrade: PcbGrade.gradeB,
          requiredGrade: PcbGrade.gradeA,
        ),
        isFalse,
      );
      expect(
        MobilePcbRegistrationClient.isGradeAuthorized(
          registrantGrade: PcbGrade.gradeB,
          requiredGrade: PcbGrade.gradeB,
        ),
        isTrue,
      );

      // Grade C can only do Grade C
      expect(
        MobilePcbRegistrationClient.isGradeAuthorized(
          registrantGrade: PcbGrade.gradeC,
          requiredGrade: PcbGrade.gradeA,
        ),
        isFalse,
      );
      expect(
        MobilePcbRegistrationClient.isGradeAuthorized(
          registrantGrade: PcbGrade.gradeC,
          requiredGrade: PcbGrade.gradeB,
        ),
        isFalse,
      );
      expect(
        MobilePcbRegistrationClient.isGradeAuthorized(
          registrantGrade: PcbGrade.gradeC,
          requiredGrade: PcbGrade.gradeC,
        ),
        isTrue,
      );
    });

    test('Evaluation states and renewal handling', () {
      // Active
      final active = MobilePcbRegistrationClient.evaluateRegistration(
        status: PcbStatus.active,
        daysUntilExpiry: 120,
      );
      expect(active.isValid, isTrue);
      expect(active.statusCode, 'ACTIVE');

      // Expiring soon
      final expiring = MobilePcbRegistrationClient.evaluateRegistration(
        status: PcbStatus.active,
        daysUntilExpiry: 10,
      );
      expect(expiring.isValid, isTrue);
      expect(expiring.statusCode, 'EXPIRING_SOON');
      expect(expiring.messageEn, contains('10 days'));
      expect(expiring.messageBn, contains('10 দিন'));

      // Expired without renewal
      final expired = MobilePcbRegistrationClient.evaluateRegistration(
        status: PcbStatus.expired,
        daysUntilExpiry: -1,
      );
      expect(expired.isValid, isFalse);
      expect(expired.statusCode, 'EXPIRED');

      // Pending renewal
      final renewal = MobilePcbRegistrationClient.evaluateRegistration(
        status: PcbStatus.pendingRenewal,
        daysUntilExpiry: -5,
      );
      expect(renewal.isValid, isTrue);
      expect(renewal.statusCode, 'PENDING_RENEWAL');

      // Suspended
      final suspended = MobilePcbRegistrationClient.evaluateRegistration(
        status: PcbStatus.suspended,
        daysUntilExpiry: 30,
      );
      expect(suspended.isValid, isFalse);
      expect(suspended.statusCode, 'SUSPENDED');
    });

    test('Preflight validation checks min lengths and dates', () {
      expect(
        MobilePcbRegistrationClient.validatePreflight(
          registrationNo: 'A-12845',
          registeredName: 'Md. Tanvir Hasan',
          issueDateStr: '2020-01-01',
          validUntilStr: '2026-12-31',
        ),
        isTrue,
      );

      // Short registration number
      expect(
        MobilePcbRegistrationClient.validatePreflight(
          registrationNo: 'A',
          registeredName: 'Md. Tanvir',
          issueDateStr: '2020-01-01',
          validUntilStr: '2026-12-31',
        ),
        isFalse,
      );

      // Inverted dates
      expect(
        MobilePcbRegistrationClient.validatePreflight(
          registrationNo: 'A-12845',
          registeredName: 'Md. Tanvir',
          issueDateStr: '2026-12-31',
          validUntilStr: '2020-01-01',
        ),
        isFalse,
      );
    });

    test('Grade localization labels', () {
      expect(PcbGrade.gradeA.getLocalizedLabel('bn'), contains('এ-গ্রেড'));
      expect(PcbGrade.gradeA.getLocalizedLabel('en'), contains('Grade A'));
      expect(PcbGrade.gradeB.getLocalizedLabel('bn'), contains('বি-গ্রেড'));
      expect(PcbGrade.gradeC.getLocalizedLabel('bn'), contains('সি-গ্রেড'));
    });
  });
}

