# Security and Governance

## Core security requirements

- HTTPS in production
- JWT-based authentication with refresh tokens
- secure token storage
- password hashing and verification where applicable
- OTP protection for sensitive workflows
- rate limiting and input validation
- authorization and role-based permission checks via domain policy layers
- secure headers and CORS configuration
- secret management through environment variables and deployment secret stores
- audit logging for privileged and transactional actions
- payment provider webhook signatures must be verified against the exact raw
  request body using a constant-time comparison
- payment idempotency keys and provider event IDs must be persisted and
  deduplicated
- raw card numbers and CVV must never enter application storage or logs
- no secrets committed to source control

## System notes

The payment module currently has no configured production provider. Its test
adapter is selected only in the automated test environment and does not process
real payments. Production credentials and webhook verification configuration
must be supplied through the chosen provider's deployment secret mechanism
before enabling payment processing. Never use the test adapter in production.
