# AquaFlow Mobile, Backend, and Admin Audit

## Scope and evidence

This audit reviewed the repository README and architecture/API documentation,
the mobile and Admin implementation reports, the QA E2E report, the Customer
Flutter app and tests, Admin Web source and tests, and NestJS authentication,
authorization, cart, order, catalog, and Admin services/controllers. Relevant
source references include [mobile/lib/main.dart](../mobile/lib/main.dart),
[mobile/lib/cart_screen.dart](../mobile/lib/cart_screen.dart),
[mobile/lib/catalog_screen.dart](../mobile/lib/catalog_screen.dart),
[mobile/lib/admin/admin_mobile.dart](../mobile/lib/admin/admin_mobile.dart),
[admin/src/App.tsx](../admin/src/App.tsx),
[backend/src/admin/admin.controller.ts](../backend/src/admin/admin.controller.ts),
[backend/src/admin/admin-role.guard.ts](../backend/src/admin/admin-role.guard.ts),
[backend/src/admin/admin.service.ts](../backend/src/admin/admin.service.ts),
[backend/src/cart/cart.controller.ts](../backend/src/cart/cart.controller.ts),
and [backend/src/cart/cart.service.ts](../backend/src/cart/cart.service.ts).

No Nebras reference screenshots were found in the repository. This report
therefore makes no claim that the UI matches Nebras. No live business records,
credentials, or token values were included in the review. No database reset or
migration was run.

## A. Customer Mobile

### Screens and modules reviewed

The Customer routes and source cover Arabic-first home, category/product
browsing and search, product detail, cart, saved delivery addresses and
checkout, customer login/registration, order history and its available
actions, payment-intent groundwork, delivery tracking, in-app notifications,
and purchase reviews. API requests use the existing `/api/v1` service; cart
totals and checkout quotes are server-derived. Product images render from
`imageUrl` when present and otherwise use an explicit fallback.

The home screen's category and product cards, discount listings, and catalog
search are tied to the public catalog API. Promotions administered through the
Admin API are not separately fetched as a Customer campaign feed. The app has
no dedicated profile/settings screen despite the backend's owner-authenticated
profile API, no dedicated order-detail route, and no favorites flow. Product
variant selection is not exposed; the current cart is keyed by product ID and
does not provide a variant-specific cart contract.

### Findings and changes made

- Replaced the text-heavy AppBar language switch with a compact accessible
  icon. The narrow Arabic test had exposed the actual horizontal overflow in
  this constrained AppBar.
- Reworked cart rows into flexible, scrollable cards with quantity controls,
  remove actions, server-provided line totals/discounts, a safe-area-aware
  checkout action, and a real `PATCH /cart/items/:productId` update. The
  cart retains previously loaded items if a later Dio load fails and reports
  the error rather than rendering success-shaped empty data.
- Added responsive catalog/product cards and a real API-backed detail page.
  Added narrow-width Arabic tests for the card and cart layouts.
- Fixed a confirmed auth mismatch: the backend applies its complexity rule to
  registration, not login. Customer login now accepts any non-empty password
  for server verification; the existing letter/number/symbol/minimum-length
  validation remains on registration. Added an Arabic registration validation
  test.
- Fixed a checkout race by ignoring delivery-zone responses belonging to an
  earlier address/city selection. Zone loading clears the prior selection,
  disables zone selection and checkout, and surfaces an API error.
- Kept customer auth tokens (`auth_token`, `refresh_token`) separate from the
  Admin token keys and Admin route tree. `api_config.dart` defaults Android
  Emulator to `10.0.2.2`, accepts the `AQUAFLOW_API_BASE_URL` compile-time
  override, and requires HTTPS for release builds. The main Android manifest
  has Internet permission; cleartext is allowed only by the debug manifest.

### Remaining Customer limitations

- A usable production payment processor is not configured. Card checkout is
  explicitly represented as payment-pending; cash-on-delivery remains the
  supported completed order path in the current integration.
- No production image-upload management is present; product image rendering
  depends on URLs returned by the existing API.
- Device-level behavior, including the final APK's login and visual rendering,
  remains unverified on a responsive physical phone. See
  [MOBILE_DEVICE_TEST_REPORT.md](./MOBILE_DEVICE_TEST_REPORT.md).

## B. Admin panel

### Pages and supported operations

