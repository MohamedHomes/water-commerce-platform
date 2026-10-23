# AquaFlow Mobile

The Flutter customer app provides authentication, saved delivery addresses,
cart review, server-priced checkout drafts, customer order history/actions,
delivery status, in-app notifications, payment-intent groundwork, and verified
purchase reviews. API requests use the configured backend URL and store
access/refresh tokens with platform secure storage.

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
