# Development Guide

## Prerequisites

- Node.js 20+
- npm
- Docker and Docker Compose
- Flutter SDK
- Git

## Local project setup

```bash
npm install
```

## Run backend

```bash
cd backend
npm install
npm run start:dev
```

## Run admin portal

```bash
cd admin
npm install
npm run dev -- --host 0.0.0.0
```

## Run mobile app

```bash
cd mobile
flutter pub get
flutter run
```

## Run local infrastructure

```bash
docker compose -f infrastructure/docker-compose.yml up -d
```

## Health checks

- backend: `http://localhost:3000/health`
- admin: `http://localhost:5173`
- PostgreSQL: local compose service
- Redis: local compose service

## Implementation status

The backend includes authentication, catalog/search, carts, address
management, checkout drafts, customer orders, payment lifecycle groundwork,
inventory reservations, delivery status history, and an in-app notification
inbox, plus database-backed admin dashboard and promotion management APIs.
Payment processing has no configured real provider, and delivery has no
dispatch or live-tracking integration. PostgreSQL 16 deployment verification
remains pending.

Configure `admin/.env` with `VITE_API_URL` (see `admin/.env.example`) to point
the portal at the API. Administrator accounts must first be registered as
customers and then explicitly elevated by a trusted database operator; public
registration cannot assign the admin role. Sign in through the portal with
that account.

PGlite-backed integration tests currently execute the ordered migrations and
exercise persistence behavior. They do not replace verification against the
deployed PostgreSQL 16 configuration; see [DEPLOYMENT.md](./DEPLOYMENT.md)
before production release.
