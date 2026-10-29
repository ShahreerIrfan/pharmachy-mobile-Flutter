// test/unit/async_job_record_test.dart
// Architecture Decision: ADR-0031 & ADR-0024

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/models/async_job_record.dart';

void main() {
  group('AsyncJobRecordModel Serialization & Bilingual Localization', () {
    test('Correctly parses valid JSON and returns bilingual status labels', () {
      final json = {
        'job_id': 'job_test_123',
        'tenant': 'tenant-dhaka-central',
        'branch': 'branch-dhk-main',
        'category': 'DERIVED_ANALYTICS',
        'task_name': 'aggregate_daily_sales_analytics_task',
        'status': 'SUCCESS',
        'payload': {'date_str': '2026-10-29'},
        'result': {'total_sales': '152.40'},
        'retry_count': 0,
        'scheduled_at': '2026-10-29T09:00:00Z',
        'completed_at': '2026-10-29T09:00:01Z',
      };

      final model = AsyncJobRecordModel.fromJson(json);

      expect(model.jobId, equals('job_test_123'));
      expect(model.category, equals(JobCategoryType.derivedAnalytics));
      expect(model.status, equals(JobExecutionState.success));
      expect(model.isSuccessful, isTrue);
      expect(model.localizedStatus('en'), equals('Success'));
      expect(model.localizedStatus('bn'), equals('সফল'));
    });

    test('Correctly handles pending and failed states', () {
      final failedJson = {
        'job_id': 'job_test_failed',
        'tenant': 'tenant-dhaka-central',
        'category': 'NOTIFICATION',
        'task_name': 'send_sale_notification_task',
        'status': 'FAILED',
        'payload': {},
        'error_message': 'SMS Gateway Timeout',
        'retry_count': 3,
        'scheduled_at': '2026-10-29T09:00:00Z',
      };

      final model = AsyncJobRecordModel.fromJson(failedJson);

      expect(model.hasFailed, isTrue);
      expect(model.isSuccessful, isFalse);
      expect(model.localizedStatus('en'), equals('Failed'));
      expect(model.localizedStatus('bn'), equals('ব্যর্থ'));
      expect(model.errorMessage, equals('SMS Gateway Timeout'));
    });
  });
}
