// lib/ui/screens/dashboard_screen.dart
// Architecture Decision: ADR-0007, ADR-0009, ADR-0018 & ADR-0024

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../models/dashboard_kpi.dart';
import '../../models/tenant_session.dart';
import '../../services/mobile_security_service.dart';
import '../widgets/kpi_card.dart';

enum DashboardViewState { loading, loaded, empty, error, permissionDenied }

class DashboardScreen extends StatefulWidget {
  final TenantSession session;
  final bool isOffline;
  final DashboardKpi? initialKpi;
  final DashboardViewState? forcedState;

  const DashboardScreen({
    super.key,
    required this.session,
    this.isOffline = false,
    this.initialKpi,
    this.forcedState,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MobileSecurityService _securityService = MobileSecurityService();
  late DashboardViewState _state;
  DashboardKpi? _kpi;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAuthorizationAndLoad();
  }

  void _checkAuthorizationAndLoad() {
    if (widget.forcedState != null) {
      _state = widget.forcedState!;
      _kpi = widget.initialKpi;
      return;
    }

    try {
      _securityService.assertCanAccessManagerApp(widget.session);
      _kpi = widget.initialKpi;
      if (_kpi == null) {
        _state = DashboardViewState.empty;
      } else {
        _state = DashboardViewState.loaded;
      }
    } on SecurityException catch (e) {
      _state = DashboardViewState.permissionDenied;
      _errorMessage = e.message;
    } catch (e) {
      _state = DashboardViewState.error;
      _errorMessage = e.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.surfaceBackground,
      appBar: AppBar(
        title: const Text('Pharmacy Executive Dashboard',
            style: AppTokens.titleMedium),
        backgroundColor: AppTokens.cardSurface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(widget.isOffline ? 32.0 : 0.0),
          child: widget.isOffline
              ? _buildOfflineBanner()
              : const SizedBox.shrink(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space16),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: AppTokens.warningAmber,
      padding: const EdgeInsets.symmetric(
          vertical: 6.0, horizontal: AppTokens.space16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.wifi_slash, size: 14.0, color: Colors.white),
          SizedBox(width: AppTokens.space8),
          Text(
            'Working Offline - Showing Cached Data',
            style: TextStyle(
                color: Colors.white,
                fontSize: 12.0,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case DashboardViewState.loading:
        return const Center(child: CupertinoActivityIndicator(radius: 16.0));

      case DashboardViewState.permissionDenied:
        return Center(
          child: Container(
            padding: const EdgeInsets.all(AppTokens.space24),
            decoration: BoxDecoration(
              color: AppTokens.cardSurface,
              borderRadius: BorderRadius.circular(AppTokens.cardRadius),
              border: Border.all(color: AppTokens.dangerRed, width: 1.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.lock_shield_fill,
                    color: AppTokens.dangerRed, size: 48.0),
                const SizedBox(height: AppTokens.space16),
                const Text('Permission Denied', style: AppTokens.titleLarge),
                const SizedBox(height: AppTokens.space8),
                Text(
                  _errorMessage ??
                      'Cashier role cannot inspect executive dashboard.',
                  textAlign: TextAlign.center,
                  style: AppTokens.bodyRegular,
                ),
              ],
            ),
          ),
        );

      case DashboardViewState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.exclamationmark_circle_fill,
                  color: AppTokens.dangerRed, size: 48.0),
              const SizedBox(height: AppTokens.space16),
              const Text('Failed to Load Dashboard',
                  style: AppTokens.titleMedium),
              const SizedBox(height: AppTokens.space8),
              Text(_errorMessage ?? 'An unexpected error occurred.',
                  style: AppTokens.captionMuted),
              const SizedBox(height: AppTokens.space16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _checkAuthorizationAndLoad();
                  });
                },
                icon: const Icon(CupertinoIcons.refresh, size: 16.0),
                label: const Text('Retry'),
              ),
            ],
          ),
        );

      case DashboardViewState.empty:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.tray_fill,
                  color: AppTokens.textMuted, size: 48.0),
              SizedBox(height: AppTokens.space16),
              Text('No Transactions Recorded Today',
                  style: AppTokens.titleMedium),
              SizedBox(height: AppTokens.space8),
              Text(
                  'Sales and orders for this branch will appear here in real time.',
                  style: AppTokens.captionMuted),
            ],
          ),
        );

      case DashboardViewState.loaded:
        final kpi = _kpi!;
        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: KpiCard(
                    title: "TODAY'S REVENUE",
                    value: kpi.formattedSalesText,
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    subtitle: '${kpi.totalOrdersCount} Completed Sales',
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: KpiCard(
                    title: 'GROSS MARGIN',
                    value: '${kpi.grossMarginPercent}%',
                    icon: CupertinoIcons.percent,
                    iconColor: AppTokens.successGreen,
                    subtitle: 'Average Margin',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space12),
            Row(
              children: [
                Expanded(
                  child: KpiCard(
                    title: 'LOW STOCK ALERTS',
                    value: '${kpi.lowStockAlertCount}',
                    icon: CupertinoIcons.exclamationmark_triangle_fill,
                    iconColor: AppTokens.warningAmber,
                    subtitle: 'Items Below Par Level',
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: KpiCard(
                    title: 'PENDING RX VERIFICATIONS',
                    value: '${kpi.pendingRxCount}',
                    icon: CupertinoIcons.doc_checkmark_fill,
                    iconColor: AppTokens.primaryTeal,
                    subtitle: 'Awaiting Pharmacist',
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }
}
