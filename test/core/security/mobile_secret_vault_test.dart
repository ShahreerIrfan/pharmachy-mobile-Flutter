import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_secret_vault.dart';

void main() {
  group('MobileSecretVault (ADR-0037)', () {
    test('stores secret and generates masked preview', () {
      final vault = MobileSecretVault(tenantId: 'tenant-dhaka-central');
      vault.storeSecret('DEVICE_TOKEN', 'mob-token-9988776655-secret');

      expect(vault.hasSecret('DEVICE_TOKEN'), isTrue);
      expect(vault.getSecret('DEVICE_TOKEN'), 'mob-token-9988776655-secret');

      final preview = vault.getMaskedPreview('DEVICE_TOKEN');
      expect(preview, 'mob--****-cret');
      expect(preview.contains('9988776655'), isFalse);
    });

    test('empty key or value is rejected', () {
      final vault = MobileSecretVault(tenantId: 'tenant-dhaka-central');
      expect(() => vault.storeSecret('', 'val'), throwsArgumentError);
      expect(() => vault.storeSecret('key', ''), throwsArgumentError);
    });
  });
}

