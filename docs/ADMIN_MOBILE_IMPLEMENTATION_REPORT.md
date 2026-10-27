# AquaFlow Admin Mobile Implementation Report

## Summary

Added a dedicated Admin experience to the existing Flutter application. The
existing Customer screens, `/login` flow, customer token keys, and Customer
routes remain separate. Admin screens use the existing NestJS API and the
existing authorization guard; no backend, migrations, database resets, or
Admin privileges were added.

## Authentication, sessions, and routing

- Customer login now links to a separate Administrator sign-in at
  `/admin/login`; a direct route is also available.
- Admin login uses `POST /api/v1/auth/login` and proceeds only when the
  response role is `admin`. Public registration is not part of this flow.
- Admin access and refresh tokens are stored in Flutter secure storage under
  `admin_access_token` and `admin_refresh_token`. Customer token keys
  (`auth_token`, `refresh_token`) are not read, written, or deleted by the
  Admin API client.
- Entering `/admin` checks the protected `GET /api/v1/auth/profile` response
  for the current database-backed role before showing the dashboard. The
  backend's `JwtAuthGuard` and `AdminRoleGuard` remain authoritative for every
  protected Admin endpoint.
- Admin logout deletes only the Admin token keys. The existing API does not
  revoke stateless tokens; the Admin UI signs out locally and a new login is
  required after its access token expires.
- A valid Admin session is not automatically refreshed. An expired/rejected
  access token clears the local Admin session when profile validation returns
  `401`/`403`.

## Implemented screens and real API mappings

All paths below are relative to `/api/v1`. Admin API operations are protected
by JWT and database role authorization. Location lookup endpoints require JWT
authentication in the existing `AddressController`; city/zone configuration is
read-only.

| Admin mobile screen | Implemented behavior | Existing API |
| --- | --- | --- |
| Login | Email/password sign in, role rejection, loading and error feedback | `POST /auth/login`; `GET /auth/profile` verifies current role |
| Dashboard | Displays live metrics and five most recent orders; retry/pull-to-refresh and empty orders state | `GET /admin/dashboard`; `GET /admin/orders?limit=5` |
| Products | Loads products; create with existing category/brand IDs and optional Arabic name; edit name, Arabic name, slug, and price; activate/deactivate | `GET /admin/products`; `POST /admin/products`; `PATCH /admin/products/:id`; `GET /admin/catalog-terms` for category/brand selection |
| Categories and brands | List and create/update catalog terms, including English/Arabic names and slug | `GET /admin/catalog-terms`; `POST /admin/categories`; `PATCH /admin/categories/:id`; `POST /admin/brands`; `PATCH /admin/brands/:id` |
| Inventory | Live stock list; submit signed whole-number adjustment; server remains responsible for stock bounds | `GET /admin/inventory`; `POST /admin/inventory/:productId/adjustments` |
| Orders | List/filter by supported status and page through results; displays payment method and total | `GET /admin/orders?page=:page&limit=20&status=:status` |
| Deliveries | List; offers only the next supported state transitions (`assigned`, `picked_up`, `delivered`, `failed`) | `GET /admin/deliveries`; `PATCH /admin/deliveries/:id/status` |
| Promotions | List, create percentage/fixed discount, activate/deactivate | `GET /admin/promotions`; `POST /admin/promotions`; `PATCH /admin/promotions/:id/active` |
| Review moderation | List pending reviews and approve/reject | `GET /admin/reviews`; `PATCH /admin/reviews/:id/status` |
| Cities and delivery zones | Displays active cities, zones, fees, and estimates as read-only data | `GET /addresses/cities`; `GET /addresses/delivery-zones` |

The mobile UI does **not** claim to implement unsupported operations:

- There is no Admin customer-list/customer-detail endpoint, so no customer
  management screen is shown.
- The existing API exposes cities and delivery zones only as lookup data. No
  Admin configuration endpoint exists to create/edit/deactivate them.
