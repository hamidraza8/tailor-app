# Testing Guide

## Backend Tests

### Run All Tests
```bash
cd backend
dotnet test
```

### Unit Tests (Business Calculations)
Located in `tests/TailorShop.Tests/Unit/BusinessCalculationsTests.cs`

Tests cover:
- Asset total value = quantity × unit value
- Inventory total cost = stock × unit cost
- Order total = stitching + material - discount
- Order balance = total - paid
- Labour = stitching × labour percentage (NOT material)
- Net profit = revenue - labour - inventory cost - expenses
- Partner profit split = net profit × share %
- Invoice balance = total - paid

### Running Specific Tests
```bash
dotnet test --filter "FullyQualifiedName~BusinessCalculationsTests"
```

## Manual API Testing

### Using Swagger
1. Start backend: `cd backend/src/TailorShop.Api && dotnet run`
2. Open: http://localhost:5000/swagger
3. Login via POST /api/auth/login
4. Copy token, click "Authorize" button, enter: `Bearer <token>`
5. Test endpoints

### Using curl

```bash
# Login
TOKEN=$(curl -s http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@tailorshop.com","password":"Admin@123"}' \
  | jq -r '.token')

# Dashboard
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:5000/api/reports/dashboard

# Create customer
curl -X POST http://localhost:5000/api/customers \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Customer","phone":"03001111111"}'

# Create order
curl -X POST http://localhost:5000/api/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"customerId":"<id>","orderType":0,"stitchingAmount":3000,"materialAmount":2000,"discount":0}'
```

## Mobile App Testing

### Run on Emulator
```bash
cd mobile
flutter run
```

### Offline Testing
1. Create orders/assets/expenses while in airplane mode
2. Check sync queue shows pending items
3. Turn on internet
4. Verify items sync to server

### Key Flows to Test
1. Create customer → Create order → Receive payment → Generate invoice
2. Add asset with photo → Check pending in admin → Approve
3. Add inventory with receipt → Check pending → Approve
4. Add expense → Check pending → Approve
5. Check profit report matches calculations
