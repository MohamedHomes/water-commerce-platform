# API Contract Foundation

## Base Path

`/api/v1`

## Core endpoints

- `POST /api/v1/auth/login`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/refresh`
- `GET /api/v1/products`
- `GET /api/v1/categories`
- `GET /api/v1/brands`
- `GET /api/v1/cart`
- `POST /api/v1/cart/items`
- `PATCH /api/v1/cart/items/:productId`
- `DELETE /api/v1/cart/items/:productId`
- `DELETE /api/v1/cart`
- `POST /api/v1/cart/validate`
- `POST /api/v1/checkout/prepare`
- `GET /api/v1/checkout/:checkoutId`
- `POST /api/v1/orders`
- `GET /api/v1/orders`
- `GET /api/v1/orders/:id`
- `POST /api/v1/orders/:id/cancel`
- `POST /api/v1/orders/:id/reorder`
- `GET /api/v1/addresses`
- `POST /api/v1/addresses`
- `PATCH /api/v1/addresses/:id`
- `DELETE /api/v1/addresses/:id`
- `POST /api/v1/payments/intents`
- `GET /api/v1/payments/orders/:orderId`
- `POST /api/v1/payments/webhook`
- `GET /health`
- `GET /health/live`
- `GET /health/ready`

### Orders

- `POST /api/v1/orders` accepts `{ "checkoutId": "<checkout UUID>" }`. The
  backend verifies the customer's unexpired checkout, current cart, prices,
  product availability, and address before creating an immutable order
  snapshot. Repeating the request for the same checkout returns the existing
  order.
- Card orders are recorded as `payment_pending`; this endpoint does not capture
  payment. Cash orders are recorded as `placed`.
- Each successfully placed order reserves product-level stock in the same
  transaction; an eligible cancellation releases that reservation.
- `GET /api/v1/orders` supports `page` and `limit` query parameters (1-based,
  with a maximum limit of 100). Order and checkout resources are customer
  isolated.
- Cancellation is available while an order is `placed` or `payment_pending`.
  Reorder adds the saved product quantities to the active cart using current
  product prices and stock validation.

### Payments

- `POST /api/v1/payments/intents` requires customer authentication and accepts
  `{ "orderId": "<order UUID>", "idempotencyKey": "<unique key>" }`. The order
  must belong to the customer, be a card order, and be awaiting payment.
  Repeating the same key for that order returns the same persisted intent;
  reusing it for a different order is rejected.
- `GET /api/v1/payments/orders/:orderId` returns only the authenticated
  customer's payment attempts for that order.
- `POST /api/v1/payments/webhook` is unauthenticated at the application layer
  and requires `x-payment-signature`, an HMAC-SHA256 hex digest over the exact
  raw request body. Provider adapters must verify the signature and return a
  validated event with the payment ID, event ID, amount, currency, and success
  or failure type. Replayed events are harmless; reusing an event ID with a
  different payload is rejected.
- A verified success transitions the intent to `succeeded` and the order to
  `paid`; a verified failure marks only that attempt failed and allows another
  idempotency key. Webhook processing never accepts client-supplied card data.
- The runtime has no configured payment processor. Outside automated tests,
  intent creation and webhook processing return service unavailable. The
  deterministic test adapter is enabled only when `NODE_ENV=test`; its intents
  do not collect money or provide a checkout URL.

## Error Format

```json
{
  "code": "PRODUCT_OUT_OF_STOCK",
  "message": "The requested product is currently unavailable.",
  "details": {},
  "correlationId": "..."
}
```

## Quality requirements

- validation and pagination
- filtering and sorting
- consistent HTTP status codes
- correlation IDs and request IDs
- structured logs and no stack traces in client responses
