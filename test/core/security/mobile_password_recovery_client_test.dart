// test/core/security/mobile_password_recovery_client_test.dart
// Unit tests for P114 MobilePasswordRecoveryClient (ADR-0114).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_password_recovery_client.dart';

void main() {
  group('P114: MobilePasswordRecoveryClient Tests', () {
    late MobilePasswordRecoveryClient client;

    setUp(() {
      client = MobilePasswordRecoveryClient();
    });

    test('P114: Strong password passes all 5 criteria with score 5', () {
      final res = client.evaluatePasswordStrength('SecurePass123!#');
      expect(res.isValid, isTrue);
      expect(res.score, equals(5));
      expect(res.missingRequirements.isEmpty, isTrue);
    });

    test('P114: Short or missing symbol password fails with specific missing requirements', () {
      final res = client.evaluatePasswordStrength('Short1');
      expect(res.isValid, isFalse);
      expect(res.missingRequirements.contains('Must be at least 8 characters'), isTrue);
      expect(res.missingRequirements.contains('Must contain at least 1 special character'), isTrue);
    });

    test('P114: Empty identifier fails reset request validation', () {
      final res = client.validateResetRequest('');
      expect(res.uiStatus, equals(MobilePasswordRecoveryUiStatus.error));
      expect(res.errorCode, equals('INVALID_PAYLOAD'));
    });

    test('P114: Valid confirmation with token and strong password succeeds', () {
      final res = client.validateConfirmation(
        token: 'valid-reset-token-999',
        newPassword: 'StrongPass2026!#',
      );
      expect(res.uiStatus, equals(MobilePasswordRecoveryUiStatus.success));
      expect(res.status, equals('SUCCESS'));
    });

    test('P114: Weak password on confirmation fails with ERR_WEAK_PASSWORD', () {
      final res = client.validateConfirmation(
        token: 'valid-reset-token-999',
        newPassword: 'password',
      );
      expect(res.uiStatus, equals(MobilePasswordRecoveryUiStatus.error));
      expect(res.errorCode, equals('ERR_WEAK_PASSWORD'));
    });
  });
}

