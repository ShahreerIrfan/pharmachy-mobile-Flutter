/// MobileMultiLevelUnitConversionClient
/// Architecture Decision: ADR-0163 (P163).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Mobile multi-level unit conversion and validation engine for Flutter Mobile Manager.
/// Enforces fractional tablet prevention and inappropriate dosing-unit guardrails.
class MobileConversionPolicy {
  final String policyId;
  final String productId;
  final bool isSplittable;
  final List<double> allowedSplitFractions;
  final String clinicalDosingUnit;
  final double dosingConversionRatio;
  final Set<String> prohibitedDosingUnits;

  const MobileConversionPolicy({
    required this.policyId,
    required this.productId,
    this.isSplittable = false,
    this.allowedSplitFractions = const [1.0],
    this.clinicalDosingUnit = 'MG',
    this.dosingConversionRatio = 500.0,
    this.prohibitedDosingUnits = const {},
  });
}

class MobileValidationReport {
  final bool isValid;
  final String? errorCode;
  final String? errorMessageEn;
  final String? errorMessageBn;

  const MobileValidationReport({
    required this.isValid,
    this.errorCode,
    this.errorMessageEn,
    this.errorMessageBn,
  });

  factory MobileValidationReport.ok() => const MobileValidationReport(isValid: true);

  factory MobileValidationReport.failure({
    required String code,
    required String en,
    required String bn,
  }) {
    return MobileValidationReport(
      isValid: false,
      errorCode: code,
      errorMessageEn: en,
      errorMessageBn: bn,
    );
  }
}

class MobileConversionResult {
  final bool success;
  final String? errorCode;
  final String? errorMessageEn;
  final String? errorMessageBn;
  final double inputQuantity;
  final double convertedQuantity;
  final double costValuationBdt;
  final double mrpValuationBdt;
  final bool isClinicalDosingCalculation;

  const MobileConversionResult({
    required this.success,
    this.errorCode,
    this.errorMessageEn,
    this.errorMessageBn,
    required this.inputQuantity,
    required this.convertedQuantity,
    required this.costValuationBdt,
    required this.mrpValuationBdt,
    this.isClinicalDosingCalculation = false,
  });

  factory MobileConversionResult.failure({
    required String code,
    required String en,
    required String bn,
  }) {
    return MobileConversionResult(
      success: false,
      errorCode: code,
      errorMessageEn: en,
      errorMessageBn: bn,
      inputQuantity: 0.0,
      convertedQuantity: 0.0,
      costValuationBdt: 0.0,
      mrpValuationBdt: 0.0,
    );
  }

  factory MobileConversionResult.success({
    required double inQty,
    required double convQty,
    required double costVal,
    required double mrpVal,
    bool isClinical = false,
  }) {
    return MobileConversionResult(
      success: true,
      inputQuantity: inQty,
      convertedQuantity: convQty,
      costValuationBdt: costVal,
      mrpValuationBdt: mrpVal,
      isClinicalDosingCalculation: isClinical,
    );
  }
}

class MobileMultiLevelUnitConversionClient {
  bool canConfigurePolicy(String? userRole) {
    if (userRole == null || userRole.trim().isEmpty) return false;
    return userRole.trim().toUpperCase() != 'CASHIER';
  }