Admin Web has authentication, dashboard, products, categories/brands,
inventory, orders, deliveries, promotions, review moderation, and city/zone
lookup pages. The Flutter Admin experience maps those implemented operations
to the existing endpoints as detailed in
[ADMIN_MOBILE_IMPLEMENTATION_REPORT.md](./ADMIN_MOBILE_IMPLEMENTATION_REPORT.md).

The Web and mobile clients call actual API operations. The NestJS Admin
controller uses JWT authentication and the database-backed Admin role guard;
the role guard remains authoritative on each protected Admin API request.
Mobile Admin login also verifies `/auth/profile` before protected navigation,
stores only Admin-specific secure-storage keys, and clears only those keys on
logout. Unit/widget and backend tests cover customer-role rejection, role
revalidation, unauthenticated Admin request blocking, and Customer-session
preservation.

Admin Web exposes actual product/category/brand changes, price and inventory
operations, promotion creation/activation, delivery status transitions, and
review moderation. The review found two small operational/usability gaps and
fixed them: decrement-at-zero is disabled in the inventory UI, and the
existing supported `failed` delivery transition is now offered for
`assigned`/`picked_up` deliveries with English/Arabic labels. The product
management grid now constrains its minimum width on narrow viewports.

### Not implemented or read-only

- There is no Admin customer-list/detail endpoint; customer management is not
  implemented.
- Cities and delivery zones are lookup-only in the current API; their Admin
  view is read-only and no configuration action is claimed.
- The Admin order page is a list/read surface. There is no Admin order
  status/payment mutation, order detail, or export operation exposed by the
  reviewed API/UI.
- No settings, role-management, or audit-log viewing screen/API was found.
  Audit rows are written for supported mutations but cannot be reviewed in
  the UI through a read endpoint.
- Order paging/status filtering exists in the API and mobile Admin screen;
  Admin Web has a limited recent-order view and does not provide equivalent
  complete queue controls. No Admin-wide search/sort/export feature was found.
- No Admin UI automation harness exists in this repository. Admin Web changes
  were validated by localization tests, lint, and production build, and the
  changed UI paths were source-reviewed rather than browser-interaction-tested.

No authorization bypass was found in the reviewed Admin client/server paths.
This is a scoped code audit, not a penetration test.

## C. Cross-layer flows

| Flow | Result | Evidence / remaining boundary |
| --- | --- | --- |
| Customer/Admin login and role enforcement | **Automated-test verified** | Flutter tests cover Admin login rejection, secure-storage separation, profile-role revalidation, route protection, and logout preservation. Backend auth/Admin integration tests passed. A physical-device login was not attempted. |
| Catalog retrieval and product detail | **Automated-test verified; device unverified** | Flutter model/card tests and source use the public catalog API; backend catalog coverage exists in the QA report. No fresh device screenshot/runtime check was made. |
| Cart updates and totals | **Automated-test verified** | Flutter cart tests cover narrow Arabic layout, quantity/totals and safe checkout visibility. Backend cart integration tests cover add/update/validation/totals and customer ownership. |
| Checkout and order creation | **Partially verified** | Checkout uses authenticated address/zone APIs and server-quoted totals; checkout/widget and backend order suites are documented in the QA report. This audit did not create an order against the shared local database. |
| Customer order visibility in Admin | **Partially verified** | Customer order and Admin list endpoints are separately implemented and tested; no single joined live transaction was performed in this audit. |
| Admin delivery update reflected in Customer tracking | **Partially verified** | Backend delivery transition and tracking contracts are covered by the existing QA report; this audit did not run a live customer/Admin paired session. |
| Inventory adjustment reflected in catalog/cart | **Partially verified** | Backend Admin stock bounds and catalog availability are covered by integration tests; no shared-database stock mutation was made. |
| Physical-device API access | **Not verified** | The OPPO A73 was listed online in the prior device session, but its APK installation timed out. No `adb reverse`, launch, screenshot, or phone-to-host API request completed. |

Previously observed local health and readiness endpoints returned HTTP 200,
with the database reported connected. The QA report contains the corresponding
safe API smoke results; this audit did not modify the database.

## D. Code changes in this audit continuation

- [mobile/lib/main.dart](../mobile/lib/main.dart): limit password complexity
  validation to registration; ignore stale checkout-zone responses.
- [mobile/lib/localization.dart](../mobile/lib/localization.dart): remove the
  duplicate Arabic checkout message and add the required-password translation.
