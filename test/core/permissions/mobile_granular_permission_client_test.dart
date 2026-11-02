// test/core/permissions/mobile_granular_permission_client_test.dart
// Architecture Decision: ADR-0104
// Phase 06: Milestone M03 - Granular Action Permissions (P104)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/permissions/mobile_granular_permission_client.dart';

void main() {
  group('MobileGranularPermissionClient Tests (ADR-0104)', () {
    test('Owner and Superadmin have full action capability', () {
      final owner = MobileGranularPermissionClient.createOfflineFallback(
        userId: 'usr-owner-1',
        tenantId: 'tn-prime',
        role: 'PHARMACY_OWNER',
      );

      expect(owner.allowsSale, isTrue);
      expect(owner.allowsRefund, isTrue);
      expect(owner.allowsDiscount, isTrue);
      expect(owner.allowsCostVisibility, isTrue);
      expect(owner.allowsStockChange, isTrue);
      expect(owner.allowsPurchasing, isTrue);
      expect(owner.allowsExpenseApproval, isTrue);
      expect(owner.allowsExport, isTrue);
      expect(owner.allowsRxReview, isTrue);
    });

    test('Cashier is restricted to sale only', () {
      final cashier = MobileGranularPermissionClient.createOfflineFallback(
        userId: 'usr-cashier-1',
        tenantId: 'tn-prime',
        role: 'CASHIER',
      );

      expect(cashier.allowsSale, isTrue);
      expect(cashier.allowsRefund, isFalse);
      expect(cashier.allowsDiscount, isFalse);
      expect(cashier.allowsCostVisibility, isFalse);
      expect(cashier.allowsStockChange, isFalse);
      expect(cashier.allowsPurchasing, isFalse);
      expect(cashier.allowsExpenseApproval, isFalse);
      expect(cashier.allowsExport, isFalse);
      expect(cashier.allowsRxReview, isFalse);

      final eval = MobileGranularPermissionClient.evaluateLocalAction(
        'CASHIER',
        'refund',
      );
      expect(eval.isAllowed, isFalse);
      expect(eval.errorCode, equals('ERR_GRANULAR_PERMISSION_DENIED'));
    });

    test('Pharmacist is authorized for sale and rx_review', () {
      final pharmacist = MobileGranularPermissionClient.createOfflineFallback(
        userId: 'usr-pharm-1',
        tenantId: 'tn-prime',
        role: 'STAFF_PHARMACIST',
      );

      expect(pharmacist.allowsSale, isTrue);
      expect(pharmacist.allowsRxReview, isTrue);
      expect(pharmacist.allowsCostVisibility, isFalse);
      expect(pharmacist.allowsExpenseApproval, isFalse);
    });

    test('Branch Manager has branch isolation guard', () {
      final sameBranch = MobileGranularPermissionClient.evaluateLocalAction(
        'BRANCH_MANAGER',
        'discount',
        userBranchId: 'branch-1',
        targetBranchId: 'branch-1',
      );
      expect(sameBranch.isAllowed, isTrue);

      final crossBranch = MobileGranularPermissionClient.evaluateLocalAction(
        'BRANCH_MANAGER',
        'discount',
        userBranchId: 'branch-1',
        targetBranchId: 'branch-2',
      );
      expect(crossBranch.isAllowed, isFalse);
      expect(crossBranch.messageEn, contains('Cross-branch'));
    });

    test('Cost price masking strips wholesale fields when disabled', () {
      final medicine = {
        'product_id': 'med-101',
        'brand_name': 'Ace Plus',
        'mrp_unit': '2.50',
        'cost_unit': '1.80',
        'unit_cost_bdt': '1.80',
      };

      final masked = MobileGranularPermissionClient.maskMedicineCost(medicine, false);
      expect(masked['cost_unit'], isNull);
      expect(masked['unit_cost_bdt'], isNull);
      expect(masked['mrp_unit'], equals('2.50'));

      final unmasked = MobileGranularPermissionClient.maskMedicineCost(medicine, true);
      expect(unmasked['cost_unit'], equals('1.80'));
    });

    test('Serialization and deserialization matches contract schema', () {
      final json = {
        'user_id': 'usr-333',
        'tenant_id': 'tn-333',
        'role': 'CASHIER',
        'cost_visibility_enabled': false,
        'actions': {
          'sale': true,
          'refund': false,
          'discount': false,
          'cost_visibility': false,
          'stock_change': false,
          'purchasing': false,
          'expense_approval': false,
          'export': false,
          'rx_review': false,
        },
      };

      final state = MobileGranularPermissionState.fromJson(json);
      expect(state.userId, equals('usr-333'));
      expect(state.allowsSale, isTrue);
      expect(state.allowsRefund, isFalse);

      final serialized = state.toJson();
      expect(serialized['actions']['sale'], isTrue);
      expect(serialized['cost_visibility_enabled'], isFalse);
    });
  });
}
