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
management, checkout drafts, and customer order history/actions. PostgreSQL 16
deployment verification, payment processing, and inventory reservation are
still pending; card orders remain `payment_pending` until a payment integration
is implemented.
