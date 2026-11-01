import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_subscription_state_machine_client.dart';

void main() {
  group('P084 - Mobile Subscription State Machine Client Tests', () {
    test('Guarded transitions adhere strictly to ADR-0084 FSM state graph', () {
      // Valid Transitions
      expect(
        MobileSubscriptionStateMachineClient.canTransition(
          MobileSubscriptionState.pending,
          MobileSubscriptionState.trial,
        ),
        isTrue,
      );
      expect(
        MobileSubscriptionStateMachineClient.canTransition(
          MobileSubscriptionState.trial,
          MobileSubscriptionState.active,
        ),
        isTrue,
      );
      expect(
        MobileSubscriptionStateMachineClient.canTransition(
          MobileSubscriptionState.active,
          MobileSubscriptionState.pastDue,
        ),
        isTrue,
      );
      expect(
        MobileSubscriptionStateMachineClient.canTransition(
          MobileSubscriptionState.pastDue,
          MobileSubscriptionState.gracePeriod,
        ),
        isTrue,
      );
      expect(
        MobileSubscriptionStateMachineClient.canTransition(
          MobileSubscriptionState.gracePeriod,
          MobileSubscriptionState.suspended,
        ),
        isTrue,
      );
      expect(
        MobileSubscriptionStateMachineClient.canTransition(
          MobileSubscriptionState.suspended,
          MobileSubscriptionState.active,
        ),
        isTrue,
      );

      // Invalid Transitions
      expect(
        MobileSubscriptionStateMachineClient.canTransition(
          MobileSubscriptionState.pending,
          MobileSubscriptionState.suspended,
        ),
        isFalse,
      );
      expect(
        MobileSubscriptionStateMachineClient.canTransition(
          MobileSubscriptionState.trial,
          MobileSubscriptionState.pastDue,
        ),
        isFalse,
      );
      expect(
        MobileSubscriptionStateMachineClient.canTransition(
          MobileSubscriptionState.expired,
          MobileSubscriptionState.suspended,
        ),
        isFalse,
      );
    });

    test('Checkout lockout and delinquency statuses are accurately determined', () {
      // Permitted Checkouts
      expect(MobileSubscriptionStateMachineClient.isCheckoutAllowed(MobileSubscriptionState.active), isTrue);
      expect(MobileSubscriptionStateMachineClient.isCheckoutAllowed(MobileSubscriptionState.trial), isTrue);
      expect(MobileSubscriptionStateMachineClient.isCheckoutAllowed(MobileSubscriptionState.pastDue), isTrue);
      expect(MobileSubscriptionStateMachineClient.isCheckoutAllowed(MobileSubscriptionState.gracePeriod), isTrue);

      // Locked Out Checkouts
      expect(MobileSubscriptionStateMachineClient.isCheckoutAllowed(MobileSubscriptionState.suspended), isFalse);
      expect(MobileSubscriptionStateMachineClient.isCheckoutAllowed(MobileSubscriptionState.cancelled), isFalse);
      expect(MobileSubscriptionStateMachineClient.isCheckoutAllowed(MobileSubscriptionState.expired), isFalse);
      expect(MobileSubscriptionStateMachineClient.isCheckoutAllowed(MobileSubscriptionState.pending), isFalse);

      // Delinquency
      expect(MobileSubscriptionStateMachineClient.isDelinquent(MobileSubscriptionState.pastDue), isTrue);
      expect(MobileSubscriptionStateMachineClient.isDelinquent(MobileSubscriptionState.gracePeriod), isTrue);
      expect(MobileSubscriptionStateMachineClient.isDelinquent(MobileSubscriptionState.suspended), isTrue);
      expect(MobileSubscriptionStateMachineClient.isDelinquent(MobileSubscriptionState.active), isFalse);
      expect(MobileSubscriptionStateMachineClient.isDelinquent(MobileSubscriptionState.trial), isFalse);
    });

    test('Invariant INV-SAFETY-01: Clinical safety controls are entitled even under SUSPENDED or EXPIRED state', () {
      const allStates = MobileSubscriptionState.values;
      const safetyControls = [
        'ANTIBIOTIC_REGISTER',
        'BATCH_EXPIRY_BLOCK',
        'RECALL_QUARANTINE',
        'BANNED_DRUG_RESTRICTION',
        'RX_VERIFICATION',
      ];

      for (final state in allStates) {
        for (final control in safetyControls) {
          expect(
            MobileSubscriptionStateMachineClient.isFeatureEntitled(state, control),
            isTrue,
            reason: 'Safety control $control must be entitled under status $state',
          );
        }
      }

      // Commercial feature blocked under SUSPENDED
      expect(
        MobileSubscriptionStateMachineClient.isFeatureEntitled(
          MobileSubscriptionState.suspended,
          'COMMERCIAL_REPORTS',
        ),
        isFalse,
      );
    });

    test('Mandatory reason guard and localized bilingual labels', () {
      expect(MobileSubscriptionStateMachineClient.requiresReason(MobileSubscriptionState.suspended), isTrue);
      expect(MobileSubscriptionStateMachineClient.requiresReason(MobileSubscriptionState.cancelled), isTrue);
      expect(MobileSubscriptionStateMachineClient.requiresReason(MobileSubscriptionState.expired), isTrue);
      expect(MobileSubscriptionStateMachineClient.requiresReason(MobileSubscriptionState.active), isFalse);

      // Localization
      expect(
        MobileSubscriptionStateMachineClient.getStatusLabel(MobileSubscriptionState.active, 'en'),
        equals('Active'),
      );
      expect(
        MobileSubscriptionStateMachineClient.getStatusLabel(MobileSubscriptionState.active, 'bn'),
        equals('সক্রিয়'),
      );
      expect(
        MobileSubscriptionStateMachineClient.getStatusLabel(MobileSubscriptionState.suspended, 'bn'),
        equals('সাময়িক স্থগিত'),
      );
    });
  });
}