  MobileValidationReport validateDispense({
    required String unit,
    required double quantity,
    required String dosageForm,
    MobileConversionPolicy? policy,
  }) {
    if (quantity <= 0) {
      return MobileValidationReport.failure(
        code: 'ERR_INVALID_QUANTITY',
        en: 'Quantity must be strictly positive.',
        bn: 'পরিমাণ অবশ্যই ধনাত্মক হতে হবে।',
      );
    }

    final u = unit.trim().toUpperCase();
    if (policy != null && policy.prohibitedDosingUnits.contains(u)) {
      return MobileValidationReport.failure(
        code: 'ERR_INCOMPATIBLE_DOSING_UNIT',
        en: "Unit '$u' is incompatible with dosage form '$dosageForm'.",
        bn: "'$u' ইউনিটটি '$dosageForm' ডোজেজ ফর্মের সাথে সামঞ্জস্যপূর্ণ নয়।",
      );
    }

    final hasFraction = (quantity % 1.0) != 0.0;
    if (hasFraction) {
      final isSolidTablet = u == 'TABLET' ||
          u == 'CAPSULE' ||
          dosageForm.toUpperCase().contains('TABLET') ||
          dosageForm.toUpperCase().contains('CAPSULE');

      if (isSolidTablet) {
        if (policy == null || !policy.isSplittable) {
          return MobileValidationReport.failure(
            code: 'ERR_FRACTIONAL_TABLET_NOT_ALLOWED',
            en: 'Tablet is not scored or splittable. Fractional dispensing is prohibited.',
            bn: 'ট্যাবলেটটি অবিভাজ্য এবং ভগ্নাংশে বিক্রি বা বিতরণ নিষিদ্ধ।',
          );
        }

        final frac = quantity % 1.0;
        final matchesAllowed = policy.allowedSplitFractions.any(
          (allowed) => allowed < 1.0 && (frac - allowed).abs() < 0.001,
        );

        if (!matchesAllowed) {
          return MobileValidationReport.failure(
            code: 'ERR_INVALID_TABLET_SPLIT',
            en: 'Fractional step ($frac) is not permitted.',
            bn: 'অননুমোদিত ভগ্নাংশে ট্যাবলেট বিভাজন প্রচেষ্টা।',
          );
        }
      } else if (u == 'VIAL' || u == 'AMPOULE' || u == 'BOTTLE' || u == 'CANISTER') {
        return MobileValidationReport.failure(
          code: 'ERR_INDIVISIBLE_UNIT_FRACTION',
          en: "Unit '$u' is an indivisible pack item and cannot have fractional amounts.",
          bn: "'$u' একটি অবিভাজ্য একক এবং ভগ্নাংশে বিতরণ করা যাবে না।",
        );
      }
    }

    return MobileValidationReport.ok();
  }

  MobileConversionResult convertMultiLevel({
    required double quantity,
    required String fromUnit,
    required String toUnit,
    required int packagingMultiplier,
    required String dosageForm,
    MobileConversionPolicy? policy,
    double costPerBaseUnit = 0.0,
    double mrpPerBaseUnit = 0.0,
  }) {
    final fromCheck = validateDispense(
      unit: fromUnit,
      quantity: quantity,
      dosageForm: dosageForm,
      policy: policy,
    );
    if (!fromCheck.isValid) {
      return MobileConversionResult.failure(
        code: fromCheck.errorCode!,
        en: fromCheck.errorMessageEn!,
        bn: fromCheck.errorMessageBn!,
      );
    }

    final toU = toUnit.trim().toUpperCase();
    if (policy != null && policy.prohibitedDosingUnits.contains(toU)) {
      return MobileConversionResult.failure(
        code: 'ERR_INCOMPATIBLE_DOSING_UNIT',
        en: "Target unit '$toU' is prohibited for dosage form '$dosageForm'.",
        bn: "টার্গেট ইউনিট '$toU' নিষিদ্ধ।",
      );
    }

    // Clinical potency calculation (e.g. Tablets -> MG)
    if (policy != null && toU == policy.clinicalDosingUnit.toUpperCase()) {
      final totalPotency = quantity * policy.dosingConversionRatio;
      return MobileConversionResult.success(
        inQty: quantity,
        convQty: totalPotency,
        costVal: 0.0,
        mrpVal: 0.0,
        isClinical: true,
      );
    }

    final mult = packagingMultiplier > 0 ? packagingMultiplier : 1;
    final convertedQty = quantity * mult;

    final toCheck = validateDispense(
      unit: toU,
      quantity: convertedQty,
      dosageForm: dosageForm,
      policy: policy,
    );
    if (!toCheck.isValid) {
      return MobileConversionResult.failure(
        code: toCheck.errorCode!,
        en: toCheck.errorMessageEn!,
        bn: toCheck.errorMessageBn!,
      );
    }

    final costVal = convertedQty * costPerBaseUnit;
    final mrpVal = convertedQty * mrpPerBaseUnit;

    return MobileConversionResult.success(
      inQty: quantity,
      convQty: convertedQty,
      costVal: costVal,
      mrpVal: mrpVal,
      isClinical: false,
    );
  }
}