- [mobile/test/customer_experience_test.dart](../mobile/test/customer_experience_test.dart):
  registration validation and narrow Arabic catalog-card tests.
- [admin/src/App.tsx](../admin/src/App.tsx): disable decrement at zero and
  expose the supported failed-delivery action.
- [admin/src/i18n.ts](../admin/src/i18n.ts) and
  [admin/test/i18n.test.mjs](../admin/test/i18n.test.mjs): translate and test
  failed-delivery labels.
- [admin/src/styles.css](../admin/src/styles.css): allow the catalog grid to
  fit a narrow container without a 320px minimum overflow.
- [docs/ADMIN_MOBILE_IMPLEMENTATION_REPORT.md](./ADMIN_MOBILE_IMPLEMENTATION_REPORT.md)
  and [docs/MOBILE_DEVICE_TEST_REPORT.md](./MOBILE_DEVICE_TEST_REPORT.md):
  retain implementation evidence and report actual device-test status.

All prior Admin Mobile, customer redesign, Android manifest, QA-suite, and
documentation changes were preserved. No commit or push was made.

## E. Validation results

Final code-level validation after the checkout race fix:

| Command | Result |
| --- | --- |
| `dart format lib\main.dart` (and the earlier changed Dart-file batch) | PASS, exit 0 |
| `flutter analyze` | PASS, exit 0; no issues |
| `flutter test` | PASS, exit 0; 38 tests |
| `flutter build apk --debug` | PASS, exit 0; verified APK at `mobile/build/app/outputs/flutter-apk/app-debug.apk` (184,505,923 bytes) |
| `npm.cmd run test:localization` in `admin/` | PASS; 4 tests |
| `npm.cmd run lint` in `admin/` | PASS |
| `npm.cmd run build` in `admin/` | PASS; TypeScript and Vite production build |
| `npm.cmd test -- --runTestsByPath test\auth.e2e-spec.ts test\cart.e2e-spec.ts test\admin.e2e-spec.ts --testTimeout=30000` in `backend/` | PASS; 3 suites, 4 tests |
| `npm.cmd run build` in `backend/` | PASS; NestJS build |
| `git diff --check` | PASS; exit 0 after final source and report changes (Git emitted a line-ending warning for `mobile/lib/main.dart`) |

PowerShell blocked the `npm` PowerShell shim under the machine's execution
policy; the same package scripts were run successfully using `npm.cmd`. The
first combined backend test invocation used Jest's default 5-second fixture
hook timeout while other builds were running; the isolated cart suite and the
final three-suite run passed with a 30-second test timeout. The installed
Flutter CLI rejected an attempted `--build-dir` option (exit 64); the
canonical `flutter build apk --debug` command then succeeded. An initial
analysis/test pass also caught a duplicate localization entry and a missing
Arabic validation string; both were fixed before the final clean analysis and
38-test run. No cache was deleted and no unrelated process was stopped.

## F. Prioritized remaining work

| Priority | Module | Required action | Dependency / note |
| --- | --- | --- | --- |
| P1 | Physical Android runtime | Install/launch the verified APK on a responsive OPPO A73 or emulator; validate catalog/cart and capture screenshots/logs. | Resolve the prior ADB install timeout/device responsiveness; backend needs a reachable LAN URL or USB reverse setup. |
| P1 | Payments | Configure and test a real provider, webhook signature and end-to-end payment lifecycle before enabling card payment as paid. | Provider account, secrets outside source, backend integration and operational approval. |
| P2 | Customer account | Add a profile/settings screen only after confirming required fields and product behavior. | Existing customer profile API; business/UI requirements need confirmation. |
| P2 | Admin operations | Add customer management, city/zone configuration, order mutation, audit-log viewing or exports only if required. | Each needs an explicitly designed, authorized backend API and persistence behavior; none should be fabricated in a client. |
| P2 | Catalog | Confirm whether variants and image upload/management are business requirements. | Current cart contract keys lines by product ID; image rendering can only use API-provided URLs. |
| P3 | Admin Web | Add complete order queue search/filter/pagination and direct browser interaction tests if operational needs require parity with API/mobile capabilities. | Admin UI test harness and product requirements. |
| P3 | Release | Build/sign and verify release package with production HTTPS API URL and managed signing configuration. | Release application ID, externally managed keystore and deployment endpoint. |
