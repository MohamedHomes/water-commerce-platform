# AquaFlow project roadmap and sprint audit

Audit date: 2026-10-24

## Scope and counting method

The repository contains named changelog entries for Sprint 0 and Sprints 6–18,
but no prior `ROADMAP.md` and no sprint-specific acceptance documents for
Sprints 1–5. The user-requested audit range, Sprint 0 through Sprint 18, contains
19 numbered audit slots. Sprint 1–5 objectives below are explicitly inferred
from the implemented domains and test names; they are not represented as
recovered original requirements.

Status is based on the sprint scope actually documented in the repository,
current implementation, and current build/test evidence. “Complete” means the
documented foundation/objective for that sprint passed the available relevant
checks; it does not mean every future provider, deployment, or production
release dependency is complete. “Blocked” means implementation exists but a
required verification cannot proceed in the current environment. No sprint
after Sprint 18 is present in the repository plan.

## Sprint-by-sprint audit

| Sprint | Objective and provenance | Implemented evidence | Remaining work / gaps | Current evidence and blockers | Status |
|---|---|---|---|---|---|
| 0 | Foundation. Documented in `CHANGELOG.md`; structure, health endpoints, app shells, configuration, and Compose baseline. | [README](./README.md), [backend health tests](./backend/test/app.e2e-spec.ts), [Compose configuration](./docker-compose.yml), Flutter and admin application shells. | Compose services and PostgreSQL 16 have not been started and verified in this environment. | Backend build and health tests pass; admin build/lint and Flutter analysis/tests pass. `docker compose config` passes; Docker engine is unreachable. | **Partially Complete** |
| 1 | Authentication/customer identity. **Inferred**, not specified in an original sprint document. | [Auth service](./backend/src/auth/auth.service.ts), [auth tests](./backend/test/auth.e2e-spec.ts): registration, login, refresh, profile, logout; customer data is database-backed. | Original acceptance scope is unknown. OTP and rate limiting called out in [SECURITY](./SECURITY.md) are not evidenced as implemented. | Current backend build and full suite pass, including authentication and persistence tests. | **Partially Complete** |
| 2 | Catalog. **Inferred**, not specified in an original sprint document. | [Catalog module](./backend/src/catalog), [catalog/search tests](./backend/test/catalog-search.e2e-spec.ts), migration-backed categories, brands, products, and deterministic seed data. | Original acceptance scope is unknown; product media/object-storage integration is not evidenced. | Current backend build and catalog/search tests pass. | **Partially Complete** |
| 3 | Search. **Inferred**, not specified in an original sprint document. | [Search module](./backend/src/search), [catalog/search tests](./backend/test/catalog-search.e2e-spec.ts), [search migration](./backend/migrations/003_create_search_indexes.sql). | Original acceptance scope is unknown; no external search provider is configured or claimed. | Current backend build and catalog/search tests pass. | **Partially Complete** |
| 4 | Cart and server-side pricing. **Inferred**, not specified in an original sprint document. | [Cart module](./backend/src/cart), [cart tests](./backend/test/cart.e2e-spec.ts), checkout pricing and persistence tests in [Sprint 5 tests](./backend/test/sprint5.e2e-spec.ts). | Original acceptance scope is unknown; no separate formal acceptance record exists. | Current backend build and full PGlite-backed suite pass. | **Partially Complete** |
| 5 | Address management and checkout drafts. **Inferred** from the named [Sprint 5 tests](./backend/test/sprint5.e2e-spec.ts); no original sprint specification is present. | [Address module](./backend/src/address), [checkout module](./backend/src/checkout), customer-isolation, validation, and checkout tests; Flutter address/checkout tests in [mobile/test](./mobile/test). | Original acceptance scope is unknown; production PostgreSQL 16 is not verified. | Current backend build/full suite and Flutter analysis/tests pass; database behavior was tested with PGlite. | **Partially Complete** |
| 6 | Customer orders. Documented in `CHANGELOG.md`. | [Orders module](./backend/src/orders), [order tests](./backend/test/orders.e2e-spec.ts): checkout conversion/idempotency, ownership, immutable snapshots, cancel/reorder; mobile order history/actions. | No production payment capture in this sprint; handled by the payment domain and still unconfigured. | Current backend build and all 11 suites pass; the full order suite includes delivery/review cases added later. | **Complete** |
| 7 | Provider-neutral payment lifecycle foundation. Documented in `CHANGELOG.md`; production payment credentials/provider were explicitly out of scope. | [Payments module](./backend/src/payments), [payment tests](./backend/test/payments.e2e-spec.ts), migration 009: intent persistence, idempotency, raw-body webhook verification, deduplication, amount/currency checks, state transitions. | A real payment processor, capture/settlement, refunds, and production webhook secrets are not configured. The test adapter does not collect money. | Current backend build/full suite passes, including payment integration tests against PGlite. No live-provider test was performed. | **Complete** |
| 8 | Inventory reservation baseline. Documented in `CHANGELOG.md`. | [Orders and inventory implementation](./backend/src/orders/orders.service.ts), [order tests](./backend/test/orders.e2e-spec.ts), migration 010: atomic reserve/release, locking, non-negative stock, movement records. | Warehouse-level stock, replenishment, and fulfillment stock transitions remain outside the single product-level pool. | Current backend build/full suite passes, including reservation/cancellation behavior. | **Complete** |
| 9 | Delivery tracking foundation. Documented in `CHANGELOG.md`. | [Delivery module](./backend/src/delivery), [delivery/order tests](./backend/test/orders.e2e-spec.ts), migration 011, and customer mobile delivery status/event display. | No dispatch provider, driver assignment, location feed, or live ETA is connected. | Current backend suite covers delivery ownership/events/transitions; mobile analysis/tests pass. Provider integration is not configured. | **Complete** |
| 10 | Customer in-app notification inbox. Documented in `CHANGELOG.md`. | [Notifications module](./backend/src/notifications), [notification tests](./backend/test/notifications.e2e-spec.ts), migration 012, mobile inbox and read state. | Email, SMS, and push notification providers are not configured. | Current backend build/full suite and Flutter analysis/tests pass. | **Complete** |
| 11 | Promotion redemption foundation. Documented in `CHANGELOG.md`. | [Checkout promotion logic](./backend/src/checkout/checkout.service.ts), [order tests](./backend/test/orders.e2e-spec.ts), migration 013: server-side discount calculation, limits, snapshots, atomic redemption. | No customer-facing coupon catalog or multi-promotion rules are evidenced; promotion administration was delivered in Sprint 12. | Current backend full suite covers discounts and redemption limits; admin operations are also covered. | **Complete** |
| 12 | Admin operations foundation. Documented in `CHANGELOG.md`. | [Admin module](./backend/src/admin), [admin API/UI](./admin/src/App.tsx), migration 014, [admin tests](./backend/test/admin.e2e-spec.ts): database role checks, dashboard, order queue, promotion controls, audit. | Order queue remains read-only; no payment capture or dispatch-provider operation is exposed. | Backend build/full tests and admin production build/lint pass. Admin provisioning still requires controlled operator action. | **Complete** |
| 13 | Admin inventory controls. Documented in `CHANGELOG.md`. | [Admin inventory service](./backend/src/admin/admin.service.ts), admin UI, migration 015: locked adjustments, non-negative validation, movement and audit records. | Single product-level pool; no warehouses, supplier replenishment, or stock-count reconciliation. | Current backend admin tests and production build/lint pass. | **Complete** |
| 14 | Manual delivery operations. Documented in `CHANGELOG.md`. | [Admin delivery operations](./backend/src/admin/admin.service.ts), [delivery/order tests](./backend/test/orders.e2e-spec.ts): sequential transitions, event history, delivered timestamp, audit. | Manual status updates only; no driver/dispatch integration or location tracking. | Current backend full suite and admin build/lint pass. | **Complete** |
| 15 | Verified-purchase product reviews and moderation. Documented in `CHANGELOG.md`. | [Review service/controller](./backend/src/catalog/product-reviews.service.ts), [review API tests](./backend/test/orders.e2e-spec.ts), [admin moderation](./backend/src/admin/admin.service.ts), migration 016, mobile review submission. Tests cover owner/delivered-order eligibility, rating validation, pending visibility, approval, rejection, and duplicate prevention. | No review reporting/appeals workflow is documented; no moderation SLAs or customer moderation notices are evidenced. | Current backend build and all 11 suites/27 tests pass; Flutter analysis and all 6 tests pass. | **Complete** |
| 16 | Admin catalog controls. Documented in `CHANGELOG.md`. | [Admin catalog service](./backend/src/admin/admin.service.ts), admin UI, [admin tests](./backend/test/admin.e2e-spec.ts): listing and audited price/active-state updates. | No bulk import, product media management, or variant operations are evidenced. | Current backend full suite and admin production build/lint pass. | **Complete** |
| 17 | Deployment hardening foundation. Documented in `CHANGELOG.md`. | [Backend/admin Dockerfiles](./backend/Dockerfile), [Compose configuration](./docker-compose.yml), [production auth/CORS configuration](./backend/src/auth/auth.constants.ts), deployment docs. | Neither Docker images/runtime nor PostgreSQL 16 deployment/readiness/migration behavior has been verified. Production secret injection, backups, monitoring, and operational runbooks still need deployment-specific validation. | Backend build/tests and admin build/lint pass. `docker compose config` passes with an obsolete `version`-field warning, but the Docker engine is unreachable; PostgreSQL 16 is not verified. | **Blocked** |
| 18 | Android release safety gate. Documented in `CHANGELOG.md`. | [Android Gradle release gate](./mobile/android/app/build.gradle.kts), [HTTPS API configuration](./mobile/lib/api_config.dart), mobile release docs. Installed JDK 17.0.11 and `javac` 17.0.11 are valid; Flutter is configured to use this JDK. | Debug APK and release build remain unverified. Android SDK command-line tools are absent and license status is unknown. The failed build exhausted disk while downloading/extracting NDK 28.2.13676358. Release signing/store credentials and submission remain operator-controlled. | `flutter doctor -v` confirms missing command-line tools and unknown Android licenses. Gradle passed the former Java 11 incompatibility, then `flutter build apk --debug` failed with `There is not enough space on the disk` (exit 1). | **Blocked** |

