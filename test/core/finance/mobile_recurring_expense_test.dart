// mobile_recurring_expense_test.dart
// Architecture Decision: ADR-0288 (P288).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_recurring_expense_client.dart';

void main() {
  group('MobileRecurringExpenseClient P288 Unit Tests', () {
    const tenantId = 'ten_square_01';
    const branchId = 'br_dhanmondi_01';

    test('1. Pharmacy Owner creates monthly rent recurring template', () {
      final client = MobileRecurringExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final tpl = client.createTemplate(
        templateName: 'Dhanmondi Retail Store Rent',
        categoryId: 'EXPCAT-RENT',
        categoryName: 'Branch Rent / Shop Lease',
        payeeName: 'Abdul Latif (Landlord)',
        estimatedAmountBdt: 35000.0,
        frequency: 'MONTHLY',
        dayOfMonth: 1,
        paymentMethod: 'BANK_TRANSFER',
        autoApprove: false,
        description: 'Advance rent due on 1st of every month',
      );

      expect(tpl.templateName, equals('Dhanmondi Retail Store Rent'));
      expect(tpl.estimatedAmountBdt, equals(35000.0));
      expect(tpl.frequency, equals('MONTHLY'));
      expect(tpl.autoApprove, isFalse);
      expect(tpl.isActive, isTrue);
    });

    test('2. Finance Officer creates broadband internet recurring template with auto-approve', () {
      final client = MobileRecurringExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr_fin_01',
      );

      final tpl = client.createTemplate(
        templateName: 'AmberIT Optical Fiber Broadband',
        categoryId: 'EXPCAT-INT',
        categoryName: 'Internet & Software',
        payeeName: 'AmberIT Ltd',
        estimatedAmountBdt: 3500.0,
        frequency: 'MONTHLY',
        dayOfMonth: 5,
        paymentMethod: 'BKASH',
        autoApprove: true,
      );

      expect(tpl.autoApprove, isTrue);
      expect(tpl.paymentMethod, equals('BKASH'));
      expect(tpl.dayOfMonth, equals(5));
    });

    test('3. On-demand trigger generation produces new expense voucher', () {
      final client = MobileRecurringExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final tpl = client.createTemplate(
        templateName: 'Night Security Guard Services',
        categoryId: 'EXPCAT-SEC',
        categoryName: 'Security',
        payeeName: 'Elite Force Security',
        estimatedAmountBdt: 15000.0,
      );

      final gen = client.triggerGeneration(tpl.templateId);
      expect(gen['status'], equals('SUCCESS'));
      expect(gen['voucher_number'], startsWith('EXP-REC-'));
      expect(gen['amount_bdt'], equals(15000.0));
    });

    test('4. Archiving recurring template marks is_active = false', () {
      final client = MobileRecurringExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final tpl = client.createTemplate(
        templateName: 'Old Temporary Maintenance',
        categoryId: 'EXPCAT-MAINT',
        categoryName: 'Maintenance',
        payeeName: 'Contractor',
        estimatedAmountBdt: 4000.0,
      );

      final archived = client.archiveTemplate(tpl.templateId);
      expect(archived.isActive, isFalse);

      final activeList = client.listTemplates(isActive: true);
      expect(activeList.any((t) => t.templateId == tpl.templateId), isFalse);
    });

    test('5. Duplicate template name throws ERR_DUPLICATE_TEMPLATE_NAME', () {
      final client = MobileRecurringExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      client.createTemplate(
        templateName: 'Generator Monthly Diesel Fuel',
        categoryId: 'EXPCAT-UTIL',
        categoryName: 'Utilities',
        payeeName: 'Padma Oil Depot',
        estimatedAmountBdt: 8000.0,
      );

      expect(
        () => client.createTemplate(
          templateName: 'Generator Monthly Diesel Fuel',
          categoryId: 'EXPCAT-UTIL',
          categoryName: 'Utilities',
          payeeName: 'Padma Oil Depot',
          estimatedAmountBdt: 9000.0,
        ),
        throwsA(isA<RecurringExpenseValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_DUPLICATE_TEMPLATE_NAME'),
        )),
      );
    });

    test('6. Cashier is strictly denied from viewing or managing recurring expenses', () {
      final client = MobileRecurringExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr_cashier_01',
      );

      expect(
        () => client.listTemplates(),
        throwsA(isA<RecurringExpensePermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );

      expect(
        () => client.createTemplate(
          templateName: 'Cashier Unauthorized Schedule',
          categoryId: 'EXPCAT-RENT',
          categoryName: 'Rent',
          payeeName: 'Cashier Payee',
          estimatedAmountBdt: 1000.0,
        ),
        throwsA(isA<RecurringExpensePermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_RECURRING_MANAGE_UNAUTHORIZED'),
        )),
      );
    });
  });
}
