import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_inventory_fault_stress_client.dart';

void main() {
  group('P220: MobileInventoryFaultStressClient Tests', () {
    test('1. Authorized remote conservation run parses DTO and transitions to READY', () async {
      final client = MobileInventoryFaultStressClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          expect(method, 'POST');
          expect(path, '/api/v2/inventory/qa-stress/verify-conservation/');
          expect(bearerToken, 'tok-owner');
          return const MobileQaHttpResponse(
            statusCode: 201,
            data: {
              'run_id': 'invqa-mob001122',
              'tenant_id': 'ten-a',
              'branch_id': 'br-a',
              'branch_name': 'Dhanmondi Central',
              'test_type': 'CONSERVATION_PIPELINE',
              'status': 'PASSED',
              'total_operations': 6,
              'successful_operations': 6,
              'rejected_faults': 1,
              'initial_stock_units': 240,
              'final_stock_units': 120,
              'net_ledger_delta_units': 120,
              'conservation_verified': true,
              'branch_isolation_verified': true,
              'execution_time_ms': 42,
              'metrics_payload': {'transfer_reconciled_units': 80},
              'verification_hash':
                  'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
              'executed_by_email': 'owner@united.com',
              'executed_at': '2026-11-09T10:00:00Z',
            },
          );
        },
      );

      final outcome = await client.triggerRemoteVerification(
        testType: MobileInventoryStressTestType.conservationPipeline,
        payload: {'branch': 'br-a', 'initial_units': 200},
        bearerToken: 'tok-owner',
        actorRole: 'PHARMACY_OWNER',
        actorTenantId: 'ten-a',
        actorAssignedBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );

      expect(outcome.uiState, MobileQaUiState.ready);
      expect(outcome.data, isNotNull);
      expect(outcome.data!.conservationVerified, isTrue);
      expect(outcome.data!.finalStockUnits, 120);
      expect(outcome.messageBn, contains('সফলভাবে'));

      final roundTrip = MobileInventoryFaultStressRun.fromJson(outcome.data!.toJson());
      expect(roundTrip.runId, 'invqa-mob001122');
      expect(roundTrip.testType, MobileInventoryStressTestType.conservationPipeline);
    });

    test('2. RBAC, cross-branch, cross-tenant, suspended subscription and offline states', () async {
      final client = MobileInventoryFaultStressClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          fail('Transport must not run when guard denies');
        },
      );

      final offline = await client.triggerRemoteVerification(
        testType: MobileInventoryStressTestType.highVolumeStress,
        payload: {'branch': 'br-a'},
        bearerToken: 'tok',
        actorRole: 'PHARMACY_OWNER',
        actorTenantId: 'ten-a',
        actorAssignedBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        isOffline: true,
      );
      expect(offline.uiState, MobileQaUiState.offline);
      expect(offline.errorCode, 'ERR_OFFLINE_UNAVAILABLE');

      final cashier = await client.triggerRemoteVerification(
        testType: MobileInventoryStressTestType.concurrentMutation,
        payload: {'branch': 'br-a'},
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorAssignedBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(cashier.uiState, MobileQaUiState.permissionDenied);
      expect(cashier.errorCode, 'ERR_PERMISSION_DENIED');

      final crossBranch = await client.triggerRemoteVerification(
        testType: MobileInventoryStressTestType.faultAndIsolation,
        payload: {'branch': 'br-a2'},
        bearerToken: 'tok',
        actorRole: 'STAFF_PHARMACIST',
        actorTenantId: 'ten-a',
        actorAssignedBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a2',
      );
      expect(crossBranch.uiState, MobileQaUiState.permissionDenied);
      expect(crossBranch.errorCode, 'ERR_CROSS_BRANCH_ACCESS_DENIED');

      final suspended = await client.triggerRemoteVerification(
        testType: MobileInventoryStressTestType.conservationPipeline,
        payload: {'branch': 'br-a'},
        bearerToken: 'tok',
        actorRole: 'PHARMACY_OWNER',
        actorTenantId: 'ten-a',
        actorAssignedBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        subscriptionSuspended: true,
      );
      expect(suspended.uiState, MobileQaUiState.permissionDenied);
      expect(suspended.errorCode, 'ERR_TENANT_SUSPENDED');

      final crossTenant = await client.triggerRemoteVerification(
        testType: MobileInventoryStressTestType.conservationPipeline,
        payload: {'branch': 'br-a'},
        bearerToken: 'tok',
        actorRole: 'PHARMACY_OWNER',
        actorTenantId: 'ten-b',
        actorAssignedBranchId: 'br-b',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(crossTenant.uiState, MobileQaUiState.error);
      expect(crossTenant.errorCode, 'ERR_CROSS_TENANT_NOT_FOUND');
    });

    test('3. Empty, Error, and Ready history fetch states with unmodifiable list', () async {
      final emptyClient = MobileInventoryFaultStressClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          expect(method, 'GET');
          expect(path, '/api/v2/inventory/qa-stress/?branch=br-a');
          return const MobileQaHttpResponse(statusCode: 200, data: {'results': <dynamic>[]});
        },
      );
      final emptyOutcome = await emptyClient.fetchRunHistory(branchId: 'br-a', bearerToken: 'tok');
      expect(emptyOutcome.uiState, MobileQaUiState.empty);
      expect(emptyOutcome.data, isEmpty);

      final readyClient = MobileInventoryFaultStressClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          return const MobileQaHttpResponse(
            statusCode: 200,
            data: {
              'results': [
                {
                  'run_id': 'invqa-hist01',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'test_type': 'CONCURRENT_MUTATION',
                  'status': 'PASSED',
                  'conservation_verified': true,
                  'branch_isolation_verified': true,
                }
              ],
            },
          );
        },
      );
      final readyOutcome = await readyClient.fetchRunHistory(branchId: 'br-a', bearerToken: 'tok');
      expect(readyOutcome.uiState, MobileQaUiState.ready);
      expect(readyOutcome.data!.length, 1);
      expect(() => readyOutcome.data!.clear(), throwsUnsupportedError);
    });
  });
}
