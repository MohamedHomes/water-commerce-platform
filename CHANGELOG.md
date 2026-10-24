# Changelog

## Unreleased

### Sprint 0 - Foundation

- repository structure established for mobile, backend, admin, infrastructure, and docs
- system architecture foundation documented
- health endpoint scaffolding created for NestJS backend
- React admin portal bootstrap added
- Flutter mobile shell added
- Docker Compose foundation established for PostgreSQL and Redis
- environment template created without secrets
- design system documentation initialized

### Sprint 6 - Customer orders

- added persisted order creation from validated checkout sessions
- added customer-scoped order history and detail endpoints
- added cancellation and current-price reorder operations
- captured immutable address, delivery-zone, cart, and price snapshots
- card payment capture and inventory reservation remain deferred to their
  respective integration domains
- verified backend build and all 8 backend suites (18 tests), plus Flutter
  analysis and all 3 mobile tests

### Sprint 7 - Payment lifecycle foundation

- added provider-neutral payment intent and webhook interfaces
- persisted payment attempts with customer-scoped idempotency keys
- added raw-body HMAC webhook verification, event deduplication, and amount and
  currency checks
- added verified payment success/failure transitions and blocked order
  cancellation while a payment intent is pending
- added a deterministic automated-test-only provider; no real payment provider
  or capture is configured
- verified backend build and 9 backend suites (21 tests); Flutter analysis
  passed and all 4 mobile tests passed

### Sprint 8 - Inventory reservation baseline

- added atomic product stock reservation when orders are placed
- added exact-once reservation release on eligible order cancellation
- added non-negative stock constraint and auditable reserve/release movements
- serialized competing order placement on locked product stock rows to prevent
  overselling
- scope uses one product-level stock pool; warehouses, replenishment, and
  fulfillment stock transitions remain deferred
- verified backend build and all 9 backend suites (22 tests), plus Flutter
  analysis and all 4 mobile tests

### Sprint 9 - Delivery tracking foundation

- created delivery records only for cash orders or paid card orders
- added customer-owned delivery status and append-only event timeline
- added cancellation events for deliveries cancelled before dispatch
- added mobile delivery details and clearly identifies that live tracking is
  unavailable
- no driver dispatch, assignment, or location provider is connected
- verified backend build and all 10 backend suites (23 tests), Flutter analysis,
  and all 5 mobile tests

### Sprint 10 - Customer notification inbox

- added a persistent customer-scoped in-app notification inbox with
  deduplication and read state
- emits order placement/cancellation and verified payment success/failure events
- added mobile notification list and mark-read controls
- email, SMS, and push integrations remain unconfigured
- verified backend build and all 10 backend suites (23 tests), including PGlite
  migration/persistence coverage; Flutter analysis and all 5 mobile tests pass

### Sprint 11 - Promotion redemption foundation

- added PostgreSQL promotion definitions and customer/order redemption records
- applied optional promotion codes using server-calculated percentage or fixed
  discounts, minimum subtotal, active dates, maximum discount, and redemption
  limits
- revalidated promotion availability under a row lock and committed redemption
  atomically with order creation
- persisted discount and code snapshots on checkout and order records; displayed
  server-returned discounts in mobile checkout
- promotion authoring/admin UI is not yet available; configured promotion rows
  are required
- verified backend build and all 10 backend suites (24 tests), including PGlite
  migrations; Flutter analysis passed and all 6 mobile tests passed

### Sprint 12 - Admin operations foundation

- replaced static dashboard metrics with database-backed order, revenue,
  dispatch, and catalog summaries plus a paginated read-only order queue
- added role-protected promotion listing, creation, and enable/disable actions
- added database-backed role checks, an operator-only admin elevation process,
  and audit records for promotion changes
- replaced demo portal content with authenticated sign-in, live operations data,
  and promotion management
- no order status override, dispatch assignment, or payment capture controls
  are exposed
- verified backend build and all 11 backend suites (25 tests), including PGlite
  migration 014; admin production build passed. ESLint could not run because the
  existing admin package has no ESLint flat/legacy configuration.

### Sprint 13 - Admin inventory controls

- added an admin inventory view and explicit one-unit stock increase/decrease
  actions
- inventory adjustments lock product stock, prevent negative quantities, and
  atomically persist movement and administrator audit records
- inventory continues to use a single product-level pool; warehouse, supplier,
  and replenishment workflows are not implemented
- verified backend build and all 11 backend suites (25 tests), including PGlite
  migration 015; admin production build passed

### Sprint 14 - Manual delivery operations

- added admin delivery queue and manual status actions
- enforced sequential transitions from pending dispatch through assignment,
  pickup, and delivery; failure can be recorded after assignment
- persisted customer-visible delivery events and administrator audit entries
  atomically; delivered timestamps are recorded
- no dispatch provider, driver assignment, or live location integration is
  connected
- verified backend build and all 11 backend suites (26 tests), including admin
  transition and delivery-event coverage; admin production build passed

### Sprint 15 - Verified-purchase product reviews

- added review submission for products in a customer's delivered order
- keeps submissions pending and invisible to public catalog queries until admin
  approval; rejects duplicate reviews for the same order/product
- added approved-review summaries and ratings in the customer orders flow
- added admin moderation queue and audited approve/reject actions
- verified backend build and all 11 backend suites (26 tests), including PGlite
  migration 016; admin build, Flutter analysis, and all 6 mobile tests passed

