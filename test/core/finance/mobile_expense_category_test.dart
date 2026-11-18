// mobile_expense_category_test.dart
// Architecture Decision: ADR-0286 (P286).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_expense_category_client.dart';

void main() {
  group('MobileExpenseCategoryClient P286 Unit Tests', () {
    const tenantId = 'ten_popular_01';
    const branchId = 'br_dhanmondi_01';

    test('1. Pharmacy Owner seeds standard default operating expense categories', () {
      final client = MobileExpenseCategoryClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final seeded = client.seedDefaultCategories();
      expect(seeded.length, equals(7));

      final codes = seeded.map((c) => c.code).toSet();
      expect(codes, containsAll(['RENT', 'UTILITIES', 'SALARIES', 'TRANSPORT', 'INTERNET', 'MAINTENANCE', 'MISC']));
    });

    test('2. Finance Officer creates custom marketing expense category with budget', () {
      final client = MobileExpenseCategoryClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr_fin_01',
      );

      final cat = client.createCategory(
        name: 'Flyers & Social Media Advertising',
        nameBn: 'প্রচার ও বিজ্ঞাপন খরচ',
        code: 'MARKETING',
        defaultGlCode: '6060',
        monthlyBudgetBdt: 7500.0,
        taxDeductible: true,
        description: 'Leaflets, social media ads, and pharmacy signage',
      );

      expect(cat.code, equals('MARKETING'));
      expect(cat.monthlyBudgetBdt, equals(7500.0));
      expect(cat.taxDeductible, isTrue);
      expect(cat.isActive, isTrue);
    });

    test('3. Owner updates existing expense category budget and description', () {
      final client = MobileExpenseCategoryClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final cat = client.createCategory(
        name: 'Generator Fuel & Lubricants',
        code: 'GEN_FUEL',
        monthlyBudgetBdt: 8000.0,
      );

      final updated = client.updateCategory(
        categoryId: cat.categoryId,
        monthlyBudgetBdt: 12000.0,
        description: 'Increased budget due to load shedding in summer',
      );

      expect(updated.monthlyBudgetBdt, equals(12000.0));
      expect(updated.description, contains('load shedding'));
    });

    test('4. Archiving expense category marks is_active = false', () {
      final client = MobileExpenseCategoryClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final cat = client.createCategory(
        name: 'Temporary Project Office',
        code: 'TEMP_OFFICE',
        monthlyBudgetBdt: 2000.0,
      );

      final archived = client.archiveCategory(cat.categoryId);
      expect(archived.isActive, isFalse);

      final activeList = client.listCategories(isActive: true);
      expect(activeList.any((c) => c.categoryId == cat.categoryId), isFalse);
    });

    test('5. Duplicate category name throws ERR_DUPLICATE_CATEGORY_NAME', () {
      final client = MobileExpenseCategoryClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      client.createCategory(name: 'Security Guard Services', code: 'SECURITY');

      expect(
        () => client.createCategory(name: 'Security Guard Services', code: 'SEC_2'),
        throwsA(isA<ExpenseCategoryValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_DUPLICATE_CATEGORY_NAME'),
        )),
      );
    });

    test('6. Cashier is strictly denied from viewing or creating expense categories', () {
      final client = MobileExpenseCategoryClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr_cashier_01',
      );

      expect(
        () => client.listCategories(),
        throwsA(isA<ExpenseCategoryPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );

      expect(
        () => client.createCategory(name: 'Cashier Attempt', code: 'CASH_ATTEMPT'),
        throwsA(isA<ExpenseCategoryPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_EXPENSE_MANAGE_UNAUTHORIZED'),
        )),
      );
    });
  });
}
