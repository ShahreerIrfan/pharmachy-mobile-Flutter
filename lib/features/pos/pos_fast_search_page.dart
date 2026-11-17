// pos_fast_search_page.dart
// Architecture Decision: ADR-0222 (P222)
// Restrained Apple/Cupertino-inspired mobile POS fast search & barcode cart screen.
// Zero-emoji policy: strictly uses platform Icons and CupertinoIcons.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/sales/mobile_pos_domain_client.dart';
import '../../core/sales/mobile_pos_search_cart_client.dart';
import '../../core/theme/tokens.dart';

class _LocalCartEntry {
  final MobileFastSearchCandidate candidate;
  final MobilePackagingOption option;
  final int quantity;
  final String? serverLineId;

  const _LocalCartEntry({
    required this.candidate,
    required this.option,
    required this.quantity,
    this.serverLineId,
  });

  double get lineTotalBdt => (double.tryParse(option.unitPriceBdt) ?? 0.0) * quantity;
}

class _OfflineHeldBasket {
  final String saleId;
  final String holdReference;
  final String holdNote;
  final int holdTtlMinutes;
  final List<_LocalCartEntry> entries;
  final String discountType;
  final int discountInputBasis;
  final String discountText;
  final String roundingMode;
  final String grandTotalBdt;
  final String heldAtIso;

  const _OfflineHeldBasket({
    required this.saleId,
    required this.holdReference,
    this.holdNote = '',
    required this.holdTtlMinutes,
    required this.entries,
    required this.discountType,
    required this.discountInputBasis,
    required this.discountText,
    required this.roundingMode,
    required this.grandTotalBdt,
    required this.heldAtIso,
  });

  MobileHeldCartEntry toHeldEntry({required String branchId}) {
    return MobileHeldCartEntry(
      saleId: saleId,
      orderNumber: 'LOCAL-$saleId',
      branchId: branchId,
      holdReference: holdReference,
      holdNote: holdNote,
      heldAt: heldAtIso,
      holdExpiresAt: holdTtlMinutes > 0
          ? DateTime.now().add(Duration(minutes: holdTtlMinutes)).toUtc().toIso8601String()
          : null,
      holdStockReserved: false,
      lineCount: entries.length,
      heldGrandTotalBdt: grandTotalBdt,
      liveGrandTotalBdt: grandTotalBdt,
      lifecycleState: MobilePosLifecycleState.held,
      offlineLocalOnly: true,
    );
  }
}

class _HoldDialogInput {
  final String holdReference;
  final String holdNote;
  final int holdTtlMinutes;
  final bool reserveStock;

  const _HoldDialogInput({
    required this.holdReference,
    required this.holdNote,
    required this.holdTtlMinutes,
    required this.reserveStock,
  });
}

class _HoldCartDialog extends StatefulWidget {
  final bool isBangla;
  final String initialReference;

  const _HoldCartDialog({
    required this.isBangla,
    required this.initialReference,
  });

  @override
  State<_HoldCartDialog> createState() => _HoldCartDialogState();
}

