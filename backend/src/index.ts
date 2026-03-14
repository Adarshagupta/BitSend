import 'dotenv/config';

import { randomUUID } from 'node:crypto';

import { BitGoAPI } from '@bitgo/sdk-api';
import { Eth } from '@bitgo/sdk-coin-eth';
import { Sol } from '@bitgo/sdk-coin-sol';
import cors from 'cors';
import express from 'express';

type AppChain = 'ethereum' | 'solana';
type AppNetwork = 'testnet' | 'mainnet';

type WalletRecord = {
  chain: AppChain;
  network: AppNetwork;
  walletId: string;
  address: string;
  displayLabel: string;
  balanceBaseUnits: number;
  connectivityStatus: string;
  coin: string;
};

type TransferRecord = {
  clientTransferId: string;
  bitgoTransferId: string;
  bitgoWalletId: string;
  chain: AppChain;
  network: AppNetwork;
  receiverAddress: string;
  amountBaseUnits: number;
  status: string;
  transactionSignature?: string;
  explorerUrl?: string;
  message?: string;
  updatedAt: string;
};

type SessionRecord = {
  sessionToken: string;
  createdAt: string;
};

type SubmitTransferInput = {
  chain: AppChain;
  network: AppNetwork;
  walletId: string;
  receiverAddress: string;
  amountBaseUnits: number;
  clientTransferId: string;
};

interface Gateway {
  listWallets(): Promise<WalletRecord[]>;
  submitTransfer(input: SubmitTransferInput): Promise<TransferRecord>;
  getTransfer(clientTransferId: string): Promise<TransferRecord | null>;
}

const port = Number(process.env.PORT ?? '8788');
const sessions = new Map<string, SessionRecord>();

const app = express();
app.use(cors());
app.use(express.json());
let gateway: Gateway;

app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    mode: hasLiveBitGoConfig() ? 'live' : 'mock',
  });
});

app.post('/v1/bitgo/session/demo', async (_req, res, next) => {
  try {
    const sessionToken = randomUUID();
    sessions.set(sessionToken, {
      sessionToken,
      createdAt: new Date().toISOString(),
    });
    res.json({
      sessionToken,
      wallets: await gateway.listWallets(),
    });
  } catch (error) {
    next(error);
  }
});

app.use('/v1/bitgo', (req, res, next) => {
  if (req.path === '/session/demo') {
    next();
    return;
  }
  const auth = req.header('authorization') ?? '';
  const sessionToken = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  if (!sessionToken || !sessions.has(sessionToken)) {
    res.status(401).json({
      message: 'Missing or invalid BitGo demo session token.',
    });
    return;
  }
  next();
});

app.get('/v1/bitgo/wallets', async (_req, res, next) => {
  try {
    res.json({ wallets: await gateway.listWallets() });
  } catch (error) {
    next(error);
  }
});

app.post('/v1/bitgo/transfers', async (req, res, next) => {
  try {
    const body = req.body as Partial<SubmitTransferInput>;
    if (!body.chain || !body.network || !body.walletId) {
      res.status(400).json({ message: 'Missing chain, network, or walletId.' });
      return;
    }
    if (!body.receiverAddress || !body.amountBaseUnits || !body.clientTransferId) {
      res.status(400).json({
        message: 'Missing receiverAddress, amountBaseUnits, or clientTransferId.',
      });
      return;
    }
    const transfer = await gateway.submitTransfer({
      chain: body.chain,
      network: body.network,
      walletId: body.walletId,
      receiverAddress: body.receiverAddress,
      amountBaseUnits: Number(body.amountBaseUnits),
      clientTransferId: body.clientTransferId,
    });
    res.json(transfer);
  } catch (error) {
    next(error);
  }
});

app.get('/v1/bitgo/transfers/:clientTransferId', async (req, res, next) => {
  try {
    const transfer = await gateway.getTransfer(req.params.clientTransferId);
    if (!transfer) {
      res.status(404).json({ message: 'Transfer not found.' });
      return;
    }
    res.json(transfer);
  } catch (error) {
    next(error);
  }
});

app.use(
  (
    error: unknown,
    _req: express.Request,
    res: express.Response,
    _next: express.NextFunction,
  ) => {
    const message =
      error instanceof Error ? error.message : 'Unexpected BitGo backend error.';
    res.status(500).json({ message });
  },
);

