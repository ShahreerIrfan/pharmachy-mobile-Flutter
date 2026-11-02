// lib/core/approval/mobile_approval_client.dart
// Architecture Decision: ADR-0108
// Phase 06: Milestone M03 - Manager and Supervisor Approvals (P108)

enum MobileApprovalUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

enum MobileApprovalType {
  highDiscount,
  refund,
  stockWriteOff,
  sensitiveExpense,
  clinicalEscalation,
}

enum MobileApprovalStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

class MobileApprovalRecord {
  final String requestId;
  final String tenantId;
  final String branchId;
  final String approvalType;
  final String status;
  final String urgency;
  final String makerUsername;
  final String? checkerUsername;
  final double amountBdt;
  final double discountPercent;
  final String title;
  final String reason;
  final String? decisionNotes;
  final String? approvalToken;
  final Map<String, dynamic> payload;
  final String createdAt;
  final String? decisionAt;

  const MobileApprovalRecord({
    required this.requestId,
    required this.tenantId,
    required this.branchId,
    required this.approvalType,
    required this.status,
    required this.urgency,
    required this.makerUsername,
    this.checkerUsername,
    required this.amountBdt,
    required this.discountPercent,
    required this.title,
    required this.reason,
    this.decisionNotes,
    this.approvalToken,
    required this.payload,
    required this.createdAt,
    this.decisionAt,
  });

