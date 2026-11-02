// lib/core/device/mobile_device_registration_client.dart
// Architecture Decision: ADR-0111 / P111
// Phase 06: Milestone M03 - Offline-First Desktop POS & Owner Visibility.

import 'dart:convert';
import 'dart:typed_data';

enum MobileDeviceUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

enum MobileDeviceRegistrationStatus {
  pendingApproval,
  approved,
  rejected,
  revoked,
}

enum MobileDeviceKeyAlgorithm {
  ed25519,
  rsa2048,
  ecdsaP256,
}

class MobileDeviceRegistrationRecord {
  final String registrationId;
  final String tenantId;
  final String branchId;
  final String? branchName;
  final String deviceId;
  final String deviceLabel;
  final String deviceType;
  final String publicKeyPem;
  final String keyAlgorithm;
  final String keyFingerprint;
  final String? hardwareFingerprint;
  final String status;
  final String requestedBy;
  final String? approvedBy;
  final String? approvedAt;
  final String? rejectedBy;
  final String? rejectedAt;
  final String? rejectionReason;
  final String? revokedBy;
  final String? revokedAt;
  final String? revocationReason;
  final String? approvalNotes;
  final String createdAt;

  const MobileDeviceRegistrationRecord({
    required this.registrationId,
    required this.tenantId,
    required this.branchId,
    this.branchName,
    required this.deviceId,
    required this.deviceLabel,
    required this.deviceType,
    required this.publicKeyPem,
    required this.keyAlgorithm,
    required this.keyFingerprint,
    this.hardwareFingerprint,
    required this.status,
    required this.requestedBy,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectionReason,
    this.revokedBy,
    this.revokedAt,
    this.revocationReason,
    this.approvalNotes,
    required this.createdAt,
  });

