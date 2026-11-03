/// MobilePackagingHierarchyClient
/// Architecture Decision: ADR-0162 (P162).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Mobile packaging hierarchy tree resolution and effective-dated conversion engine
/// for Flutter Mobile Manager.
class MobilePackagingNode {
  final String nodeId;
  final String productId;
  final String parentUnit;
  final String childUnit;
  final int conversionFactor;
  final int tierLevel;
  final bool isBaseLevel;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final bool isActive;

  const MobilePackagingNode({
    required this.nodeId,
    required this.productId,
    required this.parentUnit,
    required this.childUnit,
    required this.conversionFactor,
    this.tierLevel = 1,
    this.isBaseLevel = false,
    required this.effectiveFrom,
    this.effectiveTo,
    this.isActive = true,
  });

  bool isEffectiveAt(DateTime targetDate) {
    if (!isActive) return false;
    final dOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final fOnly = DateTime(effectiveFrom.year, effectiveFrom.month, effectiveFrom.day);
    if (dOnly.isBefore(fOnly)) return false;
    if (effectiveTo != null) {
      final tOnly = DateTime(effectiveTo!.year, effectiveTo!.month, effectiveTo!.day);
      if (dOnly.isAfter(tOnly)) return false;
    }
    return true;
  }
}

class MobileHierarchyTree {
  final String productId;
  final DateTime asOfDate;
  final String baseUnit;
  final List<MobilePackagingNode> chain;
  final Map<String, int> cumulativeFactors;

  const MobileHierarchyTree({
    required this.productId,
    required this.asOfDate,
    required this.baseUnit,
    required this.chain,
    required this.cumulativeFactors,
  });
}

class MobileHierarchyConversionResult {
  final bool success;
  final String? errorCode;
  final String? errorMessageEn;
  final String? errorMessageBn;
  final double inputQuantity;
  final double convertedQuantity;
  final double conversionRatio;
  final String? fromUnit;
  final String? toUnit;
  final String? baseUnit;

  const MobileHierarchyConversionResult({
    required this.success,
    this.errorCode,
    this.errorMessageEn,
    this.errorMessageBn,
    required this.inputQuantity,
    required this.convertedQuantity,
    required this.conversionRatio,
    this.fromUnit,
    this.toUnit,
    this.baseUnit,
  });

  factory MobileHierarchyConversionResult.failure({
    required String errorCode,
    required String messageEn,
    required String messageBn,
  }) {
    return MobileHierarchyConversionResult(
      success: false,
      errorCode: errorCode,
      errorMessageEn: messageEn,
      errorMessageBn: messageBn,
      inputQuantity: 0.0,
      convertedQuantity: 0.0,
      conversionRatio: 0.0,
    );
  }

  factory MobileHierarchyConversionResult.success({
    required double inputQuantity,
    required double convertedQuantity,
    required double conversionRatio,
    required String fromUnit,
    required String toUnit,
    required String baseUnit,
  }) {
    return MobileHierarchyConversionResult(
      success: true,
      inputQuantity: inputQuantity,
      convertedQuantity: convertedQuantity,
      conversionRatio: conversionRatio,
      fromUnit: fromUnit,
      toUnit: toUnit,
      baseUnit: baseUnit,
    );
  }
}

class MobilePackagingHierarchyClient {
  bool canConfigurePackaging(String? userRole) {
    if (userRole == null || userRole.trim().isEmpty) return false;
    return userRole.trim().toUpperCase() != 'CASHIER';
  }

  bool hasCycle(String parent, String child, List<MobilePackagingNode> nodes) {
    final p = parent.trim().toUpperCase();
    final c = child.trim().toUpperCase();
    if (p == c) return true;

    final graph = <String, Set<String>>{};
    for (final node in nodes) {
      if (node.isActive) {
        graph.putIfAbsent(node.parentUnit.toUpperCase(), () => {}).add(node.childUnit.toUpperCase());
      }
    }

    final visited = <String>{};
    final queue = <String>[c];

    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      if (curr == p) return true;
      if (visited.add(curr)) {
        final next = graph[curr];
        if (next != null) queue.addAll(next);
      }
    }
    return false;
  }

  MobileHierarchyTree resolvePackagingTree({
    required String productId,
    required List<MobilePackagingNode> nodes,
    DateTime? asOfDate,
  }) {
    final targetDate = asOfDate ?? DateTime.now();
    final activeNodes = nodes.where((n) => n.productId == productId && n.isEffectiveAt(targetDate)).toList();

    if (activeNodes.isEmpty) {
      return MobileHierarchyTree(
        productId: productId,
        asOfDate: targetDate,
        baseUnit: 'PIECE',
        chain: const [],
        cumulativeFactors: const {},
      );
    }

    final parentMap = <String, MobilePackagingNode>{};
    final children = <String>{};
    for (final n in activeNodes) {
      parentMap[n.parentUnit.toUpperCase()] = n;
      children.add(n.childUnit.toUpperCase());
    }

    String? root;
    for (final p in parentMap.keys) {
      if (!children.contains(p)) {
        root = p;
        break;
      }
    }
    root ??= parentMap.keys.first;

    final chain = <MobilePackagingNode>[];
    String curr = root;
    final visited = <String>{};
    while (parentMap.containsKey(curr) && visited.add(curr)) {
      final n = parentMap[curr]!;
      chain.add(n);
      curr = n.childUnit.toUpperCase();
    }

    final baseUnit = curr;
    final cumulativeFactors = <String, int>{baseUnit: 1};
    var acc = 1;
    for (var i = chain.length - 1; i >= 0; i--) {
      final n = chain[i];
      acc *= n.conversionFactor;
      cumulativeFactors[n.parentUnit.toUpperCase()] = acc;
    }

    return MobileHierarchyTree(
      productId: productId,
      asOfDate: targetDate,
      baseUnit: baseUnit,
      chain: chain,
      cumulativeFactors: cumulativeFactors,
    );
  }

  MobileHierarchyConversionResult convertPackagingTier({
    required String productId,
    required String fromUnit,
    required String toUnit,
    required double quantity,
    required List<MobilePackagingNode> nodes,
    DateTime? asOfDate,
  }) {
    if (quantity <= 0) {
      return MobileHierarchyConversionResult.failure(
        errorCode: 'ERR_INVALID_QUANTITY',
        messageEn: 'Quantity must be strictly positive.',
        messageBn: 'পরিমাণ অবশ্যই ধনাত্মক হতে হবে।',
      );
    }

    final from = fromUnit.trim().toUpperCase();
    final to = toUnit.trim().toUpperCase();
    final tree = resolvePackagingTree(productId: productId, nodes: nodes, asOfDate: asOfDate);

    final fromFactor = tree.cumulativeFactors[from];
    final toFactor = tree.cumulativeFactors[to];

    if (fromFactor == null || toFactor == null) {
      return MobileHierarchyConversionResult.failure(
        errorCode: 'ERR_UNLINKED_PACKAGING_TIER',
        messageEn: "Units '$from' and/or '$to' are not part of the active packaging tree.",
        messageBn: "'$from' অথবা '$to' প্যাকেজিং ট্রির অংশ নয়।",
      );
    }

    final baseQty = quantity * fromFactor;
    final convertedQty = baseQty / toFactor;
    final ratio = fromFactor / toFactor;

    return MobileHierarchyConversionResult.success(
      inputQuantity: quantity,
      convertedQuantity: convertedQty,
      conversionRatio: ratio,
      fromUnit: from,
      toUnit: to,
      baseUnit: tree.baseUnit,
    );
  }
}

