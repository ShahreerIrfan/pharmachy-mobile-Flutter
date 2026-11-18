// Architecture Decision: ADR-0269 (P269)
// Phase 14: Customers, Suppliers, Dues & Payments.
// Mobile Customer Consent and Communications Client for Manager/Owner Flutter App.

enum MobileCommunicationChannel {
  smsRefillReminders,
  smsDueReminders,
  emailReceipts,
  promotionalCampaigns,
  whatsappNotifications,
}

enum MobileConsentStatus {
  granted,
  revoked,
}

class MobileCustomerConsentClient {
  static const Set<String> statutoryMandatoryChannels = {
    'STATUTORY_TAX_INVOICES',
    'STATUTORY_AR_LEDGER',
    'STATUTORY_PRESCRIPTION_AUDIT',
    'STATUTORY_ANTIBIOTIC_REGISTER',
  };

  static const Set<String> validOptionalChannels = {
    'SMS_REFILL_REMINDERS',
    'SMS_DUE_REMINDERS',
    'EMAIL_RECEIPTS',
    'PROMOTIONAL_CAMPAIGNS',
    'WHATSAPP_NOTIFICATIONS',
  };

  /// Validates that requested channel is an optional communication and not a mandatory statutory record.
  static Map<String, dynamic> validateConsentUpdate({
    required String channel,
    required String status,
  }) {
    final cleanChannel = channel.trim().toUpperCase();
    if (statutoryMandatoryChannels.contains(cleanChannel)) {
      return {
        'isValid': false,
        'errorCode': 'ERR_STATUTORY_RECORD_IMMUTABLE',
        'message':
            'Statutory transaction, ledger, and prescription record keeping is legally mandated under Bangladesh law and cannot be opted out of.',
      };
    }

    if (!validOptionalChannels.contains(cleanChannel)) {
      return {
        'isValid': false,
        'errorCode': 'ERR_INVALID_CONSENT_CHANNEL',
        'message': 'Unknown optional communication channel: $channel',
      };
    }

    final cleanStatus = status.trim().toUpperCase();
    if (cleanStatus != 'GRANTED' && cleanStatus != 'REVOKED') {
      return {
        'isValid': false,
        'errorCode': 'ERR_INVALID_CONSENT_STATUS',
        'message': 'Status must be GRANTED or REVOKED.',
      };
    }

    return {'isValid': true, 'errorCode': null, 'message': null};
  }
}
