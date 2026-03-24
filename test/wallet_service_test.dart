import 'package:bitsend/src/models/app_models.dart';
import 'package:bitsend/src/services/wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletService EVM account strategy', () {
    final WalletService service = WalletService();

    test('restored wallets default to MetaMask-compatible EVM accounts', () {
      expect(
        service.defaultEvmAccountStrategyForMode(WalletSetupMode.restored),
        EvmAccountStrategy.compatibleUnified,
      );
      expect(
        service.accountIndexForSlot(
          chain: ChainKind.ethereum,
          slot: 0,
          offline: false,
          evmAccountStrategy: EvmAccountStrategy.compatibleUnified,
        ),
        0,
      );
      expect(
        service.accountIndexForSlot(
          chain: ChainKind.bnb,
          slot: 0,
          offline: false,
          evmAccountStrategy: EvmAccountStrategy.compatibleUnified,
        ),
        0,
      );
      expect(
        service.accountIndexForSlot(
          chain: ChainKind.polygon,
          slot: 1,
          offline: false,
          evmAccountStrategy: EvmAccountStrategy.compatibleUnified,
        ),
        1,
      );
    });

    test('created wallets keep the legacy separated EVM ranges', () {
      expect(
        service.defaultEvmAccountStrategyForMode(WalletSetupMode.created),
        EvmAccountStrategy.legacySeparated,
      );
      expect(
        service.accountIndexForSlot(
          chain: ChainKind.base,
          slot: 0,
          offline: false,
          evmAccountStrategy: EvmAccountStrategy.legacySeparated,
        ),
        2,
      );
      expect(
        service.accountIndexForSlot(
          chain: ChainKind.bnb,
          slot: 0,
          offline: false,
          evmAccountStrategy: EvmAccountStrategy.legacySeparated,
        ),
        1000,
      );
    });

    test('offline migration indexes stay on the legacy deterministic path', () {
      expect(
        service.accountIndexForSlot(
          chain: ChainKind.bnb,
          slot: 0,
          offline: true,
          evmAccountStrategy: EvmAccountStrategy.compatibleUnified,
        ),
        1001,
      );
      expect(
        service.accountIndexForSlot(
          chain: ChainKind.solana,
          slot: 1,
          offline: true,
        ),
        3,
      );
    });
  });
}
