// test/core/audit/mobile_staff_audit_timeline_client_test.dart
// Unit tests for P118 Staff Audit Timeline mobile client.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/audit/mobile_staff_audit_timeline_client.dart';

void main() {
  group('MobileStaffAuditTimelineClient Tests', () {
    late MobileStaffAuditTimelineClient client;
    late List<MobileTimelineItem> sampleEvents;

    setUp(() {
      client = MobileStaffAuditTimelineClient();
      sampleEvents = [
        const MobileTimelineItem(
          timelineId: 'tl-101',
          timestamp: '2026-11-02T09:00:00Z',
          tenantId: 'tenant-1',
          branchId: 'branch-1',
          eventCategory: 'ROLE_CHANGE',
          action: 'ROLE_REVOKED',
          status: 'SUCCESS',
          actorId: 'owner-1',
          actorEmail: 'owner@pharma.com',
          actorRole: 'PHARMACY_OWNER',
          deviceId: 'DEV-TAB-01',
          ipAddress: '10.0.0.1',
          targetStaffId: 'staff-99',
          targetStaffName: 'Nasir',
          summaryEn: 'Role revoked for Nasir',
          summaryBn: 'নাসিরের রোল প্রত্যাহার করা হয়েছে',
        ),
        const MobileTimelineItem(
          timelineId: 'tl-102',
          timestamp: '2026-11-02T10:00:00Z',
          tenantId: 'tenant-1',
          branchId: 'branch-1',
          eventCategory: 'PERMISSION_DENIAL',
          action: 'EXPORT_CUSTOMERS_DENIED',
          status: 'DENIED',
          actorId: 'staff-55',
          actorEmail: 'cashier@pharma.com',
          actorRole: 'CASHIER',
          deviceId: 'DEV-POS-01',
          ipAddress: '10.0.0.2',
          summaryEn: 'Unauthorized export denied',
          summaryBn: 'অননুমোদিত এক্সপোর্ট প্রত্যাখ্যাত',
        ),
        const MobileTimelineItem(
          timelineId: 'tl-103',
          timestamp: '2026-11-02T11:00:00Z',
          tenantId: 'tenant-1',
          branchId: 'branch-2',
          eventCategory: 'OFFLINE_EVENT',
          action: 'OFFLINE_SYNC_REPLAY',
          status: 'SUCCESS',
          actorId: 'staff-88',
          actorEmail: 'mgr@pharma.com',
          actorRole: 'BRANCH_MANAGER',
          deviceId: 'DEV-DESK-01',
          ipAddress: '10.0.0.3',
          summaryEn: '15 offline transactions replayed',
          summaryBn: '১৫টি অফলাইন লেনদেন রি-প্লে সম্পন্ন',
        ),
      ];
    });

    test('Owner queries all timeline events across branches', () {
      final res = client.filterTimeline(
        items: sampleEvents,
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        targetTenantId: 'tenant-1',
      );

      expect(res.uiStatus, MobileTimelineUiStatus.success);
      expect(res.items.length, 3);
    });

    test('Filter events by category OFFLINE_EVENT', () {
      final res = client.filterTimeline(
        items: sampleEvents,
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        targetTenantId: 'tenant-1',
        filterCategory: 'OFFLINE_EVENT',
      );

      expect(res.uiStatus, MobileTimelineUiStatus.success);
      expect(res.items.length, 1);
      expect(res.items.first.action, 'OFFLINE_SYNC_REPLAY');
      expect(res.items.first.deviceId, 'DEV-DESK-01');
    });

    test('Branch Manager restricted to assigned branch', () {
      final res = client.filterTimeline(
        items: sampleEvents,
        callerRole: 'BRANCH_MANAGER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        targetTenantId: 'tenant-1',
        targetBranchId: 'branch-1',
      );

      expect(res.uiStatus, MobileTimelineUiStatus.success);
      expect(res.items.length, 2);
      expect(res.items.every((i) => i.branchId == 'branch-1'), isTrue);
    });

    test('Branch Manager querying other branch is rejected', () {
      final res = client.filterTimeline(
        items: sampleEvents,
        callerRole: 'BRANCH_MANAGER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        targetTenantId: 'tenant-1',
        targetBranchId: 'branch-2',
      );

      expect(res.uiStatus, MobileTimelineUiStatus.permissionDenied);
      expect(res.errorCode, 'ERR_CROSS_BRANCH_VIOLATION');
    });

    test('Cashier access to audit timeline is denied', () {
      final res = client.filterTimeline(
        items: sampleEvents,
        callerRole: 'CASHIER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        targetTenantId: 'tenant-1',
      );

      expect(res.uiStatus, MobileTimelineUiStatus.permissionDenied);
      expect(res.errorCode, 'ERR_STAFF_ROLE_DENIED');
    });

    test('Cross tenant timeline query is forbidden', () {
      final res = client.filterTimeline(
        items: sampleEvents,
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        targetTenantId: 'tenant-999',
      );

      expect(res.uiStatus, MobileTimelineUiStatus.permissionDenied);
      expect(res.errorCode, 'ERR_CROSS_TENANT_VIOLATION');
    });
  });
}
