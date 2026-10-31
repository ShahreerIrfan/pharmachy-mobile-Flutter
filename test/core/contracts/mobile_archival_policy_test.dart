import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_archival_policy.dart';

void main() {
  group('ADR-0056: Mobile Archival and Soft-Deletion Policy Tests', () {
    test('identifies immutable regulatory records', () {
      expect(MobileArchivalPolicyManager.isImmutable('SALE_INVOICE'), isTrue);
      expect(MobileArchivalPolicyManager.isImmutable('PRESCRIPTION_RECORD'), isTrue);
      expect(MobileArchivalPolicyManager.isImmutable('AUDIT_LOG_ENTRY'), isTrue);
      expect(MobileArchivalPolicyManager.isImmutable('PAYMENT_TRANSACTION'), isTrue);
      expect(MobileArchivalPolicyManager.isImmutable('MEDICINE_CATALOG'), isFalse);
    });

    test('prohibits destructive deletion on all domain records', () {
      expect(MobileArchivalPolicyManager.canDestructivelyDelete('SALE_INVOICE'), isFalse);
      expect(MobileArchivalPolicyManager.canDestructivelyDelete('MEDICINE_CATALOG'), isFalse);
    });

    test('throws StateError when attempting delete on immutable record', () {
      expect(
        () => MobileArchivalPolicyManager.validateDeletionPermitted('SALE_INVOICE', 'INV-555'),
        throwsA(isA<StateError>()),
      );
    });

    test('creates valid archival record for soft-deletable catalog', () {
      final record = MobileArchivalPolicyManager.createArchivalRecord(
        resourceType: 'MEDICINE_CATALOG',
        resourceId: 'MED-123',
        userId: 'mgr-admin-01',
        reason: 'Formula superseded by updated brand',
      );

      expect(record.resourceType, equals('MEDICINE_CATALOG'));
      expect(record.resourceId, equals('MED-123'));
      expect(record.isArchived, isTrue);
      expect(record.archivedBy, equals('mgr-admin-01'));
      expect(record.archivalReason, equals('Formula superseded by updated brand'));
    });

    test('rejects short reason for archival', () {
      expect(
        () => MobileArchivalPolicyManager.createArchivalRecord(
          resourceType: 'MEDICINE_CATALOG',
          resourceId: 'MED-123',
          userId: 'mgr-admin-01',
          reason: 'nope',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
