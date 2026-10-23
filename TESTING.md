# Testing Strategy

## Backend persistence validation

The backend Jest suite uses PGlite to run the actual ordered SQL migrations and
exercise API persistence, ownership checks, and data surviving an application
restart. PGlite is a PostgreSQL-compatible test engine; it does not verify the
deployed PostgreSQL 16 image or Docker configuration.

From `backend`, run:

```powershell
npm.cmd run build
npm.cmd test
```

From `mobile`, run:

```powershell
flutter analyze
flutter test
```

To verify the deployment database separately, start PostgreSQL 16 with
`docker compose up -d postgres`, set `DATABASE_URL` to that instance, then start
the backend and confirm its readiness endpoint reports `database: connected`.

## Implemented foundation coverage

- repository-level structure is present and coherent
- backend health endpoints are runnable
- admin application boots in a local development environment
- local PostgreSQL and Redis services are defined
- no secret values are committed

## Additional coverage

- order placement, ownership, idempotency, immutable snapshots, stale-checkout
  rejection, cancellation, and reorder API tests
- payment intent persistence, idempotency, customer isolation, webhook
  signatures and replay handling, amount/currency matching, and payment state
  transition tests
- atomic inventory reserve/release accounting and concurrent oversell prevention
- authorization tests
- Flutter widget and model tests

## Quality gates

- lint
- unit tests
- integration tests
- build
- security checks
- Docker build verification
- artifact validation
