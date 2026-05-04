# Mobile App UX Design

## Design Principles

1. **Photo → Select → Save** - minimize typing
2. **Big Buttons** - at least 100px tall, with icons
3. **Smart Defaults** - dropdowns over typing
4. **Offline-First** - never block work due to internet
5. **Simple like WhatsApp** - not like accounting software

## Home Screen

Six large action buttons in a 2x3 grid:

| Button | Icon | Color | Action |
|--------|------|-------|--------|
| New Order نیا آرڈر | ✂️ scissors | Green | Create order flow |
| Today's Orders آج کے آرڈر | 📋 list | Blue | Today's order cards |
| Receive Payment ادائیگی | 💰 money | Orange | Payment screen |
| Add Inventory سامان | 📦 box | Purple | Add inventory flow |
| Add Asset اثاثہ | 🔧 device | Teal | Add asset flow |
| Add Expense خرچہ | 🧾 receipt | Red | Add expense flow |

Bottom: Sync status bar ("All synced ✓" / "3 items pending")

## Flow: New Order

```
Step 1: Select Customer
  → Search existing (by name/phone)
  → OR tap "Add New" → Name + Phone only
  
Step 2: Select Order Type
  → Big icon buttons: Suit, Kurti, Trouser, Frock, Abaya, Alteration
  
Step 3: Design Photo (optional)
  → Camera button → Take photo → Preview → Confirm
  
Step 4: Measurements
  → Select existing measurement set (dropdown)
  → OR enter new (common fields with numeric inputs)
  
Step 5: Amounts
  → Stitching amount (number pad)
  → Material amount (number pad)
  → Discount (optional)
  → Due date (date picker)
  
Step 6: Advance Payment (optional)
  → Amount + Payment method dropdown
  
Step 7: Save → Success animation → Order card shown
```

## Flow: Add Asset

```
Step 1: Take Photo → Camera opens
Step 2: Select Type → Dropdown: Sewing Machine, Iron, Table, Scissors, etc.
Step 3: Enter Quantity → Number pad
Step 4: Enter Unit Value → Number pad (Rs)
Step 5: Select Owner → You / Partner / Company
Step 6: Receipt Photo (optional) → Camera
Step 7: Save → "Saved! Pending Admin Approval" message
```

## Flow: Add Inventory

```
Step 1: Take Receipt Photo → Camera opens
Step 2: OCR Draft (future) → Shows extracted data for correction
Step 3: Enter Item Name → Text or dropdown of recent items
Step 4: Enter Quantity → Number pad
Step 5: Enter Unit Cost → Number pad (Rs)
Step 6: Item Photo (optional) → Camera
Step 7: Save → "Saved! Pending Admin Approval" message
```

## Today's Orders Cards

Each card shows:
- Customer name (large)
- Order type badge (Suit, Kurti, etc.)
- Due date
- Status badge (color-coded)
- Balance amount
- Quick action buttons:
  - 📞 Call (opens dialer)
  - 💬 WhatsApp (opens chat)
  - ✅ Mark Ready
  - 💰 Receive Payment
  - 🖨️ Print Bill

## Sync Status

Bottom bar with three states:
- 🟢 "All synced" - green
- 🟡 "3 items pending sync" - yellow, tap to see queue
- 🔴 "Sync failed - tap to retry" - red

## Colors

- Primary: Teal (#00897B)
- Accent: Pink (#E91E63)
- Success: Green (#4CAF50)
- Warning: Amber (#FFC107)
- Error: Red (#F44336)
- Background: White
- Cards: Light grey (#F5F5F5)
