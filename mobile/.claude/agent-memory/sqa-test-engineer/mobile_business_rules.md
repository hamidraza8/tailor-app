---
name: TailorShop Mobile — Key Business Rules for Testing
description: Profit formula, payment validation, order status flow, labour/profit share defaults, offline-sync behaviour, approval workflow
type: project
---

## Financial Calculations
- Net Profit = Revenue − (Revenue × LabourSharePct%) − Inventory Cost − Expenses
- Partner Profit = Net Profit × ProfitSharePct%
- Default LabourSharePct = 35% (Partner 1, Tailor)
- Default ProfitSharePct = 50% per partner
- Collection Rate = (Total Collected / Total Revenue) × 100
- Total Order Value = StitchingAmount + MaterialAmount
- Balance Due = TotalAmount − sum(all payments for that order)

## Critical Validation Rules Found in Code
- receive_payment_screen.dart: amount > balanceAmount → error "Amount exceeds balance of ..."
- new_order_screen.dart: advance > total → must fail (business rule; validate in test)
- add_expense_screen.dart: amount <= 0 → snackbar "Please enter amount"; no category → "Please select a category"
- add_asset_screen.dart: no type → "Please select asset type"; unitValue <= 0 → "Please enter unit value"
- add_inventory_screen.dart: empty name → "Please enter item name"; qty <= 0 → "Please enter quantity"; cost <= 0 → "Please enter cost per unit"
- login_screen.dart: empty fields → "Please enter email and password" (client-side, no API call made)
- add_capital_screen.dart: no amount validation message seen in code — test for zero/negative amount

## Order Status Flow
Pending → Cutting → Stitching → Finishing → Ready → Delivered (also Cancelled)
- Status changes are saved to SQLite immediately and added to SyncQueue as action='update'
- Orders with dueDate < now = Overdue
- Orders with dueDate between now and now+7days = Due Soon
- Orders with dueDate > now+7days OR dueDate == null = On Track

## Approval Workflow
- Entities requiring approval: Assets, InventoryTransactions, Expenses
- Default status on creation: PendingApproval
- Admin approves/rejects via Web Admin (http://localhost:3000) or Swagger
- Mobile reflects status only after sync pull from server
- Rejected expenses should NOT count toward dashboard expense totals

## Offline-Sync Behaviour
- All writes go to SQLite first, then SyncQueue (entityType, entityId, action, payload, filePath)
- SyncService.addToQueue() is called after every save
- AppProvider.refreshSyncCount() updates the badge on Home
- Sync is triggered manually via SyncStatusScreen or automatically on reconnect
- Failed sync items remain in queue with status 'failed' for retry
- After successful sync, server assigns real IDs; local IDs are temporary

## Partner Setup Rules
- add_partner_screen.dart: two API calls — POST /users (role=1/Partner) then POST /partners with userId
- If /users call fails, partner is not created (no rollback needed — partner record doesn't exist yet)
- profitShare + labourShare are stored as floats (0-100 percentage values, not decimals)
- Theoretical business rule: sum of all partner profitSharePct should not exceed 100 (server-enforced)

## Delivery Status Logic (home_screen.dart lines 106-121)
- overdue: dueDate.isBefore(now)
- dueSoon: dueDate.isBefore(now + 7 days) AND not overdue
- onTrack: dueDate after 7 days OR dueDate is null

**Why:** These rules were derived directly from reading the source code during the first test case authoring session on 2026-05-03.  
**How to apply:** Use these rules to verify expected results in all financial, validation, and status-related test cases. Do not assume — cross-check formulas against this record.