  factory MobileApprovalRecord.fromJson(Map<String, dynamic> json) {
    return MobileApprovalRecord(
      requestId: json['request_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String? ?? '',
      approvalType: json['approval_type'] as String? ?? 'HIGH_DISCOUNT',
      status: json['status'] as String? ?? 'PENDING',
      urgency: json['urgency'] as String? ?? 'ROUTINE',
      makerUsername: json['maker_username'] as String? ?? '',
      checkerUsername: json['checker_username'] as String?,
      amountBdt: (json['amount_bdt'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
      title: json['title'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      decisionNotes: json['decision_notes'] as String?,
      approvalToken: json['approval_token'] as String?,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      createdAt: json['created_at'] as String? ?? '',
      decisionAt: json['decision_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'approval_type': approvalType,
      'status': status,
      'urgency': urgency,
      'maker_username': makerUsername,
      'checker_username': checkerUsername,
      'amount_bdt': amountBdt,
      'discount_percent': discountPercent,
      'title': title,
      'reason': reason,
      'decision_notes': decisionNotes,
      'approval_token': approvalToken,
      'payload': payload,
      'created_at': createdAt,
      'decision_at': decisionAt,
    };
  }
}

class MobileApprovalResult<T> {
  final MobileApprovalUiStatus uiStatus;
  final T? data;
  final String? errorCode;
  final String? messageEn;
  final String? messageBn;

  const MobileApprovalResult({
    required this.uiStatus,
    this.data,
    this.errorCode,
    this.messageEn,
    this.messageBn,
  });

  bool get isSuccess => uiStatus == MobileApprovalUiStatus.success;
}

class MobileApprovalClient {
  final String baseUrl;
  final Map<String, MobileApprovalRecord> _cache = {};
  final Map<String, String> _tokenMap = {};
  bool simulatedOffline = false;

  MobileApprovalClient({this.baseUrl = 'http://localhost:8000/api/v2'});

  void setSimulatedOffline(bool offline) {
    simulatedOffline = offline;
  }

  /// Submits a new Maker-Checker approval request from mobile client.
  Future<MobileApprovalResult<MobileApprovalRecord>> submitRequest({
    required String tenantId,
    required String branchId,
    required String makerUsername,
    required String makerRole,
    required String approvalType,
    required String title,
    required String reason,
    double amountBdt = 0.0,
    double discountPercent = 0.0,
    String urgency = 'ROUTINE',
    Map<String, dynamic>? payload,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.length < 3) {
      return const MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.error,
        errorCode: 'INVALID_TITLE',
        messageEn: 'Approval title must be at least 3 characters.',
        messageBn: 'অনুরোধের শিরোনাম কমপক্ষে ৩ অক্ষরের হতে হবে।',
      );
    }

    final cleanReason = reason.trim();
    if (cleanReason.length < 4) {
      return const MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.error,
        errorCode: 'INVALID_REASON',
        messageEn: 'Detailed operational justification is mandatory.',
        messageBn: 'অনুরোধের কারণ ও বিবরণ বাধ্যতামূলক।',
      );
    }

    if (amountBdt < 0) {
      return const MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.error,
        errorCode: 'INVALID_AMOUNT',
        messageEn: 'Amount BDT cannot be negative.',
        messageBn: 'টাকার পরিমাণ নেতিবাচক হতে পারবে না।',
      );
    }

    final reqId = 'appr-${DateTime.now().microsecondsSinceEpoch}';
    final rec = MobileApprovalRecord(
      requestId: reqId,
      tenantId: tenantId,
      branchId: branchId,
      approvalType: approvalType,
      status: 'PENDING',
      urgency: urgency,
      makerUsername: makerUsername,
      checkerUsername: null,
      amountBdt: amountBdt,
      discountPercent: discountPercent,
      title: cleanTitle,
      reason: cleanReason,
      decisionNotes: null,
      approvalToken: null,
      payload: payload ?? {},
      createdAt: DateTime.now().toIso8601String(),
      decisionAt: null,
    );

    _cache[reqId] = rec;

    if (simulatedOffline) {
      return MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.offline,
        data: rec,
        errorCode: 'OFFLINE_QUEUED',
        messageEn: 'Offline. Request cached locally for supervisor review.',
        messageBn: 'অফলাইন। অনুরোধটি লোকাল ক্যাশে জমা রাখা হয়েছে।',
      );
    }

    return MobileApprovalResult(
      uiStatus: MobileApprovalUiStatus.success,
      data: rec,
      messageEn: 'Approval request submitted successfully.',
      messageBn: 'অনুমোদনের অনুরোধ সফলভাবে প্রেরণ করা হয়েছে।',
    );
  }

  /// Approves a pending request (CHECKER). Enforces Maker != Checker and Role authority.
  Future<MobileApprovalResult<MobileApprovalRecord>> approveRequest({
    required String tenantId,
    required String requestId,
    required String checkerUsername,
    required String checkerRole,
    required String checkerBranchId,
    String? decisionNotes,
  }) async {
    final rec = _cache[requestId];
    if (rec == null) {
      return const MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.error,
        errorCode: 'ERR_NOT_FOUND',
        messageEn: 'Approval request not found.',
        messageBn: 'অনুমোদনের অনুরোধ খুঁজে পাওয়া যায়নি।',
      );
    }

    if (rec.status != 'PENDING') {
      return MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.error,
        data: rec,
        errorCode: 'ERR_NOT_PENDING',
        messageEn: 'Request is already ${rec.status}.',
        messageBn: 'অনুরোধটি ইতিমধ্যে ${rec.status} অবস্থায় আছে।',
      );
    }

