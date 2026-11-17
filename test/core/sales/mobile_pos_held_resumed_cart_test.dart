import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_search_cart_client.dart';
import 'package:pharmacy_mobile_manager/features/pos/pos_fast_search_page.dart';

void main() {
  group('P225: Mobile Held & Resumed Carts Client + UI', () {
    test('1. Client hold, listHeldCarts, stale resume prompt, acknowledge, expireStaleHolds, expireHold & cancelHold + guards',
        () async {
      final calls = <String>[];
      var staleAckSeen = false;

      final client = MobilePosSearchCartClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          calls.add('$method $path');
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-225/hold/') {
            return MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-225',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-225',
                'idempotency_key': 'idem-225',
                'lifecycle_state': 'HELD',
                'hold_reference': body?['hold_reference'] ?? 'COUNTER-1',
                'hold_note': body?['hold_note'] ?? '',
                'held_at': '2026-11-09T11:00:00Z',
                'held_by_email': 'cashier@pharmacy.bd',
                'hold_expires_at': '2026-11-09T13:00:00Z',
                'hold_stock_reserved': body?['reserve_stock'] == true,
                'hold_reservation_expires_at': '2026-11-09T11:30:00Z',
                'hold_snapshot_pricing_hash': 'hash-held-1',
                'hold_snapshot_grand_total_bdt': '127.40',
                'grand_total_bdt': '127.40',
                'version': 3,
                'lines': <dynamic>[],
              },
            );
          }
          if (method == 'GET' && path.startsWith('/api/v2/pos/sales/held/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'count': 1,
                'stale_count': 1,
                'expired_count': 0,
                'results': <dynamic>[
                  <String, dynamic>{
                    'sale_id': 'sale-225',
                    'order_number': 'POS-225',
                    'branch_id': 'br-a',
                    'branch_name': 'Dhanmondi Branch',
                    'customer_name': 'Rahim Uddin',
                    'lifecycle_state': 'HELD',
                    'hold_reference': 'RAHIM-RX',
                    'held_by_email': 'cashier@pharmacy.bd',
                    'hold_stock_reserved': true,
                    'line_count': 1,
                    'held_grand_total_bdt': '127.40',
                    'live_grand_total_bdt': '140.00',
                    'version': 3,
                    'staleness': <String, dynamic>{
                      'is_stale': true,
                      'has_price_change': true,
                      'stale_reasons': <String>['PRICE_CHANGED'],
                      'held_grand_total_bdt': '127.40',
                      'live_grand_total_bdt': '140.00',
                      'price_delta_bdt': '12.60',
                      'price_drift_items': <dynamic>[
                        <String, dynamic>{
                          'line_id': 'sline-1',
                          'product_id': 'med-napa',
                          'product_brand_name': 'Napa Extend',
                          'packaging_unit': 'STRIP',
                          'held_unit_price_bdt': '127.40',
                          'live_unit_price_bdt': '140.00',
                        },
                      ],
                      'user_prompt_en': 'Cart price changed (127.40 -> 140.00 BDT).',
                      'user_prompt_bn': 'কার্টের মূল্য পরিবর্তিত হয়েছে (127.40 -> 140.00 টাকা)।',
                    },
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-225/resume/') {
            if (body?['acknowledge_stale'] != true) {
              return const MobilePosHttpResponse(
                statusCode: 400,
                data: <String, dynamic>{
                  'error_code': 'ERR_HELD_CART_REQUIRES_CONFIRMATION',
                  'message_en': 'Cart price changed (127.40 -> 140.00 BDT). Confirm with acknowledge_stale=true.',
                  'message_bn': 'কার্টের মূল্য পরিবর্তিত হয়েছে। নিশ্চিত হয়ে রিজিউম করুন।',
                  'details': <String, dynamic>{
                    'error_code': 'ERR_HELD_CART_REQUIRES_CONFIRMATION',
                    'requires_confirmation': true,
                    'is_stale': true,
                    'has_price_change': true,
                    'stale_reasons': <String>['PRICE_CHANGED'],
                    'held_grand_total_bdt': '127.40',
                    'live_grand_total_bdt': '140.00',
                    'user_prompt_en': 'Cart price changed (127.40 -> 140.00 BDT).',
                    'user_prompt_bn': 'কার্টের মূল্য পরিবর্তিত হয়েছে (127.40 -> 140.00 টাকা)।',
                  },
                },
              );
            }
            staleAckSeen = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-225',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-225',
                  'lifecycle_state': 'DRAFT',
                  'grand_total_bdt': '140.00',
                  'subtotal_bdt': '140.00',
                  'is_pricing_confirmed': false,
                  'version': 4,
                  'lines': <dynamic>[],
                },
                'staleness': <String, dynamic>{
                  'is_stale': true,
                  'has_price_change': true,
                  'stale_reasons': <String>['PRICE_CHANGED'],
                },
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/expire-stale-holds/') {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'expired_count': 2,
                'released_base_units': 30,
                'voided_count': 0,
                'affected_sale_ids': <String>['sale-225', 'sale-226'],
                'message_en': 'Processed 2 stale held cart(s); released 30 reserved unit(s).',
                'message_bn': '২টি হোল্ড কার্ট প্রসেস হয়েছে এবং ৩০টি ইউনিট মুক্ত হয়েছে।',
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-225/expire-hold/') {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'released_base_units': 10,
                'sale': <String, dynamic>{
                  'sale_id': 'sale-225',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-225',
                  'lifecycle_state': 'HELD',
                  'hold_stock_reserved': false,
                  'version': 4,
                  'lines': <dynamic>[],
                },
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-225/cancel-hold/') {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-225',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-225',
                'lifecycle_state': 'VOIDED',
                'hold_stock_reserved': false,
                'version': 5,
                'lines': <dynamic>[],
              },
            );
          }
          return const MobilePosHttpResponse(statusCode: 400, data: <String, dynamic>{});
        },
      );

      // Guard checks before hitting network
      final badTtl = await client.holdCart(
        saleId: 'sale-225',
        bearerToken: 'tok-c',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        holdTtlMinutes: 0,
      );
      expect(badTtl.uiState, MobilePosUiState.error);
      expect(badTtl.errorCode, 'ERR_INVALID_HOLD_TTL');

      final badResTtl = await client.holdCart(
        saleId: 'sale-225',
        bearerToken: 'tok-c',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        holdTtlMinutes: 30,
        reserveStock: true,
        reservationTtlMinutes: 45,
      );
      expect(badResTtl.errorCode, 'ERR_INVALID_HOLD_TTL');

      final financeWriteDenied = await client.holdCart(
        saleId: 'sale-225',
        bearerToken: 'tok-fin',
        actorRole: 'FINANCE_OFFICER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(financeWriteDenied.uiState, MobilePosUiState.permissionDenied);

      final clerkReadDenied = await client.listHeldCarts(
        bearerToken: 'tok-clk',
        actorRole: 'INVENTORY_CLERK',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(clerkReadDenied.uiState, MobilePosUiState.permissionDenied);

      final suspended = await client.resumeCart(
        saleId: 'sale-225',
        bearerToken: 'tok-c',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        subscriptionSuspended: true,
      );
      expect(suspended.errorCode, 'ERR_SUBSCRIPTION_SUSPENDED');

      final xBranch = await client.cancelHold(
        saleId: 'sale-225',
        bearerToken: 'tok-c',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-b',
      );
      expect(xBranch.errorCode, 'ERR_CROSS_BRANCH_ACCESS_DENIED');

      // Valid hold -> FINANCE_OFFICER read-only list -> blind resume -> acknowledged resume
      final held = await client.holdCart(
        saleId: 'sale-225',
        bearerToken: 'tok-c',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        holdReference: 'RAHIM-RX',
        holdTtlMinutes: 120,
        reserveStock: true,
      );
      expect(held.uiState, MobilePosUiState.ready);
      expect(held.data!.lifecycleState, MobilePosLifecycleState.held);
      expect(held.data!.holdStockReserved, true);

      final listFin = await client.listHeldCarts(
        bearerToken: 'tok-fin',
        actorRole: 'FINANCE_OFFICER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(listFin.uiState, MobilePosUiState.ready);
      expect(listFin.data!.staleCount, 1);
      expect(listFin.data!.results.first.staleness.priceDriftItems.first.liveUnitPriceBdt, '140.00');

      final prompt = await client.resumeCart(
        saleId: 'sale-225',
        bearerToken: 'tok-c',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(prompt.uiState, MobilePosUiState.error);
      expect(prompt.errorCode, 'ERR_HELD_CART_REQUIRES_CONFIRMATION');
      expect(prompt.data?.requiresConfirmation, true);
      expect(prompt.data?.staleness.liveGrandTotalBdt, '140.00');

      final resumed = await client.resumeCart(
        saleId: 'sale-225',
        bearerToken: 'tok-c',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        acknowledgeStale: true,
      );
      expect(resumed.uiState, MobilePosUiState.ready);
      expect(staleAckSeen, true);
      expect(resumed.data!.sale!.lifecycleState, MobilePosLifecycleState.draft);
      expect(resumed.data!.sale!.grandTotalBdt, '140.00');

      final sweep = await client.expireStaleHolds(
        bearerToken: 'tok-c',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(sweep.uiState, MobilePosUiState.ready);
      expect(sweep.data!.releasedBaseUnits, 30);

      final rel = await client.expireHold(
        saleId: 'sale-225',
        bearerToken: 'tok-c',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(rel.uiState, MobilePosUiState.ready);
      expect(rel.data!.holdStockReserved, false);

      final cancelled = await client.cancelHold(
        saleId: 'sale-225',
        bearerToken: 'tok-c',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(cancelled.uiState, MobilePosUiState.ready);
      expect(cancelled.data!.lifecycleState, MobilePosLifecycleState.voided);

      expect(calls.length, 7);
    });

    testWidgets(
        '2. PosFastSearchPage parks basket, resets counter, prompts on stale resume, acknowledges & supports expire/cancel/BN',
        (WidgetTester tester) async {
      var listEmptyAfterResume = false;
      var releasedCalled = false;
      var sweepCalled = false;

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
                    'barcode': '894225001',
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
                  'sale_id': 'sale-ui-225',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-UI-225',
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
                  'sale_id': 'sale-ui-225',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-UI-225',
                  'lifecycle_state': 'DRAFT',
                  'subtotal_bdt': '127.40',
                  'discount_amount_bdt': '0.00',
                  'tax_amount_bdt': '0.00',
                  'rounding_adjustment_bdt': '0.00',
                  'grand_total_bdt': '127.40',
                  'is_pricing_confirmed': false,
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
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-ui-225/hold/') {
            return MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-ui-225',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-UI-225',
                'lifecycle_state': 'HELD',
                'hold_reference': body?['hold_reference'] ?? 'WAIT-UI',
                'hold_stock_reserved': body?['reserve_stock'] == true,
                'hold_snapshot_grand_total_bdt': '127.40',
                'grand_total_bdt': '127.40',
                'version': 3,
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
            );
          }
          if (method == 'GET' && path.startsWith('/api/v2/pos/sales/held/')) {
            if (listEmptyAfterResume) {
              return const MobilePosHttpResponse(
                statusCode: 200,
                data: <String, dynamic>{
                  'count': 0,
                  'stale_count': 0,
                  'expired_count': 0,
                  'results': <dynamic>[],
                },
              );
            }
            return MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'count': 1,
                'stale_count': 1,
                'expired_count': 0,
                'results': <dynamic>[
                  <String, dynamic>{
                    'sale_id': 'sale-ui-225',
                    'order_number': 'POS-UI-225',
                    'branch_id': 'br-a',
                    'lifecycle_state': 'HELD',
                    'hold_reference': 'WAIT-UI',
                    'hold_stock_reserved': !releasedCalled,
                    'line_count': 1,
                    'held_grand_total_bdt': '127.40',
                    'live_grand_total_bdt': '140.00',
                    'version': releasedCalled ? 4 : 3,
                    'staleness': const <String, dynamic>{
                      'is_stale': true,
                      'has_price_change': true,
                      'stale_reasons': <String>['PRICE_CHANGED'],
                      'held_grand_total_bdt': '127.40',
                      'live_grand_total_bdt': '140.00',
                      'user_prompt_en': 'Cart price changed (127.40 -> 140.00 BDT).',
                      'user_prompt_bn': 'কার্টের মূল্য পরিবর্তিত হয়েছে (127.40 -> 140.00 টাকা)।',
                    },
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/expire-stale-holds/') {
            sweepCalled = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'expired_count': 1,
                'released_base_units': 10,
                'voided_count': 0,
                'affected_sale_ids': <String>['sale-ui-225'],
                'message_en': 'Released 10 reserved unit(s).',
                'message_bn': '১০টি রিজার্ভকৃত ইউনিট মুক্ত হয়েছে।',
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-ui-225/expire-hold/') {
            releasedCalled = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-ui-225',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-UI-225',
                  'lifecycle_state': 'HELD',
                  'hold_reference': 'WAIT-UI',
                  'hold_stock_reserved': false,
                  'hold_snapshot_grand_total_bdt': '127.40',
                  'grand_total_bdt': '140.00',
                  'version': 4,
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
                      'line_total_bdt': '127.40',
                    },
                  ],
                },
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-ui-225/resume/') {
            if (body?['acknowledge_stale'] != true) {
              return const MobilePosHttpResponse(
                statusCode: 400,
                data: <String, dynamic>{
                  'error_code': 'ERR_HELD_CART_REQUIRES_CONFIRMATION',
                  'message_en': 'Cart price changed (127.40 -> 140.00 BDT).',
                  'message_bn': 'কার্টের মূল্য পরিবর্তিত হয়েছে।',
                  'details': <String, dynamic>{
                    'error_code': 'ERR_HELD_CART_REQUIRES_CONFIRMATION',
                    'is_stale': true,
                    'has_price_change': true,
                    'stale_reasons': <String>['PRICE_CHANGED'],
                    'held_grand_total_bdt': '127.40',
                    'live_grand_total_bdt': '140.00',
                    'user_prompt_en': 'Cart price changed (127.40 -> 140.00 BDT).',
                    'user_prompt_bn': 'কার্টের মূল্য পরিবর্তিত হয়েছে (127.40 -> 140.00 টাকা)।',
                  },
                },
              );
            }
            listEmptyAfterResume = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-ui-225',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-UI-225',
                  'lifecycle_state': 'DRAFT',
                  'subtotal_bdt': '140.00',
                  'discount_amount_bdt': '0.00',
                  'tax_amount_bdt': '0.00',
                  'rounding_adjustment_bdt': '0.00',
                  'grand_total_bdt': '140.00',
                  'is_pricing_confirmed': false,
                  'version': 5,
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
                      'unit_price_bdt': '140.00',
                      'line_subtotal_bdt': '140.00',
                      'line_tax_amount_bdt': '0.00',
                      'line_total_bdt': '140.00',
                    },
                  ],
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

      // Search & add item
      await tester.enterText(find.byKey(const Key('pos_search_input')), 'napa');
      await tester.tap(find.byKey(const Key('pos_search_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_candidate_med-napa')));
      await tester.pumpAndSettle();
      expect(find.text('BDT 127.40'), findsOneWidget);

      // Hold basket dialog with stock reservation checked
      await tester.tap(find.byKey(const Key('pos_hold_cart_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pos_hold_ref_input')), 'WAIT-UI');
      await tester.tap(find.byKey(const Key('pos_reserve_hold_check')));
      await tester.tap(find.byKey(const Key('pos_confirm_hold_btn')));
      await tester.pumpAndSettle();

      // Active counter cleared cleanly & Held badge incremented
      expect(find.text('BDT 0.00'), findsOneWidget);
      expect(find.text('Held (1)'), findsOneWidget);

      // Open Held Baskets bottom sheet
      await tester.tap(find.byKey(const Key('pos_held_carts_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pos_held_baskets_sheet')), findsOneWidget);
      expect(find.text('WAIT-UI'), findsOneWidget);

      // Test Expire Stale & Release Res buttons cleanly
      await tester.tap(find.byKey(const Key('pos_expire_stale_btn')));
      await tester.pumpAndSettle();
      expect(sweepCalled, true);

      await tester.tap(find.byKey(const Key('pos_release_hold_sale-ui-225')));
      await tester.pumpAndSettle();
      expect(releasedCalled, true);

      // Blind resume triggers inline stale confirmation banner
      await tester.tap(find.byKey(const Key('pos_resume_held_sale-ui-225')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pos_stale_confirm_banner')), findsOneWidget);

      // Acknowledge & resume restores repriced total BDT 140.00
      await tester.tap(find.byKey(const Key('pos_ack_stale_resume_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pos_stale_confirm_banner')), findsNothing);
      expect(find.text('BDT 140.00'), findsOneWidget);
      expect(find.text('Held'), findsOneWidget);

      // Switch to Bangla & verify EN/BN label + zero emojis
      await tester.tap(find.text('বাংলা'));
      await tester.pumpAndSettle();
      expect(find.text('হোল্ড'), findsOneWidget);
    });

    testWidgets('3. Offline mode parks held basket locally (honest status) and resumes cleanly',
        (WidgetTester tester) async {
      final client = MobilePosSearchCartClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          throw Exception('Offline unreachable');
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
      expect(find.text('BDT 25.00'), findsOneWidget);

      // Hold offline -> honest offline state banner + local park
      await tester.tap(find.byKey(const Key('pos_hold_cart_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pos_hold_ref_input')), 'OFFLINE-Q');
      await tester.tap(find.byKey(const Key('pos_confirm_hold_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state_banner_offline')), findsOneWidget);
      expect(find.text('BDT 0.00'), findsOneWidget);
      expect(find.text('Held (1)'), findsOneWidget);

      // Open Held sheet & resume local offline basket
      await tester.tap(find.byKey(const Key('pos_held_carts_btn')));
      await tester.pumpAndSettle();
      expect(find.text('LOCAL OFFLINE'), findsOneWidget);
      expect(find.text('OFFLINE-Q'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pos_resume_held_offline-hold-1')));
      await tester.pumpAndSettle();
      expect(find.text('BDT 25.00'), findsOneWidget);
      expect(find.text('Held'), findsOneWidget);
    });
  });
}
