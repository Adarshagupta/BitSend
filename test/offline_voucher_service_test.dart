import 'package:bitsend/src/models/app_models.dart';
import 'package:bitsend/src/services/offline_voucher_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart';

void main() {
  group('OfflineVoucherService', () {
    final OfflineVoucherService service = OfflineVoucherService();
    final EthPrivateKey signer = EthPrivateKey.fromHex(
      '0x59c6995e998f97a5a0044966f0945382d7f9e3bfcf1b57f4fb4f63e5b5f9f2dd',
    );

    test('issues canonical voucher inventory with proofs', () {
      final OfflineVoucherEscrowSession session = service.issueEscrowSession(
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        senderAddress: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
        settlementContractAddress:
            '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
        escrowAmountBaseUnits: '130000',
        spendableAmountBaseUnits: '13',
        gasReserveBaseUnits: '1000',
        expiresAt: DateTime.utc(2026, 3, 22, 0),
        createdAt: DateTime.utc(2026, 3, 21, 0),
      );

      expect(session.inventory.length, 4);
      expect(
        session.inventory.map((item) => item.voucher.amountBaseUnits).toList(),
        <String>['1', '2', '4', '6'],
      );
      expect(session.commitment.voucherCount, 4);
      expect(session.commitment.voucherRoot, startsWith('0x'));
    });

    test('composes exact-amount transfer bundles and verifies them', () {
      final OfflineVoucherEscrowSession session = service.issueEscrowSession(
        chain: ChainKind.ethereum,
        network: ChainNetwork.testnet,
        senderAddress: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
        settlementContractAddress:
            '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
        escrowAmountBaseUnits: '130000',
        spendableAmountBaseUnits: '13',
        gasReserveBaseUnits: '1000',
        expiresAt: DateTime.utc(2026, 3, 22, 0),
        createdAt: DateTime.utc(2026, 3, 21, 0),
      );

      final OfflineVoucherTransferBundle bundle = service.composeTransferBundle(
        session: session,
        transferId: 'offline-transfer-1',
        amountBaseUnits: '10',
        receiverAddress: '0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199',
        signer: signer,
        transportKind: TransportKind.ble,
        createdAt: DateTime.utc(2026, 3, 21, 1),
      );

      expect(bundle.totalAmountBaseUnits, '10');
      expect(bundle.payments.length, 2);
      expect(
        bundle.payments.map((item) => item.voucher.amountBaseUnits).toList(),
        <String>['6', '4'],
      );
      expect(service.verifyTransferBundle(bundle), isTrue);
    });

    test('rejects tampered receiver signatures', () {
      final OfflineVoucherEscrowSession session = service.issueEscrowSession(
        chain: ChainKind.base,
        network: ChainNetwork.testnet,
        senderAddress: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
        settlementContractAddress:
            '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
        escrowAmountBaseUnits: '70000',
        spendableAmountBaseUnits: '7',
        gasReserveBaseUnits: '1000',
        expiresAt: DateTime.utc(2026, 3, 22, 0),
        createdAt: DateTime.utc(2026, 3, 21, 0),
      );

      final OfflineVoucherTransferBundle bundle = service.composeTransferBundle(
        session: session,
        transferId: 'offline-transfer-2',
        amountBaseUnits: '5',
        receiverAddress: '0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199',
        signer: signer,
        transportKind: TransportKind.hotspot,
      );

      final OfflineVoucherTransferBundle tampered =
          OfflineVoucherTransferBundle(
            version: bundle.version,
            transferId: bundle.transferId,
            chain: bundle.chain,
            network: bundle.network,
            escrowId: bundle.escrowId,
            settlementContractAddress: bundle.settlementContractAddress,
            senderAddress: bundle.senderAddress,
            receiverAddress: '0x0000000000000000000000000000000000000001',
            payments: bundle.payments,
            totalAmountBaseUnits: bundle.totalAmountBaseUnits,
            createdAt: bundle.createdAt,
            transportHint: bundle.transportHint,
            integrityChecksum: bundle.integrityChecksum,
          );

      expect(service.verifyTransferBundle(tampered), isFalse);
    });
  });
}
