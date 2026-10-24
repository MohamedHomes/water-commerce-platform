# Security and Governance

## Core security requirements

- HTTPS in production
- JWT-based authentication with refresh tokens
- secure token storage
- password hashing and verification where applicable
- OTP protection for sensitive workflows
- rate limiting and input validation
- PostgreSQL-backed rate limits for authentication and profile mutations;
  counters are shared across backend instances and no in-memory fallback is
  used
- authorization and role-based permission checks via domain policy layers
- administrative endpoints verify the current database role, and public
  registration cannot assign administrative privileges
- production access and refresh JWT secrets must be distinct, explicitly
  configured values of at least 32 characters
- production browser origins are restricted through `CORS_ORIGINS`
- inventory adjustments and promotion configuration are admin-only and
  create audit records in the same transaction as the change
- delivery status changes are admin-only, transition-validated, and audited
- public review visibility requires moderation, and review submissions are
  tied to the authenticated customer's delivered order snapshot
- secure headers and CORS configuration
- secret management through environment variables and deployment secret stores
- audit logging for privileged and transactional actions
- payment provider webhook signatures must be verified against the exact raw
  request body using a constant-time comparison
- payment idempotency keys and provider event IDs must be persisted and
  deduplicated
- promotion discounts are calculated by the backend and redemption caps are
  checked in the order transaction
- raw card numbers and CVV must never enter application storage or logs
- no secrets committed to source control

## System notes

The payment module currently has no configured production provider. Its test
adapter is selected only in the automated test environment and does not process
real payments. Production credentials and webhook verification configuration
must be supplied through the chosen provider's deployment secret mechanism
before enabling payment processing. Never use the test adapter in production.

Promotion administration requires the database-backed admin role. Provision
admin accounts only through a controlled operator action after account
registration; do not add role selection to public registration.

Development-only JWT defaults are rejected in production. Configure
`JWT_SECRET`, `JWT_REFRESH_SECRET`, and `CORS_ORIGINS` through deployment secret
and environment management before starting a production process.

Login is limited to 10 attempts per client address per 15 minutes; registration
to 20; refresh and logout to 30; profile updates to 10. Exceeded windows return
429 with a `Retry-After` header. Only a SHA-256 scope/address digest is stored.
The backend currently does not trust forwarded IP headers by default; operators
must configure trusted proxy behavior deliberately when deployed behind a
reverse proxy. This control does not replace edge rate limiting.

OTP delivery and verification remain disabled pending a product decision on
the verification channel and recovery policy; no fake or unusable OTP flow is
exposed.
