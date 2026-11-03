import 'package:flutter/foundation.dart';

/// MobileConditionalPricingClient
/// Architecture Decision: ADR-0153 (P153).
/// Phase 08: Milestone M04 / M05 - Specialized Item & Multi-Tier Packaging Formulation Editors.
///
/// Flutter mobile client for Unit-Aware Conditional Pricing Form.
/// Governs packs, strips, and base piece price conversions with
/// break-bulk permission controls and bilingual unit display.

enum PricingUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

@immutable
class PricingCalculationResult {
  final bool isValid;
  final String? errorCode;
  final String? errorMessage;
  final int totalBaseUnitsPerPack;
  final double stripCostBdt;
  final double stripMrpBdt;
  final double packCostBdt;
  final double packMrpBdt;

  const PricingCalculationResult({
    required this.isValid,
    this.errorCode,
    this.errorMessage,
    this.totalBaseUnitsPerPack = 0,
    this.stripCostBdt = 0.0,
    this.stripMrpBdt = 0.0,
    this.packCostBdt = 0.0,
    this.packMrpBdt = 0.0,
  });

  factory PricingCalculationResult.success({
    required int totalUnits,
    required double stripCost,
    required double stripMrp,
    required double packCost,
    required double packMrp,
  }) {
    return PricingCalculationResult(
      isValid: true,
      totalBaseUnitsPerPack: totalUnits,
      stripCostBdt: stripCost,
      stripMrpBdt: stripMrp,
      packCostBdt: packCost,
      packMrpBdt: packMrp,
    );
  }

  factory PricingCalculationResult.failure({
    required String errorCode,
    required String errorMessage,
  }) {
    return PricingCalculationResult(
      isValid: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }
}

class MobileConditionalPricingClient {
  static const Map<String, Map<String, String>> unitTranslations = {
    'PIECE': {'en': 'Piece / Unit', 'bn': 'পিস / একক'},
    'TABLET': {'en': 'Tablet', 'bn': 'ট্যাবলেট'},
    'CAPSULE': {'en': 'Capsule', 'bn': 'ক্যাপসুল'},
    'VIAL': {'en': 'Vial', 'bn': 'ভায়াল'},
    'AMPOULE': {'en': 'Ampoule', 'bn': 'অ্যাম্পুল'},
    'BOTTLE': {'en': 'Bottle', 'bn': 'বোতল'},
    'DEVICE': {'en': 'Device', 'bn': 'ডিভাইস'},
    'SACHET': {'en': 'Sachet', 'bn': 'স্যাচেট'},
    'SUPPOSITORY': {'en': 'Suppository', 'bn': 'সাপোজিটরি'},
  };

  /// Calculates derived pack and strip prices from base piece prices and multipliers.
  PricingCalculationResult calculateDerivedPricing({
    required int packToStripMultiplier,
    required int stripToPieceMultiplier,
    int? explicitTotalUnits,
    required double costPerPieceBdt,
    required double mrpPerPieceBdt,
    bool allowStripSale = true,
    bool allowPieceSale = true,
  }) {
    if (packToStripMultiplier < 1 || stripToPieceMultiplier < 1) {
      return PricingCalculationResult.failure(
        errorCode: 'ERR_INVALID_MULTIPLIER',
        errorMessage: 'Packaging multipliers must be positive integers (>= 1).',
      );
    }

    final expectedTotalUnits = packToStripMultiplier * stripToPieceMultiplier;
    if (explicitTotalUnits != null && explicitTotalUnits != expectedTotalUnits) {
      return PricingCalculationResult.failure(
        errorCode: 'ERR_DIMENSION_MISMATCH',
        errorMessage:
            'Total base units ($explicitTotalUnits) does not match calculated product ($expectedTotalUnits).',
      );
    }

    if (costPerPieceBdt <= 0.0 || mrpPerPieceBdt <= 0.0) {
      return PricingCalculationResult.failure(
        errorCode: 'ERR_INVALID_PRICE',
        errorMessage: 'Cost and MRP per piece must be greater than 0.0.',
      );
    }

    if (expectedTotalUnits > 1 && !allowStripSale && !allowPieceSale) {
      return PricingCalculationResult.failure(
        errorCode: 'ERR_INVALID_BREAK_BULK_POLICY',
        errorMessage:
            'Multi-unit packaging must allow either strip sale or loose piece sale.',
      );
    }

    final double stripCost = double.parse(
      (costPerPieceBdt * stripToPieceMultiplier).toStringAsFixed(4),
    );
    final double stripMrp = double.parse(
      (mrpPerPieceBdt * stripToPieceMultiplier).toStringAsFixed(4),
    );
    final double packCost = double.parse(
      (costPerPieceBdt * expectedTotalUnits).toStringAsFixed(4),
    );
    final double packMrp = double.parse(
      (mrpPerPieceBdt * expectedTotalUnits).toStringAsFixed(4),
    );

    return PricingCalculationResult.success(
      totalUnits: expectedTotalUnits,
      stripCost: stripCost,
      stripMrp: stripMrp,
      packCost: packCost,
      packMrp: packMrp,
    );
  }

  /// Evaluates whether the given user role can mutate pricing.
  /// CASHIER role is read-only.
  bool canEditPricing(String? role) {
    if (role == null) return false;
    final normalized = role.toUpperCase().trim();
    return normalized != 'CASHIER';
  }

  /// Resolves localized string for base dispensing unit.
  String getUnitDisplay(String unitCode, {String locale = 'en'}) {
    final entry = unitTranslations[unitCode.toUpperCase().trim()];
    if (entry != null) {
      return entry[locale] ?? entry['en'] ?? unitCode;
    }
    return unitCode;
  }

  /// Builds standardized canonical payload for DRF API POST / PATCH.
  Map<String, dynamic> buildPricingPayload({
    required String productId,
    required String baseDispensingUnit,
    required int packToStripMultiplier,
    required int stripToPieceMultiplier,
    required double costPerPieceBdt,
    required double mrpPerPieceBdt,
    bool allowStripSale = true,
    bool allowPieceSale = true,
    double vatRatePercentage = 0.0,
  }) {
    final calc = calculateDerivedPricing(
      packToStripMultiplier: packToStripMultiplier,
      stripToPieceMultiplier: stripToPieceMultiplier,
      costPerPieceBdt: costPerPieceBdt,
      mrpPerPieceBdt: mrpPerPieceBdt,
      allowStripSale: allowStripSale,
      allowPieceSale: allowPieceSale,
    );

    return {
      'product_id': productId,
      'base_dispensing_unit': baseDispensingUnit,
      'pack_to_strip_multiplier': packToStripMultiplier,
      'strip_to_piece_multiplier': stripToPieceMultiplier,
      'total_base_units_per_pack': calc.totalBaseUnitsPerPack,
      'cost_per_piece_bdt': costPerPieceBdt,
      'mrp_per_piece_bdt': mrpPerPieceBdt,
      'strip_cost_bdt': calc.stripCostBdt,
      'strip_mrp_bdt': calc.stripMrpBdt,
      'pack_cost_bdt': calc.packCostBdt,
      'pack_mrp_bdt': calc.packMrpBdt,
      'allow_strip_sale': allowStripSale,
      'allow_piece_sale': allowPieceSale,
      'vat_rate_percentage': vatRatePercentage,
    };
  }
}

