import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_offline_migration_manager.dart';

void main() {
  group('P318 MobileOfflineMigrationManager Tests', () {
    late MobileOfflineMigrationManager manager;

    setUp(() {
      manager = MobileOfflineMigrationManager(initialVersion: 1);
    });

    test('Applies migration v1 -> v2 successfully and preserves outbox events', () {
      final outbox = [
        {'command_id': 'CMD-1', 'type': 'SALE'},
        {'command_id': 'CMD-2', 'type': 'RETURN'},
      ];

      final res = manager.applyMigration(
        targetVersion: 2,
        pendingOutboxEvents: outbox,
        migrationDdlExecutor: (events) => true,
        backupSnapshotSha256: 'mock-sha256',
      );

      expect(res['status'], 'SUCCESS');
      expect(res['to_version'], 2);
      expect(res['outbox_events_preserved'], 2);
      expect(manager.currentSchemaVersion, 2);
      expect(manager.migrationHistory.length, 1);
    });

    test('Detects outbox event loss and triggers rollback status', () {
      final outbox = [
        {'command_id': 'CMD-1', 'type': 'SALE'},
      ];

      final res = manager.applyMigration(
        targetVersion: 2,
        pendingOutboxEvents: outbox,
        migrationDdlExecutor: (events) {
          events.clear(); // Maliciously drop events
          return true;
        },
      );

      expect(res['status'], 'FAILED_ROLLED_BACK');
      expect(res['error_message'].toString().contains('ERR_OUTBOX_EVENT_LOSS_DETECTED'), true);
      expect(manager.currentSchemaVersion, 1); // Version remained at 1
    });

    test('Rolls back version cleanly', () {
      final outbox = [{'command_id': 'CMD-1'}];
      manager.applyMigration(
        targetVersion: 2,
        pendingOutboxEvents: outbox,
        migrationDdlExecutor: (events) => true,
      );
      expect(manager.currentSchemaVersion, 2);

      final rollRes = manager.rollbackMigration(
        targetVersion: 1,
        pendingOutboxEvents: outbox,
      );

      expect(rollRes['status'], 'SUCCESS');
      expect(rollRes['to_version'], 1);
      expect(manager.currentSchemaVersion, 1);
    });

    test('Computes valid SHA-256 for snapshot', () {
      final hash = manager.computeSnapshotSha256('snapshot-content');
      expect(hash.length, 64);
    });
  });
}
