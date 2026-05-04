# TailorShop Mobile App — Manual Test Cases
**Version**: 1.0  
**Date**: 2026-05-03  
**Platform**: Flutter 3.x — Android/iOS  
**Backend**: http://10.255.254.48:5000/api  
**Tester**: _______________  
**Device Under Test**: _______________  

---

## Conventions

| Symbol | Meaning |
|--------|---------|
| 🔴 HIGH | Critical business flow — must pass before go-live |
| 🟡 MEDIUM | Important but not a launch blocker |
| [ ] | Pass/Fail checkbox — tick on execution |

**Seeded Data Note**: The backend DbSeeder creates one Admin user and one Partner user on first run. Check `backend/src/TailorShop.Infrastructure/Data/DbSeeder.cs` for the exact credentials before running any test in Flows 1–10.

---

## Flow 1: First-Time Setup

---

**TC-SETUP-001** — Successful Admin Login 🔴 HIGH

- **Preconditions**: App is freshly installed or logged out. Backend is reachable at `http://10.255.254.48:5000`. Seeded admin credentials are known.
- **Steps**:
  1. Open the app. Observe the splash screen briefly, then the Login screen.
  2. Enter the seeded admin email in the Email field.
  3. Enter the seeded admin password in the Password field.
  4. Tap the Login button.
- **Expected Result**: Loading indicator appears. App navigates to the Home Dashboard. The sync indicator in the top bar is visible. No error message is shown.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-SETUP-002** — Login with Wrong Password 🔴 HIGH

- **Preconditions**: App is on the Login screen.
- **Steps**:
  1. Enter a valid email (e.g., the seeded admin email).
  2. Enter an incorrect password (e.g., `wrongpassword123`).
  3. Tap Login.
- **Expected Result**: An error message appears below the form or as a snackbar reading something like "Invalid credentials" or "Login failed". The app remains on the Login screen. No navigation occurs.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-SETUP-003** — Login with Empty Fields 🟡 MEDIUM

- **Preconditions**: App is on the Login screen.
- **Steps**:
  1. Leave both Email and Password fields empty.
  2. Tap Login.
- **Expected Result**: An inline error message appears: "Please enter email and password". The login request is NOT sent to the server (no network call made).
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-SETUP-004** — Add Partner 1 (Tailor) 🔴 HIGH

- **Preconditions**: Logged in as Admin. Backend is reachable. No existing user with the same email.
- **Steps**:
  1. From the Home screen, navigate to Partner Balances (tap "Partners" section or use the drawer/menu).
  2. Tap the "Add Partner" button.
  3. Fill in the form:
     - Full Name: `Amna Tailor`
     - Email: `amna@tailorshop.pk`
     - Phone: `03001234567`
     - Password: `Test@1234`
     - Profit Share %: `50` (default, leave as-is)
     - Labour Share %: `35` (default, leave as-is)
  4. Tap Save / Submit.
- **Expected Result**: A success snackbar appears ("Partner created successfully" or similar). The screen navigates back. The new partner appears in the partners list or Partner Balances screen.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-SETUP-005** — Add Partner 2 (Investor) 🔴 HIGH

- **Preconditions**: Logged in as Admin. Backend is reachable. No existing user with same email as Partner 2.
- **Steps**:
  1. Navigate to Add Partner screen.
  2. Fill in the form:
     - Full Name: `Zara Investor`
     - Email: `zara@tailorshop.pk`
     - Phone: `03009876543`
     - Password: `Test@5678`
     - Profit Share %: `50`
     - Labour Share %: `0` (clear the default 35, type `0`)
  3. Tap Save / Submit.
- **Expected Result**: Success snackbar. Both partners now appear in the Partner Balances screen.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-SETUP-006** — Add Partner with Duplicate Email 🟡 MEDIUM

- **Preconditions**: Partner 1 already created with email `amna@tailorshop.pk`.
- **Steps**:
  1. Navigate to Add Partner screen.
  2. Enter the same email `amna@tailorshop.pk` with a different name and phone.
  3. Tap Save / Submit.
- **Expected Result**: An error message is displayed ("Email already exists" or similar server error). No duplicate partner is created. The app remains on the Add Partner screen.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-SETUP-007** — Add Capital for Partner 1 (Initial Capital Advance) 🔴 HIGH

- **Preconditions**: Partner 1 (Amna Tailor) exists. Logged in as Admin.
- **Steps**:
  1. Navigate to the Add Capital screen (via Home screen "Add Capital" button or Partner Balances screen).
  2. From the Partner dropdown, select `Amna Tailor`.
  3. From the Transaction Type dropdown, select `CapitalAdvance`.
  4. Enter Amount: `50000`.
  5. Date: today (default).
  6. Notes: `Initial capital`.
  7. Tap Save.
- **Expected Result**: Success message. The Partner Balances screen for Amna Tailor shows Total Capital Added = PKR 50,000.00.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-SETUP-008** — Add Capital with Zero Amount 🟡 MEDIUM

