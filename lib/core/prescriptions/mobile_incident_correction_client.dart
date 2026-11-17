/// mobile/lib/core/prescriptions/mobile_incident_correction_client.dart
/// Architecture Decision: ADR-0255 (P255).
/// Mobile incident management client for incorrect dispensing, suspected damages,
/// recalls, inventory variances, CAPA tracking, and closure approvals.

class MobileIncidentCorrectionClient {
  static const List<String> validTypes = [
    'INCORRECT_DISPENSING',
    'SUSPECTED_DAMAGE',
    'PRODUCT_RECALL',
    'INVENTORY_DISCREPANCY',
    'ADVERSE_DRUG_REACTION',
    'COLD_CHAIN_EXCURSION',
  ];

  static const List<String> validSeverities = [
    'LOW',
    'MEDIUM',
    'HIGH',
    'CRITICAL',
  ];

  static const List<String> validStatuses = [
    'REPORTED',
    'UNDER_INVESTIGATION',
    'CORRECTIVE_ACTION_PENDING',
    'CLOSED',
    'DISMISSED',
  ];

  static bool canReportIncident(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return r == 'SUPERADMIN' ||
        r == 'PHARMACY_OWNER' ||
        r == 'BRANCH_MANAGER' ||
        r == 'STAFF_PHARMACIST' ||
        r == 'CASHIER';
  }

  static bool canConductInvestigation(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return r == 'SUPERADMIN' ||
        r == 'PHARMACY_OWNER' ||
        r == 'BRANCH_MANAGER' ||
        r == 'STAFF_PHARMACIST';
  }

  static bool canApproveClosure({
    required String? role,
    required String? userBranchId,
    required String? recordBranchId,
  }) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    if (r == 'SUPERADMIN' || r == 'PHARMACY_OWNER') {
      return true;
    }
    if (r == 'BRANCH_MANAGER' || r == 'STAFF_PHARMACIST') {
      return userBranchId != null && userBranchId == recordBranchId;
    }
    // Cashier cannot approve closures
    return false;
  }

  static bool isDgdaNotificationRequired({
    required String? incidentType,
    required String? severity,
  }) {
    if (severity?.toUpperCase() == 'CRITICAL') return true;
    if (incidentType?.toUpperCase() == 'PRODUCT_RECALL') return true;
    if (incidentType?.toUpperCase() == 'ADVERSE_DRUG_REACTION' &&
        severity?.toUpperCase() == 'HIGH') {
      return true;
    }
    return false;
  }

  static void validateClosureRequirements({
    required String? severity,
    required String? rootCause,
    required String? capa,
  }) {
    if (severity == null) return;
    final sev = severity.trim().toUpperCase();
    if (sev == 'HIGH' || sev == 'CRITICAL') {
      if (rootCause == null || rootCause.trim().isEmpty) {
        throw StateError(
            'High and Critical incidents require documented Root Cause before closure.');
      }
      if (capa == null || capa.trim().isEmpty) {
        throw StateError(
            'High and Critical incidents require a documented Corrective and Preventive Action (CAPA) plan before closure.');
      }
    }
  }

  static String getIncidentTypeDisplay(String? type, {String lang = 'en'}) {
    if (type == null) return '';
    final isBn = lang.toLowerCase() == 'bn';
    switch (type.trim().toUpperCase()) {
      case 'INCORRECT_DISPENSING':
        return isBn
            ? 'ভুল ওষুধ প্রদান / নিয়ার-মিস'
            : 'Incorrect Dispensing / Near Miss';
      case 'SUSPECTED_DAMAGE':
        return isBn
            ? 'ওষুধের ক্ষতি / প্যাকেজিং ত্রুটি'
            : 'Suspected Damage / Packaging Compromise';
      case 'PRODUCT_RECALL':
        return isBn
            ? 'ওষুধ প্রত্যাহার (রিকল)'
            : 'Product Recall (DGDA / Manufacturer)';
      case 'INVENTORY_DISCREPANCY':
        return isBn ? 'ইনভেন্টরি অমিল / স্টক গরমিল' : 'Inventory Discrepancy';
      case 'ADVERSE_DRUG_REACTION':
        return isBn
            ? 'ওষুধের পার্শ্বপ্রতিক্রিয়া (ADR)'
            : 'Adverse Drug Reaction';
      case 'COLD_CHAIN_EXCURSION':
        return isBn
            ? 'কোল্ড-চেইন তাপমাত্রা বিচ্যুতি'
            : 'Cold-Chain Temperature Excursion';
      default:
        return type;
    }
  }

  static String getSeverityDisplay(String? severity, {String lang = 'en'}) {
    if (severity == null) return '';
    final isBn = lang.toLowerCase() == 'bn';
    switch (severity.trim().toUpperCase()) {
      case 'LOW':
        return isBn ? 'স্বাভাবিক (Low)' : 'Low (Minor / Near-miss)';
      case 'MEDIUM':
        return isBn ? 'মাঝারি (Medium)' : 'Medium (Moderate)';
      case 'HIGH':
        return isBn ? 'উচ্চ (High)' : 'High (Clinical Error)';
      case 'CRITICAL':
        return isBn ? 'মারাত্মক (Critical)' : 'Critical (DGDA Alert)';
      default:
        return severity;
    }
  }

  static String formatBranchSummary({
    required int totalIncidents,
    required int criticalCount,
    required String totalFinancialImpactBdt,
    String lang = 'en',
  }) {
    final isBn = lang.toLowerCase() == 'bn';
    if (isBn) {
      return 'ইনসিডেন্ট রিপোর্ট: মোট $totalIncidentsটি ঘটনা, $criticalCountটি মারাত্মক/জরুরি, মোট আর্থিক ক্ষতি ৳$totalFinancialImpactBdt';
    } else {
      return 'Incident Summary: $totalIncidents total, $criticalCount critical alerts, Total financial loss: ৳$totalFinancialImpactBdt';
    }
  }
}

