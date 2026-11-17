// test/core/inventory/mobile_supply_chain_alert_test.dart
// Unit tests for P214: Supply chain stock alerts (Flutter Mobile Manager App)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_supply_chain_alert_client.dart';

void main() {
  group('P214: Mobile Supply Chain Stock Alerts Tests', () {
    late MobileSupplyChainAlertClient client;

    setUp(() {
      client = MobileSupplyChainAlertClient();
    });

    test('P214-M-1: Stockout and Reorder alerts generate with correct severity', () {
      final stockout = client.evaluateStockLevel(
        tenantId: 'ten-01',
        branchId: 'br-01',
        productId: 'prod-01',
        productName: 'Napa Extra',
        currentQty: 0,
        reorderLevel: 20,
      );

      expect(stockout.alertType, equals(MobileStockAlertType.stockout));
      expect(stockout.severity, equals(MobileAlertSeverity.critical));
      expect(stockout.status, equals(MobileAlertStatus.open));
      expect(stockout.occurredCount, equals(1));

      final reorder = client.evaluateStockLevel(
        tenantId: 'ten-01',
        branchId: 'br-01',
        productId: 'prod-02',
        productName: 'Amoxicillin 500mg',
        currentQty: 10,
        reorderLevel: 25,
      );

      expect(reorder.alertType, equals(MobileStockAlertType.reorderRequired));
      expect(reorder.severity, equals(MobileAlertSeverity.warning));
    });

    test('P214-M-2: Alert deduplication increments occurredCount without duplicate records', () {
      final a1 = client.evaluateStockLevel(
        tenantId: 'ten-01',
        branchId: 'br-01',
        productId: 'prod-01',
        productName: 'Napa Extra',
        currentQty: 0,
        reorderLevel: 20,
      );
      expect(a1.occurredCount, equals(1));

      final a2 = client.evaluateStockLevel(
        tenantId: 'ten-01',
        branchId: 'br-01',
        productId: 'prod-01',
        productName: 'Napa Extra',
        currentQty: 0,
        reorderLevel: 20,
      );

      expect(a2.alertId, equals(a1.alertId));
      expect(a2.occurredCount, equals(2));

      final active = client.listActiveAlerts('ten-01', branchId: 'br-01');
      expect(active.length, equals(1));
    });

    test('P214-M-3: Cold chain temperature risk alert generated upon excursion', () {
      final alert = client.evaluateTemperatureRisk(
        tenantId: 'ten-01',
        branchId: 'br-01',
        locationId: 'loc-fridge',
        locationName: 'Vaccine Fridge 1',
        recordedTemp: 14.5,
      );

      expect(alert.alertType, equals(MobileStockAlertType.temperatureRisk));
      expect(alert.severity, equals(MobileAlertSeverity.critical));
    });

    test('P214-M-4: Lifecycle transitions (Acknowledge and Resolve)', () {
      final alert = client.evaluateStockLevel(
        tenantId: 'ten-01',
        branchId: 'br-01',
        productId: 'prod-01',
        productName: 'Napa Extra',
        currentQty: 5,
        reorderLevel: 20,
      );

      final acked = client.acknowledgeAlert(
        userRole: 'STAFF_PHARMACIST',
        alertId: alert.alertId,
        username: 'pharmacist_ashraf',
        notes: 'Order placed',
      );
      expect(acked.status, equals(MobileAlertStatus.acknowledged));
      expect(acked.acknowledgedBy, equals('pharmacist_ashraf'));

      final resolved = client.resolveAlert(
        userRole: 'STAFF_PHARMACIST',
        alertId: alert.alertId,
        username: 'pharmacist_ashraf',
        resolutionNotes: 'Order received',
      );
      expect(resolved.status, equals(MobileAlertStatus.resolved));
    });

    test('P214-M-5: Cashier role is rejected from managing alerts', () {
      final alert = client.evaluateStockLevel(
        tenantId: 'ten-01',
        branchId: 'br-01',
        productId: 'prod-01',
        productName: 'Napa Extra',
        currentQty: 0,
        reorderLevel: 20,
      );

      expect(
        () => client.acknowledgeAlert(
          userRole: 'CASHIER',
          alertId: alert.alertId,
          username: 'cashier_rahim',
        ),
        throwsException,
      );
    });
  });
}
