/// Flutter Mobile Manager Session & Token Rotation Client Service.
/// Architecture Decision: ADR-0045 (Session & Token Rotation, Device Binding & Replay Detection).
class MobileSession {
  final String sessionId;
  final String userId;
  final String tenantId;
  final String deviceId;
  final String deviceName;
  final String clientPlatform;
  final String? ipAddress;
  final bool isActive;
  final bool isCurrent;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;

  const MobileSession({
    required this.sessionId,
    required this.userId,
    required this.tenantId,
    required this.deviceId,
    this.deviceName = '',
    this.clientPlatform = 'MOBILE_MANAGER',
    this.ipAddress,
    this.isActive = true,
    this.isCurrent = false,
    this.lastSeenAt,
    this.createdAt,
  });

  factory MobileSession.fromJson(Map<String, dynamic> json) {
    return MobileSession(
      sessionId: json['session_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? '',
      clientPlatform: json['client_platform'] as String? ?? 'MOBILE_MANAGER',
      ipAddress: json['ip_address'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      isCurrent: json['is_current'] as bool? ?? false,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'user_id': userId,
        'tenant_id': tenantId,
        'device_id': deviceId,
        'device_name': deviceName,
        'client_platform': clientPlatform,
        'ip_address': ipAddress,
        'is_active': isActive,
        'is_current': isCurrent,
        'last_seen_at': lastSeenAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };
}

class MobileSessionService {
  static bool validateDeviceBinding(
      String sessionDeviceId, String currentDeviceId) {
    return sessionDeviceId.trim().toLowerCase() ==
        currentDeviceId.trim().toLowerCase();
  }

  static bool isReplayError(String errorCode) {
    return errorCode.trim().toUpperCase() == 'TOKEN_REPLAY_DETECTED';
  }

  static Map<String, String> getBilingualErrorMessage(String errorCode) {
    switch (errorCode.toUpperCase()) {
      case 'TOKEN_REPLAY_DETECTED':
        return {
          'en':
              'Token replay attack detected. All active sessions in this family have been revoked.',
          'bn':
              'টোকেন রিপ্লে আক্রমণ সনাক্ত হয়েছে। এই সেশনের সকল অ্যাক্টিভ টোকেন বাতিল করা হয়েছে।',
        };
      case 'DEVICE_BINDING_MISMATCH':
        return {
          'en':
              'Device binding verification failed. Session is bound to a different terminal.',
          'bn':
              'ডিভাইস বাইন্ডিং যাচাইকরণ ব্যর্থ হয়েছে। সেশনটি অন্য টার্মিনালের সাথে যুক্ত।',
        };
      case 'CROSS_TENANT_SESSION_ACCESS_DENIED':
        return {
          'en': 'Cross-tenant session access is strictly denied.',
          'bn': 'ক্রস-টেন্যান্ট সেশন অ্যাক্সেস কঠোরভাবে নিষিদ্ধ।',
        };
      case 'SESSION_REVOKED':
        return {
          'en': 'Session has been terminated. Please log in again.',
          'bn': 'সেশন বাতিল করা হয়েছে। দয়া করে পুনরায় লগইন করুন।',
        };
      default:
        return {
          'en': 'Authentication failure. Please contact support.',
          'bn': 'অথেনটিকেশন ব্যর্থ হয়েছে। অনুগ্রহ করে সাপোর্টে যোগাযোগ করুন।',
        };
    }
  }
}
