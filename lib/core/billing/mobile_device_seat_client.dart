// lib/core/billing/mobile_device_seat_client.dart
// Architecture Decision: ADR-0007, ADR-0081, ADR-0082, ADR-0095 & ADR-0096
// Phase 05: Basic/Standard/Pro Subscription & Billing (P096)
// Requirement Trace: FR-004, FR-070, FR-071, FR-072 (Authoritative Device Seats & Lease Invalidation)

class MobileDeviceSeatRecord {
  final String deviceId;
  final String tenantId;
  final String branchId;
  final String branchName;
  final String deviceName;
  final String deviceType;
  final String status; // ACTIVE, REVOKED, SUSPENDED, DECOMMISSIONED
  final String macAddress;
  final String ipAddress;
  final String hardwareFingerprint;
  final DateTime enrolledAt;
  final String enrolledBy;
  final DateTime? revokedAt;
  final String? revokedBy;
  final String revocationReason;
  final DateTime? lastHeartbeatAt;
  final bool zeroDataDeleted;
  final bool leaseInvalidationEnforced;
  final bool quotaCounterSynced;
  final String headlineEn;
  final String headlineBn;
  final String detailsEn;
  final String detailsBn;

  const MobileDeviceSeatRecord({
    required this.deviceId,
    required this.tenantId,
    required this.branchId,
    required this.branchName,
    required this.deviceName,
    required this.deviceType,
    required this.status,
    required this.macAddress,
    required this.ipAddress,
    required this.hardwareFingerprint,
    required this.enrolledAt,
    required this.enrolledBy,
    this.revokedAt,
    this.revokedBy,
    required this.revocationReason,
    this.lastHeartbeatAt,
    required this.zeroDataDeleted,
    required this.leaseInvalidationEnforced,
    required this.quotaCounterSynced,
    required this.headlineEn,
    required this.headlineBn,
    required this.detailsEn,
    required this.detailsBn,
  });

