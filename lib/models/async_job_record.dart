// lib/models/async_job_record.dart
// Architecture Decision: ADR-0031 & ADR-0024
// Models asynchronous background job statuses for the pharmacy owner manager app.

enum JobCategoryType {
  notification,
  reminder,
  derivedAnalytics,
}

enum JobExecutionState {
  pending,
  processing,
  success,
  failed,
  retrying,
}

class AsyncJobRecordModel {
  final String jobId;
  final String tenantId;
  final String? branchId;
  final JobCategoryType category;
  final String taskName;
  final JobExecutionState status;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? result;
  final String? errorMessage;
  final int retryCount;
  final String scheduledAt;
  final String? completedAt;

  const AsyncJobRecordModel({
    required this.jobId,
    required this.tenantId,
    this.branchId,
    required this.category,
    required this.taskName,
    required this.status,
    required this.payload,
    this.result,
    this.errorMessage,
    required this.retryCount,
    required this.scheduledAt,
    this.completedAt,
  });

  bool get isSuccessful => status == JobExecutionState.success;
  bool get isProcessing => status == JobExecutionState.processing;
  bool get hasFailed => status == JobExecutionState.failed;

  String localizedStatus(String locale) {
    final isBn = locale.toLowerCase().startsWith('bn');
    switch (status) {
      case JobExecutionState.success:
        return isBn ? 'সফল' : 'Success';
      case JobExecutionState.processing:
        return isBn ? 'প্রক্রিয়াধীন' : 'Processing';
      case JobExecutionState.failed:
        return isBn ? 'ব্যর্থ' : 'Failed';
      case JobExecutionState.retrying:
        return isBn ? 'পুনরায় চেষ্টা চলছে' : 'Retrying';
      case JobExecutionState.pending:
      default:
        return isBn ? 'অপেক্ষমাণ' : 'Pending';
    }
  }

  factory AsyncJobRecordModel.fromJson(Map<String, dynamic> json) {
    final catStr = json['category']?.toString().toUpperCase() ?? 'NOTIFICATION';
    final category = catStr == 'DERIVED_ANALYTICS'
        ? JobCategoryType.derivedAnalytics
        : catStr == 'REMINDER'
            ? JobCategoryType.reminder
            : JobCategoryType.notification;

    final statStr = json['status']?.toString().toUpperCase() ?? 'PENDING';
    final status = statStr == 'SUCCESS'
        ? JobExecutionState.success
        : statStr == 'PROCESSING'
            ? JobExecutionState.processing
            : statStr == 'FAILED'
                ? JobExecutionState.failed
                : statStr == 'RETRYING'
                    ? JobExecutionState.retrying
                    : JobExecutionState.pending;

    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};

    final rawResult = json['result'];
    final result =
        rawResult is Map ? Map<String, dynamic>.from(rawResult) : null;

    return AsyncJobRecordModel(
      jobId: json['job_id']?.toString() ?? '',
      tenantId: json['tenant']?.toString() ?? '',
      branchId: json['branch']?.toString(),
      category: category,
      taskName: json['task_name']?.toString() ?? '',
      status: status,
      payload: payload,
      result: result,
      errorMessage: json['error_message']?.toString(),
      retryCount: json['retry_count'] as int? ?? 0,
      scheduledAt: json['scheduled_at']?.toString() ?? '',
      completedAt: json['completed_at']?.toString(),
    );
  }
}