- **Preconditions**: At least one partner exists.
- **Steps**:
  1. Navigate to Add Capital screen.
  2. Select any partner and any transaction type.
  3. Enter Amount: `0`.
  4. Tap Save.
- **Expected Result**: A validation error is shown ("Amount must be greater than zero" or similar). No API call is made. The form remains active.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

## Flow 2: Daily Operations — New Order

---

**TC-ORDER-001** — Create New Order for New Customer (Happy Path) 🔴 HIGH

- **Preconditions**: Logged in. App has at least one active partner configured. Device has internet.
- **Steps**:
  1. From Home, tap the large "New Order" action button.
  2. **Step 1 — Customer**: The customer search box is shown with an existing customers list. Tap "Add New" (or similar). Enter:
     - Name: `Sara Khanum`
     - Phone: `03331234567`
  3. Tap Next / Confirm to proceed to Step 2.
  4. **Step 2 — Order Type**: Tap the "Suit" tile (سوٹ).
  5. Tap Next.
  6. **Step 3 — Design Photo**: Skip (tap Next without capturing a photo).
  7. **Step 4 — Measurements**: Enter:
     - Chest: `36`
     - Waist: `32`
     - Hip: `40`
     - Shoulder: `14`
     - Shirt Length: `44`
     - Leave remaining fields blank.
  8. Tap Next.
  9. **Step 5 — Amounts**: Enter:
     - Stitching Amount: `2500`
     - Material Amount: `1500`
     - Advance Payment: `1000`
     - Due Date: 7 days from today (default).
     - Notes: `White kameez, no embroidery`
  10. Tap Save / Submit.
- **Expected Result**: A success confirmation is shown. The order is saved locally in SQLite. A sync queue entry is created. Navigating to Today's Orders shows this new order with status "Pending". The order total is PKR 4,000.00 (2500 + 1500). Balance due is PKR 3,000.00.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-ORDER-002** — Create New Order for Existing Customer 🟡 MEDIUM

- **Preconditions**: Customer `Sara Khanum` already exists from TC-ORDER-001.
- **Steps**:
  1. Tap "New Order".
  2. **Step 1**: In the customer search bar type `Sara`. The existing customer appears in the list. Tap her name to select.
  3. Proceed with Order Type = `Kurti`.
  4. On the Measurements step, the app should offer to use previous measurements for "Kurti" type. If available, toggle "Use Previous Measurement" ON.
  5. Enter Stitching Amount: `1200`, Material Amount: `800`, Advance: `500`.
  6. Tap Save.
- **Expected Result**: Order is saved. If a previous measurement existed for Kurti, the fields were pre-populated. Order total = PKR 2,000.00. Balance = PKR 1,500.00.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-ORDER-003** — New Order — Advance Payment Exceeds Total 🔴 HIGH

- **Preconditions**: On the New Order screen, Step 5.
- **Steps**:
  1. Enter Stitching Amount: `1000`.
  2. Enter Material Amount: `500`.
  3. Enter Advance Payment: `2000` (exceeds total of 1500).
  4. Tap Save / Submit.
- **Expected Result**: A validation error is shown ("Advance cannot exceed total amount" or similar). The order is NOT saved.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-ORDER-004** — New Order — Skip Customer Selection 🟡 MEDIUM

- **Preconditions**: On New Order screen, Step 1.
- **Steps**:
  1. Do not select or add a customer.
  2. Tap Next.
- **Expected Result**: The app does not advance to Step 2. An error or snackbar message appears: "Please select or add a customer".
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-ORDER-005** — New Order with Zero Stitching Amount 🔴 HIGH

- **Preconditions**: On New Order screen, at Step 5 (Amounts).
- **Steps**:
  1. Select a customer and order type in previous steps.
  2. Enter Stitching Amount: `0`.
  3. Enter Material Amount: `1000`.
  4. Tap Save.
- **Expected Result**: Validation error shown — stitching amount must be greater than zero. Order is not saved.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

## Flow 3: Order Lifecycle

---

**TC-LIFECYCLE-001** — View Today's Orders List 🔴 HIGH

- **Preconditions**: At least one order created today exists in local SQLite.
- **Steps**:
  1. From Home, tap "Today's Orders" button or navigate to the Today's Orders screen.
  2. Observe the list.
- **Expected Result**: The order(s) created today appear in the list. Each row shows: customer name, order type, status badge (color-coded), stitching amount, and due date.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-LIFECYCLE-002** — Advance Order Status Step-by-Step 🔴 HIGH

- **Preconditions**: An order with status "Pending" exists. Open the Order Detail screen for it.
- **Steps**:
  1. From Today's Orders, tap the order to open Order Detail.
  2. Observe the current status badge shows "Pending".
  3. Find the status update control (dropdown or buttons). Select "Cutting".
  4. Confirm if a dialog appears.
  5. Observe the status badge updates to "Cutting".
  6. Repeat: advance to "Stitching".
  7. Repeat: advance to "Finishing".
  8. Repeat: advance to "Ready".
