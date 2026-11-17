import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_search_cart_client.dart';
import 'package:pharmacy_mobile_manager/features/pos/pos_fast_search_page.dart';

void main() {
  group('P223: Mobile Cart Item Unit Selection & Container Restrictions', () {
    test('1. Fetches unit-options, converts preserve-base, handles pharmacist 403 & isolation', () async {
      String? capturedMethod;
      String? capturedPath;
      Map<String, dynamic>? capturedBody;

      final client = MobilePosSearchCartClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          capturedMethod = method;
          capturedPath = path;
          capturedBody = body;

          if (method == 'GET' && path.contains('unit-options')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'sale_id': 'sale-223',
                'line_id': 'sline-1',
                'current_packaging_unit': 'TABLET',
                'current_conversion_factor': 1,
                'current_quantity_units': 20,
                'current_base_units_total': 20,
                'product_id': 'med-napa',
                'brand_name': 'Napa Extend',
                'dosage_form': 'Tablet',
                'normalized_dosage_form': 'TABLET',
                'primary_base_unit': 'TABLET',
                'available_base_units': 250,
                'conversion_source': 'PACKAGING_HIERARCHY',
                'non_divisible_sealed_only': false,
                'blocked_units': <dynamic>[],
                'packaging_options': <dynamic>[
                  <String, dynamic>{
                    'packaging_unit': 'TABLET',
                    'label_en': 'Tablet / Unit',
                    'label_bn': 'ট্যাবলেট / পিস',
                    'conversion_factor': 1,
                    'unit_price_bdt': '2.00',
                    'conversion_source': 'PACKAGING_HIERARCHY',
                    'container_policy_status': 'STANDARD',
                    'is_allowed': true,
                    'requires_pharmacist_approval': false,
                  },
                  <String, dynamic>{
                    'packaging_unit': 'STRIP',
                    'label_en': 'Strip (10u)',
                    'label_bn': 'স্ট্রিপ (10টি)',
                    'conversion_factor': 10,
                    'unit_price_bdt': '19.00',
                    'conversion_source': 'PACKAGING_HIERARCHY',
                    'container_policy_status': 'STANDARD',
                    'is_allowed': true,
                    'requires_pharmacist_approval': false,
                  },
                ],
              },
            );
          }

          if (method == 'POST' && path.contains('select-unit') && body?['packaging_unit'] == 'VIAL') {
            return const MobilePosHttpResponse(
              statusCode: 403,
              data: <String, dynamic>{
                'error_code': 'ERR_PHARMACIST_SPLIT_APPROVAL_REQUIRED',
                'message_en': 'Splitting Ceftron box requires Pharmacist or Manager approval.',
                'message_bn': 'প্যাক ভাঙতে ফার্মাসিস্ট বা ম্যানেজারের অনুমোদন প্রয়োজন।',
              },
            );
          }

          if (method == 'POST' && path.contains('select-unit')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-223',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-223',
                  'idempotency_key': 'idem-223',
                  'lifecycle_state': 'DRAFT',
                  'version': 2,
                  'subtotal_bdt': '38.00',
                  'tax_amount_bdt': '0.00',
                  'grand_total_bdt': '38.00',
                  'lines': <dynamic>[
                    <String, dynamic>{
                      'line_id': 'sline-1',
                      'line_number': 1,
                      'product_id': 'med-napa',
                      'product_brand_name': 'Napa Extend',
                      'packaging_unit': 'STRIP',
                      'quantity_units': 2,
                      'conversion_factor': 10,
                      'base_units_total': 20,
                      'dosage_form_snapshot': 'Tablet',
                      'container_policy_applied': 'STANDARD',
                      'unit_conversion_source': 'PACKAGING_HIERARCHY',
                      'unit_price_bdt': '19.00',
                      'line_subtotal_bdt': '38.00',
                      'line_tax_amount_bdt': '0.00',
                      'line_total_bdt': '38.00',
                    }
                  ],
                }
              },
            );
          }

          return const MobilePosHttpResponse(statusCode: 400, data: <String, dynamic>{});
        },
      );

      final optRes = await client.fetchUnitOptions(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-223',
        lineId: 'sline-1',
      );
      expect(optRes.uiState, MobilePosUiState.ready);
      expect(optRes.data!.currentBaseUnitsTotal, 20);
      expect(optRes.data!.packagingOptions, hasLength(2));

      final selRes = await client.selectCartLineUnit(
        saleId: 'sale-223',
        bearerToken: 'tok-cashier',
        lineId: 'sline-1',
        packagingUnit: 'STRIP',
        conversionMode: 'CONVERT_PRESERVE_BASE',
        expectedVersion: 1,
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(capturedMethod, 'POST');
      expect(capturedPath, '/api/v2/pos/sales/sale-223/select-unit/');
      expect(capturedBody?['conversion_mode'], 'CONVERT_PRESERVE_BASE');
      expect(selRes.uiState, MobilePosUiState.ready);
      expect(selRes.data!.lines.first.quantityUnits, 2);
      expect(selRes.data!.lines.first.baseUnitsTotal, 20);
      expect(selRes.data!.lines.first.unitConversionSource, 'PACKAGING_HIERARCHY');

      final pharmDeny = await client.selectCartLineUnit(
        saleId: 'sale-223',
        bearerToken: 'tok-cashier',
        lineId: 'sline-1',
        packagingUnit: 'VIAL',
      );
      expect(pharmDeny.uiState, MobilePosUiState.permissionDenied);
      expect(pharmDeny.errorCode, 'ERR_PHARMACIST_SPLIT_APPROVAL_REQUIRED');

      // Cross-branch guard
      final xBranch = await client.fetchUnitOptions(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-other',
        productId: 'med-napa',
      );
      expect(xBranch.uiState, MobilePosUiState.permissionDenied);
      expect(xBranch.errorCode, 'ERR_CROSS_BRANCH_ACCESS_DENIED');

      // Suspended subscription guard
      final susp = await client.selectCartLineUnit(
        saleId: 'sale-223',
        bearerToken: 'tok-cashier',
        lineId: 'sline-1',
        packagingUnit: 'STRIP',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        subscriptionSuspended: true,
      );
      expect(susp.uiState, MobilePosUiState.permissionDenied);
      expect(susp.errorCode, 'ERR_SUBSCRIPTION_SUSPENDED');
    });

    testWidgets('2. PosFastSearchPage unit ChoiceChips, base-unit display & locked container policy guard',
        (WidgetTester tester) async {
      final client = MobilePosSearchCartClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          return const MobilePosHttpResponse(
            statusCode: 200,
            data: <String, dynamic>{
              'query': 'napa',
              'tenant_id': 'ten-a',
              'branch_id': 'br-a',
              'total_matches': 2,
              'latency_ms': 1.5,
              'results': <dynamic>[
                <String, dynamic>{
                  'product_id': 'med-napa',
                  'sku_code': 'NAPA-500',
                  'display_name': 'Napa 500mg',
                  'brand_name': 'Napa',
                  'brand_name_bn': 'নাপা',
                  'generic_name': 'Paracetamol',
                  'generic_name_bn': 'প্যারাসিটামল',
                  'strength': '500mg',
                  'dosage_form': 'Tablet',
                  'barcode': '880112233',
                  'shelf_location': 'Rack A-1',
                  'resolution_source': 'BRAND_GENERIC_SEARCH',
                  'resolved_packaging_unit': 'STRIP',
                  'resolved_conversion_factor': 10,
                  'unit_price_bdt': '19.00',
                  'base_unit_price_bdt': '2.00',
                  'sellable_base_units': 35,
                  'reserved_base_units': 0,
                  'available_base_units': 35,
                  'quarantined_base_units': 0,
                  'expired_base_units': 0,
                  'recalled_base_units': 0,
                  'requires_rx_verification': false,
                  'non_divisible_sealed_only': false,
                  'is_sellable': true,
                  'block_reason': '',
                  'packaging_options': <dynamic>[
                    <String, dynamic>{
                      'packaging_unit': 'TABLET',
                      'label_en': 'Tablet / Unit',
                      'label_bn': 'ট্যাবলেট / পিস',
                      'conversion_factor': 1,
                      'unit_price_bdt': '2.00',
                      'is_allowed': true,
                    },
                    <String, dynamic>{
                      'packaging_unit': 'STRIP',
                      'label_en': 'Strip (10u)',
                      'label_bn': 'স্ট্রিপ (10টি)',
                      'conversion_factor': 10,
                      'unit_price_bdt': '19.00',
                      'is_allowed': true,
                    },
                  ],
                },
                <String, dynamic>{
                  'product_id': 'med-insulin',
                  'sku_code': 'LANTUS-BOX',
                  'display_name': 'Lantus SoloStar',
                  'brand_name': 'Lantus',
                  'brand_name_bn': 'ল্যান্টাস',
                  'generic_name': 'Insulin Glargine',
                  'generic_name_bn': 'ইনসুলিন',
                  'strength': '100IU',
                  'dosage_form': 'Injection',
                  'barcode': '880999',
                  'shelf_location': 'Fridge 1',
                  'resolution_source': 'BRAND_GENERIC_SEARCH',
                  'resolved_packaging_unit': 'BOX',
                  'resolved_conversion_factor': 5,
                  'unit_price_bdt': '4400.00',
                  'base_unit_price_bdt': '900.00',
                  'sellable_base_units': 20,
                  'reserved_base_units': 0,
                  'available_base_units': 20,
                  'quarantined_base_units': 0,
                  'expired_base_units': 0,
                  'recalled_base_units': 0,
                  'requires_rx_verification': true,
                  'non_divisible_sealed_only': true,
                  'is_sellable': true,
                  'block_reason': '',
                  'blocked_units': <dynamic>['UNIT'],
                  'packaging_options': <dynamic>[
                    <String, dynamic>{
                      'packaging_unit': 'UNIT',
                      'label_en': 'Unit',
                      'label_bn': 'একক',
                      'conversion_factor': 1,
                      'unit_price_bdt': '900.00',
                      'is_allowed': false,
                      'requires_pharmacist_approval': false,
                      'block_error_code': 'ERR_NON_DIVISIBLE_PACK',
                      'block_reason_en': 'Sealed insulin pack cannot be split.',
                      'block_reason_bn': 'সিলড ইনসুলিন প্যাক খোলা যাবে না।',
                    },
                    <String, dynamic>{
                      'packaging_unit': 'BOX',
                      'label_en': 'Box (5u)',
                      'label_bn': 'বক্স (5টি)',
                      'conversion_factor': 5,
                      'unit_price_bdt': '4400.00',
                      'is_allowed': true,
                    },
                  ],
                },
              ],
            },
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PosFastSearchPage(
            client: client,
            bearerToken: '',
            actorRole: 'CASHIER',
            actorTenantId: 'ten-a',
            actorBranchId: 'br-a',
            targetTenantId: 'ten-a',
            targetBranchId: 'br-a',
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('pos_search_input')), 'napa');
      await tester.tap(find.byKey(const Key('pos_search_button')));
      await tester.pumpAndSettle();

      // Tapping restricted UNIT chip on sealed insulin pack shows error banner & stays blocked
      await tester.tap(find.byKey(const Key('cand_unit_med-insulin_UNIT')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('state_banner_error')), findsOneWidget);
      expect(find.textContaining('Sealed insulin pack cannot be split'), findsOneWidget);

      // Select TABLET on Napa candidate and add 1 unit -> cart shows 1u base & BDT 2.00
      await tester.tap(find.byKey(const Key('cand_unit_med-napa_TABLET')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_candidate_med-napa')));
      await tester.pumpAndSettle();
      expect(find.text('BDT 2.00'), findsOneWidget);
      expect(find.text('TABLET (1u base) • 2.00 BDT'), findsOneWidget);

      // Switch cart unit via PopupMenuButton from TABLET -> STRIP -> 10u base & BDT 19.00
      await tester.tap(find.byKey(const Key('cart_unit_btn_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('STRIP (10u)').last);
      await tester.pumpAndSettle();
      expect(find.text('BDT 19.00'), findsOneWidget);
      expect(find.text('STRIP (10u base) • 19.00 BDT'), findsOneWidget);
    });
  });
}
