# Bitsend Offline Voucher Protocol v1

## Goal

Replace offline transport of signed blockchain transactions with escrow-backed,
cryptographically verifiable voucher claims as described in
`bitsend.pdf`.

Bitsend v1 targets:

- EVM-first (`ethereum`, `base`)
- local wallet mode only
- transport-agnostic offline transfer (`BLE`, `QR`, `ultrasonic`, relay)
- deferred on-chain settlement
- bounded loss, not instant-final offline finality

## Security model

The protocol does **not** assume:

- trusted client software
- trusted transport
- continuous connectivity
- secure hardware

The protocol **does** rely on:

- sender signature validity
- sound Merkle inclusion proofs
- finalized escrow state proofs
- first-valid-claim-wins settlement
- expiry windows and bounded voucher value

## Core objects

### Escrow commitment

An escrow locks funds on-chain and commits a bounded voucher set.

```json
{
  "version": 1,
  "escrowId": "uuid-or-chain-unique-id",
  "chain": "ethereum",
  "network": "testnet",
  "senderAddress": "0x...",
  "assetId": "ethereum:testnet:usdc",
  "assetContract": "0x...",
  "amountBaseUnits": "1000000",
  "collateralBaseUnits": "100000",
  "voucherRoot": "0x...",
  "voucherCount": 16,
  "maxVoucherAmountBaseUnits": "100000",
  "createdAt": "ISO-8601",
  "expiresAt": "ISO-8601",
  "stateRoot": "0x...",
  "settlementContract": "0x..."
}
```

Rules:

- `sum(voucher.amountBaseUnits) <= amountBaseUnits`
- `voucherCount > 0`
- `maxVoucherAmountBaseUnits <= amountBaseUnits`
- `expiresAt > createdAt`

### Voucher leaf

```json
{
  "version": 1,
  "escrowId": "uuid-or-chain-unique-id",
  "voucherId": "uuid-or-bytes32",
  "amountBaseUnits": "50000",
  "expiryAt": "ISO-8601",
  "nonce": "base64",
  "receiverAddress": "0x..."
}
```

`receiverAddress` may be empty in bearer-style mode, but Bitsend should prefer
binding vouchers to a receiver when pairing is available.

### Escrow proof bundle

The receiver verifies payment locally using a proof bundle.

```json
{
  "version": 1,
  "escrowId": "uuid-or-chain-unique-id",
  "voucherId": "uuid-or-bytes32",
  "voucherRoot": "0x...",
  "voucherProof": ["0x...", "0x..."],
  "escrowStateRoot": "0x...",
  "escrowProof": ["0x...", "0x..."],
  "finalizedAt": "ISO-8601",
  "proofWindowExpiresAt": "ISO-8601"
}
```

### Offline payment object

This is the transport payload `P`.

```json
{
  "version": 1,
  "txId": "sha256(canonical-P)",
  "voucher": {
    "version": 1,
    "escrowId": "uuid-or-chain-unique-id",
    "voucherId": "uuid-or-bytes32",
    "amountBaseUnits": "50000",
    "expiryAt": "ISO-8601",
    "nonce": "base64",
    "receiverAddress": "0x..."
  },
  "proofBundle": {
    "version": 1,
    "escrowId": "uuid-or-chain-unique-id",
    "voucherId": "uuid-or-bytes32",
    "voucherRoot": "0x...",
    "voucherProof": ["0x...", "0x..."],
    "escrowStateRoot": "0x...",
    "escrowProof": ["0x...", "0x..."],
    "finalizedAt": "ISO-8601",
    "proofWindowExpiresAt": "ISO-8601"
  },
  "senderAddress": "0x...",
  "senderSignature": "0x...",
  "transportHint": "ble",
  "createdAt": "ISO-8601"
}
```

Rules:

- `txId` is deterministic over the canonical object without `txId`
- `voucher.voucherId == proofBundle.voucherId`
- `voucher.escrowId == proofBundle.escrowId`
- `voucher.expiryAt <= proofBundle.proofWindowExpiresAt`

## Local verification

The receiver accepts a payment only if:

1. sender signature is valid for the voucher hash
2. voucher inclusion proof matches `voucherRoot`
3. escrow proof matches a finalized `escrowStateRoot`
4. voucher is not expired
5. voucher is not already in local `seen_set`
6. optional receiver binding matches the active receive address

Acceptance is provisional until settlement.

## Relay message

The relay layer stores and forwards only authenticated payment objects.

```json
{
  "version": 1,
  "txId": "sha256(canonical-P)",
  "payment": "Offline payment object",
  "hopCount": 0,
  "priority": 0,
  "createdAt": "ISO-8601",
  "expiresAt": "ISO-8601"
}
```

Relay rules:

- drop invalid signatures
- dedupe by `txId`
- reject expired messages
- bound `hopCount`
- prioritize higher value / earlier expiry

## Claim record

Settlement is deterministic: first valid claim wins.

```json
{
  "version": 1,
  "voucherId": "uuid-or-bytes32",
  "txId": "sha256(canonical-P)",
  "escrowId": "uuid-or-chain-unique-id",
  "claimerAddress": "0x...",
  "status": "accepted",
  "createdAt": "ISO-8601",
  "resolvedAt": "ISO-8601"
}
```

Statuses:

- `accepted`
- `duplicate_rejected`
- `expired_rejected`
- `invalid_rejected`
- `submitted_onchain`
- `confirmed_onchain`

## Backend responsibilities

The worker is **not** the trust anchor. It only helps with:

- indexing escrow commitments
- serving proof bundles
- storing relay messages
- deterministic claim dedupe
- broadcasting accepted claims when connectivity exists

The worker must enforce:

- strict size limits
- expiry checks
- idempotent escrow/proof/message creation
- first-claim-wins by `voucherId`
- `txId` recomputation on ingest

## Required backend routes

- `POST /v1/offline/escrows`
- `GET /v1/offline/escrows/{escrowId}`
- `POST /v1/offline/proof-bundles`
- `GET /v1/offline/proof-bundles/{voucherId}`
- `POST /v1/offline/relay/messages`
- `GET /v1/offline/relay/messages/{txId}`
- `POST /v1/offline/claims`
- `GET /v1/offline/claims/{voucherId}`

## Abuse controls

- max escrow lifetime
- max proof bundle size
- max relay payload size
- max proof node count
- duplicate message rejection
- duplicate claim rejection
- voucher expiry enforcement
- optional receiver binding
- short proof freshness windows
- bounded voucher amounts

## Migration rule

Bitsend should migrate offline mode from:

- signed transaction handoff

to:

- escrow-backed voucher handoff

Current offline transport features can remain as transport media, but they
should carry `Offline payment object` payloads instead of raw signed chain
transactions.
