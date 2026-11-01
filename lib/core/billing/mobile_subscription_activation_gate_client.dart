/// mobile_subscription_activation_gate_client.dart
///
/// Architecture Decision: ADR-0013, ADR-0015, ADR-0033, ADR-0084 & ADR-0085
/// Phase 05: Basic/Standard/Pro Subscription & Billing (P085)
///
/// Mobile Manager Subscription Activation Gate Client:
///   - Validates client-side operations to prevent unentitled ERP writes.
///   - Permits safe read-only methods (GET, HEAD, OPTIONS) for reporting and history.
///   - Permits authorized billing routes (/api/v2/billing/*) for renewals and quotes.
///   - Surfaces clear bilingual prompts with direct navigation to payment renewal.
library mobile_subscription_activation_gate_client;

class GateDecision {
  final bool isPermitted;
  final String decisionCode;
  final String messageEn;
  final String messageBn;

  const GateDecision({
    required this.isPermitted,
    required this.decisionCode,
    required this.messageEn,
    required this.messageBn,
  });
}

class MobileSubscriptionActivationGateClient {
  static const Set<String> safeHttpMethods = {'GET', 'HEAD', 'OPTIONS'};

  static const Set<String> unentitledStatuses = {
    'SUSPENDED',
    'CANCELLED',
    'EXPIRED',
    'PENDING',
  };

  static const Set<String> entitledStatuses = {
    'ACTIVE',
    'TRIAL',
    'PAST_DUE',
    'GRACE_PERIOD',
  };

  static const List<String> exemptPathPrefixes = [
    '/api/v2/billing/',
    '/api/v2/auth/',
    '/api/v2/health',
    '/health/',
    '/api/v2/docs',
    '/api/v2/schema',
    '/api/v2/platform/',
    '/api/v2/support/',
  ];

  /// Evaluates whether an HTTP operation is permitted under current subscription state.
  static GateDecision evaluateGate({
    required String subscriptionStatus,
    required String httpMethod,
    required String path,
  }) {
    final methodUpper = httpMethod.toUpperCase().trim();
    final cleanPath = path.trim();

    // 1. Safe read-only methods
    if (safeHttpMethods.contains(methodUpper)) {
      return const GateDecision(
        isPermitted: true,
        decisionCode: 'READ_ONLY_PERMITTED',
        messageEn: 'Read-only request is permitted for regulatory and audit viewing.',
        messageBn: 'রেগুলেটরি ও অডিট দেখার জন্য রিড-অনলি রিকোয়েস্ট অনুমোদিত।',
      );
    }

    // 2. Exempt paths (Billing, Auth, Health, etc.)
    if (isPathExempt(cleanPath)) {
      return const GateDecision(
        isPermitted: true,
        decisionCode: 'EXEMPT_PATH',
        messageEn: 'Path is an authorized billing or reconciliation route.',
        messageBn: 'রুটটি অনুমোদিত বিলিং বা পুনর্মিলন পথ।',
      );
    }

    // 3. Subscription Status Check
    final statusUpper = subscriptionStatus.toUpperCase().trim();
    if (unentitledStatuses.contains(statusUpper)) {
      return GateDecision(
        isPermitted: false,
        decisionCode: 'ERR_SUBSCRIPTION_UNENTITLED_WRITE_BLOCKED',
        messageEn: 'Operational ERP write rejected: Subscription status \'$statusUpper\' does not permit data mutations.',
        messageBn: 'অপারেশনাল ডেটা পরিবর্তন প্রত্যাখ্যাত: সাবস্ক্রিপশন স্ট্যাটাস \'$statusUpper\' নতুন তথ্য যুক্ত বা পরিবর্তন করার অনুমতি দেয় না।',
      );
    }

    return const GateDecision(
      isPermitted: true,
      decisionCode: 'ENTITLED',
      messageEn: 'Subscription is entitled for operational ERP writes.',
      messageBn: 'সাবস্ক্রিপশন অপারেশনাল ডেটা পরিবর্তনের জন্য সক্রিয়।',
    );
  }

  static bool isPathExempt(String path) {
    for (final prefix in exemptPathPrefixes) {
      if (path.startsWith(prefix)) return true;
    }
    return false;
  }

  static String getBillingRenewalUrl(String tenantId) {
    return '/api/v2/billing/subscriptions/${tenantId.trim()}/';
  }
}
