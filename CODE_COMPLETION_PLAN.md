# Code completion plan

Updated: 2026-10-24

This plan separates application-code completion from deployment and provider
onboarding. Sprint completion counts for Sprints 0–18 remain recorded in
[`ROADMAP.md`](./ROADMAP.md); the tasks below track work now authorized by the
product requirements.

## P0 — Sprint 19: Complete English/Arabic application localization

**Status:** In progress  
**Dependencies:** None; use Flutter localization support and the existing React
application. Do not introduce external translation services.

**Scope and affected components**

- Admin: localizable authentication and operations dashboard, language
  selection and persistence, Arabic RTL direction, dates/status labels, and
  responsive tables/forms. Files: `admin/src/App.tsx`, `admin/src/i18n.ts`,
  `admin/src/styles.css`.
- Mobile: complete English/Arabic message catalogs for customer-facing screens,
  persisted language selection, correct RTL direction, localized validation and
  action copy. Files: `mobile/l10n.yaml`, `mobile/lib/l10n/*.arb`,
  `mobile/lib/main.dart`, `mobile/lib/cart_screen.dart`, tests.
- Documentation: language support and validation status in `README.md`,
  platform READMEs, API/UI docs as needed, and `CHANGELOG.md`.

**Acceptance criteria**

1. Every first-party user-visible label, button, validation message, empty/error
   state, status label, and operation description in the mobile app and admin
   dashboard has English and Arabic text.
2. Users can switch languages in both applications; the choice persists after
   restart/reload.
3. Arabic mode sets the correct document/widget text direction, including
   navigation, forms, tables, dialogs, and action ordering; English remains
   left-to-right.
4. Automated tests cover locale switching/persistence and representative
   Arabic/RTL content on mobile and admin.
5. Existing English fields, identifiers, server-authoritative pricing, and
   existing records remain compatible; optional bilingual fields are additive.

**Progress:** Literal mobile localization call sites are checked against the
Arabic catalog, and mobile/admin tests reject duplicate keys and verify
English/Arabic parity. Locale persistence and RTL/LTR behavior have automated
coverage. Migration 017 adds backward-compatible optional Arabic catalog
fields; catalog list/detail/search, cart/order snapshots, and the guarded admin
catalog API support bilingual content. Admin product/category/brand creation
and editing are available and audited. Product media is visibly disabled
because no storage adapter is configured. Backend (12 suites/29 tests), admin
(build, lint, 4 localization tests), and Flutter (analysis, 13 tests) currently
pass. The admin login's Arabic copy, RTL direction, and reload persistence were
verified in a browser; the authenticated dashboard and mobile device/
accessibility review remain outstanding.

## P1 — Backend security controls

**Status:** Partially implemented. Database-backed fixed-window limits now
protect login, registration, refresh, logout, and profile updates. OTP channel
decision remains required before verification can be enabled.  
**Dependencies:** A selected verification channel/provider or an explicit
operator decision to use authenticator-app TOTP. Provider credentials remain
out of scope until onboarding.

**Scope and affected components**

- Extend rate-limit coverage to additional high-risk mutations as requirements
  demand; keep the shared database-backed implementation and fail closed on
  limiter storage errors.
- Define OTP enrollment, delivery, expiry, attempt limits, replay prevention,
  recovery, and account lockout after selecting its channel.
- Review session revocation/logout semantics and error/log redaction.
- Add migrations, controller/service tests, API/security docs, and regenerate
  `infrastructure/database/full_database_setup.sql` for schema changes.

**Acceptance criteria**

- Rate limits are atomic across application instances and return a documented
  429 response without logging credentials/tokens.
- Tests prove thresholds, window expiry/reset, address-key separation, and
  concurrent counter updates.
- OTP cannot be enabled without a delivery/authenticator choice; secrets and
  codes are never returned in production API responses or logs.
- Existing auth/customer/admin isolation tests continue to pass.

## P2 — Admin catalog completeness

**Status:** Application CRUD implemented; media upload unavailable pending
storage configuration. Product listing/edit/create, category/brand
create/edit, bilingual content, server validation, referential checks, unique
slug conflicts, stock-derived availability, and audit entries are covered by
backend API tests. The admin presents a disabled media control with an explicit
unconfigured notice; no image URL or fake upload is accepted.

**Dependencies:** Confirm supported product fields and media storage strategy
before exposing uploads. Do not claim object storage works until a real adapter
is configured and tested.

**Acceptance criteria**

- Admin product creation/update validates fields and records audit events.
- Product categories/brands remain referentially valid; stock availability is
  maintained separately from the product active flag.
- Media remains unavailable until a storage provider is selected; do not
  represent a disabled UI control as a working upload integration.
- Tests cover role isolation, validation, audit, and stock availability.

## P2 — Customer catalog experience

**Status:** Implemented in the mobile app.  
**Dependencies:** Existing public catalog/search endpoints and authenticated
cart endpoint.

- Added bilingual product browsing, category filtering, search, paging, stock
  availability display, and add-to-cart controls in Flutter.
- Inactive products are excluded from public list/detail API results.
- Tests cover bilingual model mapping, English fallback for legacy records,
  and inactive product visibility.
- Product imagery remains a placeholder until a real media storage adapter
  is selected and verified.

**Acceptance criteria**

- Customer catalog searches and filters through server APIs rather than
  fabricated client-side products.
- Arabic content is preferred when present, with English fallback for legacy
  records; unavailable products cannot be added to the cart.

## P3 — Product completeness and quality gates

- Review cart/order cancellation/payment/delivery transitions for documented
  business gaps; add tests without changing completed behavior unnecessarily.
- Complete Arabic translation review, RTL accessibility, and narrow-screen
  checks.
- Extend tests to cover customer-visible API contracts and operator workflows.
- Keep source code and documentation honest about test adapters and manual
  operations.

## Deferred — deployment and external services

Do not block application development on these tasks, but require them before
production release:

- Docker engine/image/runtime and PostgreSQL 16 deployment, migration,
  readiness, restart persistence, backup/restore, monitoring, and recovery.
- Real payment processor, dispatch/tracking, email/SMS/push, and S3-compatible
  media provider onboarding and staging verification.
- Android SDK command-line tools/licenses, sufficient build disk space, debug
  and release APK/AAB validation, operator-managed signing, and store submission.
- iOS platform builds/signing if iOS is in scope.

PGlite tests and static configuration checks are not substitutes for these
environment and provider validations.
