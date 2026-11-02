// lib/core/security/mobile_rbac_negative_matrix_client.dart
// Architecture Decision: ADR-0120
// Phase 06: Milestone M03 - Comprehensive RBAC Negative Security Matrix (P120)

class MobileRbacDecision {
  final bool isAllowed;
  final int httpStatusCode;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileRbacDecision({
    required this.isAllowed,
    required this.httpStatusCode,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileRbacDecision.permitted() {
    return const MobileRbacDecision(
      isAllowed: true,
      httpStatusCode: 200,
      messageEn: 'Action permitted.',
      messageBn: 'অনুমোদিত অ্যাকশন।',
    );
  }

  factory MobileRbacDecision.forbidden({
    required String code,
    required String msgEn,
    required String msgBn,
  }) {
    return MobileRbacDecision(
      isAllowed: false,
      httpStatusCode: 403,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileRbacNegativeMatrixClient {
  MobileRbacDecision evaluateAction({
    required String callerRole,
    required String callerTenantId,
    required String callerBranchId,
    required String targetTenantId,
    String? targetBranchId,
    required String actionName,
    String subscriptionStatus = 'ACTIVE',
  }) {
    // 1. Cross-Tenant Barrier
    if (callerTenantId != targetTenantId && callerRole.toUpperCase() != 'SUPERADMIN') {
      return MobileRbacDecision.forbidden(
        code: 'ERR_CROSS_TENANT_VIOLATION',
        msgEn: 'Cross-tenant access strictly forbidden.',
        msgBn: 'অন্য টেন্যান্টের ডেটা অ্যাক্সেস নিষিদ্ধ।',
      );
    }

    // 2. Suspended Tenant Barrier
    if (subscriptionStatus.toUpperCase() == 'SUSPENDED' || subscriptionStatus.toUpperCase() == 'ARCHIVED') {
      return MobileRbacDecision.forbidden(
        code: 'ERR_SUBSCRIPTION_UNENTITLED_WRITE_BLOCKED',
        msgEn: 'Tenant subscription is suspended.',
        msgBn: 'টেন্যান্ট অ্যাকাউন্ট স্থগিত থাকায় পরিবর্তন নিষিদ্ধ।',
      );
    }

    final role = callerRole.toUpperCase();
    final isOwner = role == 'PHARMACY_OWNER' || role == 'SUPERADMIN';
    final isManager = role == 'BRANCH_MANAGER';
    final isCashier = role == 'CASHIER';
    final isPharmacist = role == 'STAFF_PHARMACIST' || role == 'PHARMACIST';

    // 3. Actions requiring Pharmacy Owner / Superadmin
    if (actionName == 'ROLE_MIGRATION' || actionName == 'MODIFY_SYSTEM_POLICIES' || actionName == 'MANAGE_BILLING') {
      if (!isOwner) {
        return MobileRbacDecision.forbidden(
          code: 'ERR_STAFF_ROLE_DENIED',
          msgEn: 'Only Pharmacy Owners may execute this administrative action.',
          msgBn: 'শুধুমাত্র ফার্মেসি মালিক এই প্রশাসনিক কাজ করতে পারেন।',
        );
      }
    }

    // 4. Branch Operating Settings
    if (actionName == 'PATCH_BRANCH_SETTINGS') {
      if (isCashier || isPharmacist) {
        return MobileRbacDecision.forbidden(
          code: 'ERR_STAFF_ROLE_DENIED',
          msgEn: 'Cashiers and Pharmacists cannot modify branch operating settings.',
          msgBn: 'ক্যাশিয়ার এবং ফার্মাসিস্ট শাখা সেটিংস পরিবর্তন করতে পারেন না।',
        );
      }
      if (isManager && targetBranchId != null && callerBranchId != targetBranchId) {
        return MobileRbacDecision.forbidden(
          code: 'ERR_CROSS_BRANCH_VIOLATION',
          msgEn: 'Branch managers cannot modify foreign branch settings.',
          msgBn: 'শাখা ব্যবস্থাপক অন্য শাখার সেটিংস পরিবর্তন করতে পারেন না।',
        );
      }
    }

    // 5. Staff Audit Timeline
    if (actionName == 'GET_STAFF_TIMELINE') {
      if (isCashier || isPharmacist) {
        return MobileRbacDecision.forbidden(
          code: 'ERR_STAFF_ROLE_DENIED',
          msgEn: 'Staff role is unauthorized to view staff audit timelines.',
          msgBn: 'স্টাফ অডিট টাইমলাইন দেখার অনুমতি নেই।',
        );
      }
      if (isManager && targetBranchId != null && callerBranchId != targetBranchId) {
        return MobileRbacDecision.forbidden(
          code: 'ERR_CROSS_BRANCH_VIOLATION',
          msgEn: 'Branch managers cannot inspect foreign branch timelines.',
          msgBn: 'শাখা ব্যবস্থাপক অন্য শাখার টাইমলাইন দেখতে পারেন না।',
        );
      }
    }

    // 6. Cashier Drawer Assignment
    if (actionName == 'ASSIGN_OTHER_DRAWER') {
      if (isCashier) {
        return MobileRbacDecision.forbidden(
          code: 'ERR_PERMISSION_DENIED',
          msgEn: 'Cashiers cannot assign registers to other staff members.',
          msgBn: 'ক্যাশিয়ার অন্য স্টাফের জন্য রেজিস্টার বরাদ্দ করতে পারেন না।',
        );
      }
      if (isManager && targetBranchId != null && callerBranchId != targetBranchId) {
        return MobileRbacDecision.forbidden(
          code: 'ERR_CROSS_BRANCH_VIOLATION',
          msgEn: 'Branch managers cannot assign registers in foreign branches.',
          msgBn: 'শাখা ব্যবস্থাপক অন্য শাখার রেজিস্টার বরাদ্দ করতে পারেন না।',
        );
      }
    }

    return MobileRbacDecision.permitted();
  }
}
