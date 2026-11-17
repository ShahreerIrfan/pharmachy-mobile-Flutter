/// mobile/lib/core/prescriptions/mobile_rx_item_matching_client.dart
/// Architecture Decision: ADR-0245 (P245).
/// Phase 13: Prescriptions, Antibiotic Register & Compliance Safety.

import 'package:flutter/foundation.dart';

enum MobileMatchStatus {
  matched('Matched', 'অনুমোদিত ও মিলেছে'),
  exceedsQuantity('Exceeds Quantity', 'অনুমোদিত পরিমাণের অতিরিক্ত'),
  substitutionProhibited('Substitution Prohibited', 'অননুমোদিত ব্র্যান্ড প্রতিস্থাপন নিষিদ্ধ'),
  alreadyDispensed('Already Dispensed', 'ইতিমধ্যে সরবরাহ সম্পন্ন'),
  otcExempt('OTC Exempt', 'প্রেসক্রিপশন প্রয়োজন নেই');

  final String enLabel;
  final String bnLabel;

  const MobileMatchStatus(this.enLabel, this.bnLabel);

  String getLocalized(String lang) => lang.toLowerCase() == 'bn' ? bnLabel : enLabel;
}

@immutable
class MobileMatchedLineDto {
  final String productId;
  final String productName;
  final int requestedQuantity;
  final MobileMatchStatus matchStatus;
  final int remainingQuantity;
  final String? error;

  const MobileMatchedLineDto({
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    required this.matchStatus,
    required this.remainingQuantity,
    this.error,
  });

  bool get isSuccess =>
      matchStatus == MobileMatchStatus.matched || matchStatus == MobileMatchStatus.otcExempt;

  factory MobileMatchedLineDto.fromJson(Map<String, dynamic> json) {
    MobileMatchStatus status = MobileMatchStatus.matched;
    final rawStatus = json['match_status'] as String? ?? 'MATCHED';
    switch (rawStatus) {
      case 'EXCEEDS_QUANTITY':
        status = MobileMatchStatus.exceedsQuantity;
        break;
      case 'SUBSTITUTION_PROHIBITED':
        status = MobileMatchStatus.substitutionProhibited;
        break;
      case 'ALREADY_DISPENSED':
        status = MobileMatchStatus.alreadyDispensed;
        break;
      case 'OTC_EXEMPT':
        status = MobileMatchStatus.otcExempt;
        break;
      default:
        status = MobileMatchStatus.matched;
    }

    return MobileMatchedLineDto(
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      requestedQuantity: json['requested_quantity'] as int? ?? 0,
      matchStatus: status,
      remainingQuantity: json['remaining_quantity_after_sale'] as int? ??
          json['remaining_quantity'] as int? ??
          0,
      error: json['error'] as String?,
    );
  }
}

@immutable
class MobileMatchingReportDto {
  final String prescriptionId;
  final bool allMatched;
  final bool canProceed;
  final List<MobileMatchedLineDto> matchedItems;
  final List<String> errors;

  const MobileMatchingReportDto({
    required this.prescriptionId,
    required this.allMatched,
    required this.canProceed,
    required this.matchedItems,
    required this.errors,
  });

  factory MobileMatchingReportDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['matched_items'] as List<dynamic>? ?? [];
    final rawErrors = json['overall_errors'] as List<dynamic>? ?? [];

    return MobileMatchingReportDto(
      prescriptionId: json['prescription_id'] as String? ?? '',
      allMatched: json['all_matched'] as bool? ?? false,
      canProceed: json['can_proceed'] as bool? ?? false,
      matchedItems: rawItems
          .map((i) => MobileMatchedLineDto.fromJson(i as Map<String, dynamic>))
          .toList(),
      errors: rawErrors.map((e) => e.toString()).toList(),
    );
  }
}

class MobileRxItemMatchingClient {
  /// Evaluates preflight match on client before checkout.
  static MobileMatchedLineDto matchCartLine({
    required String prescribedProductId,
    required String prescribedBrandName,
    required int remainingAuthorizedQty,
    required String cartProductId,
    required String cartBrandName,
    required int cartQuantity,
    required bool isRxRequired,
  }) {
    if (!isRxRequired) {
      return MobileMatchedLineDto(
        productId: cartProductId,
        productName: cartBrandName,
        requestedQuantity: cartQuantity,
        matchStatus: MobileMatchStatus.otcExempt,
        remainingQuantity: cartQuantity,
      );
    }

    if (prescribedProductId.toLowerCase() != cartProductId.toLowerCase()) {
      return MobileMatchedLineDto(
        productId: cartProductId,
        productName: cartBrandName,
        requestedQuantity: cartQuantity,
        matchStatus: MobileMatchStatus.substitutionProhibited,
        remainingQuantity: 0,
        error:
            'Automated treatment substitution prohibited. Prescribed: $prescribedBrandName, Cart: $cartBrandName',
      );
    }

    if (remainingAuthorizedQty <= 0) {
      return MobileMatchedLineDto(
        productId: cartProductId,
        productName: cartBrandName,
        requestedQuantity: cartQuantity,
        matchStatus: MobileMatchStatus.alreadyDispensed,
        remainingQuantity: 0,
        error: 'Prescribed item fully dispensed.',
      );
    }

    if (cartQuantity > remainingAuthorizedQty) {
      return MobileMatchedLineDto(
        productId: cartProductId,
        productName: cartBrandName,
        requestedQuantity: cartQuantity,
        matchStatus: MobileMatchStatus.exceedsQuantity,
        remainingQuantity: remainingAuthorizedQty,
        error:
            'Requested quantity ($cartQuantity) exceeds remaining authorized quota ($remainingAuthorizedQty).',
      );
    }

    return MobileMatchedLineDto(
      productId: cartProductId,
      productName: cartBrandName,
      requestedQuantity: cartQuantity,
      matchStatus: MobileMatchStatus.matched,
      remainingQuantity: remainingAuthorizedQty - cartQuantity,
    );
  }
}

