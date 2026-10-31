import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_auth_client.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_user_identity_service.dart';

void main() {
  group('P043: Mobile Auth Client & Token Lifecycle Test Suite', () {
    test('MobileAuthTokens parses session and validates fresh tokens', () {
      const user = MobileUserIdentity(
        userId: 'usr-mob-1',
        tenantId: 'tenant-uttara',
        branchId: 'branch-1',
        email: 'manager@uttarapharmacy.com',
        phoneNumber: '+8801712345678',
        fullName: 'Mahbub Alam',
        role: 'BRANCH_MANAGER',
        activationStatus: 'ACTIVE',
        isArchived: false,
      );

      final tokens = MobileAuthTokens(
        accessToken: 'access-jwt-123',
        refreshToken: 'refresh-jwt-456',
        expiresIn: 900,
        issuedAt: DateTime.now().toUtc(),
        user: user,
      );

      expect(tokens.accessToken, equals('access-jwt-123'));
      expect(tokens.tokenType, equals('Bearer'));
      expect(tokens.isExpired, isFalse);
      expect(tokens.user.tenantId, equals('tenant-uttara'));

      final json = tokens.toJson();
      expect(json['access'], equals('access-jwt-123'));
      expect(json['expires_in'], equals(900));
    });

    test('MobileAuthError validates client-safe bilingual messages', () {
      const error = MobileAuthError(
        errorCode: 'INVALID_CREDENTIALS',
        messageEn: 'Invalid email/phone or password.',
        messageBn: 'ভুল ইমেইল/ফোন অথবা পাসওয়ার্ড।',
      );

      expect(error.isClientSafe, isTrue);
      expect(error.errorCode, equals('INVALID_CREDENTIALS'));
      expect(error.messageBn, contains('পাসওয়ার্ড'));
    });
  });
}
