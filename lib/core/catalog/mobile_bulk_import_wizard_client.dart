// lib/core/catalog/mobile_bulk_import_wizard_client.dart
// Architecture Decision: ADR-0132
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P132)

enum MobileBulkImportUiStatus {
  success,
  error,
  permissionDenied,
  empty,
  offline,
}

class MobileImportRowError {
  final int rowIndex;
  final String field;
  final String errorMessage;

  const MobileImportRowError({
    required this.rowIndex,
    required this.field,
    required this.errorMessage,
  });

  factory MobileImportRowError.fromJson(Map<String, dynamic> json) {
    return MobileImportRowError(
      rowIndex: (json['row_index'] as num?)?.toInt() ?? 0,
      field: (json['field'] as String?) ?? '',
      errorMessage: (json['error_message'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'row_index': rowIndex,
        'field': field,
        'error_message': errorMessage,
      };
}

class MobileImportSession {
  final String sessionId;
  final String fileName;
  final String fileFormat;
  String status; // UPLOADED, MAPPED, VALIDATED, COMMITTED, ROLLED_BACK, FAILED
  int totalRows;
  int validRows;
  int invalidRows;
  int duplicateRows;
  String duplicatePolicy; // SKIP, UPDATE_OVERWRITE, FAIL_ON_DUPLICATE
  final List<String> rawHeaders;
  final List<Map<String, String>> previewRows;
  final List<Map<String, String>> allRawRows;
  Map<String, String> fieldMapping;
  List<MobileImportRowError> validationErrors;
  final List<String> createdProductIds;
  DateTime? committedAt;
  DateTime? rolledBackAt;

  MobileImportSession({
    required this.sessionId,
    required this.fileName,
    this.fileFormat = 'CSV',
    required this.status,
    required this.totalRows,
    this.validRows = 0,
    this.invalidRows = 0,
    this.duplicateRows = 0,
    this.duplicatePolicy = 'SKIP',
    this.rawHeaders = const [],
    this.previewRows = const [],
    this.allRawRows = const [],
    Map<String, String>? fieldMapping,
    List<MobileImportRowError>? validationErrors,
    List<String>? createdProductIds,
    this.committedAt,
    this.rolledBackAt,
  })  : fieldMapping = fieldMapping != null ? Map<String, String>.from(fieldMapping) : <String, String>{},
        validationErrors = validationErrors != null ? List<MobileImportRowError>.from(validationErrors) : <MobileImportRowError>[],
        createdProductIds = createdProductIds != null ? List<String>.from(createdProductIds) : <String>[];
}

class MobileBulkImportResult<T> {
  final MobileBulkImportUiStatus status;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileBulkImportResult({
    required this.status,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  static MobileBulkImportResult<T> success<T>(T data) {
    return MobileBulkImportResult<T>(
      status: MobileBulkImportUiStatus.success,
      data: data,
      messageEn: 'Operation completed successfully.',
      messageBn: 'অপারেশন সফলভাবে সম্পন্ন হয়েছে।',
    );
  }

  static MobileBulkImportResult<T> offline<T>(T data) {
    return MobileBulkImportResult<T>(
      status: MobileBulkImportUiStatus.offline,
      data: data,
      errorCode: 'STATUS_OFFLINE_CACHE',
      messageEn: 'Operating in offline draft mode.',
      messageBn: 'অফলাইন ড্রাফট মোড সক্রিয়।',
    );
  }

  static MobileBulkImportResult<T> permissionDenied<T>(String code, String en, String bn) {
    return MobileBulkImportResult<T>(
      status: MobileBulkImportUiStatus.permissionDenied,
      errorCode: code,
      messageEn: en,
      messageBn: bn,
    );
  }

  static MobileBulkImportResult<T> error<T>(String code, String en, String bn) {
    return MobileBulkImportResult<T>(
      status: MobileBulkImportUiStatus.error,
      errorCode: code,
      messageEn: en,
      messageBn: bn,
    );
  }

  static MobileBulkImportResult<T> empty<T>(String en, String bn) {
    return MobileBulkImportResult<T>(
      status: MobileBulkImportUiStatus.empty,
      errorCode: 'ERR_SESSION_NOT_FOUND',
      messageEn: en,
      messageBn: bn,
    );
  }
}

class MobileBulkImportWizardClient {
  final Map<String, MobileImportSession> _sessionStore = {};
  final Set<String> _existingCatalogBarcodes = {};
  bool _isOffline = false;

  void setOfflineMode(bool offline) {
    _isOffline = offline;
  }

  bool isOfflineMode() => _isOffline;

  void registerExistingCatalogBarcode(String barcode) {
    if (barcode.trim().isNotEmpty) {
      _existingCatalogBarcodes.add(barcode.trim());
    }
  }

  static Map<String, String> autoSuggestMapping(List<String> rawHeaders) {
    final mapping = <String, String>{};
    final synonyms = <String, List<String>>{
      'brand_name': ['brand', 'brand_name', 'trade_name', 'item_name', 'name'],
      'generic_name': ['generic', 'generic_name', 'molecule', 'inn'],
      'dosage_form': ['form', 'dosage_form', 'dosage', 'type'],
      'strength': ['strength', 'power', 'dose'],
      'mrp_unit': ['mrp', 'mrp_unit', 'price', 'retail_price', 'sale_price'],
      'cost_unit': ['cost', 'cost_unit', 'trade_price', 'tp', 'purchase_price'],
      'manufacturer': ['manufacturer', 'company', 'maker', 'pharma'],
      'barcode': ['barcode', 'upc', 'ean', 'gtin', 'code'],
    };

    for (final header in rawHeaders) {
      final clean = header.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
      for (final entry in synonyms.entries) {
        if (clean == entry.key || entry.value.contains(clean)) {
          mapping[header] = entry.key;
          break;
        }
      }
    }
    return mapping;
  }

  MobileBulkImportResult<MobileImportSession> uploadCsv({
    required String actorRole,
    required String fileName,
    required String csvContent,
    String duplicatePolicy = 'SKIP',
  }) {
    final cleanRole = actorRole.trim().toUpperCase();
    if (cleanRole == 'CASHIER') {
      return MobileBulkImportResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot perform bulk catalog import operations.',
        'ক্যাশিয়াররা বাল্ক মেডিসিন ইমপোর্ট করতে পারবেন না।',
      );
    }

    if (csvContent.trim().isEmpty) {
      return MobileBulkImportResult.error('ERR_EMPTY_CSV', 'CSV content cannot be empty.', 'সিএসভি ফাইল ফাঁকা রাখা যাবে না।');
    }

    final lines = csvContent.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) {
      return MobileBulkImportResult.error('ERR_NO_ROWS', 'CSV contains no rows.', 'সিএসভিতে কোনো সারি নেই।');
    }

    final headerLine = lines[0];
    final delimiter = headerLine.contains(';') ? ';' : headerLine.contains('\t') ? '\t' : ',';
    final rawHeaders = headerLine
        .split(delimiter)
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toList();

    if (rawHeaders.isEmpty) {
      return MobileBulkImportResult.error('ERR_NO_HEADERS', 'No column headers detected in CSV.', 'সিএসভিতে কোনো কলাম হেডার পাওয়া যায়নি।');
    }

    final allRows = <Map<String, String>>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cells = line.split(delimiter);
      final row = <String, String>{};
      for (int j = 0; j < rawHeaders.length; j++) {
        row[rawHeaders[j]] = j < cells.length ? cells[j].trim() : '';
      }
      allRows.add(row);
    }

    final preview = allRows.length > 5 ? allRows.sublist(0, 5) : allRows;
    final autoMapping = autoSuggestMapping(rawHeaders);

    final sessionId = 'imp-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final session = MobileImportSession(
      sessionId: sessionId,
      fileName: fileName.isNotEmpty ? fileName : 'catalog.csv',
      status: 'UPLOADED',
      totalRows: allRows.length,
      rawHeaders: rawHeaders,
      previewRows: preview,
      allRawRows: allRows,
      fieldMapping: autoMapping,
      duplicatePolicy: duplicatePolicy,
    );

    _sessionStore[sessionId] = session;

    if (autoMapping.containsValue('brand_name') && autoMapping.containsValue('mrp_unit')) {
      applyMappingAndValidate(
        sessionId: sessionId,
        fieldMapping: autoMapping,
        duplicatePolicy: duplicatePolicy,
      );
    }

    if (_isOffline) {
      return MobileBulkImportResult.offline(session);
    }
    return MobileBulkImportResult.success(session);
  }

  MobileBulkImportResult<MobileImportSession> applyMappingAndValidate({
    required String sessionId,
    Map<String, String>? fieldMapping,
    String? duplicatePolicy,
  }) {
    final session = _sessionStore[sessionId];
    if (session == null) {
      return MobileBulkImportResult.empty("Import session '$sessionId' not found.", "ইমপোর্ট সেশন '$sessionId' পাওয়া যায়নি।");
    }

    if (fieldMapping != null && fieldMapping.isNotEmpty) {
      session.fieldMapping = Map<String, String>.from(fieldMapping);
    }
    if (duplicatePolicy != null && duplicatePolicy.trim().isNotEmpty) {
      session.duplicatePolicy = duplicatePolicy.trim().toUpperCase();
    }

    final errors = <MobileImportRowError>[];
    final seenBarcodes = <String>{};
    int validCount = 0;
    int duplicateCount = 0;

    for (int i = 0; i < session.allRawRows.length; i++) {
      final rawRow = session.allRawRows[i];
      final rowIdx = i + 1;
      bool hasError = false;

      final mapped = <String, String>{};
      for (final entry in session.fieldMapping.entries) {
        mapped[entry.value] = rawRow[entry.key]?.trim() ?? '';
      }

      final brand = mapped['brand_name'] ?? '';
      if (brand.isEmpty) {
        errors.add(MobileImportRowError(rowIndex: rowIdx, field: 'brand_name', errorMessage: 'Brand name is mandatory.'));
        hasError = true;
      }

      final mrpStr = mapped['mrp_unit'] ?? '';
      if (mrpStr.isEmpty) {
        errors.add(MobileImportRowError(rowIndex: rowIdx, field: 'mrp_unit', errorMessage: 'MRP unit price is mandatory.'));
        hasError = true;
      } else {
        final mrp = double.tryParse(mrpStr.replaceAll(',', ''));
        if (mrp == null || mrp <= 0.0) {
          errors.add(MobileImportRowError(rowIndex: rowIdx, field: 'mrp_unit', errorMessage: 'MRP must be a positive decimal number.'));
          hasError = true;
        }
      }

      final barcode = mapped['barcode'] ?? '';
      bool isDuplicate = false;
      if (barcode.isNotEmpty) {
        if (seenBarcodes.contains(barcode) || _existingCatalogBarcodes.contains(barcode)) {
          isDuplicate = true;
        }
        seenBarcodes.add(barcode);
      }

      if (isDuplicate) {
        duplicateCount++;
        if (session.duplicatePolicy == 'FAIL_ON_DUPLICATE') {
          errors.add(MobileImportRowError(rowIndex: rowIdx, field: 'barcode', errorMessage: 'Duplicate drug barcode detected under FAIL_ON_DUPLICATE policy.'));
          hasError = true;
        }
      }

      if (!hasError && !(session.duplicatePolicy == 'SKIP' && isDuplicate)) {
        validCount++;
      }
    }

    session.validRows = validCount;
    session.invalidRows = session.allRawRows.length - validCount;
    session.duplicateRows = duplicateCount;
    session.validationErrors = errors;
    session.status = 'VALIDATED';

    return MobileBulkImportResult.success(session);
  }

  MobileBulkImportResult<MobileImportSession> commitImport(String sessionId) {
    final session = _sessionStore[sessionId];
    if (session == null) {
      return MobileBulkImportResult.empty("Import session '$sessionId' not found.", "ইমপোর্ট সেশন '$sessionId' পাওয়া যায়নি।");
    }

    if (session.status == 'COMMITTED') {
      return MobileBulkImportResult.error('ERR_IMPORT_ALREADY_COMMITTED', 'Import session already committed.', 'ইমপোর্ট সেশনটি ইতোমধ্যে কমিট করা হয়েছে।');
    }
    if (session.status == 'ROLLED_BACK') {
      return MobileBulkImportResult.error('ERR_IMPORT_ALREADY_ROLLED_BACK', 'Cannot commit a rolled-back session.', 'রোলব্যাককৃত সেশন পুনরায় কমিট করা যাবে না।');
    }
    if (session.validRows == 0) {
      return MobileBulkImportResult.error('ERR_ZERO_VALID_ROWS', 'Cannot commit import with 0 valid rows.', 'কোনো সঠিক তথ্য না থাকায় কমিট করা সম্ভব নয়।');
    }

    final created = <String>[];
    for (int i = 0; i < session.validRows; i++) {
      created.add('prod-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}_$i');
    }

    session.createdProductIds.addAll(created);
    session.status = 'COMMITTED';
    session.committedAt = DateTime.now();

    return MobileBulkImportResult.success(session);
  }

  MobileBulkImportResult<MobileImportSession> rollbackImport(String sessionId) {
    final session = _sessionStore[sessionId];
    if (session == null) {
      return MobileBulkImportResult.empty("Import session '$sessionId' not found.", "ইমপোর্ট সেশন '$sessionId' পাওয়া যায়নি।");
    }

    if (session.status == 'ROLLED_BACK') {
      return MobileBulkImportResult.error('ERR_IMPORT_ALREADY_ROLLED_BACK', 'Import session already rolled back.', 'ইমপোর্ট সেশনটি ইতোমধ্যে রোলব্যাক করা হয়েছে।');
    }
    if (session.status != 'COMMITTED') {
      return MobileBulkImportResult.error('ERR_INVALID_STATUS', 'Only committed imports can be rolled back.', 'শুধুমাত্র কমিট করা সেশনই রোলব্যাক করা সম্ভব।');
    }

    session.createdProductIds.clear();
    session.status = 'ROLLED_BACK';
    session.rolledBackAt = DateTime.now();

    return MobileBulkImportResult.success(session);
  }

  MobileImportSession? getSession(String sessionId) => _sessionStore[sessionId];
}
