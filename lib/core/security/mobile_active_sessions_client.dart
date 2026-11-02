// lib/core/security/mobile_active_sessions_client.dart
// Architecture Decision: ADR-0045, ADR-0112 (P112)
// Phase 06: Milestone M03 - Offline-First Desktop POS & Owner Visibility.

enum MobileActiveSessionsUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

enum MobileClientPlatform {
  desktopPos,
  mobileManager,
  webAdmin,
}

class MobileActiveSessionRecord {
  final String sessionId;
  final String userId;
  final String userEmail;
  final String userFullName;
  final String userRole;
  final String tenantId;
  final String? branchId;
  final String deviceId;
  final String deviceName;
  final String clientPlatform;
  final String? ipAddress;
  final bool isActive;
  final bool isCurrent;
  final String? revocationReason;
  final String? revokedAt;
  final String? lastSeenAt;
  final String? createdAt;

  const MobileActiveSessionRecord({
    required this.sessionId,
    required this.userId,
    required this.userEmail,
    required this.userFullName,
    required this.userRole,
    required this.tenantId,
    this.branchId,
    required this.deviceId,
    this.deviceName = '',
    this.clientPlatform = 'MOBILE_MANAGER',
    this.ipAddress,
    this.isActive = true,
    this.isCurrent = false,
    this.revocationReason,
    this.revokedAt,
    this.lastSeenAt,
    this.createdAt,
  });

