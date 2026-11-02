// test/core/catalog/mobile_product_metadata_review_client_test.dart
// Architecture Decision: ADR-0133
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P133)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_product_metadata_review_client.dart';

void main() {
  group('P133: MobileProductMetadataReviewClient Unit & Integration Tests', () {
    late MobileProductMetadataReviewClient client;
    const testProductId = 'med-mob-p133-001';

    setUp(() {
      client = MobileProductMetadataReviewClient();
      client.registerProduct(testProductId, {
        'brand_name': 'Napa Extra',
        'generic_name': 'Paracetamol + Caffeine',
        'dosage_form': 'Tablet',
        'strength': '500mg+65mg',
        'mrp_unit': 2.50,
        'cost_unit': 2.00,
        'curation_status': 'DRAFT',
        'version_number': 1,
      });
    });

    test('P133-M1: Propose metadata update with diff tracking captures old and new values', () {
      final result = client.proposeReview(
        productId: testProductId,
        changeType: 'METADATA_UPDATE',
        proposedChanges: {
          'mrp_unit': 3.50,
          'dosage_form': 'Extended Release Tablet',
        },
        submitterEmail: 'pharmacist1@pharmacy.local',
        userRole: 'STAFF_PHARMACIST',
        submissionNotes: 'Clinical form update per DGDA notification',
      );

      expect(result.status, equals(MobileReviewUiStatus.success));
      expect(result.data, isNotNull);
      expect(result.data!.productId, equals(testProductId));
      expect(result.data!.status, equals('PENDING_REVIEW'));
      expect(result.data!.submitterEmail, equals('pharmacist1@pharmacy.local'));

      final diff = result.data!.proposedDiff;
      expect(diff['mrp_unit']!.oldValue, equals(2.50));
      expect(diff['mrp_unit']!.newValue, equals(3.50));
      expect(diff['dosage_form']!.oldValue, equals('Tablet'));
      expect(diff['dosage_form']!.newValue, equals('Extended Release Tablet'));

      final product = client.getProduct(testProductId);
      expect(product!['curation_status'], equals('UNDER_REVIEW'));
    });

    test('P133-M2: Independent pharmacist approves review and diff merges atomically to master', () {
      final proposeRes = client.proposeReview(
        productId: testProductId,
        changeType: 'PRICE_REVISION',
        proposedChanges: {'mrp_unit': 4.00, 'cost_unit': 3.20},
        submitterEmail: 'pharmacist1@pharmacy.local',
        userRole: 'STAFF_PHARMACIST',
      );
      expect(proposeRes.status, equals(MobileReviewUiStatus.success));
      final reviewId = proposeRes.data!.reviewId;

      // Independent Pharmacist 2 approves
      final approveRes = client.approveReview(
        reviewId: reviewId,
        reviewerEmail: 'pharmacist2@pharmacy.local',
        reviewerRole: 'STAFF_PHARMACIST',
        reviewNotes: 'Verified manufacturer revised pricing schedule.',
      );

      expect(approveRes.status, equals(MobileReviewUiStatus.success));
      expect(approveRes.data!.status, equals('APPROVED'));
      expect(approveRes.data!.reviewerEmail, equals('pharmacist2@pharmacy.local'));
      expect(approveRes.data!.reviewedAt, isNotNull);

      // Verify product catalog store update
      final product = client.getProduct(testProductId);
      expect(product!['mrp_unit'], equals(4.00));
      expect(product['cost_unit'], equals(3.20));
      expect(product['curation_status'], equals('APPROVED'));
      expect(product['version_number'], equals(2));
    });

    test('P133-M3: Rejection with notes marks status REJECTED and leaves product unchanged', () {
      final proposeRes = client.proposeReview(
        productId: testProductId,
        changeType: 'METADATA_UPDATE',
        proposedChanges: {'dosage_form': 'Syrup'},
        submitterEmail: 'pharmacist1@pharmacy.local',
        userRole: 'STAFF_PHARMACIST',
      );
      final reviewId = proposeRes.data!.reviewId;

      final rejectRes = client.rejectReview(
        reviewId: reviewId,
        reviewerEmail: 'pharmacist2@pharmacy.local',
        reviewerRole: 'STAFF_PHARMACIST',
        reviewNotes: 'Rejected: Form must strictly match registered tablet monograph.',
      );

      expect(rejectRes.status, equals(MobileReviewUiStatus.success));
      expect(rejectRes.data!.status, equals('REJECTED'));
      expect(rejectRes.data!.reviewerEmail, equals('pharmacist2@pharmacy.local'));

      // Target product attributes remain untouched
      final product = client.getProduct(testProductId);
      expect(product!['dosage_form'], equals('Tablet'));
    });

    test('P133-M4: Submitter self-approval blocked by Four-Eyes Principle (Dual Control)', () {
      final proposeRes = client.proposeReview(
        productId: testProductId,
        changeType: 'PRICE_REVISION',
        proposedChanges: {'mrp_unit': 5.00},
        submitterEmail: 'pharmacist1@pharmacy.local',
        userRole: 'STAFF_PHARMACIST',
      );
      final reviewId = proposeRes.data!.reviewId;

      // Submitter attempts self-approval
      final selfApproveRes = client.approveReview(
        reviewId: reviewId,
        reviewerEmail: 'pharmacist1@pharmacy.local',
        reviewerRole: 'STAFF_PHARMACIST',
        reviewNotes: 'Self approving own change.',
      );

      expect(selfApproveRes.status, equals(MobileReviewUiStatus.permissionDenied));
      expect(selfApproveRes.errorCode, equals('ERR_FOUR_EYES_PRINCIPLE_VIOLATION'));
    });

    test('P133-M5: Cashier role blocked from submitting or approving reviews', () {
      // Cashier proposal attempt
      final cashierPropose = client.proposeReview(
        productId: testProductId,
        changeType: 'PRICE_REVISION',
        proposedChanges: {'mrp_unit': 6.00},
        submitterEmail: 'cashier@pharmacy.local',
        userRole: 'CASHIER',
      );
      expect(cashierPropose.status, equals(MobileReviewUiStatus.permissionDenied));
      expect(cashierPropose.errorCode, equals('ERR_STAFF_ROLE_DENIED'));

      // Valid proposal
      final validPropose = client.proposeReview(
        productId: testProductId,
        changeType: 'PRICE_REVISION',
        proposedChanges: {'mrp_unit': 6.00},
        submitterEmail: 'pharmacist1@pharmacy.local',
        userRole: 'STAFF_PHARMACIST',
      );
      final reviewId = validPropose.data!.reviewId;

      // Cashier approval attempt
      final cashierApprove = client.approveReview(
        reviewId: reviewId,
        reviewerEmail: 'cashier@pharmacy.local',
        reviewerRole: 'CASHIER',
        reviewNotes: 'Cashier trying to sign off.',
      );
      expect(cashierApprove.status, equals(MobileReviewUiStatus.permissionDenied));
      expect(cashierApprove.errorCode, equals('ERR_STAFF_ROLE_DENIED'));
    });

    test('P133-M6: Offline fallback serves cached review history safely', () {
      final proposeRes = client.proposeReview(
        productId: testProductId,
        changeType: 'METADATA_UPDATE',
        proposedChanges: {'dosage_form': 'Dispersible Tablet'},
        submitterEmail: 'pharmacist1@pharmacy.local',
        userRole: 'STAFF_PHARMACIST',
      );
      expect(proposeRes.status, equals(MobileReviewUiStatus.success));

      client.isOffline = true;
      expect(client.isOffline, isTrue);

      final historyRes = client.getReviewHistory(testProductId);
      expect(historyRes.status, equals(MobileReviewUiStatus.offline));
      expect(historyRes.data, isNotNull);
      expect(historyRes.data!.length, equals(1));
      expect(historyRes.data!.first.reviewId, equals(proposeRes.data!.reviewId));
    });
  });
}
