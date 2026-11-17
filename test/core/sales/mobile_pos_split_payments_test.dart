import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_search_cart_client.dart';
import 'package:pharmacy_mobile_manager/features/pos/pos_fast_search_page.dart';

void main() {
  group('P229: Mobile POS Cash & Verified Split Payments + Reconciliation', () {
    test('1. Client validates digital refs, offline MFS limits, cash change, verify/void & shift reconciliation',
        () async {
      var postedSplit = false;
      var verifiedAttempt = false;
      var voidedAttempt = false;

      final client = MobilePosDomainClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-split-1/split-payments/') {
            postedSplit = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-split-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-SP-100',
                  'lifecycle_state': 'CONFIRMED',
                  'grand_total_bdt': '120.00',
                  'paid_amount_bdt': '120.00',
                  'due_amount_bdt': '0.00',
                  'change_returned_bdt': '50.00',
                  'version': 2,
                  'payment_attempts': <dynamic>[
                    <String, dynamic>{
                      'attempt_id': 'att-1',
                      'attempt_number': 1,
                      'tender_type': 'BKASH',
                      'amount_bdt': '70.00',
                      'change_given_bdt': '0.00',
                      'net_settled_amount_bdt': '70.00',
                      'status': 'CAPTURED',
                      'verification_status': 'VERIFIED',
                      'verification_channel': 'BKASH_VERIFIED_REF',
                      'gateway_reference': 'BK-TRX-8821',
                      'idempotency_key': 'split-1-1',
                    },
                    <String, dynamic>{
                      'attempt_id': 'att-2',
                      'attempt_number': 2,
                      'tender_type': 'CASH',
                      'amount_bdt': '100.00',
                      'change_given_bdt': '50.00',
                      'net_settled_amount_bdt': '50.00',
                      'status': 'CAPTURED',
                      'verification_status': 'NOT_REQUIRED',
                      'verification_channel': 'CASH_DRAWER',
                      'idempotency_key': 'split-1-2',
                    },
                  ],
                },
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-split-1/verify-payment-attempt/') {
            verifiedAttempt = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-split-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-SP-100',
                  'lifecycle_state': 'CONFIRMED',
                  'grand_total_bdt': '120.00',
                  'paid_amount_bdt': '120.00',
                  'due_amount_bdt': '0.00',
                  'change_returned_bdt': '0.00',
                  'version': 3,
                },
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-split-1/void-payment-attempt/') {
            voidedAttempt = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-split-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-SP-100',
                  'lifecycle_state': 'DRAFT',
                  'grand_total_bdt': '120.00',
                  'paid_amount_bdt': '50.00',
                  'due_amount_bdt': '0.00',
                  'change_returned_bdt': '0.00',
                  'version': 4,
                },
              },
            );
          }
          if (method == 'GET' && path.startsWith('/api/v2/pos/sales/close-reconciliation/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'branch_id': 'br-a',
                'branch_name': 'Dhanmondi',
                'opening_float_bdt': '500.00',
                'gross_cash_tendered_bdt': '100.00',
                'cash_change_returned_bdt': '50.00',
                'net_cash_collected_bdt': '50.00',
                'cash_refunded_bdt': '0.00',
                'expected_drawer_cash_bdt': '550.00',
                'digital_total_bdt': '70.00',
                'due_issued_bdt': '0.00',
                'sales_count': 1,
                'reversed_sales_count': 0,
                'journal_balanced': true,
                'status': 'PREVIEW',
                'tender_totals': <String, dynamic>{
                  'CASH': <String, dynamic>{'net_bdt': '50.00'},
                  'BKASH': <String, dynamic>{'net_bdt': '70.00'},
                },
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/close-reconciliation/') {
            return const MobilePosHttpResponse(
              statusCode: 201,
              data: <String, dynamic>{
                'reconciliation_id': 'pcr-100',
                'branch_id': 'br-a',
                'branch_name': 'Dhanmondi',
                'opening_float_bdt': '500.00',
                'gross_cash_tendered_bdt': '100.00',
                'cash_change_returned_bdt': '50.00',
                'net_cash_collected_bdt': '50.00',
                'expected_drawer_cash_bdt': '550.00',
                'counted_cash_bdt': '545.00',
                'variance_bdt': '-5.00',
                'digital_total_bdt': '70.00',
                'due_issued_bdt': '0.00',
                'sales_count': 1,
                'reversed_sales_count': 0,
                'journal_balanced': true,
                'status': 'VARIANCE_DETECTED',
                'tender_totals_json': <String, dynamic>{
                  'CASH': <String, dynamic>{'net_bdt': '50.00'},
                  'BKASH': <String, dynamic>{'net_bdt': '70.00'},
                },
              },
            );
          }
          return const MobilePosHttpResponse(statusCode: 404, data: <String, dynamic>{});
        },
      );

      final emptyRes = await client.submitSplitPayments(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-split-1',
        splits: const <MobileSplitPaymentInput>[],
      );
      expect(emptyRes.uiState, MobilePosUiState.error);
      expect(emptyRes.errorCode, 'ERR_EMPTY_SPLIT_PAYMENTS');

      final missingRef = await client.submitSplitPayments(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-split-1',
        splits: const <MobileSplitPaymentInput>[
          MobileSplitPaymentInput(tenderType: 'BKASH', amountBdt: '70.00'),
        ],
      );
      expect(missingRef.uiState, MobilePosUiState.error);
      expect(missingRef.errorCode, 'ERR_DIGITAL_TENDER_REFERENCE_REQUIRED');

      final offlineDigital = await client.submitSplitPayments(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-split-1',
        splits: const <MobileSplitPaymentInput>[
          MobileSplitPaymentInput(tenderType: 'NAGAD', amountBdt: '70.00'),
        ],
        isOffline: true,
      );
      expect(offlineDigital.uiState, MobilePosUiState.offline);
      expect(offlineDigital.errorCode, 'ERR_OFFLINE_DIGITAL_PAYMENT_REQUIRES_REF');

      final badCard = await client.submitSplitPayments(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-split-1',
        splits: const <MobileSplitPaymentInput>[
          MobileSplitPaymentInput(
            tenderType: 'CARD',
            amountBdt: '70.00',
            gatewayReference: 'AUTH-1234',
            cardLast4: '12AB',
          ),
        ],
      );
      expect(badCard.uiState, MobilePosUiState.error);
      expect(badCard.errorCode, 'ERR_INVALID_CARD_LAST4');

      final splitOk = await client.submitSplitPayments(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-split-1',
        splits: const <MobileSplitPaymentInput>[
          MobileSplitPaymentInput(
            tenderType: 'BKASH',
            amountBdt: '70.00',
            gatewayReference: 'BK-TRX-8821',
          ),
          MobileSplitPaymentInput(tenderType: 'CASH', amountBdt: '100.00'),
        ],
      );
      expect(postedSplit, isTrue);
      expect(splitOk.uiState, MobilePosUiState.ready);
      expect(splitOk.data!.paidAmountBdt, '120.00');
      expect(splitOk.data!.changeReturnedBdt, '50.00');
      expect(splitOk.data!.paymentAttempts.length, 2);
      expect(splitOk.data!.paymentAttempts[0].verificationStatus, 'VERIFIED');
      expect(splitOk.data!.paymentAttempts[1].changeGivenBdt, '50.00');
      expect(splitOk.data!.paymentAttempts[1].effectiveNetSettledBdt, '50.00');

      final verifyRes = await client.verifyPaymentAttempt(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-split-1',
        attemptId: 'att-1',
        gatewayReference: 'BK-TRX-8821',
      );
      expect(verifiedAttempt, isTrue);
      expect(verifyRes.uiState, MobilePosUiState.ready);

      final badVoid = await client.voidPaymentAttempt(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-split-1',
        attemptId: 'att-1',
        reason: 'no',
      );
      expect(badVoid.uiState, MobilePosUiState.error);
      expect(badVoid.errorCode, 'ERR_VOID_REASON_REQUIRED');

      final voidOk = await client.voidPaymentAttempt(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-split-1',
        attemptId: 'att-1',
        reason: 'Customer switched tender to cash',
      );
      expect(voidedAttempt, isTrue);
      expect(voidOk.uiState, MobilePosUiState.ready);

      final crossBranchPreview = await client.getCloseReconciliation(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-other',
      );
      expect(crossBranchPreview.uiState, MobilePosUiState.permissionDenied);

      final previewOk = await client.getCloseReconciliation(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(previewOk.uiState, MobilePosUiState.ready);
      expect(previewOk.data!.expectedDrawerCashBdt, '550.00');
      expect(previewOk.data!.netByTender['BKASH'], '70.00');

      final negClose = await client.submitCloseReconciliation(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        countedCashBdt: '-1.00',
      );
      expect(negClose.uiState, MobilePosUiState.error);
      expect(negClose.errorCode, 'ERR_NEGATIVE_COUNTED_CASH');

      final closeRes = await client.submitCloseReconciliation(
        bearerToken: 'tok-cashier',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        countedCashBdt: '545.00',
        notes: '5 BDT drawer shortage',
      );
      expect(closeRes.uiState, MobilePosUiState.ready);
      expect(closeRes.data!.reconciliationId, 'pcr-100');
      expect(closeRes.data!.status, 'VARIANCE_DETECTED');
      expect(closeRes.data!.varianceBdt, '-5.00');
    });

    testWidgets('2. PosFastSearchPage handles verified bKash+Cash split checkout with change and shift close cleanly',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var sawSplitPost = false;
      var sawFinalize = false;
      var sawCloseSubmit = false;

      final client = MobilePosSearchCartClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          if (method == 'GET' && path.contains('/api/v2/pos/search/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'results': <dynamic>[
                  <String, dynamic>{
                    'product_id': 'med-ceftri',
                    'sku_code': 'NAPA-BOX',
                    'brand_name': 'Napa Extra Box',
                    'generic_name': 'Paracetamol',
                    'resolved_packaging_unit': 'BOX',
                    'resolved_conversion_factor': 10,
                    'unit_price_bdt': '120.00',
                    'base_unit_price_bdt': '12.00',
                    'sellable_base_units': 100,
                    'available_base_units': 100,
                    'requires_rx_verification': false,
                    'regulatory_classification': 'OTC',
                    'is_sellable': true,
                    'packaging_options': <dynamic>[
                      <String, dynamic>{
                        'packaging_unit': 'BOX',
                        'label_en': 'Box (10)',
                        'label_bn': 'বক্স (১০)',
                        'conversion_factor': 10,
                        'unit_price_bdt': '120.00',
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
                  'sale_id': 'sale-ui-split-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-SP-UI1',
                  'lifecycle_state': 'DRAFT',
                  'grand_total_bdt': '0.00',
                  'paid_amount_bdt': '0.00',
                  'due_amount_bdt': '0.00',
                  'change_returned_bdt': '0.00',
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
                  'sale_id': 'sale-ui-split-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-SP-UI1',
                  'lifecycle_state': 'DRAFT',
                  'subtotal_bdt': '120.00',
                  'grand_total_bdt': '120.00',
                  'paid_amount_bdt': '0.00',
                  'due_amount_bdt': '0.00',
                  'change_returned_bdt': '0.00',
                  'version': 2,
                  'lines': <dynamic>[
                    <String, dynamic>{
                      'line_id': 'ln-split-1',
                      'line_number': 1,
                      'product_id': 'med-ceftri',
                      'product_brand_name': 'Napa Extra Box',
                      'packaging_unit': 'BOX',
                      'quantity_units': 1,
                      'conversion_factor': 10,
                      'base_units_total': 10,
                      'unit_price_bdt': '120.00',
                      'line_subtotal_bdt': '120.00',
                      'line_total_bdt': '120.00',
                      'regulatory_classification': 'OTC',
                      'requires_rx_verification': false,
                    },
                  ],
                },
              },
            );
          }
          if (method == 'POST' && path.endsWith('/split-payments/')) {
            sawSplitPost = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-ui-split-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-SP-UI1',
                  'lifecycle_state': 'CONFIRMED',
                  'grand_total_bdt': '120.00',
                  'paid_amount_bdt': '120.00',
                  'due_amount_bdt': '0.00',
                  'change_returned_bdt': '50.00',
                  'version': 2,
                  'payment_attempts': <dynamic>[
                    <String, dynamic>{
                      'attempt_id': 'att-ui-1',
                      'attempt_number': 1,
                      'tender_type': 'BKASH',
                      'amount_bdt': '70.00',
                      'change_given_bdt': '0.00',
                      'net_settled_amount_bdt': '70.00',
                      'status': 'CAPTURED',
                      'verification_status': 'VERIFIED',
                      'gateway_reference': 'BK-TRX-8821',
                      'idempotency_key': 'u1',
                    },
                    <String, dynamic>{
                      'attempt_id': 'att-ui-2',
                      'attempt_number': 2,
                      'tender_type': 'CASH',
                      'amount_bdt': '100.00',
                      'change_given_bdt': '50.00',
                      'net_settled_amount_bdt': '50.00',
                      'status': 'CAPTURED',
                      'verification_status': 'NOT_REQUIRED',
                      'idempotency_key': 'u2',
                    },
                  ],
                },
              },
            );
          }
          if (method == 'POST' && path.endsWith('/finalize/')) {
            sawFinalize = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-ui-split-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-SP-UI1',
                  'lifecycle_state': 'FINALIZED',
                  'grand_total_bdt': '120.00',
                  'paid_amount_bdt': '120.00',
                  'due_amount_bdt': '0.00',
                  'change_returned_bdt': '50.00',
                  'version': 3,
                },
              },
            );
          }
          if (method == 'GET' && path.startsWith('/api/v2/pos/sales/close-reconciliation/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'branch_id': 'br-a',
                'branch_name': 'Dhanmondi',
                'opening_float_bdt': '0.00',
                'gross_cash_tendered_bdt': '100.00',
                'cash_change_returned_bdt': '50.00',
                'net_cash_collected_bdt': '50.00',
                'expected_drawer_cash_bdt': '50.00',
                'digital_total_bdt': '70.00',
                'due_issued_bdt': '0.00',
                'sales_count': 1,
                'status': 'PREVIEW',
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/close-reconciliation/') {
            sawCloseSubmit = true;
            return const MobilePosHttpResponse(
              statusCode: 201,
              data: <String, dynamic>{
                'reconciliation_id': 'pcr-ui-1',
                'branch_id': 'br-a',
                'expected_drawer_cash_bdt': '50.00',
                'counted_cash_bdt': '50.00',
                'variance_bdt': '0.00',
                'digital_total_bdt': '70.00',
                'due_issued_bdt': '0.00',
                'sales_count': 1,
                'status': 'BALANCED',
              },
            );
          }
          return const MobilePosHttpResponse(statusCode: 404, data: <String, dynamic>{});
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PosFastSearchPage(
            key: const Key('split-online'),
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
      await tester.tap(find.byKey(const Key('add_candidate_med-ceftri')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pos_split_pay_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pos_split_payment_sheet')), findsOneWidget);

      // Select BKASH without TrxID -> local validation block
      await tester.tap(find.byKey(const Key('pos_split_tender_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BKASH').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pos_split_amount_field')), '70.00');
      await tester.tap(find.byKey(const Key('pos_add_split_leg_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ERR_DIGITAL_TENDER_REFERENCE_REQUIRED'), findsOneWidget);

      // Enter TrxID -> add BKASH 70.00
      await tester.enterText(find.byKey(const Key('pos_split_ref_field')), 'BK-TRX-8821');
      await tester.tap(find.byKey(const Key('pos_add_split_leg_btn')));
      await tester.pumpAndSettle();

      // Switch to CASH -> add 100.00 -> shows 50.00 cash change
      await tester.tap(find.byKey(const Key('pos_split_tender_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CASH').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pos_split_amount_field')), '100.00');
      await tester.tap(find.byKey(const Key('pos_add_split_leg_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cash Change: ৳50.00'), findsOneWidget);

      Navigator.of(tester.element(find.byKey(const Key('pos_split_payment_sheet')))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pos_checkout_btn')));
      await tester.pumpAndSettle();
      expect(sawSplitPost, isTrue);
      expect(sawFinalize, isTrue);
      expect(find.textContaining('Paid: ৳120.00 (Change: ৳50.00)'), findsOneWidget);

      // Re-open sheet to run shift close reconciliation
      await tester.tap(find.byKey(const Key('pos_split_pay_btn')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('pos_refresh_close_recon_btn')));
      await tester.tap(find.byKey(const Key('pos_refresh_close_recon_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Expected Cash: ৳50.00'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('pos_close_counted_cash_field')));
      await tester.enterText(find.byKey(const Key('pos_close_counted_cash_field')), '50.00');
      await tester.ensureVisible(find.byKey(const Key('pos_submit_close_recon_btn')));
      await tester.tap(find.byKey(const Key('pos_submit_close_recon_btn')));
      await tester.pumpAndSettle();
      expect(sawCloseSubmit, isTrue);
      expect(find.textContaining('Close Reconciliation BALANCED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Offline split blocks unverified digital, allows Cash offline & supports Bangla translations cleanly',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = MobilePosSearchCartClient(baseUrl: 'http://localhost:8000');
      client.seedOfflineSnapshot('br-a', const <MobileFastSearchCandidate>[
        MobileFastSearchCandidate(
          productId: 'med-otc-off',
          skuCode: 'OTC-100',
          displayName: 'SafeMed 100mg',
          brandName: 'SafeMed',
          brandNameBn: 'সেফমেড',
          genericName: 'SafeGen',
          genericNameBn: 'জেনেরিক',
          strength: '100mg',
          dosageForm: 'Tablet',
          barcode: '8941111',
          shelfLocation: 'A-1',
          resolutionSource: 'OFFLINE_SNAPSHOT',
          resolvedPackagingUnit: 'TABLET',
          resolvedConversionFactor: 1,
          unitPriceBdt: '50.00',
          baseUnitPriceBdt: '50.00',
          sellableBaseUnits: 20,
          reservedBaseUnits: 0,
          availableBaseUnits: 20,
          quarantinedBaseUnits: 0,
          expiredBaseUnits: 0,
          recalledBaseUnits: 0,
          earliestBatchNumber: 'LOT-OFF-1',
          earliestExpiryDate: '2029-12-31',
          nearExpiryWarning: false,
          requiresRxVerification: false,
          regulatoryClassification: 'OTC',
          nonDivisibleSealedOnly: false,
          isSellable: true,
          blockReason: '',
          snapshotChecksum: 'chk-p229-off',
          rankScore: 100,
          packagingOptions: <MobilePackagingOption>[
            MobilePackagingOption(
              packagingUnit: 'TABLET',
              labelEn: 'Tablet',
              labelBn: 'ট্যাবলেট',
              conversionFactor: 1,
              unitPriceBdt: '50.00',
            ),
          ],
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: PosFastSearchPage(
            key: const Key('split-offline'),
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
      await tester.tap(find.byKey(const Key('add_candidate_med-otc-off')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pos_split_pay_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pos_split_tender_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BKASH').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pos_split_amount_field')), '50.00');
      await tester.tap(find.byKey(const Key('pos_add_split_leg_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ERR_OFFLINE_DIGITAL_PAYMENT_REQUIRES_REF'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pos_split_tender_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CASH').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pos_split_amount_field')), '50.00');
      await tester.tap(find.byKey(const Key('pos_add_split_leg_btn')));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byKey(const Key('pos_split_payment_sheet')))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pos_checkout_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('OFFLINE_PROVISIONAL_PAYMENT'), findsOneWidget);

      // Bangla UI check on isolated page instance
      await tester.pumpWidget(
        MaterialApp(
          home: PosFastSearchPage(
            key: const Key('split-bn'),
            client: client,
            bearerToken: 'tok-cashier',
            actorRole: 'CASHIER',
            actorTenantId: 'ten-a',
            actorBranchId: 'br-a',
            targetTenantId: 'ten-a',
            targetBranchId: 'br-a',
            initialBangla: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pos_split_pay_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('স্প্লিট পেমেন্ট ও ক্যাশিয়ার ক্লোজ'), findsOneWidget);
      expect(find.textContaining('ক্যাশিয়ার শিফট ক্লোজ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
