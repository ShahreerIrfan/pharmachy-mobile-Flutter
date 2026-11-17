/// mobile_cold_chain_excursion_client.dart
/// Architecture Decision: ADR-0212 (P212).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.

enum MobileIncidentStatus {
  detected('Detected / Stock Quarantined', 'বিচ্যুতি শনাক্ত / স্টক কোয়ারেন্টাইন'),
  underReview('Under Pharmacist Review', 'ফার্মাসিস্ট পর্যালোচনাধীন'),
  resolved('Resolved & Disposed', 'নিষ্পত্তি সম্পন্ন'),
  cancelled('Cancelled', 'বাতিল');

  final String labelEn;
  final String labelBn;

  const MobileIncidentStatus(this.labelEn, this.labelBn);
}

enum MobileDispositionOutcome {
  pending('Pending Review', 'পর্যালোচনা অপেক্ষমাণ'),
  releaseToSellable('Release to Sellable Stock', 'বিক্রয়যোগ্য স্টকে অবমুক্ত'),
  condemnDispose('Condemn & Write-off Disposal', 'নষ্ট ঘোষণা ও ধ্বংস'),
  returnToSupplier('Return to Vaccine/Drug Supplier', 'সরবরাহকারীকে ফেরত');

  final String labelEn;
  final String labelBn;

  const MobileDispositionOutcome(this.labelEn, this.labelBn);
}

enum MobileExcursionSeverity {
  warning('Excursion Warning', 'সতর্কতামূলক বিচ্যুতি'),
  critical('Critical Excursion', 'মারাত্মক বিচ্যুতি');

  final String labelEn;
  final String labelBn;

  const MobileExcursionSeverity(this.labelEn, this.labelBn);
}

class MobileQuarantinedBatchItem {
  final String batchNumber;
  final String productName;
  final int quantity;
  final double unitCost;
  final double totalCost;
  MobileDispositionOutcome disposition;

  MobileQuarantinedBatchItem({
    required this.batchNumber,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    this.disposition = MobileDispositionOutcome.pending,
  }) : totalCost = unitCost * quantity;

  Map<String, dynamic> toJson() => {
    'batch_number': batchNumber,
    'product_name': productName,
    'quantity': quantity,
    'unit_cost': unitCost,
    'total_cost': totalCost,
    'disposition': disposition.name,
  };
}

class MobileExcursionIncident {
  final String incidentId;
  final String incidentNumber;
  final String tenantId;
  final String branchId;
  final String storageLocationCode;
  final String storageLocationName;
  final double recordedTemperature;
  final double minThreshold;
  final double maxThreshold;
  final MobileExcursionSeverity severity;
  MobileIncidentStatus status;
  MobileDispositionOutcome dispositionOutcome;
  final int quarantinedBatchesCount;
  final double totalQuarantinedValue;
  String clinicalJustification;
  String? reviewedBy;
  DateTime? reviewedAt;
  final DateTime createdAt;
  final List<MobileQuarantinedBatchItem> affectedBatches;

  MobileExcursionIncident({
    required this.incidentId,
    required this.incidentNumber,
    required this.tenantId,
    required this.branchId,
    required this.storageLocationCode,
    required this.storageLocationName,
    required this.recordedTemperature,
    required this.minThreshold,
    required this.maxThreshold,
    required this.severity,
    this.status = MobileIncidentStatus.detected,
    this.dispositionOutcome = MobileDispositionOutcome.pending,
    this.clinicalJustification = '',
    this.reviewedBy,
    this.reviewedAt,
    DateTime? createdAt,
    required this.affectedBatches,
  })  : createdAt = createdAt ?? DateTime.now(),
        quarantinedBatchesCount = affectedBatches.length,
        totalQuarantinedValue = affectedBatches.fold(0.0, (sum, item) => sum + item.totalCost);

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    'incident_number': incidentNumber,
    'tenant_id': tenantId,
    'branch_id': branchId,
    'storage_location_code': storageLocationCode,
    'storage_location_name': storageLocationName,
    'recorded_temperature': recordedTemperature,
    'min_threshold': minThreshold,
    'max_threshold': maxThreshold,
    'severity': severity.name,
    'status': status.name,
    'disposition_outcome': dispositionOutcome.name,
    'quarantined_batches_count': quarantinedBatchesCount,
    'total_quarantined_value': totalQuarantinedValue,
    'clinical_justification': clinicalJustification,
    'reviewed_by': reviewedBy,
    'reviewed_at': reviewedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'affected_batches': affectedBatches.map((b) => b.toJson()).toList(),
  };
}