    // 1. Dual-Control Segregation
    if (checkerUsername.toLowerCase() == rec.makerUsername.toLowerCase()) {
      return const MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.permissionDenied,
        errorCode: 'ERR_CANNOT_APPROVE_OWN_REQUEST',
        messageEn: 'Maker-Checker violation: You cannot approve your own request.',
        messageBn: 'মেকার-চেকার লঙ্ঘন: আপনি নিজের তৈরি করা অনুরোধ নিজে অনুমোদন করতে পারবেন না।',
      );
    }

    // 2. Role Boundaries
    final role = checkerRole.toUpperCase();
    if (role == 'CASHIER' || role == 'INVENTORY_CLERK' || role == 'AUDITOR') {
      return const MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.permissionDenied,
        errorCode: 'ERR_INSUFFICIENT_APPROVAL_AUTHORITY',
        messageEn: 'Frontline staff cannot act as supervisor checker.',
        messageBn: 'ফ্রন্টলাইন স্টাফদের অনুমোদন প্রদানের ক্ষমতা নেই।',
      );
    }

    // Clinical Escalation Check
    if (rec.approvalType == 'CLINICAL_ESCALATION') {
      if (role != 'STAFF_PHARMACIST' && role != 'BRANCH_MANAGER' &&
          role != 'PHARMACY_OWNER' && role != 'SUPERADMIN') {
        return const MobileApprovalResult(
          uiStatus: MobileApprovalUiStatus.permissionDenied,
          errorCode: 'ERR_CLINICAL_AUTHORITY_REQUIRED',
          messageEn: 'Clinical escalation requires a licensed Supervising Pharmacist or Manager.',
          messageBn: 'ক্লিনিক্যাল এস্কেলেশন অনুমোদনের জন্য লাইসেন্সধারী ফার্মাসিস্ট বা ম্যানেজারের অনুমোদন প্রয়োজন।',
        );
      }
    }

    // Cross-Branch Check
    if (role == 'BRANCH_MANAGER' && checkerBranchId != rec.branchId) {
      return const MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.permissionDenied,
        errorCode: 'ERR_CROSS_BRANCH_VIOLATION',
        messageEn: 'Branch Manager cannot approve requests for other branches.',
        messageBn: 'ব্রাঞ্চ ম্যানেজার অন্য ব্রাঞ্চের অনুরোধ অনুমোদন করতে পারেন না।',
      );
    }

    final token = 'tok_appr_${DateTime.now().microsecondsSinceEpoch}';
    final approved = MobileApprovalRecord(
      requestId: rec.requestId,
      tenantId: rec.tenantId,
      branchId: rec.branchId,
      approvalType: rec.approvalType,
      status: 'APPROVED',
      urgency: rec.urgency,
      makerUsername: rec.makerUsername,
      checkerUsername: checkerUsername,
      amountBdt: rec.amountBdt,
      discountPercent: rec.discountPercent,
      title: rec.title,
      reason: rec.reason,
      decisionNotes: decisionNotes?.trim() ?? '',
      approvalToken: token,
      payload: rec.payload,
      createdAt: rec.createdAt,
      decisionAt: DateTime.now().toIso8601String(),
    );

    _cache[requestId] = approved;
    _tokenMap[token] = requestId;

    return MobileApprovalResult(
      uiStatus: MobileApprovalUiStatus.success,
      data: approved,
      messageEn: 'Request approved. Authorization token generated.',
      messageBn: 'অনুরোধ অনুমোদিত হয়েছে। অনুমোদন টোকেন তৈরি সম্পন্ন।',
    );
  }

  /// Rejects a pending request (CHECKER).
  Future<MobileApprovalResult<MobileApprovalRecord>> rejectRequest({
    required String tenantId,
    required String requestId,
    required String checkerUsername,
    required String checkerRole,
    required String checkerBranchId,
    required String rejectionReason,
  }) async {
    final rec = _cache[requestId];
    if (rec == null) {
      return const MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.error,
        errorCode: 'ERR_NOT_FOUND',
        messageEn: 'Approval request not found.',
        messageBn: 'অনুমোদনের অনুরোধ খুঁজে পাওয়া যায়নি।',
      );
    }

    if (rec.status != 'PENDING') {
      return MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.error,
        data: rec,
        errorCode: 'ERR_NOT_PENDING',
        messageEn: 'Request is already ${rec.status}.',
        messageBn: 'অনুরোধটি ইতিমধ্যে ${rec.status} অবস্থায় আছে।',
      );
    }

    final cleanRej = rejectionReason.trim();
    if (cleanRej.length < 4) {
      return const MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.error,
        errorCode: 'REJECTION_REASON_REQUIRED',
        messageEn: 'Detailed rejection reason is mandatory.',
        messageBn: 'বাতিল করার কারণ উল্লেখ করা বাধ্যতামূলক।',
      );
    }

    if (checkerUsername.toLowerCase() == rec.makerUsername.toLowerCase()) {
      return const MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.permissionDenied,
        errorCode: 'ERR_CANNOT_APPROVE_OWN_REQUEST',
        messageEn: 'Maker-Checker violation: You cannot reject your own request as a checker.',
        messageBn: 'মেকার-চেকার লঙ্ঘন: আপনি নিজের অনুরোধ নিজে বাতিল করতে পারবেন না।',
      );
    }

    final rejected = MobileApprovalRecord(
      requestId: rec.requestId,
      tenantId: rec.tenantId,
      branchId: rec.branchId,
      approvalType: rec.approvalType,
      status: 'REJECTED',
      urgency: rec.urgency,
      makerUsername: rec.makerUsername,
      checkerUsername: checkerUsername,
      amountBdt: rec.amountBdt,
      discountPercent: rec.discountPercent,
      title: rec.title,
      reason: rec.reason,
      decisionNotes: cleanRej,
      approvalToken: null,
      payload: rec.payload,
      createdAt: rec.createdAt,
      decisionAt: DateTime.now().toIso8601String(),
    );

    _cache[requestId] = rejected;

    return MobileApprovalResult(
      uiStatus: MobileApprovalUiStatus.success,
      data: rejected,
      messageEn: 'Request rejected with feedback.',
      messageBn: 'অনুরোধ বাতিল করা হয়েছে।',
    );
  }

  /// Verifies an authorization token.
  Future<MobileApprovalResult<MobileApprovalRecord>> verifyToken({
    required String tenantId,
    required String approvalToken,
  }) async {
    final cleanToken = approvalToken.trim();
    if (cleanToken.isEmpty) {
      return const MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.error,
        errorCode: 'EMPTY_TOKEN',
        messageEn: 'Token cannot be empty.',
        messageBn: 'টোকেন ফাঁকা হতে পারবে না।',
      );
    }

    final reqId = _tokenMap[cleanToken];
    if (reqId == null) {
      return const MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.error,
        errorCode: 'INVALID_TOKEN',
        messageEn: 'Approval token is invalid or expired.',
        messageBn: 'অনুমোদন টোকেন সঠিক নয় বা মেয়াদোত্তীর্ণ।',
      );
    }

    final rec = _cache[reqId];
    if (rec != null && rec.status == 'APPROVED') {
      return MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.success,
        data: rec,
        messageEn: 'Token verified successfully.',
        messageBn: 'টোকেন সফলভাবে যাচাই করা হয়েছে।',
      );
    }

    return const MobileApprovalResult(
      uiStatus: MobileApprovalUiStatus.error,
      errorCode: 'INVALID_TOKEN',
      messageEn: 'Approval token is invalid or expired.',
      messageBn: 'অনুমোদন টোকেন সঠিক নয় বা মেয়াদোত্তীর্ণ।',
    );
  }

  /// Lists pending requests for mobile manager dashboard.
  Future<MobileApprovalResult<List<MobileApprovalRecord>>> getPendingRequests({
    required String tenantId,
    String? branchId,
  }) async {
    final list = _cache.values.where((r) {
      return r.tenantId == tenantId &&
          (branchId == null || r.branchId == branchId) &&
          r.status == 'PENDING';
    }).toList();

    if (list.isEmpty) {
      return const MobileApprovalResult(
        uiStatus: MobileApprovalUiStatus.empty,
        data: [],
        messageEn: 'No pending approval requests.',
        messageBn: 'কোনো পেন্ডিং অনুমোদনের অনুরোধ নেই।',
      );
    }

    return MobileApprovalResult(
      uiStatus: MobileApprovalUiStatus.success,
      data: list,
      messageEn: 'Fetched ${list.length} pending requests.',
      messageBn: '${list.length}টি পেন্ডিং অনুরোধ পাওয়া গেছে।',
    );
  }
}
