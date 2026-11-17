import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_search_cart_client.dart';
import 'package:pharmacy_mobile_manager/features/pos/pos_fast_search_page.dart';

void main() {
  group('P228: Mobile POS FEFO & Atomic Lot Allocation at Checkout', () {
    test('1. Client parses FefoAllocationPlan, enforces override validation/RBAC & commits override on finalize',
        () async {
      var sawOverrideInFinalize = false;

      final domainClient = MobilePosDomainClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          if (method == 'GET' && path == '/api/v2/pos/sales/sale-m-fefo/fefo-plan/') {
            final isMgr = (bearerToken ?? '').contains('mgr');
            return MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-m-fefo',
                'order_number': 'POS-FEFO-M1',
                'fefo_allocation_status': 'PENDING',
                'fefo_ready': true,
                'has_expired_block': true,
                'has_quarantined_block': true,
                'total_requested_base_units': 15,
                'total_planned_base_units': 15,
                'total_estimated_cost_bdt': isMgr ? '28.0000' : null,
                'version': 2,
                'lines': <dynamic>[
                  <String, dynamic>{
                    'line_id': 'ln-m-1',
                    'line_number': 1,
                    'product_id': 'med-napa',
                    'brand_name': 'Napa Extra',
                    'packaging_unit': 'TABLET',
                    'requested_base_units': 15,
                    'planned_base_units': 15,
                    'is_fulfilled': true,
                    'planned_lots': <dynamic>[
                      <String, dynamic>{
                        'fefo_sequence': 1,
                        'batch_id': 'bat-1',
                        'batch_number': 'LOT-A-EARLY',
                        'expiry_date': '2026-12-10',
                        'cost_lot_id': 'lot-1a',
                        'allocated_base_units': 7,
                        'allocation_mode': 'FEFO_AUTO',
                        'unit_cost_bdt': isMgr ? '1.5000' : null,
                      },
                      <String, dynamic>{
                        'fefo_sequence': 2,
                        'batch_id': 'bat-1',
                        'batch_number': 'LOT-A-EARLY',
                        'expiry_date': '2026-12-10',
                        'cost_lot_id': 'lot-1b',
                        'allocated_base_units': 5,
                        'allocation_mode': 'FEFO_AUTO',
                      },
                      <String, dynamic>{
                        'fefo_sequence': 3,
                        'batch_id': 'bat-2',
                        'batch_number': 'LOT-B-SECOND',
                        'expiry_date': '2027-02-10',
                        'cost_lot_id': 'lot-2',
                        'allocated_base_units': 3,
                        'allocation_mode': 'FEFO_AUTO',
                      },
                    ],
                    'blocked_lots': <dynamic>[
                      <String, dynamic>{
                        'batch_id': 'bat-q',
                        'batch_number': 'LOT-QUAR',
                        'block_category': 'QUARANTINED',
                        'quantity_base_units': 40,
                        'reason': 'Quarantined lot skipped',
                      },
                    ],
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-m-fefo/allocate/') {
            final ov = body?['batch_overrides'] as Map?;
            if ((bearerToken ?? '').contains('cashier') && ov != null && ov.isNotEmpty) {
              return const MobilePosHttpResponse(
                statusCode: 403,
                data: <String, dynamic>{
                  'error_code': 'ERR_FEFO_OVERRIDE_REQUIRES_APPROVAL',
                  'detail': 'Manual FEFO batch override requires Pharmacist/Manager approval.',
                },
              );
            }
            if (ov?.values.contains('bat-exp') == true) {
              return const MobilePosHttpResponse(
                statusCode: 422,
                data: <String, dynamic>{
                  'error_code': 'ERR_BATCH_EXPIRED',
                  'detail': 'Expired batch cannot be dispensed.',
                },
              );
            }
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-m-fefo',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-FEFO-M1',
                'lifecycle_state': 'CONFIRMED',
                'fefo_allocation_status': 'RESERVED',
                'version': 3,
                'lines': <dynamic>[],
                'allocations': <dynamic>[
                  <String, dynamic>{
                    'allocation_id': 'al-1',
                    'sale_line_id': 'ln-m-1',
                    'batch_id': 'bat-late',
                    'batch_number': 'LOT-LATE',
                    'allocation_mode': 'MANUAL_OVERRIDE',
                    'override_reason': 'Ward requested long expiry',
                    'allocated_base_units': 15,
                    'status': 'RESERVED',
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-m-fefo/finalize/') {
            final ov = body?['batch_overrides'] as Map?;
            if (ov?['ln-m-1'] == 'bat-late' && body?['override_reason'] == 'Ward requested long expiry') {
              sawOverrideInFinalize = true;
            }
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-m-fefo',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-FEFO-M1',
                'lifecycle_state': 'FINALIZED',
                'fefo_allocation_status': 'COMMITTED',
                'version': 4,
                'lines': <dynamic>[],
                'allocations': <dynamic>[
                  <String, dynamic>{
                    'allocation_id': 'al-1',
                    'sale_line_id': 'ln-m-1',
                    'batch_id': 'bat-late',
                    'batch_number': 'LOT-LATE',
                    'allocation_mode': 'MANUAL_OVERRIDE',
                    'allocated_base_units': 15,
                    'status': 'COMMITTED',
                  },
                ],
              },
            );
          }
          return const MobilePosHttpResponse(statusCode: 404, data: <String, dynamic>{});
        },
      );

      final cashPlan = await domainClient.getFefoPlan(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-fefo',
      );
      expect(cashPlan.uiState, MobilePosUiState.ready);
      expect(cashPlan.data!.totalEstimatedCostBdt, isNull);
      expect(cashPlan.data!.lines.first.plannedLots.length, 3);
      expect(cashPlan.data!.lines.first.blockedLots.first.blockCategory, 'QUARANTINED');

      final mgrPlan = await domainClient.getFefoPlan(
        bearerToken: 'tok-mgr',
        actorRole: 'BRANCH_MANAGER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-fefo',
      );
      expect(mgrPlan.data!.totalEstimatedCostBdt, '28.0000');

      final shortReason = await domainClient.allocateStockFefo(
        bearerToken: 'tok-mgr',
        actorRole: 'BRANCH_MANAGER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-fefo',
        batchOverrides: const <String, String>{'ln-m-1': 'bat-late'},
        overrideReason: 'x',
      );
      expect(shortReason.uiState, MobilePosUiState.error);
      expect(shortReason.errorCode, 'ERR_FEFO_OVERRIDE_REASON_REQUIRED');

      final cashDenied = await domainClient.allocateStockFefo(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-fefo',
        batchOverrides: const <String, String>{'ln-m-1': 'bat-late'},
        overrideReason: 'Customer wanted newer lot',
      );
      expect(cashDenied.uiState, MobilePosUiState.permissionDenied);
      expect(cashDenied.errorCode, 'ERR_FEFO_OVERRIDE_REQUIRES_APPROVAL');

      final expReject = await domainClient.allocateStockFefo(
        bearerToken: 'tok-mgr',
        actorRole: 'BRANCH_MANAGER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-fefo',
        batchOverrides: const <String, String>{'ln-m-1': 'bat-exp'},
        overrideReason: 'Trying expired lot',
      );
      expect(expReject.uiState, MobilePosUiState.error);
      expect(expReject.errorCode, 'ERR_BATCH_EXPIRED');

      final mgrReserve = await domainClient.allocateStockFefo(
        bearerToken: 'tok-mgr',
        actorRole: 'BRANCH_MANAGER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-fefo',
        batchOverrides: const <String, String>{'ln-m-1': 'bat-late'},
        overrideReason: 'Ward requested long expiry',
      );
      expect(mgrReserve.uiState, MobilePosUiState.ready);
      expect(mgrReserve.data!.fefoAllocationStatus, 'RESERVED');

      final fin = await domainClient.finalizeSale(
        bearerToken: 'tok-mgr',
        actorRole: 'BRANCH_MANAGER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-fefo',
        batchOverrides: const <String, String>{'ln-m-1': 'bat-late'},
        overrideReason: 'Ward requested long expiry',
      );
      expect(fin.uiState, MobilePosUiState.ready);
      expect(fin.data!.fefoAllocationStatus, 'COMMITTED');
      expect(sawOverrideInFinalize, isTrue);
    });

    testWidgets('2. PosFastSearchPage opens FEFO lot sheet, rejects Cashier override, allows Manager override & checkout cleanly',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var reserved = false;
      var finalized = false;

      final client = MobilePosSearchCartClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          if (method == 'GET' && path.contains('/api/v2/pos/search/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'results': <dynamic>[
                  <String, dynamic>{
                    'product_id': 'med-napa',
                    'sku_code': 'NAPA-500',
                    'brand_name': 'Napa 500',
                    'generic_name': 'Paracetamol',
                    'resolved_packaging_unit': 'STRIP',
                    'resolved_conversion_factor': 10,
                    'unit_price_bdt': '12.00',
                    'base_unit_price_bdt': '1.20',
                    'sellable_base_units': 50,
                    'available_base_units': 50,
                    'requires_rx_verification': false,
                    'regulatory_classification': 'OTC',
                    'is_sellable': true,
                    'packaging_options': <dynamic>[
                      <String, dynamic>{
                        'packaging_unit': 'STRIP',
                        'label_en': 'Strip (10)',
                        'label_bn': 'পাতা (১০)',
                        'conversion_factor': 10,
                        'unit_price_bdt': '12.00',
                        'is_allowed': true,
                      },
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
                  'sale_id': 'sale-ui-fefo',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-FEFO-UI1',
                  'lifecycle_state': 'DRAFT',
                  'fefo_allocation_status': 'PENDING',
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
                  'sale_id': 'sale-ui-fefo',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-FEFO-UI1',
                  'lifecycle_state': 'DRAFT',
                  'fefo_allocation_status': 'PENDING',
                  'subtotal_bdt': '12.00',
                  'grand_total_bdt': '12.00',
                  'version': 2,
                  'lines': <dynamic>[
                    <String, dynamic>{
                      'line_id': 'ln-otc-m1',
                      'line_number': 1,
                      'product_id': 'med-napa',
                      'product_brand_name': 'Napa 500',
                      'packaging_unit': 'STRIP',
                      'quantity_units': 1,
                      'conversion_factor': 10,
                      'base_units_total': 10,
                      'unit_price_bdt': '12.00',
                      'line_subtotal_bdt': '12.00',
                      'line_total_bdt': '12.00',
                      'regulatory_classification': 'OTC',
                      'requires_rx_verification': false,
                    },
                  ],
                },
              },
            );
          }
          if (method == 'GET' && path == '/api/v2/pos/sales/sale-ui-fefo/fefo-plan/') {
            return MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-ui-fefo',
                'order_number': 'POS-FEFO-UI1',
                'fefo_allocation_status': reserved ? 'RESERVED' : 'PENDING',
                'fefo_ready': true,
                'total_requested_base_units': 10,
                'total_planned_base_units': 10,
                'lines': <dynamic>[
                  <String, dynamic>{
                    'line_id': 'ln-otc-m1',
                    'product_id': 'med-napa',
                    'brand_name': 'Napa 500',
                    'requested_base_units': 10,
                    'planned_base_units': 10,
                    'planned_lots': <dynamic>[
                      <String, dynamic>{
                        'fefo_sequence': 1,
                        'batch_id': 'bat-early',
                        'batch_number': 'LOT-A-EARLIER',
                        'expiry_date': '2026-12-20',
                        'allocated_base_units': 10,
                        'allocation_mode': 'FEFO_AUTO',
                      },
                    ],
                    'blocked_lots': <dynamic>[
                      <String, dynamic>{
                        'batch_id': 'bat-q',
                        'batch_number': 'LOT-QUAR',
                        'block_category': 'QUARANTINED',
                        'quantity_base_units': 20,
                        'reason': 'Quarantined lot blocked',
                      },
                    ],
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-ui-fefo/allocate/') {
            if ((bearerToken ?? '').contains('cashier')) {
              return const MobilePosHttpResponse(
                statusCode: 403,
                data: <String, dynamic>{
                  'error_code': 'ERR_FEFO_OVERRIDE_REQUIRES_APPROVAL',
                  'detail': 'Pharmacist or Manager approval required for FEFO override.',
                },
              );
            }
            reserved = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-ui-fefo',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-FEFO-UI1',
                'lifecycle_state': 'CONFIRMED',
                'fefo_allocation_status': 'RESERVED',
                'subtotal_bdt': '12.00',
                'grand_total_bdt': '12.00',
                'version': 3,
                'lines': <dynamic>[
                  <String, dynamic>{
                    'line_id': 'ln-otc-m1',
                    'line_number': 1,
                    'product_id': 'med-napa',
                    'product_brand_name': 'Napa 500',
                    'packaging_unit': 'STRIP',
                    'quantity_units': 1,
                    'conversion_factor': 10,
                    'base_units_total': 10,
                    'unit_price_bdt': '12.00',
                    'line_subtotal_bdt': '12.00',
                    'line_total_bdt': '12.00',
                  },
                ],
                'allocations': <dynamic>[
                  <String, dynamic>{
                    'allocation_id': 'al-1',
                    'sale_line_id': 'ln-otc-m1',
                    'batch_id': 'bat-newer',
                    'batch_number': 'LOT-B-NEWER',
                    'allocation_mode': 'MANUAL_OVERRIDE',
                    'allocated_base_units': 10,
                    'status': 'RESERVED',
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path.endsWith('/record-payment/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-ui-fefo',
                'lifecycle_state': 'CONFIRMED',
                'version': 3,
              },
            );
          }
          if (method == 'POST' && path.endsWith('/finalize/')) {
            finalized = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-ui-fefo',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-FEFO-UI1',
                'lifecycle_state': 'FINALIZED',
                'fefo_allocation_status': 'COMMITTED',
                'version': 4,
                'allocations': <dynamic>[
                  <String, dynamic>{
                    'allocation_id': 'al-1',
                    'sale_line_id': 'ln-otc-m1',
                    'batch_id': 'bat-newer',
                    'batch_number': 'LOT-B-NEWER',
                    'allocated_base_units': 10,
                    'status': 'COMMITTED',
                  },
                ],
              },
            );
          }
          return const MobilePosHttpResponse(statusCode: 404, data: <String, dynamic>{});
        },
      );

      // Start as Cashier: search & add OTC
      await tester.pumpWidget(
        MaterialApp(
          home: PosFastSearchPage(
            client: client,
            bearerToken: 'tok-cashier',
            actorRole: 'CASHIER',
            actorTenantId: 'ten-a',
            actorBranchId: 'br-a',
            targetTenantId: 'ten-a',
            targetBranchId: 'br-a',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('pos_search_input')), 'napa');
      await tester.tap(find.byKey(const Key('pos_search_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_candidate_med-napa')));
      await tester.pumpAndSettle();

      // Open FEFO sheet -> see earliest safe batch + quarantined block
      await tester.tap(find.byKey(const Key('pos_fefo_plan_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pos_fefo_plan_sheet')), findsOneWidget);
      expect(find.textContaining('LOT-A-EARLIER'), findsOneWidget);
      expect(find.textContaining('QUARANTINED'), findsOneWidget);

      // Cashier manual override denied (403)
      await tester.enterText(find.byKey(const Key('pos_fefo_override_batch_field')), 'bat-newer');
      await tester.enterText(find.byKey(const Key('pos_fefo_override_reason_field')), 'Ward requested newer date');
      await tester.tap(find.byKey(const Key('pos_fefo_reserve_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pharmacist or Manager approval required'), findsWidgets);

      Navigator.of(tester.element(find.byKey(const Key('pos_fefo_plan_sheet')))).pop();
      await tester.pumpAndSettle();

      // Pump fresh Manager session page with distinct Key so widget state is isolated
      await tester.pumpWidget(
        MaterialApp(
          home: PosFastSearchPage(
            key: const Key('pos_fefo_mgr_page'),
            client: client,
            bearerToken: 'tok-mgr',
            actorRole: 'BRANCH_MANAGER',
            actorTenantId: 'ten-a',
            actorBranchId: 'br-a',
            targetTenantId: 'ten-a',
            targetBranchId: 'br-a',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pos_search_input')), 'napa');
      await tester.tap(find.byKey(const Key('pos_search_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_candidate_med-napa')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pos_fefo_plan_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pos_fefo_override_batch_field')), 'bat-newer');
      await tester.enterText(find.byKey(const Key('pos_fefo_override_reason_field')), 'Ward requested newer date');
      await tester.tap(find.byKey(const Key('pos_fefo_reserve_btn')));
      await tester.pumpAndSettle();
      expect(reserved, isTrue);

      Navigator.of(tester.element(find.byKey(const Key('pos_fefo_plan_sheet')))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pos_checkout_btn')));
      await tester.pumpAndSettle();
      expect(finalized, isTrue);
      expect(find.textContaining('LOT-B-NEWER'), findsOneWidget);
    });

    testWidgets('3. Offline mode blocks expired cached OTC lot and permits safe offline OTC with OFFLINE_PROVISIONAL_FEFO',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = MobilePosSearchCartClient(baseUrl: 'http://localhost:8000');
      client.seedOfflineSnapshot('br-a', const <MobileFastSearchCandidate>[
        MobileFastSearchCandidate(
          productId: 'med-exp-off',
          skuCode: 'EXP-100',
          displayName: 'OldMed 100mg',
          brandName: 'OldMed',
          brandNameBn: 'ওল্ডমেড',
          genericName: 'OldGen',
          genericNameBn: 'জেনেরিক',
          strength: '100mg',
          dosageForm: 'Tablet',
          barcode: '8949991',
          shelfLocation: 'B-1',
          resolutionSource: 'OFFLINE_SNAPSHOT',
          resolvedPackagingUnit: 'TABLET',
          resolvedConversionFactor: 1,
          unitPriceBdt: '5.00',
          baseUnitPriceBdt: '5.00',
          sellableBaseUnits: 10,
          reservedBaseUnits: 0,
          availableBaseUnits: 10,
          quarantinedBaseUnits: 0,
          expiredBaseUnits: 0,
          recalledBaseUnits: 0,
          earliestBatchNumber: 'LOT-OLD',
          earliestExpiryDate: '2020-01-01',
          nearExpiryWarning: true,
          requiresRxVerification: false,
          regulatoryClassification: 'OTC',
          nonDivisibleSealedOnly: false,
          isSellable: true,
          blockReason: '',
          snapshotChecksum: 'chk-p228-exp',
          rankScore: 100,
          packagingOptions: <MobilePackagingOption>[
            MobilePackagingOption(
              packagingUnit: 'TABLET',
              labelEn: 'Tablet',
              labelBn: 'ট্যাবলেট',
              conversionFactor: 1,
              unitPriceBdt: '5.00',
            ),
          ],
        ),
        MobileFastSearchCandidate(
          productId: 'med-safe-off',
          skuCode: 'SAFE-100',
          displayName: 'SafeMed 100mg',
          brandName: 'SafeMed',
          brandNameBn: 'সেফমেড',
          genericName: 'SafeGen',
          genericNameBn: 'সেফ',
          strength: '100mg',
          dosageForm: 'Tablet',
          barcode: '8949992',
          shelfLocation: 'B-2',
          resolutionSource: 'OFFLINE_SNAPSHOT',
          resolvedPackagingUnit: 'TABLET',
          resolvedConversionFactor: 1,
          unitPriceBdt: '5.00',
          baseUnitPriceBdt: '5.00',
          sellableBaseUnits: 20,
          reservedBaseUnits: 0,
          availableBaseUnits: 20,
          quarantinedBaseUnits: 0,
          expiredBaseUnits: 0,
          recalledBaseUnits: 0,
          earliestBatchNumber: 'LOT-SAFE',
          earliestExpiryDate: '2028-12-31',
          nearExpiryWarning: false,
          requiresRxVerification: false,
          regulatoryClassification: 'OTC',
          nonDivisibleSealedOnly: false,
          isSellable: true,
          blockReason: '',
          snapshotChecksum: 'chk-p228-safe',
          rankScore: 100,
          packagingOptions: <MobilePackagingOption>[
            MobilePackagingOption(
              packagingUnit: 'TABLET',
              labelEn: 'Tablet',
              labelBn: 'ট্যাবলেট',
              conversionFactor: 1,
              unitPriceBdt: '5.00',
            ),
          ],
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: PosFastSearchPage(
            client: client,
            bearerToken: 'tok-cashier',
            actorRole: 'CASHIER',
            actorTenantId: 'ten-a',
            actorBranchId: 'br-a',
            targetTenantId: 'ten-a',
            targetBranchId: 'br-a',
            isOffline: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1) Expired cached batch blocked cleanly on offline checkout!
      await tester.enterText(find.byKey(const Key('pos_search_input')), 'OldMed');
      await tester.tap(find.byKey(const Key('pos_search_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_candidate_med-exp-off')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pos_checkout_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ERR_BATCH_EXPIRED'), findsOneWidget);
      expect(find.byKey(const Key('pos_checkout_btn')), findsOneWidget);

      // Clear blocked cart cleanly via distinct widget Key for safe offline OTC checkout
      await tester.pumpWidget(
        MaterialApp(
          home: PosFastSearchPage(
            key: const Key('pos_fefo_off_safe_page'),
            client: client,
            bearerToken: 'tok-cashier',
            actorRole: 'CASHIER',
            actorTenantId: 'ten-a',
            actorBranchId: 'br-a',
            targetTenantId: 'ten-a',
            targetBranchId: 'br-a',
            isOffline: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pos_search_input')), 'SafeMed');
      await tester.tap(find.byKey(const Key('pos_search_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_candidate_med-safe-off')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pos_checkout_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('OFFLINE_PROVISIONAL_FEFO'), findsOneWidget);
      expect(find.byKey(const Key('pos_checkout_btn')), findsNothing);
    });
  });
}
