import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_support_ticket_client.dart';

void main() {
  group('ADR-0069: Mobile Support Ticket Client Tests', () {
    test('resolves ticket status tone accurately', () {
      expect(MobileSupportTicketClient.resolveStatusTone('OPEN'), 'info');
      expect(MobileSupportTicketClient.resolveStatusTone('IN_PROGRESS'), 'warning');
      expect(MobileSupportTicketClient.resolveStatusTone('RESOLVED'), 'success');
      expect(MobileSupportTicketClient.resolveStatusTone('WAITING_ON_TENANT'), 'neutral');
      expect(MobileSupportTicketClient.resolveStatusTone('CLOSED'), 'neutral');
      expect(MobileSupportTicketClient.resolveStatusTone(null), 'neutral');
      expect(MobileSupportTicketClient.resolveStatusTone('UNKNOWN'), 'neutral');
    });

    test('detects internal notes in ticket payload for store confidentiality audit', () {
      final cleanTicket = {
        'ticket_id': 'tkt-001',
        'messages': [
          {'message_id': 'msg-1', 'is_internal': false, 'message_text': 'Public message'},
        ],
      };
      expect(MobileSupportTicketClient.containsInternalNotes(cleanTicket), isFalse);

      final contaminatedTicket = {
        'ticket_id': 'tkt-001',
        'messages': [
          {'message_id': 'msg-1', 'is_internal': false, 'message_text': 'Public message'},
          {'message_id': 'msg-2', 'is_internal': true, 'message_text': 'Internal note'},
        ],
      };
      expect(MobileSupportTicketClient.containsInternalNotes(contaminatedTicket), isTrue);

      expect(MobileSupportTicketClient.containsInternalNotes(null), isFalse);
    });

    test('validates attachment file size limit (<= 10MB)', () {
      expect(MobileSupportTicketClient.isValidAttachmentSize(1024), isTrue);
      expect(MobileSupportTicketClient.isValidAttachmentSize(10 * 1024 * 1024), isTrue);

      expect(MobileSupportTicketClient.isValidAttachmentSize(0), isFalse);
      expect(MobileSupportTicketClient.isValidAttachmentSize(-1), isFalse);
      expect(MobileSupportTicketClient.isValidAttachmentSize(11 * 1024 * 1024), isFalse);
    });

    test('validates authorized categories and priorities', () {
      expect(MobileSupportTicketClient.isValidCategory('BILLING'), isTrue);
      expect(MobileSupportTicketClient.isValidCategory('HARDWARE_PRINTER'), isTrue);
      expect(MobileSupportTicketClient.isValidCategory('SYNC_OFFLINE'), isTrue);
      expect(MobileSupportTicketClient.isValidCategory('BAD_CAT'), isFalse);
      expect(MobileSupportTicketClient.isValidCategory(null), isFalse);

      expect(MobileSupportTicketClient.isValidPriority('LOW'), isTrue);
      expect(MobileSupportTicketClient.isValidPriority('MEDIUM'), isTrue);
      expect(MobileSupportTicketClient.isValidPriority('HIGH'), isTrue);
      expect(MobileSupportTicketClient.isValidPriority('URGENT'), isTrue);
      expect(MobileSupportTicketClient.isValidPriority('UNKNOWN'), isFalse);
      expect(MobileSupportTicketClient.isValidPriority(null), isFalse);
    });

    test('builds endpoint URLs with parameter validation', () {
      expect(
        MobileSupportTicketClient.buildTenantTicketsUrl('tenant-alpha'),
        '/api/v2/tenants/support/tickets/tenant-alpha/',
      );
      expect(
        MobileSupportTicketClient.buildCreateTicketUrl('tenant-alpha'),
        '/api/v2/tenants/support/tickets/tenant-alpha/create/',
      );
      expect(
        MobileSupportTicketClient.buildTicketDetailUrl('tenant-alpha', 'tkt-12345'),
        '/api/v2/tenants/support/tickets/tenant-alpha/tkt-12345/',
      );
      expect(
        MobileSupportTicketClient.buildReplyUrl('tenant-alpha', 'tkt-12345'),
        '/api/v2/tenants/support/tickets/tenant-alpha/tkt-12345/reply/',
      );
      expect(
        MobileSupportTicketClient.buildCloseUrl('tenant-alpha', 'tkt-12345'),
        '/api/v2/tenants/support/tickets/tenant-alpha/tkt-12345/close/',
      );

      expect(
        () => MobileSupportTicketClient.buildTenantTicketsUrl('bad id!'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => MobileSupportTicketClient.buildTicketDetailUrl('tenant-alpha', ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

