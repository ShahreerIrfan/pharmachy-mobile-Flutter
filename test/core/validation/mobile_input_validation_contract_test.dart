import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/validation/mobile_input_validation_contract.dart';

void main() {
  group('P046: Mobile Manager Input Validation Contract & Guardrails Tests',
      () {
    test('Validates exact monetary Decimal scale and non-negativity', () {
      expect(
        MobileInputValidationContract.validateMoney(150.50, fieldName: 'price'),
        150.50,
      );
      expect(
        () => MobileInputValidationContract.validateMoney(-5.0,
            fieldName: 'price'),
        throwsFormatException,
      );
    });

    test('Validates positive quantities and rejects zero or negative', () {
      expect(MobileInputValidationContract.validateQuantity(10), 10);
      expect(
        () => MobileInputValidationContract.validateQuantity(0),
        throwsFormatException,
      );
      expect(
        () => MobileInputValidationContract.validateQuantity(-2),
        throwsFormatException,
      );
    });

    test('Normalizes valid Bangladesh phone numbers and rejects malformed', () {
      expect(
        MobileInputValidationContract.validatePhone('01712-345678'),
        '+8801712345678',
      );
      expect(
        MobileInputValidationContract.validatePhone('+8801812345678'),
        '+8801812345678',
      );
      expect(
        () => MobileInputValidationContract.validatePhone('01123456789'),
        throwsFormatException,
      );
    });

    test('Validates discount bounds against gross total', () {
      expect(
        () => MobileInputValidationContract.validateDiscount(500.0, 50.0),
        returnsNormally,
      );
      expect(
        () => MobileInputValidationContract.validateDiscount(500.0, 600.0),
        throwsFormatException,
      );
    });

    test('Parses server 422 error payload conforming to ADR-0014 and ADR-0046',
        () {
      final payload = {
        'error_code': 'ERR_VALIDATION_FAILED',
        'message_en': 'One or more input fields failed validation.',
        'message_bn': 'তথ্য যাচাইকরণ ব্যর্থ হয়েছে।',
        'is_retryable': false,
        'field_errors': {
          'quantity': ['Quantity must be positive.'],
          'mrp_unit': ['MRP cannot be less than cost price.']
        }
      };

      final error = MobileValidationError.fromJson(payload);
      expect(error.errorCode, 'ERR_VALIDATION_FAILED');
      expect(error.messageEn, 'One or more input fields failed validation.');
      expect(error.messageBn, 'তথ্য যাচাইকরণ ব্যর্থ হয়েছে।');
      expect(error.isRetryable, isFalse);
      expect(error.fieldErrors.containsKey('quantity'), isTrue);
      expect(error.fieldErrors['quantity'], ['Quantity must be positive.']);
      expect(error.localizedMessage('en'),
          'One or more input fields failed validation.');
      expect(error.localizedMessage('bn'), 'তথ্য যাচাইকরণ ব্যর্থ হয়েছে।');
    });
  });
}
