/// mobile_inventory_count_client.dart
/// Architecture Decision: ADR-0204 (P204).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.
///
/// Mobile owner/manager client for physical inventory count sessions,
/// scanner collection, discrepancy calculation, and maker-checker posting.

enum MobileCountSessionType {
  fullStocktake('Full Pharmacy Stocktake', 'পূর্ণ স্টকটেক'),
  cycleCount('Periodic Cycle Count', 'পর্যায়ক্রমিক সাইকেল কাউন্ট'),
  categoryAudit('Category / Shelf Audit', 'ক্যাটাগরি নিরীক্ষা'),
  coldChainAudit('Cold-Chain Refrigerator Audit', 'কোল্ড চেইন ফ্রিজ নিরীক্ষা'),
  controlledDrugAudit('Controlled Narcotics Audit', 'নিয়ন্ত্রিত ওষুধের নিরীক্ষা'),
  spotCheck('Discrepancy Spot Check', 'স্পট চেক');

  final String labelEn;
  final String labelBn;

  const MobileCountSessionType(this.labelEn, this.labelBn);
}

enum MobileCountSessionStatus {
  draft('Draft Planning', 'খসড়া'),
  inProgress('Counting in Progress', 'গণনা চলছে'),
  submittedForReview('Count Complete - Pending Review', 'পর্যালোচনার অপেক্ষায়'),
  approved('Approved by Checker', 'অনুমোদিত'),
  rejected('Rejected by Checker', 'প্রত্যাখ্যাত'),
  posted('Posted to Stock Ledger', 'পোস্ট সম্পন্ন'),
  cancelled('Cancelled', 'বাতিল');

  final String labelEn;
  final String labelBn;

  const MobileCountSessionStatus(this.labelEn, this.labelBn);
}

enum MobileCountDiscrepancyType {
  match('Match', 'সঠিক মিল'),
  surplus('Surplus', 'উদ্বৃত্ত'),
  shortage('Shortage', 'ঘাটতি');

  final String labelEn;
  final String labelBn;

  const MobileCountDiscrepancyType(this.labelEn, this.labelBn);
}

class MobileCountItem {
  final String itemId;
  final String sessionId;
  final String batchNumber;
  final int systemQuantity;
  int countedQuantity;
  int discrepancyQuantity;
  final double unitCost;
  double costDiscrepancyBdt;
  MobileCountDiscrepancyType discrepancyType;
  String? adjustmentLedgerEntryId;

  MobileCountItem({
    required this.itemId,
    required this.sessionId,
    required this.batchNumber,
    required this.systemQuantity,
    required this.countedQuantity,
    required this.unitCost,
  })  : discrepancyQuantity = countedQuantity - systemQuantity,
        costDiscrepancyBdt = (countedQuantity - systemQuantity) * unitCost,
        discrepancyType = (countedQuantity - systemQuantity) > 0
            ? MobileCountDiscrepancyType.surplus
            : ((countedQuantity - systemQuantity) < 0
                ? MobileCountDiscrepancyType.shortage
                : MobileCountDiscrepancyType.match);

  void updateCount(int newCount) {
    countedQuantity = newCount;
    discrepancyQuantity = countedQuantity - systemQuantity;
    costDiscrepancyBdt = discrepancyQuantity * unitCost;
    if (discrepancyQuantity > 0) {
      discrepancyType = MobileCountDiscrepancyType.surplus;
    } else if (discrepancyQuantity < 0) {
      discrepancyType = MobileCountDiscrepancyType.shortage;
    } else {
      discrepancyType = MobileCountDiscrepancyType.match;
    }
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'session_id': sessionId,
        'batch_number': batchNumber,
        'system_quantity': systemQuantity,
        'counted_quantity': countedQuantity,
        'discrepancy_quantity': discrepancyQuantity,
        'unit_cost': unitCost,
        'cost_discrepancy_bdt': costDiscrepancyBdt,
        'discrepancy_type': discrepancyType.name,
        'adjustment_ledger_entry_id': adjustmentLedgerEntryId,
      };
}

