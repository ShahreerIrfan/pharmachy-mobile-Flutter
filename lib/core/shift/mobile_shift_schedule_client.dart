// lib/core/shift/mobile_shift_schedule_client.dart
// Architecture Decision: ADR-0109
// Phase 06: Milestone M03 - Shift Scheduling & Attendance Boundaries (P109)

enum MobileShiftUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileShiftRecord {
  final String scheduleId;
  final String tenantId;
  final String branchId;
  final String staffUserId;
  final String staffEmail;
  final String? staffName;
  final String shiftName;
  final String shiftType;
  final String startTime;
  final String endTime;
  final String? displayStartLocal;
  final String? displayEndLocal;
  final String timezoneName;
  final String status;
  final int gracePeriodMinutes;
  final String? clockInAt;
  final String? clockOutAt;
  final String attendanceStatus;
  final String notes;
  final String createdAt;

  const MobileShiftRecord({
    required this.scheduleId,
    required this.tenantId,
    required this.branchId,
    required this.staffUserId,
    required this.staffEmail,
    this.staffName,
    required this.shiftName,
    required this.shiftType,
    required this.startTime,
    required this.endTime,
    this.displayStartLocal,
    this.displayEndLocal,
    this.timezoneName = 'Asia/Dhaka',
    required this.status,
    this.gracePeriodMinutes = 15,
    this.clockInAt,
    this.clockOutAt,
    required this.attendanceStatus,
    required this.notes,
    required this.createdAt,
  });

