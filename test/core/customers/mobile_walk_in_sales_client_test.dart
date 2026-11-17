import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/customers/mobile_walk_in_sales_client.dart';

void main() {
  group('P262: Mobile Walk-In Sales Client Tests', () {
    test('identifies walk-in anonymous customers accurately', () {
      expect(MobileWalkInSalesClient.isWalkInCustomer(null), isTrue);
      expect(MobileWalkInSalesClient.isWalkInCustomer(''), isTrue);
      expect(MobileWalkInSalesClient.isWalkInCustomer('  '), isTrue);
      expect(MobileWalkInSalesClient.isWalkInCustomer('WALK_IN'), isTrue);
      expect(MobileWalkInSalesClient.isWalkInCustomer('cust-12345'), isFalse);
    });

    test('strictly forbids credit/due tenders for anonymous walk-in sales', () {
      expect(MobileWalkInSalesClient.canTenderCredit(null), isFalse);
      expect(MobileWalkInSalesClient.canTenderCredit('cust-12345'), isTrue);

      expect(
        () => MobileWalkInSalesClient.validateWalkInTender(null, 'DUE'),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => MobileWalkInSalesClient.validateWalkInTender('cust-12345', 'DUE'),
        returnsNormally,
      );

      expect(
        () => MobileWalkInSalesClient.validateWalkInTender(null, 'CASH'),
        returnsNormally,
      );
    });

    test('resolves default names and formats bilingual receipt banners', () {
      expect(
        MobileWalkInSalesClient.getCustomerDisplayName(null, lang: 'en'),
        equals('Walk-in Customer'),
      );
      expect(
        MobileWalkInSalesClient.getCustomerDisplayName(null, lang: 'bn'),
        equals('ওয়াক-ইন ক্রেতা'),
      );
      expect(
        MobileWalkInSalesClient.getCustomerDisplayName('Kazi Nazrul', lang: 'en'),
        equals('Kazi Nazrul'),
      );

      final bannerBn = MobileWalkInSalesClient.formatReceiptBanner(
        orderNumber: 'SO-101',
        isAnonymous: true,
        lang: 'bn',
      );
      expect(bannerBn, contains('সাধারণ ওয়াক-ইন বিক্রয়'));

      final bannerEn = MobileWalkInSalesClient.formatReceiptBanner(
        orderNumber: 'SO-101',
        isAnonymous: true,
        lang: 'en',
      );
      expect(bannerEn, contains('Anonymous Counter Sale (Privacy Preserved)'));
    });
  });
}

