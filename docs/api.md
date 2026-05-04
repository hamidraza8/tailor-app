# API Documentation

Base URL: `http://localhost:5000/api`
Swagger UI: `http://localhost:5000/swagger`

## Authentication

All endpoints except `/api/auth/*` require JWT Bearer token.

### POST /api/auth/login
```json
Request: { "email": "admin@tailorshop.com", "password": "Admin@123" }
Response: { "token": "jwt...", "refreshToken": "...", "user": {...} }
```

### POST /api/auth/refresh
```json
Request: { "refreshToken": "..." }
Response: { "token": "jwt...", "refreshToken": "...", "user": {...} }
```

## Orders

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /orders | List orders (filters: from, to, status, customerId) |
| GET | /orders/today | Today's orders |
| GET | /orders/{id} | Order details |
| POST | /orders | Create order |
| PUT | /orders/{id} | Update order |
| POST | /orders/{id}/status | Update status |
| POST | /orders/{id}/photos | Upload photo |
| POST | /orders/{id}/inventory-usage | Add inventory usage |

## Customers

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /customers | List (search query param) |
| POST | /customers | Create |
| PUT | /customers/{id} | Update |
| GET | /customers/{id}/measurements | Get measurements |
| POST | /customers/measurements | Create measurement |

## Assets

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /assets | List (status filter) |
| POST | /assets | Create |
| PUT | /assets/{id} | Update |
| POST | /assets/{id}/photos | Upload photo |
| POST | /assets/{id}/approve | Approve |
| POST | /assets/{id}/reject | Reject |

## Inventory

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /inventory/items | List items |
| POST | /inventory/items | Create item |
| POST | /inventory/transactions | Create transaction |
| POST | /inventory/transactions/{id}/approve | Approve |
| POST | /inventory/transactions/{id}/reject | Reject |

## Invoices

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /invoices | List |
| POST | /invoices/generate | Generate from order |
| GET | /invoices/{id}/pdf | Download PDF |
| POST | /invoices/{id}/email | Email to customer |
| POST | /invoices/{id}/mark-printed | Mark as printed |

## Payments

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /payments | Create payment |
| GET | /payments/by-order/{orderId} | Payments for order |
| GET | /payments | All payments (from, to) |

## Expenses

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /expenses | List (status filter) |
| POST | /expenses | Create |
| POST | /expenses/{id}/approve | Approve |
| POST | /expenses/{id}/reject | Reject |

## Reports

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /reports/dashboard | Dashboard metrics |
| GET | /reports/profit-summary | Profit report (from, to) |
| GET | /reports/labour-payable | Labour report |
| GET | /reports/inventory-value | Total inventory value |
| GET | /reports/assets-value | Total asset value |

## Sync (Mobile)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /sync/push | Push offline changes |
| GET | /sync/pull | Pull server changes |
| POST | /sync/resolve-conflict | Resolve sync conflict |

## Settings

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /settings/business-profile | Get settings |
| PUT | /settings/business-profile | Update settings |

## Test Credentials

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@tailorshop.com | Admin@123 |
| Partner | partner@tailorshop.com | Partner@123 |
