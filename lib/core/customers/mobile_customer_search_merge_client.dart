// Architecture Decision: ADR-0268 (P268)
// Phase 14: Customers, Suppliers, Dues & Payments.
// Mobile Customer Search and Merge Client for Manager/Owner Flutter App.

class MobileNormalizedPhoneResult {
  final String raw;
  final String digits;
  final String local11;
  final String e164;
  final bool isValidBd;
  final List<String> variants;

  const MobileNormalizedPhoneResult({
    required this.raw,
    required this.digits,
    required this.local11,
    required this.e164,
    required this.isValidBd,
    required this.variants,
  });
}

class MobileCustomerSearchMergeClient {
  static const Set<String> allowedMergeRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'ADMIN',
  };

  /// Normalizes arbitrary Bangladesh phone input into local and international canonical variants.
  static MobileNormalizedPhoneResult normalizeBdPhone(String rawPhone) {
    final raw = rawPhone.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return MobileNormalizedPhoneResult(
        raw: raw,
        digits: '',
        local11: '',
        e164: '',
        isValidBd: false,
        variants: const [],
      );
    }

    String local11 = '';
    if (digits.startsWith('880') && digits.length == 13) {
      local11 = '0${digits.substring(3)}';
    } else if (digits.startsWith('0') && digits.length == 11) {
      local11 = digits;
    } else if (digits.startsWith('1') && digits.length == 10) {
      local11 = '0$digits';
    } else if (digits.length == 11 && digits.startsWith('01')) {
      local11 = digits;
    }

    final isValidBd = local11.length == 11 && local11.startsWith('01');
    final e164 = isValidBd ? '+88$local11' : '+$digits';

    final variantSet = <String>{raw, digits};
    if (isValidBd) {
      variantSet.add(local11);
      variantSet.add(e164);
      variantSet.add('88$local11');
      variantSet.add(local11.substring(1));
    }

    final variants = variantSet.toList()..sort();
    return MobileNormalizedPhoneResult(
      raw: raw,
      digits: digits,
      local11: local11,
      e164: e164,
      isValidBd: isValidBd,
      variants: variants,
    );
  }

  /// Validates merge inputs on the client before dispatching to API.
  static Map<String, dynamic> validateMergeInputs({
    required String sourceCustomerId,
    required String targetCustomerId,
    required String mergeReason,
    required String userRole,
  }) {
    final roleUpper = userRole.trim().toUpperCase();
    if (!allowedMergeRoles.contains(roleUpper)) {
      return {
        'isValid': false,
        'errorCode': 'ERR_PERMISSION_DENIED',
        'message': 'Only Pharmacy Owner or Branch Manager can merge customer records.',
      };
    }

    final cleanSource = sourceCustomerId.trim();
    final cleanTarget = targetCustomerId.trim();
    if (cleanSource.isEmpty || cleanTarget.isEmpty) {
      return {
        'isValid': false,
        'errorCode': 'ERR_MERGE_INPUT_INVALID',
        'message': 'Source and target customer IDs are required.',
      };
    }

    if (cleanSource == cleanTarget) {
      return {
        'isValid': false,
        'errorCode': 'ERR_SELF_MERGE_FORBIDDEN',
        'message': 'Cannot merge a customer into itself.',
      };
    }

    final cleanReason = mergeReason.trim();
    if (cleanReason.length < 3) {
      return {
        'isValid': false,
        'errorCode': 'ERR_MERGE_REASON_REQUIRED',
        'message': 'A valid merge reason of at least 3 characters is required.',
      };
    }

    return {'isValid': true, 'errorCode': null, 'message': null};
  }
}
