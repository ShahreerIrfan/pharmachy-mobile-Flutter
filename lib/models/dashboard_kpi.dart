// lib/models/dashboard_kpi.dart
// Architecture Decision: ADR-0001 & ADR-0024
// Strict monetary representation: uses exact decimal strings to avoid float drift.

class DashboardKpi {
  final String todaySalesBdt;
  final int totalOrdersCount;
  final String grossMarginPercent;
  final int lowStockAlertCount;
  final int expiringBatchesCount;
  final int pendingRxCount;
  final String asOfTimestamp;

  const DashboardKpi({
    required this.todaySalesBdt,
    required this.totalOrdersCount,
    required this.grossMarginPercent,
    required this.lowStockAlertCount,
    required this.expiringBatchesCount,
    required this.pendingRxCount,
    required this.asOfTimestamp,
  });

  String get formattedSalesText {
    // Exact formatting without floating point rounding errors
    final parts = todaySalesBdt.split('.');
    final whole = parts[0];
    final dec =
        parts.length > 1 ? parts[1].padRight(2, '0').substring(0, 2) : '00';

    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedWhole = whole.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return 'BDT $formattedWhole.$dec';
  }

  factory DashboardKpi.fromJson(Map<String, dynamic> json) {
    final sales = json['today_sales_bdt']?.toString() ?? '0.00';
    if (sales.startsWith('-')) {
      throw const FormatException('today_sales_bdt cannot be negative.');
    }

    final orders = json['total_orders_count'] as int? ?? 0;
    if (orders < 0) {
      throw const FormatException('total_orders_count cannot be negative.');
    }

    return DashboardKpi(
      todaySalesBdt: sales,
      totalOrdersCount: orders,
      grossMarginPercent: json['gross_margin_percent']?.toString() ?? '0.0',
      lowStockAlertCount: json['low_stock_alert_count'] as int? ?? 0,
      expiringBatchesCount: json['expiring_batches_count'] as int? ?? 0,
      pendingRxCount: json['pending_rx_count'] as int? ?? 0,
      asOfTimestamp: json['as_of_timestamp'] as String? ??
          DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'today_sales_bdt': todaySalesBdt,
      'total_orders_count': totalOrdersCount,
      'gross_margin_percent': grossMarginPercent,
      'low_stock_alert_count': lowStockAlertCount,
      'expiring_batches_count': expiringBatchesCount,
      'pending_rx_count': pendingRxCount,
      'as_of_timestamp': asOfTimestamp,
    };
  }
}