### Sprint 16 - Admin catalog controls

- replaced the remaining static catalog placeholder with a database-backed
  product operations view
- added admin-only price and active-state updates with validation and audit
  records; inventory remains managed through audited stock adjustments
- verified backend build and all 11 backend suites (26 tests); admin production
  build passed

### Sprint 17 - Deployment hardening foundation

- required distinct production access/refresh JWT secrets and restricted
  production browser origins to `CORS_ORIGINS`
- added non-root multi-stage backend and static Nginx admin images, Docker build
  context exclusions, and Compose environment wiring
- documented the deferred PostgreSQL 16 and Docker verification procedure
- Docker builds/runtime and PostgreSQL 16 checks remain unverified because the
  deployment environment is unavailable
- current workspace verification: backend build passed and all 11 backend
  suites (26 tests) passed; admin production build passed

### Sprint 18 - Android release safety gate

- removed debug-key signing from Android release builds and require a unique
  application ID plus external keystore variables
- require an explicitly configured HTTPS API URL for release mode while
  retaining localhost/emulator defaults for development
- updated the Android application label and release setup documentation
- store credentials and store submission remain unconfigured
- current workspace verification at that checkpoint: Flutter analysis passed
  and all 6 Flutter tests passed; an Android debug build failed because Flutter
  selected Java 11 while the configured Gradle requires Java 17 or later
- Android release build and signing gate remained unverified pending a
  compatible JDK and operator-managed signing configuration

## Stabilization update - 2026-10-24

- revalidated verified-purchase review ownership, rating validation, pending
  moderation, approved publication, rejected-review invisibility, and duplicate
  prevention through PGlite-backed end-to-end tests
- added a generated fresh-database SQL snapshot from all 16 ordered migrations,
  with matching schema migration ledger entries; a PGlite test executes the
  snapshot and confirms the backend migration runner safely skips its recorded
  migrations
- configured the existing admin ESLint command with a TypeScript-aware flat
  config and declared parser/plugin dependencies
- verified backend build (exit 0), all 11 backend suites and 27 tests (exit 0),
  admin production build (exit 0), admin lint (exit 0), Flutter analysis (exit
  0), and all 6 Flutter tests (exit 0)
- the earlier Android debug build attempt failed because Flutter selected Java
  11.0.10 while the wrapper is Gradle 9.3.1 and requires Java 17 or later;
  the audit below reconfigured Flutter to use the installed JDK 17
- PGlite validation does not verify the deployed PostgreSQL 16 configuration;
  PostgreSQL 16 and Docker runtime checks remain unverified
- the repository documents no sprint after Sprint 18 and provides no next-sprint
  acceptance criteria; no unnumbered feature work or invented sprint was started
- added [ROADMAP.md](./ROADMAP.md) with an evidence-based audit of the 19
  requested Sprint 0–18 slots; Sprints 1–5 are explicitly marked inferred
  because their original criteria are absent, and Sprint 19 is only a proposal
  pending approval
- current checkout is clean at audit start on `main` (`e9aa918`); full backend
  build and 11 suites/27 tests, admin build/lint, and Flutter analysis/6 tests
  all passed again
- verified `C:\\Program Files\\Java\\jdk-17` contains Java and javac 17.0.11,
  configured Flutter to select it, and confirmed Gradle proceeds past its Java
  requirement; the Android debug build then failed with `There is not enough
  space on the disk` while installing NDK 28.2.13676358
- removed only the incomplete NDK staging directory and installer marker
  created by that failed build; C: now has about 4.99 GB free. Android
  command-line tools are still missing and license status remains unknown.
- regenerated the consolidated SQL twice with identical hashes; PGlite
  execution, ledger comparison, and runner skip behavior pass in the backend
  suite. PostgreSQL 16 and Docker runtime remain unverified.
- `docker compose config` passed (exit 0) with an obsolete `version` attribute
  warning; `docker info` confirmed that the Docker Desktop Linux engine is not
  running/reachable, so image/runtime tests could not run.

### Sprint 19 - Bilingual application experience (in progress)

- added an admin language selector with localStorage persistence, translated
  first-party operations/authentication copy and common API validation errors,
  localized known order/payment/delivery/inventory statuses, locale-aware order
  dates, and document `lang`/`dir` updates with RTL-aware table/form styles
- added a Flutter locale controller persisted through secure storage and an
  English/Arabic selector on the customer app's main screens; Arabic applies
  Flutter's RTL localization delegates
- translated mobile authentication/address/checkout/cart/order/review/payment/
  delivery/notification labels, validation, known status values, and the
  platform's current in-app notification/event text; verified all 103 literal
  `localized(...)` call keys have Arabic entries
- added mobile tests for saved-language restoration, language updates, Arabic
  translation, and RTL/LTR direction; added admin localization/persistence/
  direction/error-format unit tests
- no backend API, database schema, or business behavior changed; product and
  customer-provided names/content are not yet bilingual data, and unknown
  server-provided messages remain in their source language
- current validation: backend build passed; all 11 backend suites and 27 tests
  passed; admin build and lint passed; 3 admin localization tests passed;
  Flutter analysis passed and all 9 mobile tests passed
- Sprint 19 remains incomplete pending bilingual catalog data/content review,
  exhaustive dynamic/API error coverage, and Arabic/RTL device/accessibility
  review. Android SDK/build and deployed PostgreSQL 16/Docker checks remain
  deferred/unverified.
