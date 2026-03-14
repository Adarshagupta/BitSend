import { DurableObject } from 'cloudflare:workers';

type AppChain = 'ethereum' | 'solana';
type AppNetwork = 'testnet' | 'mainnet';
type GatewayMode = 'mock' | 'live';

type WalletRecord = {
  chain: AppChain;
  network: AppNetwork;
  walletId: string;
  address: string;
  displayLabel: string;
  balanceBaseUnits: string;
  connectivityStatus: string;
  coin: string;
  lastSyncedAt?: string;
};

type TransferRecord = {
  clientTransferId: string;
  bitgoTransferId: string;
  bitgoWalletId: string;
  chain: AppChain;
  network: AppNetwork;
  receiverAddress: string;
  amountBaseUnits: string;
  status: string;
  gatewayMode: GatewayMode;
  transactionSignature?: string;
  explorerUrl?: string;
  message?: string;
  updatedAt: string;
};

type SessionRecord = {
  sessionToken: string;
  createdAt: string;
  expiresAt: string;
};

type SubmitTransferInput = {
  chain: AppChain;
  network: AppNetwork;
  walletId: string;
  receiverAddress: string;
  amountBaseUnits: string;
  clientTransferId: string;
};

interface Env {
  BITGO_STATE: DurableObjectNamespace<BitGoState>;
  BITGO_ENV?: 'test' | 'prod';
  BITGO_ACCESS_TOKEN?: string;
  BITGO_WALLET_PASSPHRASE?: string;
  BITGO_ETH_TESTNET_WALLET_ID?: string;
  BITGO_ETH_TESTNET_ADDRESS?: string;
  BITGO_ETH_MAINNET_WALLET_ID?: string;
  BITGO_ETH_MAINNET_ADDRESS?: string;
  BITGO_SOL_TESTNET_WALLET_ID?: string;
  BITGO_SOL_TESTNET_ADDRESS?: string;
  BITGO_SOL_MAINNET_WALLET_ID?: string;
  BITGO_SOL_MAINNET_ADDRESS?: string;
}

const sessionLifetimeMs = 7 * 24 * 60 * 60 * 1000;
const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders,
      });
    }

    const url = new URL(request.url);
    const state = getStateStub(env);

    try {
      if (request.method === 'GET' && url.pathname === '/health') {
        return jsonResponse({
          ok: true,
          mode: 'mock',
        });
      }

      if (
        request.method === 'POST' &&
        url.pathname === '/v1/bitgo/session/demo'
      ) {
        const sessionToken = crypto.randomUUID();
        const now = new Date();
        await state.createSession({
          sessionToken,
          createdAt: now.toISOString(),
          expiresAt: new Date(now.getTime() + sessionLifetimeMs).toISOString(),
        });
        return jsonResponse({
          sessionToken,
          wallets: await listWallets(env, state),
        });
      }

      if (url.pathname.startsWith('/v1/bitgo/')) {
        const authorized = await authorize(request, state);
        if (!authorized) {
          return jsonResponse(
            { message: 'Missing or invalid BitGo demo session token.' },
            401,
          );
        }
      }

      if (request.method === 'GET' && url.pathname === '/v1/bitgo/wallets') {
        return jsonResponse({
          wallets: await listWallets(env, state),
        });
      }

      if (request.method === 'POST' && url.pathname === '/v1/bitgo/transfers') {
        const body = await parseJsonBody(request);
        const input = validateSubmitTransferInput(body);
        const transfer = await submitTransfer(env, state, input);
        return jsonResponse(transfer);
      }

      if (
        request.method === 'GET' &&
        url.pathname.startsWith('/v1/bitgo/transfers/')
      ) {
        const clientTransferId = decodeURIComponent(
          url.pathname.substring('/v1/bitgo/transfers/'.length),
        );
        const transfer = await getTransfer(env, state, clientTransferId);
        if (!transfer) {
          return jsonResponse({ message: 'Transfer not found.' }, 404);
        }
        return jsonResponse(transfer);
      }

      return jsonResponse({ message: 'Not found.' }, 404);
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : 'Unexpected BitGo backend error.';
      return jsonResponse(
        { message },
        error instanceof HttpError ? error.status : 500,
      );
    }
  },
};

