// lib/core/billing/mobile_signed_offline_entitlement_client.dart
// Architecture Decision: ADR-0007, ADR-0015, ADR-0082, ADR-0092 & ADR-0093
// Phase 05: Basic/Standard/Pro Subscription & Billing (P093)
// Requirement Trace: FR-071 (SaaS Plans, Billing & Tenant Lifecycle)

enum MobileOfflineLeaseStatus {
  active,
  revoked,
  expired,
  superseded,
  unknown,
}

class MobileOfflineClientMessaging {
  final String headlineEn;
  final String headlineBn;
  final String detailsEn;
  final String detailsBn;

  const MobileOfflineClientMessaging({
    required this.headlineEn,
    required this.headlineBn,
    required this.detailsEn,
    required this.detailsBn,
  });

  factory MobileOfflineClientMessaging.fromJson(Map<String, dynamic> json) {
    return MobileOfflineClientMessaging(
      headlineEn: json['headline_en'] as String? ?? 'Offline Lease Active',
      headlineBn: json['headline_bn'] as String? ?? 'অফলাইন ইজারা সক্রিয়',
      detailsEn: json['details_en'] as String? ?? '',
      detailsBn: json['details_bn'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'headline_en': headlineEn,
        'headline_bn': headlineBn,
        'details_en': detailsEn,
        'details_bn': detailsBn,
      };
}

class MobileDeviceLeaseCertificate {
  final String leaseId;
  final String tenantId;
  final String branchId;
  final String deviceId;
  final String deviceName;
  final String roleSnapshot;
  final String planTier;
  final String policyVersion;
  final int durationHours;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final Map<String, bool> capabilitiesSnapshot;
  final String signatureAlgorithm;
  final String signature;
  final MobileOfflineLeaseStatus status;
  final MobileOfflineClientMessaging clientMessaging;

  const MobileDeviceLeaseCertificate({
    required this.leaseId,
    required this.tenantId,
    required this.branchId,
    required this.deviceId,
    required this.deviceName,
    required this.roleSnapshot,
    required this.planTier,
    required this.policyVersion,
    required this.durationHours,
    required this.issuedAt,
    required this.expiresAt,
    required this.capabilitiesSnapshot,
    required this.signatureAlgorithm,
    required this.signature,
    required this.status,
    required this.clientMessaging,
  });

  factory MobileDeviceLeaseCertificate.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] as String? ?? '').toUpperCase().trim();
    MobileOfflineLeaseStatus parsedStatus;
    switch (statusStr) {
      case 'ACTIVE':
        parsedStatus = MobileOfflineLeaseStatus.active;
        break;
      case 'REVOKED':
        parsedStatus = MobileOfflineLeaseStatus.revoked;
        break;
      case 'EXPIRED':
        parsedStatus = MobileOfflineLeaseStatus.expired;
        break;
      case 'SUPERSEDED':
        parsedStatus = MobileOfflineLeaseStatus.superseded;
        break;
      default:
        parsedStatus = MobileOfflineLeaseStatus.unknown;
    }

    final rawCaps = json['capabilities_snapshot'] as Map<String, dynamic>? ?? {};
    final parsedCaps = <String, bool>{};
    rawCaps.forEach((k, v) {
      parsedCaps[k] = v == true;
    });

    final messagingJson = json['client_messaging'] as Map<String, dynamic>? ?? {};

    return MobileDeviceLeaseCertificate(
      leaseId: json['lease_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? '',
      roleSnapshot: (json['role_snapshot'] as String? ?? 'CASHIER').toUpperCase(),
      planTier: (json['plan_tier'] as String? ?? 'BASIC').toUpperCase(),
      policyVersion: json['policy_version'] as String? ?? 'v2.0',
      durationHours: (json['duration_hours'] as num?)?.toInt() ?? 72,
      issuedAt: DateTime.tryParse(json['issued_at'] as String? ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ?? DateTime.now(),
      capabilitiesSnapshot: parsedCaps,
      signatureAlgorithm: json['signature_algorithm'] as String? ?? 'HMAC-SHA256',
      signature: json['signature'] as String? ?? '',
      status: parsedStatus,
      clientMessaging: MobileOfflineClientMessaging.fromJson(messagingJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'lease_id': leaseId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'device_id': deviceId,
        'device_name': deviceName,
        'role_snapshot': roleSnapshot,
        'plan_tier': planTier,
        'policy_version': policyVersion,
        'duration_hours': durationHours,
        'issued_at': issuedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'capabilities_snapshot': capabilitiesSnapshot,
        'signature_algorithm': signatureAlgorithm,
        'signature': signature,
        'status': status.name.toUpperCase(),
        'client_messaging': clientMessaging.toJson(),
      };

  bool isExpired([DateTime? now]) {
    final current = now ?? DateTime.now();
    return current.isAfter(expiresAt) || current.isAtSameMomentAs(expiresAt);
  }

  int hoursRemaining([DateTime? now]) {
    final current = now ?? DateTime.now();
    if (isExpired(current)) return 0;
    return expiresAt.difference(current).inHours;
  }

  bool get canDispenseOffline {
    if (status != MobileOfflineLeaseStatus.active) return false;
    if (isExpired()) return false;
    return capabilitiesSnapshot['CHECKOUT_DISPENSING'] ?? true;
  }
}
