/// dynamic_medicine_form_screen.dart
/// Architecture Decision: ADR-0158 (P158).
/// Phase 08: Specialized Item & Multi-Tier Packaging Formulation Editors.
///
/// Responsive Flutter dynamic medicine form screen with state-preserving dosage switching,
/// canonical backend validation, and multi-tenant RBAC enforcement.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/forms/mobile_dynamic_medicine_form_client.dart';
import '../../core/forms/mobile_dynamic_medicine_form_engine.dart';
import '../../core/theme/tokens.dart';
import '../../models/tenant_session.dart';

enum DynamicFormViewState {
  loading,
  loaded,
  empty,
  error,
  permissionDenied,
  offline,
}

class DynamicMedicineFormScreen extends StatefulWidget {
  final TenantSession session;
  final bool isOffline;
  final String initialDosageForm;
  final DynamicFormViewState? forcedState;
  final MobileDynamicMedicineFormClient? client;

  const DynamicMedicineFormScreen({
    super.key,
    required this.session,
    this.isOffline = false,
    this.initialDosageForm = 'TABLET_CAPSULE',
    this.forcedState,
    this.client,
  });

  @override
  State<DynamicMedicineFormScreen> createState() => _DynamicMedicineFormScreenState();
}

class _DynamicMedicineFormScreenState extends State<DynamicMedicineFormScreen> {
  late final MobileDynamicMedicineFormEngine _engine;
  late final MobileDynamicMedicineFormClient _client;
  late DynamicFormViewState _viewState;

  bool _isBengali = false;
  String _statusBannerMessage = '';
  List<InlineValidationError> _errors = [];

  final Map<String, TextEditingController> _controllers = {};

  final List<Map<String, String>> _dosageForms = [
    {'code': 'TABLET_CAPSULE', 'en': 'Solid Oral (Tablet / Capsule)', 'bn': 'ট্যাবলেট / ক্যাপসুল'},
    {'code': 'INHALER', 'en': 'Metered Inhaler', 'bn': 'ইনহেলার'},
    {'code': 'DROPS', 'en': 'Eye / Ear / Nasal Drops', 'bn': 'ড্রপস'},
    {'code': 'TOPICAL_CREAM', 'en': 'Topical Cream / Ointment', 'bn': 'মলম / ক্রিম'},
    {'code': 'SACHET_POWDER', 'en': 'Sachet / Oral Powder', 'bn': 'স্যাশে / পাউডার'},
    {'code': 'SUPPOSITORY', 'en': 'Suppository / Pessary', 'bn': 'সাপোজিটরি'},
    {'code': 'DEVICE_CONSUMABLE', 'en': 'Medical Device & Consumable', 'bn': 'মেডিকেল ডিভাইস ও সরঞ্জাম'},
  ];

  @override
  void initState() {
    super.initState();
    _engine = MobileDynamicMedicineFormEngine(widget.initialDosageForm);
    _client = widget.client ?? MobileDynamicMedicineFormClient();

    if (widget.forcedState != null) {
      _viewState = widget.forcedState!;
    } else if (widget.isOffline) {
      _viewState = DynamicFormViewState.offline;
    } else if (widget.session.isCashier) {
      _viewState = DynamicFormViewState.permissionDenied;
    } else {
      _viewState = DynamicFormViewState.loaded;
    }

    _syncControllersFromEngine();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String fieldName) {
    if (!_controllers.containsKey(fieldName)) {
      final initialVal = _engine.getFieldValue(fieldName)?.toString() ?? '';
      final ctrl = TextEditingController(text: initialVal);
      ctrl.addListener(() {
        _engine.setFieldValue(fieldName, ctrl.text);
      });
      _controllers[fieldName] = ctrl;
    }
    return _controllers[fieldName]!;
  }

  void _syncControllersFromEngine() {
    for (final entry in _engine.currentFormValues.entries) {
      final ctrl = _getController(entry.key);
      if (ctrl.text != entry.value.toString()) {
        ctrl.text = entry.value.toString();
      }
    }
  }

  Future<void> _handleDosageFormSwitch(String newForm) async {
    setState(() {
      _viewState = DynamicFormViewState.loading;
      _statusBannerMessage = _isBengali
          ? 'ডোজ ফর্ম পরিবর্তন করা হচ্ছে...'
          : 'Switching dosage form to $newForm...';
    });

    final currentVals = _engine.currentFormValues;
    final cached = _engine.retainedFormCache;

    final result = await _client.switchDosageForm(
      authToken: widget.session.authToken,
      previousForm: _engine.currentDosageForm,
      newForm: newForm,
      currentValues: currentVals,
      retainedCache: cached,
      isOffline: widget.isOffline,
    );

    _engine.switchDosageForm(result.newDosageForm);
    _syncControllersFromEngine();

    setState(() {
      _viewState = widget.isOffline ? DynamicFormViewState.offline : DynamicFormViewState.loaded;
      _errors.clear();
      _statusBannerMessage = _isBengali
          ? 'সফলভাবে $newForm এ পরিবর্তিত হয়েছে (সাধারণ মনোগ্রাফ তথ্য সংরক্ষিত)'
          : 'Switched to $newForm (common monograph fields preserved)';
    });
  }

