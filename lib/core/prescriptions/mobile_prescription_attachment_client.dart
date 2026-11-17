/// mobile/lib/core/prescriptions/mobile_prescription_attachment_client.dart
/// Architecture Decision: ADR-0242 (P242).
/// Phase 13: Prescriptions, Antibiotic Register & Compliance Safety.

import 'package:flutter/foundation.dart';

@immutable
class MobilePrescriptionAttachmentDto {
  final String attachmentId;
  final String prescriptionId;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final String checksumSha256;
  final int retentionDays;
  final DateTime retentionExpiresAt;
  final bool isVerifiedByPharmacist;
  final bool isQuarantined;
  final String? signedUrl;

  const MobilePrescriptionAttachmentDto({
    required this.attachmentId,
    required this.prescriptionId,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.checksumSha256,
    required this.retentionDays,
    required this.retentionExpiresAt,
    required this.isVerifiedByPharmacist,
    required this.isQuarantined,
    this.signedUrl,
  });

  factory MobilePrescriptionAttachmentDto.fromJson(Map<String, dynamic> json) {
    return MobilePrescriptionAttachmentDto(
      attachmentId: json['attachment_id'] as String? ?? '',
      prescriptionId: json['prescription'] as String? ?? json['prescription_id'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? 'image/jpeg',
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      checksumSha256: json['checksum_sha256'] as String? ?? '',
      retentionDays: json['retention_days'] as int? ?? 1825,
      retentionExpiresAt: json['retention_expires_at'] != null
          ? DateTime.parse(json['retention_expires_at'] as String)
          : DateTime.now().add(const Duration(days: 1825)),
      isVerifiedByPharmacist: json['is_verified_by_pharmacist'] as bool? ?? false,
      isQuarantined: json['is_quarantined'] as bool? ?? false,
      signedUrl: json['signed_url'] as String?,
    );
  }

  static bool isAllowedMime(String mime) {
    const allowed = {'image/jpeg', 'image/png', 'image/webp', 'application/pdf'};
    return allowed.contains(mime.toLowerCase());
  }

  static bool isAllowedExtension(String filename) {
    final lower = filename.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.pdf');
  }
}
