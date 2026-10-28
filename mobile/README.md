# AquaFlow Mobile

The Flutter customer app provides authentication, saved delivery addresses,
cart review, server-priced checkout drafts, customer order history/actions,
delivery status, in-app notifications, payment-intent groundwork, and verified
purchase reviews. API requests use the configured backend URL and store
access/refresh tokens with platform secure storage.
Successful checkout opens an order confirmation screen with direct links to
order history and home; Android system back returns to order history rather
than reopening the completed checkout.

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
promotions, delivery status operations, and review moderation. The mobile
orders screen supports API status filtering and pagination, with search limited
to the currently loaded page, matching Admin Web behavior. Order details use
the authorized `GET /admin/orders/:id` endpoint to display customer and address
snapshots, items, totals, payment records, and available delivery tracking
information. Delivery status updates follow the backend's allowed transitions
and require confirmation. Cities and delivery zones are shown from the existing
authenticated read-only endpoints.

The order list displays the customer's name separately from the customer ID
and shows order status separately from delivery status. Order status follows
the payment/customer lifecycle; delivery updates do not change the order
status. The backend does not provide manual Admin order-status changes,
order-status history, delivery-person assignment, or live map tracking. The
mobile app does not simulate these capabilities.

Inventory quantity is the amount available to sell: order placement decrements
it, and order cancellation releases it. Admin Mobile can review the existing
reservation, cancellation, and adjustment movement ledger. The model does not
record dispatched quantities or physical stocktakes, and reservations are not
transitioned when a delivery completes. A physical count/variance workflow
requires explicit rules for when reservations become fulfilled, how failed or
returned deliveries affect stock, and whether counts reconcile total physical
stock or available-to-sell stock. There is no Admin customer-list API or
city/delivery-zone management API, so those records are not presented as
editable features.

The dashboard's **Paid order total** sums `orders.total` for orders marked
`paid` after successful payment confirmation. It is after discounts and
includes delivery and service fees; cash, pending, and cancelled orders are
excluded. Refunds are not modeled, so this is not a complete accounting
revenue figure.

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
backend running on the Windows host. For a USB-connected physical Android
device, forward the backend port over ADB and use loopback:

```powershell
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=AQUAFLOW_API_BASE_URL=http://127.0.0.1:3000/api/v1
```

Re-establish the reverse mapping if the device disconnects from ADB. For a
device without USB debugging, configure the host machine's reachable LAN
address instead. The Android debug manifest permits cleartext HTTP for local
development only. The client refreshes expired access tokens using the stored
refresh token; the backend defaults are a 15-minute access-token lifetime and
a 7-day refresh-token lifetime. For production, configure the compile-time
define with the deployed HTTPS API URL:

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
