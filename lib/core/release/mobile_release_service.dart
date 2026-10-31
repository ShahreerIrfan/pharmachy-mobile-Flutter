/// Mobile Release & Compatibility Service
/// Architecture Decision: ADR-0038
/// Manages Flutter mobile client SemVer inspection, compatibility evaluation,
/// and bilingual upgrade banners.
library mobile_release_service;

enum MobileCompatibilityStatus {
  supported,
  deprecated,
  upgradeRequired,
  unknown,
}

class MobileSemVer implements Comparable<MobileSemVer> {
  final int major;
  final int minor;
  final int patch;
  final String? prerelease;

  const MobileSemVer({
    required this.major,
    required this.minor,
    required this.patch,
    this.prerelease,
  });

  static final RegExp _pattern = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$',
  );

  static MobileSemVer parse(String versionStr) {
    var cleaned = versionStr.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }
    final match = _pattern.firstMatch(cleaned);
    if (match == null) {
      throw FormatException('Invalid SemVer format: $versionStr');
    }
    return MobileSemVer(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      prerelease: match.group(4),
    );
  }

  @override
  int compareTo(MobileSemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    if (prerelease == null && other.prerelease != null) return 1;
    if (prerelease != null && other.prerelease == null) return -1;
    if (prerelease != null && other.prerelease != null) {
      return prerelease!.compareTo(other.prerelease!);
    }
    return 0;
  }

  @override
  String toString() =>
      '$major.$minor.$patch${prerelease != null ? '-$prerelease' : ''}';
}

class MobileCompatibilityResult {
  final MobileCompatibilityStatus status;
  final String clientVersion;
  final String targetVersion;
  final String minSupportedVersion;
  final bool isUpgradeRequired;
  final String messageEn;
  final String messageBn;
  final String downloadUrl;

  const MobileCompatibilityResult({
    required this.status,
    required this.clientVersion,
    required this.targetVersion,
    required this.minSupportedVersion,
    required this.isUpgradeRequired,
    required this.messageEn,
    required this.messageBn,
    required this.downloadUrl,
  });
}

class MobileReleaseService {
  static const String currentMobileVersion = '1.1.0';
  static const String platform = 'MOBILE';

  static MobileCompatibilityResult evaluateLocal({
    required String clientVersion,
    required String minSupported,
    required String targetVersion,
  }) {
    final c = MobileSemVer.parse(clientVersion);
    final min = MobileSemVer.parse(minSupported);
    final target = MobileSemVer.parse(targetVersion);

    MobileCompatibilityStatus status;
    bool upgradeRequired = false;

    if (c.compareTo(min) < 0) {
      status = MobileCompatibilityStatus.upgradeRequired;
      upgradeRequired = true;
    } else if (c.compareTo(target) < 0) {
      status = MobileCompatibilityStatus.deprecated;
    } else {
      status = MobileCompatibilityStatus.supported;
    }

    final msgEn = (status == MobileCompatibilityStatus.upgradeRequired)
        ? 'Mobile App v$clientVersion is unsupported. Please upgrade to v$targetVersion.'
        : (status == MobileCompatibilityStatus.deprecated)
            ? 'Mobile App v$clientVersion is deprecated. Update to v$targetVersion recommended.'
            : 'Mobile App v$clientVersion is fully supported.';

    final msgBn = (status == MobileCompatibilityStatus.upgradeRequired)
        ? 'মোবাইল অ্যাপ v$clientVersion আর সমর্থিত নয়। অনুগ্রহ করে v$targetVersion-এ আপগ্রেড করুন।'
        : (status == MobileCompatibilityStatus.deprecated)
            ? 'মোবাইল অ্যাপ v$clientVersion অপ্রচলিত হয়েছে। v$targetVersion-এ আপডেট করার পরামর্শ দেওয়া হচ্ছে।'
            : 'মোবাইল অ্যাপ v$clientVersion সম্পূর্ণ সমর্থিত।';

    return MobileCompatibilityResult(
      status: status,
      clientVersion: clientVersion,
      targetVersion: targetVersion,
      minSupportedVersion: minSupported,
      isUpgradeRequired: upgradeRequired,
      messageEn: msgEn,
      messageBn: msgBn,
      downloadUrl: 'https://pharmacy.bd/mobile',
    );
  }
}
