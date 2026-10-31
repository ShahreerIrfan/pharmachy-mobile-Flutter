import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_session_service.dart';

void main() {
  group('P045: Mobile Session Service & Replay Guard Tests', () {
    test('Validates device binding equality', () {
      expect(
        MobileSessionService.validateDeviceBinding(
            'iphone-15-pro', 'iphone-15-pro'),
        isTrue,
      );
      expect(
        MobileSessionService.validateDeviceBinding(
            'IPHONE-15-PRO', 'iphone-15-pro'),
        isTrue,
      );
      expect(
        MobileSessionService.validateDeviceBinding(
            'iphone-15-pro', 'ipad-mini-6'),
        isFalse,
      );
    });

    test('Identifies token replay error code', () {
      expect(
          MobileSessionService.isReplayError('TOKEN_REPLAY_DETECTED'), isTrue);
      expect(
          MobileSessionService.isReplayError('token_replay_detected'), isTrue);
      expect(
          MobileSessionService.isReplayError('INVALID_CREDENTIALS'), isFalse);
    });

    test('Parses MobileSession from JSON conforming to ADR-0045', () {
      final jsonMap = {
        'session_id': '88b560ce-0123-4567-89ab-cdef01234567',
        'user_id': '45a0b123-0123-4567-89ab-cdef01234567',
        'tenant_id': 'tenant-gulshan-care',
        'device_id': 'manager-pixel-8',
        'device_name': 'Manager Pixel 8 Pro',
        'client_platform': 'MOBILE_MANAGER',
        'ip_address': '103.205.180.45',
        'is_active': true,
        'is_current': true,
        'last_seen_at': '2026-10-31T06:30:00Z',
        'created_at': '2026-10-31T06:00:00Z',
      };

      final session = MobileSession.fromJson(jsonMap);
      expect(session.sessionId, '88b560ce-0123-4567-89ab-cdef01234567');
      expect(session.tenantId, 'tenant-gulshan-care');
      expect(session.deviceId, 'manager-pixel-8');
      expect(session.isActive, isTrue);
      expect(session.isCurrent, isTrue);
    });

    test('Produces client-safe bilingual error messages', () {
      final replay = MobileSessionService.getBilingualErrorMessage(
          'TOKEN_REPLAY_DETECTED');
      expect(replay['en'], contains('Token replay attack detected'));
      expect(replay['bn'], contains('টোকেন রিপ্লে আক্রমণ'));

      final crossTenant = MobileSessionService.getBilingualErrorMessage(
          'CROSS_TENANT_SESSION_ACCESS_DENIED');
      expect(crossTenant['en'], contains('Cross-tenant'));
      expect(crossTenant['bn'], contains('ক্রস-টেন্যান্ট'));
    });
  });
}
