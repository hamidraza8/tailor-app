# Architecture

## Overview

TailorShop is a monorepo containing three applications:

```
┌─────────────────────────────────────────┐
│              Mobile App (Flutter)        │
│  Offline-first, SQLite, Sync Queue      │
│  Used by: Tailor / Partner / Staff      │
└──────────────────┬──────────────────────┘
                   │ REST API + JWT
┌──────────────────▼──────────────────────┐
│          Backend API (.NET 8)            │
│  Clean Architecture, EF Core, PostgreSQL│
│  Hosted on: VPS with Docker             │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│         Web Admin (Vue 3 + Vuetify)     │
│  Dashboard, Approvals, Reports          │
│  Used by: Admin / Investor              │
└─────────────────────────────────────────┘
```

## Backend Architecture (Clean Architecture)

```
TailorShop.Api          → Controllers, Middleware, DI config
TailorShop.Application  → Services, DTOs, Business Logic
TailorShop.Domain       → Entities, Enums, Interfaces
TailorShop.Infrastructure → EF Core, Database, Storage
```

## Key Design Decisions

1. **Offline-First Mobile**: All operations save locally first, then sync
2. **Approval Workflow**: Assets, inventory purchases, expenses require admin approval
3. **Labour on Stitching Only**: Labour share calculated only on stitching amount, not fabric/material
4. **Soft Delete**: All entities use IsDeleted flag, never hard deleted
5. **Audit Trail**: Every create/update/delete/approve/reject logged
6. **Local File Storage**: Files stored on disk, abstracted via IFileStorageService for future R2 migration
7. **JWT Auth**: Stateless authentication with refresh tokens

## Data Flow

### Order Creation (Mobile)
1. User creates order on mobile (offline-capable)
2. Saved to local SQLite
3. Added to sync queue
4. When online: pushed to backend API
5. Backend saves to PostgreSQL
6. Next pull syncs server ID back to mobile

### Approval Flow
1. Partner creates asset/inventory/expense on mobile → PendingApproval
2. Synced to backend
3. Admin sees in web dashboard "Pending Approvals"
4. Admin approves/rejects with comment
5. Mobile pulls updated status on next sync

### Profit Calculation
```
Revenue (sum of all order totals)
- Labour (stitching amount × labour %)
- Inventory Cost (order inventory usage)
- Approved Expenses
= Net Profit
× Partner Share % = Partner Profit
```