- **Expected Result**: Each status change is reflected immediately on screen. A sync queue entry is added for each update. The status badge color changes correctly: Pending=orange, Cutting=blue, Stitching=purple, Finishing=orange-dark, Ready=green.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-LIFECYCLE-003** — Receive Balance Payment After Order is Ready 🔴 HIGH

- **Preconditions**: An order in "Ready" status exists with a remaining balance (e.g., total=4000, advance paid=1000, balance=3000).
- **Steps**:
  1. From Home, tap "Receive Payment" action button.
  2. In the order dropdown, select the order (customer name + balance amount should be visible).
  3. Observe the balance due amount shown.
  4. Enter Amount: `3000`.
  5. Select Payment Method: `Cash`.
  6. Tap Save Payment.
- **Expected Result**: Success snackbar. The order now shows balance = 0. The payment is recorded locally and added to sync queue. The order should no longer appear in the "unpaid orders" attention list on the Home dashboard.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-LIFECYCLE-004** — Receive Payment Amount Exceeding Balance 🔴 HIGH

- **Preconditions**: An order with balance of PKR 3,000 exists. On the Receive Payment screen.
- **Steps**:
  1. Select the order.
  2. Enter Amount: `5000` (exceeds balance).
  3. Tap Save Payment.
- **Expected Result**: Error message shown: "Amount exceeds balance of PKR 3,000.00". Payment is NOT saved.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-LIFECYCLE-005** — Deliver Order and Generate Invoice 🔴 HIGH

- **Preconditions**: An order is in "Ready" status with balance fully paid (balance = 0).
- **Steps**:
  1. Open Order Detail for that order.
  2. Advance status to "Delivered".
  3. From the Order Detail screen, find and tap the "Invoice" button or navigate to the Invoice screen.
  4. Observe the invoice details.
- **Expected Result**: Order status changes to "Delivered". The Invoice screen shows: customer name, order type, total amount, all payments listed, balance remaining = PKR 0.00, date of invoice, order number.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-LIFECYCLE-006** — Contact Customer via WhatsApp from Order Detail 🟡 MEDIUM

- **Preconditions**: An order exists where the customer has a phone number. Device has WhatsApp installed.
- **Steps**:
  1. Open Order Detail for that order.
  2. Tap the WhatsApp icon/button.
- **Expected Result**: WhatsApp opens with a pre-filled chat to the customer's number (international format: 92XXXXXXXXXX). No crash occurs.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-LIFECYCLE-007** — Partial Payment Recording 🟡 MEDIUM

- **Preconditions**: An order with total=4000 and advance=1000 (balance=3000) exists.
- **Steps**:
  1. Navigate to Receive Payment.
  2. Select the order.
  3. Enter Amount: `1500` (partial, less than balance).
  4. Select Payment Method: `JazzCash`.
  5. Tap Save.
- **Expected Result**: Payment saved. Balance is now PKR 1,500.00 (3000 - 1500). The order still appears in the unpaid orders list on dashboard.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

## Flow 4: Record Business Expense

---

**TC-EXP-001** — Record Expense — Full Happy Path (All Required Fields) 🔴 HIGH

- **Preconditions**: Logged in. App is on the Home screen.
- **Steps**:
  1. Navigate to the "Add Expense" / "Record Expense" screen (from Home or menu).
  2. From the Category picker, select `Rent`.
  3. Enter Amount: `15000`.
  4. Enter Description: `Monthly shop rent — May 2026`.
  5. Tap Save / Submit.
- **Expected Result**: Expense is saved locally. A sync queue entry is created with action `create`. A success snackbar is shown. The Expenses List screen shows this expense with status "Pending" (awaiting admin approval) and amount PKR 15,000.00.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-EXP-002** — Record Expense Without Selecting Category 🔴 HIGH

- **Preconditions**: On the Add Expense screen.
- **Steps**:
  1. Leave the Category field blank / unselected.
  2. Enter Amount: `5000`.
  3. Tap Save.
- **Expected Result**: Snackbar or inline error: "Please select a category". Expense is NOT saved.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-EXP-003** — Record Expense with Zero Amount 🔴 HIGH

- **Preconditions**: On the Add Expense screen.
- **Steps**:
  1. Select Category: `Electricity Bill`.
  2. Enter Amount: `0`.
  3. Tap Save.
- **Expected Result**: Snackbar: "Please enter amount". Expense is NOT saved.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-EXP-004** — Record Expense with Receipt Photo 🟡 MEDIUM

- **Preconditions**: On the Add Expense screen. Device has a camera.
- **Steps**:
  1. Select Category: `Machine Repair`.
  2. Enter Amount: `3500`.
  3. Tap the camera/photo icon to capture a receipt photo.
  4. Take a photo using the device camera. Confirm.
  5. Tap Save.
