# AquaFlow Mobile

The Flutter customer app provides authentication, saved delivery addresses,
cart review, server-priced checkout drafts, customer order history/actions,
delivery status, in-app notifications, payment-intent groundwork, and verified
purchase reviews. API requests use the configured backend URL and store
access/refresh tokens with platform secure storage.

The same Flutter application also includes a separate Admin experience at
**Administrator sign in** on the customer sign-in page, or directly at
`/admin/login`. It uses independent secure-storage keys and verifies the
signed-in role through `/auth/profile` before showing protected screens. The
backend continues to enforce Admin authorization on every Admin API request.
Customer registration and Customer session keys are not shared with Admin.
The Admin login and workspace include the app's persisted English/Arabic
language switch, RTL layout, and Arabic product/catalog name display when the
backend provides those fields.

Admin screens are connected to the existing APIs for dashboard metrics and
orders, product management, category/brand management, inventory adjustments,
promotions, delivery status operations, and review moderation. Cities and
delivery zones are shown from the existing authenticated read-only endpoints.
There is no Admin customer-list API or city/delivery-zone management API, so
those records are not presented as editable features.

Card orders remain payment pending when no real processor is configured; the
app does not claim to process card payments. Live delivery tracking, production
payment, and PostgreSQL 16 deployment verification remain deferred.

## Development and validation

From this directory:

```powershell
flutter pub get
flutter run
flutter analyze
flutter test
```

Android emulators use `http://10.0.2.2:3000/api/v1` by default to reach a
backend running on the Windows host. For a physical Android device, provide the
host machine's LAN address and ensure the backend listens on the LAN interface
and the device can reach it:

```powershell
flutter run --dart-define=AQUAFLOW_API_BASE_URL=http://192.168.1.20:3000/api/v1
```

Replace the example LAN address with the development host's actual reachable
address. Do not use the example unchanged. The Android debug manifest permits
cleartext HTTP for local development only. For production, configure the
compile-time define with the deployed HTTPS API URL:

```powershell
flutter build apk --release --dart-define=AQUAFLOW_API_BASE_URL=https://api.example.com/api/v1
```

Release builds reject non-HTTPS API URLs and still require the release
application ID and externally managed signing variables described below.

## Android build and release gate

Debug APKs use the emulator API default:

```powershell
flutter build apk --debug
```

Release builds require an HTTPS `AQUAFLOW_API_BASE_URL` compile-time define,
a unique `AQUAFLOW_APPLICATION_ID`, and externally managed signing values:
`AQUAFLOW_KEYSTORE_FILE`, `AQUAFLOW_KEYSTORE_PASSWORD`,
`AQUAFLOW_KEY_ALIAS`, and `AQUAFLOW_KEY_PASSWORD`. The Gradle release task
fails if those release settings are missing; debug signing is never used for a
release. Do not commit keystores or passwords. No store submission or signing
verification has been performed.
