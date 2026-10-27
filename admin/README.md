# AquaFlow Admin Web

The Admin Web app is a React/Vite SPA. Its current routes use the browser History
API (no additional routing dependency), and the Vite and Nginx configurations
serve `index.html` for direct route requests and refreshes.

| Route | Page |
| --- | --- |
| `/` | Dashboard |
| `/products` | Product management |
| `/orders` | Orders and paginated order summaries |
| `/deliveries` | Delivery status operations |
| `/inventory` | Stock and audited adjustments |
| `/promotions` | Promotion creation and activation |
| `/categories` | Category creation and editing |
| `/brands` | Brand creation and editing |
| `/reviews` | Pending review moderation |
| `/catalog-terms` | Combined category and brand management |

The app loads only the API data needed by the current page. Existing Admin
authentication and protected `/admin/*` API endpoints are retained. The access
token and account email are held in `sessionStorage` to keep authenticated
navigation working across a page refresh; sign-out clears them.

Known API limitations are represented rather than simulated: there is no
dedicated Admin order-detail endpoint or payment-status field, so expandable
order details contain only the summary fields returned by the existing
paginated order-list API; the UI labels payment method separately and calls
this limitation out. Delivery responses do not include customer information.
Review moderation currently lists pending reviews only. Product image storage
is not configured and delivery assignment/live driver tracking is unavailable.
Product searches are limited to the existing endpoint response; the Admin API
currently returns a maximum of 500 product/inventory rows and 100
delivery/review rows.

Run `npm run dev`, `npm run build`, `npm run lint`, and `npm test` from this
directory.
