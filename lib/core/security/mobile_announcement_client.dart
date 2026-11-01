/// ADR-0076: Flutter Mobile System Announcements & Read Receipts Client.
library mobile_announcement_client;

class MobileAnnouncementClient {
  static final RegExp _announcementIdPattern = RegExp(r'^ann-[a-z0-9_-]{8,64}$');

  static const Set<String> _platformAdminRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
  };

  static const Set<String> _validPriorities = {
    'INFO',
    'WARNING',
    'CRITICAL',
    'MAINTENANCE',
  };

  static const Set<String> _validTargetTypes = {
    'ALL',
    'TENANT_LIST',
    'ROLE_LIST',
    'BRANCH_LIST',
  };

  static bool canRoleManageAnnouncements(String? role) {
    if (role == null) return false;
    return _platformAdminRoles.contains(role.toUpperCase().trim());
  }

  static bool canRoleAcknowledge(String? role) {
    return role != null && role.trim().isNotEmpty;
  }

  static bool isValidAnnouncementId(String? announcementId) {
    if (announcementId == null) return false;
    return _announcementIdPattern.hasMatch(announcementId.trim().toLowerCase());
  }

  static bool isValidPriority(String? priority) {
    if (priority == null) return false;
    return _validPriorities.contains(priority.toUpperCase().trim());
  }

  static bool isValidTargetType(String? targetType) {
    if (targetType == null) return false;
    return _validTargetTypes.contains(targetType.toUpperCase().trim());
  }

  static bool isValidStateTransition(String? fromStatus, String? toStatus) {
    if (fromStatus == null || toStatus == null) return false;
    final from = fromStatus.toUpperCase().trim();
    final to = toStatus.toUpperCase().trim();
    if (from == to) return true;

    switch (from) {
      case 'DRAFT':
        return to == 'PUBLISHED' || to == 'ARCHIVED';
      case 'PUBLISHED':
        return to == 'ARCHIVED';
      default:
        return false; // ARCHIVED is terminal
    }
  }

  static String buildPlatformAnnouncementsUrl(String? baseUrl, [String? announcementId]) {
    final cleanBase = (baseUrl ?? '').replaceAll(RegExp(r'/+$'), '');
    if (announcementId == null || announcementId.trim().isEmpty) {
      return '$cleanBase/api/v2/platform/announcements/';
    }
    if (!isValidAnnouncementId(announcementId)) {
      throw ArgumentError('Invalid announcementId: $announcementId');
    }
    return '$cleanBase/api/v2/platform/announcements/${announcementId.trim()}/';
  }

  static String buildTenantAnnouncementsUrl(String? baseUrl) {
    final cleanBase = (baseUrl ?? '').replaceAll(RegExp(r'/+$'), '');
    return '$cleanBase/api/v2/tenants/announcements/';
  }

  static String buildAcknowledgeUrl(String? baseUrl, String announcementId) {
    final cleanBase = (baseUrl ?? '').replaceAll(RegExp(r'/+$'), '');
    if (!isValidAnnouncementId(announcementId)) {
      throw ArgumentError('Invalid announcementId: $announcementId');
    }
    return '$cleanBase/api/v2/tenants/announcements/${announcementId.trim()}/acknowledge/';
  }
}
