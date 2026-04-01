# BitSend Microsite

Standalone static marketing site for BitSend.

## Files

- `index.html`: landing page served at `/`
- `app/index.html`: reserved `/app/` handoff target
- `styles.css`: shared visual system and layout
- `script.js`: scroll state, active sections, and app-link wiring
- `config.js`: deploy-time config surface

## App Target

Update `APP_TARGET_URL` in `config.js` when the real web app target is ready.

Default:

```js
APP_TARGET_URL: "/app/";
```

Until then, `/app/` serves a branded placeholder so the CTA never points to a dead route.

## APK Download Target

The Android alpha button can be switched from the local site asset to the
Cloudflare Worker download route through `APK_DOWNLOAD_URL` in `config.js`.

Example:

```js
APK_DOWNLOAD_URL: "https://bitsend-bitgo-backend.blueadarsh1.workers.dev/downloads/bitsend-alpha.apk";
```
