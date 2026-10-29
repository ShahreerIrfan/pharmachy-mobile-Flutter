/// Flutter Mobile Structured Log Entry and Correlation Model (ADR-0035)
class StructuredLogEntry {
  final DateTime timestamp;
  final String level;
  final String logger;
  final String message;
  final String service;
  final String requestId;
  final String? tenantId;
  final String? deviceId;
  final String? operationId;
  final String? userId;

  StructuredLogEntry({
    required this.level,
    required this.logger,
    required this.message,
    required this.requestId,
    this.tenantId,
    this.deviceId,
    this.operationId,
    this.userId,
    DateTime? timestamp,
    this.service = 'pharmacy-mobile-manager',
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level,
      'logger': logger,
      'message': message,
      'service': service,
      'context': {
        'request_id': requestId,
        'tenant_id': tenantId,
        'device_id': deviceId,
        'operation_id': operationId,
        'user_id': userId,
      },
    };
  }

  Map<String, String> toCorrelationHeaders() {
    final headers = <String, String>{
      'X-Request-ID': requestId,
    };
    if (tenantId != null) headers['X-Tenant-ID'] = tenantId!;
    if (deviceId != null) headers['X-Device-ID'] = deviceId!;
    if (operationId != null) headers['X-Operation-ID'] = operationId!;
    return headers;
  }
}
