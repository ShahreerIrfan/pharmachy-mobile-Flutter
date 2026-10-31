import 'package:pharmacy_mobile_manager/core/contracts/mobile_api_response_envelope.dart';

/// Flutter Mobile Manager File Storage Record DTO.
/// Architecture Decision: ADR-0051 (Private File Storage, Antivirus & Expiring URLs).
class MobileStoredFile {
  final String fileId;
  final String tenantId;
  final String? branchId;
  final String fileName;
  final String category;
  final String mimeType;
  final int fileSizeBytes;
  final String checksumSha256;
  final String scanStatus;
  final bool isQuarantined;
  final String quarantineReason;
  final String? signedDownloadUrl;
  final String? expiresAt;
  final String createdAt;

  const MobileStoredFile({
    required this.fileId,
    required this.tenantId,
    this.branchId,
    required this.fileName,
    required this.category,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.checksumSha256,
    this.scanStatus = 'PENDING_SCAN',
    this.isQuarantined = false,
    this.quarantineReason = '',
    this.signedDownloadUrl,
    this.expiresAt,
    required this.createdAt,
  });

  bool get isClean => scanStatus.toUpperCase() == 'CLEAN' && !isQuarantined;

  factory MobileStoredFile.fromJson(Map<String, dynamic> json) {
    return MobileStoredFile(
      fileId: json['file_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String?,
      fileName: json['file_name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      checksumSha256: json['checksum_sha256'] as String? ?? '',
      scanStatus: json['scan_status'] as String? ?? 'PENDING_SCAN',
      isQuarantined: json['is_quarantined'] as bool? ?? false,
      quarantineReason: json['quarantine_reason'] as String? ?? '',
      signedDownloadUrl: json['signed_download_url'] as String?,
      expiresAt: json['expires_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// Flutter Mobile Manager Private File Storage and Policy Service.
class MobileFileStorageService {
  static const Set<String> allowedExtensions = {
    '.pdf',
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  static const Set<String> dangerousExtensions = {
    '.exe',
    '.bat',
    '.cmd',
    '.sh',
    '.ps1',
    '.vbs',
    '.js',
    '.php',
    '.jar',
  };

  static const int maxFileSizeBytes = 15 * 1024 * 1024; // 15MB

  /// Validates file name and size before upload.
  static bool validateFile(String filename, int fileSizeBytes) {
    if (filename.trim().isEmpty) return false;
    if (fileSizeBytes <= 0 || fileSizeBytes > maxFileSizeBytes) return false;

    final lower = filename.toLowerCase();
    for (final danger in dangerousExtensions) {
      if (lower.endsWith(danger)) return false;
    }

    for (final allowed in allowedExtensions) {
      if (lower.endsWith(allowed)) return true;
    }

    return false;
  }

  /// Scoped Category Access Control for mobile personas.
  static bool isAuthorizedForCategory(String userRole, String category) {
    final role = userRole.toUpperCase();

    if (category == 'PRESCRIPTION_IMAGE') {
      // Zero-PHI Protection: Cashier & SuperAdmin blocked
      if (role == 'CASHIER' ||
          role == 'SUPERADMIN' ||
          role == 'PLATFORM_OPERATOR') {
        return false;
      }
      return const {
        'PHARMACY_OWNER',
        'BRANCH_MANAGER',
        'STAFF_PHARMACIST',
        'AUDITOR'
      }.contains(role);
    }

    if (category == 'SALES_INVOICE_PDF') {
      return const {
        'PHARMACY_OWNER',
        'BRANCH_MANAGER',
        'FINANCE_OFFICER',
        'CASHIER',
        'AUDITOR'
      }.contains(role);
    }

    if (category == 'DGDA_COMPLIANCE') {
      return const {'PHARMACY_OWNER', 'BRANCH_MANAGER', 'AUDITOR', 'SUPERADMIN'}
          .contains(role);
    }

    return const {
      'PHARMACY_OWNER',
      'BRANCH_MANAGER',
      'STAFF_PHARMACIST',
      'AUDITOR'
    }.contains(role);
  }

  /// Verifies if a signed URL timestamp has expired.
  static bool isUrlExpired(String? expiresAtIso) {
    if (expiresAtIso == null || expiresAtIso.trim().isEmpty) return true;
    try {
      final expiry = DateTime.parse(expiresAtIso).toUtc();
      return DateTime.now().toUtc().isAfter(expiry);
    } catch (_) {
      return true;
    }
  }

  /// Resolves localized bilingual error message conforming to ADR-0014 & ADR-0051.
  static Map<String, String> getBilingualErrorMessage(String errorCode) {
    final code = errorCode.toUpperCase();
    if (code == 'ERR_STORAGE_URL_EXPIRED') {
      return const {
        'en':
            'The secure download link has expired. Please refresh the signed URL.',
        'bn':
            'ডাউনলোড লিঙ্কের মেয়াদ শেষ হয়ে গেছে। অনুগ্রহ করে নতুন স্বাক্ষরিত লিঙ্কের অনুরোধ করুন।',
      };
    } else if (code == 'ERR_FILE_QUARANTINED') {
      return const {
        'en':
            'File blocked: Antivirus policy quarantined this attachment due to security risks.',
        'bn':
            'ফাইল ব্লক করা হয়েছে: অ্যান্টিভাইরাস পলিসি দ্বারা ফাইলটি কোয়ারেন্টাইন করা হয়েছে।',
      };
    } else if (code == 'ERR_INVALID_FILE_TYPE') {
      return const {
        'en':
            'Disallowed file type or executable content detected. Only PDF, JPEG, PNG, and WebP are permitted.',
        'bn':
            'নিষিদ্ধ ফাইল ফরম্যাট শনাক্ত হয়েছে। শুধুমাত্র PDF, JPEG, PNG, এবং WebP ফাইল অনুমোদিত।',
      };
    } else if (code == 'ERR_CROSS_TENANT_VIOLATION') {
      return const {
        'en': 'Cross-tenant file access is strictly forbidden.',
        'bn': 'অন্য ফার্মেসির ফাইলে প্রবেশাধিকার কঠোরভাবে নিষিদ্ধ।',
      };
    } else if (code == 'ERR_PERMISSION_DENIED') {
      return const {
        'en':
            'Access denied: You do not have permission to view or download this attachment.',
        'bn':
            'প্রবেশাধিকার প্রত্যাখ্যাত: এই ফাইলটি দেখার বা ডাউনলোড করার অনুমতি আপনার নেই।',
      };
    }
    return const {
      'en': 'Secure storage operation failed. Please verify connection.',
      'bn': 'ফাইল স্টোরেজ পরিচালনায় ত্রুটি দেখা দিয়েছে। সংযোগ পরীক্ষা করুন।',
    };
  }

  /// Maps security error codes to MobileUiState.
  static MobileUiState resolveUiState(String errorCode) {
    final code = errorCode.toUpperCase();
    if (code == 'ERR_PERMISSION_DENIED' ||
        code == 'ERR_CROSS_TENANT_VIOLATION' ||
        code == 'ERR_FILE_QUARANTINED') {
      return MobileUiState.permissionDenied;
    }
    return MobileUiState.error;
  }
}
