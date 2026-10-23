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
