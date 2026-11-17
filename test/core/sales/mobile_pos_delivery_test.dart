import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_search_cart_client.dart';
import 'package:pharmacy_mobile_manager/features/pos/pos_fast_search_page.dart';

void main() {
  group('P226: Mobile Sales Preorders, Delivery Fulfillment & Address Privacy', () {
    test('1. Client listDeliveryOrders, createDeliveryOrder, revealDeliveryAddress, transitions, archive & guards',
        () async {
      final calls = <String>[];
      var lastCodTender = '';

      final client = MobilePosSearchCartClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          calls.add('$method $path');
          if (method == 'GET' && path.startsWith('/api/v2/pos/deliveries/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'count': 1,
                'results': <dynamic>[
                  <String, dynamic>{
                    'delivery_id': 'dlv-m-1',
                    'tenant_id': 'ten-a',
                    'branch_id': 'br-a',
                    'sale_id': 'sale-m-1',
                    'order_number': 'POS-M1',
                    'sale_lifecycle_state': 'DRAFT',
                    'sale_grand_total_bdt': '187.40',
                    'delivery_number': 'DLV-2026-M1',
                    'fulfillment_mode': 'HOME_DELIVERY',
                    'delivery_method': 'OWN_RIDER',
                    'fulfillment_state': 'PREORDER_RESERVED',
                    'stock_reserved': true,
                    'recipient_name': 'N**** I****',
                    'recipient_phone': '+88018******78',
                    'delivery_address_line': '[MASKED - Reveal to Dispatch]',
                    'delivery_area': 'Dhanmondi',
                    'delivery_city': 'Dhaka',
                    '_address_privacy_masked': true,
                    'delivery_fee_bdt': '60.00',
                    'cod_expected_bdt': '187.40',
                    'version': 1,
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/deliveries/') {
            return const MobilePosHttpResponse(
              statusCode: 201,
              data: <String, dynamic>{
                'delivery_id': 'dlv-m-2',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'sale_id': 'sale-m-2',
                'order_number': 'POS-M2',
                'sale_grand_total_bdt': '187.40',
                'delivery_number': 'DLV-2026-M2',
                'fulfillment_mode': 'HOME_DELIVERY',
                'delivery_method': 'OWN_RIDER',
                'fulfillment_state': 'PREORDER_RESERVED',
                'stock_reserved': true,
                'recipient_name': 'N**** I****',
                'recipient_phone': '+88018******78',
                'delivery_address_line': '[MASKED - Reveal to Dispatch]',
                'delivery_area': 'Dhanmondi',
                '_address_privacy_masked': true,
                'delivery_fee_bdt': '60.00',
                'cod_expected_bdt': '187.40',
                'version': 1,
              },
            );
          }
          if (method == 'PATCH' && path == '/api/v2/pos/deliveries/dlv-m-1/') {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'delivery_id': 'dlv-m-1',
                'delivery_number': 'DLV-2026-M1',
                'fulfillment_state': 'PREORDER_RESERVED',
                'delivery_fee_bdt': '80.00',
                'sale_grand_total_bdt': '207.40',
                'cod_expected_bdt': '207.40',
                'version': 2,
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/deliveries/dlv-m-1/reveal-address/') {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'delivery_id': 'dlv-m-1',
                'delivery_number': 'DLV-2026-M1',
                'recipient_name': 'Nadia Islam',
                'recipient_phone': '+8801812345678',
                'delivery_address_line': 'Flat 4B, House 19, Dhanmondi',
                'delivery_area': 'Dhanmondi',
                'delivery_city': 'Dhaka',
                '_address_privacy_masked': false,
                'audit_id': 'aud-mob-1',
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/deliveries/dlv-m-1/deliver/') {
            lastCodTender = (body?['cod_tender_type'] ?? '').toString();
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'delivery_id': 'dlv-m-1',
                'delivery_number': 'DLV-2026-M1',
                'fulfillment_state': 'DELIVERED',
                'sale_lifecycle_state': 'FINALIZED',
                'proof_of_delivery_ref': 'POD-MOB',
                'cod_expected_bdt': '0.00',
                'cod_collected_bdt': '207.40',
                'version': 5,
              },
            );
          }
          if (method == 'DELETE' && path.startsWith('/api/v2/pos/deliveries/dlv-m-2/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'delivery_id': 'dlv-m-2',
                'is_archived': true,
              },
            );
          }
          return const MobilePosHttpResponse(statusCode: 404, data: <String, dynamic>{});
        },
      );

      // Role, tenant, branch, subscription & offline guards
      final auditorDenied = await client.createDeliveryOrder(
        bearerToken: 'tok',
        actorRole: 'AUDITOR',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        payload: const <String, dynamic>{
          'fulfillment_mode': 'PREORDER_PICKUP',
          'recipient_name': 'Karim',
          'recipient_phone': '01711111111',
        },
      );
      expect(auditorDenied.uiState, MobilePosUiState.permissionDenied);

      final crossTenant = await client.listDeliveryOrders(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-b',
        targetBranchId: 'br-a',
      );
      expect(crossTenant.uiState, MobilePosUiState.error);
      expect(crossTenant.errorCode, 'ERR_CROSS_TENANT_VIOLATION');

      final crossBranch = await client.listDeliveryOrders(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-b',
      );
      expect(crossBranch.uiState, MobilePosUiState.permissionDenied);

      final suspended = await client.listDeliveryOrders(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        subscriptionSuspended: true,
      );
      expect(suspended.uiState, MobilePosUiState.permissionDenied);

      final offline = await client.listDeliveryOrders(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        isOffline: true,
      );
      expect(offline.uiState, MobilePosUiState.offline);

      // Validation guards
      final missingAddr = await client.createDeliveryOrder(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        payload: const <String, dynamic>{
          'fulfillment_mode': 'HOME_DELIVERY',
          'recipient_name': 'Nadia Islam',
          'recipient_phone': '01812345678',
        },
      );
      expect(missingAddr.uiState, MobilePosUiState.error);
      expect(missingAddr.errorCode, 'ERR_DELIVERY_ADDRESS_REQUIRED');

      final shortReason = await client.revealDeliveryAddress(
        deliveryId: 'dlv-m-1',
        reason: 'hi',
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(shortReason.uiState, MobilePosUiState.error);
      expect(shortReason.errorCode, 'ERR_REVEAL_REASON_REQUIRED');

      // Masked list
      final listRes = await client.listDeliveryOrders(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(listRes.uiState, MobilePosUiState.ready);
      expect(listRes.data!.results.first.addressPrivacyMasked, isTrue);
      expect(listRes.data!.results.first.recipientName, 'N**** I****');

      // Audited reveal
      final revealRes = await client.revealDeliveryAddress(
        deliveryId: 'dlv-m-1',
        reason: 'Doorstep courier dispatch verification',
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(revealRes.uiState, MobilePosUiState.ready);
      expect(revealRes.data!.deliveryAddressLine, 'Flat 4B, House 19, Dhanmondi');
      expect(revealRes.data!.auditId, 'aud-mob-1');

      // PATCH + deliver + archive
      final patchRes = await client.updateDeliveryOrder(
        deliveryId: 'dlv-m-1',
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        payload: const <String, dynamic>{'delivery_fee_bdt': '80.00', 'expected_version': 1},
      );
      expect(patchRes.uiState, MobilePosUiState.ready);
      expect(patchRes.data!.saleGrandTotalBdt, '207.40');

      final deliverRes = await client.transitionDelivery(
        deliveryId: 'dlv-m-1',
        actionSlug: 'deliver',
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        payload: const <String, dynamic>{
          'proof_of_delivery_ref': 'POD-MOB',
          'cod_collected_bdt': '207.40',
          'cod_tender_type': 'CASH',
        },
        successEn: 'Delivered',
        successBn: 'সম্পন্ন',
      );
      expect(deliverRes.uiState, MobilePosUiState.ready);
      expect(deliverRes.data!.fulfillmentState, 'DELIVERED');
      expect(lastCodTender, 'CASH');

      final archiveRes = await client.archiveDeliveryOrder(
        deliveryId: 'dlv-m-2',
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        reason: 'Cleanup',
      );
      expect(archiveRes.uiState, MobilePosUiState.ready);
      expect(archiveRes.data!.isArchived, isTrue);
      expect(calls, isNotEmpty);
    });

    testWidgets(
        '2. PosFastSearchPage creates delivery from cart, opens sheet, reveals masked PII, transitions & supports BN',
        (WidgetTester tester) async {
      var currentState = 'PREORDER_RESERVED';
      var revealed = false;

      final client = MobilePosSearchCartClient(
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
                'latency_ms': 1.0,
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
                    'barcode': '894226001',
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
                  'sale_id': 'sale-ui-226',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-UI-226',
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
                  'sale_id': 'sale-ui-226',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-UI-226',
                  'lifecycle_state': 'DRAFT',
                  'subtotal_bdt': '127.40',
                  'grand_total_bdt': '127.40',
                  'version': 2,
                  'lines': <dynamic>[
                    <String, dynamic>{
                      'line_id': 'ln-1',
                      'line_number': 1,
                      'product_id': 'med-napa',
                      'product_brand_name': 'Napa Extend',
                      'packaging_unit': 'STRIP',
                      'quantity_units': 1,
                      'conversion_factor': 10,
                      'base_units_total': 10,
                      'unit_price_bdt': '127.40',
                      'line_subtotal_bdt': '127.40',
                      'line_total_bdt': '127.40',
                    },
                  ],
                },
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/deliveries/') {
            return const MobilePosHttpResponse(
              statusCode: 201,
              data: <String, dynamic>{
                'delivery_id': 'dlv-m1',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'sale_id': 'sale-ui-226',
                'order_number': 'POS-UI-226',
                'sale_grand_total_bdt': '187.40',
                'delivery_number': 'DLV-MOB-01',
                'fulfillment_mode': 'HOME_DELIVERY',
                'delivery_method': 'OWN_RIDER',
                'fulfillment_state': 'PREORDER_RESERVED',
                'recipient_name': 'N**** I****',
                'recipient_phone': '+88018******78',
                'delivery_address_line': '[MASKED - Reveal to Dispatch]',
                'delivery_area': 'Dhanmondi',
                '_address_privacy_masked': true,
                'delivery_fee_bdt': '60.00',
                'cod_expected_bdt': '187.40',
                'version': 1,
              },
            );
          }
          if (method == 'GET' && path.startsWith('/api/v2/pos/deliveries/')) {
            return MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'count': 1,
                'results': <dynamic>[
                  <String, dynamic>{
                    'delivery_id': 'dlv-m1',
                    'delivery_number': 'DLV-MOB-01',
                    'fulfillment_mode': 'HOME_DELIVERY',
                    'fulfillment_state': currentState,
                    'recipient_name': revealed ? 'Nadia Islam' : 'N**** I****',
                    'recipient_phone': revealed ? '+8801812345678' : '+88018******78',
                    'delivery_address_line':
                        revealed ? 'Flat 4B, House 19, Dhanmondi' : '[MASKED - Reveal to Dispatch]',
                    'delivery_area': 'Dhanmondi',
                    '_address_privacy_masked': !revealed,
                    'delivery_fee_bdt': '60.00',
                    'sale_grand_total_bdt': '187.40',
                    'cod_expected_bdt': currentState == 'DELIVERED' ? '0.00' : '187.40',
                    'version': 1,
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/deliveries/dlv-m1/reveal-address/') {
            revealed = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'delivery_id': 'dlv-m1',
                'delivery_number': 'DLV-MOB-01',
                'recipient_name': 'Nadia Islam',
                'recipient_phone': '+8801812345678',
                'delivery_address_line': 'Flat 4B, House 19, Dhanmondi',
                'delivery_area': 'Dhanmondi',
                'delivery_city': 'Dhaka',
                '_address_privacy_masked': false,
                'audit_id': 'aud-m1',
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/deliveries/dlv-m1/pack/') {
            currentState = 'PACKED';
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'delivery_id': 'dlv-m1',
                'delivery_number': 'DLV-MOB-01',
                'fulfillment_mode': 'HOME_DELIVERY',
                'fulfillment_state': 'PACKED',
                'recipient_name': 'Nadia Islam',
                'recipient_phone': '+8801812345678',
                'delivery_address_line': 'Flat 4B, House 19, Dhanmondi',
                'delivery_fee_bdt': '60.00',
                'sale_grand_total_bdt': '187.40',
                'cod_expected_bdt': '187.40',
                'version': 2,
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/deliveries/dlv-m1/dispatch/') {
            currentState = 'DISPATCHED';
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'delivery_id': 'dlv-m1',
                'delivery_number': 'DLV-MOB-01',
                'fulfillment_mode': 'HOME_DELIVERY',
                'fulfillment_state': 'DISPATCHED',
                'recipient_name': 'Nadia Islam',
                'recipient_phone': '+8801812345678',
                'delivery_address_line': 'Flat 4B, House 19, Dhanmondi',
                'delivery_fee_bdt': '60.00',
                'sale_grand_total_bdt': '187.40',
                'cod_expected_bdt': '187.40',
                'version': 3,
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/deliveries/dlv-m1/deliver/') {
            currentState = 'DELIVERED';
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'delivery_id': 'dlv-m1',
                'delivery_number': 'DLV-MOB-01',
                'fulfillment_mode': 'HOME_DELIVERY',
                'fulfillment_state': 'DELIVERED',
                'sale_lifecycle_state': 'FINALIZED',
                'recipient_name': 'Nadia Islam',
                'recipient_phone': '+8801812345678',
                'delivery_address_line': 'Flat 4B, House 19, Dhanmondi',
                'delivery_fee_bdt': '60.00',
                'sale_grand_total_bdt': '187.40',
                'cod_expected_bdt': '0.00',
                'cod_collected_bdt': '187.40',
                'version': 4,
              },
            );
          }
          return const MobilePosHttpResponse(statusCode: 404, data: <String, dynamic>{});
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PosFastSearchPage(
            client: client,
            bearerToken: 'tok-mob',
            actorRole: 'CASHIER',
            actorTenantId: 'ten-a',
            actorBranchId: 'br-a',
            targetTenantId: 'ten-a',
            targetBranchId: 'br-a',
          ),
        ),
      );

      // Search & add Napa Extend to cart
      await tester.enterText(find.byKey(const Key('pos_search_input')), 'napa');
      await tester.tap(find.byKey(const Key('pos_search_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_candidate_med-napa')));
      await tester.pumpAndSettle();
      expect(find.text('BDT 127.40'), findsOneWidget);

      // Open Create Preorder / Delivery dialog & submit
      await tester.tap(find.byKey(const Key('pos_create_delivery_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pos_dlv_recipient_input')), 'Nadia Islam');
      await tester.enterText(find.byKey(const Key('pos_dlv_phone_input')), '01812345678');
      await tester.enterText(find.byKey(const Key('pos_dlv_address_input')), 'Flat 4B, House 19, Dhanmondi');
      await tester.enterText(find.byKey(const Key('pos_dlv_area_input')), 'Dhanmondi');
      await tester.tap(find.byKey(const Key('pos_confirm_create_dlv_btn')));
      await tester.pumpAndSettle();

      // Cart cleared and top Deliveries badge updated to 1
      expect(find.text('BDT 0.00'), findsOneWidget);
      expect(find.text('Deliveries (1)'), findsOneWidget);

      // Open Deliveries sheet -> masked view initially
      await tester.tap(find.byKey(const Key('pos_deliveries_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pos_deliveries_sheet')), findsOneWidget);
      expect(find.text('[MASKED - Reveal to Dispatch]'), findsOneWidget);

      // Operational Reveal Address shows full street address
      await tester.tap(find.byKey(const Key('pos_reveal_dlv_dlv-m1')));
      await tester.pumpAndSettle();
      expect(find.text('Flat 4B, House 19, Dhanmondi'), findsOneWidget);

      // Pack -> Dispatch -> Deliver transitions
      await tester.tap(find.byKey(const Key('pos_pack_dlv_dlv-m1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pos_dispatch_dlv_dlv-m1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pos_dispatch_dlv_dlv-m1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pos_deliver_dlv_dlv-m1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pos_deliver_dlv_dlv-m1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('DELIVERED'), findsWidgets);

      // Close sheet and toggle EN -> BN
      Navigator.of(tester.element(find.byKey(const Key('pos_deliveries_sheet')))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('বাংলা'));
      await tester.pumpAndSettle();
      expect(find.text('ডেলিভারি (1)'), findsOneWidget);
    });

    testWidgets('3. PosFastSearchPage queues offline local preorder and cancels cleanly', (WidgetTester tester) async {
      final client = MobilePosSearchCartClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          return const MobilePosHttpResponse(statusCode: 503, data: <String, dynamic>{});
        },
      );
      client.seedOfflineSnapshot('br-a', const <MobileFastSearchCandidate>[
        MobileFastSearchCandidate(
          productId: 'med-offline',
          skuCode: 'OFF-1',
          displayName: 'Napa Extra 500mg',
          brandName: 'Napa Extra',
          brandNameBn: 'নাপা এক্সট্রা',
          genericName: 'Paracetamol',
          genericNameBn: 'প্যারাসিটামল',
          strength: '500mg',
          dosageForm: 'Tablet',
          barcode: '894000999',
          shelfLocation: 'A-1',
          resolutionSource: 'OFFLINE_SNAPSHOT',
          resolvedPackagingUnit: 'TABLET',
          resolvedConversionFactor: 1,
          unitPriceBdt: '25.00',
          baseUnitPriceBdt: '25.00',
          sellableBaseUnits: 50,
          reservedBaseUnits: 0,
          availableBaseUnits: 50,
          quarantinedBaseUnits: 0,
          expiredBaseUnits: 0,
          recalledBaseUnits: 0,
          earliestBatchNumber: 'SNAP-1',
          nearExpiryWarning: false,
          requiresRxVerification: false,
          nonDivisibleSealedOnly: false,
          isSellable: true,
          blockReason: '',
          snapshotChecksum: 'chk-1',
          rankScore: 100,
          packagingOptions: <MobilePackagingOption>[
            MobilePackagingOption(
              packagingUnit: 'TABLET',
              labelEn: 'Tablet',
              labelBn: 'ট্যাবলেট',
              conversionFactor: 1,
              unitPriceBdt: '25.00',
              isAllowed: true,
            ),
          ],
        ),
      ]);

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
            isOffline: true,
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('pos_search_input')), 'napa');
      await tester.tap(find.byKey(const Key('pos_search_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_candidate_med-offline')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pos_create_delivery_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pos_dlv_recipient_input')), 'Rafiq Offline');
      await tester.enterText(find.byKey(const Key('pos_dlv_phone_input')), '01712000111');
      await tester.enterText(find.byKey(const Key('pos_dlv_address_input')), 'Road 5, Mirpur');
      await tester.tap(find.byKey(const Key('pos_confirm_create_dlv_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state_banner_offline')), findsOneWidget);
      expect(find.text('Deliveries (1)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pos_deliveries_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('OFF-DLV-1'), findsWidgets);

      await tester.tap(find.byKey(const Key('pos_cancel_dlv_offline-dlv-1')));
      await tester.pumpAndSettle();
      expect(find.text('No preorders or deliveries queued in this branch'), findsOneWidget);
    });
  });
}
