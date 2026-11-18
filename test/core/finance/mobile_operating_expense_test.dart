// mobile_operating_expense_test.dart
// Architecture Decision: ADR-0287 (P287) & ADR-0289 (P289).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_operating_expense_client.dart';

void main() {
  group('MobileOperatingExpenseClient P287 & P289 Unit Tests', () {
    const tenantId = 'ten_square_01';
    const branchId = 'br_dhanmondi_01';

    test('1. Branch Manager creates operating expense draft for shop rent with receipt URL', () {
      final client = MobileOperatingExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr_mgr_01',
      );

      final exp = client.createDraft(
        categoryId: 'EXPCAT-RENT',
        categoryName: 'Branch Rent / Shop Lease',
        categoryCode: 'RENT',
        payeeName: 'Al-Haj Abdul Latif (Landlord)',
        payeePhone: '+8801711223344',
        amountBdt: 35000.0,
        paymentMethod: 'BANK_TRANSFER',
        paymentReference: 'CHEQUE-998822',
        receiptFileUrl: 'https://storage.pharma.bd/receipts/rent_nov2026.pdf',
        notes: 'Monthly advance rent for Dhanmondi premises',
        taxDeductible: true,
      );

      expect(exp.status, equals('DRAFT'));
      expect(exp.amountBdt, equals(35000.0));
      expect(exp.payeeName, contains('Landlord'));
      expect(exp.voucherNumber, startsWith('EXP-'));
      expect(exp.paymentMethod, equals('BANK_TRANSFER'));
      expect(exp.receiptFileUrl, contains('rent_nov2026.pdf'));
    });

    test('2. Pharmacy Owner approves expense draft and posts general ledger journal', () {
      final mgrClient = MobileOperatingExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr_mgr_01',
      );

      final draft = mgrClient.createDraft(
        categoryId: 'EXPCAT-UTIL',
        categoryName: 'Electricity & Utilities',
        categoryCode: 'UTILITIES',
        payeeName: 'DESCO Ltd',
        amountBdt: 12500.0,
        paymentMethod: 'BKASH',
        paymentReference: 'BK-TRX-8822001',
      );

      final ownerClient = MobileOperatingExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final approved = ownerClient.approveExpense(
        draft.expenseId,
        approvalNotes: 'Verified DESCO electricity meter bill and bKash transaction receipt.',
      );

      expect(approved.status, equals('APPROVED'));
      expect(approved.approvedBy, equals('usr_owner_01'));
      expect(approved.postedJournalNumber, startsWith('JRN-'));
      expect(approved.approvalNotes, contains('Verified DESCO'));
    });

    test('3. Reimbursable expense creation, owner approval, and payout settlement', () {
      final staffClient = MobileOperatingExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr_staff_01',
      );

      final claim = staffClient.createDraft(
        categoryId: 'EXPCAT-MISC',
        categoryName: 'Shop Maintenance Supplies',
        categoryCode: 'MISC',
        payeeName: 'New Hardware Store',
        amountBdt: 1850.0,
        isReimbursable: true,
        claimantName: 'Kamal Hossain (Branch Staff)',
      );

      expect(claim.isReimbursable, isTrue);
      expect(claim.reimbursementStatus, equals('PENDING_REVIEW'));

      final ownerClient = MobileOperatingExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final approved = ownerClient.approveExpense(claim.expenseId);
      expect(approved.status, equals('APPROVED'));
      expect(approved.reimbursementStatus, equals('APPROVED_PENDING_PAYOUT'));

      final paid = ownerClient.reimburseExpense(
        claim.expenseId,
        payoutMethod: 'BKASH',
        reference: 'BK-TRX-REIMB-9988',
      );
      expect(paid.reimbursementStatus, equals('PAID_OUT'));
      expect(paid.reimbursementReference, equals('BK-TRX-REIMB-9988'));
      expect(paid.reimbursementPaymentMethod, equals('BKASH'));
    });

    test('4. High-value expense approval strictly requires Owner/Finance Officer sign-off', () {
      final mgrClient = MobileOperatingExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr_mgr_01',
      );

      final draft = mgrClient.createDraft(
        categoryId: 'EXPCAT-MAINT',
        categoryName: 'HVAC Aircon Servicing',
        categoryCode: 'MAINTENANCE',
        payeeName: 'Carrier AC Techs',
        amountBdt: 8500.0, // >= 5000 high value
      );

      // Branch Manager cannot approve high-value expense alone
      expect(
        () => mgrClient.approveExpense(draft.expenseId),
        throwsA(isA<OperatingExpensePermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_HIGH_VALUE_APPROVAL_REQUIRED'),
        )),
      );

      // Finance Officer can approve high-value expense
      final finClient = MobileOperatingExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr_fin_01',
      );
      final approved = finClient.approveExpense(draft.expenseId);
      expect(approved.status, equals('APPROVED'));
    });

    test('5. Self-approval of reimbursable expense by claimant is forbidden', () {
      final mgrClient = MobileOperatingExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr_fin_claimant',
      );

      final claim = mgrClient.createDraft(
        categoryId: 'EXPCAT-TRANS',
        categoryName: 'Urgent Medicine Courier',
        categoryCode: 'TRANSPORT',
        payeeName: 'Sundarban Courier',
        amountBdt: 800.0,
        isReimbursable: true,
      );

      // Self approval rejected
      expect(
        () => mgrClient.approveExpense(claim.expenseId),
        throwsA(isA<OperatingExpensePermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_SELF_APPROVAL_FORBIDDEN'),
        )),
      );
    });

    test('6. Audited full reversal of posted expense updates status to REVERSED', () {
      final ownerClient = MobileOperatingExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final draft = ownerClient.createDraft(
        categoryId: 'EXPCAT-MISC',
        categoryName: 'Erroneous Charge',
        categoryCode: 'MISC',
        payeeName: 'Erroneous Vendor',
        amountBdt: 2200.0,
      );

      ownerClient.approveExpense(draft.expenseId);

      final reversed = ownerClient.correctExpense(
        draft.expenseId,
        correctionType: 'FULL_REVERSAL',
        reason: 'Duplicate bill entered by mistake; voiding voucher',
      );

      expect(reversed.status, equals('REVERSED'));
      expect(reversed.notes, contains('Duplicate bill entered by mistake'));
    });

    test('7. Cashier is strictly denied from creating or approving expenses', () {
      final cashierClient = MobileOperatingExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr_cashier_01',
      );

      expect(
        () => cashierClient.createDraft(
          categoryId: 'EXPCAT-RENT',
          categoryName: 'Rent',
          categoryCode: 'RENT',
          payeeName: 'Landlord',
          amountBdt: 1000.0,
        ),
        throwsA(isA<OperatingExpensePermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_EXPENSE_CREATE_UNAUTHORIZED'),
        )),
      );

      expect(
        () => cashierClient.approveExpense('fake-id'),
        throwsA(isA<OperatingExpensePermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_EXPENSE_APPROVE_UNAUTHORIZED'),
        )),
      );
    });
  });
}