## Status totals

| Status | Count |
|---|---:|
| Complete | 11 |
| Partially Complete | 6 |
| Not Started | 0 |
| Blocked | 2 |
| **Audit slots (Sprint 0–18 inclusive)** | **19** |

The 11 complete sprints are 6–16. Sprints 0–5 are partial because their
original sprint acceptance criteria are absent (and Sprint 0 still lacks
runtime infrastructure verification); the inferred features have tests but
cannot be signed off against unrecovered original criteria. Sprints 17–18 have
working implementation foundations but are blocked from full verification by
unavailable deployment infrastructure and Android environment/disk
requirements. “Not Started” is zero only within the requested 0–18 range; no
Sprint 19 is part of the repository plan.

## Implemented product capabilities

- PostgreSQL-backed customer identity, catalog, cart, address, checkout,
  orders, payments, reservations, delivery records, notifications, promotions,
  admin audit, inventory adjustments, and reviews.
- Server-calculated prices and discounts, immutable order snapshots,
  idempotent checkout/order/payment operations, customer ownership checks, and
  admin role checks.
- Provider-neutral payment intent/webhook handling, customer delivery history,
  in-app notification inbox, manual delivery controls, and moderated
  verified-purchase reviews.
- React admin operations for dashboard/order queue, promotions, inventory,
  delivery status, reviews, and catalog price/active-state changes.
