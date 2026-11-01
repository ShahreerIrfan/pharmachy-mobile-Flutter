// test/core/billing/mobile_offline_plan_lapse_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_offline_plan_lapse_client.dart';

void main() {
  group('P094 - Mobile Offline Plan Lapse Client Tests', () {
    final now = DateTime.now();

    test('Parses held offline transaction record accurately', () {
      final jsonPayload = {
        'hold_id': 'hld-test-001',
        'tenant_id': 'tn-p094-mob',
        'branch_id': 'br-mob-01',
        'device_id': 'pos-terminal-01',
        'offline_event_id': 'evt-off-9912',
        'event_type': 'OFFLINE_SALE',
        'occurred_at': now.toIso8601String(),
        'financial_total_bdt': '1450.75',
        'subscription_status_at_intake': 'EXPIRED',
        'hold_status': 'HELD_PENDING_RECONCILIATION',
        'reconciled_at': null,
        'reconciled_by': null,
        'reconciliation_target_id': null,
        'client_messaging': {
          'headline_en': 'Offline Transaction Held Pending Reconciliation',
          'headline_bn': 'অফলাইন লেনদেন রিকনসিলিয়েশনের অপেক্ষায় জমা রয়েছে',
          'details_en': 'Plan was lapsed during offline push.',
          'details_bn': 'মেয়াদোত্তীর্ণ অবস্থায় অফলাইন ডাটা এসেছে।',
        },
      };

      final record = MobileLapsedHoldRecord.fromJson(jsonPayload);

      expect(record.holdId, 'hld-test-001');
      expect(record.holdStatus, MobileHoldQueueStatus.heldPendingReconciliation);
      expect(record.isReconciled, isFalse);
      expect(record.financialTotalBdt, '1450.75');
      expect(record.headlineBn, contains('রিকনসিলিয়েশনের অপেক্ষায়'));
    });

    test('Parses queue summary and detects pending held transactions', () {
      final summaryJson = {
        'tenant_id': 'tn-p094-mob',
        'pending_count': 6,
        'total_pending_amount_bdt': '7820.00',
        'reconciled_count': 12,
        'client_messaging': {
          'headline_en': 'Offline Transactions Held for Reconciliation (6 Pending)',
          'headline_bn': 'অফলাইন লেনদেন রিকনসিলিয়েশনের জন্য জমা রয়েছে (6 টি বকেয়া)',
          'details_en': 'Total amount: 7820.00 BDT.',
          'details_bn': 'মোট পরিমাণ: 7820.00 টাকা।',
        },
      };

      final summary = MobileHoldQueueSummary.fromJson(summaryJson);

      expect(summary.pendingCount, 6);
      expect(summary.hasPendingItems, isTrue);
      expect(summary.totalPendingAmountBdt, '7820.00');
      expect(summary.reconciledCount, 12);
      expect(summary.headlineBn, contains('6 টি বকেয়া'));
    });
  });
}

