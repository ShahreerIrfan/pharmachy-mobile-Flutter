// mobile_inventory_fault_stress_client.dart
// Architecture Decision: ADR-0220 (P220).
// Phase 11 Capstone: Inventory, Warehouse, Cold Chain & Transfers.
//
// Mobile Owner/Manager QA Client wired to /api/v2/inventory/qa-stress/:
// - Supports end-to-end conservation, high-volume stress, concurrent oversell contention,
//   and fault/branch isolation checks.
// - Explicit UI state handling: loading, ready, empty, error, offline, permissionDenied.
// - Bilingual EN/BN diagnostics + strict client-side role/tenant/branch/subscription guards.

import 'package:dio/dio.dart';

enum MobileInventoryStressTestType {
  conservationPipeline(
    'CONSERVATION_PIPELINE',
    'End-to-End Stock Conservation',
    'এন্ড-টু-এন্ড স্টক সংরক্ষণ যাচাই',
  ),
  highVolumeStress(
    'HIGH_VOLUME_STRESS',
    'High-Volume Ledger Stress',
    'উচ্চ-ভলিউম স্টক লেজার স্ট্রেস',
  ),
  concurrentMutation(
    'CONCURRENT_MUTATION',
    'Concurrent Update & Oversell Guard',
    'কনকারেন্ট আপডেট ও ওভারসেল সুরক্ষা',
  ),
  faultAndIsolation(
    'FAULT_AND_ISOLATION',
    'Fault & Branch Isolation Gate',
    'ফল্ট ইনজেকশন ও শাখা সুরক্ষা',
  );

  final String apiValue;
  final String labelEn;
  final String labelBn;

  const MobileInventoryStressTestType(this.apiValue, this.labelEn, this.labelBn);

  static MobileInventoryStressTestType fromApiValue(String value) {
    final normalized = value.toUpperCase();
    return MobileInventoryStressTestType.values.firstWhere(
      (e) => e.apiValue == normalized,
      orElse: () => MobileInventoryStressTestType.conservationPipeline,
    );
  }
}

enum MobileQaUiState {
  loading('Running inventory QA verification...', 'ইনভেন্টরি QA যাচাই চলছে...'),
  ready('QA verification ledger loaded.', 'QA যাচাই ফলাফল লোড হয়েছে।'),
  empty('No inventory QA runs recorded yet.', 'এখনও কোনো ইনভেন্টরি QA রান রেকর্ড হয়নি।'),
  error('QA verification error encountered.', 'QA যাচাই প্রক্রিয়ায় ত্রুটি ঘটেছে।'),
  offline('Offline mode: cloud stress execution unavailable.', 'অফলাইন মোড: ক্লাউড স্ট্রেস টেস্ট চালানো সম্ভব নয়।'),
  permissionDenied('Permission denied for inventory QA.', 'ইনভেন্টরি QA চালানোর অনুমতি নেই।');

  final String messageEn;
  final String messageBn;

  const MobileQaUiState(this.messageEn, this.messageBn);
}

class MobileInventoryFaultStressRun {
  final String runId;
  final String tenantId;
  final String? branchId;
  final String branchName;
  final MobileInventoryStressTestType testType;
  final String status;
  final int totalOperations;
  final int successfulOperations;
  final int rejectedFaults;
  final int initialStockUnits;
  final int finalStockUnits;
  final int netLedgerDeltaUnits;
  final bool conservationVerified;
  final bool branchIsolationVerified;
  final int executionTimeMs;
  final Map<String, dynamic> metricsPayload;
  final String verificationHash;
  final String? executedByEmail;
  final DateTime executedAt;

  const MobileInventoryFaultStressRun({
    required this.runId,
    required this.tenantId,
    required this.branchId,
    required this.branchName,
    required this.testType,
    required this.status,
    required this.totalOperations,
    required this.successfulOperations,
    required this.rejectedFaults,
    required this.initialStockUnits,
    required this.finalStockUnits,
    required this.netLedgerDeltaUnits,
    required this.conservationVerified,
    required this.branchIsolationVerified,
    required this.executionTimeMs,
    required this.metricsPayload,
    required this.verificationHash,
    required this.executedByEmail,
    required this.executedAt,
  });

