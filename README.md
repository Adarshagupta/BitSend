# BitSend

**BitSend** is a Flutter Android application for **hybrid crypto payments** supporting both **offline-first transfers** and **online wallet transactions**.

The app currently supports **two wallet engines**:

* **Local Mode** – Offline-first transfers using BLE or hotspot, with later on-chain settlement.
* **BitGo Mode** – Online transactions submitted through a backend-managed BitGo demo wallet.

Supported chains:

* **Solana** – Devnet / Mainnet (Local Mode)
* **Ethereum** – Sepolia / Mainnet (Local Mode)
* **BitGo demo backend** for both chains using a deployed **Cloudflare Worker**

---

# Repository Structure

```
bitsend/
│
├── lib/                # Flutter mobile application
├── backend-worker/     # Cloudflare Worker backend (default BitGo demo backend)
├── backend/            # Local Node.js backend for future live BitGo integration
```

---

# Flutter App

## Install Dependencies

```bash
flutter pub get
```

## Run the Application

```bash
flutter run
```

## Validate Code

Run static analysis:

```bash
dart analyze
```

Run tests:

```bash
flutter test
```

---

# BitGo Backend

The mobile app is configured by default to use the **deployed Cloudflare Worker backend**:

```
https://bitsend-bitgo-backend.blueadarsh1.workers.dev
```

### Health Check

```
https://bitsend-bitgo-backend.blueadarsh1.workers.dev/health
```

Expected response:

```json
{
  "ok": true,
  "mode": "mock"
}
```

The Worker runs in **mock mode** to allow the mobile app to operate over HTTPS without requiring a local server.

---

# Cloudflare Worker Backend

The Worker acts as the **default backend for BitGo demo mode**.

## Install Dependencies

```bash
cd backend-worker
npm install
```

## Run Locally

```bash
npm run dev
```

## Deploy Worker

Login to Cloudflare:

```bash
npx wrangler whoami
```

Deploy the Worker:

```bash
npm run deploy
```

The Worker uses **Durable Objects** to manage demo sessions and transfer state.

---

# BitGo Mode Setup (Inside the App)

1. Open the **BitSend Flutter app**
2. Navigate to **Settings**
3. Verify the **BitGo backend URL** points to:

```
https://bitsend-bitgo-backend.blueadarsh1.workers.dev
```

4. Tap **Connect BitGo Demo**
5. Change the wallet mode from **Local → BitGo**

---

# Local Node Backend (Optional)

The repository also contains a **Node.js backend** used for experimentation with live BitGo SDK support.

Use this backend only if you want to run a **local BitGo integration**.

## Run Local Backend

```bash
cd backend
npm install
npm run build
npm start
```

Default endpoint:

```
http://127.0.0.1:8788
```

⚠️ When running the app on a **physical Android device**, prefer using the **deployed Worker URL** instead of the local backend.

---

# Verification

The following checks were verified in this repository:

* Flutter **Dart analysis**
* Flutter **unit tests**
* Worker **dependency installation**
* Worker **type checking**
* Worker **dry-run deployment**
* Worker **Cloudflare deployment**
* Live Worker `/health` endpoint response

---

# Current Limitations

* The deployed Cloudflare Worker currently runs in **mock BitGo mode**.
* **Live BitGo SDK execution** is still limited to the local Node backend due to Node module incompatibilities with the Workers runtime.
* **Local Mode and BitGo Mode operate independently** by design:

  * BitGo Mode does **not support offline transfers**
  * Offline transfers are handled exclusively in **Local Mode**

---

# License

This project is provided for development and demonstration purposes.
