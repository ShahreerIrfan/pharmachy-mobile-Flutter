import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_permission_matrix.dart';

void main() {
  group('ADR-0059: Mobile Permission Matrix Tests', () {
    test('Cashier has checkout permissions and read permissions', () {
      final checkoutResult = MobilePermissionMatrix.evaluateAccess(
        role: 'CASHIER',
        method: 'POST',
        path: '/api/v2/invoices/',
        userBranchId: 'branch-ctg-01',
        targetBranchId: 'branch-ctg-01',
      );
      expect(checkoutResult.isAllowed, isTrue);
      expect(checkoutResult.errorCode, isNull);

      final medicineResult = MobilePermissionMatrix.evaluateAccess(
        role: 'CASHIER',
        method: 'GET',
        path: '/api/v2/medicines/',
      );
      expect(medicineResult.isAllowed, isTrue);
    });

    test('Cashier is denied destructive deletes and admin audit logs', () {
      final deleteResult = MobilePermissionMatrix.evaluateAccess(
        role: 'CASHIER',
        method: 'DELETE',
        path: '/api/v2/branches/branch-1/',
      );
      expect(deleteResult.isAllowed, isFalse);
      expect(deleteResult.errorCode, equals('ROLE_PERMISSION_DENIED'));

      final auditResult = MobilePermissionMatrix.evaluateAccess(
        role: 'CASHIER',
        method: 'GET',
        path: '/api/v2/audit-logs/',
      );
      expect(auditResult.isAllowed, isFalse);
      expect(auditResult.errorCode, equals('ROLE_PERMISSION_DENIED'));
    });

    test('Destructive DELETE on posted invoices is an absolute system block', () {
      final blockResult = MobilePermissionMatrix.evaluateAccess(
        role: 'PHARMACY_OWNER',
        method: 'DELETE',
        path: '/api/v2/invoices/inv-001/',
      );
      expect(blockResult.isAllowed, isFalse);
      expect(blockResult.errorCode, equals('ABSOLUTE_SYSTEM_BLOCK'));
    });

    test('Cross-branch access violation is denied for branch-bound cashier', () {
      final branchMismatch = MobilePermissionMatrix.evaluateAccess(
        role: 'CASHIER',
        method: 'POST',
        path: '/api/v2/invoices/',
        userBranchId: 'branch-dhk-01',
        targetBranchId: 'branch-syl-02',
      );
      expect(branchMismatch.isAllowed, isFalse);
      expect(branchMismatch.errorCode, equals('FORBIDDEN_BRANCH_BOUNDARY'));
    });

    test('Field masking protects purchase cost price and customer phone', () {
      const rawCost = '340.00';
      final maskedCost = MobilePermissionMatrix.maskFieldValue('cost_price', rawCost, 'CASHIER');
      expect(maskedCost, equals('***REDACTED***'));

      final visibleCost = MobilePermissionMatrix.maskFieldValue('cost_price', rawCost, 'PHARMACY_OWNER');
      expect(visibleCost, equals(rawCost));

      const rawPhone = '+8801812345678';
      final maskedPhone = MobilePermissionMatrix.maskFieldValue('customer_phone', rawPhone, 'CASHIER');
      expect(maskedPhone, equals('+88018****5678'));

      final visiblePhone = MobilePermissionMatrix.maskFieldValue('customer_phone', rawPhone, 'PHARMACY_OWNER');
      expect(visiblePhone, equals(rawPhone));
    });
  });
}