class MobileColdChainExcursionClient {
  final Map<String, MobileExcursionIncident> _incidents = {};

  static const Set<String> _allowedRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
  };

  void _assertPharmacistRole(String userRole) {
    if (userRole.toUpperCase() == 'CASHIER' || !_allowedRoles.contains(userRole.toUpperCase())) {
      throw Exception('Cashiers cannot review or dispose cold chain excursions. Only registered Pharmacists and Managers are authorized.');
    }
  }

  MobileExcursionIncident triggerExcursion({
    required String tenantId,
    required String branchId,
    required String storageLocationCode,
    required String storageLocationName,
    required double recordedTemp,
    double minThreshold = 2.0,
    double maxThreshold = 8.0,
    required List<MobileQuarantinedBatchItem> activeBatches,
  }) {
    if (tenantId.isEmpty) throw ArgumentError('tenantId cannot be empty');
    if (branchId.isEmpty) throw ArgumentError('branchId cannot be empty');
    if (storageLocationCode.isEmpty) throw ArgumentError('storageLocationCode cannot be empty');
    if (minThreshold >= maxThreshold) throw ArgumentError('minThreshold must be strictly less than maxThreshold');

    final diff = recordedTemp > maxThreshold
        ? recordedTemp - maxThreshold
        : minThreshold - recordedTemp;

    final severity = (diff >= 5.0 || recordedTemp >= 15.0)
        ? MobileExcursionSeverity.critical
        : MobileExcursionSeverity.warning;

    final id = 'cce-${DateTime.now().millisecondsSinceEpoch}';
    final incidentNumber = 'CCE-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';

    final incident = MobileExcursionIncident(
      incidentId: id,
      incidentNumber: incidentNumber,
      tenantId: tenantId,
      branchId: branchId,
      storageLocationCode: storageLocationCode,
      storageLocationName: storageLocationName,
      recordedTemperature: recordedTemp,
      minThreshold: minThreshold,
      maxThreshold: maxThreshold,
      severity: severity,
      affectedBatches: activeBatches,
    );

    _incidents[id] = incident;
    return incident;
  }

  MobileExcursionIncident reviewDisposition({
    required String incidentId,
    required String userRole,
    required String reviewerUsername,
    required MobileDispositionOutcome outcome,
    required String clinicalJustification,
  }) {
    _assertPharmacistRole(userRole);

    final incident = _incidents[incidentId];
    if (incident == null) {
      throw Exception('Incident $incidentId not found');
    }

    if (incident.status == MobileIncidentStatus.resolved) {
      throw StateError('Incident is already resolved');
    }

    if (outcome == MobileDispositionOutcome.pending) {
      throw ArgumentError('Valid disposition outcome must be provided');
    }

    final justification = clinicalJustification.trim();
    if (outcome == MobileDispositionOutcome.releaseToSellable) {
      if (justification.length < 15) {
        throw ArgumentError('Clinical justification must be at least 15 characters describing stability data or manufacturer consultation.');
      }
    }

    for (final item in incident.affectedBatches) {
      item.disposition = outcome;
    }

    incident.status = MobileIncidentStatus.resolved;
    incident.dispositionOutcome = outcome;
    incident.clinicalJustification = justification;
    incident.reviewedBy = reviewerUsername;
    incident.reviewedAt = DateTime.now();

    return incident;
  }

  MobileExcursionIncident? getIncident(String incidentId) {
    return _incidents[incidentId];
  }

  List<MobileExcursionIncident> listIncidents(String tenantId, {String? branchId}) {
    return _incidents.values
        .where((inc) => inc.tenantId == tenantId && (branchId == null || inc.branchId == branchId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

