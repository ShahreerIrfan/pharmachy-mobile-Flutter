import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_subscription_activation_gate_client.dart';

void main() {
  group('P085 - Mobile Subscription Activation Gate Client Tests', () {
    test('Safe read-only methods are always permitted regardless of subscription status', () {
      const statuses = ['SUSPENDED', 'EXPIRED', 'CANCELLED', 'PENDING', 'ACTIVE'];
      const methods = ['GET', 'HEAD', 'OPTIONS'];

      for (final status in statuses) {
        for (final method in methods) {
          final decision = MobileSubscriptionActivationGateClient.evaluateGate(
            subscriptionStatus: status,
            httpMethod: method,
            path: '/api/v2/sales/',
          );
          expect(decision.isPermitted, isTrue, reason: 'Method $method must be permitted under status $status');
          expect(decision.decisionCode, equals('READ_ONLY_PERMITTED'));
        }
      }
    });

    test('Authorized billing paths are permitted even when subscription is suspended or expired', () {
      const billingPaths = [
        '/api/v2/billing/subscriptions/tenant-1/verify-payment/',
        '/api/v2/billing/plans/quote/',
        '/api/v2/billing/plans/',
        '/api/v2/billing/entitlements/tenant-1/apply/',
      ];

      for (final path in billingPaths) {
        final decision = MobileSubscriptionActivationGateClient.evaluateGate(
          subscriptionStatus: 'SUSPENDED',
          httpMethod: 'POST',
          path: path,
        );
        expect(decision.isPermitted, isTrue, reason: 'Billing path $path must be permitted even when SUSPENDED');
        expect(decision.decisionCode, equals('EXEMPT_PATH'));
      }
    });

    test('Operational ERP writes are blocked when subscription is unentitled', () {
      const unentitled = ['SUSPENDED', 'EXPIRED', 'CANCELLED', 'PENDING'];
      const operationalPaths = [
        '/api/v2/sales/checkout/',
        '/api/v2/inventory/adjustments/',
        '/api/v2/procurement/orders/',
        '/api/v2/prescriptions/dispense/',
      ];

      for (final status in unentitled) {
        for (final path in operationalPaths) {
          final decision = MobileSubscriptionActivationGateClient.evaluateGate(
            subscriptionStatus: status,
            httpMethod: 'POST',
            path: path,
          );
          expect(decision.isPermitted, isFalse, reason: 'Operational write to $path must be blocked under $status');
          expect(decision.decisionCode, equals('ERR_SUBSCRIPTION_UNENTITLED_WRITE_BLOCKED'));
          expect(decision.messageEn, contains('does not permit data mutations'));
        }
      }
    });

    test('Operational ERP writes are permitted when subscription is active, trial, or past due', () {
      const entitled = ['ACTIVE', 'TRIAL', 'PAST_DUE', 'GRACE_PERIOD'];

      for (final status in entitled) {
        final decision = MobileSubscriptionActivationGateClient.evaluateGate(
          subscriptionStatus: status,
          httpMethod: 'POST',
          path: '/api/v2/sales/checkout/',
        );
        expect(decision.isPermitted, isTrue, reason: 'Operational write must be permitted under entitled $status');
        expect(decision.decisionCode, equals('ENTITLED'));
      }
    });
  });
}
