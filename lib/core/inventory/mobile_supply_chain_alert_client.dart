/// mobile_supply_chain_alert_client.dart
/// Architecture Decision: ADR-0214 (P214).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.

enum MobileStockAlertType {
  reorderRequired('Reorder Level Reached', 'রিঅর্ডার সীমা অতিক্রম'),
  stockout('Complete Stockout', 'স্টকআউট'),
  overstock('Overstock Exceeded Maximum', 'অতিরিক্ত স্টক'),
  negativeAvailability('Negative Availability Anomaly', 'নেতিবাচক স্টক অসঙ্গতি'),
  temperatureRisk('Cold Chain Temperature Risk', 'কোল্ড চেইন তাপমাত্রা ঝুঁকি');

  final String labelEn;
  final String labelBn;

  const MobileStockAlertType(this.labelEn, this.labelBn);
}

enum MobileAlertSeverity {
  info('Informational', 'তথ্যমূলক'),
  warning('Warning', 'সতর্কতা'),
  critical('Critical', 'গুরুতর'),
  emergency('Emergency', 'জরুরি');

  final String labelEn;
  final String labelBn;

  const MobileAlertSeverity(this.labelEn, this.labelBn);
}

enum MobileAlertStatus {
  open('Open / Active', 'সক্রিয়'),
  acknowledged('Acknowledged', 'স্বীকৃত'),
  resolved('Resolved', 'নিষ্পন্ন'),
  dismissed('Dismissed', 'বাতিলকৃত');

  final String labelEn;
  final String labelBn;

  const MobileAlertStatus(this.labelEn, this.labelBn);
}

class MobileStockAlert {
  final String alertId;
  final String tenantId;
  final String branchId;
  final MobileStockAlertType alertType;
  final MobileAlertSeverity severity;
  MobileAlertStatus status;
  final String title;
  final String message;
  final String messageBn;
  int currentQuantity;
  int? thresholdQuantity;
  double? currentTemperature;
  final String dedupFingerprint;
  int occurredCount;
  final DateTime firstTriggeredAt;
  DateTime lastTriggeredAt;
  String? acknowledgedBy;
  DateTime? acknowledgedAt;
  String? resolvedBy;
  DateTime? resolvedAt;
  String resolutionNotes;

  MobileStockAlert({
    required this.alertId,
    required this.tenantId,
    required this.branchId,
    required this.alertType,
    required this.severity,
    this.status = MobileAlertStatus.open,
    required this.title,
    required this.message,
    this.messageBn = '',
    required this.currentQuantity,
    this.thresholdQuantity,
    this.currentTemperature,
    required this.dedupFingerprint,
    this.occurredCount = 1,
    DateTime? firstTriggeredAt,
    DateTime? lastTriggeredAt,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNotes = '',
  })  : firstTriggeredAt = firstTriggeredAt ?? DateTime.now(),
        lastTriggeredAt = lastTriggeredAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'alert_id': alertId,
    'tenant_id': tenantId,
    'branch_id': branchId,
    'alert_type': alertType.name,
    'severity': severity.name,
    'status': status.name,
    'title': title,
    'message': message,
    'message_bn': messageBn,
    'current_quantity': currentQuantity,
    'threshold_quantity': thresholdQuantity,
    'current_temperature': currentTemperature,
    'dedup_fingerprint': dedupFingerprint,
    'occurred_count': occurredCount,
    'first_triggered_at': firstTriggeredAt.toIso8601String(),
    'last_triggered_at': lastTriggeredAt.toIso8601String(),
    'acknowledged_by': acknowledgedBy,
    'acknowledged_at': acknowledgedAt?.toIso8601String(),
    'resolved_by': resolvedBy,
    'resolved_at': resolvedAt?.toIso8601String(),
    'resolution_notes': resolutionNotes,
  };
}

class MobileSupplyChainAlertClient {
  final Map<String, MobileStockAlert> _alerts = {};