  factory MobileDeviceSeatRecord.fromJson(Map<String, dynamic> json) {
    final inv = json['invariants'] as Map<String, dynamic>? ?? {};
    final msg = json['client_messaging'] as Map<String, dynamic>? ?? {};

    return MobileDeviceSeatRecord(
      deviceId: json['device_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String? ?? '',
      branchName: json['branch_name'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? '',
      deviceType: json['device_type'] as String? ?? 'DESKTOP_POS',
      status: json['status'] as String? ?? 'ACTIVE',
      macAddress: json['mac_address'] as String? ?? '',
      ipAddress: json['ip_address'] as String? ?? '',
      hardwareFingerprint: json['hardware_fingerprint'] as String? ?? '',
      enrolledAt: DateTime.tryParse(json['enrolled_at'] as String? ?? '') ?? DateTime.now(),
      enrolledBy: json['enrolled_by'] as String? ?? '',
      revokedAt: json['revoked_at'] != null ? DateTime.tryParse(json['revoked_at'] as String) : null,
      revokedBy: json['revoked_by'] as String?,
      revocationReason: json['revocation_reason'] as String? ?? '',
      lastHeartbeatAt:
          json['last_heartbeat_at'] != null ? DateTime.tryParse(json['last_heartbeat_at'] as String) : null,
      zeroDataDeleted: inv['zero_data_deleted'] as bool? ?? true,
      leaseInvalidationEnforced: inv['lease_invalidation_enforced'] as bool? ?? true,
      quotaCounterSynced: inv['quota_counter_synced'] as bool? ?? true,
      headlineEn: msg['headline_en'] as String? ?? '',
      headlineBn: msg['headline_bn'] as String? ?? '',
      detailsEn: msg['details_en'] as String? ?? '',
      detailsBn: msg['details_bn'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'branch_name': branchName,
        'device_name': deviceName,
        'device_type': deviceType,
        'status': status,
        'mac_address': macAddress,
        'ip_address': ipAddress,
        'hardware_fingerprint': hardwareFingerprint,
        'enrolled_at': enrolledAt.toIso8601String(),
        'enrolled_by': enrolledBy,
        'revoked_at': revokedAt?.toIso8601String(),
        'revoked_by': revokedBy,
        'revocation_reason': revocationReason,
        'last_heartbeat_at': lastHeartbeatAt?.toIso8601String(),
        'invariants': {
          'zero_data_deleted': zeroDataDeleted,
          'lease_invalidation_enforced': leaseInvalidationEnforced,
          'quota_counter_synced': quotaCounterSynced,
        },
        'client_messaging': {
          'headline_en': headlineEn,
          'headline_bn': headlineBn,
          'details_en': detailsEn,
          'details_bn': detailsBn,
        },
      };

  bool get isActive => status == 'ACTIVE';
  bool get isRevoked => status == 'REVOKED';
}

class MobileDeviceSeatsSummary {
  final int totalEnrolled;
  final int activeSeatsUsed;
  final int maxLimit;
  final int remaining;
  final double utilizationPct;
  final bool isOverQuota;
  final String status;

  const MobileDeviceSeatsSummary({
    required this.totalEnrolled,
    required this.activeSeatsUsed,
    required this.maxLimit,
    required this.remaining,
    required this.utilizationPct,
    required this.isOverQuota,
    required this.status,
  });

  factory MobileDeviceSeatsSummary.fromJson(Map<String, dynamic> json) {
    return MobileDeviceSeatsSummary(
      totalEnrolled: (json['total_enrolled'] as num?)?.toInt() ?? 0,
      activeSeatsUsed: (json['active_seats_used'] as num?)?.toInt() ?? 0,
      maxLimit: (json['max_limit'] as num?)?.toInt() ?? 1,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      utilizationPct: (json['utilization_pct'] as num?)?.toDouble() ?? 0.0,
      isOverQuota: json['is_over_quota'] as bool? ?? false,
      status: json['status'] as String? ?? 'NORMAL',
    );
  }

  Map<String, dynamic> toJson() => {
        'total_enrolled': totalEnrolled,
        'active_seats_used': activeSeatsUsed,
        'max_limit': maxLimit,
        'remaining': remaining,
        'utilization_pct': utilizationPct,
        'is_over_quota': isOverQuota,
        'status': status,
      };

  bool get canEnrollMore => activeSeatsUsed < maxLimit;
  bool get isAtCapacity => activeSeatsUsed >= maxLimit;
}

class MobileDeviceSeatsResponse {
  final String tenantId;
  final String planTier;
  final List<MobileDeviceSeatRecord> devices;
  final MobileDeviceSeatsSummary seatSummary;
  final String headlineEn;
  final String headlineBn;
  final String detailsEn;
  final String detailsBn;

  const MobileDeviceSeatsResponse({
    required this.tenantId,
    required this.planTier,
    required this.devices,
    required this.seatSummary,
    required this.headlineEn,
    required this.headlineBn,
    required this.detailsEn,
    required this.detailsBn,
  });

  factory MobileDeviceSeatsResponse.fromJson(Map<String, dynamic> json) {
    final devList = (json['devices'] as List<dynamic>? ?? [])
        .map((e) => MobileDeviceSeatRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    final sumJson = json['seat_summary'] as Map<String, dynamic>? ?? {};
    final msg = json['client_messaging'] as Map<String, dynamic>? ?? {};

    return MobileDeviceSeatsResponse(
      tenantId: json['tenant_id'] as String? ?? '',
      planTier: json['plan_tier'] as String? ?? 'BASIC',
      devices: devList,
      seatSummary: MobileDeviceSeatsSummary.fromJson(sumJson),
      headlineEn: msg['headline_en'] as String? ?? 'Device Seats Management',
      headlineBn: msg['headline_bn'] as String? ?? 'ডিভাইস সীট ব্যবস্থাপনা',
      detailsEn: msg['details_en'] as String? ?? '',
      detailsBn: msg['details_bn'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'tenant_id': tenantId,
        'plan_tier': planTier,
        'devices': devices.map((d) => d.toJson()).toList(),
        'seat_summary': seatSummary.toJson(),
        'client_messaging': {
          'headline_en': headlineEn,
          'headline_bn': headlineBn,
          'details_en': detailsEn,
          'details_bn': detailsBn,
        },
      };
}

