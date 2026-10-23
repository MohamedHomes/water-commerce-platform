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
