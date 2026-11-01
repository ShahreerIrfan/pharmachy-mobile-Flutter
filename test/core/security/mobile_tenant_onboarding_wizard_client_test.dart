import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_tenant_onboarding_wizard_client.dart';

void main() {
  group('MobileTenantOnboardingWizardClient Tests (ADR-0079)', () {
    test('Should authorize Super Admin and Platform Operator only', () {
      expect(MobileTenantOnboardingWizardClient.isPlatformOnboardingAllowed('SUPERADMIN'), isTrue);
      expect(MobileTenantOnboardingWizardClient.isPlatformOnboardingAllowed('SUPER_ADMIN'), isTrue);
      expect(MobileTenantOnboardingWizardClient.isPlatformOnboardingAllowed('PLATFORM_OPERATOR'), isTrue);

      expect(MobileTenantOnboardingWizardClient.isPlatformOnboardingAllowed('PHARMACY_OWNER'), isFalse);
      expect(MobileTenantOnboardingWizardClient.isPlatformOnboardingAllowed('CASHIER'), isFalse);
      expect(MobileTenantOnboardingWizardClient.isPlatformOnboardingAllowed(null), isFalse);
    });

    test('Should enforce mobile boundary rule', () {
      expect(MobileTenantOnboardingWizardClient.shouldShowOnboardingInMobileApp(), isFalse);
    });

    test('Should validate subdomain and reject reserved platform keywords', () {
      expect(MobileTenantOnboardingWizardClient.isSubdomainValid('dhanmondi-rx'), isTrue);
      expect(MobileTenantOnboardingWizardClient.isSubdomainValid('banani-meds'), isTrue);

      expect(MobileTenantOnboardingWizardClient.isSubdomainValid('admin'), isFalse);
      expect(MobileTenantOnboardingWizardClient.isSubdomainValid('superadmin'), isFalse);
      expect(MobileTenantOnboardingWizardClient.isSubdomainValid('api'), isFalse);
      expect(MobileTenantOnboardingWizardClient.isSubdomainValid(''), isFalse);
      expect(MobileTenantOnboardingWizardClient.isSubdomainValid(null), isFalse);
    });

    test('Should validate DGDA drug license number and phone', () {
      expect(MobileTenantOnboardingWizardClient.isDrugLicenseValid('DGDA-DL-2026-102'), isTrue);
      expect(MobileTenantOnboardingWizardClient.isDrugLicenseValid(''), isFalse);
      expect(MobileTenantOnboardingWizardClient.isDrugLicenseValid(null), isFalse);

      expect(MobileTenantOnboardingWizardClient.isPhoneValid('+8801700000000'), isTrue); // synthetic-fixture
      expect(MobileTenantOnboardingWizardClient.isPhoneValid('01700000000'), isFalse);
      expect(MobileTenantOnboardingWizardClient.isPhoneValid(null), isFalse);
    });

    test('Should validate complete wizard payload correctly', () {
      expect(
        MobileTenantOnboardingWizardClient.validateCompletePayload(
          pharmacyName: 'Lazz Pharma Dhanmondi',
          subdomain: 'lazz-dhanmondi',
          drugLicense: 'DGDA-DL-4455',
          ownerEmail: 'lazz@pharmacy.local',
          ownerPhone: '+8801700000000', // synthetic-fixture
          ownerPassword: 'Secur3P@ssw0rd!',
          planTier: 'STANDARD',
        ),
        isTrue,
      );

      // Incomplete: missing license
      expect(
        MobileTenantOnboardingWizardClient.validateCompletePayload(
          pharmacyName: 'Lazz Pharma Dhanmondi',
          subdomain: 'lazz-dhanmondi',
          drugLicense: '',
          ownerEmail: 'lazz@pharmacy.local',
          ownerPhone: '+8801700000000', // synthetic-fixture
          ownerPassword: 'Secur3P@ssw0rd!',
          planTier: 'STANDARD',
        ),
        isFalse,
      );
    });

    test('Should resolve bilingual step descriptors and API endpoints', () {
      final step2 = MobileTenantOnboardingWizardClient.getStepTitles(2);
      expect(step2['en'], equals('Licensing & DGDA Compliance'));
      expect(step2['bn'], equals('ড্রাগ লাইসেন্স ও নিয়মতান্ত্রিক স্বীকৃতি'));

      expect(
        MobileTenantOnboardingWizardClient.resolveEndpoint('list'),
        equals('/api/v2/platform/onboarding-wizard/'),
      );
      expect(
        MobileTenantOnboardingWizardClient.resolveEndpoint('complete', sessionId: 'onb-999'),
        equals('/api/v2/platform/onboarding-wizard/onb-999/complete/'),
      );
    });
  });
}
