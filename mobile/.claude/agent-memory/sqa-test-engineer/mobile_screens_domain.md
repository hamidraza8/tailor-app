---
name: TailorShop Mobile — Screen & Domain Inventory
description: All Flutter screens, services, domain enums, order statuses, payment methods, expense/asset category constants
type: project
---

## Flutter Screens (mobile/lib/screens/)
- login_screen.dart — Email+password auth, navigates to /home on success
- splash_screen.dart — Brief loading before login/home decision
- home_screen.dart — Dashboard: revenue, collection rate, delivery status, attention items, partner balances section
- new_order_screen.dart — 5-step wizard: Customer → OrderType → DesignPhoto → Measurements → Amounts
- today_orders_screen.dart — Lists orders created today from local SQLite
- order_detail_screen.dart — Status updates, payment history, WhatsApp/call customer, invoice access
- receive_payment_screen.dart — Select order with balance, enter amount (validates amount <= balance), choose payment method
- invoice_screen.dart — Read-only invoice view per order
- add_inventory_screen.dart — Item name, quantity, unit (meters/yards/pieces/rolls/kg/dozen), cost per unit, supplier, notes, receipt photo
- inventory_list_screen.dart — Shows inventory transactions from SQLite
- add_asset_screen.dart — Type, name, quantity (default 1), unit value, owner (Business/Partner 1/Partner 2/Rented), notes, photo
- assets_list_screen.dart — Lists assets from SQLite
- add_expense_screen.dart — Category picker, amount, description, receipt photo; saves to SQLite + SyncQueue
- expenses_list_screen.dart — Shows expenses with approval status
- partner_balances_screen.dart — Calls /reports/partner-balances API (online only); shows capital/spendings/remaining per partner
- add_partner_screen.dart — Two-step API: POST /users (role=1) then POST /partners; profitShare default 50, labourShare default 35
- add_capital_screen.dart — Calls /partners to list, then POST /capital-transactions; types: CapitalAdvance/AdditionalCapital/Withdrawal/Adjustment
- add_spending_screen.dart — Records a spending entry
- payments_list_screen.dart — All payments from SQLite
- sync_status_screen.dart — SyncQueue items; Sync Now (forceRetry), Clear Completed, Clear All (with confirm dialog)
- settings_screen.dart — Server URL, logout

## Services (mobile/lib/services/)
- api_service.dart — HTTP client wrapping GET/POST to ApiConfig.baseUrl
- auth_service.dart — Login, token storage
- database_service.dart — SQLite CRUD for all entities
- sync_service.dart — addToQueue(), syncNow()

## Key Constants (mobile/lib/utils/constants.dart)
- ApiConfig.baseUrl = 'http://10.255.254.48:5000/api', timeout = 30s
- OrderTypes: suit, kurti, trouser, frock, abaya, alteration
- OrderStatus sequence: Pending → Cutting → Stitching → Finishing → Ready → Delivered (+ Cancelled)
- PaymentMethods: Cash, JazzCash, EasyPaisa, Bank Transfer
- ExpenseCategories: Thread & Supplies, Fabric Purchase, Machine Repair, Electricity Bill, Rent, Staff Salary, Transport, Packaging, Other
- AssetTypes: Sewing Machine, Overlock Machine, Iron/Press, Cutting Table, Mannequin, Furniture, Computer/Device, Other

## Domain Enums (backend/src/TailorShop.Domain/Enums/Enums.cs)
- ApprovalStatus: PendingApproval(0), Approved(1), Rejected(2)
- SyncStatus: Pending(0), Synced(1), Failed(2), Conflict(3)
- CapitalTransactionType: CapitalAdvance, AdditionalCapital, Withdrawal, Adjustment
- PaymentMethod: Cash, BankTransfer, EasyPaisa, JazzCash, Other
- InventoryTransactionType: Purchase, UsedInOrder, Adjustment, Return

**Why:** Needed as authoritative reference when writing test cases for status transitions, enum values, and dropdown options.  
**How to apply:** Always cross-check UI labels against these enum values when writing sync or approval test cases.
