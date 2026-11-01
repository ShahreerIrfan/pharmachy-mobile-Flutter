// test/core/billing/mobile_manual_payment_client_test.dart
// Architecture Decision: ADR-0007, ADR-0024 & ADR-0088
// Phase 05: Basic/Standard/Pro Subscription & Billing (P088)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_manual_payment_client.dart';

void main() {
  group('P088 - Mobile Manual Payment Claim Client Tests', () {
    test('Status parsing and state predicates evaluate correctly', () {
      final now = DateTime.utc(2026, 11, 1);

      final pendingClaim = MobileManualPaymentClaimModel(
        claimId: 'clm-001',
        claimNumber: 'PAY-CLM-202611-DHAKA-1001',
        tenantId: 'tn-dhaka',
        invoiceId: 'inv-001',
        paymentMethod: 'BKASH',
        transactionReference: 'BKASH-TX-1234',
        senderAccountNumber: '+8801712345678',
        claimedAmountBdt: 6825.00,
        evidenceFileUrl: 'https://slip.url/1.png',
        status: MobileManualPaymentStatus.pendingVerification,
        makerUserId: 'usr-maker-01',
        makerUserEmail: 'maker@pharma.local',
        submittedAt: now,
      );

      expect(pendingClaim.isPending, isTrue);
      expect(pendingClaim.isApproved, isFalse);
      expect(pendingClaim.isRejected, isFalse);
      expect(pendingClaim.isCancelled, isFalse);
    });

    test('Maker-Checker invariant: Prohibits self-approval, allows distinct checker', () {
      final now = DateTime.utc(2026, 11, 1);

      final claim = MobileManualPaymentClaimModel(
        claimId: 'clm-002',
        claimNumber: 'PAY-CLM-202611-CTG-2002',
        tenantId: 'tn-ctg',
        invoiceId: 'inv-002',
        paymentMethod: 'BANK_TRANSFER',
        transactionReference: 'EFT-TX-5678',
        senderAccountNumber: '1041560029381',
        claimedAmountBdt: 157500.00,
        evidenceFileUrl: 'https://slip.url/2.pdf',
        status: MobileManualPaymentStatus.pendingVerification,
        makerUserId: 'usr-maker-02',
        makerUserEmail: 'maker2@pharma.local',
        submittedAt: now,
      );

      // Same maker cannot approve
      expect(claim.canApprove('usr-maker-02'), isFalse);
      // Distinct checker can approve
      expect(claim.canApprove('usr-admin-checker-99'), isTrue);
      // Empty checker id rejected
      expect(claim.canApprove(''), isFalse);
    });

    test('JSON serialization and parsing handles full payload with activation outcomes', () {
      final jsonMap = {
        'claim_id': 'clm-003',
        'claim_number': 'PAY-CLM-202611-SYLHET-3003',
        'tenant_id': 'tn-sylhet',
        'invoice_id': 'inv-003',
        'invoice_number': 'INV-REN-202611-SYLHET-9931',
        'payment_method': 'NAGAD',
        'transaction_reference': 'NAGAD-TX-9900',
        'sender_account_number': '+8801799887766',
        'claimed_amount_bdt': '6825.00',
        'evidence_file_url': 'https://slip.url/3.png',
        'evidence_notes': 'Paid through Nagad App',
        'status': 'APPROVED',
        'maker_user_id': 'usr-maker-03',
        'maker_user_email': 'manager@sylhet.local',
        'checker_user_id': 'usr-checker-01',
        'checker_user_email': 'admin@platform.internal',
        'checker_notes': 'Matched Nagad merchant portal statement',
        'rejection_reason': null,
        'submitted_at': '2026-11-01T09:00:00.000Z',
        'verified_at': '2026-11-01T09:30:00.000Z',
        'activation_outcomes': {
          'invoice_id': 'inv-003',
          'invoice_number': 'INV-REN-202611-SYLHET-9931',
          'settled_at': '2026-11-01T09:30:00.000Z',
          'amount_bdt': '6825.00',
          'plan_tier': 'STANDARD',
          'billing_cycle': 'MONTHLY',
          'new_renewal_date': '2026-12-01',
          'subscription_status': 'ACTIVE',
        },
      };

      final claim = MobileManualPaymentClaimModel.fromJson(jsonMap);
      expect(claim.claimId, equals('clm-003'));
      expect(claim.claimNumber, equals('PAY-CLM-202611-SYLHET-3003'));
      expect(claim.status, equals(MobileManualPaymentStatus.approved));
      expect(claim.isApproved, isTrue);
      expect(claim.claimedAmountBdt, equals(6825.00));
      expect(claim.activationOutcomes, isNotNull);
      expect(claim.activationOutcomes?['new_renewal_date'], equals('2026-12-01'));

      final serialized = claim.toJson();
      expect(serialized['status'], equals('APPROVED'));
      expect(serialized['claimed_amount_bdt'], equals('6825.00'));
    });

    test('formatBdt renders BDT currency symbol and two decimals', () {
      expect(MobileManualPaymentClaimModel.formatBdt(6825.0), equals('৳ 6825.00'));
    });
  });
}
