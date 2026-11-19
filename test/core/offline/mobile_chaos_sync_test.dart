import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_chaos_sync_harness.dart';

void main() {
  group('P320 MobileChaosSyncHarness Tests', () {
    late MobileChaosSyncHarness harness;

    setUp(() {
      harness = MobileChaosSyncHarness();
    });

    test('Drill 1: Crash before commit triggers clean rollback', () {
      expect(harness.runCrashRollbackDrill(simulatedCrashBeforeCommit: true), true);
    });

    test('Drill 2: Network partition transitions outbox to RETRY_SCHEDULED', () {
      final cmd = {'command_id': 'CMD-1', 'sync_state': 'SAVED_LOCALLY', 'retry_count': 0};
      final partitioned = harness.runNetworkPartitionDrill(cmd);

      expect(partitioned['sync_state'], 'RETRY_SCHEDULED');
      expect(partitioned['retry_count'], 1);
    });

    test('Drill 3: Duplicate push blocked by idempotency tracker', () {
      expect(harness.runDuplicatePushDrill('idem-101'), true); // First time
      expect(harness.runDuplicatePushDrill('idem-101'), false); // Duplicate rejected
    });

    test('Drill 4: Lost ACK reconciled to SYNCED upon server ACK receipt', () {
      final cmd = {'command_id': 'CMD-1', 'sync_state': 'RETRY_SCHEDULED'};
      final synced = harness.runLostAckReconciliationDrill(cmd, 'ACK-CLOUD-99');

      expect(synced['sync_state'], 'SYNCED');
      expect(synced['server_ack_id'], 'ACK-CLOUD-99');
    });

    test('Drill 5: Two offline counters stock conflict quarantined', () {
      harness.runTwoDeviceStockConflictDrill(
        conflictId: 'CONF-1',
        commandId: 'CMD-1',
        reason: 'CONFLICT_STALE_STOCK',
      );

      expect(harness.quarantinedConflicts.length, 1);
      expect(harness.quarantinedConflicts.first['conflict_id'], 'CONF-1');
    });

    test('Drill 6: Expired lease correctly detected and blocked', () {
      final past = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      expect(harness.runLeaseExpiryDrill(past), true);

      final future = DateTime.now().toUtc().add(const Duration(hours: 1));
      expect(harness.runLeaseExpiryDrill(future), false);
    });
  });
}
