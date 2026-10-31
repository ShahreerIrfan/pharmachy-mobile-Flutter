import 'dart:convert';

/// Flutter Mobile Manager MFA Client & Challenge Resolver.
/// Architecture Decision: ADR-0044 (MFA for Privileged Users).
class MobileMfaChallenge {
  final bool mfaRequired;
  final String challengeToken;
  final int expiresIn;
  final String method;
  final String userId;
  final String email;
  final String role;
  final int remainingAttempts;

  const MobileMfaChallenge({
    required this.mfaRequired,
    required this.challengeToken,
    required this.expiresIn,
    required this.method,
    required this.userId,
    required this.email,
    required this.role,
    this.remainingAttempts = 5,
  });

  factory MobileMfaChallenge.fromJson(Map<String, dynamic> json) {
    return MobileMfaChallenge(
      mfaRequired: json['mfa_required'] as bool? ?? false,
      challengeToken: json['challenge_token'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 300,
      method: json['method'] as String? ?? 'TOTP',
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      remainingAttempts: json['remaining_attempts'] as int? ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
        'mfa_required': mfaRequired,
        'challenge_token': challengeToken,
        'expires_in': expiresIn,
        'method': method,
        'user_id': userId,
        'email': email,
        'role': role,
        'remaining_attempts': remainingAttempts,
      };
}

class MobileMfaStatus {
  final bool mfaEnabled;
  final bool isMandatory;
  final bool isConfirmed;
  final int remainingRecoveryCodes;
  final DateTime? enrolledAt;

  const MobileMfaStatus({
    required this.mfaEnabled,
    required this.isMandatory,
    required this.isConfirmed,
    required this.remainingRecoveryCodes,
    this.enrolledAt,
  });

  factory MobileMfaStatus.fromJson(Map<String, dynamic> json) {
    return MobileMfaStatus(
      mfaEnabled: json['mfa_enabled'] as bool? ?? false,
      isMandatory: json['is_mandatory'] as bool? ?? false,
      isConfirmed: json['is_confirmed'] as bool? ?? false,
      remainingRecoveryCodes: json['remaining_recovery_codes'] as int? ?? 0,
      enrolledAt: json['enrolled_at'] != null
          ? DateTime.tryParse(json['enrolled_at'] as String)
          : null,
    );
  }
}

class MobileMfaClient {
  static const Set<String> _privilegedRoles = {
    'SUPERADMIN',
    'PLATFORM_OPERATOR',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
  };

  static bool isPrivileged(String role) {
    return _privilegedRoles.contains(role.trim().toUpperCase());
  }

  static bool validateTotpFormat(String code) {
    final clean = code.trim();
    return RegExp(r'^\d{6}$').hasMatch(clean);
  }

  static bool validateRecoveryCodeFormat(String code) {
    final clean = code.trim();
    return RegExp(r'^[A-Za-z0-9]{4}-[A-Za-z0-9]{4}$').hasMatch(clean);
  }

  static Map<String, String> getBilingualErrorMessage(String errorCode) {
    switch (errorCode.toUpperCase()) {
      case 'MFA_LOCKED_OUT':
        return {
          'en':
              'Too many failed MFA attempts. Account MFA verification locked for 15 minutes.',
          'bn':
              'অতিরিক্ত ভুল MFA চেষ্টার কারণে অ্যাকাউন্ট ১৫ মিনিটের জন্য সাময়িকভাবে লক করা হয়েছে।',
        };
      case 'INVALID_MFA_CODE':
        return {
          'en': 'Invalid MFA verification code.',
          'bn': 'ভুল MFA ভেরিফিকেশন কোড।',
        };
      case 'MFA_MANDATORY_FOR_PRIVILEGED_ROLE':
        return {
          'en':
              'MFA is strictly mandatory for privileged roles and cannot be disabled.',
          'bn':
              'প্রিভিলেজড ব্যবহারকারীদের জন্য MFA বাধ্যতামূলক এবং এটি নিষ্ক্রিয় করা যাবে না।',
        };
      case 'CROSS_TENANT_MFA_FORBIDDEN':
        return {
          'en': 'Cross-tenant MFA challenge exchange is strictly forbidden.',
          'bn': 'ক্রস-টেন্যান্ট MFA ভেরিফিকেশন কঠোরভাবে নিষিদ্ধ।',
        };
      default:
        return {
          'en': 'Authentication failure. Please contact support.',
          'bn': 'অথেনটিকেশন ব্যর্থ হয়েছে। অনুগ্রহ করে সাপোর্টে যোগাযোগ করুন।',
        };
    }
  }
}
