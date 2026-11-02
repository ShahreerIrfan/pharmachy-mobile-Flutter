import 'dart:convert';

/// P110: Fine-Grained Field Visibility & Sensitive Data Masking Client (Flutter Mobile).
/// ADR-0110: Masks wholesale purchase costs, gross/net profits, staff salaries,
/// clinical prescriptions, and patient PII for retail pharmacy staff.
class MobileFieldVisibilityProfile {
  final String userId;
  final String tenantId;
  final String role;
  final bool costVisibility;
  final bool profitVisibility;
  final bool salaryVisibility;
  final bool prescriptionVisibility;
  final bool patientPiiVisibility;

  const MobileFieldVisibilityProfile({
    required this.userId,
    required this.tenantId,
    required this.role,
    required this.costVisibility,
    required this.profitVisibility,
    required this.salaryVisibility,
    required this.prescriptionVisibility,
    required this.patientPiiVisibility,
  });

  bool get isOwnerOrSuperAdmin =>
      role == 'PHARMACY_OWNER' || role == 'SUPERADMIN' || role == 'SUPER_ADMIN';

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'tenant_id': tenantId,
        'role': role,
        'visibility_permissions': {
          'cost_visibility': costVisibility,
          'profit_visibility': profitVisibility,
          'salary_visibility': salaryVisibility,
          'prescription_visibility': prescriptionVisibility,
          'patient_pii_visibility': patientPiiVisibility,
        },
      };
}

class MobileMaskedMedicine {
  final String productId;
  final String brandName;
  final double mrpUnit;
  final double? costUnit; // null if masked
  final bool isCostMasked;

  const MobileMaskedMedicine({
    required this.productId,
    required this.brandName,
    required this.mrpUnit,
    required this.costUnit,
    required this.isCostMasked,
  });

  String getDisplayCost([String language = 'en']) {
    if (isCostMasked || costUnit == null) {
      return '***';
    }
    return '৳${costUnit!.toStringAsFixed(2)}';
  }

  String getCostBadge([String language = 'en']) {
    if (!isCostMasked) return '';
    return language == 'bn' ? 'ক্রয়মূল্য সংরক্ষিত' : 'Cost Restricted';
  }
}

class MobileMaskedInvoice {
  final String invoiceId;
  final String customerName; // e.g. "R**** U****" if masked
  final String customerPhone; // e.g. "017****5678" if masked
  final double totalAmount;
  final double? cogsAmount; // null if cost masked
  final double? grossProfit; // null if profit masked
  final bool isCostMasked;
  final bool isProfitMasked;
  final bool isPiiMasked;

  const MobileMaskedInvoice({
    required this.invoiceId,
    required this.customerName,
    required this.customerPhone,
    required this.totalAmount,
    required this.cogsAmount,
    required this.grossProfit,
    required this.isCostMasked,
    required this.isProfitMasked,
    required this.isPiiMasked,
  });

  String getDisplayProfit([String language = 'en']) {
    if (isProfitMasked || grossProfit == null) {
      return '***';
    }
    return '৳${grossProfit!.toStringAsFixed(2)}';
  }
}

class MobileMaskedSalary {
  final String salaryId;
  final String staffUserId;
  final String username;
  final double? baseSalaryBdt; // null if masked
  final String bankAccountNo; // "***REDACTED***" if masked
  final bool isSalaryMasked;

  const MobileMaskedSalary({
    required this.salaryId,
    required this.staffUserId,
    required this.username,
    required this.baseSalaryBdt,
    required this.bankAccountNo,
    required this.isSalaryMasked,
  });

  String getDisplaySalary([String language = 'en']) {
    if (isSalaryMasked || baseSalaryBdt == null) {
      return '***REDACTED***';
    }
    return '৳${baseSalaryBdt!.toStringAsFixed(2)}';
  }
}

