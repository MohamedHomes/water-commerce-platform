# Deployment Guide

## Local deployment

The project includes a Docker Compose foundation for local infrastructure:

```bash
docker compose up -d --build
```

The backend image uses a production runtime stage and runs as a non-root user.
The admin image serves a static Vite build through Nginx. Set `VITE_API_URL`
when building the admin image if the API is not reachable at the local default.

## PostgreSQL 16 verification

For the deferred deployment check, verify the rendered configuration and start
the database service:

```powershell
docker compose config
docker compose up -d postgres
```

Configure `DATABASE_URL` to point to that PostgreSQL 16 service, start the
backend, and confirm `/health/ready` reports the database as connected and
migrations have completed. PGlite tests do not replace this deployment check.

## Production environment

- set `NODE_ENV=production`
- provide distinct `JWT_SECRET` and `JWT_REFRESH_SECRET` values of at least 32
  characters through secret management
- set `CORS_ORIGINS` to an explicit comma-separated browser origin allowlist
- configure the admin `VITE_API_URL` at image build time
- do not use the local Compose database password or development JWT defaults in
  production

## Production deployment

Production deployment is intentionally documented separately from the foundation scaffold. The architecture supports controlled deployment via environment-specific configuration and secure secret injection.

## Deployment controls

- separate staging and production environments
- controlled approval flow
- artifact generation after build and test gates
- no direct production migration from unreviewed changes
