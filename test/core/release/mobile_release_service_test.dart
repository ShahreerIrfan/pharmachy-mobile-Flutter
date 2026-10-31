import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/release/mobile_release_service.dart';

void main() {
  group('P038: Mobile Release & Compatibility Test Suite', () {
    test('MobileSemVer parses and compares properly', () {
      final v1 = MobileSemVer.parse('1.0.0');
      final v2 = MobileSemVer.parse('1.1.0');
      final v3 = MobileSemVer.parse('2.0.0-rc.1');

      expect(v1.compareTo(v2) < 0, isTrue);
      expect(v2.compareTo(v1) > 0, isTrue);
      expect(v2.compareTo(v3) < 0, isTrue);
      expect(MobileSemVer.parse('v1.1.0').toString(), equals('1.1.0'));
    });

    test('Local compatibility evaluation returns correct statuses and banners',
        () {
      final resSupported = MobileReleaseService.evaluateLocal(
        clientVersion: '1.1.0',
        minSupported: '1.0.0',
        targetVersion: '1.1.0',
      );
      expect(resSupported.status, equals(MobileCompatibilityStatus.supported));
      expect(resSupported.isUpgradeRequired, isFalse);
      expect(resSupported.messageBn, contains('সম্পূর্ণ সমর্থিত'));

      final resDeprecated = MobileReleaseService.evaluateLocal(
        clientVersion: '1.0.5',
        minSupported: '1.0.0',
        targetVersion: '1.1.0',
      );
      expect(
          resDeprecated.status, equals(MobileCompatibilityStatus.deprecated));
      expect(resDeprecated.isUpgradeRequired, isFalse);
      expect(resDeprecated.messageEn, contains('deprecated'));

      final resBlocked = MobileReleaseService.evaluateLocal(
        clientVersion: '0.9.0',
        minSupported: '1.0.0',
        targetVersion: '1.1.0',
      );
      expect(
          resBlocked.status, equals(MobileCompatibilityStatus.upgradeRequired));
      expect(resBlocked.isUpgradeRequired, isTrue);
      expect(resBlocked.messageBn, contains('আপগ্রেড করুন'));
    });

    test('Invalid SemVer strings throw FormatException', () {
      expect(() => MobileSemVer.parse('invalid-semver'), throwsFormatException);
      expect(() => MobileSemVer.parse('1.2'), throwsFormatException);
    });
  });
}
