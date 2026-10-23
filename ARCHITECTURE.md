# Architecture Overview

## System Goals

The platform is built as a modular monolith designed to support:

- B2C ordering flows for water and related FMCG products
- future B2B, mosque, event, and recurring-order expansion
- multi-city and multi-zone delivery operations
- server-authoritative pricing and inventory enforcement
- operational and compliance auditability

## Proposed Runtime Architecture

```text
Flutter Mobile (Android + iOS)
        |
        | HTTPS
        v
NestJS Backend
  +-----------------------------+
  | auth | customers | catalog |
  | pricing | cart | checkout  |
  | orders | payments | inventory |
  | delivery | promotions | etc. |
  +-----------------------------+
        |      |      |
        v      v      v
   PostgreSQL  Redis  Object Storage
        |
        +-----> Admin Portal (React + TS)
```

## Design Principles

- domain boundaries remain clear and modular
- services are not microservices by default
- future extraction is possible without rewrite
- pricing is always recalculated on the backend
- payment capture is provider-adapter based; payment data never includes raw card numbers or CVV
- customer-facing pricing is never trusted
- all order and payment transitions are auditable
- health, readiness, metrics, and structured logs are built in

## Strategic Boundaries

The application intentionally keeps a modular monolith shape for the initial stage, while preserving the ability to extract future services such as Order, Payment, Delivery, Notification, and Catalog when scale requires it.

## Data model and persistence

- PostgreSQL is the source of truth for transactional data
- Redis is used for caching, rate limiting support, and transient operational state
- S3-compatible object storage handles product media and document artifacts

## Security architecture

- HTTPS everywhere in production
- JWT access tokens plus refresh tokens
- secure secret management through environment files and deployment secrets
- rate limiting and request validation
- audit logging for privileged operations

## MVP foundation

Sprint 0 focuses on establishing the repository boundary, local runtime configuration, health endpoints, and the required foundational documentation and project structure.
