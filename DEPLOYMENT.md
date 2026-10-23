# Deployment Guide

## Local deployment

The project includes a Docker Compose foundation for local infrastructure:

```bash
docker compose -f infrastructure/docker-compose.yml up -d
```

## Production deployment

Production deployment is intentionally documented separately from the foundation scaffold. The architecture supports controlled deployment via environment-specific configuration and secure secret injection.

## Deployment controls

- separate staging and production environments
- controlled approval flow
- artifact generation after build and test gates
- no direct production migration from unreviewed changes
