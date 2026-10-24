# AquaFlow Commerce Platform

AquaFlow is an original water-commerce platform designed for bottled water, water cartons, bulk orders, mosque supply, and recurring household delivery. This repository establishes the foundation for a modular monolith architecture spanning a Flutter mobile app, a NestJS backend, a React admin portal, and local infrastructure.

## Current implementation

The repository includes:

- `/mobile` for the Flutter client
- `/backend` for the NestJS API
- `/admin` for the React admin portal
- `/infrastructure` for local service configuration
- `/docs` for product, design, and architecture documentation
- Root-level configuration and environment examples

The backend currently implements customer authentication, catalog and search,
cart/pricing, customer addresses, checkout drafts, customer order management,
and order-level stock reservation. These domains use PostgreSQL through the
backend migration runner;
PGlite integration tests cover migrations and persistence. Verification
against the Docker PostgreSQL 16 service remains environment dependent. Card
orders are recorded as payment-pending until a verified provider webhook
confirms payment.

The payments API provides provider-neutral intent persistence and signed,
idempotent webhook handling. Only its deterministic test adapter is configured
for automated tests; no production payment processor is connected.

The app also includes customer delivery status history and a persistent in-app
notification inbox. Driver dispatch/live tracking and external email, SMS, and
push notification providers remain unconfigured.

Promotion codes are calculated server-side during checkout and revalidated
against their configured limits when the order is placed. The admin portal
uses database-backed operations metrics, an order queue, and promotion
management; payment capture and delivery dispatch remain unavailable.

Customers can submit product reviews only for delivered purchases. Reviews
remain hidden until administrator moderation.

English/Arabic localization is in progress across the mobile client and admin
portal. The admin dashboard now has persisted language selection and RTL
layout; the mobile app has persisted language selection, translated customer
copy, and Arabic RTL. See `ROADMAP.md` for remaining localization acceptance
work and `CODE_COMPLETION_PLAN.md` for the application completion queue.

Backend and admin containers have production-oriented build stages, but Docker
runtime and PostgreSQL 16 deployment verification have not been run in this
environment.

## Product Vision

The platform is a production-grade commerce and delivery solution for water products and adjacent FMCG items. The solution is designed around business capability domains, not a clone of any existing app.

## Repository Layout

- `mobile/` - Flutter customer app skeleton with RTL/LTR-ready structure
- `backend/` - NestJS API with health endpoints and modular domain scaffolding
- `admin/` - React + TypeScript portal skeleton
- `infrastructure/` - Docker Compose and local deployment definitions
- `docs/` - Design system and architecture documentation

## Local Runtime Stack

- PostgreSQL
- Redis
- NestJS backend
- React admin portal
- Flutter mobile app shell

## Security

- no real secrets committed
- `.env.example` is the template for local environment values
- production credentials must be supplied externally

## Development

See `DEVELOPMENT.md` for setup steps.
See [`ROADMAP.md`](./ROADMAP.md) for the sprint-by-sprint implementation audit,
verified status, and remaining production readiness work. See
[`CODE_COMPLETION_PLAN.md`](./CODE_COMPLETION_PLAN.md) for prioritized
application-code gaps and deferred provider/infrastructure tasks.
