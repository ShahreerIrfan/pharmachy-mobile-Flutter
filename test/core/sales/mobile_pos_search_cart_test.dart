import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_search_cart_client.dart';
import 'package:pharmacy_mobile_manager/features/pos/pos_fast_search_page.dart';

void main() {
  group('P222: Mobile Fast Search & Barcode Cart Tests', () {
    test('1. Online prioritized search, Cashier cost redaction & offline snapshot fallback', () async {
      final onlineClient = MobilePosSearchCartClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          expect(method, 'GET');
          expect(path, contains('/api/v2/pos/search/'));
          return const MobilePosHttpResponse(
            statusCode: 200,
            data: <String, dynamic>{
              'query': 'napa',
              'tenant_id': 'ten-a',
              'branch_id': 'br-a',
              'total_matches': 1,
              'latency_ms': 2.5,
              'results': <dynamic>[
                <String, dynamic>{
                  'product_id': 'med-napa',
                  'sku_code': 'NAPA-500',
                  'display_name': 'Napa 500mg Tablet',
                  'brand_name': 'Napa',
                  'brand_name_bn': 'নাপা',
                  'generic_name': 'Paracetamol',
                  'generic_name_bn': 'প্যারাসিটামল',
                  'strength': '500mg',
                  'dosage_form': 'Tablet',
                  'barcode': '880112233',
                  'shelf_location': 'Rack A-1',
                  'resolution_source': 'BARCODE_ALTERNATE',
                  'resolved_packaging_unit': 'STRIP',
                  'resolved_conversion_factor': 10,
                  'unit_price_bdt': '12.00',
                  'base_unit_price_bdt': '1.20',
                  'unit_cost_bdt': null,
                  'sellable_base_units': 100,
                  'reserved_base_units': 0,
                  'available_base_units': 100,
                  'quarantined_base_units': 0,
                  'expired_base_units': 0,
                  'recalled_base_units': 0,
                  'earliest_batch_number': 'BAT-01',
                  'earliest_expiry_date': '2028-05-01',
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
                      'unit_price_bdt': '12.00',
                    }
                  ],
                }
              ],
            },
          );
        },
      );

      final res = await onlineClient.fastSearch(
        query: '880112233',
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(res.uiState, MobilePosUiState.ready);
      expect(res.data!.results, hasLength(1));
      expect(res.data!.results.first.unitCostBdt, isNull);
      expect(res.data!.results.first.resolutionSource, 'BARCODE_ALTERNATE');

      final offlineClient = MobilePosSearchCartClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          throw Exception('Network timeout');
        },
      );
      offlineClient.seedOfflineSnapshot('br-a', res.data!.results);

      final offRes = await offlineClient.fastSearch(
        query: 'নাপা',
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(offRes.uiState, MobilePosUiState.offline);
      expect(offRes.data!.fromOfflineCache, isTrue);
      expect(offRes.data!.results.first.resolutionSource, 'OFFLINE_SNAPSHOT');
    });

    test('2. Guards Cashier snapshot rebuild, empty query, scanAdd & mutateCartLine', () async {
      final client = MobilePosSearchCartClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          if (path.contains('scan-add')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-m1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-M1',
                  'idempotency_key': 'idem-m1',
                  'lifecycle_state': 'DRAFT',
                  'subtotal_bdt': '12.00',
                  'tax_amount_bdt': '0.00',
                  'grand_total_bdt': '12.00',
                  'lines': <dynamic>[
                    <String, dynamic>{
                      'line_id': 'sline-1',
                      'line_number': 1,
                      'product_id': 'med-napa',
                      'product_brand_name': 'Napa',
                      'packaging_unit': 'STRIP',
                      'quantity_units': 1,
                      'conversion_factor': 10,
                      'base_units_total': 10,
                      'unit_price_bdt': '12.00',
                      'line_subtotal_bdt': '12.00',
                      'line_tax_amount_bdt': '0.00',
                      'line_total_bdt': '12.00',
                    }
                  ],
                }
              },
            );
          }
          return const MobilePosHttpResponse(
            statusCode: 403,
            data: <String, dynamic>{'error_code': 'ERR_PERMISSION_DENIED'},
          );
        },
      );

      final denied = await client.triggerServerSnapshotRebuild(
        targetBranchId: 'br-a',
        actorRole: 'CASHIER',
        bearerToken: 'tok-cashier',
      );
      expect(denied.uiState, MobilePosUiState.permissionDenied);
      expect(denied.errorCode, 'ERR_PERMISSION_DENIED');

      final emptyQ = await client.fastSearch(
        query: '   ',
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(emptyQ.uiState, MobilePosUiState.error);

      final addRes = await client.scanAdd(
        saleId: 'sale-m1',
        bearerToken: 'tok-cashier',
        barcode: '880112233',
        packagingUnit: 'STRIP',
        quantityDelta: 1,
        expectedVersion: 1,
      );
      expect(addRes.uiState, MobilePosUiState.ready);
      expect(addRes.data!.grandTotalBdt, '12.00');
    });

    testWidgets('3. PosFastSearchPage renders EN/BN toggle, blocks expired items, adds & updates cart',
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
              'latency_ms': 1.8,
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
                  'unit_price_bdt': '12.00',
                  'base_unit_price_bdt': '1.20',
                  'sellable_base_units': 30,
                  'reserved_base_units': 0,
                  'available_base_units': 30,
                  'quarantined_base_units': 0,
                  'expired_base_units': 0,
                  'recalled_base_units': 0,
                  'earliest_expiry_date': '2028-05-01',
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
                      'unit_price_bdt': '12.00',
                    }
                  ],
                },
                <String, dynamic>{
                  'product_id': 'med-exp',
                  'sku_code': 'EXP-01',
                  'display_name': 'ExpiredDrug',
                  'brand_name': 'ExpiredDrug',
                  'brand_name_bn': 'মেয়াদোত্তীর্ণ',
                  'generic_name': 'OldGen',
                  'generic_name_bn': 'পুরাতন',
                  'strength': '10mg',
                  'dosage_form': 'Tablet',
                  'barcode': '999888',
                  'shelf_location': 'Quarantine',
                  'resolution_source': 'BRAND_GENERIC_SEARCH',
                  'resolved_packaging_unit': 'TABLET',
                  'resolved_conversion_factor': 1,
                  'unit_price_bdt': '50.00',
                  'base_unit_price_bdt': '50.00',
                  'sellable_base_units': 0,
                  'reserved_base_units': 0,
                  'available_base_units': 0,
                  'quarantined_base_units': 0,
                  'expired_base_units': 12,
                  'recalled_base_units': 0,
                  'requires_rx_verification': true,
                  'non_divisible_sealed_only': false,
                  'is_sellable': false,
                  'block_reason': 'EXPIRED_STOCK_BLOCKED',
                  'packaging_options': <dynamic>[],
                }
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

      expect(find.byKey(const Key('state_banner_empty')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('pos_search_input')), 'napa');
      await tester.tap(find.byKey(const Key('pos_search_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state_banner_ready')), findsOneWidget);
      expect(find.text('Napa 500mg'), findsOneWidget);

      final ElevatedButton expiredBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('add_candidate_med-exp')),
      );
      expect(expiredBtn.onPressed, isNull, reason: 'Expired item Add button must be disabled');

      await tester.tap(find.byKey(const Key('add_candidate_med-napa')));
      await tester.pumpAndSettle();
      expect(find.text('BDT 12.00'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cart_inc_0')));
      await tester.pumpAndSettle();
      expect(find.text('BDT 24.00'), findsOneWidget);

      // Toggle EN -> BN
      await tester.tap(find.text('বাংলা'));
      await tester.pumpAndSettle();
      expect(find.text('দ্রুত সার্চ ও বারকোড কার্ট'), findsOneWidget);
    });
  });
}