- Flutter customer flows for authentication, catalog/cart/checkout, order
  history/actions, delivery status, notification inbox, promotions, and
  review submission. English and Arabic locales are declared, but full
  translated UI strings and RTL acceptance are not demonstrated.
- Ordered PostgreSQL migration runner and reproducible consolidated SQL
  snapshot. PGlite validates the snapshot, migration checksums/ledger, and
  persistence behavior.

## Remaining work before production readiness

1. **Deployment/database:** provide Docker and a PostgreSQL 16 environment;
   run `docker compose config`, build/start the backend/admin images, apply
   migrations using the runner, verify readiness and persistence across
   restarts, and document backup/restore and migration recovery. PGlite is not
   a substitute for this check.
2. **Android release:** free sufficient disk space (the attempted NDK install
   exhausted C:), install Android SDK command-line tools, accept SDK licenses,
   rerun `flutter doctor -v`, and build the debug APK. Then have the operator
   provide a unique application ID, HTTPS production API URL, and externally
   managed release signing values; verify the release gate without committing
   secrets. Store submission remains separate.
3. **Payments:** select and configure a real processor through secret
   management, implement/test its adapter and webhook lifecycle in staging,
   and define capture, settlement, refund, failure, and reconciliation
   procedures. No live payment operation is currently available.