class MobileCountSession {
  final String sessionId;
  final String tenantId;
  final String branchId;
  final String sessionNumber;
  final MobileCountSessionType sessionType;
  MobileCountSessionStatus status;
  final String createdByUserId;
  String? countedByUserId;
  String? reviewedByUserId;
  String checkerNotes;
  DateTime? submittedAt;
  DateTime? reviewedAt;
  DateTime? postedAt;
  int totalDiscrepancyUnits = 0;
  double totalCostDiscrepancyBdt = 0.0;
  int surplusCount = 0;
  int shortageCount = 0;
  int matchedCount = 0;
  final Map<String, MobileCountItem> items = {};

  MobileCountSession({
    required this.sessionId,
    required this.tenantId,
    required this.branchId,
    required this.sessionNumber,
    required this.sessionType,
    required this.createdByUserId,
  })  : status = MobileCountSessionStatus.inProgress,
        countedByUserId = createdByUserId,
        checkerNotes = '';

  void recalculateTotals() {
    int totalDisc = 0;
    double costDisc = 0.0;
    int surplus = 0;
    int shortage = 0;
    int matched = 0;

    for (final item in items.values) {
      totalDisc += item.discrepancyQuantity;
      costDisc += item.costDiscrepancyBdt;
      if (item.discrepancyType == MobileCountDiscrepancyType.surplus) {
        surplus++;
      } else if (item.discrepancyType == MobileCountDiscrepancyType.shortage) {
        shortage++;
      } else {
        matched++;
      }
    }

    totalDiscrepancyUnits = totalDisc;
    totalCostDiscrepancyBdt = costDisc;
    surplusCount = surplus;
    shortageCount = shortage;
    matchedCount = matched;
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'session_number': sessionNumber,
        'session_type': sessionType.name,
        'status': status.name,
        'total_items_counted': items.length,
        'total_discrepancy_units': totalDiscrepancyUnits,
        'total_cost_discrepancy_bdt': totalCostDiscrepancyBdt,
        'surplus_count': surplusCount,
        'shortage_count': shortageCount,
        'matched_count': matchedCount,
        'items': items.values.map((i) => i.toJson()).toList(),
      };
}

class MobileInventoryCountClient {
  static int _counter = 0;
  static String _nextId(String prefix) => '$prefix-${DateTime.now().millisecondsSinceEpoch}-${++_counter}';

  final Map<String, MobileCountSession> sessions = {};

  MobileCountSession createSession({
    required String tenantId,
    required String branchId,
    required MobileCountSessionType type,
    required String actorRole,
    required String actorUserId,
  }) {
    if (actorRole.toUpperCase() == 'CASHIER') {
      throw StateError('ERR_STAFF_ROLE_DENIED: Cashiers cannot create count sessions.');
    }
    final id = _nextId('cnt');
    final num = 'CNT-${DateTime.now().millisecondsSinceEpoch}';
    final session = MobileCountSession(
      sessionId: id,
      tenantId: tenantId,
      branchId: branchId,
      sessionNumber: num,
      sessionType: type,
      createdByUserId: actorUserId,
    );
    sessions[session.sessionId] = session;
    return session;
  }