export class BitGoState extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
  }

  async createSession(session: SessionRecord): Promise<void> {
    await this.ctx.storage.put(sessionStorageKey(session.sessionToken), session);
  }

  async hasSession(sessionToken: string): Promise<boolean> {
    if (!sessionToken) {
      return false;
    }
    const session = await this.ctx.storage.get<SessionRecord>(
      sessionStorageKey(sessionToken),
    );
    if (!session) {
      return false;
    }
    if (Date.parse(session.expiresAt) <= Date.now()) {
      await this.ctx.storage.delete(sessionStorageKey(sessionToken));
      return false;
    }
    return true;
  }

  async saveTransfer(transfer: TransferRecord): Promise<void> {
    await this.ctx.storage.put(transferStorageKey(transfer.clientTransferId), transfer);
  }

  async loadTransfer(clientTransferId: string): Promise<TransferRecord | null> {
    return (
      (await this.ctx.storage.get<TransferRecord>(
        transferStorageKey(clientTransferId),
      )) ?? null
    );
  }

  async saveMockBalance(walletId: string, balanceBaseUnits: string): Promise<void> {
    await this.ctx.storage.put(walletBalanceKey(walletId), balanceBaseUnits);
  }

  async loadMockBalance(walletId: string): Promise<string | null> {
    return (
      (await this.ctx.storage.get<string>(walletBalanceKey(walletId))) ?? null
    );
  }
}

function getStateStub(env: Env): DurableObjectStub<BitGoState> {
  const id = env.BITGO_STATE.idFromName('global');
  return env.BITGO_STATE.get(id);
}

async function authorize(
  request: Request,
  state: DurableObjectStub<BitGoState>,
): Promise<boolean> {
  const auth = request.headers.get('authorization') ?? '';
  const sessionToken = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  return state.hasSession(sessionToken);
}

function getGatewayMode(env: Env): GatewayMode {
  return 'mock';
}

async function listWallets(
  env: Env,
  state: DurableObjectStub<BitGoState>,
): Promise<WalletRecord[]> {
  return listMockWallets(env, state);
}

async function listMockWallets(
  env: Env,
  state: DurableObjectStub<BitGoState>,
): Promise<WalletRecord[]> {
  const baseWallets = configuredWalletsFromEnv(env);
  const defaults = baseWallets.length > 0
    ? mergeMockDefaults(baseWallets)
    : defaultMockWallets();
  const nextWallets = await Promise.all(
    defaults.map(async (wallet) => {
      const overrideBalance = await state.loadMockBalance(wallet.walletId);
      return {
        ...wallet,
        balanceBaseUnits: overrideBalance ?? wallet.balanceBaseUnits,
      };
    }),
  );
  return nextWallets;
}

async function submitTransfer(
  env: Env,
  state: DurableObjectStub<BitGoState>,
  input: SubmitTransferInput,
): Promise<TransferRecord> {
  return submitMockTransfer(env, state, input);
}