  factory MobileInventoryFaultStressRun.fromJson(Map<String, dynamic> json) {
    return MobileInventoryFaultStressRun(
      runId: (json['run_id'] ?? '') as String,
      tenantId: (json['tenant_id'] ?? '') as String,
      branchId: json['branch_id'] as String?,
      branchName: (json['branch_name'] ?? '') as String,
      testType: MobileInventoryStressTestType.fromApiValue((json['test_type'] ?? '') as String),
      status: (json['status'] ?? 'FAILED') as String,
      totalOperations: (json['total_operations'] ?? 0) as int,
      successfulOperations: (json['successful_operations'] ?? 0) as int,
      rejectedFaults: (json['rejected_faults'] ?? 0) as int,
      initialStockUnits: (json['initial_stock_units'] ?? 0) as int,
      finalStockUnits: (json['final_stock_units'] ?? 0) as int,
      netLedgerDeltaUnits: (json['net_ledger_delta_units'] ?? 0) as int,
      conservationVerified: (json['conservation_verified'] ?? false) as bool,
      branchIsolationVerified: (json['branch_isolation_verified'] ?? false) as bool,
      executionTimeMs: (json['execution_time_ms'] ?? 0) as int,
      metricsPayload: Map<String, dynamic>.from((json['metrics_payload'] ?? const <String, dynamic>{}) as Map),
      verificationHash: (json['verification_hash'] ?? '') as String,
      executedByEmail: json['executed_by_email'] as String?,
      executedAt: json['executed_at'] != null
          ? DateTime.parse(json['executed_at'] as String)
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'run_id': runId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'branch_name': branchName,
        'test_type': testType.apiValue,
        'status': status,
        'total_operations': totalOperations,
        'successful_operations': successfulOperations,
        'rejected_faults': rejectedFaults,
        'initial_stock_units': initialStockUnits,
        'final_stock_units': finalStockUnits,
        'net_ledger_delta_units': netLedgerDeltaUnits,
        'conservation_verified': conservationVerified,
        'branch_isolation_verified': branchIsolationVerified,
        'execution_time_ms': executionTimeMs,
        'metrics_payload': metricsPayload,
        'verification_hash': verificationHash,
        'executed_by_email': executedByEmail,
        'executed_at': executedAt.toUtc().toIso8601String(),
      };
}

class MobileQaHttpResponse {
  final int statusCode;
  final Map<String, dynamic> data;

  const MobileQaHttpResponse({required this.statusCode, required this.data});
}

typedef MobileQaTransport = Future<MobileQaHttpResponse> Function(
  String method,
  String path, {
  Map<String, dynamic>? body,
  String? bearerToken,
});

class MobileQaClientOutcome<T> {
  final MobileQaUiState uiState;
  final T? data;
  final String errorCode;
  final String messageEn;
  final String messageBn;

  const MobileQaClientOutcome({
    required this.uiState,
    this.data,
    this.errorCode = '',
    required this.messageEn,
    required this.messageBn,
  });
}

class MobileInventoryFaultStressClient {
  static const Set<String> _allowedQaRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'STAFF_PHARMACIST',
    'AUDITOR',
    'CHIEF_PHARMACIST',
  };

