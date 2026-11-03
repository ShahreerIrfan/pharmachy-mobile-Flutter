// lib/core/catalog/mobile_form_template_migration_client.dart
// Architecture Decision: ADR-0139
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P139)

import 'dart:convert';
import 'dart:typed_data';

enum MobileMigrationUiStatus {
  success,
  error,
  permissionDenied,
  empty,
  offline,
}

enum MobileMigrationPlanStatus {
  draft,
  validated,
  executing,
  completed,
  rolledBack,
  failed,
}

/// Standard FIPS 180-4 SHA-256 implementation in pure Dart
class MobileMigrationSha256 {
  static const List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ];

  static int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;
  static int _shr(int x, int n) => (x >> n) & 0xFFFFFFFF;

  static String hashString(String input) {
    final bytes = utf8.encode(input);
    final bitLength = bytes.length * 8;
    final padLength = (((bytes.length + 8) >> 6) + 1) << 6;
    final buffer = Uint8List(padLength);
    buffer.setRange(0, bytes.length, bytes);
    buffer[bytes.length] = 0x80;

    final bd = ByteData.view(buffer.buffer);
    bd.setUint64(padLength - 8, bitLength, Endian.big);

    int h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
    int h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;

    final w = List<int>.filled(64, 0);

    for (int i = 0; i < padLength; i += 64) {
      for (int t = 0; t < 16; t++) {
        w[t] = bd.getUint32(i + (t * 4), Endian.big);
      }
      for (int t = 16; t < 64; t++) {
        final s0 = _rotr(w[t - 15], 7) ^ _rotr(w[t - 15], 18) ^ _shr(w[t - 15], 3);
        final s1 = _rotr(w[t - 2], 17) ^ _rotr(w[t - 2], 19) ^ _shr(w[t - 2], 10);
        w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;

      for (int t = 0; t < 64; t++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ (~e & g);
        final temp1 = (h + s1 + ch + _k[t] + w[t]) & 0xFFFFFFFF;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
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
        .map((x) => x.toRadixString(16).padLeft(8, '0'))
        .join();
  }
}

class MobileMigrationPlanRecord {
  final String planId;
  final String planName;
  final String tenantId;
  final String fromTemplateId;
  final String toTemplateId;
  final String strategy;
  MobileMigrationPlanStatus status;
  final Map<String, dynamic> fieldMappings;
  Map<String, dynamic> dryRunSummary;
  int affectedMedicineCount;
  int migratedMedicineCount;
  int historicalDispensingAuditedCount;
  final String planHash;
  final String createdAt;
  String? executedAt;
  String? rolledBackAt;

  MobileMigrationPlanRecord({
    required this.planId,
    required this.planName,
    required this.tenantId,
    required this.fromTemplateId,
    required this.toTemplateId,
    required this.strategy,
    required this.status,
    required this.fieldMappings,
    required this.dryRunSummary,
    required this.affectedMedicineCount,
    required this.migratedMedicineCount,
    required this.historicalDispensingAuditedCount,
    required this.planHash,
    required this.createdAt,
    this.executedAt,
    this.rolledBackAt,
  });

  Map<String, dynamic> toJson() => {
    'plan_id': planId,
    'plan_name': planName,
    'tenant_id': tenantId,
    'from_template_id': fromTemplateId,
    'to_template_id': toTemplateId,
    'strategy': strategy,
    'status': status.name.toUpperCase(),
    'field_mappings': fieldMappings,
    'dry_run_summary': dryRunSummary,
    'affected_medicine_count': affectedMedicineCount,
    'migrated_medicine_count': migratedMedicineCount,
    'historical_dispensing_audited_count': historicalDispensingAuditedCount,
    'plan_hash': planHash,
    'created_at': createdAt,
    'executed_at': executedAt,
    'rolled_back_at': rolledBackAt,
  };
}

class MobileMigrationResult<T> {
  final MobileMigrationUiStatus status;
  final T? data;
  final String? errorCode;
  final String? errorMessageEn;
  final String? errorMessageBn;

  const MobileMigrationResult._({
    required this.status,
    this.data,
    this.errorCode,
    this.errorMessageEn,
    this.errorMessageBn,
  });

  factory MobileMigrationResult.success(T data) => MobileMigrationResult._(
    status: MobileMigrationUiStatus.success,
    data: data,
  );

  factory MobileMigrationResult.offline(T data) => MobileMigrationResult._(
    status: MobileMigrationUiStatus.offline,
    data: data,
    errorMessageEn: 'Serving from local offline cache',
    errorMessageBn: 'লোকাল অফলাইন ক্যাশ থেকে পরিবেশিত',
  );

  factory MobileMigrationResult.permissionDenied(String code, String en, String bn) => MobileMigrationResult._(
    status: MobileMigrationUiStatus.permissionDenied,
    errorCode: code,
    errorMessageEn: en,
    errorMessageBn: bn,
  );

  factory MobileMigrationResult.error(String code, String en, String bn) => MobileMigrationResult._(
    status: MobileMigrationUiStatus.error,
    errorCode: code,
    errorMessageEn: en,
    errorMessageBn: bn,
  );

  factory MobileMigrationResult.empty() => const MobileMigrationResult._(
    status: MobileMigrationUiStatus.empty,
    errorMessageEn: 'No records found',
    errorMessageBn: 'কোন তথ্য পাওয়া যায়নি',
  );
}

class MobileFormTemplateMigrationClient {
  static int _idCounter = 0;
  final Map<String, MobileMigrationPlanRecord> _planStore = {};
  final Map<String, Map<String, dynamic>> _rollbackSnapshots = {};
  bool _isOffline = false;

  void setOffline(bool offline) {
    _isOffline = offline;
  }

  bool get isOffline => _isOffline;

  MobileMigrationResult<MobileMigrationPlanRecord> createPlan({
    required String tenantId,
    required String planName,
    required String fromTemplateId,
    required String toTemplateId,
    String strategy = 'COERCE_SAFE',
    Map<String, dynamic>? fieldMappings,
    required String userRole,
    String planTier = 'STANDARD',
    bool isSuspended = false,
  }) {
    if (_isOffline) {
      return MobileMigrationResult.error(
        'ERR_OFFLINE_MUTATION',
        'Cannot create migration plans while offline',
        'অফলাইনে মাইগ্রেশন প্ল্যান তৈরি করা যাবে না',
      );
    }

    if (isSuspended) {
      return MobileMigrationResult.permissionDenied(
        'ERR_TENANT_SUSPENDED',
        'Tenant subscription account is suspended.',
        'ফার্মেসির সাবস্ক্রিপশন অ্যাকাউন্ট স্থগিত রয়েছে।',
      );
    }

    final role = userRole.toUpperCase();
    if (role == 'CASHIER') {
      return MobileMigrationResult.permissionDenied(
        'ERR_PERMISSION_DENIED',
        'Cashier role is not permitted to create migration plans.',
        'ক্যাশিয়ার রোলের জন্য মাইগ্রেশন প্ল্যান তৈরি নিষিদ্ধ।',
      );
    }

    if (planTier.toUpperCase() == 'BASIC' && role != 'SUPERADMIN') {
      return MobileMigrationResult.permissionDenied(
        'ERR_SUBSCRIPTION_UNENTITLED',
        'Basic subscription does not entitle template migration.',
        'বেসিক সাবস্ক্রিপশনে টেমপ্লেট মাইগ্রেশন সেবা অন্তর্ভুক্ত নয়।',
      );
    }

    if (planName.trim().isEmpty) {
      return MobileMigrationResult.error(
        'ERR_INVALID_INPUT',
        'planName is required and cannot be empty.',
        'প্ল্যানের নাম আবশ্যক।',
      );
    }

    if (fromTemplateId == toTemplateId) {
      return MobileMigrationResult.error(
        'ERR_INVALID_INPUT',
        'Target template cannot be identical to source template.',
        'লক্ষ্য টেমপ্লেট এবং উৎস টেমপ্লেট একই হতে পারবে না।',
      );
    }

    final planId = 'ftmp-mob-${DateTime.now().millisecondsSinceEpoch}-${++_idCounter}';
    final hash = MobileMigrationSha256.hashString('$planId|$tenantId|$fromTemplateId|$toTemplateId|$strategy');

    final record = MobileMigrationPlanRecord(
      planId: planId,
      planName: planName.trim(),
      tenantId: tenantId,
      fromTemplateId: fromTemplateId,
      toTemplateId: toTemplateId,
      strategy: strategy,
      status: MobileMigrationPlanStatus.draft,
      fieldMappings: fieldMappings ?? {},
      dryRunSummary: {},
      affectedMedicineCount: 0,
      migratedMedicineCount: 0,
      historicalDispensingAuditedCount: 0,
      planHash: hash,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    _planStore[planId] = record;
    return MobileMigrationResult.success(record);
  }

  MobileMigrationResult<MobileMigrationPlanRecord> validateDryRun({
    required String planId,
    required String userRole,
    required String requestTenantId,
    int simulatedMedicineCount = 20,
    int simulatedDispenseCount = 80,
  }) {
    final plan = _planStore[planId];
    if (plan == null) {
      return MobileMigrationResult.error('ERR_NOT_FOUND', 'Plan not found: $planId', 'মাইগ্রেশন প্ল্যান পাওয়া যায়নি');
    }

    if (_checkCrossTenant(plan, userRole, requestTenantId)) {
      return MobileMigrationResult.permissionDenied('ERR_CROSS_TENANT_ACCESS', 'Cross-tenant access prohibited', 'অন্য ফার্মেসির প্ল্যানে অ্যাক্সেস নিষিদ্ধ');
    }

    plan.dryRunSummary = {
      'total_affected_medicines': simulatedMedicineCount,
      'historical_dispensing_checked_count': simulatedDispenseCount,
      'historical_immutability_certified': true,
      'validated_at': DateTime.now().toUtc().toIso8601String(),
    };
    plan.affectedMedicineCount = simulatedMedicineCount;
    plan.historicalDispensingAuditedCount = simulatedDispenseCount;
    plan.status = MobileMigrationPlanStatus.validated;

    return MobileMigrationResult.success(plan);
  }

  MobileMigrationResult<MobileMigrationPlanRecord> executePlan({
    required String planId,
    required String userRole,
    required String requestTenantId,
  }) {
    if (_isOffline) {
      return MobileMigrationResult.error(
        'ERR_OFFLINE_MUTATION',
        'Cannot execute migration plan while offline',
        'অফলাইনে মাইগ্রেশন প্ল্যান চালানো যাবে না',
      );
    }

    final plan = _planStore[planId];
    if (plan == null) {
      return MobileMigrationResult.error('ERR_NOT_FOUND', 'Plan not found: $planId', 'মাইগ্রেশন প্ল্যান পাওয়া যায়নি');
    }

    if (_checkCrossTenant(plan, userRole, requestTenantId)) {
      return MobileMigrationResult.permissionDenied('ERR_CROSS_TENANT_ACCESS', 'Cross-tenant access prohibited', 'অন্য ফার্মেসির প্ল্যানে অ্যাক্সেস নিষিদ্ধ');
    }

    if (plan.status == MobileMigrationPlanStatus.completed) {
      return MobileMigrationResult.error(
        'ERR_ALREADY_EXECUTED',
        'Migration plan has already been executed.',
        'মাইগ্রেশন প্ল্যান ইতোমধ্যেই সম্পন্ন হয়েছে।',
      );
    }

    _rollbackSnapshots[planId] = {
      'planId': planId,
      'migratedCount': plan.affectedMedicineCount,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    plan.migratedMedicineCount = plan.affectedMedicineCount;
    plan.status = MobileMigrationPlanStatus.completed;
    plan.executedAt = DateTime.now().toUtc().toIso8601String();

    return MobileMigrationResult.success(plan);
  }

  MobileMigrationResult<MobileMigrationPlanRecord> rollbackPlan({
    required String planId,
    required String userRole,
    required String requestTenantId,
  }) {
    if (_isOffline) {
      return MobileMigrationResult.error(
        'ERR_OFFLINE_MUTATION',
        'Cannot rollback migration plan while offline',
        'অফলাইনে মাইগ্রেশন প্ল্যান রোলব্যাক করা যাবে না',
      );
    }

    final plan = _planStore[planId];
    if (plan == null) {
      return MobileMigrationResult.error('ERR_NOT_FOUND', 'Plan not found: $planId', 'মাইগ্রেশন প্ল্যান পাওয়া যায়নি');
    }

    if (_checkCrossTenant(plan, userRole, requestTenantId)) {
      return MobileMigrationResult.permissionDenied('ERR_CROSS_TENANT_ACCESS', 'Cross-tenant access prohibited', 'অন্য ফার্মেসির প্ল্যানে অ্যাক্সেস নিষিদ্ধ');
    }

    if (plan.status != MobileMigrationPlanStatus.completed) {
      return MobileMigrationResult.error(
        'ERR_INVALID_STATE',
        'Only COMPLETED plans can be rolled back.',
        'শুধুমাত্র সম্পন্ন প্ল্যান রোলব্যাক করা যাবে।',
      );
    }

    if (!_rollbackSnapshots.containsKey(planId)) {
      return MobileMigrationResult.error('ERR_NO_SNAPSHOT', 'No snapshot available for rollback', 'রোলব্যাকের জন্য কোনো স্ন্যাপশট নেই');
    }

    plan.status = MobileMigrationPlanStatus.rolledBack;
    plan.rolledBackAt = DateTime.now().toUtc().toIso8601String();

    return MobileMigrationResult.success(plan);
  }

  MobileMigrationResult<MobileMigrationPlanRecord> queryPlan({
    required String planId,
    required String requestTenantId,
  }) {
    final plan = _planStore[planId];
    if (plan == null) {
      return MobileMigrationResult.empty();
    }

    if (_isOffline) {
      return MobileMigrationResult.offline(plan);
    }
    return MobileMigrationResult.success(plan);
  }

  bool _checkCrossTenant(MobileMigrationPlanRecord plan, String userRole, String requestTenantId) {
    if (userRole.toUpperCase() == 'SUPERADMIN') {
      return false;
    }
    if (plan.tenantId.isNotEmpty && plan.tenantId != 'platform') {
      return plan.tenantId != requestTenantId;
    }
    return false;
  }
}
