import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/customers/mobile_customer_consent_client.dart';

void main() {
  group('MobileCustomerConsentClient Tests (P269)', () {
    test('validateConsentUpdate accepts valid optional communication channels', () {
      final res1 = MobileCustomerConsentClient.validateConsentUpdate(
        channel: 'SMS_REFILL_REMINDERS',
        status: 'GRANTED',
      );
      expect(res1['isValid'], isTrue);

      final res2 = MobileCustomerConsentClient.validateConsentUpdate(
        channel: 'PROMOTIONAL_CAMPAIGNS',
        status: 'REVOKED',
      );
      expect(res2['isValid'], isTrue);
    });

    test('validateConsentUpdate rejects attempts to opt out of statutory mandatory records', () {
      final resTax = MobileCustomerConsentClient.validateConsentUpdate(
        channel: 'STATUTORY_TAX_INVOICES',
        status: 'REVOKED',
      );
      expect(resTax['isValid'], isFalse);
      expect(resTax['errorCode'], equals('ERR_STATUTORY_RECORD_IMMUTABLE'));

      final resRx = MobileCustomerConsentClient.validateConsentUpdate(
        channel: 'STATUTORY_PRESCRIPTION_AUDIT',
        status: 'REVOKED',
      );
      expect(resRx['isValid'], isFalse);
      expect(resRx['errorCode'], equals('ERR_STATUTORY_RECORD_IMMUTABLE'));
    });

    test('validateConsentUpdate rejects invalid status or unknown channel', () {
      final badChannel = MobileCustomerConsentClient.validateConsentUpdate(
        channel: 'UNKNOWN_RANDOM_CHANNEL',
        status: 'GRANTED',
      );
      expect(badChannel['isValid'], isFalse);
      expect(badChannel['errorCode'], equals('ERR_INVALID_CONSENT_CHANNEL'));

      final badStatus = MobileCustomerConsentClient.validateConsentUpdate(
        channel: 'EMAIL_RECEIPTS',
        status: 'MAYBE',
      );
      expect(badStatus['isValid'], isFalse);
      expect(badStatus['errorCode'], equals('ERR_INVALID_CONSENT_STATUS'));
    });
  });
}