  factory MobileShiftRecord.fromJson(Map<String, dynamic> json) {
    return MobileShiftRecord(
      scheduleId: json['schedule_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String? ?? '',
      staffUserId: json['staff_user_id'] as String? ?? '',
      staffEmail: json['staff_email'] as String? ?? '',
      staffName: json['staff_name'] as String?,
      shiftName: json['shift_name'] as String? ?? '',
      shiftType: json['shift_type'] as String? ?? 'MORNING',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      displayStartLocal: json['display_start_local'] as String?,
      displayEndLocal: json['display_end_local'] as String?,
      timezoneName: json['timezone_name'] as String? ?? 'Asia/Dhaka',
      status: json['status'] as String? ?? 'SCHEDULED',
      gracePeriodMinutes: json['grace_period_minutes'] as int? ?? 15,
      clockInAt: json['clock_in_at'] as String?,
      clockOutAt: json['clock_out_at'] as String?,
      attendanceStatus: json['attendance_status'] as String? ?? 'PENDING',
      notes: json['notes'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schedule_id': scheduleId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'staff_user_id': staffUserId,
      'staff_email': staffEmail,
      'staff_name': staffName,
      'shift_name': shiftName,
      'shift_type': shiftType,
      'start_time': startTime,
      'end_time': endTime,
      'display_start_local': displayStartLocal,
      'display_end_local': displayEndLocal,
      'timezone_name': timezoneName,
      'status': status,
      'grace_period_minutes': gracePeriodMinutes,
      'clock_in_at': clockInAt,
      'clock_out_at': clockOutAt,
      'attendance_status': attendanceStatus,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}

class MobileShiftResult<T> {
  final MobileShiftUiStatus uiStatus;
  final T? data;
  final String? errorCode;
  final String? messageEn;
  final String? messageBn;

  const MobileShiftResult({
    required this.uiStatus,
    this.data,
    this.errorCode,
    this.messageEn,
    this.messageBn,
  });

  bool get isSuccess => uiStatus == MobileShiftUiStatus.success;
}

class MobileShiftScheduleClient {
  final String baseUrl;
  final Map<String, MobileShiftRecord> _cache = {};
  bool simulatedOffline = false;

  MobileShiftScheduleClient({this.baseUrl = 'http://localhost:8000/api/v2'});

  void setSimulatedOffline(bool offline) {
    simulatedOffline = offline;
  }

  /// Creates a staff shift schedule. Enforces interval, zero-overlap, and manager RBAC.
  Future<MobileShiftResult<MobileShiftRecord>> createShiftSchedule({
    required String tenantId,
    required String branchId,
    required String staffUserId,
    required String staffEmail,
    required String shiftName,
    required String shiftType,
    required DateTime startTime,
    required DateTime endTime,
    int gracePeriodMinutes = 15,
    String notes = '',
    required String actorRole,
    required String actorBranchId,
  }) async {
    final role = actorRole.toUpperCase();
    if (role != 'SUPERADMIN' && role != 'PHARMACY_OWNER' && role != 'BRANCH_MANAGER') {
      return const MobileShiftResult(
        uiStatus: MobileShiftUiStatus.permissionDenied,
        errorCode: 'ERR_PERMISSION_DENIED',
        messageEn: 'Frontline staff cannot schedule rosters.',
        messageBn: 'শিফট শিডিউল তৈরি করার অনুমতি আপনার নেই।',
      );
    }

    if (role == 'BRANCH_MANAGER' && actorBranchId != branchId) {
      return const MobileShiftResult(
        uiStatus: MobileShiftUiStatus.permissionDenied,
        errorCode: 'ERR_CROSS_BRANCH_VIOLATION',
        messageEn: 'Branch Manager cannot schedule shifts for other branches.',
        messageBn: 'ব্রাঞ্চ ম্যানেজার অন্য ব্রাঞ্চের জন্য শিফট নির্ধারণ করতে পারেন না।',
      );
    }

    if (shiftName.trim().length < 2) {
      return const MobileShiftResult(
        uiStatus: MobileShiftUiStatus.error,
        errorCode: 'INVALID_SHIFT_NAME',
        messageEn: 'Shift name must be at least 2 characters.',
        messageBn: 'শিফটের নাম কমপক্ষে ২ অক্ষরের হতে হবে।',
      );
    }

    if (!endTime.isAfter(startTime)) {
      return const MobileShiftResult(
        uiStatus: MobileShiftUiStatus.error,
        errorCode: 'ERR_INVALID_SHIFT_INTERVAL',
        messageEn: 'Shift end time must be after start time.',
        messageBn: 'শিফটের সমাপ্তি সময় অবশ্যই শুরুর সময়ের পরে হতে হবে।',
      );
    }

    if (endTime.difference(startTime).inMinutes < 30) {
      return const MobileShiftResult(
        uiStatus: MobileShiftUiStatus.error,
        errorCode: 'ERR_SHIFT_TOO_SHORT',
        messageEn: 'Shift duration must be at least 30 minutes.',
        messageBn: 'শিফটের স্থায়িত্ব কমপক্ষে ৩০ মিনিট হতে হবে।',
      );
    }

    // Zero Collision Overlap Check
    for (final r in _cache.values) {
      if (r.tenantId == tenantId && r.staffUserId == staffUserId && r.status != 'CANCELLED') {
        final rStart = DateTime.parse(r.startTime);
        final rEnd = DateTime.parse(r.endTime);
        if (rStart.isBefore(endTime) && rEnd.isAfter(startTime)) {
          return MobileShiftResult(
            uiStatus: MobileShiftUiStatus.error,
            errorCode: 'ERR_SHIFT_OVERLAP_COLLISION',
            messageEn: 'Staff member already has an overlapping shift: ${r.shiftName}',
            messageBn: 'কর্মী ইতিমধ্যে অন্য একটি নির্ধারিত শিফটে অন্তর্ভুক্ত রয়েছেন।',
          );
        }
      }
    }

    final schedId = 'sched-${DateTime.now().microsecondsSinceEpoch}';
    final rec = MobileShiftRecord(
      scheduleId: schedId,
      tenantId: tenantId,
      branchId: branchId,
      staffUserId: staffUserId,
      staffEmail: staffEmail,
      shiftName: shiftName.trim(),
      shiftType: shiftType,
      startTime: startTime.toIso8601String(),
      endTime: endTime.toIso8601String(),
      displayStartLocal: '${startTime.hour.toString().padLeft(2, '0')}:00 BST',
      displayEndLocal: '${endTime.hour.toString().padLeft(2, '0')}:00 BST',
      timezoneName: 'Asia/Dhaka',
      status: 'SCHEDULED',
      gracePeriodMinutes: gracePeriodMinutes,
      clockInAt: null,
      clockOutAt: null,
      attendanceStatus: 'PENDING',
      notes: notes.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    _cache[schedId] = rec;

    if (simulatedOffline) {
      return MobileShiftResult(
        uiStatus: MobileShiftUiStatus.offline,
        data: rec,
        errorCode: 'OFFLINE_QUEUED',
        messageEn: 'Offline. Shift schedule cached locally.',
        messageBn: 'অফলাইন। শিফট শিডিউল লোকাল ক্যাশে জমা রাখা হয়েছে।',
      );
    }

    return MobileShiftResult(
      uiStatus: MobileShiftUiStatus.success,
      data: rec,
      messageEn: 'Shift scheduled successfully.',
      messageBn: 'শিফট শিডিউল সফলভাবে সম্পন্ন হয়েছে।',
    );
  }

  /// Clocks in staff member, checking attendance boundaries.
  Future<MobileShiftResult<MobileShiftRecord>> clockIn({
    required String tenantId,
    required String scheduleId,
    required String actorUserId,
    required String actorRole,
  }) async {
    final r = _cache[scheduleId];
    if (r == null) {
      return const MobileShiftResult(
        uiStatus: MobileShiftUiStatus.error,
        errorCode: 'ERR_NOT_FOUND',
        messageEn: 'Shift schedule not found.',
        messageBn: 'শিফট শিডিউল খুঁজে পাওয়া যায়নি।',
      );
    }

    final role = actorRole.toUpperCase();
    if (r.staffUserId != actorUserId && role != 'BRANCH_MANAGER' &&
        role != 'PHARMACY_OWNER' && role != 'SUPERADMIN') {
      return const MobileShiftResult(
        uiStatus: MobileShiftUiStatus.permissionDenied,
        errorCode: 'ERR_CANNOT_CLOCK_IN_FOR_OTHERS',
        messageEn: 'You can only clock in to your own assigned shift.',
        messageBn: 'আপনি কেবল আপনার নিজের শিফটে ক্লক-ইন করতে পারবেন।',
      );
    }

    final now = DateTime.now();
    final rStart = DateTime.parse(r.startTime);
    final graceLimit = rStart.add(Duration(minutes: r.gracePeriodMinutes));
    final attStatus = now.isAfter(graceLimit) ? 'LATE' : 'ON_TIME';

    final updated = MobileShiftRecord(
      scheduleId: r.scheduleId,
      tenantId: r.tenantId,
      branchId: r.branchId,
      staffUserId: r.staffUserId,
      staffEmail: r.staffEmail,
      shiftName: r.shiftName,
      shiftType: r.shiftType,
      startTime: r.startTime,
      endTime: r.endTime,
      displayStartLocal: r.displayStartLocal,
      displayEndLocal: r.displayEndLocal,
      timezoneName: r.timezoneName,
      status: 'IN_PROGRESS',
      gracePeriodMinutes: r.gracePeriodMinutes,
      clockInAt: now.toIso8601String(),
      clockOutAt: r.clockOutAt,
      attendanceStatus: attStatus,
      notes: r.notes,
      createdAt: r.createdAt,
    );

    _cache[scheduleId] = updated;

    return MobileShiftResult(
      uiStatus: MobileShiftUiStatus.success,
      data: updated,
      messageEn: 'Clocked in successfully ($attStatus).',
      messageBn: 'ক্লক-ইন সম্পন্ন হয়েছে ($attStatus)।',
    );
  }

  /// Clocks out staff member, marking shift COMPLETED.
  Future<MobileShiftResult<MobileShiftRecord>> clockOut({
    required String tenantId,
    required String scheduleId,
    required String actorUserId,
    required String actorRole,
  }) async {
    final r = _cache[scheduleId];
    if (r == null) {
      return const MobileShiftResult(
        uiStatus: MobileShiftUiStatus.error,
        errorCode: 'ERR_NOT_FOUND',
        messageEn: 'Shift schedule not found.',
        messageBn: 'শিফট শিডিউল খুঁজে পাওয়া যায়নি।',
      );
    }

    final now = DateTime.now();
    final completed = MobileShiftRecord(
      scheduleId: r.scheduleId,
      tenantId: r.tenantId,
      branchId: r.branchId,
      staffUserId: r.staffUserId,
      staffEmail: r.staffEmail,
      shiftName: r.shiftName,
      shiftType: r.shiftType,
      startTime: r.startTime,
      endTime: r.endTime,
      displayStartLocal: r.displayStartLocal,
      displayEndLocal: r.displayEndLocal,
      timezoneName: r.timezoneName,
      status: 'COMPLETED',
      gracePeriodMinutes: r.gracePeriodMinutes,
      clockInAt: r.clockInAt,
      clockOutAt: now.toIso8601String(),
      attendanceStatus: r.attendanceStatus,
      notes: r.notes,
      createdAt: r.createdAt,
    );

    _cache[scheduleId] = completed;

    return MobileShiftResult(
      uiStatus: MobileShiftUiStatus.success,
      data: completed,
      messageEn: 'Shift completed and clocked out.',
      messageBn: 'শিফট সম্পন্ন এবং ক্লক-আউট হয়েছে।',
    );
  }

  /// Retrieves assigned shifts for logged in staff member.
  Future<MobileShiftResult<List<MobileShiftRecord>>> getMyShifts({
    required String tenantId,
    required String staffUserId,
  }) async {
    final list = _cache.values
        .where((r) => r.tenantId == tenantId && r.staffUserId == staffUserId)
        .toList();

    if (list.isEmpty) {
      return const MobileShiftResult(
        uiStatus: MobileShiftUiStatus.empty,
        data: [],
        messageEn: 'No assigned shifts found.',
        messageBn: 'কোনো নির্ধারিত শিফট পাওয়া যায়নি।',
      );
    }

    return MobileShiftResult(
      uiStatus: MobileShiftUiStatus.success,
      data: list,
      messageEn: 'Retrieved ${list.length} shifts.',
      messageBn: '${list.length}টি শিফট পাওয়া গেছে।',
    );
  }
}
