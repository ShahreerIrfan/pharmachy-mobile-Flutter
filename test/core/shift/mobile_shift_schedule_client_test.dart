import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/shift/mobile_shift_schedule_client.dart';

void main() {
  group('P109: MobileShiftScheduleClient Tests', () {
    late MobileShiftScheduleClient client;
    const tenantId = 'tn-popular-dhk';
    const branchA = 'br-dhanmondi-main';
    const branchB = 'br-gulshan-outlet';
    const staffId = 'usr-cashier-01';
    const staffEmail = 'cashier_rahim@popular.local';

    setUp(() {
      client = MobileShiftScheduleClient(baseUrl: 'http://localhost:8000/api/v2');
    });

    test('P109: Branch Manager schedules staff shift successfully', () async {
      final now = DateTime.now();
      final start = now.add(const Duration(hours: 2));
      final end = start.add(const Duration(hours: 8));

      final res = await client.createShiftSchedule(
        tenantId: tenantId,
        branchId: branchA,
        staffUserId: staffId,
        staffEmail: staffEmail,
        shiftName: 'Morning Dispensing Roster',
        shiftType: 'MORNING',
        startTime: start,
        endTime: end,
        gracePeriodMinutes: 15,
        notes: 'Counter priority',
        actorRole: 'BRANCH_MANAGER',
        actorBranchId: branchA,
      );

      expect(res.isSuccess, isTrue);
      expect(res.uiStatus, equals(MobileShiftUiStatus.success));
      expect(res.data?.status, equals('SCHEDULED'));
      expect(res.data?.attendanceStatus, equals('PENDING'));
    });

    test('P109: Inverted interval or short shift duration rejected', () async {
      final now = DateTime.now();
      final start = now.add(const Duration(hours: 2));
      final badEnd = start.subtract(const Duration(hours: 1));

      final inverted = await client.createShiftSchedule(
        tenantId: tenantId,
        branchId: branchA,
        staffUserId: staffId,
        staffEmail: staffEmail,
        shiftName: 'Bad Interval',
        shiftType: 'CUSTOM',
        startTime: start,
        endTime: badEnd,
        actorRole: 'BRANCH_MANAGER',
        actorBranchId: branchA,
      );
      expect(inverted.uiStatus, equals(MobileShiftUiStatus.error));
      expect(inverted.errorCode, equals('ERR_INVALID_SHIFT_INTERVAL'));

      final shortEnd = start.add(const Duration(minutes: 15));
      final tooShort = await client.createShiftSchedule(
        tenantId: tenantId,
        branchId: branchA,
        staffUserId: staffId,
        staffEmail: staffEmail,
        shiftName: 'Short Interval',
        shiftType: 'CUSTOM',
        startTime: start,
        endTime: shortEnd,
        actorRole: 'BRANCH_MANAGER',
        actorBranchId: branchA,
      );
      expect(tooShort.uiStatus, equals(MobileShiftUiStatus.error));
      expect(tooShort.errorCode, equals('ERR_SHIFT_TOO_SHORT'));
    });

    test('P109: Shift overlap collision blocked for same staff', () async {
      final now = DateTime.now();
      final start1 = now.add(const Duration(hours: 2));
      final end1 = start1.add(const Duration(hours: 6));

      // 1. Create first shift
      final first = await client.createShiftSchedule(
        tenantId: tenantId,
        branchId: branchA,
        staffUserId: staffId,
        staffEmail: staffEmail,
        shiftName: 'Initial Shift',
        shiftType: 'MORNING',
        startTime: start1,
        endTime: end1,
        actorRole: 'BRANCH_MANAGER',
        actorBranchId: branchA,
      );
      expect(first.isSuccess, isTrue);

      // 2. Attempt overlapping shift
      final start2 = start1.add(const Duration(hours: 2));
      final end2 = end1.add(const Duration(hours: 2));

      final collision = await client.createShiftSchedule(
        tenantId: tenantId,
        branchId: branchA,
        staffUserId: staffId,
        staffEmail: staffEmail,
        shiftName: 'Colliding Shift',
        shiftType: 'EVENING',
        startTime: start2,
        endTime: end2,
        actorRole: 'BRANCH_MANAGER',
        actorBranchId: branchA,
      );

      expect(collision.uiStatus, equals(MobileShiftUiStatus.error));
      expect(collision.errorCode, equals('ERR_SHIFT_OVERLAP_COLLISION'));
      expect(collision.messageBn, contains('ইতিমধ্যে অন্য একটি নির্ধারিত শিফট'));
    });

    test('P109: Cashier denied creating shift schedules (RBAC)', () async {
      final now = DateTime.now();
      final start = now.add(const Duration(hours: 1));
      final end = start.add(const Duration(hours: 8));

      final res = await client.createShiftSchedule(
        tenantId: tenantId,
        branchId: branchA,
        staffUserId: staffId,
        staffEmail: staffEmail,
        shiftName: 'Unauthorized Cashier Shift',
        shiftType: 'MORNING',
        startTime: start,
        endTime: end,
        actorRole: 'CASHIER',
        actorBranchId: branchA,
      );

      expect(res.uiStatus, equals(MobileShiftUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_PERMISSION_DENIED'));
    });

    test('P109: Branch Manager cross-branch violation blocked', () async {
      final now = DateTime.now();
      final start = now.add(const Duration(hours: 1));
      final end = start.add(const Duration(hours: 8));

      // Manager of Branch B attempts to schedule for Branch A
      final res = await client.createShiftSchedule(
        tenantId: tenantId,
        branchId: branchA,
        staffUserId: staffId,
        staffEmail: staffEmail,
        shiftName: 'Cross Branch Shift',
        shiftType: 'MORNING',
        startTime: start,
        endTime: end,
        actorRole: 'BRANCH_MANAGER',
        actorBranchId: branchB,
      );

      expect(res.uiStatus, equals(MobileShiftUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_CROSS_BRANCH_VIOLATION'));
    });

    test('P109: Clock-in and Clock-out updates attendance status', () async {
      final now = DateTime.now();
      final start = now.add(const Duration(minutes: 5));
      final end = start.add(const Duration(hours: 8));

      final sub = await client.createShiftSchedule(
        tenantId: tenantId,
        branchId: branchA,
        staffUserId: staffId,
        staffEmail: staffEmail,
        shiftName: 'Active Shift Flow',
        shiftType: 'MORNING',
        startTime: start,
        endTime: end,
        actorRole: 'BRANCH_MANAGER',
        actorBranchId: branchA,
      );
      expect(sub.isSuccess, isTrue);

      // Clock in
      final clockInRes = await client.clockIn(
        tenantId: tenantId,
        scheduleId: sub.data!.scheduleId,
        actorUserId: staffId,
        actorRole: 'CASHIER',
      );
      expect(clockInRes.isSuccess, isTrue);
      expect(clockInRes.data?.status, equals('IN_PROGRESS'));
      expect(clockInRes.data?.attendanceStatus, equals('ON_TIME'));

      // Clock out
      final clockOutRes = await client.clockOut(
        tenantId: tenantId,
        scheduleId: sub.data!.scheduleId,
        actorUserId: staffId,
        actorRole: 'CASHIER',
      );
      expect(clockOutRes.isSuccess, isTrue);
      expect(clockOutRes.data?.status, equals('COMPLETED'));
    });

    test('P109: Offline client queues shifts and allows roster inspection', () async {
      client.setSimulatedOffline(true);

      final now = DateTime.now();
      final start = now.add(const Duration(hours: 4));
      final end = start.add(const Duration(hours: 8));

      final sub = await client.createShiftSchedule(
        tenantId: tenantId,
        branchId: branchA,
        staffUserId: staffId,
        staffEmail: staffEmail,
        shiftName: 'Offline Shift Roster',
        shiftType: 'MORNING',
        startTime: start,
        endTime: end,
        actorRole: 'BRANCH_MANAGER',
        actorBranchId: branchA,
      );

      expect(sub.uiStatus, equals(MobileShiftUiStatus.offline));
      expect(sub.errorCode, equals('OFFLINE_QUEUED'));

      final myShifts = await client.getMyShifts(
        tenantId: tenantId,
        staffUserId: staffId,
      );
      expect(myShifts.isSuccess, isTrue);
      expect(myShifts.data?.length, equals(1));
    });
  });
}
