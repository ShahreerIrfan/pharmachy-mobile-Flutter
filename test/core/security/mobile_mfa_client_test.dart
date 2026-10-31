import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_mfa_client.dart';

void main() {
  group('P044: Mobile MFA Client & Second-Factor Guard Tests', () {
    test('Privileged roles correctly identified for mandatory MFA', () {
      expect(MobileMfaClient.isPrivileged('SUPERADMIN'), isTrue);
      expect(MobileMfaClient.isPrivileged('PLATFORM_OPERATOR'), isTrue);
      expect(MobileMfaClient.isPrivileged('PHARMACY_OWNER'), isTrue);
      expect(MobileMfaClient.isPrivileged('BRANCH_MANAGER'), isTrue);
      expect(MobileMfaClient.isPrivileged('FINANCE_OFFICER'), isTrue);

      expect(MobileMfaClient.isPrivileged('CASHIER'), isFalse);
      expect(MobileMfaClient.isPrivileged('STAFF_PHARMACIST'), isFalse);
    });

    test('Validates 6-digit TOTP format', () {
      expect(MobileMfaClient.validateTotpFormat('123456'), isTrue);
      expect(MobileMfaClient.validateTotpFormat('000111'), isTrue);
      expect(MobileMfaClient.validateTotpFormat('12345'), isFalse);
      expect(MobileMfaClient.validateTotpFormat('1234567'), isFalse);
      expect(MobileMfaClient.validateTotpFormat('abc123'), isFalse);
    });

    test('Validates backup recovery code format (XXXX-XXXX)', () {
      expect(MobileMfaClient.validateRecoveryCodeFormat('ABCD-1234'), isTrue);
      expect(MobileMfaClient.validateRecoveryCodeFormat('1a2b-3c4d'), isTrue);
      expect(MobileMfaClient.validateRecoveryCodeFormat('ABCD1234'), isFalse);
      expect(MobileMfaClient.validateRecoveryCodeFormat('ABC-1234'), isFalse);
    });

    test('Parses MobileMfaChallenge from JSON conforming to ADR-0044', () {
      final jsonMap = {
        'mfa_required': true,
        'challenge_token': 'sec_challenge_99887766554433221100aabbcc',
        'expires_in': 300,
        'method': 'TOTP',
        'user_id': '88b560ce-0123-4567-89ab-cdef01234567',
        'email': 'owner@gulshanpharma.bd',
        'role': 'PHARMACY_OWNER',
        'remaining_attempts': 5,
      };

      final challenge = MobileMfaChallenge.fromJson(jsonMap);
      expect(challenge.mfaRequired, isTrue);
      expect(
          challenge.challengeToken, 'sec_challenge_99887766554433221100aabbcc');
      expect(challenge.expiresIn, 300);
      expect(challenge.email, 'owner@gulshanpharma.bd');
      expect(challenge.role, 'PHARMACY_OWNER');
      expect(challenge.remainingAttempts, 5);
    });

    test('Produces client-safe bilingual error messages', () {
      final lockout =
          MobileMfaClient.getBilingualErrorMessage('MFA_LOCKED_OUT');
      expect(lockout['en'], contains('Too many failed MFA attempts'));
      expect(lockout['bn'], contains('লক'));

      final mandatory = MobileMfaClient.getBilingualErrorMessage(
          'MFA_MANDATORY_FOR_PRIVILEGED_ROLE');
      expect(mandatory['en'], contains('mandatory'));
      expect(mandatory['bn'], contains('বাধ্যতামূলক'));
    });
  });
}
