/// mobile/test/core/prescriptions/mobile_prescription_attachment_client_test.dart
/// Architecture Decision: ADR-0242 (P242).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_prescription_attachment_client.dart';

void main() {
  group('P242: Mobile Prescription Attachment Client Tests', () {
    test('P242-Mobile-1: Allowed extensions and MIME validation', () {
      expect(MobilePrescriptionAttachmentDto.isAllowedExtension('scan.jpg'), isTrue);
      expect(MobilePrescriptionAttachmentDto.isAllowedExtension('document.pdf'), isTrue);
      expect(MobilePrescriptionAttachmentDto.isAllowedExtension('image.png'), isTrue);
      expect(MobilePrescriptionAttachmentDto.isAllowedExtension('image.webp'), isTrue);

      expect(MobilePrescriptionAttachmentDto.isAllowedExtension('virus.exe'), isFalse);
      expect(MobilePrescriptionAttachmentDto.isAllowedExtension('script.sh'), isFalse);

      expect(MobilePrescriptionAttachmentDto.isAllowedMime('image/jpeg'), isTrue);
      expect(MobilePrescriptionAttachmentDto.isAllowedMime('application/pdf'), isTrue);
      expect(MobilePrescriptionAttachmentDto.isAllowedMime('application/x-msdownload'), isFalse);
    });

    test('P242-Mobile-2: JSON serialization and 5-year retention parsing', () {
      final json = {
        'attachment_id': 'att-rx-998877',
        'prescription_id': 'rx-202611-001',
        'file_name': 'prescription_dr_huda.pdf',
        'mime_type': 'application/pdf',
        'file_size_bytes': 345000,
        'checksum_sha256': '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
        'retention_days': 1825,
        'retention_expires_at': '2031-11-17',
        'is_verified_by_pharmacist': true,
        'is_quarantined': false,
        'signed_url': 'https://storage.pharmacy.bd/signed/token12345',
      };

      final dto = MobilePrescriptionAttachmentDto.fromJson(json);

      expect(dto.attachmentId, 'att-rx-998877');
      expect(dto.prescriptionId, 'rx-202611-001');
      expect(dto.fileName, 'prescription_dr_huda.pdf');
      expect(dto.mimeType, 'application/pdf');
      expect(dto.fileSizeBytes, 345000);
      expect(dto.retentionDays, 1825);
      expect(dto.retentionExpiresAt.year, 2031);
      expect(dto.isVerifiedByPharmacist, isTrue);
      expect(dto.isQuarantined, isFalse);
      expect(dto.signedUrl, contains('https://storage.pharmacy.bd/signed/'));
    });
  });
}