- **Expected Result**: Photo thumbnail is displayed in the form. Expense is saved with the photo path stored locally. The sync queue entry includes the file path for upload.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-EXP-005** — Expenses List Shows Pending Status Before Admin Approval 🔴 HIGH

- **Preconditions**: At least one expense has been recorded and not yet approved.
- **Steps**:
  1. Navigate to the Expenses List screen.
  2. Observe the newly created expense entry.
- **Expected Result**: The expense shows status "Pending" (or "PendingApproval") with the correct amount and category. It is NOT shown as "Approved".
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

## Flow 5: Inventory Purchase

---

**TC-INV-001** — Add Inventory Item — Happy Path 🔴 HIGH

- **Preconditions**: Logged in. On the Home screen.
- **Steps**:
  1. Navigate to "Add Inventory" screen.
  2. Enter Item Name: `Blue Cotton Fabric`.
  3. Enter Quantity: `10`.
  4. From the Unit dropdown, select `meters`.
  5. Enter Cost per Unit: `350`.
  6. Enter Supplier: `Siddiq Fabrics, Lahore`.
  7. Notes: `For suit orders — May batch`.
  8. Tap Save.
- **Expected Result**: Inventory item saved locally. Sync queue entry created. Total cost calculated = 10 × 350 = PKR 3,500.00. Success snackbar shown.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-INV-002** — Add Inventory — Empty Item Name 🟡 MEDIUM

- **Preconditions**: On the Add Inventory screen.
- **Steps**:
  1. Leave Item Name blank.
  2. Enter Quantity: `5` and Cost: `200`.
  3. Tap Save.
- **Expected Result**: Error snackbar: "Please enter item name". Item is NOT saved.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-INV-003** — Add Inventory — Zero Quantity 🟡 MEDIUM

- **Preconditions**: On the Add Inventory screen.
- **Steps**:
  1. Enter Item Name: `Thread Rolls`.
  2. Enter Quantity: `0`.
  3. Enter Cost per Unit: `50`.
  4. Tap Save.
- **Expected Result**: Error snackbar: "Please enter quantity". Item is NOT saved.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-INV-004** — Inventory Item Appears in Inventory List 🔴 HIGH

- **Preconditions**: TC-INV-001 has been completed (Blue Cotton Fabric exists).
- **Steps**:
  1. Navigate to the Inventory List screen.
  2. Scroll through the list or search for "Blue Cotton Fabric".
- **Expected Result**: The item is visible in the list with: name "Blue Cotton Fabric", quantity 10 meters, cost per unit PKR 350.00, total PKR 3,500.00, status "Pending".
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

## Flow 6: Partner Capital Management

---

**TC-CAP-001** — View Partner Balances Screen 🔴 HIGH

- **Preconditions**: Both partners exist. At least one capital transaction recorded (TC-SETUP-007). Backend reachable.
- **Steps**:
  1. Navigate to Partner Balances screen.
  2. Wait for data to load (the screen calls `/reports/partner-balances` API).
  3. Observe the summary cards at the top.
  4. Tap a partner card to expand it.
- **Expected Result**: Screen shows: Total Capital Added, Total Funded Spendings, Remaining Balance for each partner. Summary totals match individual partner sums. No loading error.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-CAP-002** — Add Additional Capital for Partner 2 🔴 HIGH

- **Preconditions**: Partner 2 (Zara Investor) exists.
- **Steps**:
  1. Navigate to Add Capital screen.
  2. Select Partner: `Zara Investor`.
  3. Transaction Type: `AdditionalCapital`.
  4. Amount: `100000`.
  5. Date: today.
  6. Notes: `Second instalment`.
  7. Tap Save.
- **Expected Result**: Success message. Partner Balances screen for Zara Investor reflects the new total capital (existing + 100,000).
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-CAP-003** — Record a Withdrawal Transaction 🟡 MEDIUM

- **Preconditions**: A partner with positive remaining balance exists.
- **Steps**:
  1. Navigate to Add Capital screen.
  2. Select the partner.
  3. Transaction Type: `Withdrawal`.
  4. Amount: `10000`.
  5. Tap Save.
- **Expected Result**: Transaction saved. Partner Balances shows reduced remaining balance by PKR 10,000.00.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-CAP-004** — Partner Balances Screen When Offline 🟡 MEDIUM

- **Preconditions**: Device is connected. Partner Balances was loaded previously (cached or local).
- **Steps**:
  1. Turn off WiFi and mobile data on the device.
  2. Navigate to Partner Balances screen.
- **Expected Result**: Either: (a) previously cached data is shown with a "No connection" banner, OR (b) an error message is displayed ("Could not load balances — no internet connection"). The app does NOT crash.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

## Flow 7: Asset Purchase

---

**TC-ASSET-001** — Add a Business Asset — Happy Path 🔴 HIGH

