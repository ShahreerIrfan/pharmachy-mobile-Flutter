// test/core/billing/mobile_signed_offline_entitlement_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_signed_offline_entitlement_client.dart';

void main() {
  group('P093 - Mobile Signed Offline Entitlement Tests', () {
    final now = DateTime.now();

    test('Parses signed offline certificate and evaluates active dispensing', () {
      final jsonPayload = {
        'lease_id': 'ls-mob-00123456',
        'tenant_id': 'tn-p093-mob',
        'branch_id': 'br-mob-01',
        'device_id': 'mob-tablet-counter-01',
        'device_name': 'Samsung Galaxy Tab A8 POS',
        'role_snapshot': 'CASHIER',
        'plan_tier': 'STANDARD',
        'policy_version': 'v2.0',
        'duration_hours': 72,
        'issued_at': now.toIso8601String(),
        'expires_at': now.add(const Duration(hours: 48)).toIso8601String(),
        'capabilities_snapshot': {
          'CHECKOUT_DISPENSING': true,
          'ANTIBIOTIC_REGISTER': true,
          'BATCH_EXPIRY_BLOCK': true,
          'RX_VERIFICATION': true,
        },
        'signature_algorithm': 'HMAC-SHA256',
        'signature': 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        'status': 'ACTIVE',
        'client_messaging': {
          'headline_en': 'Signed Offline Lease Active (48 Hours Remaining)',
          'headline_bn': 'স্বাক্ষরিত অফলাইন ইজারা সক্রিয় (অবশিষ্ট ৪৮ ঘণ্টা)',
          'details_en': 'POS operations permitted offline.',
          'details_bn': 'অফলাইনে বিক্রয় সচল রয়েছে।',
        },
      };

      final cert = MobileDeviceLeaseCertificate.fromJson(jsonPayload);

      expect(cert.leaseId, 'ls-mob-00123456');
      expect(cert.status, MobileOfflineLeaseStatus.active);
      expect(cert.canDispenseOffline, isTrue);
      expect(cert.isExpired(), isFalse);
      expect(cert.hoursRemaining(), greaterThanOrEqualTo(47));
      expect(cert.capabilitiesSnapshot['ANTIBIOTIC_REGISTER'], isTrue);
      expect(cert.clientMessaging.headlineBn, contains('স্বাক্ষরিত অফলাইন ইজারা সক্রিয়'));
    });

    test('Expired and revoked states block offline dispensing', () {
      final expiredJson = {
        'lease_id': 'ls-mob-expired',
        'tenant_id': 'tn-p093-mob',
        'branch_id': 'br-mob-01',
        'device_id': 'mob-tablet-counter-01',
        'device_name': 'Samsung POS',
        'role_snapshot': 'CASHIER',
        'plan_tier': 'STANDARD',
        'policy_version': 'v2.0',
        'duration_hours': 72,
        'issued_at': now.subtract(const Duration(hours: 80)).toIso8601String(),
        'expires_at': now.subtract(const Duration(hours: 8)).toIso8601String(),
        'capabilities_snapshot': {'CHECKOUT_DISPENSING': true},
        'signature_algorithm': 'HMAC-SHA256',
        'signature': 'fake-sig',
        'status': 'ACTIVE',
        'client_messaging': {
          'headline_en': 'Expired',
          'headline_bn': 'মেয়াদ উত্তীর্ণ',
          'details_en': 'Reconnect to renew',
          'details_bn': 'অনলাইনে যুক্ত হোন',
        },
      };

      final expiredCert = MobileDeviceLeaseCertificate.fromJson(expiredJson);
      expect(expiredCert.isExpired(), isTrue);
      expect(expiredCert.canDispenseOffline, isFalse);

      final revokedJson = Map<String, dynamic>.from(expiredJson);
      revokedJson['status'] = 'REVOKED';
      revokedJson['expires_at'] = now.add(const Duration(hours: 10)).toIso8601String();

      final revokedCert = MobileDeviceLeaseCertificate.fromJson(revokedJson);
      expect(revokedCert.status, MobileOfflineLeaseStatus.revoked);
      expect(revokedCert.canDispenseOffline, isFalse);
    });
  });
}