  factory MobileDeviceRegistrationRecord.fromJson(Map<String, dynamic> json) {
    return MobileDeviceRegistrationRecord(
      registrationId: json['registration_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String? ?? '',
      branchName: json['branch_name'] as String?,
      deviceId: json['device_id'] as String? ?? '',
      deviceLabel: json['device_label'] as String? ?? '',
      deviceType: json['device_type'] as String? ?? 'DESKTOP_POS',
      publicKeyPem: json['public_key_pem'] as String? ?? '',
      keyAlgorithm: json['key_algorithm'] as String? ?? 'ED25519',
      keyFingerprint: json['key_fingerprint'] as String? ?? '',
      hardwareFingerprint: json['hardware_fingerprint'] as String?,
      status: json['status'] as String? ?? 'PENDING_APPROVAL',
      requestedBy: json['requested_by_username'] as String? ?? '',
      approvedBy: json['approved_by_username'] as String?,
      approvedAt: json['approved_at'] as String?,
      rejectedBy: json['rejected_by_username'] as String?,
      rejectedAt: json['rejected_at'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      revokedBy: json['revoked_by_username'] as String?,
      revokedAt: json['revoked_at'] as String?,
      revocationReason: json['revocation_reason'] as String?,
      approvalNotes: json['approval_notes'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'registration_id': registrationId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'branch_name': branchName,
        'device_id': deviceId,
        'device_label': deviceLabel,
        'device_type': deviceType,
        'public_key_pem': publicKeyPem,
        'key_algorithm': keyAlgorithm,
        'key_fingerprint': keyFingerprint,
        'hardware_fingerprint': hardwareFingerprint,
        'status': status,
        'requested_by_username': requestedBy,
        'approved_by_username': approvedBy,
        'approved_at': approvedAt,
        'rejected_by_username': rejectedBy,
        'rejected_at': rejectedAt,
        'rejection_reason': rejectionReason,
        'revoked_by_username': revokedBy,
        'revoked_at': revokedAt,
        'revocation_reason': revocationReason,
        'approval_notes': approvalNotes,
        'created_at': createdAt,
      };
}

class MobileDeviceVerificationResult {
  final bool isTrusted;
  final String status;
  final String? registrationId;
  final String? deviceId;
  final String? deviceLabel;
  final String? branchId;
  final String? branchName;
  final String? keyFingerprint;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileDeviceVerificationResult({
    required this.isTrusted,
    required this.status,
    this.registrationId,
    this.deviceId,
    this.deviceLabel,
    this.branchId,
    this.branchName,
    this.keyFingerprint,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileDeviceVerificationResult.trusted({
    required String registrationId,
    required String deviceId,
    required String deviceLabel,
    required String branchId,
    String? branchName,
    required String keyFingerprint,
  }) {
    return MobileDeviceVerificationResult(
      isTrusted: true,
      status: 'APPROVED',
      registrationId: registrationId,
      deviceId: deviceId,
      deviceLabel: deviceLabel,
      branchId: branchId,
      branchName: branchName,
      keyFingerprint: keyFingerprint,
      messageEn: 'Device is trusted and authorized for terminal operations.',
      messageBn: 'ডিভাইসটি সফলভাবে যাচাইকৃত এবং টার্মিনাল ব্যবহারের জন্য অনুমোদিত।',
    );
  }

  factory MobileDeviceVerificationResult.rejected({
    required String errorCode,
    required String messageEn,
    required String messageBn,
  }) {
    return MobileDeviceVerificationResult(
      isTrusted: false,
      status: 'UNTRUSTED',
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }
}

class MobileDeviceUiState {
  final MobileDeviceUiStatus uiStatus;
  final String? errorMessageEn;
  final String? errorMessageBn;
  final List<MobileDeviceRegistrationRecord> devices;
  final MobileDeviceRegistrationRecord? selectedDevice;
  final int offlineQueueCount;

  const MobileDeviceUiState({
    required this.uiStatus,
    this.errorMessageEn,
    this.errorMessageBn,
    this.devices = const [],
    this.selectedDevice,
    this.offlineQueueCount = 0,
  });
}

/// Pure Dart SHA-256 implementation (NIST FIPS 180-4 compliant)
String computeSha256Fingerprint(String input) {
  final clean = input.trim();
  final bytes = utf8.encode(clean);

  // K constants
  const k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  // Initial hash values
  var h0 = 0x6a09e667;
  var h1 = 0xbb67ae85;
  var h2 = 0x3c6ef372;
  var h3 = 0xa54ff53a;
  var h4 = 0x510e527f;
  var h5 = 0x9b05688c;
  var h6 = 0x1f83d9ab;
  var h7 = 0x5be0cd19;

  // Pre-processing
  final bitLength = bytes.length * 8;
  final padLen = (bytes.length % 64 < 56)
      ? (56 - (bytes.length % 64))
      : (120 - (bytes.length % 64));

  final padded = Uint8List(bytes.length + padLen + 8);
  padded.setRange(0, bytes.length, bytes);
  padded[bytes.length] = 0x80;

  // Append length in bits as 64-bit big-endian
  final byteData = ByteData.view(padded.buffer);
  byteData.setUint64(padded.length - 8, bitLength, Endian.big);

  int rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xFFFFFFFF;

  // Process each 64-byte chunk
  final w = List<int>.filled(64, 0);
  for (var i = 0; i < padded.length; i += 64) {
    for (var t = 0; t < 16; t++) {
      w[t] = byteData.getUint32(i + t * 4, Endian.big);
    }
    for (var t = 16; t < 64; t++) {
      final s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >>> 3);
      final s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >>> 10);
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xFFFFFFFF;
    }

    var a = h0;
    var b = h1;
    var c = h2;
    var d = h3;
    var e = h4;
    var f = h5;
    var g = h6;
    var h = h7;

    for (var t = 0; t < 64; t++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e) & g);
      final temp1 = (h + s1 + ch + k[t] + w[t]) & 0xFFFFFFFF;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xFFFFFFFF;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xFFFFFFFF;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xFFFFFFFF;
    }

    h0 = (h0 + a) & 0xFFFFFFFF;
    h1 = (h1 + b) & 0xFFFFFFFF;
    h2 = (h2 + c) & 0xFFFFFFFF;
    h3 = (h3 + d) & 0xFFFFFFFF;
    h4 = (h4 + e) & 0xFFFFFFFF;
    h5 = (h5 + f) & 0xFFFFFFFF;
    h6 = (h6 + g) & 0xFFFFFFFF;
    h7 = (h7 + h) & 0xFFFFFFFF;
  }

  return [h0, h1, h2, h3, h4, h5, h6, h7]
      .map((val) => val.toRadixString(16).padLeft(8, '0'))
      .join('');
}

class MobileDeviceRegistrationClient {
  final String baseUrl;
  final String tenantId;
  final String userRole;
  final String? userBranchId;
  final String username;

  bool _isOffline = false;
  final Map<String, MobileDeviceRegistrationRecord> _localCache = {};
  final List<MobileDeviceRegistrationRecord> _offlineQueue = [];

  MobileDeviceRegistrationClient({
    required this.baseUrl,
    required this.tenantId,
    required this.userRole,
    this.userBranchId,
    required this.username,
  });

  bool get isOffline => _isOffline;
  void setOffline(bool offline) => _isOffline = offline;

  bool get isOwnerOrSuperAdmin {
    final r = userRole.toUpperCase();
    return r == 'PHARMACY_OWNER' || r == 'SUPERADMIN' || r == 'SUPER_ADMIN';
  }

  void importRegistration(MobileDeviceRegistrationRecord record) {
    _localCache[record.registrationId] = record;
  }

  void _assertApprovalAuthority(MobileDeviceRegistrationRecord record) {
    if (isOwnerOrSuperAdmin) return;

    final r = userRole.toUpperCase();
    if (r == 'BRANCH_MANAGER') {
      if (userBranchId != null && userBranchId == record.branchId) {
        return;
      }
      throw StateError(
          'ERR_CROSS_BRANCH_VIOLATION: Branch Manager cannot approve devices outside assigned branch.');
    }
    throw StateError(
        'ERR_PERMISSION_DENIED: Role $userRole is not authorized to approve or manage devices.');
  }

  MobileDeviceRegistrationRecord registerDevice({
    required String branchId,
    required String deviceId,
    required String deviceLabel,
    required String publicKeyPem,
    MobileDeviceKeyAlgorithm algorithm = MobileDeviceKeyAlgorithm.ed25519,
    String? hardwareFingerprint,
    String? macAddress,
  }) {
    if (deviceId.trim().isEmpty) {
      throw ArgumentError('deviceId is required');
    }
    if (deviceLabel.trim().isEmpty) {
      throw ArgumentError('deviceLabel is required');
    }
    if (publicKeyPem.trim().length < 32) {
      throw ArgumentError('publicKeyPem must be at least 32 characters');
    }

    final fingerprint = computeSha256Fingerprint(publicKeyPem);
    final regId = 'dreg-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final now = DateTime.now().toUtc().toIso8601String();

    final record = MobileDeviceRegistrationRecord(
      registrationId: regId,
      tenantId: tenantId,
      branchId: branchId,
      branchName: 'Branch $branchId',
      deviceId: deviceId.trim(),
      deviceLabel: deviceLabel.trim(),
      deviceType: 'DESKTOP_POS',
      publicKeyPem: publicKeyPem.trim(),
      keyAlgorithm: algorithm.name.toUpperCase(),
      keyFingerprint: fingerprint,
      hardwareFingerprint: hardwareFingerprint,
      status: 'PENDING_APPROVAL',
      requestedBy: username,
      createdAt: now,
    );

    if (_isOffline) {
      _offlineQueue.add(record);
      _localCache[record.registrationId] = record;
      return record;
    }

    _localCache[record.registrationId] = record;
    return record;
  }

  MobileDeviceRegistrationRecord approveDevice(String registrationId, {String? notes}) {
    final record = _localCache[registrationId];
    if (record == null) {
      throw ArgumentError('Device registration $registrationId not found.');
    }
    _assertApprovalAuthority(record);

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = MobileDeviceRegistrationRecord(
      registrationId: record.registrationId,
      tenantId: record.tenantId,
      branchId: record.branchId,
      branchName: record.branchName,
      deviceId: record.deviceId,
      deviceLabel: record.deviceLabel,
      deviceType: record.deviceType,
      publicKeyPem: record.publicKeyPem,
      keyAlgorithm: record.keyAlgorithm,
      keyFingerprint: record.keyFingerprint,
      hardwareFingerprint: record.hardwareFingerprint,
      status: 'APPROVED',
      requestedBy: record.requestedBy,
      approvedBy: username,
      approvedAt: now,
      approvalNotes: notes,
      createdAt: record.createdAt,
    );

    _localCache[registrationId] = updated;
    return updated;
  }

  MobileDeviceRegistrationRecord rejectDevice(String registrationId, {required String reason}) {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw ArgumentError('ERR_REASON_REQUIRED: A rejection reason is required.');
    }
    final record = _localCache[registrationId];
    if (record == null) {
      throw ArgumentError('Device registration $registrationId not found.');
    }
    _assertApprovalAuthority(record);

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = MobileDeviceRegistrationRecord(
      registrationId: record.registrationId,
      tenantId: record.tenantId,
      branchId: record.branchId,
      branchName: record.branchName,
      deviceId: record.deviceId,
      deviceLabel: record.deviceLabel,
      deviceType: record.deviceType,
      publicKeyPem: record.publicKeyPem,
      keyAlgorithm: record.keyAlgorithm,
      keyFingerprint: record.keyFingerprint,
      hardwareFingerprint: record.hardwareFingerprint,
      status: 'REJECTED',
      requestedBy: record.requestedBy,
      rejectedBy: username,
      rejectedAt: now,
      rejectionReason: cleanReason,
      createdAt: record.createdAt,
    );

    _localCache[registrationId] = updated;
    return updated;
  }

  MobileDeviceRegistrationRecord revokeDevice(String registrationId, {required String reason}) {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw ArgumentError('ERR_REASON_REQUIRED: A revocation reason is required.');
    }
    final record = _localCache[registrationId];
    if (record == null) {
      throw ArgumentError('Device registration $registrationId not found.');
    }
    _assertApprovalAuthority(record);

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = MobileDeviceRegistrationRecord(
      registrationId: record.registrationId,
      tenantId: record.tenantId,
      branchId: record.branchId,
      branchName: record.branchName,
      deviceId: record.deviceId,
      deviceLabel: record.deviceLabel,
      deviceType: record.deviceType,
      publicKeyPem: record.publicKeyPem,
      keyAlgorithm: record.keyAlgorithm,
      keyFingerprint: record.keyFingerprint,
      hardwareFingerprint: record.hardwareFingerprint,
      status: 'REVOKED',
      requestedBy: record.requestedBy,
      approvedBy: record.approvedBy,
      approvedAt: record.approvedAt,
      rejectedBy: record.rejectedBy,
      rejectedAt: record.rejectedAt,
      rejectionReason: record.rejectionReason,
      revokedBy: username,
      revokedAt: now,
      revocationReason: cleanReason,
      approvalNotes: record.approvalNotes,
      createdAt: record.createdAt,
    );

    _localCache[registrationId] = updated;
    return updated;
  }

  MobileDeviceVerificationResult verifyDevice(String deviceId, {String? publicKeyPem}) {
    if (deviceId.trim().isEmpty) {
      return MobileDeviceVerificationResult.rejected(
        errorCode: 'MISSING_DEVICE_ID',
        messageEn: 'Device ID is required.',
        messageBn: 'ডিভাইস আইডি প্রদান করা আবশ্যক।',
      );
    }

    MobileDeviceRegistrationRecord? found;
    for (final rec in _localCache.values) {
      if (rec.deviceId == deviceId.trim()) {
        found = rec;
        break;
      }
    }

    if (found == null) {
      return MobileDeviceVerificationResult.rejected(
        errorCode: 'ERR_DEVICE_NOT_FOUND',
        messageEn: "Device '$deviceId' is not registered with this pharmacy.",
        messageBn: "ডিভাইস '$deviceId' এই ফার্মেসিতে নিবন্ধিত নয়।",
      );
    }

    if (found.status == 'PENDING_APPROVAL') {
      return MobileDeviceVerificationResult.rejected(
        errorCode: 'ERR_DEVICE_NOT_APPROVED',
        messageEn: "Device '$deviceId' is pending manager/owner approval.",
        messageBn: "ডিভাইস '$deviceId' ব্যবস্থাপকের অনুমোদনের অপেক্ষায় রয়েছে।",
      );
    }

    if (found.status == 'REJECTED') {
      return MobileDeviceVerificationResult.rejected(
        errorCode: 'ERR_DEVICE_REJECTED',
        messageEn: "Device '$deviceId' registration was rejected: ${found.rejectionReason}",
        messageBn: "ডিভাইস '$deviceId'-এর রেজিস্ট্রেশন প্রত্যাখ্যান করা হয়েছে।",
      );
    }

    if (found.status == 'REVOKED') {
      return MobileDeviceVerificationResult.rejected(
        errorCode: 'ERR_DEVICE_REVOKED',
        messageEn: "Device '$deviceId' cryptographic trust has been revoked: ${found.revocationReason}",
        messageBn: "ডিভাইস '$deviceId'-এর ক্রিপ্টোগ্রাফিক অনুমোদন বাতিল করা হয়েছে।",
      );
    }

    if (publicKeyPem != null && publicKeyPem.trim().isNotEmpty) {
      final fp = computeSha256Fingerprint(publicKeyPem);
      if (fp != found.keyFingerprint) {
        return MobileDeviceVerificationResult.rejected(
          errorCode: 'ERR_DEVICE_KEY_MISMATCH',
          messageEn: 'Cryptographic public key does not match enrolled device key material.',
          messageBn: 'প্রদানকৃত পাবলিক কি নিবন্ধিত ডিভাইসের কি ম্যাটেরিয়ালের সাথে মিলছে না।',
        );
      }
    }

    return MobileDeviceVerificationResult.trusted(
      registrationId: found.registrationId,
      deviceId: found.deviceId,
      deviceLabel: found.deviceLabel,
      branchId: found.branchId,
      branchName: found.branchName,
      keyFingerprint: found.keyFingerprint,
    );
  }

  List<MobileDeviceRegistrationRecord> listRegistrations({String? branchFilter, String? statusFilter}) {
    final results = <MobileDeviceRegistrationRecord>[];
    for (final rec in _localCache.values) {
      if (branchFilter != null && branchFilter.isNotEmpty && rec.branchId != branchFilter) {
        continue;
      }
      if (statusFilter != null && statusFilter.isNotEmpty && rec.status != statusFilter.toUpperCase()) {
        continue;
      }
      results.add(rec);
    }
    return results;
  }

  MobileDeviceRegistrationRecord updateDeviceLabel(String registrationId, String newLabel) {
    final clean = newLabel.trim();
    if (clean.isEmpty) {
      throw ArgumentError('newLabel cannot be empty');
    }
    final record = _localCache[registrationId];
    if (record == null) {
      throw ArgumentError('Device registration $registrationId not found.');
    }
    _assertApprovalAuthority(record);

    final updated = MobileDeviceRegistrationRecord(
      registrationId: record.registrationId,
      tenantId: record.tenantId,
      branchId: record.branchId,
      branchName: record.branchName,
      deviceId: record.deviceId,
      deviceLabel: clean,
      deviceType: record.deviceType,
      publicKeyPem: record.publicKeyPem,
      keyAlgorithm: record.keyAlgorithm,
      keyFingerprint: record.keyFingerprint,
      hardwareFingerprint: record.hardwareFingerprint,
      status: record.status,
      requestedBy: record.requestedBy,
      approvedBy: record.approvedBy,
      approvedAt: record.approvedAt,
      rejectedBy: record.rejectedBy,
      rejectedAt: record.rejectedAt,
      rejectionReason: record.rejectionReason,
      revokedBy: record.revokedBy,
      revokedAt: record.revokedAt,
      revocationReason: record.revocationReason,
      approvalNotes: record.approvalNotes,
      createdAt: record.createdAt,
    );

    _localCache[registrationId] = updated;
    return updated;
  }

  int syncOfflineRegistrations() {
    final count = _offlineQueue.length;
    _offlineQueue.clear();
    return count;
  }

  MobileDeviceUiState getUiState({String? branchFilter, String? statusFilter}) {
    if (_isOffline) {
      final cached = listRegistrations(branchFilter: branchFilter, statusFilter: statusFilter);
      return MobileDeviceUiState(
        uiStatus: MobileDeviceUiStatus.offline,
        errorMessageEn: 'Running in offline mode. Registrations cached locally.',
        errorMessageBn: 'মোবাইল অ্যাপটি অফলাইন মোডে চলছে। ডাটা লোকাল ডিভাইসে সংরক্ষিত।',
        devices: cached,
        offlineQueueCount: _offlineQueue.length,
      );
    }

    final items = listRegistrations(branchFilter: branchFilter, statusFilter: statusFilter);
    if (items.isEmpty) {
      return const MobileDeviceUiState(
        uiStatus: MobileDeviceUiStatus.empty,
        devices: [],
      );
    }

    return MobileDeviceUiState(
      uiStatus: MobileDeviceUiStatus.success,
      devices: items,
      selectedDevice: items.first,
    );
  }
}