class _HoldCartDialogState extends State<_HoldCartDialog> {
  late final TextEditingController _refController;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _ttlController = TextEditingController(text: '120');
  bool _reserveStock = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _refController = TextEditingController(text: widget.initialReference);
  }

  @override
  void dispose() {
    _refController.dispose();
    _noteController.dispose();
    _ttlController.dispose();
    super.dispose();
  }

  void _submit() {
    final parsedTtl = int.tryParse(_ttlController.text.trim());
    if (parsedTtl == null || parsedTtl < 1 || parsedTtl > 1440) {
      setState(() {
        _validationError = widget.isBangla
            ? 'হোল্ডের মেয়াদ ১ থেকে ১৪৪০ মিনিটের মধ্যে হতে হবে।'
            : 'Hold TTL must be between 1 and 1440 minutes.';
      });
      return;
    }
    Navigator.of(context).pop(
      _HoldDialogInput(
        holdReference: _refController.text.trim(),
        holdNote: _noteController.text.trim(),
        holdTtlMinutes: parsedTtl,
        reserveStock: _reserveStock,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isBangla ? 'কার্ট হোল্ড করুন' : 'Hold Current Cart'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              key: const Key('pos_hold_ref_input'),
              controller: _refController,
              decoration: InputDecoration(
                labelText: widget.isBangla ? 'রেফারেন্স / গ্রাহকের নাম' : 'Hold Reference / Customer',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTokens.space12),
            TextField(
              key: const Key('pos_hold_note_input'),
              controller: _noteController,
              decoration: InputDecoration(
                labelText: widget.isBangla ? 'নোট (ঐচ্ছিক)' : 'Hold Note (optional)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTokens.space12),
            TextField(
              key: const Key('pos_hold_ttl_input'),
              controller: _ttlController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.isBangla ? 'মেয়াদ (মিনিট, ১-১৪৪০)' : 'Hold TTL (minutes, 1-1440)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTokens.space8),
            CheckboxListTile(
              key: const Key('pos_reserve_hold_check'),
              contentPadding: EdgeInsets.zero,
              value: _reserveStock,
              onChanged: (v) => setState(() => _reserveStock = v ?? false),
              title: Text(
                widget.isBangla ? 'হোল্ড স্টক রিজার্ভ করুন (FEFO)' : 'Reserve Batch Stock (FEFO)',
                style: AppTokens.bodyRegular,
              ),
            ),
            if (_validationError != null) ...<Widget>[
              const SizedBox(height: AppTokens.space4),
              Text(
                _validationError!,
                style: AppTokens.captionMuted.copyWith(color: AppTokens.dangerRed),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.isBangla ? 'বাতিল' : 'Cancel'),
        ),
        ElevatedButton(
          key: const Key('pos_confirm_hold_btn'),
          onPressed: _submit,
          child: Text(widget.isBangla ? 'হোল্ড করুন' : 'Park Cart'),
        ),
      ],
    );
  }
}

class _DeliveryDialogInput {
  final String fulfillmentMode;
  final String deliveryMethod;
  final String recipientName;
  final String recipientPhone;
  final String addressLine;
  final String area;
  final String feeBdt;
  final bool reserveStock;

  const _DeliveryDialogInput({
    required this.fulfillmentMode,
    required this.deliveryMethod,
    required this.recipientName,
    required this.recipientPhone,
    required this.addressLine,
    required this.area,
    required this.feeBdt,
    required this.reserveStock,
  });
}

class _CreateDeliveryDialog extends StatefulWidget {
  final bool isBangla;

  const _CreateDeliveryDialog({required this.isBangla});

  @override
  State<_CreateDeliveryDialog> createState() => _CreateDeliveryDialogState();
}

class _CreateDeliveryDialogState extends State<_CreateDeliveryDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _feeController = TextEditingController(text: '60.00');
  String _mode = 'HOME_DELIVERY';
  bool _reserveStock = true;
  String? _validationError;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _areaController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final feeStr = _feeController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() {
        _validationError = widget.isBangla
            ? 'প্রাপকের নাম ও ফোন নম্বর দিন।'
            : 'Recipient name and phone are required.';
      });
      return;
    }
    if (_mode == 'HOME_DELIVERY' && address.isEmpty) {
      setState(() {
        _validationError = widget.isBangla
            ? 'হোম ডেলিভারির জন্য পূর্ণ ঠিকানা দিন।'
            : 'Street address is required for Home Delivery.';
      });
      return;
    }
    final parsedFee = feeStr.isEmpty ? 0.0 : double.tryParse(feeStr);
    if (parsedFee == null || parsedFee < 0) {
      setState(() {
        _validationError = widget.isBangla
            ? 'সঠিক সংখ্যাসূচক ডেলিভারি ফি লিখুন।'
            : 'Enter a valid non-negative delivery fee.';
      });
      return;
    }
    final method = _mode == 'PREORDER_PICKUP'
        ? 'BRANCH_PICKUP'
        : (_mode == 'COURIER_PARCEL' ? 'THIRD_PARTY_COURIER' : 'OWN_RIDER');
    Navigator.of(context).pop(
      _DeliveryDialogInput(
        fulfillmentMode: _mode,
        deliveryMethod: method,
        recipientName: name,
        recipientPhone: phone,
        addressLine: address,
        area: _areaController.text.trim(),
        feeBdt: parsedFee.toStringAsFixed(2),
        reserveStock: _reserveStock,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isBangla ? 'প্রি-অর্ডার / ডেলিভারি তৈরি' : 'Create Preorder / Delivery'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DropdownButtonFormField<String>(
              key: const Key('pos_dlv_mode_dropdown'),
              initialValue: _mode,
              decoration: InputDecoration(
                labelText: widget.isBangla ? 'অর্ডারের ধরন' : 'Fulfillment Mode',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'HOME_DELIVERY', child: Text('HOME_DELIVERY')),
                DropdownMenuItem(value: 'PREORDER_PICKUP', child: Text('PREORDER_PICKUP')),
                DropdownMenuItem(value: 'COURIER_PARCEL', child: Text('COURIER_PARCEL')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _mode = v);
              },
            ),
            const SizedBox(height: AppTokens.space8),
            TextField(
              key: const Key('pos_dlv_recipient_input'),
              controller: _nameController,
              decoration: InputDecoration(
                labelText: widget.isBangla ? 'প্রাপকের নাম' : 'Recipient Name',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppTokens.space8),
            TextField(
              key: const Key('pos_dlv_phone_input'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: widget.isBangla ? 'ফোন (017...)' : 'Phone (017...)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppTokens.space8),
            TextField(
              key: const Key('pos_dlv_address_input'),
              controller: _addressController,
              decoration: InputDecoration(
                labelText: widget.isBangla ? 'সড়ক / বাসার ঠিকানা' : 'Street Address',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppTokens.space8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('pos_dlv_area_input'),
                    controller: _areaController,
                    decoration: InputDecoration(
                      labelText: widget.isBangla ? 'এলাকা' : 'Area',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
                SizedBox(
                  width: 110,
                  child: TextField(
                    key: const Key('pos_dlv_fee_input'),
                    controller: _feeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: widget.isBangla ? 'ফি (টাকা)' : 'Fee BDT',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              key: const Key('pos_dlv_reserve_check'),
              value: _reserveStock,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                widget.isBangla ? 'ব্যাচ স্টক সংরক্ষণ করুন' : 'Reserve batch stock (FEFO)',
                style: AppTokens.captionMuted,
              ),
              onChanged: (v) => setState(() => _reserveStock = v ?? true),
            ),
            if (_validationError != null) ...<Widget>[
              const SizedBox(height: AppTokens.space4),
              Text(
                _validationError!,
                style: AppTokens.captionMuted.copyWith(color: AppTokens.dangerRed),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.isBangla ? 'বাতিল' : 'Cancel'),
        ),
        ElevatedButton(
          key: const Key('pos_confirm_create_dlv_btn'),
          onPressed: _submit,
          child: Text(widget.isBangla ? 'নিশ্চিত করুন' : 'Create Order'),
        ),
      ],
    );
  }
}

class PosFastSearchPage extends StatefulWidget {
  final MobilePosSearchCartClient client;
  final String bearerToken;
  final String actorRole;
  final String actorTenantId;
  final String actorBranchId;
  final String targetTenantId;
  final String targetBranchId;
  final bool initialBangla;
  final bool isOffline;
  final bool subscriptionSuspended;

  const PosFastSearchPage({
    super.key,
    required this.client,
    required this.bearerToken,
    required this.actorRole,
    required this.actorTenantId,
    required this.actorBranchId,
    required this.targetTenantId,
    required this.targetBranchId,
    this.initialBangla = false,
    this.isOffline = false,
    this.subscriptionSuspended = false,
  });

  @override
  State<PosFastSearchPage> createState() => _PosFastSearchPageState();
}

class _PosFastSearchPageState extends State<PosFastSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _discountValueController = TextEditingController();
  final TextEditingController _rxDoctorNameController = TextEditingController();
  final TextEditingController _rxDoctorBmdcController = TextEditingController();
  final TextEditingController _rxPatientController = TextEditingController();
  final TextEditingController _rxRefController = TextEditingController();
  final TextEditingController _rxPcbController = TextEditingController();
  final TextEditingController _rxNotesController = TextEditingController();
  final TextEditingController _fefoOverrideBatchController = TextEditingController();
  final TextEditingController _fefoOverrideReasonController = TextEditingController();
  final TextEditingController _splitAmountController = TextEditingController();
  final TextEditingController _splitRefController = TextEditingController();
  final TextEditingController _splitPayerController = TextEditingController();
  final TextEditingController _closeCountedCashController = TextEditingController();
  final TextEditingController _closeNotesController = TextEditingController();
  final TextEditingController _dueCollectAmountController = TextEditingController();
  final TextEditingController _dueCollectRefController = TextEditingController();
  late bool _isBangla;
  late bool _isOffline;
  MobilePosUiState _uiState = MobilePosUiState.empty;
  String _statusMessageEn = 'Scan barcode or search medicine brand/generic.';
  String _statusMessageBn = 'বারকোড স্ক্যান করুন অথবা ওষুধের নাম লিখে সার্চ করুন।';
  List<MobileFastSearchCandidate> _results = const <MobileFastSearchCandidate>[];
  final List<_LocalCartEntry> _cart = <_LocalCartEntry>[];
  final Map<String, MobilePackagingOption> _selectedCandidateUnit = <String, MobilePackagingOption>{};
  String? _activeSaleId;
  MobilePosSaleOrder? _serverSaleOrder;
  int _cartVersion = 1;
  String _discountType = 'NONE';
  int _discountInputBasis = 0; // rate x100 (bps) for PERCENTAGE or paisa for FLAT_BDT
  String _roundingMode = 'NONE';
  final List<_OfflineHeldBasket> _offlineHeldBaskets = <_OfflineHeldBasket>[];
  List<MobileHeldCartEntry> _heldCarts = const <MobileHeldCartEntry>[];
  int _heldCartCount = 0;
  int _offlineHoldSeq = 1;
  MobileHeldCartEntry? _pendingStaleEntry;
  MobileHeldCartStaleness? _pendingStaleStaleness;
  bool _loadingHeld = false;
  MobilePosUiState? _heldSheetState;
  String? _heldSheetMessageEn;
  String? _heldSheetMessageBn;
  final List<MobilePosDeliveryOrder> _offlineDeliveries = <MobilePosDeliveryOrder>[];
  List<MobilePosDeliveryOrder> _deliveryOrders = const <MobilePosDeliveryOrder>[];
  int _deliveryCount = 0;
  int _offlineDlvSeq = 1;
  bool _loadingDeliveries = false;
  MobilePosUiState? _deliverySheetState;
  String? _deliverySheetMessageEn;
  String? _deliverySheetMessageBn;
  MobileRxGateStatus? _rxGateStatusCache;
  List<MobileAntibioticRegisterEntry> _abxRegisterEntries = const <MobileAntibioticRegisterEntry>[];
  int _abxRegisterCount = 0;
  bool _loadingRxGate = false;
  MobilePosUiState? _rxSheetState;
  String? _rxSheetMessageEn;
  String? _rxSheetMessageBn;
  MobileFefoAllocationPlan? _fefoPlanCache;
  bool _loadingFefo = false;
  MobilePosUiState? _fefoSheetState;
  String? _fefoSheetMessageEn;
  String? _fefoSheetMessageBn;
  Map<String, String> _fefoBatchOverrides = <String, String>{};
  String _fefoOverrideReason = '';
  String _splitTenderType = 'CASH';
  final List<MobileSplitPaymentInput> _stagedSplits = <MobileSplitPaymentInput>[];
  MobileCashierCloseReconciliation? _closeReconCache;
  bool _loadingSplitPay = false;
  MobilePosUiState? _splitSheetState;
  String? _splitSheetMessageEn;
  String? _splitSheetMessageBn;
  List<MobilePosCustomer> _cachedCustomers = const <MobilePosCustomer>[];
  MobilePosCustomer? _activeCustomer;
  List<MobileCustomerDueRecord> _cachedCustomerDues = const <MobileCustomerDueRecord>[];
  MobileCustomerDueRecord? _selectedDueRecord;
  String _dueCollectTender = 'CASH';

  static const Set<String> _posWriteRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'STAFF_PHARMACIST',
    'CASHIER',
  };

  @override
  void initState() {
    super.initState();
    _isBangla = widget.initialBangla;
    _isOffline = widget.isOffline;
    if (_isOffline) {
      _uiState = MobilePosUiState.offline;
      _statusMessageEn = MobilePosUiState.offline.messageEn;
      _statusMessageBn = MobilePosUiState.offline.messageBn;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _discountValueController.dispose();
    _rxDoctorNameController.dispose();
    _rxDoctorBmdcController.dispose();
    _rxPatientController.dispose();
    _rxRefController.dispose();
    _rxPcbController.dispose();
    _rxNotesController.dispose();
    _fefoOverrideBatchController.dispose();
    _fefoOverrideReasonController.dispose();
    _splitAmountController.dispose();
    _splitRefController.dispose();
    _splitPayerController.dispose();
    _closeCountedCashController.dispose();
    _closeNotesController.dispose();
    _dueCollectAmountController.dispose();
    _dueCollectRefController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _uiState = MobilePosUiState.loading;
      _statusMessageEn = MobilePosUiState.loading.messageEn;
      _statusMessageBn = MobilePosUiState.loading.messageBn;
    });

    final res = await widget.client.fastSearch(
      query: query,
      bearerToken: widget.bearerToken,
      actorRole: widget.actorRole,
      actorTenantId: widget.actorTenantId,
      actorBranchId: widget.actorBranchId,
      targetTenantId: widget.targetTenantId,
      targetBranchId: widget.targetBranchId,
      isOffline: _isOffline,
      subscriptionSuspended: widget.subscriptionSuspended,
    );
    if (!mounted) return;
    setState(() {
      _uiState = res.uiState;
      _statusMessageEn = res.messageEn;
      _statusMessageBn = res.messageBn;
      _results = res.data?.results ?? const <MobileFastSearchCandidate>[];
    });
  }

  MobilePackagingOption _resolveChosenOption(MobileFastSearchCandidate candidate, [MobilePackagingOption? explicitOpt]) {
    if (explicitOpt != null) return explicitOpt;
    final selected = _selectedCandidateUnit[candidate.productId];
    if (selected != null) return selected;
    return candidate.packagingOptions.firstWhere(
      (o) => o.packagingUnit == candidate.resolvedPackagingUnit,
      orElse: () => candidate.packagingOptions.firstWhere(
        (o) => o.isAllowed,
        orElse: () => candidate.packagingOptions.isNotEmpty
            ? candidate.packagingOptions.first
            : MobilePackagingOption(
                packagingUnit: candidate.resolvedPackagingUnit,
                labelEn: candidate.resolvedPackagingUnit,
                labelBn: candidate.resolvedPackagingUnit,
                conversionFactor: candidate.resolvedConversionFactor,
                unitPriceBdt: candidate.unitPriceBdt,
              ),
      ),
    );
  }

  void _showOptionBlocked(MobilePackagingOption opt) {
    setState(() {
      _uiState = opt.requiresPharmacistApproval ? MobilePosUiState.permissionDenied : MobilePosUiState.error;
      _statusMessageEn = opt.blockReasonEn.isNotEmpty
          ? opt.blockReasonEn
          : 'Container policy restricts ${opt.packagingUnit}.';
      _statusMessageBn = opt.blockReasonBn.isNotEmpty
          ? opt.blockReasonBn
          : 'কনটেইনার নীতি অনুযায়ী ${opt.packagingUnit} অনুমোদিত নয়।';
    });
  }

  Future<void> _addCandidate(MobileFastSearchCandidate candidate, [MobilePackagingOption? explicitOpt]) async {
    if (!candidate.isSellable || candidate.availableBaseUnits <= 0) {
      setState(() {
        _uiState = MobilePosUiState.error;
        _statusMessageEn = 'Blocked: ${candidate.brandName} (${candidate.blockReason}).';
        _statusMessageBn = 'ব্লকড: ${candidate.brandName} বিক্রি করা যাবে না।';
      });
      return;
    }
    final chosenOpt = _resolveChosenOption(candidate, explicitOpt);
    if (!chosenOpt.isAllowed) {
      _showOptionBlocked(chosenOpt);
      return;
    }

    final currentBaseForProduct = _cart
        .where((e) => e.candidate.productId == candidate.productId)
        .fold<int>(0, (sum, e) => sum + (e.quantity * e.option.conversionFactor));
    if (currentBaseForProduct + chosenOpt.conversionFactor > candidate.availableBaseUnits) {
      setState(() {
        _uiState = MobilePosUiState.error;
        _statusMessageEn = 'Insufficient FEFO sellable stock (${candidate.availableBaseUnits}u available).';
        _statusMessageBn = 'পর্যাপ্ত বিক্রয়যোগ্য FEFO স্টক নেই (মজুদ: ${candidate.availableBaseUnits}টি)।';
      });
      return;
    }

    String? matchedServerLineId;
    if (!_isOffline && widget.bearerToken.isNotEmpty) {
      if (_activeSaleId == null) {
        final openRes = await widget.client.openQuickCart(
          targetBranchId: widget.targetBranchId,
          bearerToken: widget.bearerToken,
        );
        if (openRes.data != null) {
          _activeSaleId = openRes.data!.saleId;
          _cartVersion = openRes.data!.version;
        } else if (openRes.uiState == MobilePosUiState.permissionDenied ||
            openRes.uiState == MobilePosUiState.error) {
          if (!mounted) return;
          setState(() {
            _uiState = openRes.uiState;
            _statusMessageEn = openRes.messageEn;
            _statusMessageBn = openRes.messageBn;
          });
          return;
        }
      }
      if (_activeSaleId != null) {
        final addRes = await widget.client.scanAdd(
          saleId: _activeSaleId!,
          bearerToken: widget.bearerToken,
          barcode: candidate.barcode.isNotEmpty ? candidate.barcode : candidate.skuCode,
          productId: candidate.productId,
          variantId: candidate.variantId,
          packagingUnit: chosenOpt.packagingUnit,
          quantityDelta: 1,
          expectedVersion: _cartVersion,
        );
        if (addRes.uiState == MobilePosUiState.error || addRes.uiState == MobilePosUiState.permissionDenied) {
          if (!mounted) return;
          setState(() {
            _uiState = addRes.uiState;
            _statusMessageEn = addRes.messageEn;
            _statusMessageBn = addRes.messageBn;
          });
          return;
        }
        if (addRes.data != null) {
          _serverSaleOrder = addRes.data;
          _cartVersion = addRes.data!.version;
          for (final l in addRes.data!.lines) {
            if (l.productId == candidate.productId && l.packagingUnit == chosenOpt.packagingUnit) {
              matchedServerLineId = l.lineId;
              break;
            }
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      final idx = _cart.indexWhere(
        (e) =>
            e.candidate.productId == candidate.productId &&
            e.option.packagingUnit == chosenOpt.packagingUnit,
      );
      if (idx >= 0) {
        final old = _cart[idx];
        _cart[idx] = _LocalCartEntry(
          candidate: old.candidate,
          option: old.option,
          quantity: old.quantity + 1,
          serverLineId: matchedServerLineId ?? old.serverLineId,
        );
      } else {
        _cart.add(
          _LocalCartEntry(
            candidate: candidate,
            option: chosenOpt,
            quantity: 1,
            serverLineId: matchedServerLineId,
          ),
        );
      }
      _uiState = _isOffline ? MobilePosUiState.offline : MobilePosUiState.ready;
      _statusMessageEn = 'Added ${candidate.brandName} (${chosenOpt.packagingUnit}, ${chosenOpt.conversionFactor}u base).';
      _statusMessageBn = '${candidate.brandName} (${chosenOpt.packagingUnit}) কার্টে যুক্ত হয়েছে।';
    });
  }

  Future<void> _selectCartUnit(int index, MobilePackagingOption targetOpt) async {
    if (index < 0 || index >= _cart.length) return;
    final item = _cart[index];
    if (!targetOpt.isAllowed) {
      _showOptionBlocked(targetOpt);
      return;
    }

    final otherBase = _cart
        .where((e) => e != item && e.candidate.productId == item.candidate.productId)
        .fold<int>(0, (sum, e) => sum + (e.quantity * e.option.conversionFactor));
    final neededBase = otherBase + (item.quantity * targetOpt.conversionFactor);
    if (neededBase > item.candidate.availableBaseUnits) {
      setState(() {
        _uiState = MobilePosUiState.error;
        _statusMessageEn =
            'Insufficient FEFO sellable stock for ${item.quantity} ${targetOpt.packagingUnit} (${neededBase}u > ${item.candidate.availableBaseUnits}u).';
        _statusMessageBn =
            '${targetOpt.packagingUnit} নেওয়ার মতো পর্যাপ্ত FEFO স্টক নেই (চাহিদা: $neededBase, মজুদ: ${item.candidate.availableBaseUnits})।';
      });
      return;
    }

    if (!_isOffline && widget.bearerToken.isNotEmpty && _activeSaleId != null && item.serverLineId != null) {
      final res = await widget.client.selectCartLineUnit(
        saleId: _activeSaleId!,
        bearerToken: widget.bearerToken,
        lineId: item.serverLineId,
        packagingUnit: targetOpt.packagingUnit,
        quantityUnits: item.quantity,
        expectedVersion: _cartVersion,
        actorRole: widget.actorRole,
        actorTenantId: widget.actorTenantId,
        actorBranchId: widget.actorBranchId,
        targetTenantId: widget.targetTenantId,
        targetBranchId: widget.targetBranchId,
        subscriptionSuspended: widget.subscriptionSuspended,
      );
      if (!mounted) return;
      if (res.uiState == MobilePosUiState.error || res.uiState == MobilePosUiState.permissionDenied) {
        setState(() {
          _uiState = res.uiState;
          _statusMessageEn = res.messageEn;
          _statusMessageBn = res.messageBn;
        });
        return;
      }
      if (res.data != null) {
        _serverSaleOrder = res.data;
        _cartVersion = res.data!.version;
        final updatedLine = res.data!.lines.firstWhere(
          (l) => l.lineId == item.serverLineId,
          orElse: () => res.data!.lines.first,
        );
        final syncedOpt = MobilePackagingOption(
          packagingUnit: updatedLine.packagingUnit,
          labelEn: targetOpt.labelEn,
          labelBn: targetOpt.labelBn,
          conversionFactor: updatedLine.conversionFactor,
          unitPriceBdt: updatedLine.unitPriceBdt,
          conversionSource: updatedLine.unitConversionSource,
          containerPolicyStatus: updatedLine.containerPolicyApplied,
          isAllowed: true,
        );
        setState(() {
          _cart[index] = _LocalCartEntry(
            candidate: item.candidate,
            option: syncedOpt,
            quantity: updatedLine.quantityUnits,
            serverLineId: updatedLine.lineId,
          );
          _uiState = MobilePosUiState.ready;
          _statusMessageEn =
              '${item.candidate.brandName} set to ${syncedOpt.packagingUnit} (${updatedLine.baseUnitsTotal}u base).';
          _statusMessageBn =
              '${item.candidate.brandName} পরিবর্তন করে ${syncedOpt.packagingUnit} (${updatedLine.baseUnitsTotal}টি বেস) করা হয়েছে।';
        });
        return;
      }
    }

    final nextBase = item.quantity * targetOpt.conversionFactor;
    setState(() {
      _cart[index] = _LocalCartEntry(
        candidate: item.candidate,
        option: targetOpt,
        quantity: item.quantity,
        serverLineId: item.serverLineId,
      );
      _uiState = _isOffline ? MobilePosUiState.offline : MobilePosUiState.ready;
      _statusMessageEn =
          '${item.candidate.brandName} set to ${targetOpt.packagingUnit} (${nextBase}u base).';
      _statusMessageBn =
          '${item.candidate.brandName} পরিবর্তন করে ${targetOpt.packagingUnit} ($nextBaseটি বেস) করা হয়েছে।';
    });
  }

  static int _parseToPaisa(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return 0;
    final neg = s.startsWith('-');
    final clean = neg ? s.substring(1) : (s.startsWith('+') ? s.substring(1) : s);
    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(clean);
    if (match == null) return 0;
    final whole = int.tryParse(match.group(1)!) ?? 0;
    final fracRaw = match.group(2) ?? '';
    final fracPadded = '${fracRaw}000'.substring(0, 3);
    var paisa = int.tryParse(fracPadded.substring(0, 2)) ?? 0;
    final thirdDigit = int.tryParse(fracPadded.substring(2, 3)) ?? 0;
    if (thirdDigit >= 5) {
      paisa += 1;
    }
    final total = whole * 100 + paisa;
    return neg ? -total : total;
  }

  static String _formatPaisa(int paisa) {
    final neg = paisa < 0;
    final absVal = paisa.abs();
    final whole = absVal ~/ 100;
    final frac = (absVal % 100).toString().padLeft(2, '0');
    return '${neg ? '-' : ''}$whole.$frac';
  }

  static int _computeLocalRoundingPaisa(int preRoundPaisa, String mode) {
    switch (mode) {
      case 'HALF_UP_WHOLE_BDT':
        final rem = preRoundPaisa % 100;
        final base = preRoundPaisa - rem;
        final rounded = rem >= 50 ? base + 100 : base;
        return rounded - preRoundPaisa;
      case 'FLOOR_WHOLE_BDT':
        final rounded = (preRoundPaisa ~/ 100) * 100;
        return rounded - preRoundPaisa;
      case 'NEAREST_FIVE_BDT':
        final rem = preRoundPaisa % 500;
        final base = preRoundPaisa - rem;
        final rounded = rem >= 250 ? base + 500 : base;
        return rounded - preRoundPaisa;
      default:
        return 0;
    }
  }

  ({
    int subtotalPaisa,
    int discountPaisa,
    int taxPaisa,
    int roundingAdjPaisa,
    int grandTotalPaisa,
    bool isConfirmed,
    String taxModeLabel,
  }) _resolvedTotals() {
    if (_serverSaleOrder != null && _cart.isNotEmpty) {
      final o = _serverSaleOrder!;
      return (
        subtotalPaisa: _parseToPaisa(o.subtotalBdt),
        discountPaisa: _parseToPaisa(o.discountAmountBdt),
        taxPaisa: _parseToPaisa(o.taxAmountBdt),
        roundingAdjPaisa: _parseToPaisa(o.roundingAdjustmentBdt),
        grandTotalPaisa: _parseToPaisa(o.grandTotalBdt),
        isConfirmed: o.isPricingConfirmed,
        taxModeLabel: '${o.taxMode == 'INCLUSIVE' ? 'INCL' : 'EXCL'} ${o.taxRatePct}%',
      );
    }

    var subtotal = 0;
    for (final entry in _cart) {
      final unitPaisa = _parseToPaisa(entry.option.unitPriceBdt);
      subtotal += unitPaisa * entry.quantity;
    }
    var discount = 0;
    if (_discountType == 'PERCENTAGE' && subtotal > 0) {
      discount = ((subtotal * _discountInputBasis) + 5000) ~/ 10000;
    } else if (_discountType == 'FLAT_BDT') {
      discount = _discountInputBasis > subtotal ? subtotal : _discountInputBasis;
    }
    final preRound = (subtotal - discount) < 0 ? 0 : (subtotal - discount);
    final roundAdj = _cart.isEmpty ? 0 : _computeLocalRoundingPaisa(preRound, _roundingMode);
    final grand = (preRound + roundAdj) < 0 ? 0 : (preRound + roundAdj);
    return (
      subtotalPaisa: subtotal,
      discountPaisa: discount,
      taxPaisa: 0,
      roundingAdjPaisa: roundAdj,
      grandTotalPaisa: grand,
      isConfirmed: false,
      taxModeLabel: 'EXCL 0.00%',
    );
  }

  void _adjustQty(int index, int delta) {
    final item = _cart[index];
    final nextQty = item.quantity + delta;
    if (nextQty <= 0) {
      setState(() {
        _cart.removeAt(index);
        _serverSaleOrder = null;
      });
      return;
    }
    if (delta > 0) {
      final currentBase = _cart
          .where((e) => e.candidate.productId == item.candidate.productId)
          .fold<int>(0, (sum, e) => sum + (e.quantity * e.option.conversionFactor));
      if (currentBase + item.option.conversionFactor > item.candidate.availableBaseUnits) {
        setState(() {
          _uiState = MobilePosUiState.error;
          _statusMessageEn = 'Insufficient FEFO sellable stock (${item.candidate.availableBaseUnits}u available).';
          _statusMessageBn = 'পর্যাপ্ত বিক্রয়যোগ্য FEFO স্টক নেই।';
        });
        return;
      }
    }
    setState(() {
      _serverSaleOrder = null;
      _cart[index] = _LocalCartEntry(
        candidate: item.candidate,
        option: item.option,
        quantity: nextQty,
        serverLineId: item.serverLineId,
      );
    });
  }

  Future<void> _applyPricing({String? nextDiscountType, String? nextRoundingMode}) async {
    if (_cart.isEmpty) {
      setState(() {
        _uiState = MobilePosUiState.empty;
        _statusMessageEn = 'Add at least one item before updating pricing.';
        _statusMessageBn = 'মূল্য সমন্বয়ের আগে কার্টে আইটেম যুক্ত করুন।';
      });
      return;
    }
    final dType = nextDiscountType ?? _discountType;
    final rMode = nextRoundingMode ?? _roundingMode;
    final rawTxt = _discountValueController.text.trim();
    int basis = 0;
    if (rawTxt.isNotEmpty) {
      if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(rawTxt)) {
        setState(() {
          _uiState = MobilePosUiState.error;
          _statusMessageEn = "Invalid discount number '$rawTxt'.";
          _statusMessageBn = "ভুল ডিসকাউন্ট মান '$rawTxt'।";
        });
        return;
      }
      basis = _parseToPaisa(rawTxt);
    }

    if (dType == 'PERCENTAGE' && basis > 10000) {
      setState(() {
        _uiState = MobilePosUiState.error;
        _statusMessageEn = 'Discount percentage cannot exceed 100%.';
        _statusMessageBn = 'শতাংশ ছাড় ১০০%-এর বেশি হতে পারবে না।';
      });
      return;
    }

    if (!_isOffline && widget.bearerToken.isNotEmpty && _activeSaleId != null) {
      final payload = <String, dynamic>{
        'discount_type': dType,
        if (dType == 'PERCENTAGE')
          'discount_rate_pct': _formatPaisa(basis)
        else if (dType == 'FLAT_BDT')
          'header_discount_amount_bdt': _formatPaisa(basis)
        else
          'header_discount_amount_bdt': '0.00',
        'rounding_mode': rMode,
        'expected_version': _cartVersion,
      };
      final res = await widget.client.updateCartPricing(
        saleId: _activeSaleId!,
        pricingPayload: payload,
        bearerToken: widget.bearerToken,
        actorRole: widget.actorRole,
        actorTenantId: widget.actorTenantId,
        actorBranchId: widget.actorBranchId,
        targetTenantId: widget.targetTenantId,
        targetBranchId: widget.targetBranchId,
        subscriptionSuspended: widget.subscriptionSuspended,
      );
      if (!mounted) return;
      if (res.uiState == MobilePosUiState.ready && res.data != null) {
        setState(() {
          _serverSaleOrder = res.data;
          _cartVersion = res.data!.version;
          _discountType = dType;
          _discountInputBasis = basis;
          _roundingMode = rMode;
          _uiState = MobilePosUiState.ready;
          _statusMessageEn = res.messageEn;
          _statusMessageBn = res.messageBn;
        });
      } else {
        setState(() {
          _uiState = res.uiState;
          _statusMessageEn = res.messageEn;
          _statusMessageBn = res.messageBn;
        });
      }
      return;
    }

    // Local preview + Cashier <= 5% ceiling check
    var subtotal = 0;
    for (final entry in _cart) {
      subtotal += _parseToPaisa(entry.option.unitPriceBdt) * entry.quantity;
    }
    var discPaisa = 0;
    if (dType == 'PERCENTAGE' && subtotal > 0) {
      discPaisa = ((subtotal * basis) + 5000) ~/ 10000;
    } else if (dType == 'FLAT_BDT') {
      if (basis > subtotal) {
        setState(() {
          _uiState = MobilePosUiState.error;
          _statusMessageEn = 'Discount exceeds cart subtotal.';
          _statusMessageBn = 'ছাড় উপ-মোটের চেয়ে বেশি হতে পারবে না।';
        });
        return;
      }
      discPaisa = basis;
    }
    final roundAdj = _computeLocalRoundingPaisa(subtotal - discPaisa, rMode);
    final negRound = roundAdj < 0 ? -roundAdj : 0;
    if (widget.actorRole.toUpperCase() == 'CASHIER' &&
        subtotal > 0 &&
        (discPaisa + negRound) * 100 > subtotal * 5) {
      setState(() {
        _uiState = MobilePosUiState.permissionDenied;
        _statusMessageEn = 'Cashiers cannot exceed 5% combined concession without Manager approval.';
        _statusMessageBn = 'ক্যাশিয়ার অনুমোদন ছাড়া ৫%-এর বেশি ছাড় বা নেগেটিভ রাউন্ডিং দিতে পারবেন না।';
      });
      return;
    }

    setState(() {
      _serverSaleOrder = null;
      _discountType = dType;
      _discountInputBasis = basis;
      _roundingMode = rMode;
      _uiState = _isOffline ? MobilePosUiState.offline : MobilePosUiState.ready;
      _statusMessageEn = _isOffline
          ? 'Offline preview totals updated (cloud confirmation required online).'
          : 'Cart totals recalculated.';
      _statusMessageBn = _isOffline
          ? 'অফলাইন প্রাক্কলিত মূল্য হালনাগাদ হয়েছে।'
          : 'কার্টের মোট মূল্য পুনর্গণনা হয়েছে।';
    });
  }

  Future<void> _confirmPricing() async {
    if (_cart.isEmpty) {
      setState(() {
        _uiState = MobilePosUiState.empty;
        _statusMessageEn = 'Cannot confirm pricing for an empty cart.';
        _statusMessageBn = 'খালি কার্টের মূল্য নিশ্চিত করা যাবে না।';
      });
      return;
    }
    if (_isOffline || widget.bearerToken.isEmpty || _activeSaleId == null) {
      setState(() {
        _uiState = MobilePosUiState.offline;
        _statusMessageEn = 'Offline mode: server pricing confirmation unavailable while disconnected.';
        _statusMessageBn = 'অফলাইন মোড: সংযোগ ছাড়া সার্ভার মূল্য নিশ্চিতকরণ সম্ভব নয়।';
      });
      return;
    }

    final res = await widget.client.confirmCartPricing(
      saleId: _activeSaleId!,
      bearerToken: widget.bearerToken,
      expectedGrandTotalBdt: _serverSaleOrder?.grandTotalBdt ?? _formatPaisa(_resolvedTotals().grandTotalPaisa),
      expectedPricingHash: _serverSaleOrder?.currentPricingHash,
      expectedVersion: _cartVersion,
      actorRole: widget.actorRole,
      actorTenantId: widget.actorTenantId,
      actorBranchId: widget.actorBranchId,
      targetTenantId: widget.targetTenantId,
      targetBranchId: widget.targetBranchId,
      subscriptionSuspended: widget.subscriptionSuspended,
    );
    if (!mounted) return;
    setState(() {
      if (res.uiState == MobilePosUiState.ready && res.data != null) {
        _serverSaleOrder = res.data;
        _cartVersion = res.data!.version;
      }
      _uiState = res.uiState;
      _statusMessageEn = res.messageEn;
      _statusMessageBn = res.messageBn;
    });
  }

  void _recomputeHeldCount() {
    final ids = <String>{};
    for (final b in _offlineHeldBaskets) {
      ids.add(b.saleId);
    }
    for (final h in _heldCarts) {
      ids.add(h.saleId);
    }
    _heldCartCount = ids.length;
  }

  List<MobileHeldCartEntry> _combinedHeldEntries() {
    final seen = <String>{};
    final combined = <MobileHeldCartEntry>[];
    for (final b in _offlineHeldBaskets) {
      if (seen.add(b.saleId)) {
        combined.add(b.toHeldEntry(branchId: widget.targetBranchId));
      }
    }
    for (final h in _heldCarts) {
      if (seen.add(h.saleId)) {
        combined.add(h);
      }
    }
    return combined;
  }

  void _clearActiveCartCounter() {
    _cart.clear();
    _activeSaleId = null;
    _serverSaleOrder = null;
    _cartVersion = 1;
    _discountType = 'NONE';
    _discountInputBasis = 0;
    _discountValueController.clear();
    _roundingMode = 'NONE';
  }

  void _restoreServerSaleToActiveCounter(MobilePosSaleOrder order) {
    _cart.clear();
    final cachedSnapshot = widget.client.getCachedSnapshot(widget.targetBranchId);
    for (final line in order.lines) {
      MobileFastSearchCandidate? matchedCandidate;
      for (final r in _results) {
        if (r.productId == line.productId) {
          matchedCandidate = r;
          break;
        }
      }
      if (matchedCandidate == null) {
        for (final c in cachedSnapshot) {
          if (c.productId == line.productId) {
            matchedCandidate = c;
            break;
          }
        }
      }
      final fallbackOpt = MobilePackagingOption(
        packagingUnit: line.packagingUnit,
        labelEn: line.packagingUnit,
        labelBn: line.packagingUnit,
        conversionFactor: line.conversionFactor > 0 ? line.conversionFactor : 1,
        unitPriceBdt: line.unitPriceBdt,
        conversionSource: line.unitConversionSource,
        containerPolicyStatus: line.containerPolicyApplied,
        isAllowed: true,
      );
      final candidate = matchedCandidate ??
          MobileFastSearchCandidate(
            productId: line.productId,
            skuCode: line.productId,
            displayName: line.productBrandName.isNotEmpty ? line.productBrandName : line.productId,
            brandName: line.productBrandName.isNotEmpty ? line.productBrandName : line.productId,
            brandNameBn: '',
            genericName: '',
            genericNameBn: '',
            strength: '',
            dosageForm: line.dosageFormSnapshot,
            barcode: '',
            shelfLocation: '',
            resolutionSource: 'HELD_RESUME',
            resolvedPackagingUnit: line.packagingUnit,
            resolvedConversionFactor: line.conversionFactor > 0 ? line.conversionFactor : 1,
            unitPriceBdt: line.unitPriceBdt,
            baseUnitPriceBdt: line.unitPriceBdt,
            sellableBaseUnits: 999999,
            reservedBaseUnits: 0,
            availableBaseUnits: 999999,
            quarantinedBaseUnits: 0,
            expiredBaseUnits: 0,
            recalledBaseUnits: 0,
            earliestBatchNumber: '',
            nearExpiryWarning: false,
            requiresRxVerification: line.requiresRxVerification,
            nonDivisibleSealedOnly: false,
            isSellable: true,
            blockReason: '',
            snapshotChecksum: '',
            rankScore: 100,
            packagingOptions: <MobilePackagingOption>[fallbackOpt],
          );
      var chosenOpt = fallbackOpt;
      for (final o in candidate.packagingOptions) {
        if (o.packagingUnit == line.packagingUnit) {
          chosenOpt = MobilePackagingOption(
            packagingUnit: o.packagingUnit,
            labelEn: o.labelEn,
            labelBn: o.labelBn,
            conversionFactor: line.conversionFactor > 0 ? line.conversionFactor : o.conversionFactor,
            unitPriceBdt: line.unitPriceBdt,
            conversionSource: o.conversionSource,
            containerPolicyStatus: o.containerPolicyStatus,
            isAllowed: true,
          );
          break;
        }
      }
      _cart.add(
        _LocalCartEntry(
          candidate: candidate,
          option: chosenOpt,
          quantity: line.quantityUnits > 0 ? line.quantityUnits : 1,
          serverLineId: line.lineId,
        ),
      );
    }
    _activeSaleId = order.saleId;
    _serverSaleOrder = order;
    _cartVersion = order.version;
    _discountType = order.discountType;
    _roundingMode = order.roundingMode;
    if (order.discountType == 'PERCENTAGE') {
      _discountInputBasis = _parseToPaisa(order.discountRatePct);
      _discountValueController.text = order.discountRatePct;
    } else if (order.discountType == 'FLAT_BDT') {
      _discountInputBasis = _parseToPaisa(order.headerDiscountAmountBdt);
      _discountValueController.text = order.headerDiscountAmountBdt;
    } else {
      _discountInputBasis = 0;
      _discountValueController.clear();
    }
  }

  MobileHeldCartEntry _buildHeldEntryFromServerOrder(MobilePosSaleOrder order) {
    return MobileHeldCartEntry(
      saleId: order.saleId,
      orderNumber: order.orderNumber,
      branchId: order.branchId,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      lifecycleState: order.lifecycleState,
      holdReference: order.holdReference.isNotEmpty ? order.holdReference : order.orderNumber,
      holdNote: order.holdNote,
      heldByEmail: order.heldByEmail,
      heldAt: order.heldAt,
      holdExpiresAt: order.holdExpiresAt,
      holdStockReserved: order.holdStockReserved,
      holdReservationExpiresAt: order.holdReservationExpiresAt,
      lineCount: order.lines.length,
      heldGrandTotalBdt: order.holdSnapshotGrandTotalBdt,
      liveGrandTotalBdt: order.grandTotalBdt,
      staleness: order.staleness ?? const MobileHeldCartStaleness(),
      version: order.version,
      sale: order,
    );
  }

  Future<void> _showHoldCartDialog() async {
    if (_cart.isEmpty) {
      setState(() {
        _uiState = MobilePosUiState.empty;
        _statusMessageEn = 'Cannot hold an empty cart.';
        _statusMessageBn = 'খালি কার্ট হোল্ড করা যাবে না।';
      });
      return;
    }
    final defaultRef = 'COUNTER-${_heldCartCount + 1}';
    final input = await showDialog<_HoldDialogInput>(
      context: context,
      builder: (_) => _HoldCartDialog(
        isBangla: _isBangla,
        initialReference: defaultRef,
      ),
    );
    if (input == null || !mounted) return;
    await _submitHoldCart(input);
  }

  Future<void> _submitHoldCart(_HoldDialogInput input) async {
    if (_cart.isEmpty) {
      setState(() {
        _uiState = MobilePosUiState.empty;
        _statusMessageEn = 'Cannot hold an empty cart.';
        _statusMessageBn = 'খালি কার্ট হোল্ড করা যাবে না।';
      });
      return;
    }

    final roleUpper = widget.actorRole.trim().toUpperCase();
    if (widget.subscriptionSuspended) {
      setState(() {
        _uiState = MobilePosUiState.permissionDenied;
        _statusMessageEn = 'Subscription suspended. POS hold actions locked.';
        _statusMessageBn = 'সাবস্ক্রিপশন স্থগিত। কার্ট হোল্ড করা যাবে না।';
      });
      return;
    }
    if (!_posWriteRoles.contains(roleUpper)) {
      setState(() {
        _uiState = MobilePosUiState.permissionDenied;
        _statusMessageEn = 'Role $roleUpper cannot hold or resume POS carts.';
        _statusMessageBn = '$roleUpper রোল-এর কার্ট হোল্ড করার অনুমতি নেই।';
      });
      return;
    }

    final canUseServer = !_isOffline &&
        widget.bearerToken.isNotEmpty &&
        _activeSaleId != null &&
        !_activeSaleId!.startsWith('offline-hold-');

    if (canUseServer) {
      final res = await widget.client.holdCart(
        saleId: _activeSaleId!,
        bearerToken: widget.bearerToken,
        actorRole: widget.actorRole,
        actorTenantId: widget.actorTenantId,
        actorBranchId: widget.actorBranchId,
        targetTenantId: widget.targetTenantId,
        targetBranchId: widget.targetBranchId,
        holdReference: input.holdReference,
        holdNote: input.holdNote,
        holdTtlMinutes: input.holdTtlMinutes,
        reserveStock: input.reserveStock,
        expectedVersion: _cartVersion,
        subscriptionSuspended: widget.subscriptionSuspended,
      );
      if (!mounted) return;
      if (res.uiState == MobilePosUiState.ready && res.data != null) {
        final parked = _buildHeldEntryFromServerOrder(res.data!);
        setState(() {
          _heldCarts = <MobileHeldCartEntry>[
            parked,
            ..._heldCarts.where((e) => e.saleId != parked.saleId),
          ];
          _clearActiveCartCounter();
          _pendingStaleEntry = null;
          _pendingStaleStaleness = null;
          _recomputeHeldCount();
          _uiState = MobilePosUiState.ready;
          _statusMessageEn = res.messageEn;
          _statusMessageBn = res.messageBn;
        });
        await _refreshHeldCarts(quiet: true);
        return;
      }
      if (res.uiState != MobilePosUiState.offline) {
        setState(() {
          _uiState = res.uiState;
          _statusMessageEn = res.messageEn;
          _statusMessageBn = res.messageBn;
        });
        return;
      }
    }

    final localId = 'offline-hold-${_offlineHoldSeq++}';
    final resolvedRef = input.holdReference.isEmpty ? 'LOCAL-$localId' : input.holdReference;
    final grandStr = _formatPaisa(_resolvedTotals().grandTotalPaisa);
    final basket = _OfflineHeldBasket(
      saleId: localId,
      holdReference: resolvedRef,
      holdNote: input.holdNote,
      holdTtlMinutes: input.holdTtlMinutes,
      entries: List<_LocalCartEntry>.from(_cart),
      discountType: _discountType,
      discountInputBasis: _discountInputBasis,
      discountText: _discountValueController.text,
      roundingMode: _roundingMode,
      grandTotalBdt: grandStr,
      heldAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    setState(() {
      _offlineHeldBaskets.insert(0, basket);
      _clearActiveCartCounter();
      _pendingStaleEntry = null;
      _pendingStaleStaleness = null;
      _recomputeHeldCount();
      _uiState = _isOffline ? MobilePosUiState.offline : MobilePosUiState.ready;
      _statusMessageEn = _isOffline
          ? 'Offline mode: basket parked locally ($resolvedRef; cloud stock NOT reserved).'
          : 'Basket parked locally ($resolvedRef). Counter is ready for next customer.';
      _statusMessageBn = _isOffline
          ? 'অফলাইন মোড: কার্ট লোকালে হোল্ড করা হয়েছে ($resolvedRef; ক্লাউড স্টক রিজার্ভ নয়)।'
          : 'কার্টটি হোল্ড করা হয়েছে ($resolvedRef)। পরবর্তী গ্রাহকের জন্য কাউন্টার প্রস্তুত।';
    });
  }

  Future<void> _refreshHeldCarts({
    bool quiet = false,
    void Function(VoidCallback)? sheetSetState,
  }) async {
    if (_isOffline || widget.bearerToken.isEmpty) {
      if (!mounted || quiet) return;
      final localCount = _offlineHeldBaskets.length;
      setState(() {
        _loadingHeld = false;
        _recomputeHeldCount();
        _heldSheetState = _isOffline ? MobilePosUiState.offline : (localCount == 0 ? MobilePosUiState.empty : MobilePosUiState.ready);
        _heldSheetMessageEn = _isOffline
            ? 'Offline mode: showing $localCount locally parked basket(s).'
            : (localCount == 0 ? 'No held carts currently parked.' : 'Showing $localCount local held basket(s).');
        _heldSheetMessageBn = _isOffline
            ? 'অফলাইন মোড: $localCountটি লোকাল হোল্ড কার্ট দেখানো হচ্ছে।'
            : (localCount == 0 ? 'কোনো হোল্ড কার্ট পাওয়া যায়নি।' : '$localCountটি লোকাল হোল্ড কার্ট প্রস্তুত।');
      });
      sheetSetState?.call(() {});
      return;
    }

    if (!quiet && mounted) {
      setState(() => _loadingHeld = true);
      sheetSetState?.call(() {});
    }

    final res = await widget.client.listHeldCarts(
      bearerToken: widget.bearerToken,
      actorRole: widget.actorRole,
      actorTenantId: widget.actorTenantId,
      actorBranchId: widget.actorBranchId,
      targetTenantId: widget.targetTenantId,
      targetBranchId: widget.targetBranchId,
      includeExpired: true,
      subscriptionSuspended: widget.subscriptionSuspended,
      isOffline: _isOffline,
    );
    if (!mounted) return;

    if (quiet && res.uiState != MobilePosUiState.ready && res.uiState != MobilePosUiState.empty) {
      return;
    }

    setState(() {
      _loadingHeld = false;
      if (res.uiState == MobilePosUiState.ready || res.uiState == MobilePosUiState.empty) {
        _heldCarts = res.data?.results ?? const <MobileHeldCartEntry>[];
        _recomputeHeldCount();
      }
      _heldSheetState = res.uiState;
      _heldSheetMessageEn = res.messageEn;
      _heldSheetMessageBn = res.messageBn;
      if (!quiet && (res.uiState == MobilePosUiState.permissionDenied || res.uiState == MobilePosUiState.error)) {
        _uiState = res.uiState;
        _statusMessageEn = res.messageEn;
        _statusMessageBn = res.messageBn;
      }
    });
    sheetSetState?.call(() {});
  }

  Future<void> _resumeHeldEntry(
    MobileHeldCartEntry entry, {
    required bool acknowledgeStale,
    BuildContext? sheetContext,
    void Function(VoidCallback)? sheetSetState,
  }) async {
    if (_cart.isNotEmpty) {
      if (sheetContext != null && Navigator.canPop(sheetContext)) {
        Navigator.pop(sheetContext);
      }
      setState(() {
        _uiState = MobilePosUiState.error;
        _statusMessageEn = 'Hold or clear the active cart before resuming another held basket.';
        _statusMessageBn = 'অন্য হোল্ড কার্ট রিজিউম করার আগে বর্তমান কার্ট হোল্ড বা খালি করুন।';
      });
      return;
    }

    if (entry.offlineLocalOnly) {
      final idx = _offlineHeldBaskets.indexWhere((b) => b.saleId == entry.saleId);
      if (idx < 0) return;
      final basket = _offlineHeldBaskets.removeAt(idx);
      if (sheetContext != null && Navigator.canPop(sheetContext)) {
        Navigator.pop(sheetContext);
      }
      setState(() {
        _cart
          ..clear()
          ..addAll(basket.entries);
        _activeSaleId = null;
        _serverSaleOrder = null;
        _cartVersion = 1;
        _discountType = basket.discountType;
        _discountInputBasis = basket.discountInputBasis;
        _discountValueController.text = basket.discountText;
        _roundingMode = basket.roundingMode;
        _pendingStaleEntry = null;
        _pendingStaleStaleness = null;
        _recomputeHeldCount();
        _uiState = _isOffline ? MobilePosUiState.offline : MobilePosUiState.ready;
        _statusMessageEn = 'Resumed locally held basket (${basket.holdReference}).';
        _statusMessageBn = 'লোকাল হোল্ড কার্ট পুনরুদ্ধার করা হয়েছে (${basket.holdReference})।';
      });
      return;
    }

    final res = await widget.client.resumeCart(
      saleId: entry.saleId,
      bearerToken: widget.bearerToken,
      actorRole: widget.actorRole,
      actorTenantId: widget.actorTenantId,
      actorBranchId: widget.actorBranchId,
      targetTenantId: widget.targetTenantId,
      targetBranchId: widget.targetBranchId,
      acknowledgeStale: acknowledgeStale,
      repriceToLive: true,
      reReserveStock: entry.holdStockReserved && !entry.staleness.hasStockShortage,
      expectedVersion: entry.version > 0 ? entry.version : null,
      subscriptionSuspended: widget.subscriptionSuspended,
      isOffline: _isOffline,
    );
    if (!mounted) return;

    if (res.data != null && res.data!.requiresConfirmation) {
      if (sheetContext != null && sheetContext.mounted && Navigator.canPop(sheetContext)) {
        Navigator.pop(sheetContext);
      }
      setState(() {
        _pendingStaleEntry = entry;
        _pendingStaleStaleness = res.data!.staleness;
        _uiState = MobilePosUiState.error;
        _statusMessageEn = res.messageEn;
        _statusMessageBn = res.messageBn;
      });
      return;
    }

    if (res.uiState == MobilePosUiState.ready && res.data?.sale != null) {
      if (sheetContext != null && sheetContext.mounted && Navigator.canPop(sheetContext)) {
        Navigator.pop(sheetContext);
      }
      setState(() {
        _heldCarts = _heldCarts.where((h) => h.saleId != entry.saleId).toList();
        _pendingStaleEntry = null;
        _pendingStaleStaleness = null;
        _recomputeHeldCount();
        _restoreServerSaleToActiveCounter(res.data!.sale!);
        _uiState = MobilePosUiState.ready;
        _statusMessageEn = res.messageEn;
        _statusMessageBn = res.messageBn;
      });
      return;
    }

    setState(() {
      _heldSheetState = res.uiState;
      _heldSheetMessageEn = res.messageEn;
      _heldSheetMessageBn = res.messageBn;
      _uiState = res.uiState;
      _statusMessageEn = res.messageEn;
      _statusMessageBn = res.messageBn;
    });
    sheetSetState?.call(() {});
  }

  Future<void> _expireStaleHolds({void Function(VoidCallback)? sheetSetState}) async {
    if (_isOffline || widget.bearerToken.isEmpty) {
      setState(() {
        _heldSheetState = MobilePosUiState.offline;
        _heldSheetMessageEn = 'Offline mode: cannot sweep server hold reservations while disconnected.';
        _heldSheetMessageBn = 'অফলাইন মোড: সংযোগ ছাড়া সার্ভার রিজার্ভেশন এক্সপায়ার সুইপ চালানো যাবে না।';
      });
      sheetSetState?.call(() {});
      return;
    }

    final res = await widget.client.expireStaleHolds(
      bearerToken: widget.bearerToken,
      actorRole: widget.actorRole,
      actorTenantId: widget.actorTenantId,
      actorBranchId: widget.actorBranchId,
      targetTenantId: widget.targetTenantId,
      targetBranchId: widget.targetBranchId,
      reason: 'Mobile POS stale hold sweep',
      subscriptionSuspended: widget.subscriptionSuspended,
      isOffline: _isOffline,
    );
    if (!mounted) return;
    setState(() {
      _heldSheetState = res.uiState;
      _heldSheetMessageEn = res.messageEn;
      _heldSheetMessageBn = res.messageBn;
      _uiState = res.uiState;
      _statusMessageEn = res.messageEn;
      _statusMessageBn = res.messageBn;
    });
    if (res.uiState == MobilePosUiState.ready) {
      await _refreshHeldCarts(quiet: true, sheetSetState: sheetSetState);
    }
    sheetSetState?.call(() {});
  }

  Future<void> _releaseHoldReservation(
    MobileHeldCartEntry entry, {
    void Function(VoidCallback)? sheetSetState,
  }) async {
    if (entry.offlineLocalOnly) return;
    final res = await widget.client.expireHold(
      saleId: entry.saleId,
      bearerToken: widget.bearerToken,
      actorRole: widget.actorRole,
      actorTenantId: widget.actorTenantId,
      actorBranchId: widget.actorBranchId,
      targetTenantId: widget.targetTenantId,
      targetBranchId: widget.targetBranchId,
      voidHold: false,
      reason: 'Operator released hold reservation from mobile POS',
      subscriptionSuspended: widget.subscriptionSuspended,
      isOffline: _isOffline,
    );
    if (!mounted) return;
    setState(() {
      if (res.uiState == MobilePosUiState.ready && res.data != null) {
        final updated = _buildHeldEntryFromServerOrder(res.data!);
        _heldCarts = _heldCarts.map((h) => h.saleId == updated.saleId ? updated : h).toList();
      }
      _heldSheetState = res.uiState;
      _heldSheetMessageEn = res.messageEn;
      _heldSheetMessageBn = res.messageBn;
      _uiState = res.uiState;
      _statusMessageEn = res.messageEn;
      _statusMessageBn = res.messageBn;
    });
    sheetSetState?.call(() {});
  }

  Future<void> _cancelHeldEntry(
    MobileHeldCartEntry entry, {
    void Function(VoidCallback)? sheetSetState,
  }) async {
    if (entry.offlineLocalOnly) {
      setState(() {
        _offlineHeldBaskets.removeWhere((b) => b.saleId == entry.saleId);
        if (_pendingStaleEntry?.saleId == entry.saleId) {
          _pendingStaleEntry = null;
          _pendingStaleStaleness = null;
        }
        _recomputeHeldCount();
        _heldSheetState = MobilePosUiState.ready;
        _heldSheetMessageEn = 'Cancelled local held basket (${entry.holdReference}).';
        _heldSheetMessageBn = 'লোকাল হোল্ড কার্ট বাতিল করা হয়েছে (${entry.holdReference})।';
      });
      sheetSetState?.call(() {});
      return;
    }

    final res = await widget.client.cancelHold(
      saleId: entry.saleId,
      bearerToken: widget.bearerToken,
      actorRole: widget.actorRole,
      actorTenantId: widget.actorTenantId,
      actorBranchId: widget.actorBranchId,
      targetTenantId: widget.targetTenantId,
      targetBranchId: widget.targetBranchId,
      reason: 'Cancelled from mobile POS held sheet',
      expectedVersion: entry.version > 0 ? entry.version : null,
      subscriptionSuspended: widget.subscriptionSuspended,
      isOffline: _isOffline,
    );
    if (!mounted) return;
    setState(() {
      if (res.uiState == MobilePosUiState.ready) {
        _heldCarts = _heldCarts.where((h) => h.saleId != entry.saleId).toList();
        if (_pendingStaleEntry?.saleId == entry.saleId) {
          _pendingStaleEntry = null;
          _pendingStaleStaleness = null;
        }
        _recomputeHeldCount();
      }
      _heldSheetState = res.uiState;
      _heldSheetMessageEn = res.messageEn;
      _heldSheetMessageBn = res.messageBn;
      _uiState = res.uiState;
      _statusMessageEn = res.messageEn;
      _statusMessageBn = res.messageBn;
    });
    sheetSetState?.call(() {});
  }

  Future<void> _openHeldCartsSheet() async {
    var sheetActive = true;
    void Function(VoidCallback)? sheetSetState;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surfaceBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (_, setModalState) {
            if (sheetSetState == null) {
              sheetSetState = setModalState;
              Future<void>.microtask(() async {
                await _refreshHeldCarts(
                  quiet: false,
                  sheetSetState: (fn) {
                    if (sheetActive && sheetCtx.mounted) {
                      setModalState(fn);
                    }
                  },
                );
              });
            }
            final entries = _combinedHeldEntries();
            return FractionallySizedBox(
              key: const Key('pos_held_baskets_sheet'),
              heightFactor: 0.78,
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.pause_circle_outline, color: AppTokens.primaryTeal),
                        const SizedBox(width: AppTokens.space8),
                        Expanded(
                          child: Text(
                            _isBangla
                                ? 'হোল্ড করা কার্টসমূহ (${entries.length})'
                                : 'Held Baskets (${entries.length})',
                            style: AppTokens.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          key: const Key('pos_refresh_held_btn'),
                          tooltip: _isBangla ? 'রিফ্রেশ' : 'Refresh',
                          icon: const Icon(Icons.refresh),
                          onPressed: () => _refreshHeldCarts(
                            quiet: false,
                            sheetSetState: (fn) {
                              if (sheetActive && sheetCtx.mounted) setModalState(fn);
                            },
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const Key('pos_expire_stale_btn'),
                          onPressed: () => _expireStaleHolds(
                            sheetSetState: (fn) {
                              if (sheetActive && sheetCtx.mounted) setModalState(fn);
                            },
                          ),
                          icon: const Icon(Icons.schedule, size: 16),
                          label: Text(_isBangla ? 'মেয়াদ শেষ সুইপ' : 'Expire Stale'),
                        ),
                      ],
                    ),
                    if (_heldSheetMessageEn != null && _heldSheetMessageEn!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppTokens.space8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTokens.space8),
                        decoration: BoxDecoration(
                          color: _heldSheetState == MobilePosUiState.permissionDenied ||
                                  _heldSheetState == MobilePosUiState.error
                              ? const Color(0xFFFEF2F2)
                              : (_heldSheetState == MobilePosUiState.offline
                                  ? const Color(0xFFFFFBEB)
                                  : AppTokens.cardSurface),
                          borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
                          border: Border.all(color: AppTokens.borderSubtle),
                        ),
                        child: Text(
                          _isBangla ? (_heldSheetMessageBn ?? _heldSheetMessageEn!) : _heldSheetMessageEn!,
                          style: AppTokens.captionMuted.copyWith(color: AppTokens.textPrimary),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space12),
                    Expanded(
                      child: _loadingHeld
                          ? const Center(child: CircularProgressIndicator())
                          : entries.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(Icons.pause_circle_outline, size: 40, color: AppTokens.textMuted),
                                      const SizedBox(height: AppTokens.space8),
                                      Text(
                                        _isBangla
                                            ? 'এই শাখায় কোনো হোল্ড করা কার্ট নেই'
                                            : 'No held baskets parked in this branch',
                                        style: AppTokens.captionMuted,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: entries.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space8),
                                  itemBuilder: (_, idx) {
                                    final e = entries[idx];
                                    return Container(
                                      key: Key('held_card_${e.saleId}'),
                                      padding: const EdgeInsets.all(AppTokens.space12),
                                      decoration: BoxDecoration(
                                        color: AppTokens.cardSurface,
                                        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                                        border: Border.all(
                                          color: e.staleness.isStale
                                              ? AppTokens.warningAmber
                                              : AppTokens.borderSubtle,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            children: <Widget>[
                                              Expanded(
                                                child: Text(
                                                  e.holdReference.isNotEmpty ? e.holdReference : e.orderNumber,
                                                  style: AppTokens.titleMedium,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: e.offlineLocalOnly
                                                      ? const Color(0xFFFFFBEB)
                                                      : (e.staleness.isStale
                                                          ? const Color(0xFFFEF2F2)
                                                          : const Color(0xFFF0FDF4)),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  e.offlineLocalOnly
                                                      ? (_isBangla ? 'লোকাল অফলাইন' : 'LOCAL OFFLINE')
                                                      : (e.staleness.isStale
                                                          ? (_isBangla ? 'সতর্কতা / মেয়াদোত্তীর্ণ' : 'STALE')
                                                          : (e.holdStockReserved ? 'RESERVED' : 'HELD')),
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AppTokens.space4),
                                          Text(
                                            '${e.lineCount} ${_isBangla ? 'টি আইটেম' : 'line(s)'} • '
                                            'Held: BDT ${e.heldGrandTotalBdt} | Live: BDT ${e.liveGrandTotalBdt}',
                                            style: AppTokens.captionMuted,
                                          ),
                                          if (e.staleness.isStale) ...<Widget>[
                                            const SizedBox(height: AppTokens.space4),
                                            Text(
                                              _isBangla ? e.staleness.userPromptBn : e.staleness.userPromptEn,
                                              style: AppTokens.captionMuted.copyWith(color: AppTokens.dangerRed),
                                            ),
                                          ],
                                          const SizedBox(height: AppTokens.space8),
                                          Wrap(
                                            spacing: AppTokens.space8,
                                            runSpacing: AppTokens.space4,
                                            children: <Widget>[
                                              ElevatedButton.icon(
                                                key: Key('pos_resume_held_${e.saleId}'),
                                                onPressed: () => _resumeHeldEntry(
                                                  e,
                                                  acknowledgeStale: false,
                                                  sheetContext: sheetCtx,
                                                  sheetSetState: (fn) {
                                                    if (sheetActive && sheetCtx.mounted) setModalState(fn);
                                                  },
                                                ),
                                                icon: const Icon(Icons.play_arrow, size: 16),
                                                label: Text(_isBangla ? 'রিজিউম' : 'Resume'),
                                              ),
                                              if (e.holdStockReserved && !e.offlineLocalOnly)
                                                OutlinedButton.icon(
                                                  key: Key('pos_release_hold_${e.saleId}'),
                                                  onPressed: () => _releaseHoldReservation(
                                                    e,
                                                    sheetSetState: (fn) {
                                                      if (sheetActive && sheetCtx.mounted) setModalState(fn);
                                                    },
                                                  ),
                                                  icon: const Icon(Icons.lock_open_outlined, size: 16),
                                                  label: Text(_isBangla ? 'স্টক মুক্ত' : 'Release Res.'),
                                                ),
                                              TextButton.icon(
                                                key: Key('pos_cancel_hold_${e.saleId}'),
                                                onPressed: () => _cancelHeldEntry(
                                                  e,
                                                  sheetSetState: (fn) {
                                                    if (sheetActive && sheetCtx.mounted) setModalState(fn);
                                                  },
                                                ),
                                                icon: const Icon(Icons.delete_outline, size: 16, color: AppTokens.dangerRed),
                                                label: Text(
                                                  _isBangla ? 'বাতিল' : 'Cancel',
                                                  style: const TextStyle(color: AppTokens.dangerRed),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    sheetActive = false;
  }

  // ---------------------------------------------------------------------------
  // P226: Preorders, Delivery Fulfillment & Address Privacy UI Actions
  // ---------------------------------------------------------------------------

  void _recomputeDeliveryCount() {
    _deliveryCount = _deliveryOrders.length + _offlineDeliveries.length;
  }

  List<MobilePosDeliveryOrder> _combinedDeliveries() {
    return <MobilePosDeliveryOrder>[..._deliveryOrders, ..._offlineDeliveries];
  }

  Future<void> _refreshDeliveries({
    bool quiet = false,
    void Function(VoidCallback)? sheetSetState,
  }) async {
    if (_isOffline || widget.bearerToken.isEmpty) {
      if (!mounted || quiet) return;
      setState(() {
        _deliveryOrders = const <MobilePosDeliveryOrder>[];
        _recomputeDeliveryCount();
        _deliverySheetState = MobilePosUiState.offline;
        _deliverySheetMessageEn = _offlineDeliveries.isEmpty
            ? 'Offline mode: no local preorder or delivery orders queued.'
            : 'Offline mode: showing ${_offlineDeliveries.length} locally queued order(s).';
        _deliverySheetMessageBn = _offlineDeliveries.isEmpty
            ? 'অফলাইন মোড: কোনো লোকাল প্রি-অর্ডার/ডেলিভারি নেই।'
            : 'অফলাইন মোড: ${_offlineDeliveries.length}টি লোকাল ডেলিভারি দেখানো হচ্ছে।';
      });
      sheetSetState?.call(() {});
      return;
    }

    if (!quiet && mounted) {
      setState(() => _loadingDeliveries = true);
      sheetSetState?.call(() {});
    }

    final res = await widget.client.listDeliveryOrders(
      bearerToken: widget.bearerToken,
      actorRole: widget.actorRole,
      actorTenantId: widget.actorTenantId,
      actorBranchId: widget.actorBranchId,
      targetTenantId: widget.targetTenantId,
      targetBranchId: widget.targetBranchId,
      subscriptionSuspended: widget.subscriptionSuspended,
      isOffline: _isOffline,
    );
    if (!mounted) return;
    setState(() {
      _loadingDeliveries = false;
      if (res.uiState == MobilePosUiState.ready || res.uiState == MobilePosUiState.empty) {
        _deliveryOrders = res.data?.results ?? const <MobilePosDeliveryOrder>[];
      }
      _recomputeDeliveryCount();
      if (!quiet) {
        _deliverySheetState = res.uiState;
        _deliverySheetMessageEn = res.messageEn;
        _deliverySheetMessageBn = res.messageBn;
      }
    });
    sheetSetState?.call(() {});
  }

  Future<void> _showCreateDeliveryDialog() async {
    if (_cart.isEmpty && _activeSaleId == null) {
      setState(() {
        _uiState = MobilePosUiState.empty;
        _statusMessageEn = 'Add items to cart before creating a preorder or delivery order.';
        _statusMessageBn = 'প্রি-অর্ডার বা ডেলিভারি তৈরি করার আগে কার্টে ওষুধ যুক্ত করুন।';
      });
      return;
    }
    final input = await showDialog<_DeliveryDialogInput>(
      context: context,
      builder: (_) => _CreateDeliveryDialog(isBangla: _isBangla),
    );
    if (input == null || !mounted) return;

    final roleUpper = widget.actorRole.trim().toUpperCase();
    if (widget.subscriptionSuspended) {
      setState(() {
        _uiState = MobilePosUiState.permissionDenied;
        _statusMessageEn = 'Subscription is suspended. Preorder/delivery creation locked.';
        _statusMessageBn = 'সাবস্ক্রিপশন স্থগিত। প্রি-অর্ডার তৈরি করা যাবে না।';
      });
      return;
    }
    if (!_posWriteRoles.contains(roleUpper)) {
      setState(() {
        _uiState = MobilePosUiState.permissionDenied;
        _statusMessageEn = 'Role $roleUpper cannot create preorder or delivery orders.';
        _statusMessageBn = '$roleUpper রোল-এর ডেলিভারি অর্ডার তৈরির অনুমতি নেই।';
      });
      return;
    }

    final canUseServer = !_isOffline &&
        widget.bearerToken.isNotEmpty &&
        (_activeSaleId == null || !_activeSaleId!.startsWith('offline-hold-'));

    if (canUseServer && !_isOffline) {
      final payload = <String, dynamic>{
        'branch': widget.targetBranchId,
        'fulfillment_mode': input.fulfillmentMode,
        'delivery_method': input.deliveryMethod,
        'reserve_stock': input.reserveStock,
        'recipient_name': input.recipientName,
        'recipient_phone': input.recipientPhone,
        'delivery_address_line': input.addressLine,
        if (input.area.isNotEmpty) 'delivery_area': input.area,
        'delivery_fee_bdt': input.feeBdt,
        if (_activeSaleId != null)
          'sale_id': _activeSaleId!
        else
          'lines': _cart
              .map(
                (c) => <String, dynamic>{
                  'product_id': c.candidate.productId,
                  'packaging_unit': c.option.packagingUnit,
                  'quantity_units': c.quantity,
                },
              )
              .toList(),
        'idempotency_key': 'mob-dlv-${DateTime.now().microsecondsSinceEpoch}',
      };

      final res = await widget.client.createDeliveryOrder(
        bearerToken: widget.bearerToken,
        actorRole: widget.actorRole,
        actorTenantId: widget.actorTenantId,
        actorBranchId: widget.actorBranchId,
        targetTenantId: widget.targetTenantId,
        targetBranchId: widget.targetBranchId,
        payload: payload,
        subscriptionSuspended: widget.subscriptionSuspended,
      );
      if (!mounted) return;
      if (res.uiState == MobilePosUiState.ready && res.data != null) {
        setState(() {
          _deliveryOrders = <MobilePosDeliveryOrder>[
            res.data!,
            ..._deliveryOrders.where((d) => d.deliveryId != res.data!.deliveryId),
          ];
          _clearActiveCartCounter();
          _recomputeDeliveryCount();
          _uiState = MobilePosUiState.ready;
          _statusMessageEn = res.messageEn;
          _statusMessageBn = res.messageBn;
        });
        return;
      }
      if (res.uiState != MobilePosUiState.offline) {
        setState(() {
          _uiState = res.uiState;
          _statusMessageEn = res.messageEn;
          _statusMessageBn = res.messageBn;
        });
        return;
      }
    }

    final seq = _offlineDlvSeq++;
    final localId = 'offline-dlv-$seq';
    final baseTotalPaisa = _resolvedTotals().grandTotalPaisa;
    final feePaisa = ((double.tryParse(input.feeBdt) ?? 0.0) * 100).round();
    final localOrder = MobilePosDeliveryOrder(
      deliveryId: localId,
      tenantId: widget.targetTenantId,
      branchId: widget.targetBranchId,
      deliveryNumber: 'OFF-DLV-$seq',
      fulfillmentMode: input.fulfillmentMode,
      deliveryMethod: input.deliveryMethod,
      fulfillmentState: 'PREORDER_PENDING',
      recipientName: input.recipientName,
      recipientPhone: input.recipientPhone,
      deliveryAddressLine: input.addressLine,
      deliveryArea: input.area,
      deliveryFeeBdt: input.feeBdt,
      saleGrandTotalBdt: _formatPaisa(baseTotalPaisa + feePaisa),
      addressPrivacyMasked: false,
      offlineLocalOnly: true,
    );
    setState(() {
      _offlineDeliveries.insert(0, localOrder);
      _clearActiveCartCounter();
      _recomputeDeliveryCount();
      _uiState = MobilePosUiState.offline;
      _statusMessageEn = 'Offline mode: queued preorder/delivery locally (${localOrder.deliveryNumber}).';
      _statusMessageBn = 'অফলাইন মোড: প্রি-অর্ডার লোকালে সংরক্ষিত হয়েছে (${localOrder.deliveryNumber})।';
    });
  }

  Future<void> _revealDeliveryAddress(
    MobilePosDeliveryOrder order, {
    void Function(VoidCallback)? sheetSetState,
  }) async {
    if (order.offlineLocalOnly) {
      setState(() {
        _deliverySheetState = MobilePosUiState.offline;
        _deliverySheetMessageEn = 'Offline local address visible: ${order.deliveryAddressLine}';
        _deliverySheetMessageBn = 'লোকাল অফলাইন ঠিকানা: ${order.deliveryAddressLine}';
      });
      sheetSetState?.call(() {});
      return;
    }

    final res = await widget.client.revealDeliveryAddress(
      deliveryId: order.deliveryId,
      reason: 'Mobile POS courier & doorstep verification',
      bearerToken: widget.bearerToken,
      actorRole: widget.actorRole,
      actorTenantId: widget.actorTenantId,
      actorBranchId: widget.actorBranchId,
      targetTenantId: widget.targetTenantId,
      targetBranchId: widget.targetBranchId,
      subscriptionSuspended: widget.subscriptionSuspended,
      isOffline: _isOffline,
    );
    if (!mounted) return;
    setState(() {
      if (res.uiState == MobilePosUiState.ready && res.data != null) {
        final r = res.data!;
        _deliveryOrders = _deliveryOrders.map((d) {
          if (d.deliveryId != order.deliveryId) return d;
          return d.copyWith(
            recipientName: r.recipientName,
            recipientPhone: r.recipientPhone,
            deliveryAddressLine: r.deliveryAddressLine,
            deliveryArea: r.deliveryArea,
            deliveryCity: r.deliveryCity,
            deliveryLandmarkNotes: r.deliveryLandmarkNotes,
            addressPrivacyMasked: false,
          );
        }).toList();
      }
      _deliverySheetState = res.uiState;
      _deliverySheetMessageEn = res.uiState == MobilePosUiState.ready && res.data != null
          ? 'Unmasked address revealed (Audit ${res.data!.auditId}).'
          : res.messageEn;
      _deliverySheetMessageBn = res.uiState == MobilePosUiState.ready && res.data != null
          ? 'অডিট (${res.data!.auditId}) সহ পূর্ণ ঠিকানা প্রদর্শিত।'
          : res.messageBn;
    });
    sheetSetState?.call(() {});
  }

  Future<void> _transitionDelivery(
    MobilePosDeliveryOrder order,
    String actionSlug,
    String successEn,
    String successBn, {
    Map<String, dynamic> extraPayload = const <String, dynamic>{},
    void Function(VoidCallback)? sheetSetState,
  }) async {
    if (order.offlineLocalOnly || _isOffline || widget.bearerToken.isEmpty) {
      setState(() {
        _deliverySheetState = MobilePosUiState.offline;
        _deliverySheetMessageEn = 'Offline mode: fulfillment transition requires server sync.';
        _deliverySheetMessageBn = 'অফলাইন মোড: ডেলিভারি স্ট্যাটাস পরিবর্তনে সার্ভার সংযোগ প্রয়োজন।';
      });
      sheetSetState?.call(() {});
      return;
    }
    final payload = <String, dynamic>{
      ...extraPayload,
      if (order.version > 0) 'expected_version': order.version,
    };
    final res = await widget.client.transitionDelivery(
      deliveryId: order.deliveryId,
      actionSlug: actionSlug,
      bearerToken: widget.bearerToken,
      actorRole: widget.actorRole,
      actorTenantId: widget.actorTenantId,
      actorBranchId: widget.actorBranchId,
      targetTenantId: widget.targetTenantId,
      targetBranchId: widget.targetBranchId,
      payload: payload,
      successEn: successEn,
      successBn: successBn,
      subscriptionSuspended: widget.subscriptionSuspended,
      isOffline: _isOffline,
    );
    if (!mounted) return;
    setState(() {
      if (res.uiState == MobilePosUiState.ready && res.data != null) {
        _deliveryOrders = _deliveryOrders
            .map((d) => d.deliveryId == order.deliveryId ? res.data! : d)
            .toList();
      }
      _recomputeDeliveryCount();
      _deliverySheetState = res.uiState;
      _deliverySheetMessageEn = res.messageEn;
      _deliverySheetMessageBn = res.messageBn;
      _uiState = res.uiState;
      _statusMessageEn = res.messageEn;
      _statusMessageBn = res.messageBn;
    });
    sheetSetState?.call(() {});
  }

  Future<void> _cancelDelivery(
    MobilePosDeliveryOrder order, {
    void Function(VoidCallback)? sheetSetState,
  }) async {
    if (order.offlineLocalOnly) {
      setState(() {
        _offlineDeliveries.removeWhere((d) => d.deliveryId == order.deliveryId);
        _recomputeDeliveryCount();
        _deliverySheetState = MobilePosUiState.ready;
        _deliverySheetMessageEn = 'Removed offline delivery order ${order.deliveryNumber}.';
        _deliverySheetMessageBn = 'অফলাইন ডেলিভারি অর্ডার ${order.deliveryNumber} বাতিল হয়েছে।';
      });
      sheetSetState?.call(() {});
      return;
    }
    await _transitionDelivery(
      order,
      'cancel',
      'Delivery cancelled & reserved stock released.',
      'ডেলিভারি বাতিল করে সংরক্ষিত স্টক মুক্ত করা হয়েছে।',
      extraPayload: const <String, dynamic>{'reason': 'Cancelled from mobile POS delivery sheet'},
      sheetSetState: sheetSetState,
    );
  }

  Future<void> _openDeliveriesSheet() async {
    var sheetActive = true;
    void Function(VoidCallback)? sheetSetState;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surfaceBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (_, setModalState) {
            if (sheetSetState == null) {
              sheetSetState = setModalState;
              Future<void>.microtask(() async {
                await _refreshDeliveries(
                  quiet: false,
                  sheetSetState: (fn) {
                    if (sheetActive && sheetCtx.mounted) setModalState(fn);
                  },
                );
              });
            }
            final items = _combinedDeliveries();
            return FractionallySizedBox(
              heightFactor: 0.78,
              child: Padding(
                key: const Key('pos_deliveries_sheet'),
                padding: const EdgeInsets.all(AppTokens.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.local_shipping_outlined, color: AppTokens.primaryTeal),
                        const SizedBox(width: AppTokens.space8),
                        Expanded(
                          child: Text(
                            _isBangla
                                ? 'প্রি-অর্ডার ও ডেলিভারি (${items.length})'
                                : 'Preorders & Deliveries (${items.length})',
                            style: AppTokens.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          key: const Key('pos_refresh_deliveries_btn'),
                          tooltip: _isBangla ? 'রিফ্রেশ' : 'Refresh',
                          icon: const Icon(Icons.refresh),
                          onPressed: () => _refreshDeliveries(
                            quiet: false,
                            sheetSetState: (fn) {
                              if (sheetActive && sheetCtx.mounted) setModalState(fn);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_deliverySheetMessageEn != null && _deliverySheetMessageEn!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppTokens.space8),
                      Container(
                        padding: const EdgeInsets.all(AppTokens.space8),
                        decoration: BoxDecoration(
                          color: _deliverySheetState == MobilePosUiState.permissionDenied ||
                                  _deliverySheetState == MobilePosUiState.error
                              ? const Color(0xFFFEF2F2)
                              : (_deliverySheetState == MobilePosUiState.offline
                                  ? const Color(0xFFFFFBEB)
                                  : AppTokens.cardSurface),
                          borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
                          border: Border.all(color: AppTokens.borderSubtle),
                        ),
                        child: Text(
                          _isBangla
                              ? (_deliverySheetMessageBn ?? _deliverySheetMessageEn!)
                              : _deliverySheetMessageEn!,
                          style: AppTokens.captionMuted.copyWith(color: AppTokens.textPrimary),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space12),
                    Expanded(
                      child: _loadingDeliveries
                          ? const Center(child: CircularProgressIndicator())
                          : items.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(Icons.inventory_2_outlined, size: 40, color: AppTokens.textMuted),
                                      const SizedBox(height: AppTokens.space8),
                                      Text(
                                        _isBangla
                                            ? 'এই শাখায় কোনো প্রি-অর্ডার বা ডেলিভারি নেই'
                                            : 'No preorders or deliveries queued in this branch',
                                        style: AppTokens.captionMuted,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space8),
                                  itemBuilder: (_, idx) {
                                    final d = items[idx];
                                    return Container(
                                      padding: const EdgeInsets.all(AppTokens.space12),
                                      decoration: BoxDecoration(
                                        color: AppTokens.cardSurface,
                                        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                                        border: Border.all(color: AppTokens.borderSubtle),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            children: <Widget>[
                                              Expanded(
                                                child: Text(
                                                  '${d.deliveryNumber.isEmpty ? d.deliveryId : d.deliveryNumber} - ${d.recipientName} (${d.recipientPhone})',
                                                  style: AppTokens.bodyRegular.copyWith(fontWeight: FontWeight.w600),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                'BDT ${d.saleGrandTotalBdt}',
                                                style: AppTokens.bodyRegular.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTokens.primaryTeal,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${d.fulfillmentMode} | ${d.fulfillmentState} | Fee BDT ${d.deliveryFeeBdt}'
                                            '${d.offlineLocalOnly ? (_isBangla ? ' | অফলাইন' : ' | Offline') : ''}',
                                            style: AppTokens.captionMuted,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: <Widget>[
                                              Icon(
                                                d.addressPrivacyMasked ? Icons.shield_outlined : Icons.lock_open_outlined,
                                                size: 14,
                                                color: d.addressPrivacyMasked ? AppTokens.warningAmber : AppTokens.successGreen,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  d.deliveryAddressLine.isEmpty
                                                      ? (d.deliveryArea.isEmpty ? d.deliveryCity : d.deliveryArea)
                                                      : d.deliveryAddressLine,
                                                  style: AppTokens.captionMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AppTokens.space8),
                                          Wrap(
                                            spacing: AppTokens.space8,
                                            runSpacing: AppTokens.space4,
                                            children: <Widget>[
                                              if (!d.offlineLocalOnly)
                                                OutlinedButton.icon(
                                                  key: Key('pos_reveal_dlv_${d.deliveryId}'),
                                                  onPressed: () => _revealDeliveryAddress(
                                                    d,
                                                    sheetSetState: (fn) {
                                                      if (sheetActive && sheetCtx.mounted) setModalState(fn);
                                                    },
                                                  ),
                                                  icon: const Icon(Icons.visibility_outlined, size: 15),
                                                  label: Text(_isBangla ? 'ঠিকানা দেখুন' : 'Reveal Address'),
                                                ),
                                              if (!d.offlineLocalOnly &&
                                                  (d.fulfillmentState == 'PREORDER_PENDING' ||
                                                      d.fulfillmentState == 'PREORDER_RESERVED'))
                                                ElevatedButton.icon(
                                                  key: Key('pos_pack_dlv_${d.deliveryId}'),
                                                  onPressed: () => _transitionDelivery(
                                                    d,
                                                    'pack',
                                                    'Order marked PACKED.',
                                                    'অর্ডার প্যাক করা হয়েছে।',
                                                    sheetSetState: (fn) {
                                                      if (sheetActive && sheetCtx.mounted) setModalState(fn);
                                                    },
                                                  ),
                                                  icon: const Icon(Icons.inventory_outlined, size: 15),
                                                  label: Text(_isBangla ? 'প্যাক' : 'Pack'),
                                                ),
                                              if (!d.offlineLocalOnly && d.fulfillmentState == 'PACKED')
                                                ElevatedButton.icon(
                                                  key: Key('pos_dispatch_dlv_${d.deliveryId}'),
                                                  onPressed: () => _transitionDelivery(
                                                    d,
                                                    'dispatch',
                                                    'Order DISPATCHED.',
                                                    'অর্ডার ডিসপ্যাচ হয়েছে।',
                                                    extraPayload: const <String, dynamic>{'rider_name': 'Branch Rider'},
                                                    sheetSetState: (fn) {
                                                      if (sheetActive && sheetCtx.mounted) setModalState(fn);
                                                    },
                                                  ),
                                                  icon: const Icon(Icons.send_outlined, size: 15),
                                                  label: Text(_isBangla ? 'ডিসপ্যাচ' : 'Dispatch'),
                                                ),
                                              if (!d.offlineLocalOnly &&
                                                  (d.fulfillmentState == 'DISPATCHED' ||
                                                      d.fulfillmentState == 'OUT_FOR_DELIVERY' ||
                                                      d.fulfillmentState == 'PACKED'))
                                                ElevatedButton.icon(
                                                  key: Key('pos_deliver_dlv_${d.deliveryId}'),
                                                  onPressed: () => _transitionDelivery(
                                                    d,
                                                    'deliver',
                                                    'Delivery COMPLETED.',
                                                    'ডেলিভারি সম্পন্ন হয়েছে।',
                                                    extraPayload: <String, dynamic>{
                                                      'proof_of_delivery_ref': 'POD-MOB',
                                                      if ((double.tryParse(d.codExpectedBdt) ?? 0.0) > 0.0) ...<String, dynamic>{
                                                        'cod_collected_bdt': d.codExpectedBdt,
                                                        'cod_tender_type': 'CASH',
                                                      },
                                                    },
                                                    sheetSetState: (fn) {
                                                      if (sheetActive && sheetCtx.mounted) setModalState(fn);
                                                    },
                                                  ),
                                                  icon: const Icon(Icons.check_circle_outline, size: 15),
                                                  label: Text(_isBangla ? 'ডেলিভারি সম্পন্ন' : 'Deliver'),
                                                ),
                                              TextButton.icon(
                                                key: Key('pos_cancel_dlv_${d.deliveryId}'),
                                                onPressed: () => _cancelDelivery(
                                                  d,
                                                  sheetSetState: (fn) {
                                                    if (sheetActive && sheetCtx.mounted) setModalState(fn);
                                                  },
                                                ),
                                                icon: const Icon(Icons.delete_outline, size: 15, color: AppTokens.dangerRed),
                                                label: Text(
                                                  _isBangla ? 'বাতিল' : 'Cancel',
                                                  style: const TextStyle(color: AppTokens.dangerRed),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    sheetActive = false;
  }

  bool get _cartHasBlockedRecall {
    if (_serverSaleOrder?.hasBlockedRecallOrBan == true) return true;
    if (_rxGateStatusCache != null &&
        _rxGateStatusCache!.saleId == _activeSaleId &&
        _rxGateStatusCache!.hasBlockedRecallOrBan) {
      return true;
    }
    for (final entry in _cart) {
      final cls = entry.candidate.regulatoryClassification.toUpperCase();
      if (cls == 'RECALLED' || cls == 'BANNED') return true;
    }
    return false;
  }

  bool get _cartRequiresRx {
    if (_serverSaleOrder?.requiresRxVerification == true) return true;
    for (final entry in _cart) {
      if (entry.candidate.requiresRxVerification) return true;
      final cls = entry.candidate.regulatoryClassification.toUpperCase();
      if (cls.isNotEmpty && cls != 'OTC') return true;
    }
    return false;
  }

  bool get _hasUnverifiedLocalRxScaling {
    final srv = _serverSaleOrder;
    if (srv == null || !_cartRequiresRx) return false;
    final approvedByProduct = <String, int>{};
    for (final l in srv.lines) {
      if (l.requiresRxVerification) {
        approvedByProduct[l.productId] = (approvedByProduct[l.productId] ?? 0) + l.rxVerifiedBaseUnits;
      }
    }
    final localByProduct = <String, int>{};
    for (final e in _cart) {
      final isLineRx = e.candidate.requiresRxVerification ||
          srv.lines.any((l) => l.productId == e.candidate.productId && l.requiresRxVerification);
      if (isLineRx) {
        localByProduct[e.candidate.productId] =
            (localByProduct[e.candidate.productId] ?? 0) + (e.quantity * e.option.conversionFactor);
      }
    }
    for (final entry in localByProduct.entries) {
      if (entry.value > (approvedByProduct[entry.key] ?? 0)) {
        return true;
      }
    }
    return false;
  }

  bool get _isCartRxApprovedForCheckout {
    if (_cartHasBlockedRecall) return false;
    if (!_cartRequiresRx) return true;
    final srv = _serverSaleOrder;
    if (srv == null) return false;
    return srv.rxGateStatus.toUpperCase() == 'APPROVED' &&
        (srv.rxVerifiedAt?.isNotEmpty ?? false) &&
        !_hasUnverifiedLocalRxScaling;
  }

  String get _effectiveRxGateBadge {
    if (_cartHasBlockedRecall) return 'BLOCKED_RECALL_OR_BAN';
    if (!_cartRequiresRx) return 'NOT_REQUIRED';
    if (_serverSaleOrder?.rxGateStatus.toUpperCase() == 'REJECTED') return 'REJECTED';
    if (_isCartRxApprovedForCheckout) return 'APPROVED';
    return 'PENDING_PHARMACIST';
  }

  Future<void> _handleCheckout() async {
    if (_cart.isEmpty) {
      setState(() {
        _uiState = MobilePosUiState.empty;
        _statusMessageEn = 'Add medicines to cart before checkout.';
        _statusMessageBn = 'চেকআউটের আগে কার্টে ওষুধ যুক্ত করুন।';
      });
      return;
    }

    if (_cartHasBlockedRecall) {
      setState(() {
        _uiState = MobilePosUiState.error;
        _statusMessageEn = 'ERR_REGULATED_PRODUCT_BLOCKED: Cart contains RECALLED/BANNED item.';
        _statusMessageBn = 'কার্টে প্রত্যাহৃত বা নিষিদ্ধ ওষুধ থাকায় চেকআউট সম্পূর্ণ নিষিদ্ধ।';
      });
      return;
    }

    if (_cartRequiresRx && !_isCartRxApprovedForCheckout) {
      if (_isOffline) {
        setState(() {
          _uiState = MobilePosUiState.offline;
          _statusMessageEn =
              'ERR_OFFLINE_RX_BLOCKED: Offline limitation blocks unverified Rx/antibiotic checkout. Park to Hold Queue and reconnect.';
          _statusMessageBn =
              'অফলাইন সীমাবদ্ধতা: ফার্মাসিস্ট অনুমোদন ছাড়া প্রেসক্রিপশন/অ্যান্টিবায়োটিক অফলাইনে চেকআউট করা যাবে না। হোল্ড করে অনলাইনে আসুন।';
        });
        return;
      }
      setState(() {
        _uiState = MobilePosUiState.error;
        _statusMessageEn = _hasUnverifiedLocalRxScaling
            ? 'ERR_PHARMACIST_APPROVAL_REQUIRED: Cart quantities modified; re-approve in Rx Gate.'
            : 'ERR_PHARMACIST_APPROVAL_REQUIRED: Registered Pharmacist Rx approval required before checkout.';
        _statusMessageBn = _hasUnverifiedLocalRxScaling
            ? 'কার্ট পরিবর্তিত হওয়ায় পুনরায় ফার্মাসিস্ট Rx অনুমোদন আবশ্যক।'
            : 'চেকআউটের আগে নিবন্ধিত ফার্মাসিস্টের Rx অনুমোদন আবশ্যক।';
      });
      await _openRxGateSheet();
      return;
    }

    if (_isOffline) {
      final offlineBlock = _validateOfflineFefoStockSafety();
      if (offlineBlock != null) {
        setState(() {
          _uiState = MobilePosUiState.error;
          _statusMessageEn = offlineBlock.$1;
          _statusMessageBn = offlineBlock.$2;
        });
        return;
      }
      final splitBlock = _validateOfflineSplitPayments();
      if (splitBlock != null) {
        setState(() {
          _uiState = MobilePosUiState.offline;
          _statusMessageEn = splitBlock.$1;
          _statusMessageBn = splitBlock.$2;
        });
        return;
      }
      final hadSplits = _stagedSplits.isNotEmpty;
      setState(() {
        _cart.clear();
        _activeSaleId = null;
        _serverSaleOrder = null;
        _rxGateStatusCache = null;
        _fefoPlanCache = null;
        _fefoBatchOverrides = <String, String>{};
        _fefoOverrideReason = '';
        _fefoOverrideBatchController.clear();
        _fefoOverrideReasonController.clear();
        _stagedSplits.clear();
        _splitAmountController.clear();
        _splitRefController.clear();
        _splitPayerController.clear();
        _discountType = 'NONE';
        _discountInputBasis = 0;
        _discountValueController.clear();
        _uiState = MobilePosUiState.offline;
        _statusMessageEn = hadSplits
            ? 'Offline OTC sale queued safely cleanly (OFFLINE_PROVISIONAL_FEFO | OFFLINE_PROVISIONAL_PAYMENT).'
            : 'Offline OTC sale queued safely cleanly (OFFLINE_PROVISIONAL_FEFO).';
        _statusMessageBn = hadSplits
            ? 'অফলাইন OTC বিক্রয় ও ক্যাশ পেমেন্ট নিরাপদভাবে কিউতে সংরক্ষিত হয়েছে (OFFLINE_PROVISIONAL_PAYMENT)।'
            : 'অফলাইন OTC বিক্রয় নিরাপদভাবে কিউতে সংরক্ষিত হয়েছে (OFFLINE_PROVISIONAL_FEFO)।';
      });
      return;
    }

    final totals = _resolvedTotals();
    if (_activeSaleId != null &&
        !_activeSaleId!.startsWith('offline-hold-') &&
        widget.bearerToken.isNotEmpty) {
      final payAmt = _formatPaisa(totals.grandTotalPaisa);
      final usedStagedSplits = _stagedSplits.isNotEmpty;
      if (usedStagedSplits) {
        final splitRes = await widget.client.submitSplitPayments(
          bearerToken: widget.bearerToken,
          actorRole: widget.actorRole,
          actorTenantId: widget.actorTenantId,
          actorBranchId: widget.actorBranchId,
          targetTenantId: widget.targetTenantId,
          targetBranchId: widget.targetBranchId,
          saleId: _activeSaleId!,
          splits: List<MobileSplitPaymentInput>.from(_stagedSplits),
          batchIdempotencyKey: 'm-split-${DateTime.now().microsecondsSinceEpoch}',
          requireVerified: true,
          isOffline: _isOffline,
          subscriptionSuspended: widget.subscriptionSuspended,
        );
        if (!mounted) return;
        if (splitRes.uiState != MobilePosUiState.ready) {
          setState(() {
            _uiState = splitRes.uiState;
            _statusMessageEn = splitRes.messageEn;
            _statusMessageBn = splitRes.messageBn;
          });
          return;
        }
        _serverSaleOrder = splitRes.data;
      } else if (totals.grandTotalPaisa > 0) {
        final payRes = await widget.client.recordPaymentAttempt(
          bearerToken: widget.bearerToken,
          actorRole: widget.actorRole,
          actorTenantId: widget.actorTenantId,
          actorBranchId: widget.actorBranchId,
          targetTenantId: widget.targetTenantId,
          targetBranchId: widget.targetBranchId,
          saleId: _activeSaleId!,
          tenderType: 'CASH',
          amountBdt: payAmt,
          idempotencyKey: 'm-pay-${DateTime.now().microsecondsSinceEpoch}',
          isOffline: _isOffline,
          subscriptionSuspended: widget.subscriptionSuspended,
        );
        if (!mounted) return;
        if (payRes.uiState != MobilePosUiState.ready) {
          setState(() {
            _uiState = payRes.uiState;
            _statusMessageEn = payRes.messageEn;
            _statusMessageBn = payRes.messageBn;
          });
          return;
        }
      }

      final finRes = await widget.client.finalizeSale(
        bearerToken: widget.bearerToken,
        actorRole: widget.actorRole,
        actorTenantId: widget.actorTenantId,
        actorBranchId: widget.actorBranchId,
        targetTenantId: widget.targetTenantId,
        targetBranchId: widget.targetBranchId,
        saleId: _activeSaleId!,
        requiresRxVerification: _cartRequiresRx,
        rxGateStatus: _serverSaleOrder?.rxGateStatus ?? 'NOT_REQUIRED',
        batchOverrides: _fefoBatchOverrides.isEmpty ? null : _fefoBatchOverrides,
        overrideReason: _fefoOverrideReason,
        isOffline: _isOffline,
        subscriptionSuspended: widget.subscriptionSuspended,
      );
      if (!mounted) return;
      if (finRes.uiState != MobilePosUiState.ready) {
        setState(() {
          _uiState = finRes.uiState;
          _statusMessageEn = finRes.messageEn;
          _statusMessageBn = finRes.messageBn;
        });
        return;
      }
      final ref = (finRes.data?.orderNumber.isNotEmpty ?? false)
          ? finRes.data!.orderNumber
          : (_activeSaleId ?? '');
      final allocs = finRes.data?.allocations ?? const <MobilePosSaleAllocation>[];
      final lotSummary = allocs.isEmpty
          ? ''
          : ' | FEFO: ${allocs.map((a) => '${a.batchNumber.isNotEmpty ? a.batchNumber : a.batchId} x${a.allocatedBaseUnits}').join(', ')}';
      final paidStr = finRes.data?.paidAmountBdt ?? payAmt;
      final changeStr = finRes.data?.changeReturnedBdt ?? '0.00';
      final hasChange = (double.tryParse(changeStr) ?? 0.0) > 0.0;
      final paySummaryEn = usedStagedSplits
          ? ' | Paid: ৳$paidStr${hasChange ? ' (Change: ৳$changeStr)' : ''}'
          : (hasChange ? ' | Change: ৳$changeStr' : '');
      final paySummaryBn = usedStagedSplits
          ? ' | পরিশোধ: ৳$paidStr${hasChange ? ' (ফেরত: ৳$changeStr)' : ''}'
          : (hasChange ? ' | ফেরত: ৳$changeStr' : '');
      setState(() {
        _cart.clear();
        _activeSaleId = null;
        _serverSaleOrder = null;
        _rxGateStatusCache = null;
        _fefoPlanCache = null;
        _fefoBatchOverrides = <String, String>{};
        _fefoOverrideReason = '';
        _fefoOverrideBatchController.clear();
        _fefoOverrideReasonController.clear();
        _stagedSplits.clear();
        _activeCustomer = null;
        _selectedDueRecord = null;
        _splitAmountController.clear();
        _splitRefController.clear();
        _splitPayerController.clear();
        _dueCollectAmountController.clear();
        _dueCollectRefController.clear();
        _discountType = 'NONE';
        _discountInputBasis = 0;
        _discountValueController.clear();
        _uiState = MobilePosUiState.ready;
        _statusMessageEn = 'Checkout finalized ($ref)$lotSummary$paySummaryEn.';
        _statusMessageBn = 'চেকআউট সম্পন্ন হয়েছে ($ref)$lotSummary$paySummaryBn।';
      });
      return;
    }

    setState(() {
      _cart.clear();
      _activeSaleId = null;
      _serverSaleOrder = null;
      _rxGateStatusCache = null;
      _fefoPlanCache = null;
      _fefoBatchOverrides = <String, String>{};
      _fefoOverrideReason = '';
      _fefoOverrideBatchController.clear();
      _fefoOverrideReasonController.clear();
      _stagedSplits.clear();
      _activeCustomer = null;
      _selectedDueRecord = null;
      _splitAmountController.clear();
      _splitRefController.clear();
      _splitPayerController.clear();
      _dueCollectAmountController.clear();
      _dueCollectRefController.clear();
      _discountType = 'NONE';
      _discountInputBasis = 0;
      _discountValueController.clear();
      _uiState = MobilePosUiState.ready;
      _statusMessageEn = 'OTC sale completed.';
      _statusMessageBn = 'OTC বিক্রয় সম্পন্ন হয়েছে।';
    });
  }

  (String, String)? _validateOfflineSplitPayments() {
    if (_stagedSplits.isEmpty) return null;
    final totals = _resolvedTotals();
    var nonCashPaisa = 0;
    for (final leg in _stagedSplits) {
      final tender = leg.tenderType.trim().toUpperCase();
      final gwRef = leg.gatewayReference.trim();
      final ver = leg.verificationStatus.trim().toUpperCase();
      final paisa = ((double.tryParse(leg.amountBdt.trim()) ?? 0.0) * 100.0).round();
      if (paisa <= 0) {
        return (
          'ERR_INVALID_PAYMENT_AMOUNT: Split amount must be greater than 0.00 BDT.',
          'স্প্লিট পেমেন্টের পরিমাণ ০.০০ টাকার বেশি হতে হবে।'
        );
      }
      if (tender == 'DUE') {
        return (
          'ERR_OFFLINE_CREDIT_UNAVAILABLE: Offline limitation blocks customer DUE/credit checkout; pay Cash while disconnected.',
          'অফলাইন সীমাবদ্ধতা: ক্রেডিট বা বাকি বিক্রয়ের জন্য অনলাইনে ক্রেডিট লিমিট যাচাই আবশ্যক।'
        );
      }
      if (MobilePosDomainClient.digitalTenders.contains(tender) &&
          (gwRef.length < 4 || ver == 'PENDING_GATEWAY')) {
        return (
          'ERR_OFFLINE_DIGITAL_PAYMENT_REQUIRES_REF: Offline MFS/Card payment requires verified terminal TrxID (>= 4 chars) or pay with Cash.',
          'অফলাইন সীমাবদ্ধতা: বিকাশ/নগদ/কার্ড পেমেন্টের জন্য ন্যূনতম ৪ অক্ষরের ভেরিফায়েড রেফারেন্স আবশ্যক বা ক্যাশ ব্যবহার করুন।'
        );
      }
      if (tender != 'CASH') {
        nonCashPaisa += paisa;
      }
    }
    if (totals.grandTotalPaisa > 0 && nonCashPaisa > totals.grandTotalPaisa) {
      return (
        'ERR_NON_CASH_OVERPAYMENT: Non-cash split tenders cannot exceed invoice grand total.',
        'নন-ক্যাশ (বিকাশ/কার্ড/বাকি) পেমেন্ট ইনভয়েসের মোট মূল্যের বেশি হতে পারবে না।'
      );
    }
    return null;
  }

  (String, String)? _validateOfflineFefoStockSafety() {
    final nowIso = DateTime.now().toIso8601String().substring(0, 10);
    final byProduct = <String, MobileFastSearchCandidate>{};
    final neededByProduct = <String, int>{};
    for (final entry in _cart) {
      byProduct.putIfAbsent(entry.candidate.productId, () => entry.candidate);
      neededByProduct[entry.candidate.productId] =
          (neededByProduct[entry.candidate.productId] ?? 0) + (entry.quantity * entry.option.conversionFactor);
    }
    for (final pid in byProduct.keys) {
      final cand = byProduct[pid]!;
      final needed = neededByProduct[pid] ?? 0;
      final hasExpDate = cand.earliestExpiryDate != null &&
          cand.earliestExpiryDate!.trim().isNotEmpty &&
          cand.earliestExpiryDate!.trim().compareTo(nowIso) <= 0;
      final hasStockTelemetry = cand.availableBaseUnits > 0 ||
          cand.recalledBaseUnits > 0 ||
          cand.quarantinedBaseUnits > 0 ||
          cand.expiredBaseUnits > 0;
      if (cand.recalledBaseUnits > 0 && cand.availableBaseUnits <= 0) {
        return (
          'ERR_BATCH_RECALLED: Cannot sell ${cand.brandName}; cached lot is recalled.',
          '${cand.brandName} প্রত্যাহৃত হওয়ায় অফলাইনে বিক্রি নিষিদ্ধ।'
        );
      }
      if (cand.quarantinedBaseUnits > 0 && cand.availableBaseUnits <= 0) {
        return (
          'ERR_BATCH_QUARANTINED: Cannot sell ${cand.brandName}; stock is quarantined.',
          '${cand.brandName} কোয়ারেন্টিনড থাকায় অফলাইনে বিক্রি নিষিদ্ধ।'
        );
      }
      if (hasExpDate || (cand.expiredBaseUnits > 0 && cand.availableBaseUnits <= 0)) {
        return (
          'ERR_BATCH_EXPIRED: Cannot sell ${cand.brandName}; batch is expired (${cand.earliestExpiryDate ?? 'expired'}).',
          '${cand.brandName} এর ব্যাচ মেয়াদোত্তীর্ণ হওয়ায় বিক্রি নিষিদ্ধ।'
        );
      }
      if (hasStockTelemetry && needed > cand.availableBaseUnits) {
        return (
          'ERR_INSUFFICIENT_DISPENSABLE_STOCK: Need ${needed}u of ${cand.brandName}, only ${cand.availableBaseUnits}u safe FEFO available.',
          '${cand.brandName} এর পর্যাপ্ত নিরাপদ FEFO মজুদ নেই (প্রয়োজন $needed, আছে ${cand.availableBaseUnits})।'
        );
      }
    }
    return null;
  }

  Future<void> _openSplitPaymentSheet() async {
    _splitSheetState = null;
    _splitSheetMessageEn = null;
    _splitSheetMessageBn = null;
    var sheetActive = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void safeSheetUpdate(VoidCallback fn) {
              if (!sheetActive || !ctx.mounted) return;
              setSheetState(fn);
            }

            final totals = _resolvedTotals();
            var stagedTotalPaisa = 0;
            var cashPaisa = 0;
            var nonCashPaisa = 0;
            for (final leg in _stagedSplits) {
              final p = ((double.tryParse(leg.amountBdt.trim()) ?? 0.0) * 100.0).round();
              stagedTotalPaisa += p;
              if (leg.tenderType.trim().toUpperCase() == 'CASH') {
                cashPaisa += p;
              } else {
                nonCashPaisa += p;
              }
            }
            final remainingPaisa =
                totals.grandTotalPaisa > stagedTotalPaisa ? totals.grandTotalPaisa - stagedTotalPaisa : 0;
            final nonCashOverpaid = totals.grandTotalPaisa > 0 && nonCashPaisa > totals.grandTotalPaisa;
            final excessPaisa = stagedTotalPaisa > totals.grandTotalPaisa ? stagedTotalPaisa - totals.grandTotalPaisa : 0;
            final estChangePaisa =
                (!nonCashOverpaid && excessPaisa > 0 && cashPaisa >= excessPaisa) ? excessPaisa : 0;

            void addSplitLeg() {
              final amtVal = double.tryParse(_splitAmountController.text.trim());
              if (amtVal == null || amtVal <= 0.0) {
                safeSheetUpdate(() {
                  _splitSheetState = MobilePosUiState.error;
                  _splitSheetMessageEn = 'ERR_INVALID_PAYMENT_AMOUNT: Enter a positive split amount.';
                  _splitSheetMessageBn = 'সঠিক ধনাত্মক স্প্লিট পেমেন্টের পরিমাণ লিখুন।';
                });
                return;
              }
              final tender = _splitTenderType.trim().toUpperCase();
              final ref = _splitRefController.text.trim();
              final payer = _splitPayerController.text.trim();
              if (MobilePosDomainClient.digitalTenders.contains(tender) && ref.length < 4) {
                safeSheetUpdate(() {
                  _splitSheetState = _isOffline ? MobilePosUiState.offline : MobilePosUiState.error;
                  _splitSheetMessageEn = _isOffline
                      ? 'ERR_OFFLINE_DIGITAL_PAYMENT_REQUIRES_REF: Offline MFS/Card requires verified TrxID (>= 4 chars) or pay Cash.'
                      : 'ERR_DIGITAL_TENDER_REFERENCE_REQUIRED: Verified $tender payment requires TrxID / Card auth code (>= 4 chars).';
                  _splitSheetMessageBn = _isOffline
                      ? 'অফলাইন সীমাবদ্ধতা: বিকাশ/নগদ/কার্ডের জন্য ন্যূনতম ৪ অক্ষরের ভেরিফায়েড রেফারেন্স আবশ্যক বা ক্যাশ ব্যবহার করুন।'
                      : 'ভেরিফায়েড $tender পেমেন্টের জন্য ন্যূনতম ৪ অক্ষরের TrxID বা কার্ড রেফারেন্স আবশ্যক।';
                });
                return;
              }
              if (tender == 'DUE') {
                if (_isOffline) {
                  safeSheetUpdate(() {
                    _splitSheetState = MobilePosUiState.offline;
                    _splitSheetMessageEn =
                        'ERR_OFFLINE_CREDIT_UNAVAILABLE: Offline limitation blocks customer DUE sales; use Cash.';
                    _splitSheetMessageBn =
                        'অফলাইন সীমাবদ্ধতা: ক্রেডিট বা বাকি বিক্রয়ের জন্য অনলাইন সংযোগ আবশ্যক।';
                  });
                  return;
                }
                if (_activeCustomer == null) {
                  safeSheetUpdate(() {
                    _splitSheetState = MobilePosUiState.error;
                    _splitSheetMessageEn =
                        'ERR_APPROVED_CUSTOMER_REQUIRED: Select an approved credit customer before staging DUE.';
                    _splitSheetMessageBn = 'বাকি বিক্রয়ের আগে অনুমোদিত গ্রাহক নির্বাচন করুন।';
                  });
                  return;
                }
                if (!_activeCustomer!.isCreditApproved ||
                    _activeCustomer!.creditStatus.toUpperCase() != 'APPROVED') {
                  safeSheetUpdate(() {
                    _splitSheetState = MobilePosUiState.error;
                    _splitSheetMessageEn =
                        'ERR_CUSTOMER_CREDIT_NOT_APPROVED: Customer credit status is ${_activeCustomer!.creditStatus}.';
                    _splitSheetMessageBn = 'নির্বাচিত গ্রাহকের ক্রেডিট অনুমোদন নেই।';
                  });
                  return;
                }
                final avail = double.tryParse(_activeCustomer!.availableCreditBdt) ?? 0.0;
                var stagedDueSum = 0.0;
                for (final l in _stagedSplits) {
                  if (l.tenderType.toUpperCase() == 'DUE') {
                    stagedDueSum += double.tryParse(l.amountBdt) ?? 0.0;
                  }
                }
                if (stagedDueSum + amtVal > avail) {
                  safeSheetUpdate(() {
                    _splitSheetState = MobilePosUiState.error;
                    _splitSheetMessageEn =
                        'ERR_CUSTOMER_CREDIT_LIMIT_EXCEEDED: Exceeds available credit ৳${avail.toStringAsFixed(2)}.';
                    _splitSheetMessageBn =
                        'উপলব্ধ ক্রেডিট লিমিট ৳${avail.toStringAsFixed(2)} অতিক্রম করেছে।';
                  });
                  return;
                }
              }
              final formattedAmt = amtVal.toStringAsFixed(2);
              final cardLast4 = (tender == 'CARD' && RegExp(r'^\d{4}$').hasMatch(ref)) ? ref : '';
              final input = MobileSplitPaymentInput(
                tenderType: tender,
                amountBdt: formattedAmt,
                gatewayReference: ref,
                payerReference: payer,
                cardLast4: cardLast4,
                idempotencyKey: 'm-leg-${DateTime.now().microsecondsSinceEpoch}-${_stagedSplits.length + 1}',
              );
              setState(() {
                _stagedSplits.add(input);
                _splitAmountController.clear();
                _splitRefController.clear();
                _splitPayerController.clear();
                _splitSheetState = MobilePosUiState.ready;
                _splitSheetMessageEn = 'Staged $tender ৳$formattedAmt split leg.';
                _splitSheetMessageBn = '$tender ৳$formattedAmt স্প্লিট যুক্ত হয়েছে।';
              });
              safeSheetUpdate(() {});
            }

            Future<void> submitStagedSplits() async {
              if (_stagedSplits.isEmpty) {
                safeSheetUpdate(() {
                  _splitSheetState = MobilePosUiState.error;
                  _splitSheetMessageEn = 'ERR_EMPTY_SPLIT_PAYMENTS: Add at least one tender split leg.';
                  _splitSheetMessageBn = 'অন্তত একটি টেন্ডার স্প্লিট লাইন যোগ করুন।';
                });
                return;
              }
              if (_isOffline) {
                final offErr = _validateOfflineSplitPayments();
                safeSheetUpdate(() {
                  _splitSheetState = offErr != null ? MobilePosUiState.offline : MobilePosUiState.ready;
                  _splitSheetMessageEn = offErr != null
                      ? offErr.$1
                      : 'Cash split staged for offline queue checkout (OFFLINE_PROVISIONAL_PAYMENT). Close sheet and tap Checkout.';
                  _splitSheetMessageBn = offErr != null
                      ? offErr.$2
                      : 'অফলাইন ক্যাশ স্প্লিট প্রস্তুত (OFFLINE_PROVISIONAL_PAYMENT)। শিট বন্ধ করে চেকআউট চাপুন।';
                });
                return;
              }
              if (_activeSaleId == null || widget.bearerToken.isEmpty) {
                safeSheetUpdate(() {
                  _splitSheetState = MobilePosUiState.ready;
                  _splitSheetMessageEn = 'Splits staged locally and will post automatically on Checkout.';
                  _splitSheetMessageBn = 'স্প্লিট পেমেন্ট প্রস্তুত; চেকআউটে স্বয়ংক্রিয়ভাবে পোস্ট হবে।';
                });
                return;
              }
              safeSheetUpdate(() => _loadingSplitPay = true);
              final res = await widget.client.submitSplitPayments(
                bearerToken: widget.bearerToken,
                actorRole: widget.actorRole,
                actorTenantId: widget.actorTenantId,
                actorBranchId: widget.actorBranchId,
                targetTenantId: widget.targetTenantId,
                targetBranchId: widget.targetBranchId,
                saleId: _activeSaleId!,
                splits: List<MobileSplitPaymentInput>.from(_stagedSplits),
                batchIdempotencyKey: 'm-split-${DateTime.now().microsecondsSinceEpoch}',
                requireVerified: true,
                isOffline: _isOffline,
                subscriptionSuspended: widget.subscriptionSuspended,
              );
              if (!mounted) return;
              setState(() {
                _loadingSplitPay = false;
                if (res.data != null) {
                  _serverSaleOrder = res.data;
                  _stagedSplits.clear();
                }
                _splitSheetState = res.uiState;
                _splitSheetMessageEn = res.data != null
                    ? 'Posted split payments. Paid: ৳${res.data!.paidAmountBdt}, Change: ৳${res.data!.changeReturnedBdt}, Due: ৳${res.data!.dueAmountBdt}.'
                    : '${res.errorCode.isNotEmpty ? '${res.errorCode}: ' : ''}${res.messageEn}';
                _splitSheetMessageBn = res.data != null
                    ? 'স্প্লিট পেমেন্ট গৃহীত হয়েছে। পরিশোধ: ৳${res.data!.paidAmountBdt}, ফেরত: ৳${res.data!.changeReturnedBdt}।'
                    : res.messageBn;
              });
              safeSheetUpdate(() {});
            }

            Future<void> refreshCloseRecon() async {
              if (_isOffline || widget.bearerToken.isEmpty) {
                safeSheetUpdate(() {
                  _splitSheetState = MobilePosUiState.offline;
                  _splitSheetMessageEn =
                      'Offline limitation: Cashier shift close reconciliation requires cloud connectivity.';
                  _splitSheetMessageBn =
                      'অফলাইন সীমাবদ্ধতা: শিফট ক্লোজ রিকনসিলিয়েশন দেখতে সার্ভার সংযোগ প্রয়োজন।';
                });
                return;
              }
              safeSheetUpdate(() => _loadingSplitPay = true);
              final res = await widget.client.getCloseReconciliation(
                bearerToken: widget.bearerToken,
                actorRole: widget.actorRole,
                actorTenantId: widget.actorTenantId,
                actorBranchId: widget.actorBranchId,
                targetTenantId: widget.targetTenantId,
                targetBranchId: widget.targetBranchId,
                isOffline: _isOffline,
                subscriptionSuspended: widget.subscriptionSuspended,
              );
              if (!mounted) return;
              setState(() {
                _loadingSplitPay = false;
                if (res.data != null) _closeReconCache = res.data;
                _splitSheetState = res.uiState;
                _splitSheetMessageEn = res.data != null
                    ? 'Shift summary: Expected Cash ৳${res.data!.expectedDrawerCashBdt} | Digital ৳${res.data!.digitalTotalBdt} | Sales ${res.data!.salesCount}.'
                    : '${res.errorCode.isNotEmpty ? '${res.errorCode}: ' : ''}${res.messageEn}';
                _splitSheetMessageBn = res.data != null
                    ? 'শিফট সামারি: প্রত্যাশিত নগদ ৳${res.data!.expectedDrawerCashBdt} | ডিজিটাল ৳${res.data!.digitalTotalBdt}।'
                    : res.messageBn;
              });
              safeSheetUpdate(() {});
            }

            Future<void> submitCloseRecon() async {
              if (_isOffline || widget.bearerToken.isEmpty) {
                safeSheetUpdate(() {
                  _splitSheetState = MobilePosUiState.offline;
                  _splitSheetMessageEn =
                      'Offline limitation: Cannot finalize cashier close reconciliation while disconnected.';
                  _splitSheetMessageBn =
                      'অফলাইন সীমাবদ্ধতা: সংযোগ ছাড়া শিফট ক্লোজ রিকনসিলিয়েশন জমা দেওয়া যাবে না।';
                });
                return;
              }
              safeSheetUpdate(() => _loadingSplitPay = true);
              final res = await widget.client.submitCloseReconciliation(
                bearerToken: widget.bearerToken,
                actorRole: widget.actorRole,
                actorTenantId: widget.actorTenantId,
                actorBranchId: widget.actorBranchId,
                targetTenantId: widget.targetTenantId,
                targetBranchId: widget.targetBranchId,
                countedCashBdt: _closeCountedCashController.text.trim(),
                notes: _closeNotesController.text.trim(),
                isOffline: _isOffline,
                subscriptionSuspended: widget.subscriptionSuspended,
              );
              if (!mounted) return;
              setState(() {
                _loadingSplitPay = false;
                if (res.data != null) _closeReconCache = res.data;
                _splitSheetState = res.uiState;
                _splitSheetMessageEn = res.data != null
                    ? 'Close Reconciliation ${res.data!.status}: Variance ৳${res.data!.varianceBdt} (Expected ৳${res.data!.expectedDrawerCashBdt}, Counted ৳${res.data!.countedCashBdt}).'
                    : '${res.errorCode.isNotEmpty ? '${res.errorCode}: ' : ''}${res.messageEn}';
                _splitSheetMessageBn = res.data != null
                    ? 'ক্লোজ রিকনসিলিয়েশন ${res.data!.status}: পার্থক্য ৳${res.data!.varianceBdt}।'
                    : res.messageBn;
              });
              safeSheetUpdate(() {});
            }

            final serverAttempts = _serverSaleOrder?.paymentAttempts ?? const <MobilePosPaymentAttempt>[];
            final canMutateSale = _serverSaleOrder?.lifecycleState.isMutable ?? true;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  key: const Key('pos_split_payment_sheet'),
                  height: MediaQuery.of(ctx).size.height * 0.80,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _isBangla
                                    ? 'স্প্লিট পেমেন্ট ও ক্যাশিয়ার ক্লোজ'
                                    : 'Split Payments & Cashier Close',
                                style: AppTokens.titleMedium,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTokens.surfaceBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTokens.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _isBangla
                                    ? 'মোট বিল: ৳${_formatPaisa(totals.grandTotalPaisa)} | জমা: ৳${_formatPaisa(stagedTotalPaisa)} | বাকি: ৳${_formatPaisa(remainingPaisa)}'
                                    : 'Total: ৳${_formatPaisa(totals.grandTotalPaisa)} | Tendered: ৳${_formatPaisa(stagedTotalPaisa)} | Rem: ৳${_formatPaisa(remainingPaisa)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              if (estChangePaisa > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _isBangla
                                      ? 'ক্যাশ ফেরত: ৳${_formatPaisa(estChangePaisa)}'
                                      : 'Cash Change: ৳${_formatPaisa(estChangePaisa)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTokens.primaryTeal,
                                  ),
                                ),
                              ],
                              if (nonCashOverpaid) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _isBangla
                                      ? 'নন-ক্যাশ (বিকাশ/কার্ড/বাকি) মোট বিলের চেয়ে বেশি হতে পারবে না।'
                                      : 'ERR_NON_CASH_OVERPAYMENT: Non-cash total exceeds grand total.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTokens.dangerRed,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_splitSheetMessageEn != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _splitSheetState == MobilePosUiState.error ||
                                      _splitSheetState == MobilePosUiState.permissionDenied
                                  ? const Color(0xFFFEE2E2)
                                  : (_splitSheetState == MobilePosUiState.offline
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFECFEFF)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTokens.borderSubtle),
                            ),
                            child: Text(
                              _isBangla
                                  ? (_splitSheetMessageBn ?? _splitSheetMessageEn!)
                                  : _splitSheetMessageEn!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                key: const Key('pos_split_tender_dropdown'),
                                initialValue: _splitTenderType,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: _isBangla ? 'মাধ্যম' : 'Tender',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const <String>[
                                  'CASH',
                                  'BKASH',
                                  'NAGAD',
                                  'ROCKET',
                                  'UPAY',
                                  'CARD',
                                  'BANK_TRANSFER',
                                  'DUE',
                                ].map((t) => DropdownMenuItem<String>(value: t, child: Text(t))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    safeSheetUpdate(() => _splitTenderType = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                key: const Key('pos_split_amount_field'),
                                controller: _splitAmountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: _isBangla ? 'টাকা (BDT)' : 'Amount (BDT)',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                key: const Key('pos_split_ref_field'),
                                controller: _splitRefController,
                                decoration: InputDecoration(
                                  labelText: _isBangla ? 'TrxID / কার্ড শেষ ৪' : 'TrxID / Auth / Last4',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                key: const Key('pos_split_payer_field'),
                                controller: _splitPayerController,
                                decoration: InputDecoration(
                                  labelText: _isBangla ? 'প্রদানকারী (ঐচ্ছিক)' : 'Payer (Optional)',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            ElevatedButton.icon(
                              key: const Key('pos_add_split_leg_btn'),
                              onPressed: addSplitLeg,
                              icon: const Icon(Icons.add_card, size: 16),
                              label: Text(_isBangla ? 'যোগ করুন' : 'Add Split'),
                            ),
                            OutlinedButton.icon(
                              key: const Key('pos_clear_split_legs_btn'),
                              onPressed: () {
                                setState(() {
                                  _stagedSplits.clear();
                                  _splitSheetState = MobilePosUiState.empty;
                                  _splitSheetMessageEn = 'Cleared staged split legs.';
                                  _splitSheetMessageBn = 'স্টেজড স্প্লিট তালিকা খালি করা হয়েছে।';
                                });
                                safeSheetUpdate(() {});
                              },
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: Text(_isBangla ? 'মুছুন' : 'Clear'),
                            ),
                            ElevatedButton.icon(
                              key: const Key('pos_submit_splits_btn'),
                              onPressed: _loadingSplitPay ? null : submitStagedSplits,
                              icon: const Icon(Icons.payments_outlined, size: 16),
                              label: Text(_isBangla ? 'পেমেন্ট পোস্ট' : 'Post Splits'),
                            ),
                          ],
                        ),
                        if (_stagedSplits.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            _isBangla ? 'স্টেজড স্প্লিট তালিকা:' : 'Staged Split Legs:',
                            style: AppTokens.captionMuted,
                          ),
                          const SizedBox(height: 4),
                          ..._stagedSplits.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final leg = entry.value;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                dense: true,
                                title: Text('${leg.tenderType} — ৳${leg.amountBdt}'),
                                subtitle: leg.gatewayReference.isNotEmpty
                                    ? Text('Ref: ${leg.gatewayReference}')
                                    : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () {
                                    setState(() => _stagedSplits.removeAt(idx));
                                    safeSheetUpdate(() {});
                                  },
                                ),
                              ),
                            );
                          }),
                        ],
                        if (serverAttempts.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            _isBangla ? 'সার্ভার পেমেন্ট এন্ট্রি:' : 'Server Payment Attempts:',
                            style: AppTokens.captionMuted,
                          ),
                          const SizedBox(height: 4),
                          ...serverAttempts.map((a) {
                            final isPendingGw = a.verificationStatus == 'PENDING_GATEWAY';
                            final canVoid = a.status != 'VOIDED' &&
                                a.status != 'REFUNDED' &&
                                canMutateSale;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        '${a.tenderType} ৳${a.amountBdt} [${a.verificationStatus}]${(double.tryParse(a.changeGivenBdt) ?? 0) > 0 ? ' (Chg ৳${a.changeGivenBdt})' : ''}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    if (!_isOffline && _activeSaleId != null && isPendingGw)
                                      TextButton(
                                        key: Key('pos_verify_attempt_${a.attemptId}'),
                                        onPressed: () async {
                                          final r = await widget.client.verifyPaymentAttempt(
                                            bearerToken: widget.bearerToken,
                                            actorRole: widget.actorRole,
                                            actorTenantId: widget.actorTenantId,
                                            actorBranchId: widget.actorBranchId,
                                            targetTenantId: widget.targetTenantId,
                                            targetBranchId: widget.targetBranchId,
                                            saleId: _activeSaleId!,
                                            attemptId: a.attemptId,
                                            gatewayReference: _splitRefController.text.trim(),
                                            isOffline: _isOffline,
                                            subscriptionSuspended: widget.subscriptionSuspended,
                                          );
                                          if (!mounted) return;
                                          setState(() {
                                            if (r.data != null) _serverSaleOrder = r.data;
                                            _splitSheetState = r.uiState;
                                            _splitSheetMessageEn = r.messageEn;
                                            _splitSheetMessageBn = r.messageBn;
                                          });
                                          safeSheetUpdate(() {});
                                        },
                                        child: Text(_isBangla ? 'ভেরিফাই' : 'Verify'),
                                      ),
                                    if (!_isOffline && _activeSaleId != null && canVoid)
                                      TextButton(
                                        key: Key('pos_void_attempt_${a.attemptId}'),
                                        onPressed: () async {
                                          final r = await widget.client.voidPaymentAttempt(
                                            bearerToken: widget.bearerToken,
                                            actorRole: widget.actorRole,
                                            actorTenantId: widget.actorTenantId,
                                            actorBranchId: widget.actorBranchId,
                                            targetTenantId: widget.targetTenantId,
                                            targetBranchId: widget.targetBranchId,
                                            saleId: _activeSaleId!,
                                            attemptId: a.attemptId,
                                            reason: 'Cashier adjusted split tender',
                                            isOffline: _isOffline,
                                            subscriptionSuspended: widget.subscriptionSuspended,
                                          );
                                          if (!mounted) return;
                                          setState(() {
                                            if (r.data != null) _serverSaleOrder = r.data;
                                            _splitSheetState = r.uiState;
                                            _splitSheetMessageEn = r.messageEn;
                                            _splitSheetMessageBn = r.messageBn;
                                          });
                                          safeSheetUpdate(() {});
                                        },
                                        child: Text(_isBangla ? 'ভয়েড' : 'Void'),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _isBangla
                                    ? 'ক্রেডিট গ্রাহক ও বাকি আদায় (বিনা ডাবল রেভিনিউ)'
                                    : 'Customer Credit & Due Collection (No Double Revenue)',
                                style: AppTokens.titleMedium,
                              ),
                            ),
                            OutlinedButton.icon(
                              key: const Key('pos_load_customers_btn'),
                              onPressed: _loadingSplitPay
                                  ? null
                                  : () async {
                                      if (_isOffline || widget.bearerToken.isEmpty) {
                                        safeSheetUpdate(() {
                                          _splitSheetState = MobilePosUiState.offline;
                                          _splitSheetMessageEn =
                                              'Offline limitation: customer credit directory requires cloud sync.';
                                          _splitSheetMessageBn =
                                              'অফলাইন সীমাবদ্ধতা: ক্রেডিট গ্রাহক তালিকা আনতে অনলাইন সংযোগ প্রয়োজন।';
                                        });
                                        return;
                                      }
                                      safeSheetUpdate(() => _loadingSplitPay = true);
                                      final res = await widget.client.listCustomers(
                                        bearerToken: widget.bearerToken,
                                        actorRole: widget.actorRole,
                                        actorTenantId: widget.actorTenantId,
                                        actorBranchId: widget.actorBranchId,
                                        targetTenantId: widget.targetTenantId,
                                        targetBranchId: widget.targetBranchId,
                                        isOffline: _isOffline,
                                        subscriptionSuspended: widget.subscriptionSuspended,
                                      );
                                      if (!mounted) return;
                                      setState(() {
                                        _loadingSplitPay = false;
                                        if (res.data != null) _cachedCustomers = res.data!;
                                        _splitSheetState = res.uiState;
                                        _splitSheetMessageEn = res.messageEn;
                                        _splitSheetMessageBn = res.messageBn;
                                      });
                                      safeSheetUpdate(() {});
                                    },
                              icon: const Icon(Icons.people_outline, size: 16),
                              label: Text(_isBangla ? 'গ্রাহক' : 'Customers'),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              key: const Key('pos_load_dues_btn'),
                              onPressed: _loadingSplitPay
                                  ? null
                                  : () async {
                                      if (_isOffline || widget.bearerToken.isEmpty) {
                                        safeSheetUpdate(() {
                                          _splitSheetState = MobilePosUiState.offline;
                                          _splitSheetMessageEn =
                                              'Offline limitation: open dues lookup requires cloud sync.';
                                          _splitSheetMessageBn =
                                              'অফলাইন সীমাবদ্ধতা: বকেয়া তালিকা দেখতে অনলাইন সংযোগ প্রয়োজন।';
                                        });
                                        return;
                                      }
                                      safeSheetUpdate(() => _loadingSplitPay = true);
                                      final res = await widget.client.listCustomerDues(
                                        bearerToken: widget.bearerToken,
                                        actorRole: widget.actorRole,
                                        actorTenantId: widget.actorTenantId,
                                        actorBranchId: widget.actorBranchId,
                                        targetTenantId: widget.targetTenantId,
                                        targetBranchId: widget.targetBranchId,
                                        customerId: _activeCustomer?.customerId ?? '',
                                        isOffline: _isOffline,
                                        subscriptionSuspended: widget.subscriptionSuspended,
                                      );
                                      if (!mounted) return;
                                      setState(() {
                                        _loadingSplitPay = false;
                                        if (res.data != null) {
                                          _cachedCustomerDues = res.data!;
                                          final openDues = _cachedCustomerDues
                                              .where((d) => (double.tryParse(d.remainingDueBdt) ?? 0.0) > 0.0)
                                              .toList();
                                          if (openDues.isNotEmpty) _selectedDueRecord = openDues.first;
                                        }
                                        _splitSheetState = res.uiState;
                                        _splitSheetMessageEn = res.messageEn;
                                        _splitSheetMessageBn = res.messageBn;
                                      });
                                      safeSheetUpdate(() {});
                                    },
                              icon: const Icon(Icons.receipt_long_outlined, size: 16),
                              label: Text(_isBangla ? 'বাকি' : 'Dues'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTokens.surfaceBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTokens.borderSubtle),
                          ),
                          child: Text(
                            _activeCustomer == null
                                ? (_isBangla
                                    ? 'বর্তমান গ্রাহক: ওয়াক-ইন (DUE নিষ্ক্রিয়)'
                                    : 'Customer: Walk-in (Select approved customer for DUE)')
                                : 'Customer: ${_activeCustomer!.fullName} | ${_activeCustomer!.creditStatus} | Avail: ৳${_activeCustomer!.availableCreditBdt}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (_cachedCustomers.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _cachedCustomers.map((c) {
                              final selected = _activeCustomer?.customerId == c.customerId;
                              return OutlinedButton(
                                key: Key('pos_customer_select_${c.customerId}'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: selected ? const Color(0xFFCCFBF1) : null,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 32),
                                ),
                                onPressed: () async {
                                  setState(() => _activeCustomer = c);
                                  if (!_isOffline && _activeSaleId != null && widget.bearerToken.isNotEmpty) {
                                    final att = await widget.client.attachCustomerToSale(
                                      bearerToken: widget.bearerToken,
                                      actorRole: widget.actorRole,
                                      actorTenantId: widget.actorTenantId,
                                      actorBranchId: widget.actorBranchId,
                                      targetTenantId: widget.targetTenantId,
                                      targetBranchId: widget.targetBranchId,
                                      saleId: _activeSaleId!,
                                      customerId: c.customerId,
                                      isOffline: _isOffline,
                                      subscriptionSuspended: widget.subscriptionSuspended,
                                    );
                                    if (mounted && att.data != null) {
                                      setState(() => _serverSaleOrder = att.data);
                                    }
                                  }
                                  safeSheetUpdate(() {
                                    _splitSheetState = MobilePosUiState.ready;
                                    _splitSheetMessageEn =
                                        'Attached ${c.fullName} (${c.creditStatus}, Avail ৳${c.availableCreditBdt}).';
                                    _splitSheetMessageBn =
                                        'গ্রাহক ${c.fullName} যুক্ত হয়েছে (${c.creditStatus})।';
                                  });
                                },
                                child: Text('${c.fullName} (${c.creditStatus})', style: const TextStyle(fontSize: 11)),
                              );
                            }).toList(),
                          ),
                        ],
                        if (_cachedCustomerDues.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _cachedCustomerDues
                                .where((d) => (double.tryParse(d.remainingDueBdt) ?? 0.0) > 0.0)
                                .map((d) {
                              final sel = _selectedDueRecord?.dueId == d.dueId;
                              return OutlinedButton(
                                key: Key('pos_select_due_${d.dueId}'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: sel ? const Color(0xFFCCFBF1) : null,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 32),
                                ),
                                onPressed: () => safeSheetUpdate(() => _selectedDueRecord = d),
                                child: Text('${d.dueId}: ৳${d.remainingDueBdt}', style: const TextStyle(fontSize: 11)),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  key: const Key('pos_due_collect_tender_dropdown'),
                                  initialValue: _dueCollectTender,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: _isBangla ? 'আদায় মাধ্যম' : 'Collect Via',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: const <String>[
                                    'CASH',
                                    'BKASH',
                                    'NAGAD',
                                    'ROCKET',
                                    'UPAY',
                                    'CARD',
                                    'BANK_TRANSFER',
                                  ].map((t) => DropdownMenuItem<String>(value: t, child: Text(t))).toList(),
                                  onChanged: (v) {
                                    if (v != null) safeSheetUpdate(() => _dueCollectTender = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  key: const Key('pos_due_collect_amount_field'),
                                  controller: _dueCollectAmountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: _isBangla ? 'আদায় (BDT)' : 'Collect (BDT)',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  key: const Key('pos_due_collect_ref_field'),
                                  controller: _dueCollectRefController,
                                  decoration: InputDecoration(
                                    labelText: _isBangla ? 'TrxID (ডিজিটাল)' : 'TrxID (MFS/Card)',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ElevatedButton.icon(
                            key: const Key('pos_collect_due_btn'),
                            onPressed: _loadingSplitPay || _selectedDueRecord == null
                                ? null
                                : () async {
                                    safeSheetUpdate(() => _loadingSplitPay = true);
                                    final res = await widget.client.collectCustomerDue(
                                      bearerToken: widget.bearerToken,
                                      actorRole: widget.actorRole,
                                      actorTenantId: widget.actorTenantId,
                                      actorBranchId: widget.actorBranchId,
                                      targetTenantId: widget.targetTenantId,
                                      targetBranchId: widget.targetBranchId,
                                      dueId: _selectedDueRecord!.dueId,
                                      tenderType: _dueCollectTender,
                                      amountBdt: _dueCollectAmountController.text.trim(),
                                      gatewayReference: _dueCollectRefController.text.trim(),
                                      idempotencyKey: 'm-dcol-${DateTime.now().microsecondsSinceEpoch}',
                                      isOffline: _isOffline,
                                      subscriptionSuspended: widget.subscriptionSuspended,
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      _loadingSplitPay = false;
                                      if (res.data != null) {
                                        _dueCollectAmountController.clear();
                                        _dueCollectRefController.clear();
                                        _cachedCustomerDues = _cachedCustomerDues
                                            .map((d) => d.dueId == res.data!.dueRecord.dueId ? res.data!.dueRecord : d)
                                            .toList();
                                        _selectedDueRecord = res.data!.dueRecord;
                                      }
                                      _splitSheetState = res.uiState;
                                      _splitSheetMessageEn = res.messageEn;
                                      _splitSheetMessageBn = res.messageBn;
                                    });
                                    safeSheetUpdate(() {});
                                  },
                            icon: const Icon(Icons.task_alt_outlined, size: 16),
                            label: Text(_isBangla ? 'বাকি আদায় জমা' : 'Collect Due Payment'),
                          ),
                        ],
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _isBangla ? 'ক্যাশিয়ার শিফট ক্লোজ' : 'Cashier Shift Close Reconciliation',
                                style: AppTokens.titleMedium,
                              ),
                            ),
                            OutlinedButton.icon(
                              key: const Key('pos_refresh_close_recon_btn'),
                              onPressed: _loadingSplitPay ? null : refreshCloseRecon,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: Text(_isBangla ? 'শিফট লোড' : 'Load Shift'),
                            ),
                          ],
                        ),
                        if (_closeReconCache != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTokens.surfaceBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTokens.borderSubtle),
                            ),
                            child: Text(
                              'Expected Cash: ৳${_closeReconCache!.expectedDrawerCashBdt} | Digital: ৳${_closeReconCache!.digitalTotalBdt} | Due: ৳${_closeReconCache!.dueIssuedBdt} | Due Col Cash: ৳${_closeReconCache!.dueCollectedCashBdt} | Status: ${_closeReconCache!.status} | Variance: ৳${_closeReconCache!.varianceBdt}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                key: const Key('pos_close_counted_cash_field'),
                                controller: _closeCountedCashController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: _isBangla ? 'গননাকৃত নগদ (BDT)' : 'Counted Cash (BDT)',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                key: const Key('pos_close_notes_field'),
                                controller: _closeNotesController,
                                decoration: InputDecoration(
                                  labelText: _isBangla ? 'নোট (ঐচ্ছিক)' : 'Notes (Optional)',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          key: const Key('pos_submit_close_recon_btn'),
                          onPressed: _loadingSplitPay ? null : submitCloseRecon,
                          icon: const Icon(Icons.lock_clock_outlined, size: 16),
                          label: Text(_isBangla ? 'শিফট ক্লোজ জমা দিন' : 'Submit Close Reconciliation'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    sheetActive = false;
  }

  Future<void> _openFefoPlanSheet() async {
    _fefoSheetState = null;
    _fefoSheetMessageEn = null;
    _fefoSheetMessageBn = null;
    if (!_isOffline && _activeSaleId != null && widget.bearerToken.isNotEmpty) {
      final pre = await widget.client.getFefoPlan(
        bearerToken: widget.bearerToken,
        actorRole: widget.actorRole,
        actorTenantId: widget.actorTenantId,
        actorBranchId: widget.actorBranchId,
        targetTenantId: widget.targetTenantId,
        targetBranchId: widget.targetBranchId,
        saleId: _activeSaleId!,
        isOffline: _isOffline,
        subscriptionSuspended: widget.subscriptionSuspended,
      );
      if (!mounted) return;
      setState(() {
        if (pre.data != null) _fefoPlanCache = pre.data;
        _fefoSheetState = pre.uiState;
        _fefoSheetMessageEn = pre.messageEn;
        _fefoSheetMessageBn = pre.messageBn;
      });
    }
    final batchCtrl = _fefoOverrideBatchController;
    final reasonCtrl = _fefoOverrideReasonController;
    var sheetActive = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void safeSheetUpdate(VoidCallback fn) {
              if (!sheetActive || !ctx.mounted) return;
              setSheetState(fn);
            }

            Future<void> refreshPlan() async {
              if (_isOffline || _activeSaleId == null || widget.bearerToken.isEmpty) {
                safeSheetUpdate(() {
                  _fefoSheetState = MobilePosUiState.offline;
                  _fefoSheetMessageEn =
                      'Offline limitation: live FEFO plan requires cloud connectivity (OFFLINE_PROVISIONAL_FEFO cached check active).';
                  _fefoSheetMessageBn =
                      'অফলাইন সীমাবদ্ধতা: লাইভ FEFO লট দেখতে সার্ভার সংযোগ প্রয়োজন।';
                });
                return;
              }
              safeSheetUpdate(() => _loadingFefo = true);
              final res = await widget.client.getFefoPlan(
                bearerToken: widget.bearerToken,
                actorRole: widget.actorRole,
                actorTenantId: widget.actorTenantId,
                actorBranchId: widget.actorBranchId,
                targetTenantId: widget.targetTenantId,
                targetBranchId: widget.targetBranchId,
                saleId: _activeSaleId!,
                isOffline: _isOffline,
                subscriptionSuspended: widget.subscriptionSuspended,
              );
              if (!mounted) return;
              setState(() {
                _loadingFefo = false;
                if (res.data != null) {
                  _fefoPlanCache = res.data;
                }
                _fefoSheetState = res.uiState;
                _fefoSheetMessageEn = res.messageEn;
                _fefoSheetMessageBn = res.messageBn;
                _uiState = res.uiState;
                _statusMessageEn = res.messageEn;
                _statusMessageBn = res.messageBn;
              });
              safeSheetUpdate(() {});
            }

            Future<void> reserveFefo() async {
              if (_activeSaleId == null || widget.bearerToken.isEmpty || _isOffline) {
                safeSheetUpdate(() {
                  _fefoSheetState = _isOffline ? MobilePosUiState.offline : MobilePosUiState.empty;
                  _fefoSheetMessageEn = _isOffline
                      ? 'Offline limitation: server batch reservation requires connectivity.'
                      : 'Open an active server cart before reserving FEFO lots.';
                  _fefoSheetMessageBn = _isOffline
                      ? 'অফলাইন সীমাবদ্ধতা: ব্যাচ রিজার্ভ করতে সার্ভার সংযোগ প্রয়োজন।'
                      : 'ব্যাচ রিজার্ভের আগে সক্রিয় কার্ট খুলুন।';
                });
                return;
              }
              final batchOverrideText = batchCtrl.text.trim();
              final reasonText = reasonCtrl.text.trim();
              final targetLineId = (_serverSaleOrder?.lines.isNotEmpty ?? false)
                  ? _serverSaleOrder!.lines.first.lineId
                  : (_fefoPlanCache?.lines.isNotEmpty ?? false ? _fefoPlanCache!.lines.first.lineId : '');
              final overrides = (batchOverrideText.isNotEmpty && targetLineId.isNotEmpty)
                  ? <String, String>{targetLineId: batchOverrideText}
                  : null;
              safeSheetUpdate(() => _loadingFefo = true);
              final res = await widget.client.allocateStockFefo(
                bearerToken: widget.bearerToken,
                actorRole: widget.actorRole,
                actorTenantId: widget.actorTenantId,
                actorBranchId: widget.actorBranchId,
                targetTenantId: widget.targetTenantId,
                targetBranchId: widget.targetBranchId,
                saleId: _activeSaleId!,
                batchOverrides: overrides,
                overrideReason: reasonText,
                expectedVersion: _serverSaleOrder?.version,
                isOffline: _isOffline,
                subscriptionSuspended: widget.subscriptionSuspended,
              );
              if (!mounted) return;
              setState(() {
                _loadingFefo = false;
                _fefoSheetState = res.uiState;
                _fefoSheetMessageEn = res.messageEn;
                _fefoSheetMessageBn = res.messageBn;
                _uiState = res.uiState;
                _statusMessageEn = res.messageEn;
                _statusMessageBn = res.messageBn;
                if (res.uiState == MobilePosUiState.ready && res.data != null) {
                  _restoreServerSaleToActiveCounter(res.data!);
                  if (overrides != null) {
                    _fefoBatchOverrides = overrides;
                    _fefoOverrideReason = reasonText;
                  }
                }
              });
              safeSheetUpdate(() {});
            }

            final plan = _fefoPlanCache;
            final statusLabel = _isOffline
                ? 'OFFLINE_PROVISIONAL_FEFO'
                : (plan != null
                    ? (plan.fefoReady ? plan.fefoAllocationStatus : 'BLOCKED')
                    : (_serverSaleOrder?.fefoAllocationStatus ?? 'PENDING'));
            return SafeArea(
              child: SingleChildScrollView(
                key: const Key('pos_fefo_plan_sheet'),
                padding: EdgeInsets.fromLTRB(
                  AppTokens.space16,
                  AppTokens.space16,
                  AppTokens.space16,
                  MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.layers_outlined, size: 20, color: AppTokens.primaryTeal),
                        const SizedBox(width: AppTokens.space8),
                        Expanded(
                          child: Text(
                            _isBangla ? 'FEFO লট বরাদ্দ ও স্টক নিরাপত্তা' : 'FEFO Lot Plan & Stock Safety',
                            style: AppTokens.titleMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusLabel == 'BLOCKED'
                                ? const Color(0xFFFEE2E2)
                                : (statusLabel == 'RESERVED' || statusLabel == 'COMMITTED'
                                    ? const Color(0xFFD1E7DD)
                                    : const Color(0xFFE0F2FE)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: AppTokens.captionMuted.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          key: const Key('pos_fefo_refresh_btn'),
                          onPressed: _loadingFefo ? null : refreshPlan,
                          icon: const Icon(Icons.refresh, size: 18),
                          tooltip: _isBangla ? 'প্ল্যান রিফ্রেশ' : 'Refresh FEFO Plan',
                        ),
                      ],
                    ),
                    if (_loadingFefo) ...[
                      const SizedBox(height: AppTokens.space8),
                      const LinearProgressIndicator(),
                    ],
                    if ((_fefoSheetMessageEn ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppTokens.space8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTokens.space8),
                        decoration: BoxDecoration(
                          color: _fefoSheetState == MobilePosUiState.ready
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
                          border: Border.all(
                            color: _fefoSheetState == MobilePosUiState.ready
                                ? AppTokens.primaryTeal
                                : AppTokens.warningAmber,
                          ),
                        ),
                        child: Text(
                          _isBangla ? (_fefoSheetMessageBn ?? _fefoSheetMessageEn!) : _fefoSheetMessageEn!,
                          style: AppTokens.captionMuted.copyWith(color: AppTokens.textPrimary),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space8),
                    if (plan == null && _serverSaleOrder == null)
                      Text(
                        _isBangla
                            ? 'সক্রিয় কার্ট বা অনলাইন সংযোগ ছাড়া লাইভ লট প্ল্যান পাওয়া যায়নি।'
                            : 'Load or add medicines to inspect server FEFO lot selection.',
                        style: AppTokens.captionMuted,
                      ),
                    if (plan != null)
                      for (final ln in plan.lines) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: AppTokens.space8),
                          child: Text(
                            '${ln.brandName} (${ln.plannedBaseUnits}/${ln.requestedBaseUnits} base u)',
                            style: AppTokens.titleMedium,
                          ),
                        ),
                        for (final lot in ln.plannedLots)
                          Text(
                            '• ${lot.batchNumber} (${lot.batchId}) — ${lot.allocatedBaseUnits}u · Exp ${lot.expiryDate} [${lot.allocationMode}]',
                            style: AppTokens.captionMuted.copyWith(color: AppTokens.textPrimary),
                          ),
                        for (final blk in ln.blockedLots)
                          Text(
                            'BLOCKED [${blk.blockCategory}] ${blk.batchNumber}: ${blk.reason}',
                            style: AppTokens.captionMuted.copyWith(color: const Color(0xFF991B1B)),
                          ),
                      ],
                    const SizedBox(height: AppTokens.space12),
                    TextField(
                      key: const Key('pos_fefo_override_batch_field'),
                      controller: batchCtrl,
                      decoration: InputDecoration(
                        labelText: _isBangla
                            ? 'ঐচ্ছিক ওভাররাইড ব্যাচ আইডি (ফার্মাসিস্ট/ম্যানেজার)'
                            : 'Optional Override Batch ID (Pharmacist/Manager)',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    TextField(
                      key: const Key('pos_fefo_override_reason_field'),
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        labelText: _isBangla
                            ? 'ওভাররাইডের কারণ (>= ৩ অক্ষর)'
                            : 'Override Reason (>= 3 chars if bypassing FEFO)',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loadingFefo ? null : refreshPlan,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: Text(_isBangla ? 'প্ল্যান রিফ্রেশ' : 'Refresh Plan'),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space8),
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const Key('pos_fefo_reserve_btn'),
                            onPressed: _loadingFefo ? null : reserveFefo,
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: Text(_isBangla ? 'FEFO রিজার্ভ' : 'Reserve FEFO'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    sheetActive = false;
  }

  Future<void> _openRxGateSheet() async {
    if (_rxGateStatusCache?.doctorName.isNotEmpty ?? false) {
      _rxDoctorNameController.text = _rxGateStatusCache!.doctorName;
    }
    if (_rxGateStatusCache?.doctorBmdcNo.isNotEmpty ?? false) {
      _rxDoctorBmdcController.text = _rxGateStatusCache!.doctorBmdcNo;
    }
    if (_rxGateStatusCache?.patientToken.isNotEmpty ?? false) {
      _rxPatientController.text = _rxGateStatusCache!.patientToken;
    }
    final preRef = (_serverSaleOrder?.rxReferenceCode.isNotEmpty ?? false)
        ? _serverSaleOrder!.rxReferenceCode
        : (_rxGateStatusCache?.rxReferenceCode ?? '');
    if (preRef.isNotEmpty) {
      _rxRefController.text = preRef;
    }
    if (_serverSaleOrder?.pharmacistPcbNoSnapshot.isNotEmpty ?? false) {
      _rxPcbController.text = _serverSaleOrder!.pharmacistPcbNoSnapshot;
    }
    final doctorNameCtrl = _rxDoctorNameController;
    final doctorBmdcCtrl = _rxDoctorBmdcController;
    final patientCtrl = _rxPatientController;
    final rxRefCtrl = _rxRefController;
    final pcbCtrl = _rxPcbController;
    final notesCtrl = _rxNotesController;

    var sheetActive = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void safeSheetUpdate(VoidCallback fn) {
              if (!sheetActive || !ctx.mounted) return;
              setSheetState(fn);
            }

            Future<void> refreshGateAndRegister() async {
              safeSheetUpdate(() => _loadingRxGate = true);
              if (!_isOffline && _activeSaleId != null && widget.bearerToken.isNotEmpty) {
                final gRes = await widget.client.getRxGateStatus(
                  bearerToken: widget.bearerToken,
                  actorRole: widget.actorRole,
                  actorTenantId: widget.actorTenantId,
                  actorBranchId: widget.actorBranchId,
                  targetTenantId: widget.targetTenantId,
                  targetBranchId: widget.targetBranchId,
                  saleId: _activeSaleId!,
                  isOffline: _isOffline,
                  subscriptionSuspended: widget.subscriptionSuspended,
                );
                if (!mounted) return;
                if (gRes.uiState == MobilePosUiState.ready && gRes.data != null) {
                  setState(() => _rxGateStatusCache = gRes.data);
                }
              }
              final abxRes = await widget.client.listAntibioticRegister(
                bearerToken: widget.bearerToken,
                actorRole: widget.actorRole,
                actorTenantId: widget.actorTenantId,
                actorBranchId: widget.actorBranchId,
                targetTenantId: widget.targetTenantId,
                targetBranchId: widget.targetBranchId,
                isOffline: _isOffline,
                subscriptionSuspended: widget.subscriptionSuspended,
              );
              if (!mounted) return;
              setState(() {
                _loadingRxGate = false;
                if (abxRes.data != null) {
                  _abxRegisterEntries = abxRes.data!.results;
                  _abxRegisterCount = abxRes.data!.count;
                }
                _rxSheetState = abxRes.uiState;
                _rxSheetMessageEn = abxRes.messageEn;
                _rxSheetMessageBn = abxRes.messageBn;
              });
              safeSheetUpdate(() {});
            }

            Future<void> handleAttachRx() async {
              if (_activeSaleId == null || widget.bearerToken.isEmpty || _isOffline) {
                setState(() {
                  _rxSheetState = _isOffline ? MobilePosUiState.offline : MobilePosUiState.empty;
                  _rxSheetMessageEn = _isOffline
                      ? 'Offline limitation: prescription upload requires online server connection.'
                      : 'Open an active server cart before attaching prescription.';
                  _rxSheetMessageBn = _isOffline
                      ? 'অফলাইন সীমাবদ্ধতা: প্রেসক্রিপশন সংযুক্ত করতে সার্ভার সংযোগ প্রয়োজন।'
                      : 'প্রেসক্রিপশন সংযুক্ত করার আগে একটি সক্রিয় কার্ট খুলুন।';
                });
                safeSheetUpdate(() {});
                return;
              }
              safeSheetUpdate(() => _loadingRxGate = true);
              final res = await widget.client.attachPrescription(
                bearerToken: widget.bearerToken,
                actorRole: widget.actorRole,
                actorTenantId: widget.actorTenantId,
                actorBranchId: widget.actorBranchId,
                targetTenantId: widget.targetTenantId,
                targetBranchId: widget.targetBranchId,
                saleId: _activeSaleId!,
                doctorName: doctorNameCtrl.text.trim(),
                doctorBmdcNo: doctorBmdcCtrl.text.trim(),
                patientToken: patientCtrl.text.trim(),
                rxReferenceCode: rxRefCtrl.text.trim(),
                expectedVersion: _serverSaleOrder?.version,
                isOffline: _isOffline,
                subscriptionSuspended: widget.subscriptionSuspended,
              );
              if (!mounted) return;
              setState(() {
                _loadingRxGate = false;
                _rxSheetState = res.uiState;
                _rxSheetMessageEn = res.messageEn;
                _rxSheetMessageBn = res.messageBn;
                _uiState = res.uiState;
                _statusMessageEn = res.messageEn;
                _statusMessageBn = res.messageBn;
                if (res.uiState == MobilePosUiState.ready && res.data != null) {
                  _restoreServerSaleToActiveCounter(res.data!);
                }
              });
              safeSheetUpdate(() {});
            }

            Future<void> handleVerifyRx() async {
              if (_activeSaleId == null || widget.bearerToken.isEmpty || _isOffline) {
                setState(() {
                  _rxSheetState = _isOffline ? MobilePosUiState.offline : MobilePosUiState.empty;
                  _rxSheetMessageEn = _isOffline
                      ? 'Offline limitation: Pharmacist Rx verification cannot run offline.'
                      : 'Open an active server cart first.';
                  _rxSheetMessageBn = _isOffline
                      ? 'অফলাইন সীমাবদ্ধতা: ফার্মাসিস্ট Rx অনুমোদন অফলাইনে দেওয়া যাবে না।'
                      : 'প্রথমে সক্রিয় কার্ট খুলুন।';
                });
                safeSheetUpdate(() {});
                return;
              }
              safeSheetUpdate(() => _loadingRxGate = true);
              final res = await widget.client.verifyRxSale(
                bearerToken: widget.bearerToken,
                actorRole: widget.actorRole,
                actorTenantId: widget.actorTenantId,
                actorBranchId: widget.actorBranchId,
                targetTenantId: widget.targetTenantId,
                targetBranchId: widget.targetBranchId,
                saleId: _activeSaleId!,
                pharmacistPcbNo: pcbCtrl.text.trim(),
                notes: notesCtrl.text.trim(),
                rxReferenceCode: rxRefCtrl.text.trim(),
                doctorName: doctorNameCtrl.text.trim(),
                doctorBmdcNo: doctorBmdcCtrl.text.trim(),
                expectedVersion: _serverSaleOrder?.version,
                isOffline: _isOffline,
                subscriptionSuspended: widget.subscriptionSuspended,
              );
              if (!mounted) return;
              setState(() {
                _loadingRxGate = false;
                _rxSheetState = res.uiState;
                _rxSheetMessageEn = res.messageEn;
                _rxSheetMessageBn = res.messageBn;
                _uiState = res.uiState;
                _statusMessageEn = res.messageEn;
                _statusMessageBn = res.messageBn;
                if (res.uiState == MobilePosUiState.ready && res.data != null) {
                  _restoreServerSaleToActiveCounter(res.data!);
                }
              });
              safeSheetUpdate(() {});
            }

            Future<void> handleRejectRx() async {
              if (_activeSaleId == null || widget.bearerToken.isEmpty || _isOffline) {
                setState(() {
                  _rxSheetState = _isOffline ? MobilePosUiState.offline : MobilePosUiState.empty;
                  _rxSheetMessageEn = _isOffline
                      ? 'Offline limitation: Pharmacist Rx rejection requires server connection.'
                      : 'Open an active server cart first.';
                  _rxSheetMessageBn = _isOffline
                      ? 'অফলাইন সীমাবদ্ধতা: Rx প্রত্যাখ্যান করতে সার্ভার সংযোগ প্রয়োজন।'
                      : 'প্রথমে সক্রিয় কার্ট খুলুন।';
                });
                safeSheetUpdate(() {});
                return;
              }
              safeSheetUpdate(() => _loadingRxGate = true);
              final res = await widget.client.rejectRxSale(
                bearerToken: widget.bearerToken,
                actorRole: widget.actorRole,
                actorTenantId: widget.actorTenantId,
                actorBranchId: widget.actorBranchId,
                targetTenantId: widget.targetTenantId,
                targetBranchId: widget.targetBranchId,
                saleId: _activeSaleId!,
                pharmacistPcbNo: pcbCtrl.text.trim(),
                reason: notesCtrl.text.trim(),
                expectedVersion: _serverSaleOrder?.version,
                isOffline: _isOffline,
                subscriptionSuspended: widget.subscriptionSuspended,
              );
              if (!mounted) return;
              setState(() {
                _loadingRxGate = false;
                _rxSheetState = res.uiState;
                _rxSheetMessageEn = res.messageEn;
                _rxSheetMessageBn = res.messageBn;
                _uiState = res.uiState;
                _statusMessageEn = res.messageEn;
                _statusMessageBn = res.messageBn;
                if (res.uiState == MobilePosUiState.ready && res.data != null) {
                  _restoreServerSaleToActiveCounter(res.data!);
                }
              });
              safeSheetUpdate(() {});
            }

            final gateLabel = _effectiveRxGateBadge;
            final sheetMsg = _isBangla ? (_rxSheetMessageBn ?? '') : (_rxSheetMessageEn ?? '');

            return Padding(
              key: const Key('pos_rx_gate_sheet'),
              padding: EdgeInsets.only(
                left: AppTokens.space16,
                right: AppTokens.space16,
                top: AppTokens.space16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.verified_user_outlined, color: AppTokens.primaryTeal),
                        const SizedBox(width: AppTokens.space8),
                        Expanded(
                          child: Text(
                            _isBangla ? 'প্রেসক্রিপশন সেফটি গেট ($gateLabel)' : 'Prescription Safety Gate ($gateLabel)',
                            style: AppTokens.titleMedium,
                          ),
                        ),
                        IconButton(
                          key: const Key('pos_abx_register_refresh_btn'),
                          tooltip: _isBangla ? 'অ্যান্টিবায়োটিক রেজিস্টার রিফ্রেশ' : 'Refresh Abx Register',
                          onPressed: refreshGateAndRegister,
                          icon: const Icon(Icons.menu_book_outlined),
                        ),
                      ],
                    ),
                    if (_loadingRxGate) const LinearProgressIndicator(),
                    if (sheetMsg.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppTokens.space8),
                      Text(
                        sheetMsg,
                        key: const Key('pos_rx_sheet_status'),
                        style: AppTokens.captionMuted.copyWith(
                          color: (_rxSheetState == MobilePosUiState.error ||
                                  _rxSheetState == MobilePosUiState.permissionDenied)
                              ? AppTokens.dangerRed
                              : (_rxSheetState == MobilePosUiState.offline
                                  ? AppTokens.warningAmber
                                  : AppTokens.successGreen),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            key: const Key('pos_rx_doctor_name_input'),
                            controller: doctorNameCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: _isBangla ? 'চিকিৎসকের নাম' : 'Doctor Name',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space8),
                        Expanded(
                          child: TextField(
                            key: const Key('pos_rx_doctor_bmdc_input'),
                            controller: doctorBmdcCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: _isBangla ? 'BMDC রেজি' : 'BMDC Reg No.',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            key: const Key('pos_rx_patient_input'),
                            controller: patientCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: _isBangla ? 'রোগীর রেফ' : 'Patient Ref',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space8),
                        Expanded(
                          child: TextField(
                            key: const Key('pos_rx_ref_input'),
                            controller: rxRefCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: _isBangla ? 'Rx রেফারেন্স' : 'Rx Reference',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        key: const Key('pos_rx_attach_btn'),
                        onPressed: handleAttachRx,
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: Text(_isBangla ? 'Rx সংযুক্ত করুন' : 'Attach Rx'),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            key: const Key('pos_rx_pcb_input'),
                            controller: pcbCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: _isBangla ? 'ফার্মাসিস্ট PCB রেজি' : 'Pharmacist PCB Reg',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space8),
                        Expanded(
                          child: TextField(
                            key: const Key('pos_rx_notes_input'),
                            controller: notesCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: _isBangla ? 'অনুমোদন / বাতিলের কারণ' : 'Notes / Reject Reason',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space12),
                    Wrap(
                      spacing: AppTokens.space8,
                      runSpacing: AppTokens.space8,
                      children: <Widget>[
                        ElevatedButton.icon(
                          key: const Key('pos_rx_approve_btn'),
                          onPressed: handleVerifyRx,
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: Text(_isBangla ? 'Rx অনুমোদন' : 'Approve Rx'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('pos_rx_reject_btn'),
                          onPressed: handleRejectRx,
                          icon: const Icon(Icons.cancel_outlined, size: 16, color: AppTokens.dangerRed),
                          label: Text(
                            _isBangla ? 'Rx প্রত্যাখ্যান' : 'Reject Rx',
                            style: const TextStyle(color: AppTokens.dangerRed),
                          ),
                        ),
                      ],
                    ),
                    if (_abxRegisterEntries.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppTokens.space12),
                      Text(
                        _isBangla
                            ? 'অ্যান্টিবায়োটিক রেজিস্টার ($_abxRegisterCount)'
                            : 'Antibiotic Dispense Register ($_abxRegisterCount)',
                        style: AppTokens.titleMedium,
                      ),
                      const SizedBox(height: AppTokens.space4),
                      ListView.builder(
                        key: const Key('pos_abx_register_list'),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _abxRegisterEntries.length > 5 ? 5 : _abxRegisterEntries.length,
                        itemBuilder: (_, idx) {
                          final row = _abxRegisterEntries[idx];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.medication_outlined, size: 18, color: AppTokens.primaryTeal),
                            title: Text('${row.brandName} (${row.dispensedBaseUnits}u)'),
                            subtitle: Text('PCB ${row.approvingPharmacistPcbNo} | ${row.status}'),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    sheetActive = false;
  }

  Widget _buildStaleConfirmationBanner() {
    if (_pendingStaleEntry == null || _pendingStaleStaleness == null) {
      return const SizedBox.shrink();
    }
    final entry = _pendingStaleEntry!;
    final stale = _pendingStaleStaleness!;
    final reasonStr = stale.staleReasons.join(', ');
    final promptText = _isBangla
        ? (stale.userPromptBn.isNotEmpty
            ? stale.userPromptBn
            : 'হোল্ড করা কার্টে মূল্য বা স্টক পরিবর্তন হয়েছে। নিশ্চিত হয়ে রিজিউম করুন।')
        : (stale.userPromptEn.isNotEmpty
            ? stale.userPromptEn
            : 'Held cart has stale price/stock changes. Confirm to reprice and resume.');
    return Container(
      key: const Key('pos_stale_confirm_banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTokens.space12),
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
        border: Border.all(color: AppTokens.warningAmber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.warning_amber_rounded, color: AppTokens.warningAmber, size: 18),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  '${entry.holdReference.isNotEmpty ? entry.holdReference : entry.orderNumber} '
                  '${reasonStr.isNotEmpty ? '($reasonStr)' : ''}',
                  style: AppTokens.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            '$promptText (Held: ${stale.heldGrandTotalBdt} -> Live: ${stale.liveGrandTotalBdt} BDT)',
            style: AppTokens.captionMuted.copyWith(color: AppTokens.textPrimary),
          ),
          const SizedBox(height: AppTokens.space8),
          Wrap(
            spacing: AppTokens.space8,
            runSpacing: AppTokens.space4,
            children: <Widget>[
              ElevatedButton.icon(
                key: const Key('pos_ack_stale_resume_btn'),
                onPressed: () => _resumeHeldEntry(entry, acknowledgeStale: true),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text(_isBangla ? 'নিশ্চিত ও রিজিউম' : 'Confirm & Resume'),
              ),
              TextButton(
                key: const Key('pos_dismiss_stale_btn'),
                onPressed: () => setState(() {
                  _pendingStaleEntry = null;
                  _pendingStaleStaleness = null;
                }),
                child: Text(_isBangla ? 'বাতিল' : 'Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.surfaceBackground,
      appBar: AppBar(
        backgroundColor: AppTokens.cardSurface,
        foregroundColor: AppTokens.textPrimary,
        elevation: 0,
        title: Text(
          _isBangla ? 'দ্রুত সার্চ ও বারকোড কার্ট' : 'Fast Search & Barcode Cart',
          style: AppTokens.titleMedium,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          TextButton.icon(
            key: const Key('pos_held_carts_btn'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 36),
            ),
            onPressed: _openHeldCartsSheet,
            icon: const Icon(Icons.pause_circle_outline, size: 16),
            label: Text(
              _heldCartCount > 0
                  ? '${_isBangla ? 'হোল্ড' : 'Held'} ($_heldCartCount)'
                  : (_isBangla ? 'হোল্ড' : 'Held'),
            ),
          ),
          TextButton.icon(
            key: const Key('pos_deliveries_btn'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 36),
            ),
            onPressed: _openDeliveriesSheet,
            icon: const Icon(Icons.local_shipping_outlined, size: 16),
            label: Text(
              _deliveryCount > 0
                  ? '${_isBangla ? 'ডেলিভারি' : 'Deliveries'} ($_deliveryCount)'
                  : (_isBangla ? 'ডেলিভারি' : 'Deliveries'),
            ),
          ),
          TextButton.icon(
            key: const Key('pos_split_pay_btn'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 36),
            ),
            onPressed: _openSplitPaymentSheet,
            icon: Icon(
              Icons.payments_outlined,
              size: 16,
              color: _stagedSplits.isNotEmpty ? AppTokens.primaryTealDark : AppTokens.primaryTeal,
            ),
            label: Text(
              _stagedSplits.isEmpty
                  ? (_isBangla ? 'পে' : 'Pay')
                  : '${_isBangla ? 'পে' : 'Pay'}(${_stagedSplits.length})',
            ),
          ),
          TextButton.icon(
            key: const Key('pos_fefo_plan_btn'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 36),
            ),
            onPressed: _openFefoPlanSheet,
            icon: Icon(
              Icons.layers_outlined,
              size: 16,
              color: (_fefoPlanCache != null && !_fefoPlanCache!.fefoReady)
                  ? AppTokens.warningAmber
                  : AppTokens.primaryTeal,
            ),
            label: Text(
              (_fefoPlanCache != null && !_fefoPlanCache!.fefoReady)
                  ? (_isBangla ? 'FEFO!' : 'FEFO!')
                  : 'FEFO',
            ),
          ),
          TextButton.icon(
            key: const Key('pos_rx_gate_btn'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 36),
            ),
            onPressed: _openRxGateSheet,
            icon: Icon(
              Icons.verified_user_outlined,
              size: 16,
              color: _cartHasBlockedRecall || (_cartRequiresRx && !_isCartRxApprovedForCheckout)
                  ? AppTokens.warningAmber
                  : AppTokens.primaryTeal,
            ),
            label: Text(
              _isCartRxApprovedForCheckout && _cartRequiresRx
                  ? (_isBangla ? 'Rx অনুমোদিত' : 'Rx OK')
                  : (_cartRequiresRx
                      ? (_isBangla ? 'Rx আবশ্যক' : 'Rx Gate!')
                      : 'Rx'),
            ),
          ),
          IconButton(
            tooltip: _isBangla ? 'অফলাইন স্ন্যাপশট সিঙ্ক' : 'Sync Offline Snapshot',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
            icon: const Icon(Icons.sync, size: 18),
            onPressed: () async {
              final res = await widget.client.refreshLocalSnapshotCache(
                targetBranchId: widget.targetBranchId,
                bearerToken: widget.bearerToken,
              );
              if (!mounted) return;
              setState(() {
                _uiState = res.uiState;
                _statusMessageEn = res.messageEn;
                _statusMessageBn = res.messageBn;
              });
            },
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 36),
            ),
            onPressed: () => setState(() => _isBangla = !_isBangla),
            icon: const Icon(Icons.language, size: 16),
            label: Text(_isBangla ? 'EN' : 'বাংলা'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTokens.space12),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('pos_search_input'),
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _runSearch,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(CupertinoIcons.barcode_viewfinder),
                      hintText: _isBangla
                          ? 'বারকোড স্ক্যান বা ব্র্যান্ড/জেনেরিক লিখুন...'
                          : 'Scan barcode or search brand / generic...',
                      filled: true,
                      fillColor: AppTokens.cardSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                        borderSide: const BorderSide(color: AppTokens.borderSubtle),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
                SizedBox(
                  height: AppTokens.minTouchTarget,
                  child: ElevatedButton.icon(
                    key: const Key('pos_search_button'),
                    onPressed: () => _runSearch(_searchController.text),
                    icon: const Icon(Icons.search),
                    label: Text(_isBangla ? 'খুঁজুন' : 'Search'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space8),
            _buildStateBanner(),
            const SizedBox(height: AppTokens.space8),
            _buildStaleConfirmationBanner(),
            Expanded(
              child: _uiState == MobilePosUiState.loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? _buildEmptyOrCartPlaceholder()
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space8),
                          itemBuilder: (_, idx) => _buildCandidateCard(_results[idx]),
                        ),
            ),
            const SizedBox(height: AppTokens.space8),
            _buildCartSummaryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStateBanner() {
    Color bg;
    Color fg;
    IconData icon;
    switch (_uiState) {
      case MobilePosUiState.ready:
        bg = const Color(0xFFF0FDF4);
        fg = AppTokens.successGreen;
        icon = Icons.check_circle_outline;
      case MobilePosUiState.loading:
        bg = const Color(0xFFEFF6FF);
        fg = AppTokens.primaryTeal;
        icon = Icons.hourglass_top;
      case MobilePosUiState.offline:
        bg = const Color(0xFFFFFBEB);
        fg = AppTokens.warningAmber;
        icon = Icons.cloud_off;
      case MobilePosUiState.permissionDenied:
        bg = const Color(0xFFFEF2F2);
        fg = AppTokens.dangerRed;
        icon = Icons.lock_outline;
      case MobilePosUiState.error:
        bg = const Color(0xFFFEF2F2);
        fg = AppTokens.dangerRed;
        icon = Icons.error_outline;
      case MobilePosUiState.empty:
        bg = AppTokens.cardSurface;
        fg = AppTokens.textMuted;
        icon = Icons.inventory_2_outlined;
    }

    return Container(
      key: Key('state_banner_${_uiState.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: AppTokens.space8),
          Expanded(
            child: Text(
              _isBangla ? _statusMessageBn : _statusMessageEn,
              style: AppTokens.bodyRegular.copyWith(color: AppTokens.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrCartPlaceholder() {
    if (_cart.isNotEmpty) {
      return ListView.separated(
        itemCount: _cart.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space8),
        itemBuilder: (_, idx) => _buildCartRow(idx, _cart[idx]),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.qr_code_scanner, size: 42, color: AppTokens.textMuted),
          const SizedBox(height: AppTokens.space8),
          Text(
            _isBangla ? 'কার্টে যুক্ত করতে ওষুধ খুঁজুন বা স্ক্যান করুন' : 'Search or scan a barcode to add medicines',
            style: AppTokens.captionMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateCard(MobileFastSearchCandidate c) {
    final brand = _isBangla && c.brandNameBn.isNotEmpty ? '${c.brandName} (${c.brandNameBn})' : c.brandName;
    final generic = _isBangla && c.genericNameBn.isNotEmpty ? c.genericNameBn : c.genericName;
    final chosen = _resolveChosenOption(c);
    return Container(
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: AppTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: AppTokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('$brand ${c.strength}'.trim(), style: AppTokens.titleMedium),
                    const SizedBox(height: AppTokens.space4),
                    Text(
                      '$generic | ${c.skuCode} | Avail: ${c.availableBaseUnits}u',
                      style: AppTokens.captionMuted,
                    ),
                  ],
                ),
              ),
              if (c.requiresRxVerification)
                const Padding(
                  padding: EdgeInsets.only(right: AppTokens.space8),
                  child: Chip(
                    label: Text('Rx', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    backgroundColor: Color(0xFFFEF3C7),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ElevatedButton.icon(
                key: Key('add_candidate_${c.productId}'),
                onPressed: c.isSellable ? () => _addCandidate(c) : null,
                icon: Icon(c.isSellable ? Icons.add_shopping_cart : Icons.block, size: 16),
                label: Text(
                  c.isSellable
                      ? (_isBangla ? 'যুক্ত করুন' : 'Add')
                      : (_isBangla ? 'ব্লকড' : c.blockReason),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          Wrap(
            spacing: AppTokens.space8,
            runSpacing: AppTokens.space4,
            children: <Widget>[
              if (c.shelfLocation.isNotEmpty)
                Text('Shelf: ${c.shelfLocation}', style: AppTokens.captionMuted),
              if (c.earliestExpiryDate != null)
                Text('FEFO Exp: ${c.earliestExpiryDate}', style: AppTokens.captionMuted),
              Text(
                'BDT ${chosen.unitPriceBdt} / ${chosen.packagingUnit}',
                style: AppTokens.bodyRegular.copyWith(
                  color: AppTokens.primaryTealDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (c.packagingOptions.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppTokens.space8),
            Wrap(
              spacing: AppTokens.space8,
              runSpacing: AppTokens.space4,
              children: c.packagingOptions.map((opt) {
                final selected = chosen.packagingUnit == opt.packagingUnit;
                return ChoiceChip(
                  key: Key('cand_unit_${c.productId}_${opt.packagingUnit}'),
                  avatar: !opt.isAllowed
                      ? const Icon(Icons.lock_outline, size: 14, color: AppTokens.dangerRed)
                      : null,
                  label: Text(
                    '${opt.packagingUnit} (${opt.conversionFactor}u) • ${opt.unitPriceBdt}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: selected && opt.isAllowed,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    if (!opt.isAllowed) {
                      _showOptionBlocked(opt);
                      return;
                    }
                    setState(() {
                      _selectedCandidateUnit[c.productId] = opt;
                      _uiState = _isOffline ? MobilePosUiState.offline : MobilePosUiState.ready;
                      _statusMessageEn =
                          'Selected ${opt.packagingUnit} (${opt.conversionFactor}u) for ${c.brandName}.';
                      _statusMessageBn =
                          '${c.brandName}-এর জন্য ${opt.packagingUnit} (${opt.conversionFactor}টি) নির্বাচিত হয়েছে।';
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartRow(int idx, _LocalCartEntry entry) {
    final baseUnits = entry.quantity * entry.option.conversionFactor;
    final menuOptions = entry.candidate.packagingOptions.isNotEmpty
        ? entry.candidate.packagingOptions
        : <MobilePackagingOption>[entry.option];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space12, vertical: AppTokens.space8),
      decoration: BoxDecoration(
        color: AppTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
        border: Border.all(color: AppTokens.borderSubtle),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(entry.candidate.brandName, style: AppTokens.titleMedium, overflow: TextOverflow.ellipsis),
                Text(
                  '${entry.option.packagingUnit} (${baseUnits}u base) • ${entry.option.unitPriceBdt} BDT',
                  style: AppTokens.captionMuted,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PopupMenuButton<MobilePackagingOption>(
            key: Key('cart_unit_btn_$idx'),
            tooltip: _isBangla ? 'প্যাকেজিং ইউনিট পরিবর্তন' : 'Select packaging unit',
            onSelected: (opt) => _selectCartUnit(idx, opt),
            itemBuilder: (_) => menuOptions.map((opt) {
              return PopupMenuItem<MobilePackagingOption>(
                value: opt,
                child: Row(
                  children: <Widget>[
                    Icon(
                      !opt.isAllowed
                          ? Icons.lock_outline
                          : (opt.packagingUnit == entry.option.packagingUnit
                              ? Icons.check
                              : Icons.inventory_2_outlined),
                      size: 16,
                      color: !opt.isAllowed ? AppTokens.dangerRed : AppTokens.primaryTealDark,
                    ),
                    const SizedBox(width: AppTokens.space8),
                    Expanded(
                      child: Text(
                        '${opt.packagingUnit} (${opt.conversionFactor}u) • ${opt.unitPriceBdt} BDT',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.space8, vertical: AppTokens.space4),
              decoration: BoxDecoration(
                color: AppTokens.surfaceBackground,
                borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
                border: Border.all(color: AppTokens.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.inventory_2_outlined, size: 14, color: AppTokens.primaryTealDark),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.option.packagingUnit} (${entry.option.conversionFactor}u)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ),
          ),
          IconButton(
            key: Key('cart_dec_$idx'),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _adjustQty(idx, -1),
          ),
          Text('${entry.quantity}', style: AppTokens.titleMedium),
          IconButton(
            key: Key('cart_inc_$idx'),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _adjustQty(idx, 1),
          ),
          IconButton(
            key: Key('cart_remove_$idx'),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.delete_outline, color: AppTokens.dangerRed),
            onPressed: () => _adjustQty(idx, -entry.quantity),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummaryCard() {
    final totals = _resolvedTotals();
    return Container(
      padding: const EdgeInsets.all(AppTokens.space8),
      decoration: BoxDecoration(
        color: AppTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: AppTokens.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_cart.isNotEmpty && _results.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 76),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _cart.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space4),
                itemBuilder: (_, idx) => _buildCartRow(idx, _cart[idx]),
              ),
            ),
          if (_cart.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppTokens.space8),
            Wrap(
              spacing: AppTokens.space8,
              runSpacing: AppTokens.space8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                DropdownButton<String>(
                  key: const Key('pos_discount_type_dropdown'),
                  value: _discountType,
                  isDense: true,
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'NONE', child: Text(_isBangla ? 'ছাড় নেই' : 'No Disc.')),
                    DropdownMenuItem(value: 'PERCENTAGE', child: Text(_isBangla ? 'শতাংশ (%)' : 'Percent %')),
                    DropdownMenuItem(value: 'FLAT_BDT', child: Text(_isBangla ? 'নির্দিষ্ট BDT' : 'Flat BDT')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _discountType = v);
                      if (v == 'NONE') {
                        _discountValueController.clear();
                        _applyPricing(nextDiscountType: 'NONE');
                      }
                    }
                  },
                ),
                SizedBox(
                  width: 82,
                  child: TextField(
                    key: const Key('pos_discount_input'),
                    controller: _discountValueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '0.00',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _applyPricing(),
                  ),
                ),
                DropdownButton<String>(
                  key: const Key('pos_rounding_mode_dropdown'),
                  value: _roundingMode,
                  isDense: true,
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'NONE', child: Text(_isBangla ? 'সঠিক পয়সা' : 'Exact Paisa')),
                    DropdownMenuItem(value: 'HALF_UP_WHOLE_BDT', child: Text(_isBangla ? '১ টাকা' : 'Nearest 1')),
                    DropdownMenuItem(value: 'FLOOR_WHOLE_BDT', child: Text(_isBangla ? 'নিম্ন ১' : 'Floor 1')),
                    DropdownMenuItem(value: 'NEAREST_FIVE_BDT', child: Text(_isBangla ? '৫ টাকা' : 'Nearest 5')),
                  ],
                  onChanged: (v) {
                    if (v != null) _applyPricing(nextRoundingMode: v);
                  },
                ),
                OutlinedButton(
                  key: const Key('pos_apply_pricing_btn'),
                  onPressed: () => _applyPricing(),
                  child: Text(_isBangla ? 'প্রয়োগ' : 'Apply'),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space8),
            Wrap(
              spacing: AppTokens.space12,
              runSpacing: AppTokens.space4,
              children: <Widget>[
                Text(
                  '${_isBangla ? 'উপ-মোট' : 'Sub'}: ${_formatPaisa(totals.subtotalPaisa)}',
                  style: AppTokens.captionMuted,
                ),
                Text(
                  '${_isBangla ? 'ছাড়' : 'Disc'}: -${_formatPaisa(totals.discountPaisa)}',
                  key: const Key('mobile_cart_discount'),
                  style: AppTokens.captionMuted,
                ),
                Text(
                  '${_isBangla ? 'ভ্যাট' : 'VAT'} (${totals.taxModeLabel}): ${_formatPaisa(totals.taxPaisa)}',
                  style: AppTokens.captionMuted,
                ),
                Text(
                  '${_isBangla ? 'রাউন্ডিং' : 'Round'}: ${_formatPaisa(totals.roundingAdjPaisa)}',
                  key: const Key('mobile_cart_rounding'),
                  style: AppTokens.captionMuted,
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space8),
          ],
          Row(
            children: <Widget>[
              const Icon(Icons.shopping_cart_outlined, color: AppTokens.primaryTeal),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _isBangla ? 'মোট (${_cart.length} লাইন)' : 'Cart Total (${_cart.length} lines)',
                      style: AppTokens.titleMedium,
                    ),
                    if (_cart.isNotEmpty)
                      Wrap(
                        spacing: AppTokens.space8,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            totals.isConfirmed
                                ? (_isBangla ? 'সার্ভার নিশ্চিতকৃত' : 'Server Confirmed')
                                : (_isOffline
                                    ? (_isBangla ? 'অফলাইন প্রাক্কলন' : 'Offline Preview')
                                    : (_isBangla ? 'অনিশ্চিত' : 'Pending Confirm')),
                            key: const Key('pos_pricing_confirm_badge'),
                            style: AppTokens.captionMuted.copyWith(
                              color: totals.isConfirmed ? AppTokens.successGreen : AppTokens.warningAmber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _cartHasBlockedRecall
                                ? (_isBangla ? 'Rx ব্লকড: প্রত্যাহৃত ওষুধ' : 'Rx BLOCKED: Recalled/banned item')
                                : (!_cartRequiresRx
                                    ? (_isOffline
                                        ? (_isBangla ? 'Rx গেট: OTC (অফলাইন অনুমোদিত)' : 'Rx Gate: NOT_REQUIRED (Offline OTC Ready)')
                                        : (_isBangla ? 'Rx গেট: OTC প্রস্তুত' : 'Rx Gate: NOT_REQUIRED (OTC Ready)'))
                                    : (_isCartRxApprovedForCheckout
                                        ? (_isBangla ? 'Rx অনুমোদিত (চেকআউট প্রস্তুত)' : 'Rx APPROVED (Checkout Ready)')
                                        : (_isOffline
                                            ? (_isBangla
                                                ? 'অফলাইন ব্লক: অনুমোদনহীন Rx নিষিদ্ধ'
                                                : 'Offline Block: Unverified Rx blocked')
                                            : (_isBangla
                                                ? 'Rx অপেক্ষমাণ: ফার্মাসিস্ট অনুমোদন আবশ্যক'
                                                : 'Rx Pending: Pharmacist Approval Required')))),
                            key: const Key('pos_rx_checkout_hint'),
                            style: AppTokens.captionMuted.copyWith(
                              color: (_cartHasBlockedRecall || (_cartRequiresRx && !_isCartRxApprovedForCheckout))
                                  ? AppTokens.warningAmber
                                  : AppTokens.successGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Text(
                'BDT ${_formatPaisa(totals.grandTotalPaisa)}',
                key: const Key('mobile_cart_total'),
                style: AppTokens.kpiValue,
              ),
            ],
          ),
          if (_cart.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppTokens.space4),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: <Widget>[
                  OutlinedButton(
                    key: const Key('pos_confirm_pricing_btn'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: _confirmPricing,
                    child: Text(_isBangla ? 'মূল্য নিশ্চিত' : 'Confirm Prices'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('pos_hold_cart_btn'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: _showHoldCartDialog,
                    icon: const Icon(Icons.pause_circle_outline, size: 15),
                    label: Text(_isBangla ? 'কার্ট হোল্ড' : 'Hold Cart'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('pos_create_delivery_btn'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: _showCreateDeliveryDialog,
                    icon: const Icon(Icons.local_shipping_outlined, size: 15),
                    label: Text(_isBangla ? 'ডেলিভারি / প্রি-অর্ডার' : 'Preorder / Delivery'),
                  ),
                  ElevatedButton.icon(
                    key: const Key('pos_checkout_btn'),
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: _handleCheckout,
                    icon: const Icon(Icons.point_of_sale, size: 15),
                    label: Text(_isBangla ? 'চেকআউট' : 'Checkout'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
