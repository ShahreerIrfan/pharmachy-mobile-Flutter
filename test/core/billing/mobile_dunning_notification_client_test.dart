// test/core/billing/mobile_dunning_notification_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_dunning_notification_client.dart';

void main() {
  group('MobileDunningNotificationClient Tests', () {
    test('parses MobileDunningAlert from JSON and evaluates urgency correctly', () {
      final jsonUrgent = {
        'notification_id': 'notif-1',
        'tenant_id': 'tn-01',
        'stage': 'PAYMENT_FAILED',
        'channel': 'IN_APP',
        'delivery_status': 'DELIVERED',
        'dedup_key': 'k1',
        'title_en': 'Payment Failed',
        'title_bn': 'পেমেন্ট ব্যর্থ',
        'body_en': 'Please pay invoice',
        'body_bn': 'ইনভয়েস পরিশোধ করুন',
        'amount_due_bdt': '4500.00',
        'is_acknowledged': false,
        'retry_count': 0,
        'max_retries': 3,
        'created_at': '2026-11-01T10:00:00Z',
      };

      final alert = MobileDunningAlert.fromJson(jsonUrgent);
      expect(alert.notificationId, 'notif-1');
      expect(alert.stage, 'PAYMENT_FAILED');
      expect(alert.amountDueBdt, '4500.00');
      expect(alert.isUrgent, isTrue);
      expect(alert.isSuppressed, isFalse);
      expect(alert.isRecovered, isFalse);
    });

    test('detects suppressed duplicate alert and recovered alert', () {
      final jsonSuppressed = {
        'notification_id': 'notif-dup',
        'tenant_id': 'tn-01',
        'stage': 'GRACE_PERIOD_ACTIVE',
        'channel': 'IN_APP',
        'delivery_status': 'SUPPRESSED',
        'dedup_key': 'k2',
        'title_en': 'Grace Warning',
        'title_bn': 'গ্রেস সতর্কতা',
        'body_en': 'Suppressed duplicate',
        'body_bn': 'ডুপ্লিকেট বাতিল',
        'amount_due_bdt': '4500.00',
        'is_acknowledged': false,
        'retry_count': 0,
        'max_retries': 3,
        'created_at': '2026-11-01T11:00:00Z',
      };

      final suppressedAlert = MobileDunningAlert.fromJson(jsonSuppressed);
      expect(suppressedAlert.isSuppressed, isTrue);

      final jsonRecovered = {
        'notification_id': 'notif-rec',
        'tenant_id': 'tn-01',
        'stage': 'PAYMENT_RECOVERED',
        'channel': 'IN_APP',
        'delivery_status': 'DELIVERED',
        'dedup_key': 'k3',
        'title_en': 'Payment Recovered',
        'title_bn': 'পেমেন্ট নিশ্চিত',
        'body_en': 'Service restored',
        'body_bn': 'সার্ভিস পুনরুদ্ধার',
        'amount_due_bdt': '4500.00',
        'is_acknowledged': true,
        'retry_count': 0,
        'max_retries': 3,
        'created_at': '2026-11-01T12:00:00Z',
      };

      final recoveredAlert = MobileDunningAlert.fromJson(jsonRecovered);
      expect(recoveredAlert.isRecovered, isTrue);
      expect(recoveredAlert.isUrgent, isFalse);
    });

    test('creates offline and permissionDenied UI states correctly', () {
      final denied = MobileDunningState.permissionDenied('CASHIER');
      expect(denied.status, MobileDunningUiStatus.permissionDenied);
      expect(denied.errorMessageEn, contains("Access denied for role 'CASHIER'"));
      expect(denied.errorMessageBn, contains('ডানিং নোটিফিকেশন দেখার অনুমতি নেই'));

      final offline = MobileDunningState.offline();
      expect(offline.status, MobileDunningUiStatus.offline);
      expect(offline.errorMessageEn, contains('offline'));
      expect(offline.errorMessageBn, contains('অফলাইনে আছে'));
    });
  });
}
