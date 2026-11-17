/// mobile_barcode_inventory_client.dart
/// Architecture Decision: ADR-0218 (P218).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.
///
/// Mobile Manager Client for Barcode Inventory Workflows:
/// - Receive: Inward scanning, cold-chain checks, and staging.
/// - Put-Away: Batch barcode + location barcode with storage policy enforcement.
/// - Move: Internal relocation between storage shelves/bins.
/// - Count: Physical cycle counts with discrepancy auditing.
/// - Verify: Station barcode lookup with FEFO expiry and quarantine alerts.
/// - Bilingual operator prompts in English and Bengali.

enum MobileBarcodeWorkflowType {
  receive('Inward Receive & Staging', 'ইনওয়ার্ড গ্রহণ ও স্টেজিং'),
  putAway('Put-Away to Shelf / Bin', 'সেলফ/বিনে সংরক্ষণ'),
  move('Internal Relocation', 'অভ্যন্তরীণ স্থানান্তর'),
  count('Cycle Count & Audit', 'সাইকেল কাউন্ট ও অডিট'),
  verify('Item & Expiry Verification', 'আইটেম ও মেয়াদ যাচাই');

  final String labelEn;
  final String labelBn;

  const MobileBarcodeWorkflowType(this.labelEn, this.labelBn);
}

class MobileBarcodeScanResult {
  final MobileBarcodeWorkflowType workflowType;
  final String productName;
  final String batchNumber;
  final String sourceLocation;
  final String destinationLocation;
  final int expectedQuantity;
  final int scannedQuantity;
  final int discrepancy;
  final String operatorPromptEn;
  final String operatorPromptBn;
  final bool isSuccess;
  final String errorCode;

  MobileBarcodeScanResult({
    required this.workflowType,
    this.productName = '',
    this.batchNumber = '',
    this.sourceLocation = '',
    this.destinationLocation = '',
    this.expectedQuantity = 0,
    this.scannedQuantity = 0,
    required this.operatorPromptEn,
    required this.operatorPromptBn,
    this.isSuccess = true,
    this.errorCode = '',
  }) : discrepancy = scannedQuantity - expectedQuantity;

  Map<String, dynamic> toJson() => {
    'workflow_type': workflowType.name,
    'product_name': productName,
    'batch_number': batchNumber,
    'source_location': sourceLocation,
    'destination_location': destinationLocation,
    'expected_quantity': expectedQuantity,
    'scanned_quantity': scannedQuantity,
    'discrepancy': discrepancy,
    'operator_prompt_en': operatorPromptEn,
    'operator_prompt_bn': operatorPromptBn,
    'is_success': isSuccess,
    'error_code': errorCode,
  };
}

class MobileBarcodeInventoryClient {
  final Map<String, String> _batchLocations = {};

  MobileBarcodeScanResult receive({
    required String productName,
    required String barcode,
    required bool isColdChain,
  }) {
    final String promptEn;
    final String promptBn;

    if (isColdChain) {
      promptEn = "Cold-Chain item '$productName' received. Immediately transfer to refrigerated storage (2°C - 8°C).";
      promptBn = "কোল্ড-চেইন আইটেম '$productName' গৃহীত হয়েছে। অবিলম্বে রেফ্রিজারেটরে (২°-৮° সে.) স্থানান্তর করুন।";
    } else {
      promptEn = "Item '$productName' received. Scan destination storage shelf or bin barcode.";
      promptBn = "আইটেম '$productName' গৃহীত হয়েছে। স্টোরেজ সেলফ বা বিন বারকোড স্ক্যান করুন।";
    }

    return MobileBarcodeScanResult(
      workflowType: MobileBarcodeWorkflowType.receive,
      productName: productName,
      operatorPromptEn: promptEn,
      operatorPromptBn: promptBn,
      isSuccess: true,
    );
  }

