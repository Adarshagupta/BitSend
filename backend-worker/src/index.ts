import { DurableObject } from 'cloudflare:workers';

type AppChain = 'ethereum' | 'solana';
type AppNetwork = 'testnet' | 'mainnet';
type GatewayMode = 'mock' | 'live';
type FileverseStorageMode = 'fileverse' | 'worker';

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

type FileverseReceiptInput = {
  transferId: string;
  chain: AppChain;
  network: AppNetwork;
  walletEngine: 'local' | 'bitgo';
  direction: 'inbound' | 'outbound';
  status: string;
  amountBaseUnits: string;
  amountLabel: string;
  senderAddress: string;
  receiverAddress: string;
  transport: 'hotspot' | 'ble';
  updatedAt: string;
  createdAt: string;
  transactionSignature?: string;
  explorerUrl?: string;
  receiptPngBase64: string;
};

type FileverseReceiptRecord = {
  receiptId: string;
  receiptUrl: string;
  savedAt: string;
  upstreamUrl?: string;
  storageMode: FileverseStorageMode;
  message?: string;
};

type StoredFileverseReceiptRecord = FileverseReceiptRecord & {
  transferId: string;
  chain: AppChain;
  network: AppNetwork;
  walletEngine: 'local' | 'bitgo';
  direction: 'inbound' | 'outbound';
  status: string;
  amountBaseUnits: string;
  amountLabel: string;
  senderAddress: string;
  receiverAddress: string;
  transport: 'hotspot' | 'ble';
  updatedAt: string;
  createdAt: string;
  transactionSignature?: string;
  explorerUrl?: string;
  receiptPngBase64: string;
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
  FILEVERSE_API_KEY?: string;
  FILEVERSE_RECEIPT_UPSTREAM?: string;
  FILEVERSE_DDOCS_ENDPOINT?: string;
}

