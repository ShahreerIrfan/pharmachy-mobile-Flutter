// test/core/billing/mobile_device_seat_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_device_seat_client.dart';

void main() {
  group('P096 - Mobile Device Seats Management Client Tests', () {
    test('Parses MobileDeviceSeatRecord JSON accurately with invariants', () {
      final now = DateTime.now();
      final jsonPayload = {
        'device_id': 'dev-mob-01',
        'tenant_id': 'tn-test-01',
        'branch_id': 'br-01',
        'branch_name': 'Banani Branch',
        'device_name': 'Counter 1 POS',
        'device_type': 'DESKTOP_POS',
        'status': 'ACTIVE',
        'mac_address': 'AA:BB:CC:DD:EE:FF',
        'ip_address': '192.168.1.50',
        'hardware_fingerprint': 'hw-fp-9921',
        'enrolled_at': now.toIso8601String(),
        'enrolled_by': 'owner@pharma.local',
        'revoked_at': null,
        'revoked_by': null,
        'revocation_reason': '',
        'last_heartbeat_at': now.toIso8601String(),
        'invariants': {
          'zero_data_deleted': true,
          'lease_invalidation_enforced': true,
          'quota_counter_synced': true,
        },
        'client_messaging': {
          'headline_en': 'Device Seat Active: Counter 1 POS',
          'headline_bn': 'ডিভাইস সীট সক্রিয়: Counter 1 POS',
          'details_en': 'Assigned to branch Banani Branch.',
          'details_bn': 'শাখা Banani Branch-এ বরাদ্দকৃত।',
        },
      };

      final record = MobileDeviceSeatRecord.fromJson(jsonPayload);

      expect(record.deviceId, 'dev-mob-01');
      expect(record.branchName, 'Banani Branch');
      expect(record.isActive, isTrue);
      expect(record.isRevoked, isFalse);
      expect(record.zeroDataDeleted, isTrue);
      expect(record.leaseInvalidationEnforced, isTrue);
      expect(record.quotaCounterSynced, isTrue);
      expect(record.headlineBn, contains('সক্রিয়'));
    });

    test('Parses MobileDeviceSeatsSummary and evaluates seat capacity correctly', () {
      final summaryJson = {
        'total_enrolled': 5,
        'active_seats_used': 5,
        'max_limit': 5,
        'remaining': 0,
        'utilization_pct': 100.0,
        'is_over_quota': false,
        'status': 'LIMIT_REACHED',
      };

      final summary = MobileDeviceSeatsSummary.fromJson(summaryJson);

      expect(summary.activeSeatsUsed, 5);
      expect(summary.maxLimit, 5);
      expect(summary.remaining, 0);
      expect(summary.isAtCapacity, isTrue);
      expect(summary.canEnrollMore, isFalse);
      expect(summary.status, 'LIMIT_REACHED');
    });

    test('Parses full MobileDeviceSeatsResponse correctly', () {
      final responseJson = {
        'tenant_id': 'tn-test-01',
        'plan_tier': 'STANDARD',
        'devices': [
          {
            'device_id': 'dev-01',
            'tenant_id': 'tn-test-01',
            'branch_id': 'br-01',
            'branch_name': 'Banani',
            'device_name': 'Terminal 1',
            'device_type': 'DESKTOP_POS',
            'status': 'ACTIVE',
            'mac_address': '',
            'ip_address': '',
            'hardware_fingerprint': '',
            'enrolled_at': '2026-11-01T10:00:00Z',
            'enrolled_by': 'admin@test.local',
            'revocation_reason': '',
            'invariants': {
              'zero_data_deleted': true,
              'lease_invalidation_enforced': true,
              'quota_counter_synced': true,
            },
            'client_messaging': {
              'headline_en': 'Active',
              'headline_bn': 'সক্রিয়',
              'details_en': 'Details',
              'details_bn': 'বিবরণ',
            },
          }
        ],
        'seat_summary': {
          'total_enrolled': 1,
          'active_seats_used': 1,
          'max_limit': 5,
          'remaining': 4,
          'utilization_pct': 20.0,
          'is_over_quota': false,
          'status': 'NORMAL',
        },
        'client_messaging': {
          'headline_en': 'Device Seats Management',
          'headline_bn': 'ডিভাইস সীট ব্যবস্থাপনা',
          'details_en': '1 of 5 device seats in use.',
          'details_bn': 'মোট ৫ টির মধ্যে ১ টি ব্যবহৃত হচ্ছে।',
        },
      };

      final response = MobileDeviceSeatsResponse.fromJson(responseJson);

      expect(response.tenantId, 'tn-test-01');
      expect(response.planTier, 'STANDARD');
      expect(response.devices.length, 1);
      expect(response.devices[0].deviceId, 'dev-01');
      expect(response.seatSummary.canEnrollMore, isTrue);
      expect(response.headlineBn, contains('ডিভাইস সীট ব্যবস্থাপনা'));
    });
  });
}

