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
5. Backend APIs, identifiers, request payloads, and server-authoritative
   business behavior remain unchanged.

**Progress:** Admin selection/persistence, first-party dashboard translation,
common server-error/status translation, document language, and RTL table/forms
are implemented. The mobile app now has an app-wide persisted locale
controller, a language switch on its main screens, Arabic translations for
customer-facing static copy/known notifications/statuses, and RTL supplied by
Flutter's Arabic localization delegates. Flutter and admin localization tests
cover locale state, translated examples, and direction. Remaining work is a
complete translation-key audit, missing language content in catalog data,
screen-level UI/accessibility review, and Android/iOS device verification; the
sprint is not yet complete.

## P1 — Backend security controls

**Status:** Not started; OTP channel decision required before enforcing
verification on registration or sensitive account changes.  
**Dependencies:** A selected verification channel/provider or an explicit
operator decision to use authenticator-app TOTP. Provider credentials remain
out of scope until onboarding.

**Scope and affected components**

- Add bounded, persistent rate limits for login, registration, refresh, and
  sensitive mutation routes; prefer database-backed state so production does
  not silently fall back to per-process memory.
- Define OTP enrollment, delivery, expiry, attempt limits, replay prevention,
  recovery, and account lockout after selecting its channel.
- Review session revocation/logout semantics and error/log redaction.
- Add migrations, controller/service tests, API/security docs, and regenerate
  `infrastructure/database/full_database_setup.sql` for schema changes.

**Acceptance criteria**

- Rate limits are atomic across application instances and return a documented
  429 response without logging credentials/tokens.
- Tests prove limits, expiry/reset, customer isolation, and concurrent safety.
- OTP cannot be enabled without a delivery/authenticator choice; secrets and
  codes are never returned in production API responses or logs.
- Existing auth/customer/admin isolation tests continue to pass.

## P2 — Admin catalog completeness

**Status:** Partially implemented. Listing, price update, and active-state
control exist; product creation, category/brand authoring, and media upload
interfaces are not evidenced.

**Dependencies:** Confirm supported product fields and media storage strategy
before exposing uploads. Do not claim object storage works until a real adapter
is configured and tested.

**Acceptance criteria**

- Admin product creation/update validates fields and records audit events.
- Product categories/brands remain referentially valid; availability derives
  from active state and stock.
- Media interface validates allowed content type/size and fails explicitly
  when storage is unconfigured; it never stores arbitrary remote URLs as
  trusted media.
- Tests cover role isolation, validation, audit, and stock availability.

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
