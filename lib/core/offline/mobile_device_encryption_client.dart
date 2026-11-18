// mobile_device_encryption_client.dart
// Architecture Decision: ADR-0302 (P302).

class DeviceEncryptionPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  DeviceEncryptionPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });
}

enum KeyVaultUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

class DeviceEncryptionKeyDto {
  final String keyId;
  final String deviceId;
  final int keyVersion;
  final String algorithm;
  final String status;
  final bool needsRotation;

  DeviceEncryptionKeyDto({
    required this.keyId,
    required this.deviceId,
    required this.keyVersion,
    required this.algorithm,
    required this.status,
    required this.needsRotation,
  });

  factory DeviceEncryptionKeyDto.fromJson(Map<String, dynamic> json) {
    return DeviceEncryptionKeyDto(
      keyId: json['key_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      keyVersion: (json['key_version'] as num?)?.toInt() ?? 1,
      algorithm: json['algorithm']?.toString() ?? 'AES_256_GCM_ENVELOPE',
      status: json['status']?.toString() ?? 'ACTIVE',
      needsRotation: json['needs_rotation'] as bool? ?? false,
    );
  }

  Map<String, String> localizedKeyBadge() {
    if (status == 'COMPROMISED_REVOKED') {
      return {'en': 'Revoked (Compromised)', 'bn': 'বাতিলকৃত (ঝুঁকিপূর্ণ)'};
    }
    if (needsRotation) {
      return {'en': 'Rotation Overdue', 'bn': 'কী রোটেশন প্রয়োজন'};
    }
    return {'en': 'Encrypted (v$keyVersion Active)', 'bn': 'এনক্রিপ্টেড (v$keyVersion সক্রিয়)'};
  }
}

class MobileDeviceEncryptionClient {
  static const Set<String> _manageRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  final String tenantId;
  final String userRole;
  KeyVaultUiState uiState = KeyVaultUiState.idle;
  List<DeviceEncryptionKeyDto> _cache = [];

  MobileDeviceEncryptionClient({required this.tenantId, required String userRole})
      : userRole = userRole.toUpperCase();

  bool canManageKeys() => _manageRoles.contains(userRole);

  void assertManageAuthorized() {
    if (!canManageKeys()) {
      uiState = KeyVaultUiState.permissionDenied;
      throw DeviceEncryptionPermissionException(
        errorCode: 'ERR_DEVICE_KEY_MANAGE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can rotate or recover device encryption keys.',
        messageBn: 'শুধুমাত্র ওনার বা ফিন্যান্স অফিসার এনক্রিপশন কী রোটেশন বা রিকভারি করতে পারেন।',
      );
    }
  }

  List<DeviceEncryptionKeyDto> parseKeyList(Map<String, dynamic> json) {
    final raw = (json['keys'] as List<dynamic>? ?? []);
    final items = raw.map((e) => DeviceEncryptionKeyDto.fromJson(e as Map<String, dynamic>)).toList();
    _cache = items;
    uiState = items.isEmpty ? KeyVaultUiState.empty : KeyVaultUiState.loaded;
    return items;
  }

  List<DeviceEncryptionKeyDto> loadOfflineFallback() {
    uiState = _cache.isEmpty ? KeyVaultUiState.empty : KeyVaultUiState.offlineCache;
    return List.unmodifiable(_cache);
  }
}
