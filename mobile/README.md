# AquaFlow Mobile

The Flutter customer app provides authentication, saved delivery addresses,
cart review, server-priced checkout drafts, and customer order history,
cancellation, and reorder actions. API requests use the configured backend URL
and store access/refresh tokens with platform secure storage.

Card orders are explicitly shown as payment pending; the app does not claim to
process card payments. Inventory reservation and production PostgreSQL
verification remain deferred.

## Development and validation

From this directory:

```powershell
flutter pub get
flutter run
flutter analyze
flutter test
```