- **Preconditions**: Logged in. On Home screen.
- **Steps**:
  1. Navigate to Add Asset screen.
  2. From the Asset Type picker, select `Sewing Machine`.
  3. Enter Name: `Singer Industrial M`.
  4. Enter Quantity: `1`.
  5. Enter Unit Value: `45000`.
  6. Owner: `Business` (default).
  7. Notes: `Purchased from Al-Rehman Machines`.
  8. Tap Save.
- **Expected Result**: Asset saved locally. Sync queue entry added. Success snackbar shown. Total Value = 1 × 45,000 = PKR 45,000.00.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-ASSET-002** — Add Asset Without Selecting Type 🟡 MEDIUM

- **Preconditions**: On the Add Asset screen.
- **Steps**:
  1. Leave Asset Type unselected.
  2. Enter Name: `Some Machine`.
  3. Enter Unit Value: `10000`.
  4. Tap Save.
- **Expected Result**: Error snackbar: "Please select asset type". Asset is NOT saved.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-ASSET-003** — Add Asset with Zero Unit Value 🟡 MEDIUM

- **Preconditions**: On the Add Asset screen.
- **Steps**:
  1. Select Asset Type: `Iron / Press`.
  2. Enter Name: `Steam Iron`.
  3. Enter Unit Value: `0`.
  4. Tap Save.
- **Expected Result**: Error snackbar: "Please enter unit value". Asset is NOT saved.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-ASSET-004** — Asset Appears in Assets List 🔴 HIGH

- **Preconditions**: TC-ASSET-001 has been completed.
- **Steps**:
  1. Navigate to Assets List screen.
  2. Look for "Singer Industrial M" in the list.
- **Expected Result**: The asset is visible with: name, type "Sewing Machine", quantity 1, unit value PKR 45,000.00, total value PKR 45,000.00, owner "Business", status "Pending".
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-ASSET-005** — Add Asset with Multiple Quantity 🟡 MEDIUM

- **Preconditions**: On the Add Asset screen.
- **Steps**:
  1. Select Asset Type: `Furniture`.
  2. Enter Name: `Wooden Chair`.
  3. Enter Quantity: `4`.
  4. Enter Unit Value: `3500`.
  5. Tap Save.
- **Expected Result**: Asset saved. Total Value = 4 × 3,500 = PKR 14,000.00. The Home dashboard total asset value increases by PKR 14,000.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

## Flow 8: Offline → Sync Flow

---

**TC-SYNC-001** — Create Order While Offline 🔴 HIGH

- **Preconditions**: App is loaded and previously connected. At least one customer exists in local SQLite.
- **Steps**:
  1. Turn off WiFi and mobile data on the device.
  2. From Home, tap "New Order".
  3. Select existing customer (from local SQLite list).
  4. Select Order Type: `Trouser`.
  5. Skip photo. Enter measurements.
  6. Enter Stitching: `800`, Material: `400`, Advance: `300`. Due in 5 days.
  7. Tap Save.
- **Expected Result**: Order is saved to local SQLite with a local-only ID. A sync queue entry with status "Pending" is added. A success snackbar appears. No network error is shown. The order appears in Today's Orders immediately.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-SYNC-002** — Record Payment While Offline 🔴 HIGH

- **Preconditions**: Offline. An order with balance exists in local SQLite.
- **Steps**:
  1. Keeping WiFi off, navigate to Receive Payment.
  2. Select the order (locally available).
  3. Enter the balance amount.
  4. Select method: `Cash`.
  5. Tap Save.
- **Expected Result**: Payment saved locally. Sync queue gains a new "Pending" entry for the payment. No crash or network error shown.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-SYNC-003** — Manual Sync Trigger After Reconnect 🔴 HIGH

- **Preconditions**: TC-SYNC-001 and TC-SYNC-002 completed. Multiple pending sync items exist in queue.
- **Steps**:
  1. Turn WiFi back on.
  2. Navigate to the Sync Status screen (from Home or menu).
  3. Observe the list of sync queue items — they should show as "Pending".
  4. Tap the "Sync Now" / retry button.
  5. Wait for sync to complete (observe progress).
- **Expected Result**: The pending items are processed. Their status changes to "Completed" (or they disappear from the list after clearing completed). The sync counter badge on the Home screen resets to 0. Data is now available on the server (verifiable via web admin or Swagger).
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-SYNC-004** — Sync Status Screen Shows Queue Items Correctly 🟡 MEDIUM

- **Preconditions**: At least one pending sync item exists.
- **Steps**:
  1. Navigate to Sync Status screen.
  2. Observe the list without triggering sync.
- **Expected Result**: Each sync item shows: entity type (order/expense/asset/etc.), action (create/update), status (Pending/Failed/Completed), and timestamp. The total count matches the badge shown on Home.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-SYNC-005** — Clear Completed Sync Items 🟡 MEDIUM

- **Preconditions**: At least some sync items have status "completed" after a successful sync.
- **Steps**:
  1. Navigate to Sync Status screen.
  2. Tap the "Clear Completed" icon button (broom/sweep icon in the app bar).
  3. Observe the list.
