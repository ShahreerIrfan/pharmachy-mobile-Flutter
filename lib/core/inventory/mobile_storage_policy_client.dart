/// mobile_storage_policy_client.dart
/// Architecture Decision: ADR-0213 (P213).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.

enum MobileStorageLocationType {
  shelf('Ambient Shelf / Rack', 'সাধারণ শেলফ / র্যাক'),
  bin('Medicine Bin / Drawer', 'মেডিসিন বিন / ড্রয়ার'),
  fridge('Refrigerated Cold Chain Unit (2°C - 8°C)', 'রেফ্রিজারেটর কোল্ড-চেইন (২°সে - ৮°সে)'),
  freezer('Deep Freezer Unit (-20°C)', 'ডিপ ফ্রিজার (-২০°সে)'),
  quarantineZone('Quarantine Holding Area', 'কোয়ারেন্টাইন এলাকা'),
  narcoticsVault('Controlled Substances Vault', 'নিয়ন্ত্রিত ওষুধের ভল্ট'),
  dispensaryCounter('Dispensary Fast Counter', 'দ্রুত বিতরণ কাউন্টার');

  final String labelEn;
  final String labelBn;

  const MobileStorageLocationType(this.labelEn, this.labelBn);
}

class MobileStorageLocationInfo {
  final String locationId;
  final String branchId;
  final String code;
  final String name;
  final MobileStorageLocationType locationType;
  final bool isColdCapable;
  final double? minTemp;
  final double? maxTemp;

  MobileStorageLocationInfo({
    required this.locationId,
    required this.branchId,
    required this.code,
    required this.name,
    required this.locationType,
    bool? isColdCapable,
    this.minTemp,
    this.maxTemp,
  }) : isColdCapable = isColdCapable ?? (locationType == MobileStorageLocationType.fridge || locationType == MobileStorageLocationType.freezer);

  Map<String, dynamic> toJson() => {
    'location_id': locationId,
    'branch_id': branchId,
    'code': code,
    'name': name,
    'location_type': locationType.name,
    'is_cold_capable': isColdCapable,
    'min_temp': minTemp,
    'max_temp': maxTemp,
  };
}

class MobileBatchAssignment {
  final String batchId;
  final String batchNumber;
  final String productName;
  final bool requiresColdChain;
  String storageLocationCode;
  final int quantityUnits;

  MobileBatchAssignment({
    required this.batchId,
    required this.batchNumber,
    required this.productName,
    required this.requiresColdChain,
    required this.storageLocationCode,
    required this.quantityUnits,
  });

  Map<String, dynamic> toJson() => {
    'batch_id': batchId,
    'batch_number': batchNumber,
    'product_name': productName,
    'requires_cold_chain': requiresColdChain,
    'storage_location_code': storageLocationCode,
    'quantity_units': quantityUnits,
  };
}

class MobileStorageValidationResult {
  final bool isCompliant;
  final String reason;
  final String productName;
  final String locationCode;

  MobileStorageValidationResult({
    required this.isCompliant,
    required this.reason,
    required this.productName,
    required this.locationCode,
  });

  Map<String, dynamic> toJson() => {
    'is_compliant': isCompliant,
    'reason': reason,
    'product_name': productName,
    'location_code': locationCode,
  };
}

class MobileStoragePolicyClient {
  static const Set<String> _allowedRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
  };

  void _assertInventoryRole(String userRole) {
    if (userRole.toUpperCase() == 'CASHIER' || !_allowedRoles.contains(userRole.toUpperCase())) {
      throw Exception('Cashiers cannot assign or relocate medicine stock. Access is restricted to Managers, Owners, and Pharmacists.');
    }
  }

  MobileStorageValidationResult validateAssignment({
    required String productName,
    required bool requiresColdChain,
    required MobileStorageLocationInfo targetLocation,
    String? overrideJustification,
  }) {
    if (requiresColdChain && !targetLocation.isColdCapable) {
      if (overrideJustification != null && overrideJustification.trim().length >= 15) {
        return MobileStorageValidationResult(
          isCompliant: true,
          reason: 'Overridden with clinical justification: ${overrideJustification.trim()}',
          productName: productName,
          locationCode: targetLocation.code,
        );
      }
      return MobileStorageValidationResult(
        isCompliant: false,
        reason: "Storage policy violation: Medicine '$productName' requires cold-chain temperature control (2.00°C - 8.00°C) and cannot be assigned to ambient location '${targetLocation.name}' [${targetLocation.code}].",
        productName: productName,
        locationCode: targetLocation.code,
      );
    }

    if (!requiresColdChain && targetLocation.locationType == MobileStorageLocationType.freezer) {
      return MobileStorageValidationResult(
        isCompliant: false,
        reason: "Storage policy violation: Ambient product '$productName' cannot be stored in Deep Freezer '${targetLocation.name}'.",
        productName: productName,
        locationCode: targetLocation.code,
      );
    }

    return MobileStorageValidationResult(
      isCompliant: true,
      reason: 'Storage assignment is compliant.',
      productName: productName,
      locationCode: targetLocation.code,
    );
  }

  MobileBatchAssignment relocateBatch({
    required String userRole,
    required MobileBatchAssignment batch,
    required MobileStorageLocationInfo targetLocation,
    String? overrideJustification,
  }) {
    _assertInventoryRole(userRole);

    final check = validateAssignment(
      productName: batch.productName,
      requiresColdChain: batch.requiresColdChain,
      targetLocation: targetLocation,
      overrideJustification: overrideJustification,
    );

    if (!check.isCompliant) {
      throw ArgumentError(check.reason);
    }

    batch.storageLocationCode = targetLocation.code;
    return batch;
  }

  Map<String, dynamic> auditBranchCompliance({
    required List<MobileBatchAssignment> batches,
    required Map<String, MobileStorageLocationInfo> locationsMap,
  }) {
    int total = batches.length;
    int compliantCount = 0;
    List<Map<String, String>> violations = [];

    for (final b in batches) {
      final loc = locationsMap[b.storageLocationCode];
      if (loc == null) {
        if (b.requiresColdChain) {
          violations.add({
            'batch_number': b.batchNumber,
            'product_name': b.productName,
            'reason': 'Cold chain product stored in unmapped location.',
          });
        } else {
          compliantCount++;
        }
        continue;
      }

      final res = validateAssignment(
        productName: b.productName,
        requiresColdChain: b.requiresColdChain,
        targetLocation: loc,
      );

      if (res.isCompliant) {
        compliantCount++;
      } else {
        violations.add({
          'batch_number': b.batchNumber,
          'product_name': b.productName,
          'reason': res.reason,
        });
      }
    }

    return {
      'total_batches': total,
      'compliant_count': compliantCount,
      'violation_count': violations.length,
      'compliance_rate': total > 0 ? (compliantCount / total) * 100.0 : 100.0,
      'violations': violations,
    };
  }
}

