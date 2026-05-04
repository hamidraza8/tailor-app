---
name: TailorShop Mobile — Manual Test Case Registry
description: 66 manual test cases written on 2026-05-03, file location, flow-to-TC mapping, coverage gaps noted
type: project
---

## Test Case File
`D:/Personal/Apps/tailor-application/docs/mobile-manual-test-cases.md`

## Coverage Summary (66 total test cases)
| Flow | TCs | IDs |
|------|-----|-----|
| Flow 1: First-Time Setup | 8 | TC-SETUP-001 to TC-SETUP-008 |
| Flow 2: New Order | 5 | TC-ORDER-001 to TC-ORDER-005 |
| Flow 3: Order Lifecycle | 7 | TC-LIFECYCLE-001 to TC-LIFECYCLE-007 |
| Flow 4: Record Expense | 5 | TC-EXP-001 to TC-EXP-005 |
| Flow 5: Inventory | 4 | TC-INV-001 to TC-INV-004 |
| Flow 6: Partner Capital | 4 | TC-CAP-001 to TC-CAP-004 |
| Flow 7: Asset Purchase | 5 | TC-ASSET-001 to TC-ASSET-005 |
| Flow 8: Offline → Sync | 7 | TC-SYNC-001 to TC-SYNC-007 |
| Flow 9: Financial Dashboard | 7 | TC-DASH-001 to TC-DASH-007 |
| Flow 10: Admin Approvals | 4 | TC-APPR-001 to TC-APPR-004 |
| Edge Cases | 10 | TC-EDGE-001 to TC-EDGE-010 |

## HIGH Priority Test Cases (must pass before go-live)
TC-SETUP-001, TC-SETUP-004, TC-SETUP-005, TC-SETUP-007,
TC-ORDER-001, TC-ORDER-003, TC-ORDER-005,
TC-LIFECYCLE-001, TC-LIFECYCLE-002, TC-LIFECYCLE-003, TC-LIFECYCLE-004, TC-LIFECYCLE-005,
TC-EXP-001, TC-EXP-002, TC-EXP-003,
TC-INV-001, TC-INV-004,
TC-CAP-001, TC-CAP-002,
TC-ASSET-001, TC-ASSET-004,
TC-SYNC-001, TC-SYNC-002, TC-SYNC-003,
TC-DASH-001, TC-DASH-002, TC-DASH-003, TC-DASH-006,
TC-APPR-001, TC-APPR-002,
TC-EDGE-001, TC-EDGE-003, TC-EDGE-005, TC-EDGE-007, TC-EDGE-010

## Known Coverage Gaps (not yet tested — future test case candidates)
- add_spending_screen.dart: no test cases written (screen not yet fully understood)
- OCR document upload flow (OcrController)
- Invoice PDF generation and sharing
- Settings screen — changing server URL
- Pull-to-refresh behaviour on list screens
- Concurrent sync: two devices syncing the same entity simultaneously
- Partner login (role=Partner) — what screens are accessible vs restricted
- Staff role login and access restrictions
- Extremely large sync queue (100+ items) — performance test
- Search/filter functionality on Inventory List and Today's Orders

## Test Data Dependencies
- TC-APPR-001 to TC-APPR-004 require Web Admin or Swagger to approve/reject — cannot be done fully on mobile alone
- TC-CAP-001, TC-CAP-004 require backend to be reachable (Partner Balances is API-only, not offline)
- TC-SETUP-004 to TC-SETUP-008 require clean DB state (no pre-existing partners with same email)
- Seeded admin credentials: check backend/src/TailorShop.Infrastructure/Data/DbSeeder.cs

**Why:** Registry created on 2026-05-03 to track coverage and gaps for the TailorShop mobile MVP.  
**How to apply:** Before starting a new test case authoring session, check this file to avoid duplicates and to identify which gaps to fill next.
