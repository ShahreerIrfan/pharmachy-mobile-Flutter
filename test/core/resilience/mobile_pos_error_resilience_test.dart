import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/resilience/mobile_pos_resilience_client.dart';

void main() {
  group('P239: Mobile POS UI Error Resilience & Recovery Tests', () {
    test('Report and resolve scanner failure with manual search fallback', () async {
      final client = MobilePosResilienceClient(
        'https://api.pharmacy.bd',
        transport: (method, path, {body, bearerToken}) async {
          if (method == 'POST' && path.contains('/report/')) {
            return const MobileApiResponse(
              201,
              {
                'incident_id': 'inc-mob-scan-001',
                'incident_type': 'SCANNER_FAILURE',
                'error_code': 'ERR_POS_SCANNER_FAILURE',
                'correlation_id': 'corr-mob-001',
                'device_id': 'CAM-SCANNER-01',
                'message_en': 'Camera barcode unreadable. Tap manual search.',
                'message_bn': 'ক্যামেরা স্ক্যানার দিয়ে পড়া যায়নি। ম্যানুয়াল সার্চ করুন।',
                'status': 'OPEN',
                'is_retryable': true,
                'created_at': '2026-11-17T10:00:00Z',
              },
            );
          }
          if (method == 'POST' && path.contains('/resolve/')) {
            return const MobileApiResponse(
              200,
              {
                'incident_id': 'inc-mob-scan-001',
                'incident_type': 'SCANNER_FAILURE',
                'error_code': 'ERR_POS_SCANNER_FAILURE',
                'status': 'RESOLVED',
                'recovery_action_taken': 'MANUAL_SEARCH_FALLBACK',
                'is_retryable': true,
                'created_at': '2026-11-17T10:00:00Z',
                'resolved_at': '2026-11-17T10:01:00Z',
              },
            );
          }
          return const MobileApiResponse(404, {'error_code': 'ERR_NOT_FOUND'});
        },
      );

      // 1. Report
      final reportRes = await client.reportIncident(
        type: MobilePosIncidentType.scannerFailure,
        errorCode: 'ERR_POS_SCANNER_FAILURE',
        deviceId: 'CAM-SCANNER-01',
        bearerToken: 'mock-token',
      );
      expect(reportRes.isSuccess, isTrue);
      expect(reportRes.data!.incidentId, equals('inc-mob-scan-001'));
      expect(reportRes.data!.status, equals('OPEN'));
      expect(reportRes.data!.isRetryable, isTrue);
      expect(reportRes.messageBn, contains('ম্যানুয়াল সার্চ করুন'));

      // 2. Resolve
      final resolveRes = await client.resolveIncident(
        incidentId: 'inc-mob-scan-001',
        action: MobilePosRecoveryAction.manualSearchFallback,
        recoveryPayload: {'search_query': 'Napa'},
        bearerToken: 'mock-token',
      );
      expect(resolveRes.isSuccess, isTrue);
      expect(resolveRes.data!.status, equals('RESOLVED'));
      expect(resolveRes.data!.recoveryActionTaken, equals('MANUAL_SEARCH_FALLBACK'));
    });

    test('Printer disconnect format switch fallback to PDF/A4', () async {
      final client = MobilePosResilienceClient(
        'https://api.pharmacy.bd',
        transport: (method, path, {body, bearerToken}) async {
          if (method == 'POST' && path.contains('/resolve/')) {
            return const MobileApiResponse(
              200,
              {
                'incident_id': 'inc-mob-print-001',
                'incident_type': 'PRINTER_DISCONNECTED',
                'error_code': 'ERR_POS_PRINTER_DISCONNECTED',
                'status': 'RESOLVED',
                'recovery_action_taken': 'SWITCH_PRINTER_FORMAT',
                'is_retryable': true,
                'created_at': '2026-11-17T10:00:00Z',
                'resolved_at': '2026-11-17T10:02:00Z',
              },
            );
          }
          return const MobileApiResponse(404, {});
        },
      );

      final res = await client.resolveIncident(
        incidentId: 'inc-mob-print-001',
        action: MobilePosRecoveryAction.switchPrinterFormat,
        recoveryPayload: {'target_format': 'A4_INVOICE'},
      );
      expect(res.isSuccess, isTrue);
      expect(res.data!.recoveryActionTaken, equals('SWITCH_PRINTER_FORMAT'));
    });

    test('Stock conflict fetches available alternative batches', () async {
      final client = MobilePosResilienceClient(
        'https://api.pharmacy.bd',
        transport: (method, path, {body, bearerToken}) async {
          if (method == 'GET' && path.contains('/stock-alternatives/')) {
            return const MobileApiResponse(
              200,
              {
                'product_id': 'prod-cef-200',
                'alternatives': [
                  {
                    'batch_id': 'bx-cef-01',
                    'batch_number': 'CEF-2026-1',
                    'expiry_date': '2027-08-30',
                    'available_units': 60,
                    'is_expired': false,
                    'can_fulfill_requested': true,
                  }
                ],
              },
            );
          }
          return const MobileApiResponse(404, {});
        },
      );

      final outcome = await client.fetchStockAlternatives(productId: 'prod-cef-200', requestedQuantity: 5);
      expect(outcome.isSuccess, isTrue);
      expect(outcome.data!.length, equals(1));
      expect(outcome.data!.first.batchId, equals('bx-cef-01'));
      expect(outcome.data!.first.availableUnits, equals(60));
      expect(outcome.data!.first.isExpired, isFalse);
    });

    test('Network timeout maps cleanly to offline UI state', () async {
      final client = MobilePosResilienceClient(
        'https://api.pharmacy.bd',
        transport: (method, path, {body, bearerToken}) async {
          throw Exception('Connection timed out');
        },
      );

      final outcome = await client.reportIncident(
        type: MobilePosIncidentType.networkInterrupted,
        deviceId: 'MOB-POS-01',
      );
      expect(outcome.uiState, equals(MobilePosUiState.offline));
      expect(outcome.errorCode, equals('ERR_NETWORK_UNREACHABLE'));
      expect(outcome.messageBn, contains('নেটওয়ার্ক সংযোগ বিচ্ছিন্ন'));
    });
  });
}