- **Expected Result**: Only completed items are removed from the list. Pending or failed items remain. The list refreshes automatically.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-SYNC-006** — Clear All Sync Items Shows Confirmation Dialog 🟡 MEDIUM

- **Preconditions**: On the Sync Status screen with items present.
- **Steps**:
  1. Tap the "Clear All" / trash icon (delete_forever) button.
  2. A confirmation dialog appears — "Remove all sync queue items including failed ones?"
  3. Tap "Cancel".
  4. Observe the list — items should still be present.
  5. Tap "Clear All" again. This time tap "Clear All" in the dialog.
- **Expected Result**: After Cancel: no items removed. After confirming: all items removed from the list and the sync badge counter resets.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-SYNC-007** — Sync Fails When Server Unreachable 🟡 MEDIUM

- **Preconditions**: WiFi is on but the server at `10.255.254.48:5000` is down or unreachable.
- **Steps**:
  1. Create a new expense while server is unreachable.
  2. Navigate to Sync Status screen.
  3. Tap "Sync Now".
  4. Wait for the sync attempt to complete (up to 30 seconds per the API timeout).
- **Expected Result**: After the timeout, the sync queue item status changes to "Failed". An error message or snackbar is shown ("Sync failed — server unreachable" or similar). The app does NOT crash. The failed item remains in the queue for retry.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

## Flow 9: Financial Dashboard Review

---

**TC-DASH-001** — Home Dashboard Loads All Financial Data 🔴 HIGH

- **Preconditions**: Multiple orders (with various statuses), payments, and expenses exist in local SQLite.
- **Steps**:
  1. Navigate to the Home screen.
  2. Wait for the loading indicator to disappear.
  3. Observe all sections: Quick Stats, Delivery Status, Attention Items, Financials, Inventory & Assets, and Partner Balances.
- **Expected Result**: All sections are populated with data. No section shows zeros when actual data exists. The screen renders without overflow or layout errors.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-DASH-002** — Collection Rate Calculation 🔴 HIGH

- **Preconditions**: Known test data exists. Example: 2 orders totalling PKR 6,000 (revenue), PKR 4,000 collected in payments.
- **Steps**:
  1. Ensure the specific orders and payments are in local SQLite.
  2. Navigate to Home screen and wait for load.
  3. Find the "Collection Rate" value in the Financials section.
- **Expected Result**: Collection Rate = (4000 / 6000) × 100 = 66.67%. Verify the displayed percentage matches this calculation within reasonable rounding.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-DASH-003** — Delivery Status — Overdue Orders 🔴 HIGH

- **Preconditions**: An active order (status not Delivered or Cancelled) has a due date in the past (overdue). This can be set by creating an order with a due date in the past while offline.
- **Steps**:
  1. Ensure at least one active order has a due date before today.
  2. Navigate to Home screen.
  3. Check the Delivery Status section.
- **Expected Result**: The "Overdue" counter in the Delivery section shows a count of at least 1. The badge/indicator uses the error/red color to flag urgency.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-DASH-004** — Delivery Status — Due Soon (Within 7 Days) 🟡 MEDIUM

- **Preconditions**: An active order has a due date between today and 7 days from now.
- **Steps**:
  1. Create an order with due date = 3 days from today.
  2. Return to Home screen and refresh.
  3. Check the Delivery Status section — "Due Soon" count.
- **Expected Result**: "Due Soon" counter increments by 1. The indicator uses the warning/orange color.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-DASH-005** — Attention Items — Pending Expenses Shown 🟡 MEDIUM

- **Preconditions**: At least one expense with status "Pending" exists locally.
- **Steps**:
  1. Navigate to Home screen.
  2. Find the "Attention Required" / pending items section.
  3. Check the pending expenses count.
- **Expected Result**: The pending expense count is at least 1. Tapping the item (if tappable) navigates to the Expenses List screen.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-DASH-006** — Estimated Profit Calculation 🔴 HIGH

- **Preconditions**: Known test data with: revenue = PKR 10,000, expenses = PKR 2,000, no inventory cost.  
  Formula: `Net Profit = Revenue − Labour − Inventory Cost − Expenses`  
  Labour = Revenue × LabourSharePct (35%) = PKR 3,500. Net Profit = 10,000 − 3,500 − 0 − 2,000 = PKR 4,500.
- **Steps**:
  1. Ensure the above data exists.
  2. Navigate to Home screen.
  3. Locate "Estimated Profit" in the Financials section.
- **Expected Result**: Estimated Profit displayed is approximately PKR 4,500.00. Verify the value is not negative and reflects the correct deductions.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-DASH-007** — Dashboard With Zero Data (Fresh Install) 🟡 MEDIUM

- **Preconditions**: App is freshly installed or database has been cleared. No orders, payments, or expenses exist.
- **Steps**:
  1. Log in as Admin.
  2. Navigate to Home Dashboard.
  3. Observe all sections.
