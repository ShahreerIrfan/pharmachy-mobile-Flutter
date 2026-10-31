import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_api_response_envelope.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_file_storage_service.dart';

void main() {
  group('P051: Mobile Manager Private File Storage & Policy Tests', () {
    test(
        '1. Client pre-upload validation approves valid files and rejects executables',
        () {
      expect(
          MobileFileStorageService.validateFile('prescription.jpg', 500 * 1024),
          isTrue);
      expect(
          MobileFileStorageService.validateFile('invoice_nov.pdf', 1024 * 1024),
          isTrue);
      expect(
          MobileFileStorageService.validateFile('dgda_audit.png', 800 * 1024),
          isTrue);

      // Rejects dangerous scripts and executables
      expect(
          MobileFileStorageService.validateFile('malware.exe', 1024), isFalse);
      expect(
          MobileFileStorageService.validateFile('backdoor.sh', 512), isFalse);
      expect(
          MobileFileStorageService.validateFile('payload.php', 2048), isFalse);
      expect(MobileFileStorageService.validateFile('installer.msi', 4096),
          isFalse);

      // Rejects zero or oversized
      expect(
          MobileFileStorageService.validateFile(
              'oversized.pdf', 25 * 1024 * 1024),
          isFalse);
      expect(MobileFileStorageService.validateFile('empty.pdf', 0), isFalse);
      expect(MobileFileStorageService.validateFile('', 1024), isFalse);
    });

    test(
        '2. Scoped Category RBAC enforces Zero-PHI protection against Cashier and SuperAdmin',
        () {
      // Prescription Category
      expect(
          MobileFileStorageService.isAuthorizedForCategory(
              'PHARMACY_OWNER', 'PRESCRIPTION_IMAGE'),
          isTrue);
      expect(
          MobileFileStorageService.isAuthorizedForCategory(
              'BRANCH_MANAGER', 'PRESCRIPTION_IMAGE'),
          isTrue);
      expect(
          MobileFileStorageService.isAuthorizedForCategory(
              'STAFF_PHARMACIST', 'PRESCRIPTION_IMAGE'),
          isTrue);
      expect(
          MobileFileStorageService.isAuthorizedForCategory(
              'AUDITOR', 'PRESCRIPTION_IMAGE'),
          isTrue);

      // Cashier and SuperAdmin blocked from prescription images (Zero-PHI)
      expect(
          MobileFileStorageService.isAuthorizedForCategory(
              'CASHIER', 'PRESCRIPTION_IMAGE'),
          isFalse);
      expect(
          MobileFileStorageService.isAuthorizedForCategory(
              'SUPERADMIN', 'PRESCRIPTION_IMAGE'),
          isFalse);
      expect(
          MobileFileStorageService.isAuthorizedForCategory(
              'PLATFORM_OPERATOR', 'PRESCRIPTION_IMAGE'),
          isFalse);

      // Sales Invoices
      expect(
          MobileFileStorageService.isAuthorizedForCategory(
              'CASHIER', 'SALES_INVOICE_PDF'),
          isTrue);
      expect(
          MobileFileStorageService.isAuthorizedForCategory(
              'FINANCE_OFFICER', 'SALES_INVOICE_PDF'),
          isTrue);
    });

    test('3. Expired signed download URLs are identified correctly', () {
      final past = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 5))
          .toIso8601String();
      final future = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 15))
          .toIso8601String();

      expect(MobileFileStorageService.isUrlExpired(past), isTrue);
      expect(MobileFileStorageService.isUrlExpired(future), isFalse);
      expect(MobileFileStorageService.isUrlExpired(null), isTrue);
      expect(MobileFileStorageService.isUrlExpired('not-a-date'), isTrue);
    });

    test('4. Parses server response JSON into MobileStoredFile model', () {
      final json = {
        'file_id': '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
        'tenant_id': 'tenant-dhanmondi-test',
        'branch_id': 'branch-01',
        'file_name': 'rx_scan_101.jpg',
        'category': 'PRESCRIPTION_IMAGE',
        'mime_type': 'image/jpeg',
        'file_size_bytes': 345000,
        'checksum_sha256':
            '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
        'scan_status': 'CLEAN',
        'is_quarantined': false,
        'signed_download_url':
            'https://api.pharmacy.bd/storage/download/6ba7b810/?token=abc',
        'expires_at': '2026-10-31T15:00:00Z',
        'created_at': '2026-10-31T14:00:00Z',
      };

      final file = MobileStoredFile.fromJson(json);
      expect(file.fileId, '6ba7b810-9dad-11d1-80b4-00c04fd430c8');
      expect(file.fileName, 'rx_scan_101.jpg');
      expect(file.category, 'PRESCRIPTION_IMAGE');
      expect(file.isClean, isTrue);
      expect(file.isQuarantined, isFalse);
      expect(file.signedDownloadUrl, contains('token=abc'));
    });

    test('5. Error codes map to expected MobileUiState and bilingual messages',
        () {
      expect(
        MobileFileStorageService.resolveUiState('ERR_PERMISSION_DENIED'),
        equals(MobileUiState.permissionDenied),
      );
      expect(
        MobileFileStorageService.resolveUiState('ERR_CROSS_TENANT_VIOLATION'),
        equals(MobileUiState.permissionDenied),
      );
      expect(
        MobileFileStorageService.resolveUiState('ERR_FILE_QUARANTINED'),
        equals(MobileUiState.permissionDenied),
      );
      expect(
        MobileFileStorageService.resolveUiState('ERR_STORAGE_URL_EXPIRED'),
        equals(MobileUiState.error),
      );

      final msgQuarantined = MobileFileStorageService.getBilingualErrorMessage(
          'ERR_FILE_QUARANTINED');
      expect(msgQuarantined['en'], contains('Antivirus policy'));
      expect(msgQuarantined['bn'], contains('কোয়ারেন্টাইন'));

      final msgExpired = MobileFileStorageService.getBilingualErrorMessage(
          'ERR_STORAGE_URL_EXPIRED');
      expect(msgExpired['en'], contains('expired'));
      expect(msgExpired['bn'], contains('মেয়াদ শেষ'));
    });
  });
}
