// lib/core/security/mobile_password_recovery_client.dart
// Architecture Decision: ADR-0114 (P114)
// Phase 06: Milestone M03 - Offline-First Desktop POS & Owner Visibility.

enum MobilePasswordRecoveryUiStatus {
  idle,
  loading,
  success,
  error,
  permissionDenied,
  throttled,
  offline,
}

class MobilePasswordStrengthResult {
  final bool isValid;
  final int score;
  final List<String> missingRequirements;

  const MobilePasswordStrengthResult({
    required this.isValid,
    required this.score,
    required this.missingRequirements,
  });
}

class MobilePasswordRecoveryResponse {
  final MobilePasswordRecoveryUiStatus uiStatus;
  final String status;
  final bool tokenValid;
  final int? expiresInSeconds;
  final String? userEmail;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobilePasswordRecoveryResponse({
    required this.uiStatus,
    required this.status,
    this.tokenValid = false,
    this.expiresInSeconds,
    this.userEmail,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobilePasswordRecoveryResponse.dispatched() {
    return const MobilePasswordRecoveryResponse(
      uiStatus: MobilePasswordRecoveryUiStatus.success,
      status: 'DISPATCHED',
      messageEn: 'If the account exists, password reset instructions have been dispatched.',
      messageBn: 'অ্যাকাউন্টটি বিদ্যমান থাকলে পাসওয়ার্ড রিসেট নির্দেশাবলী পাঠানো হয়েছে।',
    );
  }

  factory MobilePasswordRecoveryResponse.tokenValid({
    required String email,
    required int expiresSec,
  }) {
    return MobilePasswordRecoveryResponse(
      uiStatus: MobilePasswordRecoveryUiStatus.success,
      status: 'VALID_TOKEN',
      tokenValid: true,
      userEmail: email,
      expiresInSeconds: expiresSec,
      messageEn: 'Token is valid. You may proceed.',
      messageBn: 'টোকেনটি বৈধ। নতুন পাসওয়ার্ড সেট করতে পারেন।',
    );
  }

  factory MobilePasswordRecoveryResponse.success() {
    return const MobilePasswordRecoveryResponse(
      uiStatus: MobilePasswordRecoveryUiStatus.success,
      status: 'SUCCESS',
      messageEn: 'Password has been reset successfully. Please log in.',
      messageBn: 'পাসওয়ার্ড সফলভাবে পরিবর্তিত হয়েছে। অনুগ্রহ করে লগইন করুন।',
    );
  }

  factory MobilePasswordRecoveryResponse.error({
    required MobilePasswordRecoveryUiStatus status,
    required String errorCode,
    required String msgEn,
    required String msgBn,
  }) {
    return MobilePasswordRecoveryResponse(
      uiStatus: status,
      status: 'ERROR',
      errorCode: errorCode,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobilePasswordRecoveryClient {
  static final _upperRegex = RegExp(r'[A-Z]');
  static final _lowerRegex = RegExp(r'[a-z]');
  static final _digitRegex = RegExp(r'\d');
  static final _specialRegex = RegExp(r'[\W_]');

  MobilePasswordStrengthResult evaluatePasswordStrength(String password) {
    final missing = <String>[];
    int score = 0;

    if (password.length >= 8) {
      score++;
    } else {
      missing.add('Must be at least 8 characters');
    }

    if (_upperRegex.hasMatch(password)) {
      score++;
    } else {
      missing.add('Must contain at least 1 uppercase letter');
    }

    if (_lowerRegex.hasMatch(password)) {
      score++;
    } else {
      missing.add('Must contain at least 1 lowercase letter');
    }

    if (_digitRegex.hasMatch(password)) {
      score++;
    } else {
      missing.add('Must contain at least 1 number');
    }

    if (_specialRegex.hasMatch(password)) {
      score++;
    } else {
      missing.add('Must contain at least 1 special character');
    }

    return MobilePasswordStrengthResult(
      isValid: score == 5,
      score: score,
      missingRequirements: missing,
    );
  }

  MobilePasswordRecoveryResponse validateResetRequest(String identifier) {
    if (identifier.trim().isEmpty) {
      return MobilePasswordRecoveryResponse.error(
        status: MobilePasswordRecoveryUiStatus.error,
        errorCode: 'INVALID_PAYLOAD',
        msgEn: 'Identifier (email or phone) is required.',
        msgBn: 'ইমেইল বা ফোন নম্বর আবশ্যক।',
      );
    }
    return MobilePasswordRecoveryResponse.dispatched();
  }

  MobilePasswordRecoveryResponse validateConfirmation({
    required String token,
    required String newPassword,
  }) {
    if (token.trim().isEmpty) {
      return MobilePasswordRecoveryResponse.error(
        status: MobilePasswordRecoveryUiStatus.error,
        errorCode: 'INVALID_RESET_TOKEN',
        msgEn: 'Password reset token is missing.',
        msgBn: 'রিসেট টোকেন অনুপস্থিত।',
      );
    }

    final strength = evaluatePasswordStrength(newPassword);
    if (!strength.isValid) {
      return MobilePasswordRecoveryResponse.error(
        status: MobilePasswordRecoveryUiStatus.error,
        errorCode: 'ERR_WEAK_PASSWORD',
        msgEn: strength.missingRequirements.join(', '),
        msgBn: 'পাসওয়ার্ড নীতি পূরণ করেনি।',
      );
    }

    return MobilePasswordRecoveryResponse.success();
  }
}

