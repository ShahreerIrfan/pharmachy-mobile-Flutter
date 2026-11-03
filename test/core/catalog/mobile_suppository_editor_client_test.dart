// test/core/catalog/mobile_suppository_editor_client_test.dart
// Unit tests for MobileSuppositoryEditorClient (P150)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_suppository_editor_client.dart';

void main() {
  group('MobileSuppositoryEditorClient Tests', () {
    test('validateDraftPayload accepts valid rectal suppository configuration', () {
      final payload = {
        'product_id': 'prod-001',
        'suppository_base_type': 'FATTY_BASE_COCOA_BUTTER',
        'administration_route': 'RECTAL',
        'strength_value': 250.0,
        'strength_unit': 'MG',
        'pieces_per_strip': 5,
        'strips_per_pack': 2,
        'total_pieces_per_pack': 10,
        'loose_piece_sale_eligible': true,
        'requires_refrigeration': true,
        'storage_condition': 'REFRIGERATED_2_8',
      };

      final res = MobileSuppositoryEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
    });

    test('validateDraftPayload rejects solid oral tablet attributes', () {
      final payload = {
        'product_id': 'prod-001',
        'suppository_base_type': 'FATTY_BASE_COCOA_BUTTER',
        'administration_route': 'RECTAL',
        'strength_value': 250.0,
        'pieces_per_strip': 5,
        'strips_per_pack': 2,
        'tablets_per_strip': 10, // Prohibited solid field
      };

      final res = MobileSuppositoryEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validateDraftPayload rejects needle gauge field', () {
      final payload = {
        'product_id': 'prod-001',
        'suppository_base_type': 'WATER_SOLUBLE_PEG',
        'administration_route': 'VAGINAL',
        'strength_value': 500.0,
        'pieces_per_strip': 6,
        'strips_per_pack': 1,
        'needle_gauge': '27G', // Prohibited injectable field
      };

      final res = MobileSuppositoryEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validateDraftPayload rejects invalid suppository base', () {
      final payload = {
        'product_id': 'prod-001',
        'suppository_base_type': 'PETROLEUM_JELLY',
        'administration_route': 'RECTAL',
        'strength_value': 250.0,
        'pieces_per_strip': 5,
        'strips_per_pack': 2,
      };

      final res = MobileSuppositoryEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_SUPPOSITORY_BASE'));
    });

    test('validateDraftPayload rejects invalid administration route', () {
      final payload = {
        'product_id': 'prod-001',
        'suppository_base_type': 'FATTY_BASE_COCOA_BUTTER',
        'administration_route': 'ORAL',
        'strength_value': 250.0,
        'pieces_per_strip': 5,
        'strips_per_pack': 2,
      };

      final res = MobileSuppositoryEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_SUPPOSITORY_ROUTE'));
    });

    test('validateDraftPayload rejects non-positive strength', () {
      final payload = {
        'product_id': 'prod-001',
        'suppository_base_type': 'FATTY_BASE_COCOA_BUTTER',
        'administration_route': 'RECTAL',
        'strength_value': 0.0,
        'pieces_per_strip': 5,
        'strips_per_pack': 2,
      };

      final res = MobileSuppositoryEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_STRENGTH'));
    });

    test('validateDraftPayload rejects out-of-bounds pieces per strip', () {
      final payload = {
        'product_id': 'prod-001',
        'suppository_base_type': 'FATTY_BASE_COCOA_BUTTER',
        'administration_route': 'RECTAL',
        'strength_value': 250.0,
        'pieces_per_strip': 0,
        'strips_per_pack': 2,
      };

      final res = MobileSuppositoryEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_PIECES_PER_STRIP'));
    });

    test('validateDraftPayload rejects dimension consistency mismatch', () {
      final payload = {
        'product_id': 'prod-001',
        'suppository_base_type': 'FATTY_BASE_COCOA_BUTTER',
        'administration_route': 'RECTAL',
        'strength_value': 250.0,
        'pieces_per_strip': 5,
        'strips_per_pack': 2,
        'total_pieces_per_pack': 15, // 5 * 2 = 10 != 15
      };

      final res = MobileSuppositoryEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_DIMENSION_CONSISTENCY_MISMATCH'));
    });

    test('validateDraftPayload enforces melt protection when refrigeration is required', () {
      final payload = {
        'product_id': 'prod-001',
        'suppository_base_type': 'FATTY_BASE_COCOA_BUTTER',
        'administration_route': 'RECTAL',
        'strength_value': 250.0,
        'pieces_per_strip': 5,
        'strips_per_pack': 2,
        'requires_refrigeration': true,
        'storage_condition': 'COOL_BELOW_30',
      };

      final res = MobileSuppositoryEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_MELT_PROTECTION_STORAGE_REQUIRED'));
    });

    test('MobileSuppositoryRecord serialization and deserialization', () {
      final jsonMap = {
        'config_id': 'cfg-supp-001',
        'product_id': 'prod-001',
        'tenant_id': 'tenant-test',
        'suppository_base_type': 'FATTY_BASE_COCOA_BUTTER',
        'administration_route': 'RECTAL',
        'strength_value': 250.0,
        'strength_unit': 'MG',
        'pieces_per_strip': 5,
        'strips_per_pack': 2,
        'total_pieces_per_pack': 10,
        'loose_piece_sale_eligible': true,
        'requires_refrigeration': true,
        'storage_condition': 'REFRIGERATED_2_8',
        'patient_instructions_en': 'Insert into rectum',
        'patient_instructions_bn': 'মলদ্বারে প্রবেশ করান',
        'is_active': true,
      };

      final record = MobileSuppositoryRecord.fromJson(jsonMap);
      expect(record.configId, equals('cfg-supp-001'));
      expect(record.strengthValue, equals(250.0));
      expect(record.piecesPerStrip, equals(5));
      expect(record.totalPiecesPerPack, equals(10));
      expect(record.requiresRefrigeration, isTrue);

      final outJson = record.toJson();
      expect(outJson['suppository_base_type'], equals('FATTY_BASE_COCOA_BUTTER'));
      expect(outJson['pieces_per_strip'], equals(5));
      expect(outJson['total_pieces_per_pack'], equals(10));
    });
  });
}