  factory MobileActiveSessionRecord.fromJson(Map<String, dynamic> json) {
    return MobileActiveSessionRecord(
      sessionId: json['session_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userEmail: json['user_email'] as String? ?? '',
      userFullName: json['user_full_name'] as String? ?? '',
      userRole: json['user_role'] as String? ?? 'CASHIER',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String?,
      deviceId: json['device_id'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? '',
      clientPlatform: json['client_platform'] as String? ?? 'MOBILE_MANAGER',
      ipAddress: json['ip_address'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      isCurrent: json['is_current'] as bool? ?? false,
      revocationReason: json['revocation_reason'] as String?,
      revokedAt: json['revoked_at'] as String?,
      lastSeenAt: json['last_seen_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'user_id': userId,
        'user_email': userEmail,
        'user_full_name': userFullName,
        'user_role': userRole,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'device_id': deviceId,
        'device_name': deviceName,
        'client_platform': clientPlatform,
        'ip_address': ipAddress,
        'is_active': isActive,
        'is_current': isCurrent,
        'revocation_reason': revocationReason,
        'revoked_at': revokedAt,
        'last_seen_at': lastSeenAt,
        'created_at': createdAt,
      };

  String getDisplayStatus([String language = 'en']) {
    if (!isActive) {
      return language == 'bn' ? 'বাতিলকৃত' : 'Revoked';
    }
    if (isCurrent) {
      return language == 'bn' ? 'বর্তমান ডিভাইস (সক্রিয়)' : 'Current Device (Active)';
    }
    return language == 'bn' ? 'সক্রিয়' : 'Active';
  }
}

class MobileSessionRevocationResult {
  final String sessionId;
  final String status;
  final bool revoked;
  final String messageEn;
  final String messageBn;

  const MobileSessionRevocationResult({
    required this.sessionId,
    required this.status,
    required this.revoked,
    required this.messageEn,
    required this.messageBn,
  });
}

class MobileBulkRevocationResult {
  final String status;
  final int revokedCount;
  final String targetUserId;
  final String messageEn;
  final String messageBn;

  const MobileBulkRevocationResult({
    required this.status,
    required this.revokedCount,
    required this.targetUserId,
    required this.messageEn,
    required this.messageBn,
  });
}

class MobileActiveSessionsUiState {
  final MobileActiveSessionsUiStatus uiStatus;
  final String? errorMessageEn;
  final String? errorMessageBn;
  final List<MobileActiveSessionRecord> sessions;
  final MobileActiveSessionRecord? selectedSession;
  final int offlineQueueCount;

  const MobileActiveSessionsUiState({
    required this.uiStatus,
    this.errorMessageEn,
    this.errorMessageBn,
    this.sessions = const [],
    this.selectedSession,
    this.offlineQueueCount = 0,
  });
}

class MobileActiveSessionsClient {
  final String baseUrl;
  final String tenantId;
  final String userRole;
  final String? userBranchId;
  final String userId;
  final String userEmail;
  final String? currentSessionId;

  bool _isOffline = false;
  final Map<String, MobileActiveSessionRecord> _sessionCache = {};
  final List<String> _offlineRevocationQueue = [];

  MobileActiveSessionsClient({
    required this.baseUrl,
    required this.tenantId,
    required this.userRole,
    this.userBranchId,
    required this.userId,
    required this.userEmail,
    this.currentSessionId,
  });

  bool get isOffline => _isOffline;
  void setOffline(bool offline) => _isOffline = offline;

  bool get isSuperAdmin {
    final r = userRole.toUpperCase();
    return r == 'SUPERADMIN' || r == 'SUPER_ADMIN' || r == 'PLATFORM_OPERATOR';
  }

  bool get isOwnerOrSuperAdmin {
    final r = userRole.toUpperCase();
    return isSuperAdmin || r == 'PHARMACY_OWNER' || r == 'TENANT_OWNER';
  }

  bool get isBranchManager {
    final r = userRole.toUpperCase();
    return r == 'BRANCH_MANAGER' || r == 'PHARMACY_MANAGER';
  }

  void importSession(MobileActiveSessionRecord session) {
    _sessionCache[session.sessionId] = session;
  }

  void _assertRevocationAuthority(MobileActiveSessionRecord session) {
    if (!isSuperAdmin && tenantId != session.tenantId) {
      throw StateError(
          'ERR_CROSS_TENANT_VIOLATION: Cross-tenant session revocation is strictly forbidden.');
    }

    if (isOwnerOrSuperAdmin) return;

    if (isBranchManager) {
      if (userBranchId != null && userBranchId == session.branchId) {
        return;
      }
      throw StateError(
          'ERR_CROSS_BRANCH_VIOLATION: Branch Manager cannot revoke sessions in another branch.');
    }

    // Cashier: strictly self-only
    if (userId != session.userId) {
      throw StateError(
          "ERR_PERMISSION_DENIED: Staff members cannot revoke another user's session.");
    }
  }

  List<MobileActiveSessionRecord> listSessions({
    String? branchFilter,
    String? userFilter,
    bool? activeOnly,
  }) {
    final results = <MobileActiveSessionRecord>[];

    for (final s in _sessionCache.values) {
      if (tenantId != s.tenantId) continue;

      if (!isOwnerOrSuperAdmin) {
        if (isBranchManager) {
          if (userBranchId != null && userBranchId != s.branchId) continue;
        } else {
          if (userId != s.userId) continue;
        }
      }

      if (branchFilter != null && branchFilter.isNotEmpty && branchFilter != s.branchId) {
        continue;
      }
      if (userFilter != null && userFilter.isNotEmpty && userFilter != s.userId) {
        continue;
      }
      if (activeOnly != null && s.isActive != activeOnly) {
        continue;
      }

      results.add(s);
    }

    results.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return (b.lastSeenAt ?? '').compareTo(a.lastSeenAt ?? '');
    });

    return results;
  }

  MobileSessionRevocationResult revokeSession(String sessionId, {String reason = 'MANUAL_REVOCATION'}) {
    final record = _sessionCache[sessionId];
    if (record == null) {
      throw ArgumentError('SESSION_NOT_FOUND: Session $sessionId not found.');
    }

    _assertRevocationAuthority(record);

    final now = DateTime.now().toUtc().toIso8601String();

    if (_isOffline) {
      _offlineRevocationQueue.add(sessionId);
      final offlineRevoked = MobileActiveSessionRecord(
        sessionId: record.sessionId,
        userId: record.userId,
        userEmail: record.userEmail,
        userFullName: record.userFullName,
        userRole: record.userRole,
        tenantId: record.tenantId,
        branchId: record.branchId,
        deviceId: record.deviceId,
        deviceName: record.deviceName,
        clientPlatform: record.clientPlatform,
        ipAddress: record.ipAddress,
        isActive: false,
        isCurrent: record.isCurrent,
        revocationReason: reason,
        revokedAt: now,
        lastSeenAt: record.lastSeenAt,
        createdAt: record.createdAt,
      );
      _sessionCache[sessionId] = offlineRevoked;

      return MobileSessionRevocationResult(
        sessionId: sessionId,
        status: 'OFFLINE_QUEUED',
        revoked: true,
        messageEn: 'Session marked revoked locally. Queued for online sync.',
        messageBn: 'সেশনটি লোকালি বাতিল করা হয়েছে। অনলাইনে সিঙ্ক হবে।',
      );
    }

    final updated = MobileActiveSessionRecord(
      sessionId: record.sessionId,
      userId: record.userId,
      userEmail: record.userEmail,
      userFullName: record.userFullName,
      userRole: record.userRole,
      tenantId: record.tenantId,
      branchId: record.branchId,
      deviceId: record.deviceId,
      deviceName: record.deviceName,
      clientPlatform: record.clientPlatform,
      ipAddress: record.ipAddress,
      isActive: false,
      isCurrent: record.isCurrent,
      revocationReason: reason,
      revokedAt: now,
      lastSeenAt: record.lastSeenAt,
      createdAt: record.createdAt,
    );
    _sessionCache[sessionId] = updated;

    return MobileSessionRevocationResult(
      sessionId: sessionId,
      status: 'SUCCESS',
      revoked: true,
      messageEn: 'Device session successfully revoked.',
      messageBn: 'ডিভাইস সেশনটি সফলভাবে বাতিল করা হয়েছে।',
    );
  }

  MobileBulkRevocationResult revokeAllSessions({String? targetUserId, String reason = 'LOGOUT_ALL'}) {
    final effectiveTarget = (targetUserId != null && targetUserId.isNotEmpty) ? targetUserId : userId;

    if (!isOwnerOrSuperAdmin && effectiveTarget != userId) {
      if (isBranchManager) {
        bool targetInBranch = false;
        for (final s in _sessionCache.values) {
          if (effectiveTarget == s.userId && userBranchId != null && userBranchId == s.branchId) {
            targetInBranch = true;
            break;
          }
        }
        if (!targetInBranch) {
          throw StateError(
              'ERR_CROSS_BRANCH_VIOLATION: Branch Manager cannot revoke sessions in another branch.');
        }
      } else {
        throw StateError(
            "ERR_PERMISSION_DENIED: Staff members cannot bulk-revoke other users' sessions.");
      }
    }

    int count = 0;
    final now = DateTime.now().toUtc().toIso8601String();

    for (final s in _sessionCache.values) {
      if (effectiveTarget == s.userId && s.isActive) {
        final revoked = MobileActiveSessionRecord(
          sessionId: s.sessionId,
          userId: s.userId,
          userEmail: s.userEmail,
          userFullName: s.userFullName,
          userRole: s.userRole,
          tenantId: s.tenantId,
          branchId: s.branchId,
          deviceId: s.deviceId,
          deviceName: s.deviceName,
          clientPlatform: s.clientPlatform,
          ipAddress: s.ipAddress,
          isActive: false,
          isCurrent: s.isCurrent,
          revocationReason: reason,
          revokedAt: now,
          lastSeenAt: s.lastSeenAt,
          createdAt: s.createdAt,
        );
        _sessionCache[s.sessionId] = revoked;
        count++;
      }
    }

    return MobileBulkRevocationResult(
      status: 'SUCCESS',
      revokedCount: count,
      targetUserId: effectiveTarget,
      messageEn: 'Successfully revoked $count active device session(s).',
      messageBn: 'সফলভাবে $countটি সক্রিয় ডিভাইস সেশন বাতিল করা হয়েছে।',
    );
  }

  int syncOfflineRevocations() {
    final count = _offlineRevocationQueue.length;
    _offlineRevocationQueue.clear();
    return count;
  }

  MobileActiveSessionsUiState getUiState({
    String? branchFilter,
    String? userFilter,
    bool? activeOnly,
  }) {
    if (_isOffline) {
      final cached = listSessions(branchFilter: branchFilter, userFilter: userFilter, activeOnly: activeOnly);
      return MobileActiveSessionsUiState(
        uiStatus: MobileActiveSessionsUiStatus.offline,
        errorMessageEn: 'Running in offline mode. Session revocations queued locally.',
        errorMessageBn: 'মোবাইল অ্যাপটি অফলাইন মোডে চলছে। সেশন বাতিল লোকালি সংরক্ষিত।',
        sessions: cached,
        selectedSession: cached.isNotEmpty ? cached.first : null,
        offlineQueueCount: _offlineRevocationQueue.length,
      );
    }

    final list = listSessions(branchFilter: branchFilter, userFilter: userFilter, activeOnly: activeOnly);
    if (list.isEmpty) {
      return const MobileActiveSessionsUiState(
        uiStatus: MobileActiveSessionsUiStatus.empty,
        sessions: [],
      );
    }

    MobileActiveSessionRecord? current;
    for (final s in list) {
      if (s.isCurrent) {
        current = s;
        break;
      }
    }
    current ??= list.first;

    return MobileActiveSessionsUiState(
      uiStatus: MobileActiveSessionsUiStatus.success,
      sessions: list,
      selectedSession: current,
    );
  }
}