- Admin order state/payment mutation and delete operations for products,
  categories, brands, or promotions are not exposed by the current backend and
  are not offered in the app.
- The application does not bypass authorization by relying on hidden routes:
  the backend still checks the user role for each `/admin/*` operation.

## Arabic localization and RTL

- Admin sign-in and the Admin workspace expose the existing persisted language
  switch. The switch now names the alternate language in the current language.
- Admin navigation, dashboard labels, operation tabs, form fields, validation,
  empty/error states, and common actions use Arabic translations when Arabic is
  selected. Flutter's Arabic locale supplies RTL layout; paging arrows and
  directional action alignment follow the active direction.
- Product, category, brand, city, and review product names prefer their
  Arabic API fields when present and fall back to the existing English value.
  Customer-facing localization remains in the same locale provider/catalog.
- Free-form data such as review comments remains in its source language.

## API base URL and Android configuration

`AQUAFLOW_API_BASE_URL` is a compile-time Dart define and must point to the
backend API prefix ending in `/api/v1`.

- Android Emulator with backend on the Windows host defaults to
  `http://10.0.2.2:3000/api/v1`; Android's `localhost` is not treated as the
  Windows host.
- Windows desktop and Flutter Web development default to
  `http://localhost:3000/api/v1`.
- Physical Android device development must pass the developer machine's LAN
  address, for example:

  ```powershell
  flutter run --dart-define=AQUAFLOW_API_BASE_URL=http://192.168.1.20:3000/api/v1
  ```

  Replace the sample LAN address with the actual reachable host address. The
  backend must listen on a network interface accessible to the device, and
  host firewall/network policy must permit the connection. Android debug
  builds permit cleartext traffic for local development.
- Release builds require a configured HTTPS URL:

  ```powershell
  flutter build apk --release --dart-define=AQUAFLOW_API_BASE_URL=https://api.example.com/api/v1
  ```

  The release build also continues to require the existing external
  application-ID and signing configuration. No signing secrets are stored in
  source or this report.

The Android main manifest includes the Internet permission for release and
debug builds. Cleartext HTTP is enabled only in the Android debug manifest.

## Tests and diagnostics

### Added automated tests

- `mobile/test/admin_api_test.dart`: Admin-only secure-storage keys, customer
  role rejection, role revalidation after role change, bearer token usage,
  unauthenticated request prevention, and Admin logout preserving Customer
  session keys.
- `mobile/test/admin_mobile_test.dart`: login rejection/success, password
  obscuring, protected-route gate, dashboard live-data/error-retry states,
  product loaded/empty state, product create/edit API requests, Arabic product
  names and RTL login layout, navigation to inventory, catalog loading, and
  read-only city/zone data.
- `mobile/test/localization_test.dart`: localization-catalog coverage, locale
  persistence, English LTR, Arabic RTL, and the localized language-switch
  target.

During implementation the first Flutter test run found a real retry-handler
bug: assigning a `Future` inside an expression-bodied `setState` callback
caused Flutter to reject the callback at runtime. The callbacks were changed to
block-bodied synchronous `setState` functions, and the retry widget test now
passes.

### Executed commands and results

Commands were executed from `mobile/` using the installed Flutter SDK
(`C:\Users\DELL\flutter\bin\flutter.bat`) and Dart formatter
(`C:\Users\DELL\flutter\bin\dart.bat`):

| Command | Result |
| --- | --- |
| `dart format lib\admin\admin_mobile.dart lib\localization.dart test\admin_mobile_test.dart test\localization_test.dart` | PASS; exit code 0 |
| `flutter analyze` | PASS; no issues found |
| `flutter test test\admin_api_test.dart test\admin_mobile_test.dart` | PASS; 19 Admin API/widget tests |
| `flutter test` | PASS; full Flutter suite (33 tests) |
| `flutter build apk --debug` | PASS; exit code 0; APK at `E:\AquaFlowMobileBuild\app\outputs\flutter-apk\app-debug.apk` (184,469,903 bytes) |
| `git diff --check` | PASS; exit code 0; Git emitted only the working-copy LF-to-CRLF warning for `mobile/lib/main.dart` |