  static const Set<String> _tenantWideRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'AUDITOR',
  };

  final String baseUrl;
  final MobileQaTransport _transport;
  MobileQaUiState currentState = MobileQaUiState.empty;

  MobileInventoryFaultStressClient({
    required this.baseUrl,
    MobileQaTransport? transport,
    Dio? dio,
  }) : _transport = transport ?? _createDioTransport(baseUrl, dio);

  static MobileQaTransport _createDioTransport(String rootUrl, Dio? customDio) {
    final normalizedRoot = rootUrl.replaceAll(RegExp(r'/+$'), '');
    final dio = customDio ??
        Dio(BaseOptions(
          baseUrl: normalizedRoot,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (_) => true,
        ));
    return (
      String method,
      String path, {
      Map<String, dynamic>? body,
      String? bearerToken,
    }) async {
      final options = Options(
        method: method,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (bearerToken != null && bearerToken.isNotEmpty)
            'Authorization': 'Bearer $bearerToken',
        },
      );
      final resp = await dio.request<dynamic>(path, data: body, options: options);
      final payload = resp.data is Map<String, dynamic>
          ? resp.data as Map<String, dynamic>
          : <String, dynamic>{'raw': resp.data};
      return MobileQaHttpResponse(statusCode: resp.statusCode ?? 500, data: payload);
    };
  }

  MobileQaClientOutcome<void> authorizeScope({
    required String actorRole,
    required String actorTenantId,
    required String actorAssignedBranchId,
    required String targetTenantId,
    required String targetBranchId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) {
    if (isOffline) {
      currentState = MobileQaUiState.offline;
      return MobileQaClientOutcome(
        uiState: MobileQaUiState.offline,
        errorCode: 'ERR_OFFLINE_UNAVAILABLE',
        messageEn: MobileQaUiState.offline.messageEn,
        messageBn: MobileQaUiState.offline.messageBn,
      );
    }

    if (subscriptionSuspended) {
      currentState = MobileQaUiState.permissionDenied;
      return const MobileQaClientOutcome(
        uiState: MobileQaUiState.permissionDenied,
        errorCode: 'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant subscription is suspended or expired. Inventory QA operations are locked.',
        messageBn: 'টেন্যান্ট সাবস্ক্রিপশন স্থগিত বা মেয়াদোত্তীর্ণ। এই অপারেশন লক করা হয়েছে।',
      );
    }

    final roleUpper = actorRole.trim().toUpperCase();
    if (roleUpper == 'CASHIER' || !_allowedQaRoles.contains(roleUpper)) {
      currentState = MobileQaUiState.permissionDenied;
      return MobileQaClientOutcome(
        uiState: MobileQaUiState.permissionDenied,
        errorCode: 'ERR_PERMISSION_DENIED',
        messageEn: "Role '$roleUpper' is forbidden from running inventory fault and stress verification.",
        messageBn: "'$roleUpper' রোল-এর জন্য ইনভেন্টরি স্ট্রেস ও ফল্ট টেস্ট চালানো নিষিদ্ধ।",
      );
    }

    if (roleUpper != 'SUPERADMIN' && actorTenantId != targetTenantId) {
      currentState = MobileQaUiState.error;
      return const MobileQaClientOutcome(
        uiState: MobileQaUiState.error,
        errorCode: 'ERR_CROSS_TENANT_NOT_FOUND',
        messageEn: 'Target branch was not found in your pharmacy tenant.',
        messageBn: 'অন্য টেন্যান্টের শাখায় প্রবেশ অনুমোদিত নয়।',
      );
    }

    if (!_tenantWideRoles.contains(roleUpper) && actorAssignedBranchId != targetBranchId) {
      currentState = MobileQaUiState.permissionDenied;
      return MobileQaClientOutcome(
        uiState: MobileQaUiState.permissionDenied,
        errorCode: 'ERR_CROSS_BRANCH_ACCESS_DENIED',
        messageEn: "Branch-bound staff cannot execute QA diagnostics for sibling branch '$targetBranchId'.",
        messageBn: 'শাখার সীমানা লঙ্ঘন: নির্ধারিত শাখার বাইরে স্ট্রেস টেস্ট অনুমোদিত নয়।',
      );
    }

    return const MobileQaClientOutcome(
      uiState: MobileQaUiState.ready,
      messageEn: 'Authorized',
      messageBn: 'অনুমোদিত',
    );
  }

  Future<MobileQaClientOutcome<MobileInventoryFaultStressRun>> triggerRemoteVerification({
    required MobileInventoryStressTestType testType,
    required Map<String, dynamic> payload,
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorAssignedBranchId,
    required String targetTenantId,
    required String targetBranchId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final auth = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorAssignedBranchId: actorAssignedBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (auth.uiState != MobileQaUiState.ready) {
      return MobileQaClientOutcome(
        uiState: auth.uiState,
        errorCode: auth.errorCode,
        messageEn: auth.messageEn,
        messageBn: auth.messageBn,
      );
    }

    currentState = MobileQaUiState.loading;
    final endpoint = switch (testType) {
      MobileInventoryStressTestType.conservationPipeline => '/api/v2/inventory/qa-stress/verify-conservation/',
      MobileInventoryStressTestType.highVolumeStress => '/api/v2/inventory/qa-stress/run-high-volume/',
      MobileInventoryStressTestType.concurrentMutation => '/api/v2/inventory/qa-stress/run-concurrency/',
      MobileInventoryStressTestType.faultAndIsolation => '/api/v2/inventory/qa-stress/verify-fault-isolation/',
    };

    try {
      final res = await _transport('POST', endpoint, body: payload, bearerToken: bearerToken);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final dto = MobileInventoryFaultStressRun.fromJson(res.data);
        currentState = MobileQaUiState.ready;
        return MobileQaClientOutcome(
          uiState: MobileQaUiState.ready,
          data: dto,
          messageEn: '${testType.labelEn} passed successfully.',
          messageBn: '${testType.labelBn} সফলভাবে সম্পন্ন হয়েছে।',
        );
      } else if (res.statusCode == 403) {
        currentState = MobileQaUiState.permissionDenied;
        return MobileQaClientOutcome(
          uiState: MobileQaUiState.permissionDenied,
          errorCode: (res.data['error_code'] ?? 'ERR_PERMISSION_DENIED') as String,
          messageEn: 'Server denied QA stress execution (HTTP 403).',
          messageBn: 'সার্ভার অনুমতি প্রত্যাখ্যান করেছে (HTTP 403)।',
        );
      } else {
        currentState = MobileQaUiState.error;
        return MobileQaClientOutcome(
          uiState: MobileQaUiState.error,
          errorCode: 'ERR_HTTP_${res.statusCode}',
          messageEn: 'QA execution rejected (HTTP ${res.statusCode}).',
          messageBn: 'QA যাচাই ব্যর্থ হয়েছে (HTTP ${res.statusCode})।',
        );
      }
    } catch (e) {
      currentState = MobileQaUiState.offline;
      return MobileQaClientOutcome(
        uiState: MobileQaUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network error reaching $baseUrl$endpoint: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন। ক্লাউড QA সার্ভারে পৌঁছানো যাচ্ছে না।',
      );
    }
  }

  Future<MobileQaClientOutcome<List<MobileInventoryFaultStressRun>>> fetchRunHistory({
    String? branchId,
    required String bearerToken,
    bool isOffline = false,
  }) async {
    if (isOffline) {
      currentState = MobileQaUiState.offline;
      return MobileQaClientOutcome(
        uiState: MobileQaUiState.offline,
        data: const [],
        errorCode: 'ERR_OFFLINE_UNAVAILABLE',
        messageEn: MobileQaUiState.offline.messageEn,
        messageBn: MobileQaUiState.offline.messageBn,
      );
    }

    currentState = MobileQaUiState.loading;
    final path = '/api/v2/inventory/qa-stress/${(branchId != null && branchId.isNotEmpty) ? '?branch=$branchId' : ''}';
    try {
      final res = await _transport('GET', path, bearerToken: bearerToken);
      if (res.statusCode == 200) {
        final rawList = (res.data['results'] ?? res.data['data'] ?? const <dynamic>[]) as List<dynamic>;
        final runs = List<MobileInventoryFaultStressRun>.unmodifiable(
          rawList.map((item) => MobileInventoryFaultStressRun.fromJson(Map<String, dynamic>.from(item as Map))),
        );
        currentState = runs.isEmpty ? MobileQaUiState.empty : MobileQaUiState.ready;
        return MobileQaClientOutcome(
          uiState: currentState,
          data: runs,
          messageEn: currentState.messageEn,
          messageBn: currentState.messageBn,
        );
      } else if (res.statusCode == 403) {
        currentState = MobileQaUiState.permissionDenied;
        return MobileQaClientOutcome(
          uiState: MobileQaUiState.permissionDenied,
          data: const [],
          errorCode: 'ERR_PERMISSION_DENIED',
          messageEn: MobileQaUiState.permissionDenied.messageEn,
          messageBn: MobileQaUiState.permissionDenied.messageBn,
        );
      } else {
        currentState = MobileQaUiState.error;
        return MobileQaClientOutcome(
          uiState: MobileQaUiState.error,
          data: const [],
          errorCode: 'ERR_HTTP_${res.statusCode}',
          messageEn: 'Failed to load QA run history: HTTP ${res.statusCode}',
          messageBn: 'QA ইতিহাস লোড ব্যর্থ হয়েছে: HTTP ${res.statusCode}',
        );
      }
    } catch (_) {
      currentState = MobileQaUiState.offline;
      return MobileQaClientOutcome(
        uiState: MobileQaUiState.offline,
        data: const [],
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: MobileQaUiState.offline.messageEn,
        messageBn: MobileQaUiState.offline.messageBn,
      );
    }
  }
}