- **Expected Result**: All counters show 0. Collection rate shows 0% or "N/A". No division-by-zero crash. The screen renders cleanly without broken layout.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

## Flow 10: Admin Approvals (via Backend / Web Admin)

> **Note**: The mobile app currently shows approval status (Pending/Approved/Rejected) but the Admin approval action is performed via the Web Admin at `http://localhost:3000` or directly via the API. The following tests verify that the mobile app correctly reflects approval status changes after sync.

---

**TC-APPR-001** — Expense Approval Reflected After Sync 🔴 HIGH

- **Preconditions**: An expense has been created on the mobile app and synced to the server (status = PendingApproval on server). An Admin is available to approve via Web Admin or API.
- **Steps**:
  1. On the Web Admin (or via Swagger at `http://10.255.254.48:5000/swagger`), approve the pending expense using the admin account.
  2. On the mobile device, navigate to Sync Status screen.
  3. Tap "Sync Now" to pull latest data.
  4. Navigate to Expenses List screen.
  5. Find the approved expense.
- **Expected Result**: After sync, the expense status changes from "Pending" to "Approved". The status badge color updates accordingly (green).
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-APPR-002** — Expense Rejection Reflected After Sync 🔴 HIGH

- **Preconditions**: Same as TC-APPR-001, but the Admin rejects the expense instead.
- **Steps**:
  1. Via Web Admin or Swagger, reject a pending expense.
  2. On mobile, trigger a sync.
  3. Navigate to Expenses List screen.
- **Expected Result**: The expense status shows "Rejected". The status badge uses red/error color. The expense amount is NOT counted in the dashboard's expense totals (since it is rejected).
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-APPR-003** — Inventory Transaction Approval Reflected After Sync 🟡 MEDIUM

- **Preconditions**: An inventory item was added via mobile and synced (status = PendingApproval on server). Admin approves it.
- **Steps**:
  1. Via Web Admin/Swagger, approve the pending inventory transaction.
  2. On mobile, trigger sync.
  3. Navigate to Inventory List screen.
- **Expected Result**: The inventory item status changes from "Pending" to "Approved". The item's value is now counted in the dashboard's Inventory Value total.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-APPR-004** — Asset Approval Reflected After Sync 🟡 MEDIUM

- **Preconditions**: An asset was added via mobile and synced. Admin approves it.
- **Steps**:
  1. Via Web Admin/Swagger, approve the pending asset.
  2. On mobile, trigger sync.
  3. Navigate to Assets List screen.
- **Expected Result**: Asset status changes from "Pending" to "Approved". The Home dashboard Total Asset Value now includes this asset.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

## Additional Edge Cases

---

**TC-EDGE-001** — JWT Token Expiry (24-Hour Limit) 🔴 HIGH

- **Preconditions**: The app was last logged in more than 24 hours ago (or simulate by manipulating the stored token to be expired).
- **Steps**:
  1. Without logging in again, open the app.
  2. Attempt any action that requires API access (e.g., Partner Balances, Add Capital, Sync).
- **Expected Result**: The app detects the expired token. Either: (a) navigates automatically to the Login screen with a message ("Session expired, please log in again"), OR (b) shows an error "Unauthorized" and prompts re-login. The app does NOT crash.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-EDGE-002** — Very Long Customer Name Entry 🟡 MEDIUM

- **Preconditions**: On New Order screen, Step 1, adding a new customer.
- **Steps**:
  1. Enter a name that is exactly 100 characters long (e.g., `Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`).
  2. Enter a valid phone number.
  3. Proceed through all steps and save the order.
- **Expected Result**: The app accepts the name without truncation or crash. The name is stored and displayed (possibly truncated in the UI with ellipsis for display purposes).
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-EDGE-003** — Decimal Amount Precision in Payments 🔴 HIGH

- **Preconditions**: On Receive Payment screen with an order that has a balance.
- **Steps**:
  1. Enter Amount: `1500.75`.
  2. Select Payment Method: `Bank Transfer`.
  3. Tap Save.
- **Expected Result**: Payment saved with the exact amount PKR 1,500.75 (2 decimal places). The balance is deducted correctly. No rounding error. The amount displays as "1,500.75" not "1500.7" or "1501".
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-EDGE-004** — Inventory with Decimal Quantity Unit Cost 🟡 MEDIUM

- **Preconditions**: On Add Inventory screen.
- **Steps**:
  1. Item Name: `Silk Thread`.
  2. Quantity: `25`.
  3. Unit: `pieces`.
  4. Cost per Unit: `12.50`.
  5. Tap Save.
- **Expected Result**: Total cost = 25 × 12.50 = PKR 312.50. Displayed correctly with 2 decimal places in the Inventory List.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-EDGE-005** — Add Partner — Profit Share Percentages Exceeding 100% 🔴 HIGH

- **Preconditions**: On the Add Partner screen (or system already has a partner with 50% profit share).  
  **Business Rule**: The sum of all partners' profit share percentages should not exceed 100%.
