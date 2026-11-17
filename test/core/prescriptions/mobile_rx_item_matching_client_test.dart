/// mobile/test/core/prescriptions/mobile_rx_item_matching_client_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_rx_item_matching_client.dart';

void main() {
  group('MobileRxItemMatchingClient Tests', () {
    test('Exact match and authorized quantity passes', () {
      final line = MobileRxItemMatchingClient.matchCartLine(
        prescribedProductId: 'prod-cefix-01',
        prescribedBrandName: 'Cef-3 200mg',
        remainingAuthorizedQty: 14,
        cartProductId: 'prod-cefix-01',
        cartBrandName: 'Cef-3 200mg',
        cartQuantity: 10,
        isRxRequired: true,
      );

      expect(line.isSuccess, isTrue);
      expect(line.matchStatus, equals(MobileMatchStatus.matched));
      expect(line.remainingQuantity, equals(4));
      expect(line.error, isNull);
      expect(line.matchStatus.getLocalized('bn'), equals('অনুমোদিত ও মিলেছে'));
    });

    test('Automated treatment substitution prohibited', () {
      final line = MobileRxItemMatchingClient.matchCartLine(
        prescribedProductId: 'prod-cefix-01',
        prescribedBrandName: 'Cef-3 200mg',
        remainingAuthorizedQty: 14,
        cartProductId: 'prod-azithro-01',
        cartBrandName: 'Zimax 500mg',
        cartQuantity: 10,
        isRxRequired: true,
      );

      expect(line.isSuccess, isFalse);
      expect(line.matchStatus, equals(MobileMatchStatus.substitutionProhibited));
      expect(line.error, contains('Automated treatment substitution prohibited'));
      expect(line.matchStatus.getLocalized('bn'), equals('অননুমোদিত ব্র্যান্ড প্রতিস্থাপন নিষিদ্ধ'));
    });

    test('Over quantity detected', () {
      final line = MobileRxItemMatchingClient.matchCartLine(
        prescribedProductId: 'prod-cefix-01',
        prescribedBrandName: 'Cef-3 200mg',
        remainingAuthorizedQty: 5,
        cartProductId: 'prod-cefix-01',
        cartBrandName: 'Cef-3 200mg',
        cartQuantity: 10,
        isRxRequired: true,
      );

      expect(line.isSuccess, isFalse);
      expect(line.matchStatus, equals(MobileMatchStatus.exceedsQuantity));
      expect(line.error, contains('exceeds remaining authorized quota'));
    });

    test('JSON DTO parsing of match report', () {
      final json = {
        'prescription_id': 'rx-match-123',
        'all_matched': true,
        'can_proceed': true,
        'matched_items': [
          {
            'product_id': 'prod-cefix-01',
            'product_name': 'Cef-3 200mg',
            'requested_quantity': 7,
            'match_status': 'MATCHED',
            'remaining_quantity_after_sale': 7,
          }
        ],
        'overall_errors': [],
      };

      final report = MobileMatchingReportDto.fromJson(json);
      expect(report.prescriptionId, equals('rx-match-123'));
      expect(report.allMatched, isTrue);
      expect(report.canProceed, isTrue);
      expect(report.matchedItems.length, equals(1));
      expect(report.matchedItems.first.matchStatus, equals(MobileMatchStatus.matched));
    });
  });
}

