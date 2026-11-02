// test/core/catalog/mobile_dosage_form_client_test.dart
// Unit tests for P122 Dosage Form Registry mobile client.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_dosage_form_client.dart';

void main() {
  group('MobileDosageFormClient Tests', () {
    late MobileDosageFormClient client;
    late List<MobileDosageFormRecord> sampleForms;

    setUp(() {
      client = MobileDosageFormClient();
      sampleForms = [
        const MobileDosageFormRecord(
          formId: 'df-tablet',
          formCode: 'TABLET',
          nameEn: 'Tablet',
          nameBn: 'ট্যাবলেট',
          category: 'SOLID',
          defaultRoute: 'Oral',
          booleanIsStripApplicable: true,
          displayOrder: 10,
        ),
        const MobileDosageFormRecord(
          formId: 'df-syrup',
          formCode: 'SYRUP',
          nameEn: 'Syrup',
          nameBn: 'সিরাপ',
          category: 'LIQUID',
          defaultRoute: 'Oral',
          booleanIsStripApplicable: false,
          isVolumeApplicable: true,
          displayOrder: 20,
        ),
        const MobileDosageFormRecord(
          formId: 'df-injection',
          formCode: 'INJECTION',
          nameEn: 'Injection',
          nameBn: 'ইনজেকশন',
          category: 'INJECTABLE',
          defaultRoute: 'Intravenous',
          booleanIsStripApplicable: false,
          isVolumeApplicable: true,
          isColdChainApplicable: true,
          displayOrder: 30,
        ),
      ];
    });

    test('Filter by strip applicability (Tablet only)', () {
      final res = client.filterForms(
        forms: sampleForms,
        stripApplicableOnly: true,
      );

      expect(res.uiStatus, MobileDosageFormUiStatus.success);
      expect(res.forms.length, 1);
      expect(res.forms.first.formCode, 'TABLET');
    });

    test('Filter by category LIQUID', () {
      final res = client.filterForms(
        forms: sampleForms,
        category: 'LIQUID',
      );

      expect(res.uiStatus, MobileDosageFormUiStatus.success);
      expect(res.forms.length, 1);
      expect(res.forms.first.formCode, 'SYRUP');
    });

    test('Maintains display order sorting', () {
      final res = client.filterForms(forms: sampleForms);
      expect(res.uiStatus, MobileDosageFormUiStatus.success);
      expect(res.forms.length, 3);
      expect(res.forms[0].displayOrder, 10);
      expect(res.forms[2].displayOrder, 30);
    });

    test('Tenant manager cannot create dosage forms', () {
      final res = client.attemptCreateForm(
        callerRole: 'BRANCH_MANAGER',
        form: sampleForms.first,
      );

      expect(res.uiStatus, MobileDosageFormUiStatus.permissionDenied);
      expect(res.errorCode, 'PLATFORM_CATALOG_OWNERSHIP_PROTECTED');
    });

    test('Platform Superadmin operator can create dosage forms', () {
      final res = client.attemptCreateForm(
        callerRole: 'SUPERADMIN',
        form: sampleForms.first,
      );

      expect(res.uiStatus, MobileDosageFormUiStatus.success);
      expect(res.forms.length, 1);
    });
  });
}
