import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/layout/mobile_dynamic_field_group_layout_client.dart';

void main() {
  group('MobileDynamicFieldGroupLayoutClient Tests (P152)', () {
    late MobileDynamicFieldGroupLayoutClient client;
    late List<MobileFieldLayoutGroup> sampleGroups;

    setUp(() {
      client = MobileDynamicFieldGroupLayoutClient();

      const brandField = MobileFieldDefinition(
        fieldName: 'brand_name',
        tabIndex: 1,
        labelEn: 'Brand Name',
        labelBn: 'ব্র্যান্ড নাম',
        controlType: 'TEXT_INPUT',
        isMandatory: true,
        desktopGridWidth: 'HALF',
        keyboardMnemonic: 'B',
        ariaLabel: 'Enter brand name',
      );

      const genericField = MobileFieldDefinition(
        fieldName: 'generic_name',
        tabIndex: 2,
        labelEn: 'Generic Name',
        labelBn: 'জেনেরিক নাম',
        controlType: 'TEXT_INPUT',
        isMandatory: true,
        desktopGridWidth: 'HALF',
        keyboardMnemonic: 'N',
        ariaLabel: 'Enter generic name',
      );

      const actuationField = MobileFieldDefinition(
        fieldName: 'dose_per_actuation',
        tabIndex: 5,
        labelEn: 'Dose per Actuation',
        labelBn: 'প্রতি পাফে মাত্রা',
        controlType: 'TEXT_INPUT',
        isMandatory: true,
        desktopGridWidth: 'HALF',
        keyboardMnemonic: 'E',
        ariaLabel: 'Inhaler dose',
      );

      const stripField = MobileFieldDefinition(
        fieldName: 'pieces_per_strip',
        tabIndex: 10,
        labelEn: 'Pieces per Strip',
        labelBn: 'স্ট্রিপে পিস সংখ্যা',
        controlType: 'NUMERIC_INPUT',
        isMandatory: false,
        desktopGridWidth: 'THIRD',
        keyboardMnemonic: '1',
      );

      const packField = MobileFieldDefinition(
        fieldName: 'strips_per_pack',
        tabIndex: 11,
        labelEn: 'Strips per Pack',
        labelBn: 'প্যাকে স্ট্রিপ',
        controlType: 'NUMERIC_INPUT',
        isMandatory: false,
        desktopGridWidth: 'THIRD',
        keyboardMnemonic: '2',
      );

      const totalField = MobileFieldDefinition(
        fieldName: 'total_pieces_per_pack',
        tabIndex: 12,
        labelEn: 'Total Pieces per Pack',
        labelBn: 'মোট পিস',
        controlType: 'NUMERIC_INPUT',
        isMandatory: false,
        desktopGridWidth: 'THIRD',
        keyboardMnemonic: '3',
      );

      const group1 = MobileFieldLayoutGroup(
        groupCode: 'GENERAL_IDENTIFICATION',
        displayOrder: 1,
        titleEn: 'General Identification',
        titleBn: 'সাধারণ পরিচিতি',
        keyboardShortcutMnemonic: 'G',
        fields: [brandField, genericField],
        isVisible: true,
      );

      const group2 = MobileFieldLayoutGroup(
        groupCode: 'FORM_SPECIFIC_PARAMETERS',
        displayOrder: 2,
        titleEn: 'Formulation Parameters',
        titleBn: 'ডোজ ফর্ম পরিমাপ',
        keyboardShortcutMnemonic: 'F',
        visibilityCondition: {
          'field': 'dosage_form',
          'operator': 'IN',
          'value': ['INHALER'],
        },
        fields: [actuationField],
        isVisible: true,
      );

      const group3 = MobileFieldLayoutGroup(
        groupCode: 'PACKAGING_DIMENSIONS',
        displayOrder: 3,
        titleEn: 'Packaging Dimensions',
        titleBn: 'প্যাকেজিং হিসাব',
        keyboardShortcutMnemonic: 'P',
        fields: [stripField, packField, totalField],
        isVisible: true,
      );

      sampleGroups = [group1, group2, group3];
    });

    test('1. Evaluate visibility condition for INHALER dosage form', () {
      const condition = {
        'field': 'dosage_form',
        'operator': 'IN',
        'value': ['INHALER', 'DROPS'],
      };

      final inhalerValues = {'dosage_form': 'INHALER'};
      expect(client.evaluateVisibility(condition, inhalerValues), isTrue);

      final tabletValues = {'dosage_form': 'TABLET'};
      expect(client.evaluateVisibility(condition, tabletValues), isFalse);
    });

    test('2. Resolve linear keyboard tab sequence across visible groups', () {
      final tabSeq = client.resolveTabSequence(sampleGroups);

      expect(tabSeq.length, equals(6));
      expect(tabSeq[0].fieldName, equals('brand_name'));
      expect(tabSeq[0].tabIndex, equals(1));
      expect(tabSeq[1].fieldName, equals('generic_name'));
      expect(tabSeq[1].tabIndex, equals(2));
      expect(tabSeq[2].fieldName, equals('dose_per_actuation'));
      expect(tabSeq[2].tabIndex, equals(5));
      expect(tabSeq[3].fieldName, equals('pieces_per_strip'));
      expect(tabSeq[3].tabIndex, equals(10));
      expect(tabSeq[4].fieldName, equals('strips_per_pack'));
      expect(tabSeq[4].tabIndex, equals(11));
      expect(tabSeq[5].fieldName, equals('total_pieces_per_pack'));
      expect(tabSeq[5].tabIndex, equals(12));
    });

    test('3. Inline errors aggregated for missing mandatory fields', () {
      final formValues = {
        'brand_name': '',
        'generic_name': 'Salbutamol',
        'dose_per_actuation': '',
      };

      final errors = client.validateFormInputs(sampleGroups, formValues);

      expect(errors.length, equals(2));
      expect(errors[0].fieldName, equals('brand_name'));
      expect(errors[0].errorCode, equals('ERR_MANDATORY_FIELD_MISSING'));
      expect(errors[1].fieldName, equals('dose_per_actuation'));
    });

    test('4. Inline error on packaging dimension mismatch', () {
      final formValues = {
        'brand_name': 'Napa 500',
        'generic_name': 'Paracetamol',
        'dose_per_actuation': '100mcg',
        'pieces_per_strip': 10,
        'strips_per_pack': 5,
        'total_pieces_per_pack': 60, // 10 * 5 = 50 != 60
      };

      final errors = client.validateFormInputs(sampleGroups, formValues);

      expect(errors.length, equals(1));
      expect(errors[0].fieldName, equals('total_pieces_per_pack'));
      expect(errors[0].errorCode, equals('ERR_DIMENSION_MISMATCH'));
    });

    test('5. Inline error on storage temperature range order', () {
      final formValues = {
        'brand_name': 'Cold Chain Drug',
        'generic_name': 'Sample',
        'dose_per_actuation': 'N/A',
        'storage_temperature_celsius_min': '30.0',
        'storage_temperature_celsius_max': '20.0', // Min > Max
      };

      final errors = client.validateFormInputs(sampleGroups, formValues);

      expect(errors.length, equals(1));
      expect(errors[0].fieldName, equals('storage_temperature_celsius_min'));
      expect(errors[0].errorCode, equals('ERR_INVALID_TEMPERATURE_RANGE'));
    });

    test('6. Serialization and deserialization preserves all group and field definitions', () {
      final json = sampleGroups[0].toJson();
      expect(json['group_code'], equals('GENERAL_IDENTIFICATION'));
      expect(json['keyboard_shortcut_mnemonic'], equals('G'));

      final deserialized = MobileFieldLayoutGroup.fromJson(json);
      expect(deserialized.groupCode, equals('GENERAL_IDENTIFICATION'));
      expect(deserialized.fields.length, equals(2));
      expect(deserialized.fields[0].fieldName, equals('brand_name'));
    });
  });
}