async function submitMockTransfer(
  env: Env,
  state: DurableObjectStub<BitGoState>,
  input: SubmitTransferInput,
): Promise<TransferRecord> {
  const wallets = await listMockWallets(env, state);
  const wallet = wallets.find(
    (item) =>
      item.walletId === input.walletId &&
      item.chain === input.chain &&
      item.network === input.network,
  );
  if (!wallet) {
    throw new HttpError(
      404,
      'Configured BitGo wallet was not found for this scope.',
    );
  }

  const balance = parseBaseUnits(wallet.balanceBaseUnits);
  const amount = parseBaseUnits(input.amountBaseUnits);
  if (amount > balance) {
    throw new HttpError(
      400,
      'BitGo wallet balance is too low for that transfer.',
    );
  }

  const transactionSignature = crypto.randomUUID().replaceAll('-', '');
  const transfer: TransferRecord = {
    clientTransferId: input.clientTransferId,
    bitgoTransferId: crypto.randomUUID(),
    bitgoWalletId: wallet.walletId,
    chain: input.chain,
    network: input.network,
    receiverAddress: input.receiverAddress,
    amountBaseUnits: input.amountBaseUnits,
    status: 'submitted',
    gatewayMode: 'mock',
    transactionSignature,
    explorerUrl: explorerUrlFor(
      input.chain,
      input.network,
      transactionSignature,
    ),
    updatedAt: new Date().toISOString(),
  };

  await state.saveMockBalance(
    wallet.walletId,
    (balance - amount).toString(),
  );
  await state.saveTransfer(transfer);
  return transfer;
}

async function getTransfer(
  env: Env,
  state: DurableObjectStub<BitGoState>,
  clientTransferId: string,
): Promise<TransferRecord | null> {
  const current = await state.loadTransfer(clientTransferId);
  if (!current) {
    return null;
  }
  const ageMs = Date.now() - Date.parse(current.updatedAt);
  if (current.status === 'submitted' && ageMs > 8000) {
    const confirmed = {
      ...current,
      status: 'confirmed',
      updatedAt: new Date().toISOString(),
    };
    await state.saveTransfer(confirmed);
    return confirmed;
  }
  return current;
}

function configuredWalletsFromEnv(env: Env): WalletRecord[] {
  return [
    configuredWalletFromEnv(env, 'ethereum', 'testnet'),
    configuredWalletFromEnv(env, 'ethereum', 'mainnet'),
    configuredWalletFromEnv(env, 'solana', 'testnet'),
    configuredWalletFromEnv(env, 'solana', 'mainnet'),
  ].filter((wallet): wallet is WalletRecord => wallet !== null);
}

function configuredWalletFromEnv(
  env: Env,
  chain: AppChain,
  network: AppNetwork,
): WalletRecord | null {
  const suffix = `${chain === 'ethereum' ? 'ETH' : 'SOL'}_${
    network === 'testnet' ? 'TESTNET' : 'MAINNET'
  }`;
  const walletId = env[`BITGO_${suffix}_WALLET_ID` as keyof Env] as string | undefined;
  const address = env[`BITGO_${suffix}_ADDRESS` as keyof Env] as string | undefined;
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
    balanceBaseUnits: '0',
    connectivityStatus: 'connected',
    coin: coinForScope(chain, network),
  };
}

function defaultMockWallets(): WalletRecord[] {
  return [
    {
      chain: 'ethereum',
      network: 'testnet',
      walletId: 'demo-eth-testnet',
      address: '0x1111111111111111111111111111111111111111',
      displayLabel: 'Demo ETH Testnet',
      balanceBaseUnits: '50000000000000000',
      connectivityStatus: 'demo',
      coin: 'hteth',
    },
    {
      chain: 'ethereum',
      network: 'mainnet',
      walletId: 'demo-eth-mainnet',
      address: '0x2222222222222222222222222222222222222222',
      displayLabel: 'Demo ETH Mainnet',
      balanceBaseUnits: '12000000000000000',
      connectivityStatus: 'demo',
      coin: 'eth',
    },
    {
      chain: 'solana',
      network: 'testnet',
      walletId: 'demo-sol-testnet',
      address: '5g7hH9bN2YpQkFjYB1rR5L8uD1sWnXwqJ8z2tP5eQk1Z',
      displayLabel: 'Demo SOL Testnet',
      balanceBaseUnits: '1500000000',
      connectivityStatus: 'demo',
      coin: 'tsol',
    },
    {
      chain: 'solana',
      network: 'mainnet',
      walletId: 'demo-sol-mainnet',
      address: 'C6gTQX2hFQf6yLC3xGx9pPYoUXKcLhjMUM3E2hD4AmuM',
      displayLabel: 'Demo SOL Mainnet',
      balanceBaseUnits: '750000000',
      connectivityStatus: 'demo',
      coin: 'sol',
    },
  ];
}