  static const Set<String> _allowedRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
  };

  void _assertInventoryRole(String userRole) {
    if (userRole.toUpperCase() == 'CASHIER' || !_allowedRoles.contains(userRole.toUpperCase())) {
      throw Exception('Cashiers cannot manage supply chain alerts.');
    }
  }

  String _fingerprint(String tenantId, String branchId, String alertType, String entityId) {
    return '$tenantId:$branchId:$alertType:$entityId';
  }

  MobileStockAlert evaluateStockLevel({
    required String tenantId,
    required String branchId,
    required String productId,
    required String productName,
    required int currentQty,
    required int reorderLevel,
    int? maxLevel,
  }) {
    MobileStockAlertType type;
    MobileAlertSeverity sev;
    String title;
    String msg;

    if (currentQty < 0) {
      type = MobileStockAlertType.negativeAvailability;
      sev = MobileAlertSeverity.critical;
      title = 'Negative Stock: $productName';
      msg = 'Negative stock anomaly detected ($currentQty units).';
    } else if (currentQty == 0) {
      type = MobileStockAlertType.stockout;
      sev = MobileAlertSeverity.critical;
      title = 'Stockout: $productName';
      msg = 'Product $productName is completely out of stock.';
    } else if (reorderLevel > 0 && currentQty <= reorderLevel) {
      type = MobileStockAlertType.reorderRequired;
      sev = MobileAlertSeverity.warning;
      title = 'Reorder Level Reached: $productName';
      msg = 'Current stock ($currentQty) is below reorder threshold ($reorderLevel).';
    } else if (maxLevel != null && currentQty > maxLevel) {
      type = MobileStockAlertType.overstock;
      sev = MobileAlertSeverity.info;
      title = 'Overstock: $productName';
      msg = 'Current stock ($currentQty) exceeds max target ($maxLevel).';
    } else {
      // Auto-resolve open alerts
      final fp1 = _fingerprint(tenantId, branchId, MobileStockAlertType.stockout.name, productId);
      final fp2 = _fingerprint(tenantId, branchId, MobileStockAlertType.reorderRequired.name, productId);
      _alerts.values
          .where((a) => (a.dedupFingerprint == fp1 || a.dedupFingerprint == fp2) &&
              (a.status == MobileAlertStatus.open || a.status == MobileAlertStatus.acknowledged))
          .forEach((a) {
        a.status = MobileAlertStatus.resolved;
        a.resolutionNotes = 'Auto-resolved: stock replenished.';
        a.resolvedAt = DateTime.now();
      });
      return MobileStockAlert(
        alertId: 'resolved',
        tenantId: tenantId,
        branchId: branchId,
        alertType: MobileStockAlertType.reorderRequired,
        severity: MobileAlertSeverity.info,
        status: MobileAlertStatus.resolved,
        title: 'Resolved',
        message: 'Safe range',
        currentQuantity: currentQty,
        dedupFingerprint: '',
      );
    }

    final fp = _fingerprint(tenantId, branchId, type.name, productId);

    for (final existing in _alerts.values) {
      if (existing.dedupFingerprint == fp &&
          (existing.status == MobileAlertStatus.open || existing.status == MobileAlertStatus.acknowledged)) {
        existing.occurredCount++;
        existing.currentQuantity = currentQty;
        existing.thresholdQuantity = reorderLevel;
        existing.lastTriggeredAt = DateTime.now();
        return existing;
      }
    }

    final id = 'alert-${DateTime.now().millisecondsSinceEpoch}-${_alerts.length}';
    final alert = MobileStockAlert(
      alertId: id,
      tenantId: tenantId,
      branchId: branchId,
      alertType: type,
      severity: sev,
      title: title,
      message: msg,
      currentQuantity: currentQty,
      thresholdQuantity: reorderLevel,
      dedupFingerprint: fp,
    );
    _alerts[id] = alert;
    return alert;
  }

  MobileStockAlert evaluateTemperatureRisk({
    required String tenantId,
    required String branchId,
    required String locationId,
    required String locationName,
    required double recordedTemp,
    double minTemp = 2.0,
    double maxTemp = 8.0,
  }) {
    final fp = _fingerprint(tenantId, branchId, MobileStockAlertType.temperatureRisk.name, locationId);

    if (recordedTemp < minTemp || recordedTemp > maxTemp) {
      for (final existing in _alerts.values) {
        if (existing.dedupFingerprint == fp &&
            (existing.status == MobileAlertStatus.open || existing.status == MobileAlertStatus.acknowledged)) {
          existing.occurredCount++;
          existing.currentTemperature = recordedTemp;
          existing.lastTriggeredAt = DateTime.now();
          return existing;
        }
      }

      final id = 'temp-alert-${DateTime.now().millisecondsSinceEpoch}';
      final alert = MobileStockAlert(
        alertId: id,
        tenantId: tenantId,
        branchId: branchId,
        alertType: MobileStockAlertType.temperatureRisk,
        severity: MobileAlertSeverity.critical,
        title: 'Temperature Excursion: $locationName',
        message: 'Temperature breached safe limits ($recordedTemp°C)',
        currentQuantity: 0,
        currentTemperature: recordedTemp,
        dedupFingerprint: fp,
      );
      _alerts[id] = alert;
      return alert;
    }

    return MobileStockAlert(
      alertId: 'resolved',
      tenantId: tenantId,
      branchId: branchId,
      alertType: MobileStockAlertType.temperatureRisk,
      severity: MobileAlertSeverity.info,
      status: MobileAlertStatus.resolved,
      title: 'Normal',
      message: 'Temperature normal',
      currentQuantity: 0,
      dedupFingerprint: fp,
    );
  }

  MobileStockAlert acknowledgeAlert({
    required String userRole,
    required String alertId,
    required String username,
    String notes = '',
  }) {
    _assertInventoryRole(userRole);
    final alert = _alerts[alertId];
    if (alert == null) throw Exception('Alert not found');

    alert.status = MobileAlertStatus.acknowledged;
    alert.acknowledgedBy = username;
    alert.acknowledgedAt = DateTime.now();
    if (notes.isNotEmpty) alert.resolutionNotes = notes;
    return alert;
  }

  MobileStockAlert resolveAlert({
    required String userRole,
    required String alertId,
    required String username,
    String resolutionNotes = '',
  }) {
    _assertInventoryRole(userRole);
    final alert = _alerts[alertId];
    if (alert == null) throw Exception('Alert not found');

    alert.status = MobileAlertStatus.resolved;
    alert.resolvedBy = username;
    alert.resolvedAt = DateTime.now();
    alert.resolutionNotes = resolutionNotes.isNotEmpty ? resolutionNotes : 'Resolved by staff';
    return alert;
  }

  List<MobileStockAlert> listActiveAlerts(String tenantId, {String? branchId}) {
    return _alerts.values
        .where((a) => a.tenantId == tenantId && (branchId == null || a.branchId == branchId))
        .where((a) => a.status == MobileAlertStatus.open || a.status == MobileAlertStatus.acknowledged)
        .toList()
      ..sort((a, b) => b.lastTriggeredAt.compareTo(a.lastTriggeredAt));
  }
}
