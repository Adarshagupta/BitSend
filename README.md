# BitSend

BitSend is a multichain Flutter payment app built for fast wallet setup, clean transfer flows, and flexible settlement across local and managed wallet paths.

## Highlights

- Offline-first local wallet flow with hotspot and BLE handoff
- Managed wallet backend flow for online submission
- Multichain support for Solana, Ethereum, and Base
- ENS-aware EVM send flow with `.eth` name resolution and optional payment preference records
- Local and offline wallet derivation for secure device-to-device transfer preparation
- Fileverse-powered receipt publishing through the backend
- Cloudflare Worker backend for wallet sessions, transfer orchestration, and receipt services
- Clean mobile-first Flutter UI with onboarding, funding, send, receive, settings, and activity flows

## Chain Support

- Solana Devnet and Mainnet
- Ethereum Sepolia and Mainnet
- Base Sepolia and Mainnet

## Tech Stack

- Flutter
- Dart
- Cloudflare Workers
- Durable Objects
- SQLite-backed Worker state
- Solana SDK
- web3dart
- BLE and hotspot transport layers
- Fileverse receipt integration

## Repository Layout

- `lib/`: Flutter application
- `backend-worker/`: Cloudflare Worker backend
- `backend/`: additional backend workspace for integration work
- `test/`: Flutter test suite

## Flutter App

### Install dependencies

```powershell
flutter pub get
```

### Run the app

```powershell
flutter run
```

### Validate the app

```powershell
flutter test
```

## Backend Worker

### Install dependencies

```powershell
cd backend-worker
npm install
```

### Run locally

```powershell
npm run dev
```

### Deploy

```powershell
npm run deploy
```

## Worker Environment

Configure the wallet and receipt backend through Worker environment variables.

### Managed wallet variables

- `BITGO_ENV`
- `BITGO_ACCESS_TOKEN`
- `BITGO_API_BASE_URL`
- `BITGO_EXPRESS_BASE_URL`
- `BITGO_WALLET_PASSPHRASE`
- `BITGO_ETH_TESTNET_WALLET_ID`
- `BITGO_ETH_TESTNET_ADDRESS`
- `BITGO_ETH_MAINNET_WALLET_ID`
- `BITGO_ETH_MAINNET_ADDRESS`
- `BITGO_BASE_TESTNET_WALLET_ID`
- `BITGO_BASE_TESTNET_ADDRESS`
- `BITGO_BASE_MAINNET_WALLET_ID`
- `BITGO_BASE_MAINNET_ADDRESS`
- `BITGO_SOL_TESTNET_WALLET_ID`
- `BITGO_SOL_TESTNET_ADDRESS`
- `BITGO_SOL_MAINNET_WALLET_ID`
- `BITGO_SOL_MAINNET_ADDRESS`

### Fileverse variables

- `FILEVERSE_API_KEY`
- `FILEVERSE_RECEIPT_UPSTREAM`
- `FILEVERSE_DDOCS_ENDPOINT`

## App Flow

1. Create or restore a wallet.
2. Choose a chain and network.
3. Fund the main wallet or connect the managed wallet backend.
4. Move funds into the offline signer when using the local flow.
5. Send through hotspot, BLE, or managed online submission.
6. Track activity and publish receipts through the backend.

## ENS Usage

On EVM send flows, BitSend accepts either a normal `0x...` wallet address or an ENS `.eth` name in the receiver field.

1. Open the send flow on Ethereum or Base.
2. Enter the receiver as a raw address like `0x...` or an ENS name like `alice.eth`.
3. If you enter a `.eth` name, BitSend resolves it to the destination address before signing.
4. If that ENS name has BitSend payment preference text records, the app reads and shows the preferred chain and token as routing hints.
5. Use that ENS preference to send on the recipient's preferred chain or in the recipient's preferred token setup.

BitSend does not automatically convert assets or force a chain switch from the ENS record. The `.eth` preference is shown to help the sender choose the right route before submission.

You can also manage ENS payment preferences from Settings. Add the ENS name, then save the preferred chain and preferred token that other BitSend users should see when they send to that `.eth` name. Reading and writing ENS records requires internet access, and saving ENS preferences submits an Ethereum mainnet transaction from the ENS manager wallet, so that wallet must have enough ETH for gas.

## Product Focus

BitSend brings together:

- local-first crypto transfer UX
- managed online settlement
- multichain wallet support
- mobile-native transport options
- backend-backed receipt persistence

## Development Notes

- Flutter app state lives in `lib/src/state/`
- Wallet and chain models live in `lib/src/models/`
- Chain services live in `lib/src/services/`
- Main UI flows live in `lib/src/screens/`
- Worker routes and transfer logic live in `backend-worker/src/index.ts`