const sessionLifetimeMs = 7 * 24 * 60 * 60 * 1000;
const fileverseSyncPollAttempts = 45;
const fileverseSyncPollDelayMs = 2000;
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
        const sessionToken = await createSession(state);
        return jsonResponse({
          sessionToken,
          wallets: await listWallets(env, state),
        });
      }

      if (
        request.method === 'POST' &&
        url.pathname === '/v1/fileverse/session/demo'
      ) {
        const sessionToken = await createSession(state);
        return jsonResponse({
          sessionToken,
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

      if (url.pathname.startsWith('/v1/fileverse/')) {
        const authorized = await authorize(request, state);
        if (!authorized) {
          return jsonResponse(
            { message: 'Missing or invalid Fileverse session token.' },
            401,
          );
        }
      }

      if (
        request.method === 'GET' &&
        url.pathname.startsWith('/fileverse/receipts/')
      ) {
        const receiptId = decodeURIComponent(
          url.pathname.substring('/fileverse/receipts/'.length),
        );
        const receipt = await state.loadFileverseReceipt(receiptId);
        if (!receipt) {
          return htmlResponse(renderNotFoundPage(), 404);
        }
        return htmlResponse(renderFileverseReceiptPage(receipt));
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

      if (
        request.method === 'POST' &&
        url.pathname === '/v1/fileverse/receipts'
      ) {
        const body = await parseJsonBody(request);
        const input = validateFileverseReceiptInput(body);
        const receipt = await publishFileverseReceipt(
          env,
          state,
          url.origin,
          input,
        );
        return jsonResponse(receipt);
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

  async saveFileverseReceipt(
    receipt: StoredFileverseReceiptRecord,
  ): Promise<void> {
    await this.ctx.storage.put(fileverseReceiptKey(receipt.receiptId), receipt);
  }

  async loadFileverseReceipt(
    receiptId: string,
  ): Promise<StoredFileverseReceiptRecord | null> {
    return (
      (await this.ctx.storage.get<StoredFileverseReceiptRecord>(
        fileverseReceiptKey(receiptId),
      )) ?? null
    );
  }
}

async function createSession(
  state: DurableObjectStub<BitGoState>,
): Promise<string> {
  const sessionToken = crypto.randomUUID();
  const now = new Date();
  await state.createSession({
    sessionToken,
    createdAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + sessionLifetimeMs).toISOString(),
  });
  return sessionToken;
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

async function publishFileverseReceipt(
  env: Env,
  state: DurableObjectStub<BitGoState>,
  origin: string,
  input: FileverseReceiptInput,
): Promise<FileverseReceiptRecord> {
  const archiveReceiptId = `bitsend-${input.transferId}-${crypto.randomUUID().slice(0, 8)}`;
  const archiveReceiptUrl = new URL(
    `/fileverse/receipts/${encodeURIComponent(archiveReceiptId)}`,
    origin,
  ).toString();

  const persistReceipt = async ({
    savedAt,
    upstreamUrl,
    responseReceiptId,
    responseReceiptUrl,
    storageMode,
    message,
  }: {
    savedAt?: string;
    upstreamUrl?: string;
    responseReceiptId?: string;
    responseReceiptUrl?: string;
    storageMode: FileverseStorageMode;
    message?: string;
  }): Promise<FileverseReceiptRecord> => {
    const resolvedSavedAt = savedAt ?? new Date().toISOString();
    const receipt: StoredFileverseReceiptRecord = {
      receiptId: archiveReceiptId,
      receiptUrl: archiveReceiptUrl,
      savedAt: resolvedSavedAt,
      upstreamUrl,
      storageMode,
      message,
      transferId: input.transferId,
      chain: input.chain,
      network: input.network,
      walletEngine: input.walletEngine,
      direction: input.direction,
      status: input.status,
      amountBaseUnits: input.amountBaseUnits,
      amountLabel: input.amountLabel,
      senderAddress: input.senderAddress,
      receiverAddress: input.receiverAddress,
      transport: input.transport,
      updatedAt: input.updatedAt,
      createdAt: input.createdAt,
      transactionSignature: input.transactionSignature,
      explorerUrl: input.explorerUrl,
      receiptPngBase64: input.receiptPngBase64,
    };
    await state.saveFileverseReceipt(receipt);
    return {
      receiptId: responseReceiptId ?? receipt.receiptId,
      receiptUrl: responseReceiptUrl ?? receipt.receiptUrl,
      savedAt: receipt.savedAt,
      upstreamUrl: receipt.upstreamUrl,
      storageMode: receipt.storageMode,
      message: receipt.message,
    };
  };

  const apiKey = pickString(env.FILEVERSE_API_KEY);
  const ddocsEndpoint = pickString(env.FILEVERSE_DDOCS_ENDPOINT);
  const upstream = pickString(env.FILEVERSE_RECEIPT_UPSTREAM);

  if (apiKey && ddocsEndpoint) {
    try {
      const endpoint = appendApiKey(ddocsEndpoint, apiKey);
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          title: buildFileverseReceiptTitle(input),
          content: buildFileverseReceiptMarkdown(input, archiveReceiptUrl),
        }),
      });
      const rawBody = await response.text();
      const payload = rawBody.trim().length === 0
        ? {}
        : tryParseJsonObject(rawBody);
      if (!response.ok) {
        throw new HttpError(
          response.status,
          pickString(
            payload.message,
            payload.error,
            payload.reason,
          ) ?? `Fileverse ddoc publish failed (${response.status}).`,
        );
      }
      const ddoc = await waitForFileverseDdocLink(
        ddocsEndpoint,
        apiKey,
        payload,
      );
      return persistReceipt({
        savedAt: ddoc.savedAt,
        upstreamUrl: ddoc.link,
        responseReceiptId: ddoc.ddocId,
        responseReceiptUrl: ddoc.link,
        storageMode: 'fileverse',
        message:
          'Receipt details were saved to Fileverse. The Bitsend archive keeps the captured screenshot.',
      });
    } catch (error) {
      console.error(
        'Fileverse ddoc publish failed, trying legacy upload path.',
        error,
      );
    }
  }

  if (!apiKey || !upstream) {
    return persistReceipt({
      storageMode: 'worker',
      message:
        'Receipt archived on the Bitsend Worker because the Fileverse upstream is not configured yet.',
    });
  }

  try {
    const response = await fetch(upstream, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
        'x-api-key': apiKey,
      },
      body: JSON.stringify(input),
    });
    const rawBody = await response.text();
    const payload = rawBody.trim().length === 0
      ? {}
      : tryParseJsonObject(rawBody);
    if (!response.ok) {
      throw new HttpError(
        response.status,
        pickString(
          payload.message,
          payload.error,
          payload.reason,
        ) ?? `Fileverse upstream failed (${response.status}).`,
      );
    }
    const upstreamReceipt = normalizeFileverseReceiptRecord(
      payload,
      input.transferId,
    );
    return persistReceipt({
      savedAt: upstreamReceipt.savedAt,
      upstreamUrl: upstreamReceipt.upstreamUrl,
      responseReceiptId: upstreamReceipt.receiptId,
      responseReceiptUrl: upstreamReceipt.receiptUrl,
      storageMode: upstreamReceipt.storageMode,
      message:
        'Receipt saved to Fileverse and mirrored to the Bitsend Worker link.',
    });
  } catch (error) {
    console.error(
      'Fileverse upstream publish failed, archiving on Worker.',
      error,
    );
    return persistReceipt({
      storageMode: 'worker',
      message:
        'Receipt archived on the Bitsend Worker because Fileverse was unavailable.',
    });
  }
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