  MobileCountItem recordScanItem({
    required String sessionId,
    required String batchNumber,
    required int systemQuantity,
    required int countedQuantity,
    required double unitCost,
    required String actorRole,
  }) {
    if (actorRole.toUpperCase() == 'CASHIER') {
      throw StateError('ERR_STAFF_ROLE_DENIED: Cashiers cannot scan items in count sessions.');
    }
    if (countedQuantity < 0) {
      throw ArgumentError('ERR_INVALID_QUANTITY: Counted quantity cannot be negative.');
    }

    final session = sessions[sessionId];
    if (session == null) {
      throw StateError('ERR_SESSION_NOT_FOUND');
    }
    if (session.status != MobileCountSessionStatus.draft &&
        session.status != MobileCountSessionStatus.inProgress) {
      throw StateError('ERR_INVALID_STATUS: Session is not in progress.');
    }

    var item = session.items[batchNumber];
    if (item == null) {
      final itemId = _nextId('cnti');
      item = MobileCountItem(
        itemId: itemId,
        sessionId: sessionId,
        batchNumber: batchNumber,
        systemQuantity: systemQuantity,
        countedQuantity: countedQuantity,
        unitCost: unitCost,
      );
      session.items[batchNumber] = item;
    } else {
      item.updateCount(countedQuantity);
    }

    session.recalculateTotals();
    return item;
  }

  MobileCountSession submitForReview({
    required String sessionId,
    required String actorRole,
    required String actorUserId,
  }) {
    if (actorRole.toUpperCase() == 'CASHIER') {
      throw StateError('ERR_STAFF_ROLE_DENIED');
    }
    final session = sessions[sessionId];
    if (session == null) throw StateError('ERR_SESSION_NOT_FOUND');

    if (session.items.isEmpty) {
      throw ArgumentError('ERR_EMPTY_SESSION: Cannot submit empty count session.');
    }
    if (session.status != MobileCountSessionStatus.inProgress) {
      throw StateError('ERR_INVALID_STATUS');
    }

    session.status = MobileCountSessionStatus.submittedForReview;
    session.submittedAt = DateTime.now();
    session.countedByUserId = actorUserId;
    return session;
  }

  MobileCountSession reviewSession({
    required String sessionId,
    required bool isApproved,
    required String checkerRole,
    required String checkerUserId,
    String checkerNotes = '',
  }) {
    if (!RegExp(r'BRANCH_MANAGER|PHARMACY_OWNER|PLATFORM_SUPER_ADMIN', caseSensitive: false).hasMatch(checkerRole)) {
      throw StateError('ERR_CHECKER_ROLE_DENIED: Only Managers or Owners can review sessions.');
    }
    final session = sessions[sessionId];
    if (session == null) throw StateError('ERR_SESSION_NOT_FOUND');

    if (session.status != MobileCountSessionStatus.submittedForReview) {
      throw StateError('ERR_INVALID_STATUS');
    }

    // Anti-Self-Approval
    if (checkerUserId == session.countedByUserId) {
      throw StateError('ERR_MAKER_CHECKER_SELF_APPROVAL: Maker cannot check their own count.');
    }

    session.reviewedByUserId = checkerUserId;
    session.reviewedAt = DateTime.now();
    session.checkerNotes = checkerNotes;
    session.status = isApproved ? MobileCountSessionStatus.approved : MobileCountSessionStatus.rejected;
    return session;
  }

  Map<String, dynamic> postAdjustments({
    required String sessionId,
    required String actorRole,
  }) {
    final session = sessions[sessionId];
    if (session == null) throw StateError('ERR_SESSION_NOT_FOUND');

    if (session.status == MobileCountSessionStatus.posted) {
      throw StateError('ERR_ALREADY_POSTED: Session is already posted.');
    }
    if (session.status != MobileCountSessionStatus.approved) {
      throw StateError('ERR_NOT_APPROVED: Session must be approved before posting.');
    }

    int postedCount = 0;
    for (final item in session.items.values) {
      if (item.discrepancyQuantity != 0) {
        item.adjustmentLedgerEntryId = _nextId('sled');
        postedCount++;
      }
    }

    session.status = MobileCountSessionStatus.posted;
    session.postedAt = DateTime.now();

    return {
      'sessionId': session.sessionId,
      'status': session.status.name,
      'postedAdjustments': postedCount,
      'totalDiscrepancyUnits': session.totalDiscrepancyUnits,
      'costDiscrepancyBdt': session.totalCostDiscrepancyBdt,
    };
  }
}
