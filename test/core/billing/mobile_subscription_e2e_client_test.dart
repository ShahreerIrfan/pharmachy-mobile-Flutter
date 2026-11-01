// test/core/billing/mobile_subscription_e2e_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_subscription_e2e_client.dart';

void main() {
  group('MobileSubscriptionE2eClient Tests', () {
    test('parses MobileSupportOverrideRecord and evaluates emergency state', () {
      final jsonEmergency = {
        'override_id': 'ovr-mob-1',
        'tenant_id': 'tn-pharma-01',
        'subscription_id': 'sub-pharma-01',
        'override_type': 'EMERGENCY_UNBLOCK',
        'status': 'ACTIVE',
        'extension_days': 5,
        'quota_bonus': 0,
        'justification': 'DGDA inspection ongoing; urgent dispensary access required',
        'ticket_reference': 'DGDA-2026-NOV',
        'granted_by_user_id': 'usr-admin-01',
        'granted_at': '2026-11-01T10:00:00Z',
        'expires_at': '2026-11-06T10:00:00Z',
      };

      final record = MobileSupportOverrideRecord.fromJson(jsonEmergency);
      expect(record.overrideId, 'ovr-mob-1');
      expect(record.overrideType, 'EMERGENCY_UNBLOCK');
      expect(record.isActive, isTrue);
      expect(record.isEmergencyUnblock, isTrue);
      expect(record.isGraceExtended, isFalse);
      expect(record.ticketReference, 'DGDA-2026-NOV');
    });

    test('generates success state with localized badge rendering', () {
      final jsonGrace = {
        'override_id': 'ovr-mob-2',
        'tenant_id': 'tn-pharma-01',
        'subscription_id': 'sub-pharma-01',
        'override_type': 'GRACE_EXTENSION',
        'status': 'ACTIVE',
        'extension_days': 7,
        'quota_bonus': 0,
        'justification': 'Bank holiday wire clearance delay',
        'ticket_reference': 'SUP-54321',
        'granted_by_user_id': 'usr-admin-01',
        'granted_at': '2026-11-01T10:00:00Z',
        'expires_at': '2026-11-08T10:00:00Z',
      };

      final record = MobileSupportOverrideRecord.fromJson(jsonGrace);
      final state = MobileSubscriptionE2eState.success([record]);

      expect(state.status, MobileSubscriptionE2eUiStatus.success);
      expect(state.hasActiveOverride, isTrue);
      expect(state.activeBadgeEn, contains('Grace Period Extended by 7 Days'));
      expect(state.activeBadgeBn, contains('গ্রেস পিরিয়ড 7 দিন বাড়ানো হয়েছে'));
    });

    test('handles offline and permission denied states cleanly', () {
      final denied = MobileSubscriptionE2eState.permissionDenied('CASHIER');
      expect(denied.status, MobileSubscriptionE2eUiStatus.permissionDenied);
      expect(denied.errorMessageEn, contains("Access denied for role 'CASHIER'"));
      expect(denied.errorMessageBn, contains('সাপোর্ট ওভাররাইড দেখার অনুমতি নেই'));

      final offline = MobileSubscriptionE2eState.offline();
      expect(offline.status, MobileSubscriptionE2eUiStatus.offline);
      expect(offline.errorMessageEn, contains('offline'));
      expect(offline.errorMessageBn, contains('অফলাইনে আছে'));
    });
  });
}
