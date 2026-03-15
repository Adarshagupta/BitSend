# bitsend

`bitsend` is a Flutter Android app for hybrid crypto payments with two wallet engines:

- `Local`: offline-first handoff over BLE or hotspot, then later on-chain settlement
- `BitGo`: online-only submit through a backend-managed BitGo demo wallet

The app currently supports:

- Solana: devnet/mainnet in Local mode
- Ethereum: Sepolia/mainnet in Local mode
- BitGo demo backend mode for both chains through a deployed Cloudflare Worker

## Repo layout

- `lib/`: Flutter app
- `backend-worker/`: deployed Cloudflare Worker backend used by the app
- `backend/`: local Node backend retained for future live BitGo work

## Flutter app

### Install app dependencies

```powershell
flutter pub get
```

### Run the app

```powershell
flutter run
```

### Validate the app

```powershell
dart analyze
flutter test
```

## BitGo backend

The app now defaults to the deployed Cloudflare Worker:

```text
https://bitsend-bitgo-backend.blueadarsh1.workers.dev
```

Health check:

```text
https://bitsend-bitgo-backend.blueadarsh1.workers.dev/health
```

Expected response:

```json
{"ok":true,"mode":"mock"}
```

### Cloudflare Worker backend

This is the backend the app is configured to use by default for BitGo demo mode.

### Install Worker dependencies

```powershell
cd backend-worker
npm install
```

### Run the Worker locally

```powershell
npm run dev
```

### Deploy the Worker

```powershell
npx wrangler whoami
npm run deploy
```

The deployed worker uses a Durable Object for demo sessions and transfer state.

### Fileverse upstream

Receipt publishing to Fileverse is handled by the Worker, not directly by the
Flutter app. This repo is configured to use the Fileverse server root:

```text
https://quiet-island-41070-e71391e7dca9.herokuapp.com/
```

The Worker derives the ddocs endpoint automatically as:

```text
https://quiet-island-41070-e71391e7dca9.herokuapp.com/api/ddocs
```

Before deploying, set the Fileverse API key as a Worker secret:

```powershell
cd backend-worker
npx wrangler secret put FILEVERSE_API_KEY
```

If you need to override the ddocs path explicitly, set
`FILEVERSE_DDOCS_ENDPOINT`. Otherwise `FILEVERSE_SERVER_URL` is enough.

Important:

- The Worker is the default app backend for BitGo demo mode.
- The Worker currently runs in `mock` mode on Cloudflare.
- This keeps the mobile app runnable over HTTPS without needing a local server.

## BitGo app setup

1. Open the Flutter app.
2. Go to `Settings`.
3. Confirm `BitGo backend` points to the Worker URL.
4. Tap `Connect BitGo demo`.
5. Switch the Home header wallet mode from `Local` to `BitGo`.

If you want to override the backend manually, you still can.

## Local Node backend

The original Node backend is still in `backend/`.

Use it only if you want to keep iterating on a future live BitGo path locally:

```powershell
cd backend
npm install
npm run build
npm start
```

Default local endpoint:

```text
http://127.0.0.1:8788
```

On a physical Android phone, use the deployed Worker URL unless you intentionally want to point the app at your own local machine.

## What was verified

Verified in this repo:

- Flutter Dart analysis on the touched app files
- Focused Flutter tests for the touched app files
- Worker `npm install`
- Worker `npm run typecheck`
- Worker `wrangler deploy --dry-run`
- Worker deployment to Cloudflare
- Live Worker `/health` response in mock mode

## Current limits

- The deployed Cloudflare Worker is currently a BitGo demo/mock backend, not a live BitGo signer
- Live BitGo SDK execution is still kept in the local Node backend because the BitGo SDK imports unsupported Node modules for the Workers runtime
- Local mode and BitGo mode are parallel flows by design: BitGo mode does not do offline envelope receive or hotspot settlement