The first full-suite run exposed only test expectation/setup mistakes (relative
Dio request paths, rendered order-ID truncation, a test double's generic error
message, and asserting obscured input by visible text). These were corrected;
the final focused Admin suite and complete Flutter suite passed. No password or
token value is emitted by the tests.

### Final build and runtime result

The final `flutter build apk --debug` completed with exit code 0, and the APK
was verified at:

`E:\AquaFlowMobileBuild\app\outputs\flutter-apk\app-debug.apk`

The file size is 184,469,903 bytes. Flutter's `mobile\build` output directory
is backed by the existing build-output junction on E:. The APK installed on the
booted Android 11 emulator and `MainActivity` launched; Flutter reported the
API 30 emulator as unsupported, and Android's launcher/System UI became
unresponsive during accessibility inspection, so screen-level device
interaction could not be completed. A subsequent ADB check reported the
emulator offline/still authorizing. The emulator had no AquaFlow package
installed before this test.

The local backend returned HTTP 200 from `/api/v1/health/live` and
`/api/v1/health/ready` (`database: connected`; cache is not configured).
Unauthenticated `GET /api/v1/admin/dashboard` returned HTTP 401. No local
administrator credentials were entered, so authenticated mobile sign-in and
role-specific live API calls were not exercised. The Admin Web dev server was
not listening on port 5173 during this check. Emulator-to-host HTTP probing was
blocked because the emulator image has no `curl`, `wget`, `nc`, or `ping`
utility. No release APK was built.

## Remaining limitations

- The Android package name and release signing remain governed by the
  pre-existing release gate and are not changed here.
- The emulator launcher/System UI ANR prevented reliable screen-level device
  interaction after app launch. Widget/API tests pass, but authenticated
  device-level E2E still needs a responsive emulator and local Admin sign-in.
- Some free-form API data, such as review comments, remains in its source
  language when the backend does not provide a translated field.
- Refresh-token rotation is not implemented in the Admin client, and backend
  logout does not revoke tokens. Expired sessions require signing in again.
- Customer administration and delivery configuration remain unsupported until
  corresponding backend APIs are deliberately added.

## Codebase audit continuation

The subsequent Customer/Admin audit and final code validation are documented
in [AQUAFLOW_CODEBASE_MOBILE_ADMIN_AUDIT.md](./AQUAFLOW_CODEBASE_MOBILE_ADMIN_AUDIT.md).
The latest source differs from the earlier validation above; do not treat the
older test count and E-drive APK path as the latest build.

Latest verified results:

| Command | Result |
| --- | --- |
| `dart format` on changed Flutter files | PASS; exit 0 |
| `flutter analyze` | PASS; no issues |
| `flutter test` | PASS; 38 tests |
| `flutter build apk --debug` | PASS; exit 0; `mobile/build/app/outputs/flutter-apk/app-debug.apk`, 184,505,923 bytes |
| Admin Web localization tests | PASS; 4 tests |
| Admin Web lint | PASS |
| Admin Web production build | PASS |
| Backend auth/cart/Admin integration tests | PASS; 3 suites, 4 tests |
| Backend build | PASS |

The test and build outputs validate source and artifact creation only. The
physical OPPO A73 installation attempt timed out after 90 seconds; no current
phone launch, API session, or screenshot is claimed. See
[MOBILE_DEVICE_TEST_REPORT.md](./MOBILE_DEVICE_TEST_REPORT.md).

The audit also corrected Customer sign-in validation so registration-only
password complexity does not reject a valid existing account before the
backend can authenticate it. Checkout now ignores a late delivery-zone
response from a previously selected address.