app.listen(port, () => {
  console.log(`BitGo backend listening on http://0.0.0.0:${port}`);
  console.log(`Mode: ${hasLiveBitGoConfig() ? 'live' : 'mock'}`);
});

function hasLiveBitGoConfig(): boolean {
  return Boolean(
    process.env.BITGO_ACCESS_TOKEN &&
        process.env.BITGO_WALLET_PASSPHRASE &&
        configuredWallets().length > 0,
  );
}

function configuredWallets(): WalletRecord[] {
  return [
    configuredWalletFromEnv('ethereum', 'testnet'),
    configuredWalletFromEnv('ethereum', 'mainnet'),
    configuredWalletFromEnv('solana', 'testnet'),
    configuredWalletFromEnv('solana', 'mainnet'),
  ].filter((wallet): wallet is WalletRecord => wallet !== null);
}

function configuredWalletFromEnv(
  chain: AppChain,
  network: AppNetwork,
): WalletRecord | null {
  const suffix = `${chain === 'ethereum' ? 'ETH' : 'SOL'}_${
    network === 'testnet' ? 'TESTNET' : 'MAINNET'
  }`;
  const walletId = process.env[`BITGO_${suffix}_WALLET_ID`];
  const address = process.env[`BITGO_${suffix}_ADDRESS`];
  if (!walletId || !address) {
    return null;
  }
  return {
    chain,
    network,
    walletId,
    address,
    displayLabel: `${chain === 'ethereum' ? 'ETH' : 'SOL'} ${
      network === 'testnet' ? 'Testnet' : 'Mainnet'
    }`,
    balanceBaseUnits: 0,
    connectivityStatus: 'connected',
    coin: coinForScope(chain, network),
  };
}

function coinForScope(chain: AppChain, network: AppNetwork): string {
  if (chain === 'solana') {
    return network === 'mainnet' ? 'sol' : 'tsol';
  }
  // BitGo currently uses Holesky for Ethereum testnet.
  return network === 'mainnet' ? 'eth' : 'hteth';
}

function explorerUrlFor(
  chain: AppChain,
  network: AppNetwork,
  transactionSignature?: string,
): string | undefined {
  if (!transactionSignature) {
    return undefined;
  }
  if (chain === 'solana') {
    const cluster = network === 'mainnet' ? '' : '?cluster=devnet';
    return `https://explorer.solana.com/tx/${transactionSignature}${cluster}`;
  }
  const prefix = network === 'mainnet' ? '' : 'sepolia.';
  return `https://${prefix}etherscan.io/tx/${transactionSignature}`;
}

class MockBitGoGateway implements Gateway {
  private readonly wallets: WalletRecord[] = configuredWallets().length > 0
    ? configuredWallets()
    : [
        {
          chain: 'ethereum',
          network: 'testnet',
          walletId: 'demo-eth-testnet',
          address: '0x1111111111111111111111111111111111111111',
          displayLabel: 'Demo ETH Testnet',
          balanceBaseUnits: 50000000000000000,
          connectivityStatus: 'connected',
          coin: 'hteth',
        },
        {
          chain: 'solana',
          network: 'testnet',
          walletId: 'demo-sol-testnet',
          address: '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
          displayLabel: 'Demo SOL Testnet',
          balanceBaseUnits: 1500000000,
          connectivityStatus: 'connected',
          coin: 'tsol',
        },
      ];

  private readonly transfers = new Map<string, TransferRecord>();

  async listWallets(): Promise<WalletRecord[]> {
    return this.wallets;
  }

  async submitTransfer(input: SubmitTransferInput): Promise<TransferRecord> {
    const wallet = this.wallets.find(
      (item) =>
        item.walletId === input.walletId &&
        item.chain === input.chain &&
        item.network === input.network,
    );
    if (!wallet) {
      throw new Error('Configured BitGo wallet was not found for this scope.');
    }
    if (input.amountBaseUnits > wallet.balanceBaseUnits) {
      throw new Error('BitGo wallet balance is too low for that transfer.');
    }
    const transactionSignature = randomUUID().replaceAll('-', '');
    const transfer: TransferRecord = {
      clientTransferId: input.clientTransferId,
      bitgoTransferId: randomUUID(),
      bitgoWalletId: wallet.walletId,
      chain: input.chain,
      network: input.network,
      receiverAddress: input.receiverAddress,
      amountBaseUnits: input.amountBaseUnits,
      status: 'submitted',
      transactionSignature,
      explorerUrl: explorerUrlFor(
        input.chain,
        input.network,
        transactionSignature,
      ),
      updatedAt: new Date().toISOString(),
    };
    wallet.balanceBaseUnits -= input.amountBaseUnits;
    this.transfers.set(input.clientTransferId, transfer);
    return transfer;
  }

