/// MobileDeviceRevocationClient
/// Architecture Decision: ADR-0319 (P319).
/// Phase 16: JavaFX SQLite Offline Store and Reliable Cloud Sync.
///
/// Manages mobile device revocation state, lockdown enforcement,
/// and extraction of unsynced outbox evidence for owner recovery dossiers.
class MobileDeviceRevocationClient {
  bool _isLocked = false;
  String _revocationReason = '';

  bool get isLocked => _isLocked;
  String get revocationReason => _revocationReason;

  void lockDevice(String reason) {
    _isLocked = true;
    _revocationReason = reason;
  }

  void assertOperational() {
    if (_isLocked) {
      throw StateError(
        'ERR_DEVICE_REVOKED: This device has been revoked by administration. Action blocked.',
      );
    }
  }

  Map<String, dynamic> packUnsyncedEvidence({
    required String deviceId,
    required List<Map<String, dynamic>> unsyncedCommands,
  }) {
    return {
      'device_id': deviceId,
      'unsynced_command_count': unsyncedCommands.length,
      'commands': unsyncedCommands,
      'quarantined_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  String getSecurityLockdownMessage() {
    return 'DEVICE REVOKED: Terminal locked due to compromise or retirement.';
  }
}
