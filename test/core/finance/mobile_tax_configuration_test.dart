// mobile_tax_configuration_test.dart
// Architecture Decision: ADR-0297 (P297).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_tax_configuration_client.dart';

void main() {
  group('P297 MobileTaxConfigurationClient', () {
    test('01. Owner parses reviewed active tax rules with EN/BN labels', () {
      final client = MobileTaxConfigurationClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'PHARMACY_OWNER',
      );

      final rules = client.parseRulesResponse({
        'rules': [
          {
            'rule_id': 'taxr-1',
            'rule_code': 'RETAIL_VAT_7_5',
            'name': 'Non-Medicine Retail VAT (Reviewed)',
            'name_bn': 'নন-মেডিসিন রিটেইল ভ্যাট',
            'applies_to_scope': 'NON_MEDICINE_RETAIL',
            'calculation_mode': 'EXCLUSIVE',
            'tax_rate_pct': '7.500',
            'gl_account_code': '2030',
            'effective_from': '2026-07-01',
            'status': 'REVIEWED_ACTIVE',
            'review_reference': 'ADVISOR-MEMO-2026-07',
          }
        ],
      });

      expect(rules.length, 1);
      expect(rules.first.localizedStatusLabel()['bn'], 'পর্যালোচিত ও সক্রিয়');
      expect(client.uiState, TaxUiState.loaded);
    });

    test('02. Empty rules response sets empty state', () {
      final client = MobileTaxConfigurationClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'PHARMACY_OWNER',
      );
      expect(client.parseRulesResponse({'rules': []}), isEmpty);
      expect(client.uiState, TaxUiState.empty);
    });

    test('03. Offline fallback restores cached reviewed rules', () {
      final client = MobileTaxConfigurationClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'FINANCE_OFFICER',
      );
      client.parseRulesResponse({
        'rules': [
          {'rule_id': 'taxr-2', 'rule_code': 'MED_ZERO', 'status': 'REVIEWED_ACTIVE'}
        ],
      });
      final cached = client.loadOfflineFallback();
      expect(cached.length, 1);
      expect(client.uiState, TaxUiState.offlineCache);
    });

    test('04. Branch Manager and Cashier blocked from creating tax rules', () {
      for (final role in ['BRANCH_MANAGER', 'CASHIER']) {
        final client = MobileTaxConfigurationClient(
          tenantId: 'ten-1',
          branchId: 'br-1',
          userRole: role,
        );
        expect(
          () => client.buildDraftRulePayload(
            ruleCode: 'VAT5',
            name: 'VAT 5%',
            taxRatePct: '5.000',
            effectiveFrom: '2026-07-01',
          ),
          throwsA(isA<TaxConfigPermissionException>()),
        );
        expect(client.uiState, TaxUiState.permissionDenied);
      }
    });

    test('05. Out-of-bounds tax rate throws validation exception', () {
      final client = MobileTaxConfigurationClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'PHARMACY_OWNER',
      );
      expect(
        () => client.buildDraftRulePayload(
          ruleCode: 'BAD',
          name: 'Invalid',
          taxRatePct: '125.000',
          effectiveFrom: '2026-07-01',
        ),
        throwsA(isA<TaxConfigValidationException>()),
      );
    });
  });
}
