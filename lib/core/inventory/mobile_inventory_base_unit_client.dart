/// MobileInventoryBaseUnitClient
/// Architecture Decision: ADR-0161 (P161).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Mobile inventory base-unit client for Flutter Mobile Manager.
/// Provides multi-tier conversions (Pack -> Strip -> Base), indivisible
/// unit constraints, unpacking reversal, and exact financial valuation.
class MobileStrategyConfig {
  final String strategyId;
  final String productId;
  final String baseUnit;
  final bool isIndivisible;
  final bool allowDecimalQuantities;
  final int decimalPlacesAllowed;
  final double minimumDispenseQuantity;
  final String packUnitLabel;
  final String intermediateUnitLabel;
  final int packToIntermediateMultiplier;
  final int intermediateToBaseMultiplier;
  final int totalBaseUnitsPerPack;
  final double costPerBaseUnit;
  final double mrpPerBaseUnit;

  const MobileStrategyConfig({
    required this.strategyId,
    required this.productId,
    required this.baseUnit,
    this.isIndivisible = true,
    this.allowDecimalQuantities = false,
    this.decimalPlacesAllowed = 0,
    this.minimumDispenseQuantity = 1.0,
    this.packUnitLabel = 'BOX',
    this.intermediateUnitLabel = 'STRIP',
    this.packToIntermediateMultiplier = 1,
    this.intermediateToBaseMultiplier = 1,
    required this.totalBaseUnitsPerPack,
    required this.costPerBaseUnit,
    required this.mrpPerBaseUnit,
  });
}

class MobileConversionResult {
  final bool success;
  final String? errorCode;
  final String? errorMessageEn;
  final String? errorMessageBn;
  final double baseUnitQuantity;
  final double costValuationBdt;
  final double mrpValuationBdt;

  const MobileConversionResult({
    required this.success,
    this.errorCode,
    this.errorMessageEn,
    this.errorMessageBn,
    required this.baseUnitQuantity,
    required this.costValuationBdt,
    required this.mrpValuationBdt,
  });

  factory MobileConversionResult.failure({
    required String errorCode,
    required String messageEn,
    required String messageBn,
  }) {
    return MobileConversionResult(
      success: false,
      errorCode: errorCode,
      errorMessageEn: messageEn,
      errorMessageBn: messageBn,
      baseUnitQuantity: 0.0,
      costValuationBdt: 0.0,
      mrpValuationBdt: 0.0,
    );
  }

  factory MobileConversionResult.success({
    required double baseUnitQuantity,
    required double costValuation,
    required double mrpValuation,
  }) {
    return MobileConversionResult(
      success: true,
      baseUnitQuantity: baseUnitQuantity,
      costValuationBdt: costValuation,
      mrpValuationBdt: mrpValuation,
    );
  }
}

class MobileDecomposeResult {
  final int totalBaseUnits;
  final int packs;
  final String packLabel;
  final int intermediate;
  final String intermediateLabel;
  final int looseBase;
  final String baseUnit;

  const MobileDecomposeResult({
    required this.totalBaseUnits,
    required this.packs,
    required this.packLabel,
    required this.intermediate,
    required this.intermediateLabel,
    required this.looseBase,
    required this.baseUnit,
  });
}

class MobileInventoryBaseUnitClient {
  bool canConfigureStrategy(String? userRole) {
    if (userRole == null || userRole.trim().isEmpty) {
      return false;
    }
    return userRole.trim().toUpperCase() != 'CASHIER';
  }

  MobileConversionResult convertToBaseUnits({
    required double quantity,
    required String unitTier,
    required MobileStrategyConfig config,
  }) {
    if (quantity <= 0) {
      return MobileConversionResult.failure(
        errorCode: 'ERR_INVALID_QUANTITY',
        messageEn: 'Quantity must be strictly positive.',
        messageBn: 'পরিমাণ অবশ্যই ধনাত্মক হতে হবে।',
      );
    }

    final tier = unitTier.trim().toUpperCase();
    double baseQty;

    switch (tier) {
      case 'PACK':
        baseQty = quantity * config.totalBaseUnitsPerPack;
        break;
      case 'INTERMEDIATE':
        baseQty = quantity * config.intermediateToBaseMultiplier;
        break;
      case 'BASE':
        baseQty = quantity;
        break;
      default:
        return MobileConversionResult.failure(
          errorCode: 'ERR_INVALID_UNIT_TIER',
          messageEn: 'Unit tier must be PACK, INTERMEDIATE, or BASE.',
          messageBn: 'ইউনিট টায়ার PACK, INTERMEDIATE অথবা BASE হতে হবে।',
        );
    }

    if (config.isIndivisible) {
      if (baseQty % 1.0 != 0.0) {
        return MobileConversionResult.failure(
          errorCode: 'ERR_INDIVISIBLE_UNIT_FRACTION',
          messageEn:
              "Item has indivisible base unit '${config.baseUnit}' and cannot have fractional pieces ($baseQty).",
          messageBn:
              "'${config.baseUnit}' একটি অবিভাজ্য একক, এটি ভগ্নাংশে রূপান্তর করা যাবে না।",
        );
      }
    }

    final costVal = baseQty * config.costPerBaseUnit;
    final mrpVal = baseQty * config.mrpPerBaseUnit;

    return MobileConversionResult.success(
      baseUnitQuantity: baseQty,
      costValuation: costVal,
      mrpValuation: mrpVal,
    );
  }

  MobileDecomposeResult decomposeBaseUnits({
    required int totalBaseUnits,
    required MobileStrategyConfig config,
  }) {
    if (totalBaseUnits < 0) {
      return MobileDecomposeResult(
        totalBaseUnits: 0,
        packs: 0,
        packLabel: config.packUnitLabel,
        intermediate: 0,
        intermediateLabel: config.intermediateUnitLabel,
        looseBase: 0,
        baseUnit: config.baseUnit,
      );
    }

    final packFactor = config.totalBaseUnitsPerPack;
    final stripFactor = config.intermediateToBaseMultiplier;

    final packs = totalBaseUnits ~/ packFactor;
    final remainderAfterPacks = totalBaseUnits % packFactor;

    final strips = remainderAfterPacks ~/ stripFactor;
    final looseBase = remainderAfterPacks % stripFactor;

    return MobileDecomposeResult(
      totalBaseUnits: totalBaseUnits,
      packs: packs,
      packLabel: config.packUnitLabel,
      intermediate: strips,
      intermediateLabel: config.intermediateUnitLabel,
      looseBase: looseBase,
      baseUnit: config.baseUnit,
    );
  }

  List<String> validateDispenseQuantity({
    required double quantity,
    required MobileStrategyConfig config,
  }) {
    final errors = <String>[];
    if (quantity < config.minimumDispenseQuantity) {
      errors.add('ERR_BELOW_MINIMUM_DISPENSE_QTY');
      return errors;
    }

    if (config.isIndivisible) {
      if (quantity % 1.0 != 0.0) {
        errors.add('ERR_INDIVISIBLE_UNIT_FRACTION');
      }
    }
    return errors;
  }
}