4. **Delivery and notifications:** select and configure dispatch/tracking and
   email/SMS/push providers or formally accept manual delivery and inbox-only
   notifications as the intended product scope.
5. **Security/compliance:** implement or explicitly waive the documented OTP
   and rate-limiting requirements; validate production secret/CORS settings,
   threat model, privacy/retention, audit retention, and incident response.
6. **Localization and mobile release:** translate user-facing strings, verify
   Arabic/RTL layouts on devices, run Android/iOS platform builds and tests,
   and complete operator-owned store metadata, signing, and release workflows.
7. **Runtime integrations and operations:** determine whether Redis-backed
   caching/rate limiting and S3-compatible media storage are production
   requirements for this release; those services appear in architecture and
   environment configuration but active backend integrations are not
   evidenced. Define production hosting, monitoring/alerting, backups, restore
   objectives, rollout/rollback, and on-call procedures. Production deployment
   is still a scaffold, not an operational service.

## Sprint 19 — Bilingual application experience (in progress)

This scope is defined by the current product requirement; it is additional to
the audited Sprint 0–18 range and is not included in its historical counts.
Production deployment, Android release work, and external provider onboarding
remain deferred.

**Objective:** Provide complete English and Arabic customer-facing mobile and
admin experiences, including persisted language choice and correct RTL/LTR
layout, while preserving existing API and business behavior.

**Acceptance criteria:**

- All first-party visible application copy, validation, empty/error states,
  actions, and known status labels have English and Arabic translations.
- Both apps provide a language selector and persist the selected language
  across app reload/restart.
- Arabic mode applies RTL to navigation, forms, tables, dialogs, and layout;
  English remains LTR.
- Automated tests verify locale switching/persistence and representative
  translated RTL screens; builds and lint/analyzer checks pass.
- No API contract or backend business rule changes are made as a side effect.

**Current evidence/gaps:** Both platforms now offer English/Arabic selection,
persisted language choice, translated first-party labels and actions, and RTL
behavior. Mobile tests cover persisted locale state and Arabic/LTR direction;
admin tests cover message interpolation, persistence helpers, and document
direction. Admin build/lint and Flutter analyzer/tests pass. The sprint remains
in progress: no exhaustive string-coverage audit or device-level Arabic review
has been completed, and catalog/customer-generated content does not yet have
separate bilingual data fields. Android build/runtime verification remains
environment-blocked as documented above.

See [`CODE_COMPLETION_PLAN.md`](./CODE_COMPLETION_PLAN.md) for the remaining
application and deferred release work.
