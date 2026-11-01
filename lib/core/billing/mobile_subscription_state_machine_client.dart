/// mobile_subscription_state_machine_client.dart
///
/// Architecture Decision: ADR-0013, ADR-0015, ADR-0033 & ADR-0084
/// Phase 05: Basic/Standard/Pro Subscription & Billing (P084)
///
/// Mobile Manager Subscription State Machine Client:
///   - Guarded transitions: PENDING, TRIAL, ACTIVE, PAST_DUE, GRACE_PERIOD, SUSPENDED, CANCELLED, EXPIRED.
///   - Checkout lockout evaluation: SUSPENDED, CANCELLED, and EXPIRED lock out POS cash checkouts.
///   - Delinquency detection: PAST_DUE and GRACE_PERIOD allow checkouts with persistent warning alerts.
///   - Invariant INV-SAFETY-01: Clinical safety controls are NEVER gated, even when suspended.
library mobile_subscription_state_machine_client;

enum MobileSubscriptionState {
  pending,
  trial,
  active,
  pastDue,
  gracePeriod,
  suspended,
  cancelled,
  expired,
}

class MobileSubscriptionStateMachineClient {
  static const Set<String> clinicalSafetyFeatures = {
    'ANTIBIOTIC_REGISTER',
    'BATCH_EXPIRY_BLOCK',
    'RECALL_QUARANTINE',
    'BANNED_DRUG_RESTRICTION',
    'RX_VERIFICATION',
  };

  /// Invariant INV-SAFETY-01: Verifies whether clinical features remain active regardless of subscription state.
  static bool isFeatureEntitled(MobileSubscriptionState? status, String? featureKey) {
    if (featureKey == null || featureKey.trim().isEmpty) return false;
    final clean = featureKey.toUpperCase().trim();
    if (clinicalSafetyFeatures.contains(clean)) {
      return true; // Clinical safety controls are NEVER gated
    }
    if (status == null || !isCheckoutAllowed(status)) {
      return false;
    }
    return true;
  }

  /// Evaluates whether POS sales checkouts are permitted for the given status.
  static bool isCheckoutAllowed(MobileSubscriptionState? status) {
    if (status == null) return false;
    switch (status) {
      case MobileSubscriptionState.trial:
      case MobileSubscriptionState.active:
      case MobileSubscriptionState.pastDue:
      case MobileSubscriptionState.gracePeriod:
        return true;
      case MobileSubscriptionState.pending:
      case MobileSubscriptionState.suspended:
      case MobileSubscriptionState.cancelled:
      case MobileSubscriptionState.expired:
        return false;
    }
  }

  /// Returns true if the subscription requires immediate payment settlement.
  static bool isDelinquent(MobileSubscriptionState? status) {
    if (status == null) return false;
    switch (status) {
      case MobileSubscriptionState.pastDue:
      case MobileSubscriptionState.gracePeriod:
      case MobileSubscriptionState.suspended:
      case MobileSubscriptionState.expired:
        return true;
      case MobileSubscriptionState.pending:
      case MobileSubscriptionState.trial:
      case MobileSubscriptionState.active:
      case MobileSubscriptionState.cancelled:
        return false;
    }
  }

  /// Guard: checks if the state transition is valid under ADR-0084.
  static bool canTransition(MobileSubscriptionState from, MobileSubscriptionState to) {
    if (from == to) return true;

    switch (from) {
      case MobileSubscriptionState.pending:
        return to == MobileSubscriptionState.trial ||
            to == MobileSubscriptionState.active ||
            to == MobileSubscriptionState.cancelled;
      case MobileSubscriptionState.trial:
        return to == MobileSubscriptionState.active ||
            to == MobileSubscriptionState.expired ||
            to == MobileSubscriptionState.cancelled;
      case MobileSubscriptionState.active:
        return to == MobileSubscriptionState.pastDue ||
            to == MobileSubscriptionState.gracePeriod ||
            to == MobileSubscriptionState.suspended ||
            to == MobileSubscriptionState.cancelled;
      case MobileSubscriptionState.pastDue:
        return to == MobileSubscriptionState.active ||
            to == MobileSubscriptionState.gracePeriod ||
            to == MobileSubscriptionState.suspended ||
            to == MobileSubscriptionState.cancelled;
      case MobileSubscriptionState.gracePeriod:
        return to == MobileSubscriptionState.active ||
            to == MobileSubscriptionState.suspended ||
            to == MobileSubscriptionState.expired ||
            to == MobileSubscriptionState.cancelled;
      case MobileSubscriptionState.suspended:
        return to == MobileSubscriptionState.active ||
            to == MobileSubscriptionState.cancelled ||
            to == MobileSubscriptionState.expired;
      case MobileSubscriptionState.cancelled:
        return to == MobileSubscriptionState.active || to == MobileSubscriptionState.expired;
      case MobileSubscriptionState.expired:
        return to == MobileSubscriptionState.active;
    }
  }

  /// Guard: checks if transitioning to the target state requires a mandatory non-empty reason.
  static bool requiresReason(MobileSubscriptionState target) {
    switch (target) {
      case MobileSubscriptionState.suspended:
      case MobileSubscriptionState.cancelled:
      case MobileSubscriptionState.expired:
      case MobileSubscriptionState.pastDue:
        return true;
      case MobileSubscriptionState.pending:
      case MobileSubscriptionState.trial:
      case MobileSubscriptionState.active:
      case MobileSubscriptionState.gracePeriod:
        return false;
    }
  }

  /// Parses string into MobileSubscriptionState.
  static MobileSubscriptionState parseState(String? value) {
    if (value == null) return MobileSubscriptionState.active;
    final clean = value.toUpperCase().replaceAll('-', '_').trim();
    switch (clean) {
      case 'PENDING':
        return MobileSubscriptionState.pending;
      case 'TRIAL':
        return MobileSubscriptionState.trial;
      case 'ACTIVE':
        return MobileSubscriptionState.active;
      case 'PAST_DUE':
        return MobileSubscriptionState.pastDue;
      case 'GRACE_PERIOD':
      case 'GRACE':
        return MobileSubscriptionState.gracePeriod;
      case 'SUSPENDED':
        return MobileSubscriptionState.suspended;
      case 'CANCELLED':
        return MobileSubscriptionState.cancelled;
      case 'EXPIRED':
        return MobileSubscriptionState.expired;
      default:
        return MobileSubscriptionState.active;
    }
  }

  /// Resolves localized bilingual status labels.
  static String getStatusLabel(MobileSubscriptionState status, String locale) {
    final isBn = locale.toUpperCase().startsWith('BN');
    switch (status) {
      case MobileSubscriptionState.pending:
        return isBn ? 'পেমেন্ট অপেক্ষারত' : 'Pending Payment';
      case MobileSubscriptionState.trial:
        return isBn ? 'মূল্যায়ন ট্রায়াল' : 'Evaluation Trial';
      case MobileSubscriptionState.active:
        return isBn ? 'সক্রিয়' : 'Active';
      case MobileSubscriptionState.pastDue:
        return isBn ? 'বকেয়া পেমেন্ট' : 'Past Due';
      case MobileSubscriptionState.gracePeriod:
        return isBn ? 'গ্রেস পিরিয়ড' : 'Grace Period';
      case MobileSubscriptionState.suspended:
        return isBn ? 'সাময়িক স্থগিত' : 'Suspended';
      case MobileSubscriptionState.cancelled:
        return isBn ? 'বাতিলকৃত' : 'Cancelled';
      case MobileSubscriptionState.expired:
        return isBn ? 'মেয়াদোত্তীর্ণ' : 'Expired';
    }
  }
}
