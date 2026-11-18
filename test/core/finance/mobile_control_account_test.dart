// mobile_control_account_test.dart
// Architecture Decision: ADR-0285 (P285).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_control_account_client.dart';

void main() {
  group('MobileControlAccountClient P285 Unit Tests', () {
    const tenantId = 'ten_pharma_01';
    const branchId = 'br_dhanmondi_01';

    test('1. Owner reconciles balanced Customer AR control account (MATCHED)', () {
      final client = MobileControlAccountClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final run = client.reconcileControlAccount(
        controlAccountType: 'CUSTOMER_AR',
        glControlBalanceBdt: 15000.0,
        subledgerTotalBalanceBdt: 15000.0,
        partyCount: 12,
      );

      expect(run.status, equals('MATCHED'));
      expect(run.isBalanced, isTrue);
      expect(run.varianceBdt, equals(0.0));
      expect(run.glAccountCode, equals('1030'));
      expect(run.partyCount, equals(12));
    });

    test('2. Finance Officer reconciles Supplier AP with variance and flags discrepancy', () {
      final client = MobileControlAccountClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr_fin_01',
      );

      final run = client.reconcileControlAccount(
        controlAccountType: 'SUPPLIER_AP',
        glControlBalanceBdt: 50000.0,
        subledgerTotalBalanceBdt: 48500.0,
        partyCount: 5,
      );

      expect(run.status, equals('DISCREPANCY_FLAGGED'));
      expect(run.isBalanced, isFalse);
      expect(run.varianceBdt, equals(1500.0));
      expect(run.glAccountCode, equals('2010'));
    });

    test('3. Pharmacy Owner applies audited balancing adjustment to reconcile discrepancy', () {
      final client = MobileControlAccountClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final run = client.reconcileControlAccount(
        controlAccountType: 'CUSTOMER_AR',
        glControlBalanceBdt: 20000.0,
        subledgerTotalBalanceBdt: 19500.0,
        partyCount: 8,
      );

      expect(run.status, equals('DISCREPANCY_FLAGGED'));

      final adjusted = client.applyAdjustment(
        runId: run.runId,
        reason: 'Monthly closing reconciliation variance write-off',
      );

      expect(adjusted.status, equals('RECONCILED'));
      expect(adjusted.isBalanced, isTrue);
      expect(adjusted.varianceBdt, equals(0.0));
      expect(adjusted.adjustmentJournalNumber, isNotNull);
      expect(adjusted.reconciliationNotes, contains('reconciliation variance write-off'));
    });

    test('4. Live overview reports side-by-side AR and AP control accounts', () {
      final client = MobileControlAccountClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final overview = client.getOverview(
        arGl: 10000.0,
        arSub: 10000.0,
        apGl: 25000.0,
        apSub: 25000.0,
      );

      expect(overview.isFullyReconciled, isTrue);
      expect(overview.overallStatus, equals('BALANCED'));
      expect(overview.accountsReceivable['account_code'], equals('1030'));
      expect(overview.accountsPayable['account_code'], equals('2010'));
    });

    test('5. Cashier role is strictly denied from viewing or reconciling control accounts', () {
      final client = MobileControlAccountClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr_cashier_01',
      );

      expect(
        () => client.reconcileControlAccount(
          controlAccountType: 'CUSTOMER_AR',
          glControlBalanceBdt: 1000.0,
          subledgerTotalBalanceBdt: 1000.0,
        ),
        throwsA(isA<ControlAccountPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });

    test('6. Applying adjustment to already balanced run throws ERR_NO_ADJUSTMENT_NEEDED', () {
      final client = MobileControlAccountClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final run = client.reconcileControlAccount(
        controlAccountType: 'CUSTOMER_AR',
        glControlBalanceBdt: 5000.0,
        subledgerTotalBalanceBdt: 5000.0,
      );

      expect(
        () => client.applyAdjustment(
          runId: run.runId,
          reason: 'Unnecessary adjustment',
        ),
        throwsA(isA<ControlAccountValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_NO_ADJUSTMENT_NEEDED'),
        )),
      );
    });
  });
}