function mergeMockDefaults(wallets: WalletRecord[]): WalletRecord[] {
  const defaultsByScope = new Map<string, WalletRecord>(
    defaultMockWallets().map((wallet) => [
      scopeKey(wallet.chain, wallet.network),
      wallet,
    ]),
  );
  return wallets.map((wallet) => {
    const defaultWallet = defaultsByScope.get(
      scopeKey(wallet.chain, wallet.network),
    );
    return {
      ...wallet,
      displayLabel: wallet.displayLabel.length > 0
          ? wallet.displayLabel
          : (defaultWallet?.displayLabel ?? wallet.displayLabel),
      balanceBaseUnits:
          defaultWallet?.balanceBaseUnits ?? wallet.balanceBaseUnits,
      connectivityStatus: 'demo',
    };
  });
}

function validateSubmitTransferInput(body: unknown): SubmitTransferInput {
  if (typeof body !== 'object' || body == null) {
    throw new HttpError(400, 'Invalid transfer payload.');
  }
  const input = body as Record<string, unknown>;
  const chain = input.chain;
  const network = input.network;
  const walletId = sanitizeString(input.walletId);
  const receiverAddress = sanitizeString(input.receiverAddress);
  const clientTransferId = sanitizeString(input.clientTransferId);
  const amountBaseUnits = normalizeBaseUnits(input.amountBaseUnits);

  if (chain !== 'ethereum' && chain !== 'solana') {
    throw new HttpError(400, 'Missing chain.');
  }
  if (network !== 'testnet' && network !== 'mainnet') {
    throw new HttpError(400, 'Missing network.');
  }
  if (!walletId) {
    throw new HttpError(400, 'Missing walletId.');
  }
  if (!receiverAddress) {
    throw new HttpError(400, 'Missing receiverAddress.');
  }
  if (!clientTransferId) {
    throw new HttpError(400, 'Missing clientTransferId.');
  }
  if (parseBaseUnits(amountBaseUnits) <= 0n) {
    throw new HttpError(400, 'amountBaseUnits must be greater than zero.');
  }

  return {
    chain,
    network,
    walletId,
    receiverAddress,
    amountBaseUnits,
    clientTransferId,
  };
}

async function parseJsonBody(request: Request): Promise<unknown> {
  try {
    return await request.json();
  } catch {
    throw new HttpError(400, 'Request body must be valid JSON.');
  }
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders,
    },
  });
}

function coinForScope(chain: AppChain, network: AppNetwork): string {
  if (chain === 'solana') {
    return network === 'mainnet' ? 'sol' : 'tsol';
  }
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

function normalizeBaseUnits(value: unknown): string {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (/^\d+$/.test(trimmed)) {
      return trimmed;
    }
  }
  if (typeof value === 'number' && Number.isFinite(value) && value >= 0) {
    return Math.trunc(value).toString();
  }
  if (typeof value === 'bigint' && value >= 0n) {
    return value.toString();
  }
  return '0';
}

function parseBaseUnits(value: unknown): bigint {
  const normalized = normalizeBaseUnits(value);
  try {
    return BigInt(normalized);
  } catch {
    throw new HttpError(400, 'Invalid amountBaseUnits.');
  }
}

function pickString(...values: unknown[]): string | null {
  for (const value of values) {
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
  }
  return null;
}

function sanitizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function sessionStorageKey(sessionToken: string): string {
  return `session:${sessionToken}`;
}

function transferStorageKey(clientTransferId: string): string {
  return `transfer:${clientTransferId}`;
}

function walletBalanceKey(walletId: string): string {
  return `wallet:${walletId}:balance`;
}

function scopeKey(chain: AppChain, network: AppNetwork): string {
  return `${chain}:${network}`;
}
