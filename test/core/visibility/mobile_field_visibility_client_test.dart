import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/visibility/mobile_field_visibility_client.dart';

void main() {
  group('P110: MobileFieldVisibilityClient Tests', () {
    test('P110: Pharmacy Owner has all 5 visibility permissions active', () {
      final profile = MobileFieldVisibilityClient.resolveProfile(
        userId: 'usr-owner-01',
        tenantId: 'tn-popular',
        role: 'PHARMACY_OWNER',
      );

      expect(profile.costVisibility, isTrue);
      expect(profile.profitVisibility, isTrue);
      expect(profile.salaryVisibility, isTrue);
      expect(profile.prescriptionVisibility, isTrue);
      expect(profile.patientPiiVisibility, isTrue);

      final med = MobileFieldVisibilityClient.maskMedicine(
        productId: 'm-1',
        brandName: 'Napa',
        mrpUnit: 1.20,
        costUnit: 0.85,
        profile: profile,
      );
      expect(med.isCostMasked, isFalse);
      expect(med.costUnit, 0.85);
      expect(med.getDisplayCost(), '৳0.85');
    });

    test('P110: Cashier has costs, profits, salaries, prescriptions and PII masked', () {
      final profile = MobileFieldVisibilityClient.resolveProfile(
        userId: 'usr-cashier-01',
        tenantId: 'tn-popular',
        role: 'CASHIER',
      );

      expect(profile.costVisibility, isFalse);
      expect(profile.profitVisibility, isFalse);
      expect(profile.salaryVisibility, isFalse);
      expect(profile.prescriptionVisibility, isFalse);
      expect(profile.patientPiiVisibility, isFalse);

      // 1. Medicine Cost Masked
      final med = MobileFieldVisibilityClient.maskMedicine(
        productId: 'm-2',
        brandName: 'Ace Plus',
        mrpUnit: 2.50,
        costUnit: 1.75,
        profile: profile,
      );
      expect(med.isCostMasked, isTrue);
      expect(med.costUnit, isNull);
      expect(med.getDisplayCost(), '***');
      expect(med.getCostBadge('bn'), 'ক্রয়মূল্য সংরক্ষিত');

      // 2. Invoice Profit & PII Masked
      final inv = MobileFieldVisibilityClient.maskInvoice(
        invoiceId: 'inv-01',
        customerName: 'Kamal Hossain',
        customerPhone: '01712345678',
        totalAmount: 300.0,
        cogsAmount: 200.0,
        grossProfit: 100.0,
        profile: profile,
      );
      expect(inv.isCostMasked, isTrue);
      expect(inv.isProfitMasked, isTrue);
      expect(inv.isPiiMasked, isTrue);
      expect(inv.grossProfit, isNull);
      expect(inv.customerPhone, '017****5678');
      expect(inv.customerName, 'K**** H****');

      // 3. Salary Masked
      final sal = MobileFieldVisibilityClient.maskSalary(
        salaryId: 'sal-01',
        staffUserId: 'usr-cashier-01',
        username: 'cashier1',
        baseSalaryBdt: 25000.0,
        bankAccountNo: '1234567890',
        profile: profile,
      );
      expect(sal.isSalaryMasked, isTrue);
      expect(sal.baseSalaryBdt, isNull);
      expect(sal.bankAccountNo, '***REDACTED***');
      expect(sal.getDisplaySalary(), '***REDACTED***');

      // 4. Prescription Clinical Notes Masked
      final rx = MobileFieldVisibilityClient.maskPrescription(
        prescriptionId: 'rx-01',
        doctorName: 'Dr. Kabir',
        diagnosis: 'Typhoid Fever',
        notes: 'Ciprofloxacin 500mg BD',
        prescriptionImageUrl: 'https://cdn.example.com/rx/1.jpg',
        profile: profile,
      );
      expect(rx.isPrescriptionMasked, isTrue);
      expect(rx.diagnosis, '[CLINICAL_DIAGNOSIS_REDACTED]');
      expect(rx.notes, '[CONFIDENTIAL_CLINICAL_NOTES]');
      expect(rx.prescriptionImageUrl, isNull);
    });

    test('P110: Branch Manager sees costs and prescriptions, profits and salaries masked', () {
      final profile = MobileFieldVisibilityClient.resolveProfile(
        userId: 'usr-mgr-01',
        tenantId: 'tn-popular',
        role: 'BRANCH_MANAGER',
      );

      expect(profile.costVisibility, isTrue);
      expect(profile.profitVisibility, isFalse);
      expect(profile.salaryVisibility, isFalse);
      expect(profile.prescriptionVisibility, isTrue);
      expect(profile.patientPiiVisibility, isTrue);

      final inv = MobileFieldVisibilityClient.maskInvoice(
        invoiceId: 'inv-02',
        customerName: 'Anwar Sadat',
        customerPhone: '01899887766',
        totalAmount: 1200.0,
        cogsAmount: 900.0,
        grossProfit: 300.0,
        profile: profile,
      );
      expect(inv.isCostMasked, isFalse);
      expect(inv.cogsAmount, 900.0);
      expect(inv.isProfitMasked, isTrue);
      expect(inv.grossProfit, isNull);
      expect(inv.isPiiMasked, isFalse);
      expect(inv.customerPhone, '01899887766');
    });

    test('P110: Custom Role granting salary_visibility allows salary inspection', () {
      final profile = MobileFieldVisibilityClient.resolveProfile(
        userId: 'usr-custom-hr',
        tenantId: 'tn-popular',
        role: 'HR_OFFICER',
        customKeys: ['hr:view_salary', 'staff:salary_visibility'],
      );

      expect(profile.salaryVisibility, isTrue);
      expect(profile.profitVisibility, isFalse);

      final sal = MobileFieldVisibilityClient.maskSalary(
        salaryId: 'sal-03',
        staffUserId: 'usr-stf-03',
        username: 'pharmacist1',
        baseSalaryBdt: 42000.0,
        bankAccountNo: '5566778899',
        profile: profile,
      );
      expect(sal.isSalaryMasked, isFalse);
      expect(sal.baseSalaryBdt, 42000.0);
      expect(sal.bankAccountNo, '5566778899');
    });

    test('P110: Profile JSON serialization matches schema specifications', () {
      final profile = MobileFieldVisibilityClient.resolveProfile(
        userId: 'usr-fin-01',
        tenantId: 'tn-popular',
        role: 'FINANCE_OFFICER',
      );

      final json = profile.toJson();
      expect(json['user_id'], 'usr-fin-01');
      expect(json['tenant_id'], 'tn-popular');
      expect(json['role'], 'FINANCE_OFFICER');
      final perms = json['visibility_permissions'] as Map<String, dynamic>;
      expect(perms['cost_visibility'], isTrue);
      expect(perms['profit_visibility'], isTrue);
      expect(perms['salary_visibility'], isTrue);
      expect(perms['prescription_visibility'], isFalse);
    });
  });
}
