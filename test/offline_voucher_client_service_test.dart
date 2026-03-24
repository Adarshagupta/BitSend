import 'dart:convert';

import 'package:bitsend/src/models/app_models.dart';
import 'package:bitsend/src/services/offline_voucher_client_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OfflineVoucherClientService', () {
    test('registers escrows against the offline voucher backend', () async {
      final MockClient client = MockClient((http.Request request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/offline/escrows');

        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['escrowId'], 'escrow-1');

        return http.Response(request.body, 200);
      });
      final OfflineVoucherClientService service =
          OfflineVoucherClientService(
            endpoint: 'https://bitsend.example',
            client: client,
          );

      final OfflineVoucherEscrowCommitment escrow =
          await service.registerEscrow(
            const OfflineVoucherEscrowCommitment(
              version: 1,
              escrowId: 'escrow-1',
              chain: ChainKind.ethereum,
              network: ChainNetwork.testnet,
              senderAddress: '0x1111111111111111111111111111111111111111',
              assetId: 'ethereum:testnet:usdc',
              assetContract: '0x2222222222222222222222222222222222222222',
              amountBaseUnits: '5000000',
              collateralBaseUnits: '500000',
              voucherRoot: 'root-1',
              voucherCount: 5,
              maxVoucherAmountBaseUnits: '1000000',
              createdAt: DateTime.utc(2026, 3, 21, 10),
              expiresAt: DateTime.utc(2026, 3, 22, 10),
              stateRoot: 'state-root-1',
              settlementContract:
                  '0x3333333333333333333333333333333333333333',
            ),
          );

      expect(escrow.escrowId, 'escrow-1');
      expect(escrow.assetId, 'ethereum:testnet:usdc');
    });

    test('returns null for missing proof bundles', () async {
      final MockClient client = MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/offline/proof-bundles/voucher-404');
        return http.Response('{"message":"Offline proof bundle not found."}', 404);
      });
      final OfflineVoucherClientService service =
          OfflineVoucherClientService(
            endpoint: 'https://bitsend.example',
            client: client,
          );

      final OfflineVoucherProofBundle? bundle = await service.fetchProofBundle(
        'voucher-404',
      );

      expect(bundle, isNull);
    });

    test('submits claims and parses claim records', () async {
      final MockClient client = MockClient((http.Request request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/offline/claims');

        final Map<String, dynamic> response = <String, dynamic>{
          ...(jsonDecode(request.body) as Map<String, dynamic>),
          'status': 'accepted',
          'resolvedAt': '2026-03-21T13:05:00.000Z',
        };
        return http.Response(jsonEncode(response), 200);
      });
      final OfflineVoucherClientService service =
          OfflineVoucherClientService(
            endpoint: 'https://bitsend.example',
            client: client,
          );

      final OfflineVoucherClaimRecord claim = await service.submitClaim(
        const OfflineVoucherClaimSubmission(
          version: 1,
          voucherId: 'voucher-1',
          txId: 'tx-1',
          escrowId: 'escrow-1',
          claimerAddress: '0x4444444444444444444444444444444444444444',
          createdAt: DateTime.utc(2026, 3, 21, 13),
        ),
      );

      expect(claim.status, OfflineVoucherClaimStatus.accepted);
      expect(claim.resolvedAt, DateTime.utc(2026, 3, 21, 13, 5));
    });

    test('requests sponsored claims', () async {
      final MockClient client = MockClient((http.Request request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/offline/claims/sponsored');
        final Map<String, dynamic> response = <String, dynamic>{
          ...(jsonDecode(request.body) as Map<String, dynamic>),
          'status': 'submitted_onchain',
          'submissionMode': 'sponsor',
          'submissionAttempts': 1,
          'graceLockExpiresAt': '2026-03-21T13:35:00.000Z',
          'resolvedAt': '2026-03-21T13:05:00.000Z',
        };
        return http.Response(jsonEncode(response), 200);
      });
      final OfflineVoucherClientService service =
          OfflineVoucherClientService(
            endpoint: 'https://bitsend.example',
            client: client,
          );

      final OfflineVoucherClaimRecord claim = await service.requestSponsoredClaim(
        const OfflineVoucherClaimSubmission(
          version: 1,
          voucherId: 'voucher-1',
          txId: 'tx-1',
          escrowId: 'escrow-1',
          claimerAddress: '0x4444444444444444444444444444444444444444',
          createdAt: DateTime.utc(2026, 3, 21, 13),
        ),
      );

      expect(claim.status, OfflineVoucherClaimStatus.submittedOnchain);
      expect(claim.submissionMode, OfflineVoucherClaimSubmissionMode.sponsor);
      expect(claim.submissionAttempts, 1);
    });

    test('fetches refund eligibility', () async {
      final MockClient client = MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/v1/offline/escrows/escrow-1/refund-eligibility',
        );
        return http.Response(
          jsonEncode(<String, dynamic>{
            'escrowId': 'escrow-1',
            'refundable': false,
            'reason': 'claim_grace_active',
            'lockedUntil': '2026-03-21T13:35:00.000Z',
            'blockingVoucherId': 'voucher-1',
          }),
          200,
        );
      });
      final OfflineVoucherClientService service =
          OfflineVoucherClientService(
            endpoint: 'https://bitsend.example',
            client: client,
          );

      final OfflineVoucherRefundEligibility? eligibility =
          await service.fetchRefundEligibility('escrow-1');

      expect(eligibility, isNotNull);
      expect(eligibility!.refundable, isFalse);
      expect(eligibility.reason, 'claim_grace_active');
      expect(eligibility.blockingVoucherId, 'voucher-1');
    });
  });
}
