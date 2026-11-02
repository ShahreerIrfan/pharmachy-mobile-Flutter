// lib/core/cashier/mobile_cashier_register_client.dart
// Architecture Decision: ADR-0117
// Phase 06: Milestone M03 - Cashier Register Assignment & Concurrent Drawer Collision Guard (P117)

enum MobileCashierUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class CashierRegisterAssignmentRecord {
  final String assignmentId;
  final String tenantId;
  final String branchId;
  final String registerId;
  final String cashierId;
  final String cashierName;
  final double openingFloatAmount;
  final double? closingFloatAmount;
  final String status; // ACTIVE, CLOSED, RECONCILED
  final String assignedAt;

  const CashierRegisterAssignmentRecord({
    required this.assignmentId,
    required this.tenantId,
    required this.branchId,
    required this.registerId,
    required this.cashierId,
    required this.cashierName,
    required this.openingFloatAmount,
    this.closingFloatAmount,
    required this.status,
    required this.assignedAt,
  });

  factory CashierRegisterAssignmentRecord.fromJson(Map<String, dynamic> json) {
    return CashierRegisterAssignmentRecord(
      assignmentId: json['assignment_id'] ?? json['id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      branchId: json['branch_id'] ?? '',
      registerId: json['register_id'] ?? '',
      cashierId: json['cashier_id'] ?? '',
      cashierName: json['cashier_name'] ?? '',
      openingFloatAmount: (json['opening_float_amount'] is num)
          ? (json['opening_float_amount'] as num).toDouble()
          : double.tryParse(json['opening_float_amount']?.toString() ?? '0') ?? 0.0,
      closingFloatAmount: json['closing_float_amount'] != null
          ? ((json['closing_float_amount'] is num)
              ? (json['closing_float_amount'] as num).toDouble()
              : double.tryParse(json['closing_float_amount'].toString()))
          : null,
      status: json['status'] ?? 'ACTIVE',
      assignedAt: json['assigned_at'] ?? '',
    );
  }
}

class CashierAssignmentResult {
  final MobileCashierUiStatus uiStatus;
  final CashierRegisterAssignmentRecord? record;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const CashierAssignmentResult({
    required this.uiStatus,
    this.record,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory CashierAssignmentResult.success(CashierRegisterAssignmentRecord record) {
    return CashierAssignmentResult(
      uiStatus: MobileCashierUiStatus.success,
      record: record,
      messageEn: 'Cashier register assigned successfully.',
      messageBn: 'ক্যাশিয়ার রেজিস্টার সফলভাবে বরাদ্দ করা হয়েছে।',
    );
  }

  factory CashierAssignmentResult.error({
    required MobileCashierUiStatus status,
    required String code,
    required String msgEn,
    required String msgBn,
  }) {
    return CashierAssignmentResult(
      uiStatus: status,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileCashierRegisterClient {
  CashierAssignmentResult attemptAssignment({
    required List<CashierRegisterAssignmentRecord> existingAssignments,
    required String callerRole,
    required String callerTenantId,
    required String callerBranchId,
    required String callerStaffId,
    required String targetTenantId,
    required String targetBranchId,
    required String targetRegisterId,
    required String targetCashierId,
    required String targetCashierName,
    required double openingFloatAmount,
  }) {
    // 1. Cross-tenant check
    if (callerTenantId != targetTenantId && callerRole.toUpperCase() != 'SUPERADMIN') {
      return CashierAssignmentResult.error(
        status: MobileCashierUiStatus.permissionDenied,
        code: 'ERR_CROSS_TENANT_VIOLATION',
        msgEn: 'Cross-tenant register assignment forbidden.',
        msgBn: 'অন্য টেন্যান্টের রেজিস্টার বরাদ্দ করা যাবে না।',
      );
    }

    final isOwner = callerRole.toUpperCase() == 'PHARMACY_OWNER' || callerRole.toUpperCase() == 'SUPERADMIN';
    final isManager = callerRole.toUpperCase() == 'BRANCH_MANAGER';

    // 2. Cross-branch check for managers
    if (isManager && callerBranchId != targetBranchId) {
      return CashierAssignmentResult.error(
        status: MobileCashierUiStatus.permissionDenied,
        code: 'ERR_CROSS_BRANCH_VIOLATION',
        msgEn: 'Branch managers cannot assign registers in foreign branches.',
        msgBn: 'শাখা ব্যবস্থাপক অন্য শাখার রেজিস্টার বরাদ্দ করতে পারেন না।',
      );
    }

    // 3. Cashier self-assignment check
    if (!isOwner && !isManager && callerStaffId != targetCashierId) {
      return CashierAssignmentResult.error(
        status: MobileCashierUiStatus.permissionDenied,
        code: 'ERR_PERMISSION_DENIED',
        msgEn: 'Cashiers cannot assign registers to other staff members.',
        msgBn: 'ক্যাশিয়ার অন্য স্টাফের জন্য রেজিস্টার বরাদ্দ করতে পারেন না।',
      );
    }

    // 4. Invariant: Register already assigned
    for (final assignment in existingAssignments) {
      if (assignment.status.toUpperCase() == 'ACTIVE' &&
          assignment.branchId == targetBranchId &&
          assignment.registerId == targetRegisterId) {
        return CashierAssignmentResult.error(
          status: MobileCashierUiStatus.error,
          code: 'ERR_REGISTER_ALREADY_ASSIGNED',
          msgEn: 'Register $targetRegisterId is already assigned to ${assignment.cashierName}',
          msgBn: 'এই রেজিস্টারটি ইতিমধ্যেই সক্রিয়ভাবে বরাদ্দকৃত।',
        );
      }
    }

    // 5. Invariant: Cashier already assigned elsewhere
    for (final assignment in existingAssignments) {
      if (assignment.status.toUpperCase() == 'ACTIVE' && assignment.cashierId == targetCashierId) {
        return CashierAssignmentResult.error(
          status: MobileCashierUiStatus.error,
          code: 'ERR_CASHIER_ALREADY_ASSIGNED',
          msgEn: 'Cashier $targetCashierName is already assigned to register ${assignment.registerId}',
          msgBn: 'এই ক্যাশিয়ার ইতিমধ্যেই অন্য একটি রেজিস্টারে সক্রিয় আছেন।',
        );
      }
    }

    final newRecord = CashierRegisterAssignmentRecord(
      assignmentId: 'cra-mob-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: targetTenantId,
      branchId: targetBranchId,
      registerId: targetRegisterId,
      cashierId: targetCashierId,
      cashierName: targetCashierName,
      openingFloatAmount: openingFloatAmount,
      closingFloatAmount: null,
      status: 'ACTIVE',
      assignedAt: DateTime.now().toIso8601String(),
    );

    return CashierAssignmentResult.success(newRecord);
  }
}