  MobileBarcodeScanResult putAway({
    required String batchNumber,
    required String destinationLocation,
    required bool isColdChain,
    bool enforceColdChain = true,
  }) {
    final dest = destinationLocation.trim().toUpperCase();
    final isFridge = dest.contains('FRIDGE') || dest.contains('COLD') || dest.contains('CHILL');

    if (isColdChain && enforceColdChain && !isFridge) {
      final promptEn = "Storage policy violation: Cold-chain batch '$batchNumber' cannot be placed in ambient zone '$dest'. Scan refrigerator location.";
      final promptBn = "স্টোরেজ নীতি লঙ্ঘন: কোল্ড-চেইন ব্যাচ '$batchNumber' সাধারণ স্থান '$dest'-এ রাখা যাবে না। রেফ্রিজারেটর লোকেশন স্ক্যান করুন।";
      return MobileBarcodeScanResult(
        workflowType: MobileBarcodeWorkflowType.putAway,
        batchNumber: batchNumber,
        destinationLocation: dest,
        operatorPromptEn: promptEn,
        operatorPromptBn: promptBn,
        isSuccess: false,
        errorCode: 'ERR_STORAGE_POLICY_VIOLATION',
      );
    }

    _batchLocations[batchNumber] = dest;
    final promptEn = "Batch '$batchNumber' placed in '$dest' successfully.";
    final promptBn = "ব্যাচ '$batchNumber' সফলভাবে '$dest' লোকেশনে সংরক্ষণ করা হয়েছে।";

    return MobileBarcodeScanResult(
      workflowType: MobileBarcodeWorkflowType.putAway,
      batchNumber: batchNumber,
      destinationLocation: dest,
      operatorPromptEn: promptEn,
      operatorPromptBn: promptBn,
      isSuccess: true,
    );
  }

  MobileBarcodeScanResult move({
    required String batchNumber,
    required String fromLocation,
    required String toLocation,
  }) {
    final dest = toLocation.trim().toUpperCase();
    _batchLocations[batchNumber] = dest;

    final promptEn = "Relocation complete: Batch '$batchNumber' moved from '$fromLocation' to '$dest'.";
    final promptBn = "স্থানান্তর সম্পন্ন: ব্যাচ '$batchNumber' '$fromLocation' থেকে '$dest'-এ স্থানান্তরিত হয়েছে।";

    return MobileBarcodeScanResult(
      workflowType: MobileBarcodeWorkflowType.move,
      batchNumber: batchNumber,
      sourceLocation: fromLocation,
      destinationLocation: dest,
      operatorPromptEn: promptEn,
      operatorPromptBn: promptBn,
      isSuccess: true,
    );
  }

  MobileBarcodeScanResult count({
    required String batchNumber,
    required String location,
    required int countedQty,
    required int systemQty,
  }) {
    final discrepancy = countedQty - systemQty;
    final String promptEn;
    final String promptBn;

    if (discrepancy == 0) {
      promptEn = "Count matched: $countedQty units verified for batch '$batchNumber' (Zero discrepancy).";
      promptBn = "গণনা মিলেছে: ব্যাচ '$batchNumber'-এর জন্য $countedQty ইউনিট নিশ্চিত (কোনো পার্থক্য নেই)।";
    } else {
      promptEn = "Discrepancy detected: Counted $countedQty vs System $systemQty (${discrepancy > 0 ? '+' : ''}$discrepancy units). Logged for review.";
      promptBn = "পার্থক্য শনাক্ত: গণনা $countedQty বনাম সিস্টেম $systemQty (${discrepancy > 0 ? '+' : ''}$discrepancy ইউনিট)। পর্যালোচনার জন্য রেকর্ড করা হয়েছে।";
    }

    return MobileBarcodeScanResult(
      workflowType: MobileBarcodeWorkflowType.count,
      batchNumber: batchNumber,
      sourceLocation: location,
      expectedQuantity: systemQty,
      scannedQuantity: countedQty,
      operatorPromptEn: promptEn,
      operatorPromptBn: promptBn,
      isSuccess: true,
    );
  }

  MobileBarcodeScanResult verify({
    required String productName,
    required String batchNumber,
    required int quantity,
    required bool isExpired,
    required bool isQuarantined,
  }) {
    final String promptEn;
    final String promptBn;

    if (isExpired) {
      promptEn = "EXPIRED LOT ALERT: Batch '$batchNumber' is expired. DO NOT DISPENSE.";
      promptBn = "মেয়াদোত্তীর্ণ ব্যাচ সতর্কতা: ব্যাচ '$batchNumber'-এর মেয়াদ শেষ। বিক্রি করবেন না।";
    } else if (isQuarantined) {
      promptEn = "QUARANTINE ALERT: Batch '$batchNumber' is held in quarantine.";
      promptBn = "কোয়ারেন্টাইন সতর্কতা: ব্যাচ '$batchNumber' কোয়ারেন্টাইনে রয়েছে।";
    } else {
      promptEn = "Verified: $productName (Batch: $batchNumber, Qty: $quantity).";
      promptBn = "যাচাইকৃত: $productName (ব্যাচ: $batchNumber, পরিমাণ: $quantity)।";
    }

    return MobileBarcodeScanResult(
      workflowType: MobileBarcodeWorkflowType.verify,
      productName: productName,
      batchNumber: batchNumber,
      sourceLocation: _batchLocations[batchNumber] ?? '',
      expectedQuantity: quantity,
      scannedQuantity: quantity,
      operatorPromptEn: promptEn,
      operatorPromptBn: promptBn,
      isSuccess: true,
    );
  }
}
