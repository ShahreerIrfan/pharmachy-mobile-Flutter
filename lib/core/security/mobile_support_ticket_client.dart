/// ADR-0069: Mobile Support Ticket Client.
/// Coordinates ticket listing, creation, status tone mapping, attachment limits,
/// and enforces strict client-side confidentiality for internal notes.
library mobile_support_ticket_client;

class MobileSupportTicketClient {
  static final RegExp _idPattern = RegExp(r'^[a-z0-9_-]{3,64}$');
  static const int maxAttachmentSizeBytes = 10 * 1024 * 1024; // 10MB

  static const Set<String> _validCategories = {
    'BILLING',
    'HARDWARE_PRINTER',
    'SYNC_OFFLINE',
    'INVENTORY_STOCK',
    'REGULATORY_DGDA',
    'GENERAL_SUPPORT',
  };

  static const Set<String> _validPriorities = {
    'LOW',
    'MEDIUM',
    'HIGH',
    'URGENT',
  };

  /// Resolves status tone conforming to Apple-inspired restrained design system.
  static String resolveStatusTone(String? status) {
    if (status == null) return 'neutral';
    switch (status.toUpperCase().trim()) {
      case 'OPEN':
        return 'info';
      case 'IN_PROGRESS':
        return 'warning';
      case 'RESOLVED':
        return 'success';
      case 'WAITING_ON_TENANT':
      case 'CLOSED':
      default:
        return 'neutral';
    }
  }

  /// Audits ticket payload to verify internal notes are absent in mobile manager app.
  static bool containsInternalNotes(Map<String, dynamic>? ticketPayload) {
    if (ticketPayload == null) return false;
    final messages = ticketPayload['messages'];
    if (messages is List) {
      for (final item in messages) {
        if (item is Map && item['is_internal'] == true) {
          return true;
        }
      }
    }
    return false;
  }

  /// Validates attachment size limit (<= 10MB).
  static bool isValidAttachmentSize(int sizeBytes) {
    return sizeBytes > 0 && sizeBytes <= maxAttachmentSizeBytes;
  }

  /// Validates category according to ADR-0069.
  static bool isValidCategory(String? category) {
    if (category == null) return false;
    return _validCategories.contains(category.toUpperCase().trim());
  }

  /// Validates priority according to ADR-0069.
  static bool isValidPriority(String? priority) {
    if (priority == null) return false;
    return _validPriorities.contains(priority.toUpperCase().trim());
  }

  /// Builds tenant tickets list endpoint URL.
  static String buildTenantTicketsUrl(String tenantId) {
    _validateId(tenantId, 'tenant');
    return '/api/v2/tenants/support/tickets/${tenantId.trim()}/';
  }

  /// Builds ticket submission endpoint URL.
  static String buildCreateTicketUrl(String tenantId) {
    _validateId(tenantId, 'tenant');
    return '/api/v2/tenants/support/tickets/${tenantId.trim()}/create/';
  }

  /// Builds ticket detail endpoint URL.
  static String buildTicketDetailUrl(String tenantId, String ticketId) {
    _validateId(tenantId, 'tenant');
    _validateId(ticketId, 'ticket');
    return '/api/v2/tenants/support/tickets/${tenantId.trim()}/${ticketId.trim()}/';
  }

  /// Builds ticket reply endpoint URL.
  static String buildReplyUrl(String tenantId, String ticketId) {
    _validateId(tenantId, 'tenant');
    _validateId(ticketId, 'ticket');
    return '/api/v2/tenants/support/tickets/${tenantId.trim()}/${ticketId.trim()}/reply/';
  }

  /// Builds ticket close endpoint URL.
  static String buildCloseUrl(String tenantId, String ticketId) {
    _validateId(tenantId, 'tenant');
    _validateId(ticketId, 'ticket');
    return '/api/v2/tenants/support/tickets/${tenantId.trim()}/${ticketId.trim()}/close/';
  }

  static void _validateId(String id, String fieldName) {
    if (!_idPattern.hasMatch(id.trim())) {
      throw ArgumentError('Invalid $fieldName identifier: \'$id\'');
    }
  }
}