- **Steps**:
  1. Attempt to add a new partner with Profit Share: `70`.
  2. If a partner with 50% already exists, the combined would be 120%.
  3. Tap Save / Submit.
- **Expected Result**: Ideally, the server returns an error preventing total profit share from exceeding 100%. The app displays the error. If validation is only on the server, a clear error message is shown from the API response.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-EDGE-006** — Payments List Shows All Payment Methods 🟡 MEDIUM

- **Preconditions**: Payments have been recorded using different methods: Cash, JazzCash, EasyPaisa, Bank Transfer.
- **Steps**:
  1. Navigate to Payments List screen.
  2. Scroll through the list.
- **Expected Result**: Each payment entry shows its payment method correctly. Payment method labels match exactly: "Cash", "JazzCash", "EasyPaisa", "Bank Transfer". No method shows as blank or "Unknown".
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-EDGE-007** — App Handles No Internet on Startup 🔴 HIGH

- **Preconditions**: Device has no internet connection. App is installed with existing local SQLite data.
- **Steps**:
  1. Turn off WiFi and mobile data.
  2. Open the app from scratch (cold start).
  3. Observe splash screen and login behavior.
- **Expected Result**: If already logged in (token stored locally): the app proceeds to Home dashboard showing locally cached data. If not logged in: the login screen is shown. The app does NOT show a "no internet" crash on startup — it degrades gracefully.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-EDGE-008** — Order with No Due Date 🟡 MEDIUM

- **Preconditions**: On New Order screen, Step 5.
- **Steps**:
  1. Complete all required fields (customer, order type, amounts).
  2. Clear or remove the due date if the UI allows it (set to null/empty).
  3. Tap Save.
- **Expected Result**: Order is saved without a due date. In the Home dashboard delivery section, this order is counted in the "On Track" bucket (as per the `onTrack++` logic for null due dates). No crash.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-EDGE-009** — Settings Screen Loads Without Crash 🟡 MEDIUM

- **Preconditions**: Logged in.
- **Steps**:
  1. Navigate to Settings screen (via drawer or Home menu).
  2. Observe all settings options.
- **Expected Result**: Settings screen loads without crash or blank white screen. Basic settings (server URL, logout option) are visible and functional.
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

**TC-EDGE-010** — Logout and Re-Login 🔴 HIGH

- **Preconditions**: Logged in as Admin.
- **Steps**:
  1. Navigate to Settings.
  2. Tap Logout.
  3. Confirm logout if a dialog appears.
  4. Observe navigation to Login screen.
  5. Log in again with admin credentials.
- **Expected Result**: Logout clears the JWT token from local storage. App navigates to Login. Re-login succeeds and returns to Home. The Home dashboard data persists (SQLite not wiped on logout).
- **Actual Result**: _______________
- **Status**: [ ] Pass  [ ] Fail  [ ] Blocked

---

## Test Execution Summary

| Flow | Total TCs | Pass | Fail | Blocked | Skipped |
|------|-----------|------|------|---------|---------|
| Flow 1: First-Time Setup | 8 | | | | |
| Flow 2: New Order | 5 | | | | |
| Flow 3: Order Lifecycle | 7 | | | | |
| Flow 4: Record Expense | 5 | | | | |
| Flow 5: Inventory | 4 | | | | |
| Flow 6: Partner Capital | 4 | | | | |
| Flow 7: Asset Purchase | 5 | | | | |
| Flow 8: Offline Sync | 7 | | | | |
| Flow 9: Financial Dashboard | 7 | | | | |
| Flow 10: Admin Approvals | 4 | | | | |
| Edge Cases | 10 | | | | |
| **TOTAL** | **66** | | | | |

---

## Defect Log

| Defect ID | TC Ref | Title | Steps to Reproduce | Expected | Actual | Severity | Component |
|-----------|--------|-------|--------------------|----------|--------|----------|-----------|
| DEF-001 | | | | | | | |
| DEF-002 | | | | | | | |

**Severity Guide**: Critical (app crash / data loss) | High (key feature broken) | Medium (incorrect behaviour, workaround exists) | Low (cosmetic)

---

## Test Environment Notes

- **Backend URL**: `http://10.255.254.48:5000/api` (configured in `mobile/lib/utils/constants.dart` → `ApiConfig.baseUrl`)
- **Swagger**: `http://10.255.254.48:5000/swagger`
- **JWT Expiry**: 24 hours (token), 7 days (refresh token)
- **Seeded Users**: Created by `backend/src/TailorShop.Infrastructure/Data/DbSeeder.cs`
- **Local DB**: SQLite via `mobile/lib/services/database_service.dart`
- **Sync Queue**: Managed by `mobile/lib/services/sync_service.dart`
- **Profit Formula**: `Net Profit = Revenue − (Revenue × LabourSharePct%) − Inventory Cost − Expenses`
- **Default Shares**: Labour = 35%, Profit = 50% per partner