  async getTransfer(clientTransferId: string): Promise<TransferRecord | null> {
    const transfer = this.transfers.get(clientTransferId);
    if (!transfer) {
      return null;
    }
    const ageMs =
      Date.now() - new Date(transfer.updatedAt).getTime();
    if (ageMs > 8000 && transfer.status === 'submitted') {
      transfer.status = 'confirmed';
      transfer.updatedAt = new Date().toISOString();
    }
    return transfer;
  }
}

class LiveBitGoGateway implements Gateway {
  private readonly bitgo: BitGoAPI;
  private readonly wallets = configuredWallets();
  private readonly transfers = new Map<string, TransferRecord>();

  constructor() {
    this.bitgo = new BitGoAPI({
      env: (process.env.BITGO_ENV as 'test' | 'prod') ?? 'test',
      accessToken: process.env.BITGO_ACCESS_TOKEN,
    });
    this.bitgo.register('eth', Eth.createInstance);
    this.bitgo.register('hteth', Eth.createInstance);
    this.bitgo.register('sol', Sol.createInstance);
    this.bitgo.register('tsol', Sol.createInstance);
  }

  async listWallets(): Promise<WalletRecord[]> {
    const enriched = await Promise.all(
      this.wallets.map(async (wallet) => {
        try {
          const sdkWallet = await this.getSdkWallet(wallet);
          const rawBalance =
            (typeof sdkWallet.balanceString === 'function'
              ? sdkWallet.balanceString()
              : sdkWallet.balanceString) ?? '0';
          return {
            ...wallet,
            balanceBaseUnits: Number.parseInt(String(rawBalance), 10) || 0,
          };
        } catch {
          return wallet;
        }
      }),
    );
    return enriched;
  }

  async submitTransfer(input: SubmitTransferInput): Promise<TransferRecord> {
    const wallet = this.wallets.find(
      (item) =>
        item.walletId === input.walletId &&
        item.chain === input.chain &&
        item.network === input.network,
    );
    if (!wallet) {
      throw new Error('Configured BitGo wallet was not found for this scope.');
    }
    const sdkWallet = await this.getSdkWallet(wallet);
    const result = await sdkWallet.sendMany({
      recipients: [
        {
          amount: String(input.amountBaseUnits),
          address: input.receiverAddress,
        },
      ],
      walletPassphrase: process.env.BITGO_WALLET_PASSPHRASE,
    });
    const transactionSignature =
      result?.transfer?.txid ??
      result?.txid ??
      result?.hash ??
      result?.transfer?.hash;
    const transfer: TransferRecord = {
      clientTransferId: input.clientTransferId,
      bitgoTransferId:
        result?.transfer?.id ?? result?.id ?? randomUUID(),
      bitgoWalletId: wallet.walletId,
      chain: input.chain,
      network: input.network,
      receiverAddress: input.receiverAddress,
      amountBaseUnits: input.amountBaseUnits,
      status: 'submitted',
      transactionSignature,
      explorerUrl: explorerUrlFor(
        input.chain,
        input.network,
        transactionSignature,
      ),
      updatedAt: new Date().toISOString(),
    };
    this.transfers.set(input.clientTransferId, transfer);
    return transfer;
  }

  async getTransfer(clientTransferId: string): Promise<TransferRecord | null> {
    const transfer = this.transfers.get(clientTransferId);
    if (!transfer) {
      return null;
    }
    return transfer;
  }

  private async getSdkWallet(wallet: WalletRecord): Promise<any> {
    return this.bitgo.coin(wallet.coin).wallets().get({ id: wallet.walletId });
  }
}

gateway = hasLiveBitGoConfig()
  ? new LiveBitGoGateway()
  : new MockBitGoGateway();
