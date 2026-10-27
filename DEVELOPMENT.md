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
inbox, customer favorites, password recovery by SMTP email, plus database-backed
admin dashboard and promotion management APIs. Notification preferences and
push/email notification delivery are not currently implemented.
Payment processing has no configured real provider, and delivery has no
dispatch or live-tracking integration. PostgreSQL 16 deployment verification
remains pending.

### Customer password recovery

The customer app's password recovery flow uses a 64-character, single-use
recovery code delivered by email. Codes expire after 15 minutes; the database
stores only a SHA-256 digest. The request response does not disclose whether an
email is registered. Configure `SMTP_HOST`, `SMTP_PORT`, and `SMTP_FROM` to
enable recovery; `SMTP_USER` and `SMTP_PASSWORD` are optional for servers that
do not require authentication. Do not put real mail credentials in tracked
files. Without the required SMTP settings, the API reports recovery as
unavailable rather than pretending an email was sent. Database migrations run
on backend startup and create the reset-token table.

Configure `admin/.env` with `VITE_API_URL` (see `admin/.env.example`) to point
the portal at the API. Administrator accounts must first be registered as
customers and then explicitly elevated by a trusted database operator; public
registration cannot assign the admin role. Sign in through the portal with
that account.

### Local administrator bootstrap

There is no default administrator account or administrator password. Register a
dedicated local account through the supported customer registration flow, then
have a trusted local database operator promote only that exact account:

```powershell
psql -h 127.0.0.1 -p 5432 -U postgres -d aquaflow
```

`psql` prompts for the database password. In its interactive session, run the
following statements, substituting the email address used for that registration:

```sql
BEGIN;
UPDATE customers
SET role = 'admin'
WHERE email = lower('operator-chosen-local-email@example.test')
  AND role = 'customer'
RETURNING role;
```

Commit only if the update returns exactly one row with role `admin`; otherwise
roll back. Then sign in at the Admin portal using that account's chosen
credentials. Do not add role assignment to public registration or commit local
credentials. Admin API routes independently verify the current database role.

### Resetting an existing local administrator password

The repository does not define a default password or password seed for
`admin@aquaflow.local`. If that account exists in the local development
database but its password is unknown, reset it interactively from the
`backend/` directory:

```powershell
npm run build
npm run admin:reset-local-password
```

The script requires an interactive terminal, explicitly confirms the exact
account, prompts for the new password twice without echoing it, and applies the
same bcrypt hashing helper and password policy used by registration/login.
It refuses `NODE_ENV=production`, any database other than `aquaflow` on
`127.0.0.1:5432`, and any account that is missing or does not already have
role `admin`. It updates only `password_hash` and `updated_at`; the existing
role is preserved. The password/hash are not printed. Restart the backend
after rebuilding so the running service uses the current code. This tool is
for explicitly requested local recovery, not production password management.

PGlite-backed integration tests currently execute the ordered migrations and
exercise persistence behavior. They do not replace verification against the
deployed PostgreSQL 16 configuration; see [DEPLOYMENT.md](./DEPLOYMENT.md)
before production release.
