import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_user_identity_service.dart';

void main() {
  group('P042: Mobile User Identity Service Test Suite', () {
    test('Normalizes valid BD mobile numbers to E.164 standard', () {
      expect(MobileUserIdentity.normalizeBdPhone('01712345678'),
          equals('+8801712345678'));
      expect(MobileUserIdentity.normalizeBdPhone('+8801912345678'),
          equals('+8801912345678'));
      expect(MobileUserIdentity.normalizeBdPhone('01812-345678'),
          equals('+8801812345678'));
    });

    test('Rejects invalid phone numbers with FormatException', () {
      expect(() => MobileUserIdentity.normalizeBdPhone('123'),
          throwsFormatException);
      expect(() => MobileUserIdentity.normalizeBdPhone('01212345678'),
          throwsFormatException);
    });

    test('MobileUserIdentity verifies role and archival boundaries', () {
      const activeOwner = MobileUserIdentity(
        userId: 'usr-10',
        tenantId: 'tenant-dhaka',
        branchId: 'branch-1',
        email: 'owner@dhakapharmacy.com',
        phoneNumber: '+8801712345678',
        fullName: 'Kabir Ahmed',
        role: 'PHARMACY_OWNER',
        activationStatus: 'ACTIVE',
        isArchived: false,
      );

      expect(activeOwner.canAccessManagementKpis, isTrue);
      expect(activeOwner.canApprovePurchases, isTrue);

      const archivedOwner = MobileUserIdentity(
        userId: 'usr-11',
        tenantId: 'tenant-dhaka',
        branchId: 'branch-1',
        email: 'old@dhakapharmacy.com',
        phoneNumber: '+8801812345678',
        fullName: 'Old Owner',
        role: 'PHARMACY_OWNER',
        activationStatus: 'DEACTIVATED',
        isArchived: true,
      );

      expect(archivedOwner.canAccessManagementKpis, isFalse);
      expect(archivedOwner.canApprovePurchases, isFalse);
    });
  });
}
