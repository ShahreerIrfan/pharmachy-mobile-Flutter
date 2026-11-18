import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/customers/mobile_customer_search_merge_client.dart';

void main() {
  group('MobileCustomerSearchMergeClient Tests (P268)', () {
    test('normalizeBdPhone correctly normalizes various BD phone formats', () {
      final res1 = MobileCustomerSearchMergeClient.normalizeBdPhone('01712345678');
      expect(res1.isValidBd, isTrue);
      expect(res1.local11, equals('01712345678'));
      expect(res1.e164, equals('+8801712345678'));
      expect(res1.variants, contains('01712345678'));
      expect(res1.variants, contains('+8801712345678'));

      final res2 = MobileCustomerSearchMergeClient.normalizeBdPhone('+880 1812-345678');
      expect(res2.isValidBd, isTrue);
      expect(res2.local11, equals('01812345678'));
      expect(res2.e164, equals('+8801812345678'));

      final res3 = MobileCustomerSearchMergeClient.normalizeBdPhone('1912345678');
      expect(res3.isValidBd, isTrue);
      expect(res3.local11, equals('01912345678'));
    });

    test('validateMergeInputs rejects self merge and invalid inputs', () {
      final selfMerge = MobileCustomerSearchMergeClient.validateMergeInputs(
        sourceCustomerId: 'cust-123',
        targetCustomerId: 'cust-123',
        mergeReason: 'Duplicate profile created by mistake',
        userRole: 'PHARMACY_OWNER',
      );
      expect(selfMerge['isValid'], isFalse);
      expect(selfMerge['errorCode'], equals('ERR_SELF_MERGE_FORBIDDEN'));

      final shortReason = MobileCustomerSearchMergeClient.validateMergeInputs(
        sourceCustomerId: 'cust-1',
        targetCustomerId: 'cust-2',
        mergeReason: 'ok',
        userRole: 'PHARMACY_OWNER',
      );
      expect(shortReason['isValid'], isFalse);
      expect(shortReason['errorCode'], equals('ERR_MERGE_REASON_REQUIRED'));
    });

    test('validateMergeInputs enforces RBAC restrictions for Cashiers', () {
      final cashierRes = MobileCustomerSearchMergeClient.validateMergeInputs(
        sourceCustomerId: 'cust-1',
        targetCustomerId: 'cust-2',
        mergeReason: 'Duplicate profile created by mistake',
        userRole: 'CASHIER',
      );
      expect(cashierRes['isValid'], isFalse);
      expect(cashierRes['errorCode'], equals('ERR_PERMISSION_DENIED'));

      final ownerRes = MobileCustomerSearchMergeClient.validateMergeInputs(
        sourceCustomerId: 'cust-1',
        targetCustomerId: 'cust-2',
        mergeReason: 'Duplicate profile created by mistake',
        userRole: 'PHARMACY_OWNER',
      );
      expect(ownerRes['isValid'], isTrue);
    });
  });
}
