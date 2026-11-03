import 'package:flutter/foundation.dart';

/// MobileLocalInventoryClient
/// Architecture Decision: ADR-0156 (P156).
/// Phase 08: Milestone M04 / M05 - Specialized Item & Consumable Editors.
///
/// Flutter mobile client for branch-specific inventory overrides.
/// Governs branch SKUs, custom store selling prices, reorder alert thresholds,
/// physical shelf coordinates, and store visibility.

enum InventoryUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

@immutable
class LocalInventoryValidationResult {
  final bool isValid;
  final String? errorCode;
  final String? errorMessage;
  final double effectiveSellingPrice;
  final bool isPriceOverridden;

  const LocalInventoryValidationResult({
    required this.isValid,
    this.errorCode,
    this.errorMessage,
    this.effectiveSellingPrice = 0.0,
    this.isPriceOverridden = false,
  });

  factory LocalInventoryValidationResult.success({
    required double effectivePrice,
    required bool isPriceOverridden,
  }) {
    return LocalInventoryValidationResult(
      isValid: true,
      effectiveSellingPrice: effectivePrice,
      isPriceOverridden: isPriceOverridden,
    );
  }

  factory LocalInventoryValidationResult.failure({
    required String errorCode,
    required String errorMessage,
  }) {
    return LocalInventoryValidationResult(
      isValid: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }
}

class MobileLocalInventoryClient {
  static final RegExp skuPattern = RegExp(r'^[A-Za-z0-9\-_./]*$');

  /// Validates branch inventory parameters and calculates effective price.
  LocalInventoryValidationResult validateLocalInventory({
    String? localSku,
    double? localSellingPriceBdt,
    double? masterMrpUnit,
    int reorderLevel = 10,
    int minOrderQuantity = 1,
    int? maxCapacityUnits,
    String? shelfLocation,
  }) {
    if (localSku != null && localSku.trim().isNotEmpty) {
      final trimmed = localSku.trim();
      if (trimmed.length > 64) {
        return LocalInventoryValidationResult.failure(
          errorCode: 'ERR_INVALID_SKU_LENGTH',
          errorMessage: 'Local SKU cannot exceed 64 characters.',
        );
      }
      if (!skuPattern.hasMatch(trimmed)) {
        return LocalInventoryValidationResult.failure(
          errorCode: 'ERR_INVALID_SKU_FORMAT',
          errorMessage: 'Local SKU contains invalid characters.',
        );
      }
    }

    if (localSellingPriceBdt != null && localSellingPriceBdt < 0.01) {
      return LocalInventoryValidationResult.failure(
        errorCode: 'ERR_INVALID_SELLING_PRICE',
        errorMessage: 'Local selling price must be at least 0.01 BDT.',
      );
    }

    if (reorderLevel < 0 || reorderLevel > 100000) {
      return LocalInventoryValidationResult.failure(
        errorCode: 'ERR_INVALID_REORDER_LEVEL',
        errorMessage: 'Reorder level must be between 0 and 100,000.',
      );
    }

    if (minOrderQuantity < 1 || minOrderQuantity > 50000) {
      return LocalInventoryValidationResult.failure(
        errorCode: 'ERR_INVALID_MIN_ORDER_QTY',
        errorMessage: 'Minimum order quantity must be between 1 and 50,000.',
      );
    }

    if (maxCapacityUnits != null && maxCapacityUnits < minOrderQuantity) {
      return LocalInventoryValidationResult.failure(
        errorCode: 'ERR_CAPACITY_BELOW_MIN_ORDER',
        errorMessage:
            'Maximum capacity ($maxCapacityUnits) cannot be less than minimum order quantity ($minOrderQuantity).',
      );
    }

    if (shelfLocation != null && shelfLocation.trim().length > 128) {
      return LocalInventoryValidationResult.failure(
        errorCode: 'ERR_LOCATION_TOO_LONG',
        errorMessage: 'Shelf location cannot exceed 128 characters.',
      );
    }

    final bool overridden = localSellingPriceBdt != null;
    final double effectivePrice = overridden
        ? localSellingPriceBdt
        : (masterMrpUnit ?? 0.0);

    return LocalInventoryValidationResult.success(
      effectivePrice: effectivePrice,
      isPriceOverridden: overridden,
    );
  }

  /// Determines if stock quantity is at or below the reorder threshold.
  bool isLowStock(int currentStock, int reorderLevel) {
    return currentStock <= reorderLevel;
  }

  /// Cashier role is restricted from modifying local inventory configurations.
  bool canMutateInventory(String? role) {
    if (role == null) return false;
    final normalized = role.toUpperCase().trim();
    return normalized != 'CASHIER';
  }

  /// Builds canonical payload for DRF API POST / PATCH.
  Map<String, dynamic> buildInventoryPayload({
    required String productId,
    String? branchId,
    String? localSku,
    double? localSellingPriceBdt,
    int reorderLevel = 10,
    String shelfLocation = '',
    bool isVisible = true,
    int minOrderQuantity = 1,
    int? maxCapacityUnits,
    String notes = '',
  }) {
    final validation = validateLocalInventory(
      localSku: localSku,
      localSellingPriceBdt: localSellingPriceBdt,
      reorderLevel: reorderLevel,
      minOrderQuantity: minOrderQuantity,
      maxCapacityUnits: maxCapacityUnits,
      shelfLocation: shelfLocation,
    );

    if (!validation.isValid) {
      throw ArgumentError(validation.errorMessage);
    }

    return {
      'product_id': productId,
      'branch_id': branchId,
      'local_sku': localSku?.trim() ?? '',
      'local_selling_price_bdt': localSellingPriceBdt,
      'reorder_level': reorderLevel,
      'shelf_location': shelfLocation.trim(),
      'is_visible': isVisible,
      'min_order_quantity': minOrderQuantity,
      'max_capacity_units': maxCapacityUnits,
      'notes': notes.trim(),
    };
  }
}
