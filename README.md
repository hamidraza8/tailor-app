# TailorShop MVP - Ladies Custom Tailoring & Garments

Complete business management system for a ladies custom tailoring shop in Pakistan.

## Components

| Component | Tech Stack | Purpose |
|-----------|-----------|---------|
| Backend API | .NET 8, PostgreSQL, EF Core | REST API, business logic, PDF generation |
| Mobile App | Flutter, SQLite | Offline-first app for tailor/partner |
| Web Admin | Vue 3, Vuetify, Pinia | Dashboard, approvals, reports for admin |
| Deployment | Docker Compose, Nginx | Single VPS hosting (~$5/mo) |

## Quick Start

### Prerequisites
- .NET 8 SDK
- Node.js 18+
- Flutter 3.x
- PostgreSQL (or use Docker)
- Docker & Docker Compose (for deployment)

### Backend

```bash
cd backend

# Start PostgreSQL (Docker)
docker run -d --name tailorshop-db -p 5432:5432 \
  -e POSTGRES_DB=tailorshop -e POSTGRES_PASSWORD=postgres \
  postgres:16-alpine

# Run API
cd src/TailorShop.Api
dotnet run
# API: http://localhost:5000
# Swagger: http://localhost:5000/swagger
```

### Web Admin

```bash
cd web-admin
npm install
npm run dev
# Admin: http://localhost:3001
```

### Mobile App

```bash
cd mobile
flutter pub get
flutter run
```

### Run Tests

```bash
cd backend
dotnet test
```

## Test Credentials

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@tailorshop.com | Admin@123 |
| Partner | partner@tailorshop.com | Partner@123 |

## Deployment

See [deployment/deploy-guide.md](deployment/deploy-guide.md) for full VPS deployment instructions.

```bash
cd deployment
cp .env.example .env
# Edit .env with your settings
docker compose up -d --build
```

## Documentation

- [Architecture](docs/architecture.md)
- [Database Schema](docs/database.md)
- [API Reference](docs/api.md)
- [Mobile UX Design](docs/mobile-ux.md)
- [Hosting Guide](docs/hosting-low-cost-guide.md)
- [Testing Guide](docs/testing-guide.md)

## Monthly Cost

| Service | Cost |
|---------|------|
| VPS (Hetzner CX21) | ~$5/mo |
| Email (Brevo free) | Free |
| SSL (Let's Encrypt) | Free |
| Storage (local disk) | Free |
| **Total** | **~$5/month** |
