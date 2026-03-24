# BitSend Privacy Policy

Effective date: March 20, 2026

## 1. Overview
BitSend is a non-custodial mobile wallet application that supports local wallet operations, optional managed-backend flows, and local transfer channels (hotspot, Bluetooth, and ultrasonic handoff). This Privacy Policy explains what information is processed when you use BitSend and how that information is handled.

By using BitSend, you agree to this Privacy Policy.

## 2. Who This Policy Applies To
This policy applies to users of the BitSend mobile app and related backend endpoints used by the app.

## 3. Information We Process

### 3.1 Information Stored On Your Device
BitSend stores app data locally on your device, including:
- Wallet metadata and addresses
- Local transfer queue and activity history
- App settings (such as selected endpoints and preferences)
- Security state needed to enforce device unlock and biometric checks

Sensitive secrets are intended to remain on-device and are protected using platform security primitives where available.

### 3.2 Permissions and Device Access
BitSend may request the following permissions to provide app functionality:
- Camera: scan QR codes for addresses and transfer payloads
- Nearby devices / Bluetooth: local discovery and Bluetooth transfer handoff
- Microphone: ultrasonic transfer and receive workflows
- Network and Wi-Fi state: determine connectivity and local endpoint behavior
- Biometric capability: device authentication for wallet unlock flows

BitSend requests permissions contextually when you use features that need them.

### 3.3 Network Requests
When you use online or managed features, BitSend sends necessary request data to configured endpoints, such as:
- Blockchain RPC endpoints (for balance, transaction, and chain operations)
- Optional managed backend endpoints (if enabled in Settings)
- Optional relay or receipt endpoints (if configured)

Transferred data can include wallet addresses, chain/network parameters, signed payloads, and request metadata needed to complete operations.

### 3.4 What BitSend Does Not Intend To Collect by Default
BitSend is not designed as an advertising SDK app and does not intentionally collect advertising identifiers for behavioral ads in the core flow.

## 4. How We Use Information
We process information to:
- Operate wallet, transfer, receive, and settlement features
- Authenticate and secure access to app functions
- Maintain local state (history, queue, and settings)
- Troubleshoot failures and improve reliability
- Meet legal, fraud-prevention, or security obligations where required

## 5. Data Sharing
BitSend may share data only as necessary with:
- Blockchain infrastructure providers used by your configured RPC endpoints
- Backend/relay/receipt providers you explicitly configure or enable
- Legal authorities, if required by law

BitSend does not sell personal data.

## 6. Data Retention
- On-device data remains until you remove it or uninstall the app.
- In-app reset/clear actions can delete local data.
- Data sent to external endpoints is governed by those endpoint operators' retention policies.

## 7. Security
BitSend applies technical and organizational safeguards, including platform security storage where available and permission-gated workflows. No system is 100 percent secure; users remain responsible for securing their devices and backup materials.

## 8. Your Choices and Rights
Depending on your jurisdiction, you may have rights to access, correct, delete, or object to processing of personal information. Because BitSend is largely local-first and non-custodial, many controls are user-managed directly in app settings and device permissions.

For rights requests, use the contact methods below.

## 9. Children
BitSend is not directed to children under 13 (or the minimum legal age in your jurisdiction). Do not use BitSend if you are not legally permitted to do so.

## 10. International Use
BitSend may be used globally. Network interactions may involve infrastructure located outside your country.

## 11. Policy Updates
We may update this policy over time. The latest version will be published in this repository. Material changes should be communicated in release notes or equivalent channels.

## 12. Contact
For privacy requests and questions:
- GitHub Issues: https://github.com/Adarshagupta/BitSend/issues
- Subject line recommendation: "Privacy Request - BitSend"

To help us process your request, include:
- Your request type (access, correction, deletion, objection)
- Wallet address(es) or app context relevant to the request
- Country/state of residence (for rights handling)
