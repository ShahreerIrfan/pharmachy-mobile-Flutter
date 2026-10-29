// lib/models/stock_alert.dart
// Architecture Decision: ADR-0024

class StockAlert {
  final String medicineName;
  final String batchNumber;
  final int remainingQuantity;
  final String expiryDate;
  final String alertLevel; // WARNING, CRITICAL

  const StockAlert({
    required this.medicineName,
    required this.batchNumber,
    required this.remainingQuantity,
    required this.expiryDate,
    required this.alertLevel,
  });

  bool get isCritical => alertLevel == 'CRITICAL';

  factory StockAlert.fromJson(Map<String, dynamic> json) {
    return StockAlert(
      medicineName: json['medicine_name'] as String,
      batchNumber: json['batch_number'] as String,
      remainingQuantity: json['remaining_quantity'] as int,
      expiryDate: json['expiry_date'] as String,
      alertLevel: json['alert_level'] as String? ?? 'WARNING',
    );
  }
}
