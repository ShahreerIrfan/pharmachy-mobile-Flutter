// mobile_customer_due_collection_screen.dart
// Architecture Decision: ADR-0277 (P277).
// Phase 14: Customers, Suppliers, Dues & Payments.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_customer_due_collection_client.dart';

class MobileCustomerDueCollectionScreen extends StatefulWidget {
  final MobileCustomerDueCollectionClient client;
  final bool isOfflineMode;

  const MobileCustomerDueCollectionScreen({
    Key? key,
    required this.client,
    this.isOfflineMode = false,
  }) : super(key: key);

  @override
  State<MobileCustomerDueCollectionScreen> createState() =>
      _MobileCustomerDueCollectionScreenState();
}

class _MobileCustomerDueCollectionScreenState
    extends State<MobileCustomerDueCollectionScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  List<MobileOutstandingDueDto> _dues = [];
  MobileDueCollectionSummaryDto? _summary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (!widget.client.isAuthorized) {
      setState(() {
        _errorMessage = 'ERR_STAFF_ROLE_DENIED: Access restricted to Pharmacy Owners and Managers.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _dues = widget.client.listOutstandingDues(search: _searchQuery);
      _summary = widget.client.getDueSummary();
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    setState(() {});
  }

  void _openCollectionSheet(MobileOutstandingDueDto due) {
    if (widget.isOfflineMode) {
      _showErrorDialog('ERR_OFFLINE_UNAVAILABLE', 'Due collections require online connectivity / ইন্টারনেট সংযোগ প্রয়োজন।');
      return;
    }

    final amountController = TextEditingController(text: due.remainingDueBdt.toStringAsFixed(2));
    final refController = TextEditingController();
    final notesController = TextEditingController();
    String selectedTender = 'CASH';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDigital = ['BKASH', 'NAGAD', 'ROCKET', 'UPAY', 'CARD', 'BANK_TRANSFER'].contains(selectedTender);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Record Due Collection / বাকি আদায়',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${due.customerName} (${due.customerPhone})',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                    Text(
                      'Invoice: #${due.invoiceNumber} | Remaining: ${due.remainingDueBdt.toStringAsFixed(2)} BDT',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Collection Amount (BDT) / আদায়ের পরিমাণ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixText: 'BDT',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedTender,
                      decoration: InputDecoration(
                        labelText: 'Payment Tender / মাধ্যম',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('Cash / নগদ')),
                        DropdownMenuItem(value: 'BKASH', child: Text('bKash / বিকাশ')),
                        DropdownMenuItem(value: 'NAGAD', child: Text('Nagad / নগদ ওয়ালেট')),
                        DropdownMenuItem(value: 'CARD', child: Text('POS Card Terminal / কার্ড')),
                        DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer / ব্যাংক')),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          selectedTender = val ?? 'CASH';
                        });
                      },
                    ),
                    if (isDigital) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: refController,
                        decoration: InputDecoration(
                          labelText: 'Gateway Reference / TrxID (Min 4 chars)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes / মন্তব্য (Optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final amt = double.tryParse(amountController.text) ?? 0.0;
                          try {
                            final receipt = widget.client.recordDueCollection(
                              dueId: due.dueId,
                              amountBdt: amt,
                              tenderType: selectedTender,
                              gatewayReference: refController.text,
                              notes: notesController.text,
                              isOffline: widget.isOfflineMode,
                            );
                            Navigator.pop(ctx);
                            _loadData();
                            _showReceiptDialog(receipt);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                            );
                          }
                        },
                        child: const Text('Confirm Collection / আদায় নিশ্চিত করুন', style: TextStyle(fontSize: 16)),
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
  }

  void _showReceiptDialog(MobileDigitalReceiptDto receipt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Digital Receipt / রসিদ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt #: ${receipt.receiptNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Text('Customer: ${receipt.customerName}'),
            Text('Invoice: #${receipt.invoiceNumber}'),
            Text('Collected: ${receipt.amountCollectedBdt.toStringAsFixed(2)} BDT (${receipt.tenderType})'),
            Text('Remaining Due: ${receipt.remainingDueBdt.toStringAsFixed(2)} BDT [${receipt.dueStatus}]'),
            if (receipt.gatewayReference.isNotEmpty) Text('TrxID: ${receipt.gatewayReference}'),
            Text('Collected by: ${receipt.collectedByName}'),
            const SizedBox(height: 8),
            Text(receipt.messageBn, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close / বন্ধ করুন'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String code, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(code, style: const TextStyle(color: Colors.red)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Dues / বাকি পর্যালোচনা'),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          if (widget.isOfflineMode)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: const [
                  Icon(Icons.wifi_off, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline Mode: Due collections require online connectivity.',
                      style: TextStyle(color: Colors.black87, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade100,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          if (_summary != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Outstanding / মোট বাকি',
                      '${_summary!.totalOutstandingDueBdt} BDT',
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'Overdue / মেয়াদোত্তীর্ণ',
                      '${_summary!.totalOverdueDueBdt} BDT',
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'Today / আজকের আদায়',
                      '${_summary!.todayCollectedDueBdt} BDT',
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customer name or phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (val) {
                _searchQuery = val;
                _loadData();
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _dues.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle_outline, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No outstanding dues / কোনো বকেয়া বাকি নেই', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _dues.length,
                        itemBuilder: (context, idx) {
                          final due = _dues[idx];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              title: Text(due.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${due.customerPhone} | Inv #${due.invoiceNumber}'),
                                  if (due.isOverdue)
                                    Text('Overdue by ${due.overdueDays} days', style: const TextStyle(color: Colors.red, fontSize: 12)),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${due.remainingDueBdt.toStringAsFixed(2)} BDT',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      minimumSize: const Size(60, 26),
                                    ),
                                    onPressed: () => _openCollectionSheet(due),
                                    child: const Text('Collect', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