  Future<void> _handleValidateAndSave() async {
    if (widget.session.isCashier || !_client.canMutateForm(widget.session.userRole)) {
      setState(() {
        _viewState = DynamicFormViewState.permissionDenied;
        _statusBannerMessage = _isBengali
            ? 'ক্যাশিয়ার রোলের মাস্টার ক্যাটালগে পরিবর্তন করার অনুমতি নেই।'
            : 'Cashier role is not authorized to mutate master catalog definitions.';
      });
      return;
    }

    setState(() {
      _viewState = DynamicFormViewState.loading;
    });

    final result = await _client.validateFormData(
      authToken: widget.session.authToken,
      dosageFormFamily: _engine.currentDosageForm,
      formValues: _engine.currentFormValues,
      isOffline: widget.isOffline,
    );

    setState(() {
      _errors = result.errors;
      if (result.isValid) {
        _viewState = widget.isOffline ? DynamicFormViewState.offline : DynamicFormViewState.loaded;
        _statusBannerMessage = _isBengali
            ? 'ফর্ম সফলভাবে যাচাই করা হয়েছে।'
            : 'Form successfully validated and ready to save.';
      } else {
        _viewState = DynamicFormViewState.error;
        _statusBannerMessage = _isBengali
            ? 'ভ্যালিডেশনে ${_errors.length} টি ত্রুটি পাওয়া গেছে।'
            : 'Validation failed with ${_errors.length} errors.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.surfaceBackground,
      appBar: AppBar(
        title: Text(
          _isBengali ? 'মেডিসিন মনোগ্রাফ এডিটর' : 'Medicine Monograph Editor',
          style: AppTokens.titleMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTokens.primaryTeal,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => setState(() => _isBengali = !_isBengali),
            child: Text(
              _isBengali ? 'ENGLISH' : 'বাংলা',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBodyForCurrentState(),
      ),
    );
  }

  Widget _buildBodyForCurrentState() {
    switch (_viewState) {
      case DynamicFormViewState.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTokens.primaryTeal),
              SizedBox(height: AppTokens.space16),
              Text('Processing dynamic layout...', style: TextStyle(color: AppTokens.textMuted)),
            ],
          ),
        );

      case DynamicFormViewState.permissionDenied:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Card(
              color: AppTokens.cardSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                side: const BorderSide(color: AppTokens.dangerRed, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.space24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.shield_slash, color: AppTokens.dangerRed, size: 48),
                    const SizedBox(height: AppTokens.space16),
                    Text(
                      _isBengali ? 'অনুমতি নেই' : 'Access Restricted',
                      style: AppTokens.titleLarge.copyWith(color: AppTokens.dangerRed),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    Text(
                      _isBengali
                          ? 'ক্যাশিয়ার রোলের মাস্টার আইটেম বা ডোজ ফর্ম পরিবর্তনের অনুমতি নেই। শুধুমাত্র ফার্মাসিস্ট বা ম্যানেজার এই ফর্ম পরিবর্তন করতে পারেন।'
                          : 'Cashier role has read-only access to master catalog definitions. Contact a Pharmacist or Branch Manager for catalog modifications.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTokens.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      case DynamicFormViewState.empty:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.doc_text, size: 48, color: AppTokens.textMuted),
              const SizedBox(height: AppTokens.space16),
              Text(
                _isBengali ? 'কোন ফর্ম ডেটা লোড করা হয়নি' : 'No Form Data Loaded',
                style: AppTokens.titleMedium,
              ),
              const SizedBox(height: AppTokens.space8),
              ElevatedButton(
                onPressed: () => setState(() => _viewState = DynamicFormViewState.loaded),
                style: ElevatedButton.styleFrom(backgroundColor: AppTokens.primaryTeal),
                child: Text(_isBengali ? 'নতুন ফর্ম খুলুন' : 'Initialize New Form'),
              ),
            ],
          ),
        );

      case DynamicFormViewState.loaded:
      case DynamicFormViewState.error:
      case DynamicFormViewState.offline:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isOffline || _viewState == DynamicFormViewState.offline) _buildOfflineBadge(),
              if (_statusBannerMessage.isNotEmpty) _buildStatusBanner(),
              if (_errors.isNotEmpty) _buildErrorCard(),
              _buildDosageFormSelectorCard(),
              _buildGeneralIdentificationCard(),
              _buildFormSpecificParametersCard(),
              _buildPackagingDimensionsCard(),
              _buildStorageAndColdChainCard(),
              _buildFinancialPricingCard(),
              const SizedBox(height: AppTokens.space24),
              _buildActionButtons(),
            ],
          ),
        );
    }
  }

  Widget _buildOfflineBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.space12),
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space12, vertical: AppTokens.space8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
        border: Border.all(color: AppTokens.warningAmber),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.wifi_slash, color: AppTokens.warningAmber, size: 20),
          const SizedBox(width: AppTokens.space8),
          Expanded(
            child: Text(
              _isBengali
                  ? 'অফলাইন মোড সক্রিয়: স্থানীয় ক্যাশ ব্যবহার করে ভ্যালিডেশন করা হচ্ছে।'
                  : 'Offline Mode Active: Local engine preserves form state and validates without duplication.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isErr = _viewState == DynamicFormViewState.error;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.space12),
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: isErr ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
        border: Border.all(color: isErr ? AppTokens.dangerRed : AppTokens.successGreen),
      ),
      child: Text(
        _statusBannerMessage,
        style: TextStyle(
          color: isErr ? AppTokens.dangerRed : AppTokens.successGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.space16),
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: AppTokens.dangerRed, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: AppTokens.dangerRed, size: 20),
              const SizedBox(width: AppTokens.space8),
              Text(
                _isBengali ? 'ত্রুটির তালিকা (${_errors.length})' : 'Validation Errors (${_errors.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTokens.dangerRed),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          ..._errors.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  '• ${_isBengali ? e.messageBn : e.messageEn}',
                  style: const TextStyle(fontSize: 13, color: AppTokens.dangerRed),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildDosageFormSelectorCard() {
    return Card(
      color: AppTokens.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        side: const BorderSide(color: AppTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isBengali ? 'ডোজ ফর্ম নির্বাচন' : 'Dosage Form Family',
              style: AppTokens.titleMedium,
            ),
            const SizedBox(height: AppTokens.space8),
            DropdownButtonFormField<String>(
              key: const Key('dosage_form_dropdown'),
              initialValue: _engine.currentDosageForm,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.space12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.buttonRadius)),
              ),
              items: _dosageForms.map((item) {
                return DropdownMenuItem<String>(
                  value: item['code'],
                  child: Text(_isBengali ? item['bn']! : item['en']!),
                );
              }).toList(),
              onChanged: (newVal) {
                if (newVal != null && newVal != _engine.currentDosageForm) {
                  _handleDosageFormSwitch(newVal);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralIdentificationCard() {
    return _buildSectionCard(
      title: _isBengali ? 'সাধারণ পণ্যের পরিচিতি' : 'General Product Identification',
      icon: CupertinoIcons.info_circle,
      children: [
        _buildTextField('brand_name', _isBengali ? 'ব্র্যান্ডের নাম' : 'Brand Name', isMandatory: true),
        _buildTextField('generic_name', _isBengali ? 'জেনেরিক নাম' : 'Generic Name', isMandatory: true),
        _buildTextField('dar_number', _isBengali ? 'ডিএআর নম্বর' : 'DAR Registration No', isMandatory: true),
      ],
    );
  }

  Widget _buildFormSpecificParametersCard() {
    final form = _engine.currentDosageForm;
    List<Widget> fields = [];

    if (form == 'INHALER') {
      fields = [
        _buildTextField('dose_per_actuation', _isBengali ? 'প্রতি পাফে মাত্রা' : 'Dose per Actuation', isMandatory: true),
        _buildTextField('actuations_per_device', _isBengali ? 'মোট পাফ সংখ্যা' : 'Actuations per Inhaler', isMandatory: true, isNumeric: true),
      ];
    } else if (form == 'DROPS') {
      fields = [
        _buildTextField('volume_ml', _isBengali ? 'বোতলের আয়তন (মিলি)' : 'Volume (mL)', isMandatory: true, isNumeric: true),
        _buildTextField('drop_category', _isBengali ? 'ড্রপের ধরণ' : 'Drop Category', isMandatory: true),
      ];
    } else if (form == 'TOPICAL_CREAM') {
      fields = [
        _buildTextField('tube_size_grams', _isBengali ? 'টিউবের ওজন (গ্রাম)' : 'Tube Size (g)', isMandatory: true, isNumeric: true),
        _buildTextField('application_site', _isBengali ? 'ব্যবহারের স্থান' : 'Application Site', isMandatory: true),
      ];
    } else if (form == 'SACHET_POWDER') {
      fields = [
        _buildTextField('grams_per_sachet', _isBengali ? 'প্রতি স্যাশের ওজন (গ্রাম)' : 'Weight per Sachet (g)', isMandatory: true, isNumeric: true),
        _buildTextField('sachets_per_pack', _isBengali ? 'প্যাকে স্যাশের সংখ্যা' : 'Sachets per Pack', isMandatory: true, isNumeric: true),
      ];
    } else if (form == 'SUPPOSITORY') {
      fields = [
        _buildTextField('piece_count', _isBengali ? 'পিস সংখ্যা' : 'Piece Count', isMandatory: true, isNumeric: true),
        _buildTextField('administration_route', _isBengali ? 'প্রয়োগ রুট' : 'Administration Route', isMandatory: true),
      ];
    } else if (form == 'DEVICE_CONSUMABLE') {
      fields = [
        _buildTextField('device_type', _isBengali ? 'ডিভাইসের ধরণ' : 'Device Type', isMandatory: true),
      ];
    }

    if (fields.isEmpty) return const SizedBox.shrink();

    return _buildSectionCard(
      title: _isBengali ? 'ফর্মুলেশনের নির্দিষ্ট বিবরণ' : 'Formulation Specifications',
      icon: CupertinoIcons.slider_horizontal_3,
      children: fields,
    );
  }

  Widget _buildPackagingDimensionsCard() {
    final form = _engine.currentDosageForm;
    if (form != 'TABLET_CAPSULE' && form != 'SACHET_POWDER') {
      return const SizedBox.shrink();
    }

    return _buildSectionCard(
      title: _isBengali ? 'প্যাকেজিং অনুপাত' : 'Packaging Dimensions',
      icon: CupertinoIcons.cube_box,
      children: [
        _buildTextField('pieces_per_strip', _isBengali ? 'প্রতি পাতায় পিস' : 'Pieces per Strip', isNumeric: true),
        _buildTextField('strips_per_pack', _isBengali ? 'প্যাকে পাতার সংখ্যা' : 'Strips per Pack', isNumeric: true),
        _buildTextField('total_pieces_per_pack', _isBengali ? 'প্যাকে মোট পিস' : 'Total Pieces per Pack', isNumeric: true),
      ],
    );
  }

  Widget _buildStorageAndColdChainCard() {
    return _buildSectionCard(
      title: _isBengali ? 'সংরক্ষণ ও তাপমাত্রা' : 'Storage & Cold Chain',
      icon: CupertinoIcons.thermometer,
      children: [
        _buildTextField('storage_temperature_celsius_min', _isBengali ? 'সর্বনিম্ন তাপমাত্রা (°সে)' : 'Min Temp (°C)', isNumeric: true),
        _buildTextField('storage_temperature_celsius_max', _isBengali ? 'সর্বোচ্চ তাপমাত্রা (°সে)' : 'Max Temp (°C)', isNumeric: true),
      ],
    );
  }

  Widget _buildFinancialPricingCard() {
    return _buildSectionCard(
      title: _isBengali ? 'মূল্য ও এমআরপি' : 'Financial Pricing & MRP',
      icon: CupertinoIcons.money_dollar_circle,
      children: [
        _buildTextField('cost_unit', _isBengali ? 'ক্রয়মূল্য (টাকা)' : 'Unit Cost Price (BDT)', isMandatory: true, isNumeric: true),
        _buildTextField('mrp_unit', _isBengali ? 'খুচরা মূল্য (এমআরপি)' : 'Maximum Retail Price (MRP)', isMandatory: true, isNumeric: true),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      color: AppTokens.cardSurface,
      margin: const EdgeInsets.only(top: AppTokens.space12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        side: const BorderSide(color: AppTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTokens.primaryTeal),
                const SizedBox(width: AppTokens.space8),
                Text(title, style: AppTokens.titleMedium),
              ],
            ),
            const Divider(height: AppTokens.space24, color: AppTokens.borderSubtle),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String fieldName,
    String label, {
    bool isMandatory = false,
    bool isNumeric = false,
  }) {
    final ctrl = _getController(fieldName);
    final hasErr = _errors.any((e) => e.fieldName == fieldName);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMandatory ? '$label *' : label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTokens.textPrimary),
          ),
          const SizedBox(height: 4),
          TextFormField(
            key: Key('field_$fieldName'),
            controller: ctrl,
            keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.space12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.buttonRadius)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
                borderSide: BorderSide(color: hasErr ? AppTokens.dangerRed : AppTokens.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
                borderSide: BorderSide(color: hasErr ? AppTokens.dangerRed : AppTokens.primaryTeal, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            key: const Key('btn_validate_save'),
            onPressed: _handleValidateAndSave,
            icon: const Icon(CupertinoIcons.checkmark_circle, color: Colors.white),
            label: Text(
              _isBengali ? 'যাচাই ও সংরক্ষণ' : 'Validate & Save',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.primaryTeal,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.buttonRadius)),
            ),
          ),
        ),
      ],
    );
  }
}
