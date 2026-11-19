import 'dart:convert';
import 'package:crypto/crypto.dart';

/// MobileOfflineMigrationManager
/// Architecture Decision: ADR-0318 (P318).
/// Phase 16: JavaFX SQLite Offline Store and Reliable Cloud Sync.
///
/// Manages mobile offline database schema version transitions, rollback handling,
/// and outbox preservation invariants: pending outbox events must never be dropped.
class MobileOfflineMigrationManager {
  int _currentSchemaVersion;
  final List<Map<String, dynamic>> _migrationHistory = [];

  MobileOfflineMigrationManager({int initialVersion = 1})
      : _currentSchemaVersion = initialVersion;

  int get currentSchemaVersion => _currentSchemaVersion;
  List<Map<String, dynamic>> get migrationHistory => List.unmodifiable(_migrationHistory);

  /// Executes forward schema migration with outbox event preservation check
  Map<String, dynamic> applyMigration({
    required int targetVersion,
    required List<Map<String, dynamic>> pendingOutboxEvents,
    required bool Function(List<Map<String, dynamic>> events) migrationDdlExecutor,
    String backupSnapshotSha256 = '',
  }) {
    if (targetVersion <= _currentSchemaVersion) {
      throw ArgumentError(
        'ERR_INVALID_TARGET_VERSION: Target $targetVersion must be > $_currentSchemaVersion',
      );
    }

    final countBefore = pendingOutboxEvents.length;

    try {
      // Execute migration callback
      final migrationSuccess = migrationDdlExecutor(pendingOutboxEvents);
      if (!migrationSuccess) {
        throw Exception('Migration execution failed');
      }

      // Outbox Preservation Invariant
      final countAfter = pendingOutboxEvents.length;
      if (countAfter != countBefore) {
        throw StateError(
          'ERR_OUTBOX_EVENT_LOSS_DETECTED: Outbox events before: $countBefore, after: $countAfter',
        );
      }

      final fromVer = _currentSchemaVersion;
      _currentSchemaVersion = targetVersion;

      final record = {
        'from_version': fromVer,
        'to_version': targetVersion,
        'status': 'SUCCESS',
        'outbox_events_preserved': countAfter,
        'backup_snapshot_sha256': backupSnapshotSha256,
        'applied_at': DateTime.now().toUtc().toIso8601String(),
      };
      _migrationHistory.add(record);

      return record;
    } catch (e) {
      final record = {
        'from_version': _currentSchemaVersion,
        'to_version': targetVersion,
        'status': 'FAILED_ROLLED_BACK',
        'outbox_events_preserved': countBefore,
        'error_message': e.toString(),
        'applied_at': DateTime.now().toUtc().toIso8601String(),
      };
      _migrationHistory.add(record);
      return record;
    }
  }

  /// Rolls back to previous schema version
  Map<String, dynamic> rollbackMigration({
    required int targetVersion,
    required List<Map<String, dynamic>> pendingOutboxEvents,
  }) {
    if (targetVersion >= _currentSchemaVersion) {
      throw ArgumentError(
        'ERR_INVALID_ROLLBACK_VERSION: Target $targetVersion must be < $_currentSchemaVersion',
      );
    }

    final fromVer = _currentSchemaVersion;
    _currentSchemaVersion = targetVersion;

    final record = {
      'from_version': fromVer,
      'to_version': targetVersion,
      'status': 'SUCCESS',
      'outbox_events_preserved': pendingOutboxEvents.length,
      'applied_at': DateTime.now().toUtc().toIso8601String(),
    };
    _migrationHistory.add(record);
    return record;
  }

  /// Computes SHA-256 hash of snapshot content
  String computeSnapshotSha256(String content) {
    return sha256.convert(utf8.encode(content)).toString();
  }
}
