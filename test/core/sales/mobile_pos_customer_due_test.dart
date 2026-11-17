import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_search_cart_client.dart';
import 'package:pharmacy_mobile_manager/features/pos/pos_fast_search_page.dart';

void main() {
  group('P230: Mobile POS Approved Customer Credit Sale, Limits & Due Collection Without Double Revenue', () {
    test('1. Client validates credit approval RBAC, DUE offline block & due collection AR_CUSTOMER_DUE',
        () async {
      final client = MobilePosDomainClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          if (method == 'POST' && path == '/api/v2/pos/customers/cust-1/approve-credit/') {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'customer_id': 'cust-1',
                'tenant_id': 'ten-a',
                'primary_branch': 'br-a',
                'full_name': 'Rafiqul Islam',
                'phone': '01711002233',
                'credit_limit_bdt': '1000.00',
                'current_due_bdt': '200.00',
                'available_credit_bdt': '800.00',
                'is_credit_approved': true,
                'credit_status': 'APPROVED',
                'credit_terms_days': 15,
                'is_archived': false,
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/customer-dues/due-1/collect/') {
            return const MobilePosHttpResponse(
              statusCode: 201,
              data: <String, dynamic>{
                'created': true,
                'idempotent_replay': false,
                'revenue_impact_bdt': '0.00',
                'collection': <String, dynamic>{
                  'collection_id': 'col-1',
                  'due_record_id': 'due-1',
                  'customer_id': 'cust-1',
                  'debit_account': 'BKASH_CLEARING',
                  'credit_account': 'AR_CUSTOMER_DUE',
                  'revenue_impact_bdt': '0.00',
                  'tender_type': 'BKASH',
                  'amount_bdt': '150.00',
                  'gateway_reference': 'BK-DUE-1234',
                  'status': 'CAPTURED',
                },
                'due_record': <String, dynamic>{
                  'due_id': 'due-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'customer_id': 'cust-1',
                  'total_due_bdt': '200.00',
                  'paid_amount_bdt': '150.00',
                  'remaining_due_bdt': '50.00',
                  'status': 'PARTIAL',
                },
              },
            );
          }
          return const MobilePosHttpResponse(statusCode: 404, data: <String, dynamic>{});
        },
      );

      final offlineDue = await client.submitSplitPayments(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-1',
        splits: const <MobileSplitPaymentInput>[
          MobileSplitPaymentInput(tenderType: 'DUE', amountBdt: '100.00'),
        ],
        isOffline: true,
      );
      expect(offlineDue.uiState, MobilePosUiState.offline);
      expect(offlineDue.errorCode, 'ERR_OFFLINE_CREDIT_UNAVAILABLE');

      final cashierApprove = await client.approveCustomerCredit(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        customerId: 'cust-1',
        creditLimitBdt: '1000.00',
      );
      expect(cashierApprove.uiState, MobilePosUiState.permissionDenied);

      final mgrApprove = await client.approveCustomerCredit(
        bearerToken: 'tok',
        actorRole: 'BRANCH_MANAGER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        customerId: 'cust-1',
        creditLimitBdt: '1000.00',
        creditTermsDays: 15,
      );
      expect(mgrApprove.uiState, MobilePosUiState.ready);
      expect(mgrApprove.data!.availableCreditBdt, '800.00');

      final dueWithDue = await client.collectCustomerDue(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        dueId: 'due-1',
        tenderType: 'DUE',
        amountBdt: '50.00',
      );
      expect(dueWithDue.uiState, MobilePosUiState.error);
      expect(dueWithDue.errorCode, 'ERR_CANNOT_COLLECT_DUE_WITH_DUE');

      final bkashNoRef = await client.collectCustomerDue(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        dueId: 'due-1',
        tenderType: 'BKASH',
        amountBdt: '50.00',
      );
      expect(bkashNoRef.uiState, MobilePosUiState.error);
      expect(bkashNoRef.errorCode, 'ERR_DIGITAL_TENDER_REFERENCE_REQUIRED');

      final colOk = await client.collectCustomerDue(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        dueId: 'due-1',
        tenderType: 'BKASH',
        amountBdt: '150.00',
        gatewayReference: 'BK-DUE-1234',
      );
      expect(colOk.uiState, MobilePosUiState.ready);
      expect(colOk.data!.collection.creditAccount, 'AR_CUSTOMER_DUE');
      expect(colOk.data!.revenueImpactBdt, '0.00');
      expect(colOk.data!.dueRecord.remainingDueBdt, '50.00');
    });

    testWidgets('2. PosFastSearchPage blocks unapproved DUE, approves limited split checkout & collects due',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var sawAttach = false;
      var sawSplit = false;
      var sawCollect = false;

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
                  'sale_id': 'sale-ui-due-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-DUE-UI1',
                  'lifecycle_state': 'DRAFT',
                  'grand_total_bdt': '0.00',
                  'version': 1,
                },
              },
            );
          }
          if (method == 'POST' && path.endsWith('/scan-add/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-ui-due-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-DUE-UI1',
                  'lifecycle_state': 'DRAFT',
                  'subtotal_bdt': '120.00',
                  'grand_total_bdt': '120.00',
                  'version': 2,
                  'lines': <dynamic>[
                    <String, dynamic>{
                      'line_id': 'ln-d1',
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
                    },
                  ],
                },
              },
            );
          }
          if (method == 'GET' && path.startsWith('/api/v2/pos/customers/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'results': <dynamic>[
                  <String, dynamic>{
                    'customer_id': 'cust-unapp',
                    'tenant_id': 'ten-a',
                    'primary_branch': 'br-a',
                    'full_name': 'Unapproved Walkin',
                    'phone': '01700000001',
                    'credit_limit_bdt': '0.00',
                    'current_due_bdt': '0.00',
                    'available_credit_bdt': '0.00',
                    'is_credit_approved': false,
                    'credit_status': 'UNAPPROVED',
                    'is_archived': false,
                  },
                  <String, dynamic>{
                    'customer_id': 'cust-app',
                    'tenant_id': 'ten-a',
                    'primary_branch': 'br-a',
                    'full_name': 'Approved Rafiq',
                    'phone': '01711002233',
                    'credit_limit_bdt': '200.00',
                    'current_due_bdt': '100.00',
                    'available_credit_bdt': '100.00',
                    'is_credit_approved': true,
                    'credit_status': 'APPROVED',
                    'is_archived': false,
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-ui-due-1/attach-customer/') {
            sawAttach = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-ui-due-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-DUE-UI1',
                  'customer_id': 'cust-app',
                  'lifecycle_state': 'DRAFT',
                  'grand_total_bdt': '120.00',
                  'version': 3,
                },
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-ui-due-1/split-payments/') {
            sawSplit = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-ui-due-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-DUE-UI1',
                  'lifecycle_state': 'CONFIRMED',
                  'grand_total_bdt': '120.00',
                  'paid_amount_bdt': '40.00',
                  'due_amount_bdt': '80.00',
                  'change_returned_bdt': '0.00',
                  'version': 4,
                },
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-ui-due-1/finalize/') {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale': <String, dynamic>{
                  'sale_id': 'sale-ui-due-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-DUE-UI1',
                  'lifecycle_state': 'FINALIZED',
                  'grand_total_bdt': '120.00',
                  'paid_amount_bdt': '40.00',
                  'due_amount_bdt': '80.00',
                  'change_returned_bdt': '0.00',
                  'version': 5,
                },
              },
            );
          }
          if (method == 'GET' && path.startsWith('/api/v2/pos/customer-dues/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'results': <dynamic>[
                  <String, dynamic>{
                    'due_id': 'due-ui-1',
                    'tenant_id': 'ten-a',
                    'branch_id': 'br-a',
                    'customer_id': 'cust-app',
                    'customer_name': 'Approved Rafiq',
                    'total_due_bdt': '180.00',
                    'paid_amount_bdt': '0.00',
                    'remaining_due_bdt': '180.00',
                    'status': 'OUTSTANDING',
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/customer-dues/due-ui-1/collect/') {
            sawCollect = true;
            return const MobilePosHttpResponse(
              statusCode: 201,
              data: <String, dynamic>{
                'created': true,
                'idempotent_replay': false,
                'revenue_impact_bdt': '0.00',
                'collection': <String, dynamic>{
                  'collection_id': 'col-ui-1',
                  'due_record_id': 'due-ui-1',
                  'debit_account': 'CASH_DRAWER',
                  'credit_account': 'AR_CUSTOMER_DUE',
                  'revenue_impact_bdt': '0.00',
                  'tender_type': 'CASH',
                  'amount_bdt': '100.00',
                  'status': 'CAPTURED',
                },
                'due_record': <String, dynamic>{
                  'due_id': 'due-ui-1',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'customer_id': 'cust-app',
                  'total_due_bdt': '180.00',
                  'paid_amount_bdt': '100.00',
                  'remaining_due_bdt': '80.00',
                  'status': 'PARTIAL',
                },
              },
            );
          }
          return const MobilePosHttpResponse(statusCode: 404, data: <String, dynamic>{});
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PosFastSearchPage(
            key: const Key('p230-online'),
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

      // Load customers
      await tester.ensureVisible(find.byKey(const Key('pos_load_customers_btn')));
      await tester.tap(find.byKey(const Key('pos_load_customers_btn')));
      await tester.pumpAndSettle();

      // Select unapproved customer -> DUE blocked
      await tester.ensureVisible(find.byKey(const Key('pos_customer_select_cust-unapp')));
      await tester.tap(find.byKey(const Key('pos_customer_select_cust-unapp')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('pos_split_tender_dropdown')));
      await tester.tap(find.byKey(const Key('pos_split_tender_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DUE').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pos_split_amount_field')), '50.00');
      await tester.tap(find.byKey(const Key('pos_add_split_leg_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ERR_CUSTOMER_CREDIT_NOT_APPROVED'), findsOneWidget);

      // Select Approved customer (Avail 100.00) -> 120 DUE exceeds limit -> 80 DUE + 40 Cash passes!
      await tester.ensureVisible(find.byKey(const Key('pos_customer_select_cust-app')));
      await tester.tap(find.byKey(const Key('pos_customer_select_cust-app')));
      await tester.pumpAndSettle();
      expect(sawAttach, isTrue);

      await tester.ensureVisible(find.byKey(const Key('pos_split_amount_field')));
      await tester.enterText(find.byKey(const Key('pos_split_amount_field')), '120.00');
      await tester.tap(find.byKey(const Key('pos_add_split_leg_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ERR_CUSTOMER_CREDIT_LIMIT_EXCEEDED'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('pos_split_amount_field')), '80.00');
      await tester.tap(find.byKey(const Key('pos_add_split_leg_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pos_split_tender_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CASH').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pos_split_amount_field')), '40.00');
      await tester.tap(find.byKey(const Key('pos_add_split_leg_btn')));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byKey(const Key('pos_split_payment_sheet')))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pos_checkout_btn')));
      await tester.pumpAndSettle();
      expect(sawSplit, isTrue);

      // Collect due on customer receivable without double revenue
      await tester.tap(find.byKey(const Key('pos_split_pay_btn')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('pos_load_dues_btn')));
      await tester.tap(find.byKey(const Key('pos_load_dues_btn')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('pos_due_collect_amount_field')));
      await tester.enterText(find.byKey(const Key('pos_due_collect_amount_field')), '100.00');
      await tester.ensureVisible(find.byKey(const Key('pos_collect_due_btn')));
      await tester.tap(find.byKey(const Key('pos_collect_due_btn')));
      await tester.pumpAndSettle();

      expect(sawCollect, isTrue);
      expect(find.textContaining('AR_CUSTOMER_DUE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
