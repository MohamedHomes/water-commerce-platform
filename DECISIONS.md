# Architecture Decisions

## Decision 1: Modular monolith first

The initial architecture uses a modular monolith to keep the system coherent while preserving future extraction into specialized services.

## Decision 2: Server-authoritative pricing and inventory

The backend recalculates all totals and validations before order creation or payment capture to preserve business integrity.

## Decision 3: Immutable order snapshots

Orders preserve historical snapshots so pricing and customer context remain stable after catalog or account changes.

## Decision 4: Clear domain boundaries

The implementation is organized around auth, customers, catalog, pricing, cart, checkout, orders, payments, inventory, delivery, promotions, coupons, notifications, reviews, subscriptions, audit, and admin responsibilities.

## Decision 5: Local-first foundation

Docker Compose provides local PostgreSQL and Redis services to support development, validation, and future integration work.