function validateFileverseReceiptInput(body: unknown): FileverseReceiptInput {
  if (typeof body !== 'object' || body == null) {
    throw new HttpError(400, 'Invalid Fileverse receipt payload.');
  }
  const input = body as Record<string, unknown>;
  const chain = input.chain;
  const network = input.network;
  const walletEngine = input.walletEngine;
  const direction = input.direction;
  const transport = input.transport;
  const transferId = sanitizeString(input.transferId);
  const status = sanitizeString(input.status);
  const amountBaseUnits = normalizeBaseUnits(input.amountBaseUnits);
  const amountLabel = sanitizeString(input.amountLabel);
  const senderAddress = sanitizeString(input.senderAddress);
  const receiverAddress = sanitizeString(input.receiverAddress);
  const updatedAt = sanitizeString(input.updatedAt);
  const createdAt = sanitizeString(input.createdAt);
  const transactionSignature = pickString(input.transactionSignature);
  const explorerUrl = pickString(input.explorerUrl);
  const receiptPngBase64 = sanitizeString(input.receiptPngBase64);

  if (chain !== 'ethereum' && chain !== 'solana') {
    throw new HttpError(400, 'Missing chain.');
  }
  if (network !== 'testnet' && network !== 'mainnet') {
    throw new HttpError(400, 'Missing network.');
  }
  if (walletEngine !== 'local' && walletEngine !== 'bitgo') {
    throw new HttpError(400, 'Missing walletEngine.');
  }
  if (direction !== 'inbound' && direction !== 'outbound') {
    throw new HttpError(400, 'Missing direction.');
  }
  if (transport !== 'hotspot' && transport !== 'ble') {
    throw new HttpError(400, 'Missing transport.');
  }
  if (!transferId) {
    throw new HttpError(400, 'Missing transferId.');
  }
  if (!status) {
    throw new HttpError(400, 'Missing status.');
  }
  if (parseBaseUnits(amountBaseUnits) <= 0n) {
    throw new HttpError(400, 'amountBaseUnits must be greater than zero.');
  }
  if (!amountLabel) {
    throw new HttpError(400, 'Missing amountLabel.');
  }
  if (!senderAddress || !receiverAddress) {
    throw new HttpError(400, 'Missing sender or receiver address.');
  }
  if (!updatedAt || !createdAt) {
    throw new HttpError(400, 'Missing receipt timestamps.');
  }
  if (!receiptPngBase64) {
    throw new HttpError(400, 'Missing receipt image.');
  }

  return {
    transferId,
    chain,
    network,
    walletEngine,
    direction,
    status,
    amountBaseUnits,
    amountLabel,
    senderAddress,
    receiverAddress,
    transport,
    updatedAt,
    createdAt,
    transactionSignature: transactionSignature ?? undefined,
    explorerUrl: explorerUrl ?? undefined,
    receiptPngBase64,
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

function tryParseJsonObject(raw: string): Record<string, unknown> {
  try {
    const parsed = JSON.parse(raw) as unknown;
    return typeof parsed === 'object' && parsed != null
      ? parsed as Record<string, unknown>
      : {};
  } catch {
    return {};
  }
}

function extractPayloadData(
  payload: Record<string, unknown>,
): Record<string, unknown> {
  return typeof payload.data === 'object' && payload.data != null
    ? payload.data as Record<string, unknown>
    : payload;
}

type FileverseDdocRecord = {
  ddocId: string;
  link: string | null;
  syncStatus: string;
  savedAt: string;
};

function normalizeFileverseDdocRecord(
  payload: Record<string, unknown>,
): FileverseDdocRecord {
  const data = extractPayloadData(payload);
  const ddocId = pickString(data.ddocId, data.id);
  if (!ddocId) {
    throw new HttpError(
      502,
      'Fileverse ddoc response did not include a document id.',
    );
  }
  return {
    ddocId,
    link: pickString(
      data.link,
      data.url,
      data.shareUrl,
      data.publicUrl,
      data.documentUrl,
    ),
    syncStatus: sanitizeString(data.syncStatus).toLowerCase() || 'pending',
    savedAt:
      pickString(data.updatedAt, data.createdAt) ?? new Date().toISOString(),
  };
}

function normalizeFileverseReceiptRecord(
  payload: Record<string, unknown>,
  fallbackTransferId: string,
): FileverseReceiptRecord {
  const data = extractPayloadData(payload);
  const receiptId =
    pickString(data.receiptId, data.id, data.documentId, fallbackTransferId) ??
    fallbackTransferId;
  const receiptUrl = pickString(
    data.receiptUrl,
    data.url,
    data.shareUrl,
    data.publicUrl,
    data.documentUrl,
  );
  if (!receiptUrl) {
    throw new HttpError(
      502,
      'Fileverse response did not include a receipt URL.',
    );
  }
  return {
    receiptId,
    receiptUrl,
    savedAt:
      pickString(data.savedAt, data.createdAt, data.updatedAt) ??
      new Date().toISOString(),
    upstreamUrl: receiptUrl,
    storageMode: 'fileverse',
  };
}

function appendApiKey(endpoint: string, apiKey: string): string {
  const url = new URL(endpoint);
  if (!url.searchParams.has('apiKey')) {
    url.searchParams.set('apiKey', apiKey);
  }
  return url.toString();
}

function buildFileverseDdocDetailsEndpoint(
  ddocsEndpoint: string,
  ddocId: string,
): string {
  const url = new URL(ddocsEndpoint);
  const pathname = url.pathname.endsWith('/')
    ? url.pathname.slice(0, -1)
    : url.pathname;
  url.pathname = `${pathname}/${encodeURIComponent(ddocId)}`;
  return url.toString();
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function waitForFileverseDdocLink(
  ddocsEndpoint: string,
  apiKey: string,
  payload: Record<string, unknown>,
): Promise<FileverseDdocRecord & { link: string }> {
  let ddoc = normalizeFileverseDdocRecord(payload);
  if (ddoc.link) {
    return {
      ...ddoc,
      link: ddoc.link,
    };
  }
  if (ddoc.syncStatus === 'failed') {
    throw new HttpError(502, 'Fileverse ddoc sync failed.');
  }

  const detailsEndpoint = appendApiKey(
    buildFileverseDdocDetailsEndpoint(ddocsEndpoint, ddoc.ddocId),
    apiKey,
  );

  for (let attempt = 0; attempt < fileverseSyncPollAttempts; attempt += 1) {
    await delay(fileverseSyncPollDelayMs);
    const response = await fetch(detailsEndpoint, {
      headers: {
        'Accept': 'application/json',
      },
    });
    const rawBody = await response.text();
    const nextPayload = rawBody.trim().length === 0
      ? {}
      : tryParseJsonObject(rawBody);
    if (!response.ok) {
      throw new HttpError(
        response.status,
        pickString(
          nextPayload.message,
          nextPayload.error,
          nextPayload.reason,
        ) ?? `Fileverse ddoc sync check failed (${response.status}).`,
      );
    }
    ddoc = normalizeFileverseDdocRecord(nextPayload);
    if (ddoc.link && ddoc.syncStatus === 'synced') {
      return {
        ...ddoc,
        link: ddoc.link,
      };
    }
    if (ddoc.syncStatus === 'failed') {
      throw new HttpError(502, 'Fileverse ddoc sync failed.');
    }
  }

  throw new HttpError(
    504,
    'Fileverse ddoc did not finish syncing before timeout.',
  );
}

function buildFileverseReceiptTitle(input: FileverseReceiptInput): string {
  return `Bitsend ${input.amountLabel} receipt ${input.transferId.slice(0, 8)}`;
}

function buildFileverseReceiptMarkdown(
  input: FileverseReceiptInput,
  archiveReceiptUrl: string,
): string {
  const explorerLine = input.explorerUrl
    ? `- Explorer: ${input.explorerUrl}`
    : '';
  const signatureLine = input.transactionSignature
    ? `- Transaction: ${input.transactionSignature}`
    : '';
  return [
    `# Bitsend receipt`,
    ``,
    `- Transfer ID: ${input.transferId}`,
    `- Chain: ${input.chain}`,
    `- Network: ${input.network}`,
    `- Wallet engine: ${input.walletEngine}`,
    `- Direction: ${input.direction}`,
    `- Status: ${input.status}`,
    `- Amount: ${input.amountLabel}`,
    `- Sender: ${input.senderAddress}`,
    `- Receiver: ${input.receiverAddress}`,
    `- Transport: ${input.transport}`,
    `- Created at: ${input.createdAt}`,
    `- Updated at: ${input.updatedAt}`,
    signatureLine,
    explorerLine,
    ``,
    `## Captured proof`,
    ``,
    `- Receipt archive: ${archiveReceiptUrl}`,
  ].filter((line) => line.length > 0).join('\n');
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

function fileverseReceiptKey(receiptId: string): string {
  return `fileverse:${receiptId}`;
}

function scopeKey(chain: AppChain, network: AppNetwork): string {
  return `${chain}:${network}`;
}

function htmlResponse(body: string, status = 200): Response {
  return new Response(body, {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function renderNotFoundPage(): string {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Receipt not found</title>
    <style>
      body { font-family: Arial, sans-serif; background: #f6f3ea; color: #1f1b16; margin: 0; padding: 32px; }
      .card { max-width: 720px; margin: 0 auto; background: white; border-radius: 24px; padding: 28px; box-shadow: 0 12px 40px rgba(0,0,0,0.08); }
      h1 { margin-top: 0; font-size: 28px; }
      p { line-height: 1.5; color: #5b5347; }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>Receipt not found</h1>
      <p>This Fileverse receipt link is missing or expired. Return to Bitsend and save the receipt again to generate a fresh public link.</p>
    </div>
  </body>
</html>`;
}

function renderFileverseReceiptPage(
  receipt: StoredFileverseReceiptRecord,
): string {
  const title = `${escapeHtml(receipt.amountLabel)} receipt`;
  const storageLabel = receipt.storageMode === 'fileverse'
    ? 'Saved to Fileverse'
    : 'Archived by Bitsend';
  const explorerLink = receipt.explorerUrl
    ? `<a class="action" href="${escapeHtml(receipt.explorerUrl)}" target="_blank" rel="noreferrer">Open explorer</a>`
    : '';
  const upstreamLink = receipt.upstreamUrl
    ? `<a class="action secondary" href="${escapeHtml(receipt.upstreamUrl)}" target="_blank" rel="noreferrer">Open Fileverse source</a>`
    : '';
  const storageNote = receipt.message
    ? `<p class="note">${escapeHtml(receipt.message)}</p>`
    : '';
  const txLine = receipt.transactionSignature
    ? `<div class="row"><span>Transaction</span><code>${escapeHtml(receipt.transactionSignature)}</code></div>`
    : '';
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${title}</title>
    <style>
      :root { color-scheme: light; }
      body { margin: 0; font-family: Arial, sans-serif; background: linear-gradient(180deg, #f4ead8 0%, #f8f5ee 100%); color: #1f1b16; }
      .wrap { max-width: 920px; margin: 0 auto; padding: 32px 20px 48px; }
      .card { background: rgba(255,255,255,0.94); border-radius: 28px; padding: 24px; box-shadow: 0 18px 50px rgba(0,0,0,0.10); }
      .eyebrow { text-transform: uppercase; letter-spacing: 0.16em; font-size: 12px; color: #8e7d64; margin-bottom: 10px; }
      h1 { margin: 0 0 8px; font-size: 32px; }
      p { margin: 0; color: #5b5347; line-height: 1.5; }
      .note { margin-top: 12px; }
      .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 14px; margin-top: 24px; }
      .tile { background: #faf7f1; border-radius: 18px; padding: 14px 16px; }
      .tile span { display: block; font-size: 12px; color: #8e7d64; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 6px; }
      .tile strong, .tile code { font-size: 14px; color: #1f1b16; word-break: break-word; }
      .image { margin-top: 24px; background: #f7f2e8; border-radius: 24px; padding: 18px; text-align: center; }
      img { max-width: 100%; height: auto; border-radius: 18px; box-shadow: 0 10px 26px rgba(0,0,0,0.08); }
      .actions { display: flex; gap: 12px; flex-wrap: wrap; margin-top: 20px; }
      .action { display: inline-block; padding: 11px 15px; border-radius: 999px; background: #1f1b16; color: white; text-decoration: none; }
      .action.secondary { background: #e9e0cf; color: #1f1b16; }
      .row { margin-top: 16px; padding-top: 16px; border-top: 1px solid #ece3d6; }
      @media (max-width: 640px) { .wrap { padding: 20px 14px 32px; } h1 { font-size: 28px; } }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="card">
        <div class="eyebrow">Bitsend receipt archive</div>
        <h1>${title}</h1>
        <p>Saved ${escapeHtml(receipt.savedAt)} for ${escapeHtml(receipt.chain)} ${escapeHtml(receipt.network)}. This public link is hosted by the Bitsend Worker so it stays stable even if the upstream Fileverse response URL changes.</p>
        ${storageNote}
        <div class="grid">
          <div class="tile"><span>Storage</span><strong>${escapeHtml(storageLabel)}</strong></div>
          <div class="tile"><span>Transfer ID</span><code>${escapeHtml(receipt.transferId)}</code></div>
          <div class="tile"><span>Status</span><strong>${escapeHtml(receipt.status)}</strong></div>
          <div class="tile"><span>Sender</span><code>${escapeHtml(receipt.senderAddress)}</code></div>
          <div class="tile"><span>Receiver</span><code>${escapeHtml(receipt.receiverAddress)}</code></div>
          <div class="tile"><span>Direction</span><strong>${escapeHtml(receipt.direction)}</strong></div>
          <div class="tile"><span>Transport</span><strong>${escapeHtml(receipt.transport)}</strong></div>
        </div>
        ${txLine}
        <div class="actions">
          ${explorerLink}
          ${upstreamLink}
        </div>
        <div class="image">
          <img alt="Receipt image" src="data:image/png;base64,${receipt.receiptPngBase64}" />
        </div>
      </div>
    </div>
  </body>
</html>`;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}
