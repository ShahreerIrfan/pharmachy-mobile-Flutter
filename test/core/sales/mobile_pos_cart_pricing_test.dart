import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_search_cart_client.dart';
import 'package:pharmacy_mobile_manager/features/pos/pos_fast_search_page.dart';

void main() {
  group('P224: Mobile Cart Prices, Tax/Discount Math & Server Confirmation', () {
    test('1. MobilePosDomainClient parses P224 fields and guards update-pricing & confirm-pricing', () async {
      final calls = <String>[];
      final domainClient = MobilePosDomainClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          calls.add('$method $path');
          if (path.endsWith('/update-pricing/') && body?['discount_rate_pct'] == '15.00') {
            return const MobilePosHttpResponse(
              statusCode: 403,
              data: <String, dynamic>{
                'error_code': 'ERR_CASHIER_DISCOUNT_LIMIT_EXCEEDED',
                'message_en': 'Cashiers cannot apply discounts exceeding 5% without approval.',
                'message_bn': 'ক্যাশিয়ার অনুমোদন ছাড়া ৫%-এর বেশি ছাড় দিতে পারবেন না।',
              },
            );
          }
          if (path.endsWith('/update-pricing/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-224',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-224',
                  'idempotency_key': 'idem-224',
                  'lifecycle_state': 'DRAFT',
                  'subtotal_bdt': '140.00',
                  'discount_type': 'PROMO_POLICY',
                  'discount_rate_pct': '0.00',
                  'line_discount_total_bdt': '4.00',
                  'header_discount_amount_bdt': '10.00',
                  'discount_amount_bdt': '14.00',
                  'net_before_tax_bdt': '120.00',
                  'tax_mode': 'INCLUSIVE',
                  'tax_rate_pct': '5.00',
                  'tax_amount_bdt': '6.00',
                  'rounding_mode': 'NEAREST_FIVE_BDT',
                  'rounding_adjustment_bdt': '-1.00',
                  'grand_total_bdt': '125.00',
                  'is_pricing_confirmed': false,
                  'current_pricing_hash': 'hash-p224-xyz',
                  'version': 3,
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
                      'unit_price_bdt': '20.00',
                      'price_source': 'MANAGER_OVERRIDE',
                      'price_override_approved_by_email': 'mgr@pharmacy.bd',
                      'discount_type': 'PERCENTAGE',
                      'discount_rate_pct': '10.00',
                      'discount_amount_bdt': '4.00',
                      'tax_mode': 'INCLUSIVE',
                      'tax_rate_pct': '5.00',
                      'net_before_tax_bdt': '34.29',
                      'line_subtotal_bdt': '40.00',
                      'line_tax_amount_bdt': '1.71',
                      'line_total_bdt': '36.00',
                    }
                  ],
                },
              },
            );
          }
          if (path.endsWith('/confirm-pricing/') && body?['expected_pricing_hash'] == 'stale-hash') {
            return const MobilePosHttpResponse(
              statusCode: 400,
              data: <String, dynamic>{
                'error_code': 'ERR_PRICE_CONFIRMATION_MISMATCH',
                'message_en': 'Cart prices changed since preview.',
                'message_bn': 'কার্টের মূল্য পরিবর্তিত হয়েছে।',
              },
            );
          }
          if (path.endsWith('/confirm-pricing/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-224',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-224',
                  'idempotency_key': 'idem-224',
                  'lifecycle_state': 'DRAFT',
                  'subtotal_bdt': '140.00',
                  'discount_amount_bdt': '14.00',
                  'tax_amount_bdt': '6.00',
                  'rounding_adjustment_bdt': '-1.00',
                  'grand_total_bdt': '125.00',
                  'is_pricing_confirmed': true,
                  'pricing_confirmation_hash': 'hash-p224-xyz',
                  'current_pricing_hash': 'hash-p224-xyz',
                  'pricing_confirmed_at': '2026-11-09T10:35:00Z',
                  'version': 4,
                  'lines': <dynamic>[],
                },
              },
            );
          }
          return const MobilePosHttpResponse(statusCode: 400, data: <String, dynamic>{});
        },
      );

      final upd = await domainClient.updateCartPricing(
        saleId: 'sale-224',
        pricingPayload: <String, dynamic>{'rounding_mode': 'NEAREST_FIVE_BDT'},
        bearerToken: 'tok-mgr',
        actorRole: 'BRANCH_MANAGER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(upd.uiState, MobilePosUiState.ready);
      expect(upd.data!.lineDiscountTotalBdt, '4.00');
      expect(upd.data!.headerDiscountAmountBdt, '10.00');
      expect(upd.data!.netBeforeTaxBdt, '120.00');
      expect(upd.data!.taxMode, 'INCLUSIVE');
      expect(upd.data!.roundingAdjustmentBdt, '-1.00');
      expect(upd.data!.grandTotalBdt, '125.00');
      expect(upd.data!.isPricingConfirmed, false);
      expect(upd.data!.lines.first.priceSource, 'MANAGER_OVERRIDE');
      expect(upd.data!.lines.first.netBeforeTaxBdt, '34.29');

      final conf = await domainClient.confirmCartPricing(
        saleId: 'sale-224',
        bearerToken: 'tok-mgr',
        actorRole: 'BRANCH_MANAGER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        expectedGrandTotalBdt: '125.00',
        expectedPricingHash: 'hash-p224-xyz',
        expectedVersion: 3,
      );
      expect(conf.uiState, MobilePosUiState.ready);
      expect(conf.data!.isPricingConfirmed, true);
      expect(conf.data!.pricingConfirmationHash, 'hash-p224-xyz');

      final denied = await domainClient.updateCartPricing(
        saleId: 'sale-224',
        pricingPayload: <String, dynamic>{'discount_type': 'PERCENTAGE', 'discount_rate_pct': '15.00'},
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(denied.uiState, MobilePosUiState.permissionDenied);
      expect(denied.errorCode, 'ERR_CASHIER_DISCOUNT_LIMIT_EXCEEDED');

      final mismatch = await domainClient.confirmCartPricing(
        saleId: 'sale-224',
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        expectedPricingHash: 'stale-hash',
      );
      expect(mismatch.uiState, MobilePosUiState.error);
      expect(mismatch.errorCode, 'ERR_PRICE_CONFIRMATION_MISMATCH');

      // Cross-branch & suspended plan client guards
      final xBranch = await domainClient.confirmCartPricing(
        saleId: 'sale-224',
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-other',
      );
      expect(xBranch.uiState, MobilePosUiState.permissionDenied);
      expect(xBranch.errorCode, 'ERR_CROSS_BRANCH_ACCESS_DENIED');

      expect(calls.length, 4);
    });

    testWidgets('2. PosFastSearchPage applies discount/rounding with exact paisa math, Cashier limit & EN/BN confirm',
        (WidgetTester tester) async {
      final searchClient = MobilePosSearchCartClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          if (method == 'GET' && path.contains('/api/v2/pos/search/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'query': 'napa',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'total_matches': 1,
                'latency_ms': 1.1,
                'results': <dynamic>[
                  <String, dynamic>{
                    'product_id': 'med-napa',
                    'sku_code': 'NAPA-665',
                    'display_name': 'Napa Extend 665mg',
                    'brand_name': 'Napa Extend',
                    'brand_name_bn': 'নাপা এক্সটেন্ড',
                    'generic_name': 'Paracetamol',
                    'generic_name_bn': 'প্যারাসিটামল',
                    'strength': '665mg',
                    'dosage_form': 'Tablet',
                    'barcode': '894224001',
                    'shelf_location': 'Rack A-2',
                    'resolution_source': 'BRAND_GENERIC_SEARCH',
                    'resolved_packaging_unit': 'STRIP',
                    'resolved_conversion_factor': 10,
                    'unit_price_bdt': '127.40',
                    'base_unit_price_bdt': '12.74',
                    'sellable_base_units': 100,
                    'reserved_base_units': 0,
                    'available_base_units': 100,
                    'quarantined_base_units': 0,
                    'expired_base_units': 0,
                    'recalled_base_units': 0,
                    'requires_rx_verification': false,
                    'non_divisible_sealed_only': false,
                    'is_sellable': true,
                    'block_reason': '',
                    'packaging_options': <dynamic>[
                      <String, dynamic>{
                        'packaging_unit': 'STRIP',
                        'label_en': 'Strip (10u)',
                        'label_bn': 'স্ট্রিপ (10টি)',
                        'conversion_factor': 10,
                        'unit_price_bdt': '127.40',
                        'is_allowed': true,
                      }
                    ],
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path.endsWith('/quick-cart/')) {
            return const MobilePosHttpResponse(
              statusCode: 201,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-ui-224',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-UI-224',
                  'lifecycle_state': 'DRAFT',
                  'version': 1,
                  'lines': <dynamic>[],
                },
              },
            );
          }
          if (method == 'POST' && path.endsWith('/scan-add/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-ui-224',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-UI-224',
                  'lifecycle_state': 'DRAFT',
                  'subtotal_bdt': '127.40',
                  'discount_amount_bdt': '0.00',
                  'tax_amount_bdt': '0.00',
                  'rounding_adjustment_bdt': '0.00',
                  'grand_total_bdt': '127.40',
                  'is_pricing_confirmed': false,
                  'current_pricing_hash': 'h-init',
                  'version': 2,
                  'lines': <dynamic>[
                    <String, dynamic>{
                      'line_id': 'sline-ui-1',
                      'line_number': 1,
                      'product_id': 'med-napa',
                      'product_brand_name': 'Napa Extend',
                      'packaging_unit': 'STRIP',
                      'quantity_units': 1,
                      'conversion_factor': 10,
                      'base_units_total': 10,
                      'unit_price_bdt': '127.40',
                      'line_subtotal_bdt': '127.40',
                      'line_tax_amount_bdt': '0.00',
                      'line_total_bdt': '127.40',
                    },
                  ],
                },
              },
            );
          }
          if (method == 'POST' && path.endsWith('/update-pricing/')) {
            if (body?['discount_rate_pct'] == '10.00') {
              return const MobilePosHttpResponse(
                statusCode: 403,
                data: <String, dynamic>{
                  'error_code': 'ERR_CASHIER_DISCOUNT_LIMIT_EXCEEDED',
                  'message_en': 'Cashiers cannot exceed 5% combined concession.',
                  'message_bn': 'ক্যাশিয়ার ৫%-এর বেশি ছাড় দিতে পারবেন না।',
                },
              );
            }
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-ui-224',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-UI-224',
                  'lifecycle_state': 'DRAFT',
                  'subtotal_bdt': '127.40',
                  'discount_type': 'PERCENTAGE',
                  'discount_rate_pct': '2.75',
                  'discount_amount_bdt': '3.50',
                  'tax_mode': 'EXCLUSIVE',
                  'tax_rate_pct': '0.00',
                  'tax_amount_bdt': '0.00',
                  'rounding_mode': 'HALF_UP_WHOLE_BDT',
                  'rounding_adjustment_bdt': '0.10',
                  'grand_total_bdt': '124.00',
                  'is_pricing_confirmed': false,
                  'current_pricing_hash': 'h-upd-124',
                  'version': 3,
                  'lines': <dynamic>[],
                },
              },
            );
          }
          if (method == 'POST' && path.endsWith('/confirm-pricing/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-ui-224',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-UI-224',
                  'lifecycle_state': 'DRAFT',
                  'subtotal_bdt': '127.40',
                  'discount_amount_bdt': '3.50',
                  'tax_amount_bdt': '0.00',
                  'rounding_adjustment_bdt': '0.10',
                  'grand_total_bdt': '124.00',
                  'is_pricing_confirmed': true,
                  'pricing_confirmation_hash': 'h-upd-124',
                  'current_pricing_hash': 'h-upd-124',
                  'version': 4,
                  'lines': <dynamic>[],
                },
              },
            );
          }
          return const MobilePosHttpResponse(statusCode: 400, data: <String, dynamic>{});
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PosFastSearchPage(
            client: searchClient,
            bearerToken: 'tok-cashier',
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

      await tester.tap(find.byKey(const Key('add_candidate_med-napa')));
      await tester.pumpAndSettle();
      expect(find.text('BDT 127.40'), findsOneWidget);

      // Select Percentage discount 2.75% + apply
      await tester.tap(find.byKey(const Key('pos_discount_type_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Percent %').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('pos_discount_input')), '2.75');
      await tester.tap(find.byKey(const Key('pos_apply_pricing_btn')));
      await tester.pumpAndSettle();

      expect(find.text('BDT 124.00'), findsOneWidget);
      expect(find.byKey(const Key('pos_pricing_confirm_badge')), findsOneWidget);

      // Confirm prices -> Server Confirmed badge appears
      await tester.tap(find.byKey(const Key('pos_confirm_pricing_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Server Confirmed'), findsOneWidget);

      // Try Cashier 10% discount -> permissionDenied banner
      await tester.enterText(find.byKey(const Key('pos_discount_input')), '10.00');
      await tester.tap(find.byKey(const Key('pos_apply_pricing_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('state_banner_permissionDenied')), findsOneWidget);
    });
  });
}

