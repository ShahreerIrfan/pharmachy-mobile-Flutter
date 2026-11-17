import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';

void main() {
  group('P221: MobilePosDomainClient Tests', () {
    test('1. Parses PosSaleOrder DTO cleanly and sets READY / EMPTY UI states', () async {
      final client = MobilePosDomainClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          expect(method, 'GET');
          expect(path, '/api/v2/pos/sales/?branch=br-a');
          return const MobilePosHttpResponse(
            statusCode: 200,
            data: <String, dynamic>{
              'results': <dynamic>[
                <String, dynamic>{
                  'sale_id': 'sale-mob01',
                  'tenant_id': 'ten-a',
                  'branch_id': 'br-a',
                  'order_number': 'POS-20261109-MOB01',
                  'idempotency_key': 'idem-mob-1',
                  'customer_name': 'Hasan Mahmud',
                  'customer_phone': '+8801711223344',
                  'lifecycle_state': 'FINALIZED',
                  'sync_status': 'CLOUD_CONFIRMED',
                  'subtotal_bdt': '120.00',
                  'discount_amount_bdt': '10.00',
                  'tax_amount_bdt': '5.50',
                  'grand_total_bdt': '115.50',
                  'paid_amount_bdt': '100.00',
                  'due_amount_bdt': '15.50',
                  'linked_invoice_id': 'inv_123',
                  'requires_rx_verification': false,
                  'lines': <dynamic>[
                    <String, dynamic>{
                      'line_id': 'sline-1',
                      'line_number': 1,
                      'product_id': 'med-1',
                      'product_brand_name': 'Sergel 20',
                      'packaging_unit': 'STRIP',
                      'quantity_units': 2,
                      'conversion_factor': 10,
                      'base_units_total': 20,
                      'unit_price_bdt': '60.00',
                      'line_subtotal_bdt': '120.00',
                      'line_tax_amount_bdt': '5.50',
                      'line_total_bdt': '125.50',
                      'unit_cost_bdt': '42.0000',
                      'requires_rx_verification': false,
                    }
                  ],
                  'payment_attempts': <dynamic>[
                    <String, dynamic>{
                      'attempt_id': 'payatt-1',
                      'attempt_number': 1,
                      'tender_type': 'CASH',
                      'amount_bdt': '100.00',
                      'status': 'CAPTURED',
                      'idempotency_key': 'pay-1',
                    }
                  ],
                }
              ],
            },
          );
        },
      );

      final res = await client.listSales(
        bearerToken: 'tok-owner',
        actorRole: 'PHARMACY_OWNER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );

      expect(res.uiState, MobilePosUiState.ready);
      expect(res.data, hasLength(1));
      final order = res.data!.first;
      expect(order.lifecycleState, MobilePosLifecycleState.finalized);
      expect(order.lifecycleState.isMutable, isFalse);
      expect(order.grandTotalBdt, '115.50');
      expect(order.lines.first.unitCostBdt, '42.0000');

      final emptyClient = MobilePosDomainClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async => const MobilePosHttpResponse(
          statusCode: 200,
          data: <String, dynamic>{'results': <dynamic>[]},
        ),
      );
      final emptyRes = await emptyClient.listSales(
        bearerToken: 'tok-owner',
        actorRole: 'PHARMACY_OWNER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(emptyRes.uiState, MobilePosUiState.empty);
    });

    test('2. Guards Cashier reversal, cross-branch, cross-tenant, suspended plan & offline state', () async {
      final client = MobilePosDomainClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          fail('Transport must not be called when guard rejects');
        },
      );

      final cashierRev = await client.reverseSale(
        saleId: 'sale-1',
        reason: 'Customer return',
        bearerToken: 'tok',
        actorRole: 'CASHIER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
      );
      expect(cashierRev.uiState, MobilePosUiState.permissionDenied);
      expect(cashierRev.errorCode, 'ERR_PERMISSION_DENIED');

      final crossBranch = await client.reverseSale(
        saleId: 'sale-1',
        reason: 'Return',
        bearerToken: 'tok',
        actorRole: 'BRANCH_MANAGER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-other',
      );
      expect(crossBranch.uiState, MobilePosUiState.permissionDenied);
      expect(crossBranch.errorCode, 'ERR_CROSS_BRANCH_ACCESS_DENIED');

      final crossTenant = await client.reverseSale(
        saleId: 'sale-1',
        reason: 'Return',
        bearerToken: 'tok',
        actorRole: 'PHARMACY_OWNER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-b',
        targetBranchId: 'br-b',
      );
      expect(crossTenant.uiState, MobilePosUiState.error);
      expect(crossTenant.errorCode, 'ERR_CROSS_TENANT_VIOLATION');

      final suspended = await client.reverseSale(
        saleId: 'sale-1',
        reason: 'Return',
        bearerToken: 'tok',
        actorRole: 'PHARMACY_OWNER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        subscriptionSuspended: true,
      );
      expect(suspended.uiState, MobilePosUiState.permissionDenied);
      expect(suspended.errorCode, 'ERR_SUBSCRIPTION_SUSPENDED');

      final offline = await client.listSales(
        bearerToken: 'tok',
        actorRole: 'PHARMACY_OWNER',
        actorTenantId: 'ten-a',
        actorBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        isOffline: true,
      );
      expect(offline.uiState, MobilePosUiState.offline);
    });
  });
}

