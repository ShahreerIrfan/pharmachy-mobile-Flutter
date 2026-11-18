// mobile_offline_device_schema_client.dart
// Architecture Decision: ADR-0301 (P301).
// Phase 16: JavaFX SQLite Offline Store & Reliable Cloud Sync.

class OfflineDevicePermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  OfflineDevicePermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });
}

enum DeviceMonitorUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

class OfflineDeviceSchemaDto {
  final String registrationId;
  final String deviceId;
  final String deviceLabel;
  final String branchName;
  final int schemaVersion;
  final String offlineStockPolicy;
  final bool isLeaseValid;
  final String status;

  OfflineDeviceSchemaDto({
    required this.registrationId,
    required this.deviceId,
    required this.deviceLabel,
    required this.branchName,
    required this.schemaVersion,
    required this.offlineStockPolicy,
    required this.isLeaseValid,
    required this.status,
  });

  factory OfflineDeviceSchemaDto.fromJson(Map<String, dynamic> json) {
    return OfflineDeviceSchemaDto(
      registrationId: json['registration_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      deviceLabel: json['device_label']?.toString() ?? 'POS Terminal',
      branchName: json['branch_name']?.toString() ?? '',
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      offlineStockPolicy: json['offline_stock_policy']?.toString() ?? 'CONTROLLED_RECONCILIATION',
      isLeaseValid: json['is_lease_valid'] as bool? ?? false,
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }

  Map<String, String> localizedLeaseBadge() {
    if (status == 'REVOKED') {
      return {'en': 'Device Revoked', 'bn': 'ডিভাইস বাতিলকৃত'};
    }
    return isLeaseValid
        ? {'en': 'Offline Lease Active', 'bn': 'অফলাইন লিজ সক্রিয়'}
        : {'en': 'Lease Expired — Reconnect Required', 'bn': 'লিজ মেয়াদোত্তীর্ণ — রিকানেক্ট করুন'};
  }
}

class MobileOfflineDeviceSchemaClient {
  static const Set<String> _manageRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  final String tenantId;
  final String userRole;
  DeviceMonitorUiState uiState = DeviceMonitorUiState.idle;
  List<OfflineDeviceSchemaDto> _cache = [];

  MobileOfflineDeviceSchemaClient({required this.tenantId, required String userRole})
      : userRole = userRole.toUpperCase();

  bool canManageDevices() => _manageRoles.contains(userRole);

  void assertManageAuthorized() {
    if (!canManageDevices()) {
      uiState = DeviceMonitorUiState.permissionDenied;
      throw OfflineDevicePermissionException(
        errorCode: 'ERR_DEVICE_MANAGE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Branch Manager can manage offline POS devices.',
        messageBn: 'শুধুমাত্র ওনার বা ব্রাঞ্চ ম্যানেজার অফলাইন পিওএস ডিভাইস পরিচালনা করতে পারেন।',
      );
    }
  }

  List<OfflineDeviceSchemaDto> parseDeviceList(Map<String, dynamic> json) {
    final raw = (json['devices'] as List<dynamic>? ?? []);
    final items = raw.map((e) => OfflineDeviceSchemaDto.fromJson(e as Map<String, dynamic>)).toList();
    _cache = items;
    uiState = items.isEmpty ? DeviceMonitorUiState.empty : DeviceMonitorUiState.loaded;
    return items;
  }

  List<OfflineDeviceSchemaDto> loadOfflineFallback() {
    uiState = _cache.isEmpty ? DeviceMonitorUiState.empty : DeviceMonitorUiState.offlineCache;
    return List.unmodifiable(_cache);
  }
}