class MobileMaskedPrescription {
  final String prescriptionId;
  final String doctorName;
  final String diagnosis; // "[CLINICAL_DIAGNOSIS_REDACTED]" if masked
  final String notes; // "[CONFIDENTIAL_CLINICAL_NOTES]" if masked
  final String? prescriptionImageUrl; // null if masked
  final bool isPrescriptionMasked;

  const MobileMaskedPrescription({
    required this.prescriptionId,
    required this.doctorName,
    required this.diagnosis,
    required this.notes,
    required this.prescriptionImageUrl,
    required this.isPrescriptionMasked,
  });
}

class MobileFieldVisibilityClient {
  static String maskPhoneNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '***';
    final s = phone.trim();
    if (s.length >= 11) {
      return '${s.substring(0, 3)}****${s.substring(s.length - 4)}';
    } else if (s.length >= 6) {
      return '${s.substring(0, 2)}****${s.substring(s.length - 2)}';
    }
    return '***REDACTED***';
  }

  static String maskPersonName(String? name) {
    if (name == null || name.trim().isEmpty) return '***';
    final parts = name.trim().split(RegExp(r'\s+'));
    final masked = parts.map((p) {
      if (p.length > 1) {
        return '${p[0]}****';
      }
      return p;
    }).toList();
    return masked.join(' ');
  }

  static MobileFieldVisibilityProfile resolveProfile({
    required String userId,
    required String tenantId,
    required String role,
    List<String> customKeys = const [],
  }) {
    final cleanRole = role.toUpperCase().trim();

    // 1. Superadmin & Owner
    if (cleanRole == 'PHARMACY_OWNER' ||
        cleanRole == 'SUPERADMIN' ||
        cleanRole == 'SUPER_ADMIN') {
      return MobileFieldVisibilityProfile(
        userId: userId,
        tenantId: tenantId,
        role: cleanRole,
        costVisibility: true,
        profitVisibility: true,
        salaryVisibility: true,
        prescriptionVisibility: true,
        patientPiiVisibility: true,
      );
    }

    // 2. Custom Role Overrides
    if (customKeys.isNotEmpty) {
      final keySet = customKeys.toSet();
      return MobileFieldVisibilityProfile(
        userId: userId,
        tenantId: tenantId,
        role: cleanRole,
        costVisibility: keySet.contains('cost_visibility') ||
            keySet.contains('action:cost_visibility') ||
            keySet.contains('inventory:view_cost'),
        profitVisibility: keySet.contains('profit_visibility') ||
            keySet.contains('action:profit_visibility') ||
            keySet.contains('finance:profit_visibility'),
        salaryVisibility: keySet.contains('salary_visibility') ||
            keySet.contains('action:salary_visibility') ||
            keySet.contains('hr:view_salary'),
        prescriptionVisibility: keySet.contains('prescription_visibility') ||
            keySet.contains('action:rx_review') ||
            keySet.contains('rx:verify'),
        patientPiiVisibility: keySet.contains('patient_pii_visibility') ||
            keySet.contains('patient:view_pii'),
      );
    }

    // 3. Canonical System Defaults (ADR-0110)
    switch (cleanRole) {
      case 'BRANCH_MANAGER':
        return MobileFieldVisibilityProfile(
          userId: userId,
          tenantId: tenantId,
          role: cleanRole,
          costVisibility: true,
          profitVisibility: false,
          salaryVisibility: false,
          prescriptionVisibility: true,
          patientPiiVisibility: true,
        );
      case 'FINANCE_OFFICER':
        return MobileFieldVisibilityProfile(
          userId: userId,
          tenantId: tenantId,
          role: cleanRole,
          costVisibility: true,
          profitVisibility: true,
          salaryVisibility: true,
          prescriptionVisibility: false,
          patientPiiVisibility: false,
        );
      case 'STAFF_PHARMACIST':
      case 'PHARMACIST':
        return MobileFieldVisibilityProfile(
          userId: userId,
          tenantId: tenantId,
          role: cleanRole,
          costVisibility: false,
          profitVisibility: false,
          salaryVisibility: false,
          prescriptionVisibility: true,
          patientPiiVisibility: true,
        );
      case 'INVENTORY_CLERK':
        return MobileFieldVisibilityProfile(
          userId: userId,
          tenantId: tenantId,
          role: cleanRole,
          costVisibility: true,
          profitVisibility: false,
          salaryVisibility: false,
          prescriptionVisibility: false,
          patientPiiVisibility: false,
        );
      case 'AUDITOR':
        return MobileFieldVisibilityProfile(
          userId: userId,
          tenantId: tenantId,
          role: cleanRole,
          costVisibility: true,
          profitVisibility: true,
          salaryVisibility: false,
          prescriptionVisibility: true,
          patientPiiVisibility: true,
        );
      case 'CASHIER':
      default:
        return MobileFieldVisibilityProfile(
          userId: userId,
          tenantId: tenantId,
          role: cleanRole,
          costVisibility: false,
          profitVisibility: false,
          salaryVisibility: false,
          prescriptionVisibility: false,
          patientPiiVisibility: false,
        );
    }
  }

  static MobileMaskedMedicine maskMedicine({
    required String productId,
    required String brandName,
    required double mrpUnit,
    required double? costUnit,
    required MobileFieldVisibilityProfile profile,
  }) {
    final maskCost = !profile.costVisibility;
    return MobileMaskedMedicine(
      productId: productId,
      brandName: brandName,
      mrpUnit: mrpUnit,
      costUnit: maskCost ? null : costUnit,
      isCostMasked: maskCost,
    );
  }

  static MobileMaskedInvoice maskInvoice({
    required String invoiceId,
    required String customerName,
    required String customerPhone,
    required double totalAmount,
    required double? cogsAmount,
    required double? grossProfit,
    required MobileFieldVisibilityProfile profile,
  }) {
    final maskCost = !profile.costVisibility;
    final maskProfit = !profile.profitVisibility;
    final maskPii = !profile.patientPiiVisibility;

    return MobileMaskedInvoice(
      invoiceId: invoiceId,
      customerName: maskPii ? maskPersonName(customerName) : customerName,
      customerPhone: maskPii ? maskPhoneNumber(customerPhone) : customerPhone,
      totalAmount: totalAmount,
      cogsAmount: maskCost ? null : cogsAmount,
      grossProfit: maskProfit ? null : grossProfit,
      isCostMasked: maskCost,
      isProfitMasked: maskProfit,
      isPiiMasked: maskPii,
    );
  }

  static MobileMaskedSalary maskSalary({
    required String salaryId,
    required String staffUserId,
    required String username,
    required double? baseSalaryBdt,
    required String bankAccountNo,
    required MobileFieldVisibilityProfile profile,
  }) {
    final maskSalary = !profile.salaryVisibility;
    return MobileMaskedSalary(
      salaryId: salaryId,
      staffUserId: staffUserId,
      username: username,
      baseSalaryBdt: maskSalary ? null : baseSalaryBdt,
      bankAccountNo: maskSalary ? '***REDACTED***' : bankAccountNo,
      isSalaryMasked: maskSalary,
    );
  }

  static MobileMaskedPrescription maskPrescription({
    required String prescriptionId,
    required String doctorName,
    required String diagnosis,
    required String notes,
    required String? prescriptionImageUrl,
    required MobileFieldVisibilityProfile profile,
  }) {
    final maskRx = !profile.prescriptionVisibility;
    return MobileMaskedPrescription(
      prescriptionId: prescriptionId,
      doctorName: doctorName,
      diagnosis: maskRx ? '[CLINICAL_DIAGNOSIS_REDACTED]' : diagnosis,
      notes: maskRx ? '[CONFIDENTIAL_CLINICAL_NOTES]' : notes,
      prescriptionImageUrl: maskRx ? null : prescriptionImageUrl,
      isPrescriptionMasked: maskRx,
    );
  }

  static String serializeMaskedExport(List<Map<String, dynamic>> items) {
    return jsonEncode(items);
  }
}

