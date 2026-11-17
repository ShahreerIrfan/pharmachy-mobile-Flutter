import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_search_cart_client.dart';
import 'package:pharmacy_mobile_manager/features/pos/pos_fast_search_page.dart';

void main() {
  group('P227: Mobile POS Prescription Safety Gate, Antibiotic Register & Offline Limitations', () {
    test('1. Client enforces Pharmacist PCB barrier, reject reason, offline Rx hard-block & parses Rx/Abx DTOs',
        () async {
      var finalizeHit = false;
      var attachSentBmdc = false;

      final client = MobilePosDomainClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          if (method == 'GET' && path == '/api/v2/pos/sales/sale-m-rx1/rx-gate/') {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-m-rx1',
                'order_number': 'POS-MRX-1',
                'lifecycle_state': 'PENDING_RX_REVIEW',
                'requires_rx_verification': true,
                'rx_gate_status': 'PENDING_PHARMACIST',
                'requires_antibiotic_register': true,
                'has_narcotic': false,
                'has_blocked_recall_or_ban': false,
                'can_finalize_online': false,
                'can_finalize_offline': false,
                'offline_block_reason_en': 'Offline limitation: unverified Rx blocked offline.',
                'version': 2,
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-m-rx1/attach-prescription/') {
            if (body?['doctor_bmdc_no'] == 'BMDC-5520') attachSentBmdc = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-m-rx1',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-MRX-1',
                'lifecycle_state': 'PENDING_RX_REVIEW',
                'requires_rx_verification': true,
                'rx_gate_status': 'PENDING_PHARMACIST',
                'prescription_id': 'rx-m-1',
                'rx_reference_code': 'RX-M-100',
                'version': 3,
                'lines': <dynamic>[],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-m-rx1/verify-rx/') {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-m-rx1',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-MRX-1',
                'lifecycle_state': 'DRAFT',
                'requires_rx_verification': true,
                'rx_gate_status': 'APPROVED',
                'pharmacist_pcb_no_snapshot': 'PCB-88412',
                'rx_verified_at': '2026-11-10T10:30:00Z',
                'version': 4,
                'lines': <dynamic>[],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-m-rx1/reject-rx/') {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-m-rx1',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-MRX-1',
                'lifecycle_state': 'PENDING_RX_REVIEW',
                'requires_rx_verification': true,
                'rx_gate_status': 'REJECTED',
                'rx_decision_reason': 'Altered Rx strip count',
                'version': 5,
                'lines': <dynamic>[],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-m-rx1/rx-gate/offline-preflight/') {
            return const MobilePosHttpResponse(
              statusCode: 422,
              data: <String, dynamic>{
                'error_code': 'ERR_OFFLINE_RX_BLOCKED',
                'message_en': 'Offline limitation: unverified Rx cannot finalize offline.',
                'message_bn': 'অফলাইন সীমাবদ্ধতা: অনুমোদনহীন প্রেসক্রিপশন অফলাইনে সম্পন্ন করা যাবে না।',
                'summary': <String, dynamic>{
                  'sale_id': 'sale-m-rx1',
                  'requires_rx_verification': true,
                  'rx_gate_status': 'PENDING_PHARMACIST',
                  'can_finalize_offline': false,
                },
              },
            );
          }
          if (method == 'GET' && path.startsWith('/api/v2/pos/antibiotic-register/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'count': 1,
                'results': <dynamic>[
                  <String, dynamic>{
                    'register_entry_id': 'abx-m-1',
                    'sale_id': 'sale-m-rx1',
                    'order_number': 'POS-MRX-1',
                    'brand_name': 'Azithrocin 500',
                    'generic_name': 'Azithromycin',
                    'classification_tier': 'ANTIMICROBIAL_ACCESS',
                    'dispensed_base_units': 10,
                    'doctor_bmdc_no': 'BMDC-5520',
                    'patient_token': 'PAT-10',
                    'approving_pharmacist_pcb_no': 'PCB-88412',
                    'status': 'ACTIVE',
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-m-rx1/finalize/') {
            finalizeHit = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-m-rx1',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-MRX-1',
                'lifecycle_state': 'FINALIZED',
                'requires_rx_verification': true,
                'rx_gate_status': 'APPROVED',
                'version': 6,
                'lines': <dynamic>[],
              },
            );
          }
          return const MobilePosHttpResponse(statusCode: 404, data: <String, dynamic>{});
        },
      );

      // Non-pharmacist roles blocked locally
      for (final blocked in const <String>['CASHIER', 'BRANCH_MANAGER']) {
        final denied = await client.verifyRxSale(
          bearerToken: 'tok',
          actorRole: blocked,
          actorTenantId: 'ten-a',
          actorBranchId: 'br-a',
          targetTenantId: 'ten-a',
          targetBranchId: 'br-a',
          saleId: 'sale-m-rx1',
        );
        expect(denied.uiState, MobilePosUiState.permissionDenied);
        expect(denied.errorCode, 'ERR_PHARMACIST_APPROVAL_REQUIRED');
      }
      final auditorDenied = await client.verifyRxSale(
        bearerToken: 'tok',
        actorRole: 'AUDITOR',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-rx1',
      );
      expect(auditorDenied.uiState, MobilePosUiState.permissionDenied);
      expect(auditorDenied.errorCode, 'ERR_PERMISSION_DENIED');

      final ownerNoPcb = await client.verifyRxSale(
        bearerToken: 'tok',
        actorRole: 'PHARMACY_OWNER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-rx1',
      );
      expect(ownerNoPcb.errorCode, 'ERR_PHARMACIST_APPROVAL_REQUIRED');

      // Offline Rx finalize blocked client-side without touching network
      final offlineRxBlock = await client.finalizeSale(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-rx1',
        requiresRxVerification: true,
        rxGateStatus: 'PENDING_PHARMACIST',
        isOffline: true,
      );
      expect(offlineRxBlock.uiState, MobilePosUiState.offline);
      expect(offlineRxBlock.errorCode, 'ERR_OFFLINE_RX_BLOCKED');
      expect(finalizeHit, isFalse);

      // Gate status + attach + verify + reject validation + antibiotic register + finalize
      final gateRes = await client.getRxGateStatus(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-rx1',
      );
      expect(gateRes.uiState, MobilePosUiState.ready);
      expect(gateRes.data!.requiresAntibioticRegister, isTrue);
      expect(gateRes.data!.canFinalizeOffline, isFalse);

      final attachRes = await client.attachPrescription(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-rx1',
        doctorName: 'Dr. Mahmud',
        doctorBmdcNo: 'BMDC-5520',
      );
      expect(attachRes.uiState, MobilePosUiState.ready);
      expect(attachSentBmdc, isTrue);

      final badReject = await client.rejectRxSale(
        bearerToken: 'tok',
        actorRole: 'STAFF_PHARMACIST',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-rx1',
        reason: 'no',
      );
      expect(badReject.uiState, MobilePosUiState.error);
      expect(badReject.errorCode, 'ERR_RX_REJECTION_REASON_REQUIRED');

      final okApprove = await client.verifyRxSale(
        bearerToken: 'tok',
        actorRole: 'STAFF_PHARMACIST',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-rx1',
        pharmacistPcbNo: 'PCB-88412',
        notes: 'Verified slip',
      );
      expect(okApprove.uiState, MobilePosUiState.ready);
      expect(okApprove.data!.rxGateStatus, 'APPROVED');

      final preflightRes = await client.offlineRxPreflight(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-rx1',
      );
      expect(preflightRes.errorCode, 'ERR_OFFLINE_RX_BLOCKED');

      final abxList = await client.listAntibioticRegister(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(abxList.uiState, MobilePosUiState.ready);
      expect(abxList.data!.results.single.brandName, 'Azithrocin 500');

      final finRes = await client.finalizeSale(
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        saleId: 'sale-m-rx1',
        requiresRxVerification: true,
        rxGateStatus: 'APPROVED',
      );
      expect(finRes.uiState, MobilePosUiState.ready);
      expect(finalizeHit, isTrue);
    });

    testWidgets(
        '2. PosFastSearchPage enforces Rx gate before checkout, allows Pharmacist attach/approve/Abx list & checkout',
        (WidgetTester tester) async {
      var rxApproved = false;
      var finalizedCalled = false;
      var paymentRecorded = false;

      final client = MobilePosSearchCartClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          if (method == 'GET' && path.contains('/api/v2/pos/search/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'query': 'azithrocin',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'total_matches': 1,
                'latency_ms': 1.2,
                'results': <dynamic>[
                  <String, dynamic>{
                    'product_id': 'med-abx',
                    'sku_code': 'AZM-500',
                    'display_name': 'Azithrocin 500mg',
                    'brand_name': 'Azithrocin',
                    'brand_name_bn': 'অ্যাজিথ্রোসিন',
                    'generic_name': 'Azithromycin',
                    'generic_name_bn': 'অ্যাজিথ্রোমাইসিন',
                    'strength': '500mg',
                    'dosage_form': 'Tablet',
                    'barcode': '894227002',
                    'shelf_location': 'Rack B-1',
                    'resolution_source': 'BRAND_GENERIC_SEARCH',
                    'resolved_packaging_unit': 'STRIP',
                    'resolved_conversion_factor': 10,
                    'unit_price_bdt': '350.00',
                    'base_unit_price_bdt': '35.00',
                    'sellable_base_units': 100,
                    'reserved_base_units': 0,
                    'available_base_units': 100,
                    'quarantined_base_units': 0,
                    'expired_base_units': 0,
                    'recalled_base_units': 0,
                    'requires_rx_verification': true,
                    'regulatory_classification': 'ANTIMICROBIAL_ACCESS',
                    'non_divisible_sealed_only': false,
                    'is_sellable': true,
                    'block_reason': '',
                    'packaging_options': <dynamic>[
                      <String, dynamic>{
                        'packaging_unit': 'STRIP',
                        'label_en': 'Strip (10u)',
                        'label_bn': 'স্ট্রিপ (১০টি)',
                        'conversion_factor': 10,
                        'unit_price_bdt': '350.00',
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
                  'sale_id': 'sale-ui-rx227',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-RX-227',
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
                  'sale_id': 'sale-ui-rx227',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-RX-227',
                  'lifecycle_state': 'PENDING_RX_REVIEW',
                  'subtotal_bdt': '350.00',
                  'grand_total_bdt': '350.00',
                  'requires_rx_verification': true,
                  'rx_gate_status': 'PENDING_PHARMACIST',
                  'version': 2,
                  'lines': <dynamic>[
                    <String, dynamic>{
                      'line_id': 'ln-m-abx',
                      'line_number': 1,
                      'product_id': 'med-abx',
                      'product_brand_name': 'Azithrocin',
                      'packaging_unit': 'STRIP',
                      'quantity_units': 1,
                      'conversion_factor': 10,
                      'base_units_total': 10,
                      'unit_price_bdt': '350.00',
                      'line_subtotal_bdt': '350.00',
                      'line_tax_amount_bdt': '0.00',
                      'line_total_bdt': '350.00',
                      'regulatory_classification': 'ANTIMICROBIAL_ACCESS',
                      'requires_rx_verification': true,
                      'rx_verified': false,
                      'rx_verified_base_units': 0,
                    },
                  ],
                },
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-ui-rx227/attach-prescription/') {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-ui-rx227',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-RX-227',
                'lifecycle_state': 'PENDING_RX_REVIEW',
                'subtotal_bdt': '350.00',
                'grand_total_bdt': '350.00',
                'requires_rx_verification': true,
                'rx_gate_status': 'PENDING_PHARMACIST',
                'rx_reference_code': 'RX-M-77',
                'version': 3,
                'lines': <dynamic>[
                  <String, dynamic>{
                    'line_id': 'ln-m-abx',
                    'line_number': 1,
                    'product_id': 'med-abx',
                    'product_brand_name': 'Azithrocin',
                    'packaging_unit': 'STRIP',
                    'quantity_units': 1,
                    'conversion_factor': 10,
                    'base_units_total': 10,
                    'unit_price_bdt': '350.00',
                    'line_subtotal_bdt': '350.00',
                    'line_tax_amount_bdt': '0.00',
                    'line_total_bdt': '350.00',
                    'regulatory_classification': 'ANTIMICROBIAL_ACCESS',
                    'requires_rx_verification': true,
                    'rx_verified': false,
                    'rx_verified_base_units': 0,
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-ui-rx227/verify-rx/') {
            rxApproved = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-ui-rx227',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-RX-227',
                'lifecycle_state': 'DRAFT',
                'subtotal_bdt': '350.00',
                'grand_total_bdt': '350.00',
                'requires_rx_verification': true,
                'rx_gate_status': 'APPROVED',
                'pharmacist_pcb_no_snapshot': 'PCB-88412',
                'rx_verified_at': '2026-11-10T10:35:00Z',
                'rx_reference_code': 'RX-M-77',
                'version': 4,
                'lines': <dynamic>[
                  <String, dynamic>{
                    'line_id': 'ln-m-abx',
                    'line_number': 1,
                    'product_id': 'med-abx',
                    'product_brand_name': 'Azithrocin',
                    'packaging_unit': 'STRIP',
                    'quantity_units': 1,
                    'conversion_factor': 10,
                    'base_units_total': 10,
                    'unit_price_bdt': '350.00',
                    'line_subtotal_bdt': '350.00',
                    'line_tax_amount_bdt': '0.00',
                    'line_total_bdt': '350.00',
                    'regulatory_classification': 'ANTIMICROBIAL_ACCESS',
                    'requires_rx_verification': true,
                    'rx_verified': true,
                    'rx_verified_base_units': 10,
                  },
                ],
              },
            );
          }
          if (method == 'GET' && path == '/api/v2/pos/sales/sale-ui-rx227/rx-gate/') {
            return MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-ui-rx227',
                'order_number': 'POS-RX-227',
                'requires_rx_verification': true,
                'rx_gate_status': rxApproved ? 'APPROVED' : 'PENDING_PHARMACIST',
                'requires_antibiotic_register': true,
              },
            );
          }
          if (method == 'GET' && path.startsWith('/api/v2/pos/antibiotic-register/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'count': 1,
                'results': <dynamic>[
                  <String, dynamic>{
                    'register_entry_id': 'abx-ui-1',
                    'sale_id': 'sale-ui-rx227',
                    'brand_name': 'Azithrocin',
                    'dispensed_base_units': 10,
                    'approving_pharmacist_pcb_no': 'PCB-88412',
                    'status': 'ACTIVE',
                  },
                ],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-ui-rx227/record-payment/') {
            paymentRecorded = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-ui-rx227',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-RX-227',
                'lifecycle_state': 'PARTIALLY_PAID',
                'version': 5,
                'lines': <dynamic>[],
              },
            );
          }
          if (method == 'POST' && path == '/api/v2/pos/sales/sale-ui-rx227/finalize/') {
            finalizedCalled = true;
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'sale_id': 'sale-ui-rx227',
                'tenant_id': 'ten-a',
                'branch_id': 'br-a',
                'order_number': 'POS-RX-227',
                'lifecycle_state': 'FINALIZED',
                'version': 6,
                'lines': <dynamic>[],
              },
            );
          }
          return const MobilePosHttpResponse(statusCode: 404, data: <String, dynamic>{});
        },
      );

      // Pump as STAFF_PHARMACIST to verify Attach + Approve + Antibiotic Register + Checkout end-to-end
      await tester.pumpWidget(
        MaterialApp(
          home: PosFastSearchPage(
            client: client,
            bearerToken: 'tok-pharm',
            actorRole: 'STAFF_PHARMACIST',
            actorTenantId: 'ten-a',
            actorBranchId: 'br-a',
            targetTenantId: 'ten-a',
            targetBranchId: 'br-a',
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('pos_search_input')), 'azithrocin');
      await tester.tap(find.byKey(const Key('pos_search_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_candidate_med-abx')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pos_rx_checkout_hint')), findsOneWidget);
      expect(find.textContaining('Pharmacist Approval Required'), findsOneWidget);

      // Tapping Checkout while unapproved blocks finalize & opens Rx Gate sheet!
      await tester.tap(find.byKey(const Key('pos_checkout_btn')));
      await tester.pumpAndSettle();
      expect(finalizedCalled, isFalse);
      expect(find.byKey(const Key('pos_rx_gate_sheet')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('pos_rx_doctor_name_input')), 'Dr. Kabir');
      await tester.enterText(find.byKey(const Key('pos_rx_doctor_bmdc_input')), 'A-5512');
      await tester.enterText(find.byKey(const Key('pos_rx_ref_input')), 'RX-M-77');
      await tester.tap(find.byKey(const Key('pos_rx_attach_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('pos_rx_pcb_input')), 'PCB-88412');
      await tester.enterText(find.byKey(const Key('pos_rx_notes_input')), 'Verified course');
      await tester.tap(find.byKey(const Key('pos_rx_approve_btn')));
      await tester.pumpAndSettle();
      expect(rxApproved, isTrue);

      await tester.tap(find.byKey(const Key('pos_abx_register_refresh_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pos_abx_register_list')), findsOneWidget);
      expect(find.textContaining('Azithrocin (10u)'), findsOneWidget);

      // Close sheet and tap Checkout -> payment & finalize succeed!
      Navigator.of(tester.element(find.byKey(const Key('pos_rx_gate_sheet')))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Rx APPROVED (Checkout Ready)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pos_checkout_btn')));
      await tester.pumpAndSettle();
      expect(paymentRecorded, isTrue);
      expect(finalizedCalled, isTrue);
      expect(find.text('BDT 0.00'), findsOneWidget);
      expect(find.byKey(const Key('pos_checkout_btn')), findsNothing);
    });

    testWidgets('3. PosFastSearchPage offline mode allows OTC checkout but hard-blocks unverified Rx/Antibiotic',
        (WidgetTester tester) async {
      final client = MobilePosSearchCartClient(baseUrl: 'http://localhost:8000');
      client.seedOfflineSnapshot('br-a', const <MobileFastSearchCandidate>[
        MobileFastSearchCandidate(
          productId: 'med-otc-off',
          skuCode: 'NAPA-500',
          displayName: 'Napa 500mg',
          brandName: 'Napa',
          brandNameBn: 'নাপা',
          genericName: 'Paracetamol',
          genericNameBn: 'প্যারাসিটামল',
          strength: '500mg',
          dosageForm: 'Tablet',
          barcode: '89400010',
          shelfLocation: 'A-1',
          resolutionSource: 'OFFLINE_SNAPSHOT',
          resolvedPackagingUnit: 'TABLET',
          resolvedConversionFactor: 1,
          unitPriceBdt: '1.20',
          baseUnitPriceBdt: '1.20',
          sellableBaseUnits: 100,
          reservedBaseUnits: 0,
          availableBaseUnits: 100,
          quarantinedBaseUnits: 0,
          expiredBaseUnits: 0,
          recalledBaseUnits: 0,
          earliestBatchNumber: 'SNAP-OTC',
          nearExpiryWarning: false,
          requiresRxVerification: false,
          regulatoryClassification: 'OTC',
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
              unitPriceBdt: '1.20',
              isAllowed: true,
            ),
          ],
        ),
        MobileFastSearchCandidate(
          productId: 'med-abx-off',
          skuCode: 'AZM-500',
          displayName: 'Azithrocin 500mg',
          brandName: 'Azithrocin',
          brandNameBn: 'অ্যাজিথ্রোসিন',
          genericName: 'Azithromycin',
          genericNameBn: 'অ্যাজিথ্রোমাইসিন',
          strength: '500mg',
          dosageForm: 'Tablet',
          barcode: '89400020',
          shelfLocation: 'B-2',
          resolutionSource: 'OFFLINE_SNAPSHOT',
          resolvedPackagingUnit: 'TABLET',
          resolvedConversionFactor: 1,
          unitPriceBdt: '35.00',
          baseUnitPriceBdt: '35.00',
          sellableBaseUnits: 50,
          reservedBaseUnits: 0,
          availableBaseUnits: 50,
          quarantinedBaseUnits: 0,
          expiredBaseUnits: 0,
          recalledBaseUnits: 0,
          earliestBatchNumber: 'SNAP-ABX',
          nearExpiryWarning: false,
          requiresRxVerification: true,
          regulatoryClassification: 'ANTIMICROBIAL_ACCESS',
          nonDivisibleSealedOnly: false,
          isSellable: true,
          blockReason: '',
          snapshotChecksum: 'chk-2',
          rankScore: 95,
          packagingOptions: <MobilePackagingOption>[
            MobilePackagingOption(
              packagingUnit: 'TABLET',
              labelEn: 'Tablet',
              labelBn: 'ট্যাবলেট',
              conversionFactor: 1,
              unitPriceBdt: '35.00',
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

      // 1) Offline OTC completes cleanly
      await tester.enterText(find.byKey(const Key('pos_search_input')), 'napa');
      await tester.tap(find.byKey(const Key('pos_search_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_candidate_med-otc-off')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline OTC Ready'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pos_checkout_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('state_banner_offline')), findsOneWidget);
      expect(find.text('BDT 0.00'), findsOneWidget);
      expect(find.byKey(const Key('pos_checkout_btn')), findsNothing);

      // 2) Offline Antibiotic is HARD-BLOCKED from checkout (cart stays intact!)
      await tester.enterText(find.byKey(const Key('pos_search_input')), 'azithrocin');
      await tester.tap(find.byKey(const Key('pos_search_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_candidate_med-abx-off')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline Block'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pos_checkout_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('state_banner_offline')), findsOneWidget);
      expect(find.textContaining('ERR_OFFLINE_RX_BLOCKED'), findsOneWidget);
      expect(find.byKey(const Key('pos_checkout_btn')), findsOneWidget);
      expect(find.text('BDT 35.00'), findsOneWidget);

      // Toggle EN -> BN verifies localized copy renders cleanly
      await tester.tap(find.text('বাংলা'));
      await tester.pumpAndSettle();
      expect(find.text('চেকআউট'), findsOneWidget);
      expect(find.text('Rx আবশ্যক'), findsOneWidget);
    });
  });
}
