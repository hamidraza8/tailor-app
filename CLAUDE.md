# TailorShop MVP — Claude Code Guide

## Project Overview

Full-stack business management system for a ladies custom tailoring shop in Pakistan.
- **Budget target**: ~$5/month VPS hosting
- **Team size**: ~5 people
- **Architecture**: Mobile-first, offline-capable, with approval workflows

## Components

| Component | Tech | Dev Port |
|-----------|------|----------|
| Backend API | .NET 8, PostgreSQL 16, EF Core | http://localhost:5000 |
| Web Admin | Vue 3, Vuetify 3, Vite, Pinia | http://localhost:3000 |
| Mobile | Flutter 3.x, SQLite (offline-first) | — |

## Running Locally

### Backend
```bash
# Spin up PostgreSQL
docker run -d --name tailorshop-db -p 5432:5432 \
  -e POSTGRES_DB=tailorshop -e POSTGRES_PASSWORD=postgres \
  postgres:16-alpine

cd backend/src/TailorShop.Api
dotnet run
# Swagger: http://localhost:5000/swagger
# Migrations run automatically on startup
# DbSeeder creates admin + partner test users
```

### Web Admin
```bash
cd web-admin
npm install
npm run dev   # http://localhost:3000 — proxies /api → http://localhost:5000
```

### Mobile
```bash
cd mobile
flutter pub get
flutter run
```

### Full Stack (Docker Compose)
```bash
cd deployment
cp .env.example .env   # fill in JWT_SECRET, POSTGRES_PASSWORD, etc.
docker compose up -d --build
```

## Testing
```bash
# Backend unit/integration tests (xUnit, InMemory DB)
cd backend && dotnet test

# E2E smoke tests
bash tests/e2e_test.sh
```

## Project Structure
```
backend/
  src/
    TailorShop.Api/           # Controllers, middleware, Program.cs
    TailorShop.Application/   # Services, DTOs, validators, mappings
    TailorShop.Domain/        # Entities, enums, interfaces (no deps)
    TailorShop.Infrastructure/# EF Core, migrations, file storage, OCR
  tests/TailorShop.Tests/
web-admin/src/
  views/                      # Page components
  stores/                     # Pinia stores
  services/                   # Axios API clients
mobile/lib/
  screens/                    # 20+ Flutter screens
  services/                   # API, SQLite, sync
  providers/app_provider.dart # Main Provider state
deployment/                   # Docker Compose, nginx, .env.example
docs/                         # Architecture, DB schema, API, UX docs
```

## Key Architecture Patterns

### Clean Architecture (Backend)
`Api` → `Application` → `Domain` ← `Infrastructure`

### Authentication
- JWT Bearer (24h), refresh tokens (7d)
- BCrypt password hashing
- Roles: `Admin`, `Partner`, `Staff`
- `ClaimsPrincipalExtensions.GetUserId()` used in controllers

### Database
- Global soft-delete query filter (`IsDeleted = false`)
- Optimistic concurrency via `RowVersion`
- Decimal(18,2) for all financial fields
- Unique indexes: Email, OrderNumber, InvoiceNumber

### Approval Workflows
Assets, InventoryTransactions, and Expenses require admin approval:
`PendingApproval` → `Approved` | `Rejected`

### Offline Sync (Mobile)
- SQLite mirrors server schema
- `SyncQueue` tracks pending ops
- Pushed to backend on reconnect; server IDs synced back

### File Storage
- Abstracted via `IFileStorageService`
- Default: `LocalFileStorageService` → `/app/uploads/{category}/{entityId}/`
- Designed for future cloud migration (R2)

### Profit Calculation
```
Labour Cost       = Σ(StitchingAmount × LabourSharePct)  [default 35%]
Net Profit        = Revenue − Labour − Inventory Cost − Expenses
Partner Profit    = Net Profit × ProfitSharePct           [default 50%]
```

## Environment Variables (see deployment/.env.example)
- `ConnectionStrings__DefaultConnection` — PostgreSQL DSN
- `JwtSettings__Secret` — JWT signing key
- `JwtSettings__Issuer` / `Audience`
- `FileStorage__BasePath` — upload directory

## Seeded Test Users (development only)
Created by `DbSeeder` on first run — check the seeder for credentials.
