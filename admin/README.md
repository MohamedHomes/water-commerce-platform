# AquaFlow Admin Web

The Admin Web app is a React/Vite SPA. Its current routes use the browser History
API (no additional routing dependency), and the Vite and Nginx configurations
serve `index.html` for direct route requests and refreshes.

| Route | Page |
| --- | --- |
| `/` | Dashboard |
| `/products` | Product management |
| `/orders` | Paginated order summaries with separate order and delivery statuses |
| `/deliveries` | Delivery status operations |
| `/inventory` | Available stock, audited adjustments, and recorded movement history |
| `/promotions` | Promotion creation and activation |
| `/categories` | Category creation and editing |
| `/brands` | Brand creation and editing |
| `/reviews` | Pending review moderation |
| `/catalog-terms` | Combined category and brand management |

The app loads only the API data needed by the current page. Existing Admin
authentication and protected `/admin/*` API endpoints are retained. The access
token and account email are held in `sessionStorage` to keep authenticated
navigation working across a page refresh; sign-out clears them.

Order status is driven by the payment/customer order lifecycle and is distinct
from delivery status; there is no Admin order-status mutation. The order list
shows the customer's name and ID separately, plus the persisted delivery status.
Order details use the protected `GET /admin/orders/:id` endpoint. Payment status
remains available in order details, not the paginated summary.

The dashboard's **Paid order total** is the sum of `orders.total` for orders
whose status is `paid`; that status is set by a successful payment webhook.
This amount is after order discounts and includes delivery and service fees.
Cash, pending, and cancelled orders are excluded. Refunds are not modeled, so
this is an operational paid-order total, not a complete accounting revenue
figure.

Inventory quantity is the amount available to sell: order placement decrements
it, and order cancellation releases it. The Admin movement-history endpoint
shows the existing reservation, cancellation, and adjustment ledger records.
The model does not record dispatch quantities or physical stocktakes, and
reservations are not transitioned on delivery completion. Before implementing
stocktake reconciliation, the business must define when a reservation becomes
fulfilled/consumed, how failed or returned deliveries affect stock, and whether
a physical count is compared with total physical stock or available-to-sell
stock.

Review moderation currently lists pending reviews only. Product image storage
is not configured and delivery assignment/live driver tracking is unavailable.
Product searches are limited to the existing endpoint response; the Admin API
currently returns a maximum of 500 product/inventory rows and 100
delivery/review rows.

Run `npm run dev`, `npm run build`, `npm run lint`, and `npm test` from this
directory.
