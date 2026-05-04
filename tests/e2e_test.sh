#!/bin/bash
###############################################################################
# TailorShop E2E Business Test Suite
# Tests all API endpoints that the mobile & web apps use
# Verifies data persistence, business rules, and calculations
###############################################################################

BASE_URL="http://localhost:5050/api"
PASS=0
FAIL=0
TOTAL=0
FAILURES=""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

assert_eq() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  TOTAL=$((TOTAL + 1))
  # Compare with numeric normalization (35.0 == 35, 50.00 == 50)
  local match=$(python3 -c "
e, a = '$expected', '$actual'
try:
    if float(e) == float(a): print('1')
    else: print('0')
except:
    print('1' if e == a else '0')
" 2>/dev/null)
  if [ "$match" = "1" ]; then
    echo -e "  ${GREEN}PASS${NC} $test_name"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} $test_name (expected='$expected' actual='$actual')"
    FAIL=$((FAIL + 1))
    FAILURES="$FAILURES\n  FAIL: $test_name (expected='$expected' actual='$actual')"
  fi
}

assert_not_empty() {
  local test_name="$1"
  local actual="$2"
  TOTAL=$((TOTAL + 1))
  if [ -n "$actual" ] && [ "$actual" != "null" ] && [ "$actual" != "" ]; then
    echo -e "  ${GREEN}PASS${NC} $test_name"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} $test_name (was empty/null)"
    FAIL=$((FAIL + 1))
    FAILURES="$FAILURES\n  FAIL: $test_name (was empty/null)"
  fi
}

assert_gt() {
  local test_name="$1"
  local value="$2"
  local threshold="$3"
  TOTAL=$((TOTAL + 1))
  local result=$(python3 -c "print(1 if float('${value:-0}') > float('${threshold:-0}') else 0)" 2>/dev/null)
  if [ "$result" = "1" ]; then
    echo -e "  ${GREEN}PASS${NC} $test_name ($value > $threshold)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} $test_name ($value not > $threshold)"
    FAIL=$((FAIL + 1))
    FAILURES="$FAILURES\n  FAIL: $test_name ($value not > $threshold)"
  fi
}

assert_http() {
  local test_name="$1"
  local expected_code="$2"
  local actual_code="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$expected_code" = "$actual_code" ]; then
    echo -e "  ${GREEN}PASS${NC} $test_name (HTTP $actual_code)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} $test_name (expected HTTP $expected_code, got $actual_code)"
    FAIL=$((FAIL + 1))
    FAILURES="$FAILURES\n  FAIL: $test_name (expected HTTP $expected_code, got $actual_code)"
  fi
}

# Helper: extract JSON field using python
jq_field() {
  local json_data="$1"
  local path="$2"
  echo "$json_data" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    path = '$path'
    if path:
        for k in path.split('.'):
            if isinstance(data, list):
                data = data[int(k)]
            elif isinstance(data, dict):
                data = data.get(k)
            else:
                data = None
                break
    if data is None:
        print('')
    elif isinstance(data, bool):
        print(str(data))
    elif isinstance(data, float):
        if data == int(data):
            print(int(data))
        else:
            print(data)
    else:
        print(data)
except Exception as e:
    print('')
" 2>/dev/null
}

jq_len() {
  local json_data="$1"
  local path="$2"
  echo "$json_data" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    path = '$path'
    if path:
        for k in path.split('.'):
            if isinstance(data, list):
                data = data[int(k)]
            elif isinstance(data, dict):
                data = data.get(k)
            else:
                data = None
                break
    print(len(data) if isinstance(data, (list, dict)) else 0)
except:
    print(0)
" 2>/dev/null
}

http_code() {
  curl -s -o /dev/null -w "%{http_code}" "$@"
}

echo ""
echo "======================================================================"
echo "  TailorShop E2E Business Test Suite"
echo "======================================================================"
echo ""

###############################################################################
echo -e "${YELLOW}[1/14] AUTHENTICATION${NC}"
###############################################################################

# TC-1.1: Login with valid admin credentials
RESP=$(curl -s "$BASE_URL/auth/login" -H "Content-Type: application/json" \
  -d '{"email":"admin@tailorshop.com","password":"Admin@123"}')
ADMIN_TOKEN=$(jq_field "$RESP" "token")
assert_not_empty "TC-1.1 Admin login returns token" "$ADMIN_TOKEN"

ADMIN_ID=$(jq_field "$RESP" "user.id")
assert_not_empty "TC-1.2 Admin login returns user ID" "$ADMIN_ID"

ADMIN_ROLE=$(jq_field "$RESP" "user.role")
assert_eq "TC-1.3 Admin role is 0 (Admin)" "0" "$ADMIN_ROLE"

# TC-1.4: Login with valid partner credentials
RESP=$(curl -s "$BASE_URL/auth/login" -H "Content-Type: application/json" \
  -d '{"email":"partner@tailorshop.com","password":"Partner@123"}')
PARTNER_TOKEN=$(jq_field "$RESP" "token")
assert_not_empty "TC-1.4 Partner login returns token" "$PARTNER_TOKEN"

PARTNER_ROLE=$(jq_field "$RESP" "user.role")
assert_eq "TC-1.5 Partner role is 1 (Partner)" "1" "$PARTNER_ROLE"

# TC-1.6: Login with invalid credentials
CODE=$(http_code "$BASE_URL/auth/login" -H "Content-Type: application/json" \
  -d '{"email":"admin@tailorshop.com","password":"WrongPass"}')
assert_eq "TC-1.6 Invalid password returns 401" "401" "$CODE"

# TC-1.7: Login with non-existent email
CODE=$(http_code "$BASE_URL/auth/login" -H "Content-Type: application/json" \
  -d '{"email":"nobody@test.com","password":"test123"}')
assert_eq "TC-1.7 Non-existent user returns 401" "401" "$CODE"

# TC-1.8: Refresh token
REFRESH=$(jq_field "$(curl -s "$BASE_URL/auth/login" -H "Content-Type: application/json" \
  -d '{"email":"admin@tailorshop.com","password":"Admin@123"}')" "refreshToken")
RESP=$(curl -s "$BASE_URL/auth/refresh" -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH\"}")
NEW_TOKEN=$(jq_field "$RESP" "token")
assert_not_empty "TC-1.8 Refresh token returns new token" "$NEW_TOKEN"

# TC-1.9: Access protected endpoint without token
CODE=$(http_code "$BASE_URL/customers")
assert_eq "TC-1.9 Protected endpoint without token returns 401" "401" "$CODE"

AUTH="-H \"Authorization: Bearer $ADMIN_TOKEN\""

###############################################################################
echo -e "${YELLOW}[2/14] CUSTOMERS${NC}"
###############################################################################

# TC-2.1: Create customer
RESP=$(curl -s "$BASE_URL/customers" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Sadia Bibi","phone":"03101234567","email":"sadia@test.com","address":"Model Town, Lahore","notes":"VIP customer"}')
CUST1_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-2.1 Create customer returns ID" "$CUST1_ID"

CUST1_NAME=$(jq_field "$RESP" "name")
assert_eq "TC-2.2 Customer name persisted" "Sadia Bibi" "$CUST1_NAME"

# TC-2.3: Create second customer
RESP=$(curl -s "$BASE_URL/customers" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Hina Pervez","phone":"03201234567"}')
CUST2_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-2.3 Create second customer returns ID" "$CUST2_ID"

# TC-2.4: Get all customers (should include seeded + new ones)
RESP=$(curl -s "$BASE_URL/customers" -H "Authorization: Bearer $ADMIN_TOKEN")
CUST_COUNT=$(jq_len "$RESP" "")
assert_gt "TC-2.4 Customer list has entries" "$CUST_COUNT" "3"

# TC-2.5: Search customer by name
RESP=$(curl -s "$BASE_URL/customers?search=Sadia" -H "Authorization: Bearer $ADMIN_TOKEN")
SEARCH_COUNT=$(jq_len "$RESP" "")
assert_gt "TC-2.5 Search by name finds results" "$SEARCH_COUNT" "0"

SEARCH_NAME=$(jq_field "$RESP" "0.name")
assert_eq "TC-2.6 Search result matches" "Sadia Bibi" "$SEARCH_NAME"

# TC-2.7: Search by phone
RESP=$(curl -s "$BASE_URL/customers?search=03101234567" -H "Authorization: Bearer $ADMIN_TOKEN")
SEARCH_PHONE=$(jq_field "$RESP" "0.phone")
assert_eq "TC-2.7 Search by phone works" "03101234567" "$SEARCH_PHONE"

# TC-2.8: Update customer
RESP=$(curl -s -X PUT "$BASE_URL/customers/$CUST1_ID" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Sadia Bibi Khan","phone":"03101234567","address":"DHA Phase 6, Lahore"}')
UPD_NAME=$(jq_field "$RESP" "name")
assert_eq "TC-2.8 Customer name updated" "Sadia Bibi Khan" "$UPD_NAME"

# TC-2.9: Verify update persisted
RESP=$(curl -s "$BASE_URL/customers?search=Sadia" -H "Authorization: Bearer $ADMIN_TOKEN")
PERSIST_NAME=$(jq_field "$RESP" "0.name")
assert_eq "TC-2.9 Customer update persisted" "Sadia Bibi Khan" "$PERSIST_NAME"

###############################################################################
echo -e "${YELLOW}[3/14] MEASUREMENTS${NC}"
###############################################################################

# TC-3.1: Create measurement for customer
RESP=$(curl -s "$BASE_URL/customers/measurements" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"customerId\":\"$CUST1_ID\",\"label\":\"Suit Default\",\"length\":40,\"shoulder\":14,\"chest\":34,\"waist\":28,\"hip\":38,\"sleeveLength\":22,\"neck\":14,\"trouserLength\":38,\"trouserWaist\":28}")
MEAS_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-3.1 Create measurement returns ID" "$MEAS_ID"

MEAS_CHEST=$(jq_field "$RESP" "chest")
assert_eq "TC-3.2 Measurement chest value persisted" "34" "$MEAS_CHEST"

# TC-3.3: Get measurements for customer
RESP=$(curl -s "$BASE_URL/customers/$CUST1_ID/measurements" -H "Authorization: Bearer $ADMIN_TOKEN")
MEAS_COUNT=$(jq_len "$RESP" "")
assert_gt "TC-3.3 Customer has measurements" "$MEAS_COUNT" "0"

# TC-3.4: Create second measurement set
RESP=$(curl -s "$BASE_URL/customers/measurements" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"customerId\":\"$CUST1_ID\",\"label\":\"Abaya\",\"length\":54,\"chest\":36,\"waist\":30}")
MEAS2_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-3.4 Second measurement set created" "$MEAS2_ID"

###############################################################################
echo -e "${YELLOW}[4/14] ORDERS${NC}"
###############################################################################

# TC-4.1: Create order with advance payment
RESP=$(curl -s "$BASE_URL/orders" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"customerId\":\"$CUST1_ID\",\"orderType\":0,\"measurementId\":\"$MEAS_ID\",\"stitchingAmount\":3000,\"materialAmount\":2000,\"discount\":500,\"dueDate\":\"2026-05-15\",\"designNotes\":\"Blue silk suit with embroidery\",\"isUrgent\":false,\"advancePayment\":1000}")
ORDER1_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-4.1 Create order returns ID" "$ORDER1_ID"

ORDER_NUM=$(jq_field "$RESP" "orderNumber")
assert_not_empty "TC-4.2 Order has order number" "$ORDER_NUM"

ORDER_TOTAL=$(jq_field "$RESP" "totalAmount")
assert_eq "TC-4.3 Order total = stitching + material - discount (3000+2000-500=4500)" "4500" "$ORDER_TOTAL"

ORDER_PAID=$(jq_field "$RESP" "paidAmount")
assert_eq "TC-4.4 Advance payment recorded" "1000" "$ORDER_PAID"

ORDER_BALANCE=$(jq_field "$RESP" "balanceAmount")
assert_eq "TC-4.5 Balance = total - paid (4500-1000=3500)" "3500" "$ORDER_BALANCE"

ORDER_LABOUR=$(jq_field "$RESP" "labourAmount")
assert_eq "TC-4.6 Labour = stitching * 35% (3000*0.35=1050)" "1050" "$ORDER_LABOUR"

ORDER_STATUS=$(jq_field "$RESP" "status")
assert_eq "TC-4.7 Initial status is Received (0)" "0" "$ORDER_STATUS"

# TC-4.8: Create second order for different customer
RESP=$(curl -s "$BASE_URL/orders" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"customerId\":\"$CUST2_ID\",\"orderType\":1,\"stitchingAmount\":2000,\"materialAmount\":0,\"discount\":0,\"isUrgent\":true}")
ORDER2_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-4.8 Second order created" "$ORDER2_ID"

ORDER2_URGENT=$(jq_field "$RESP" "isUrgent")
assert_eq "TC-4.9 Urgent flag persisted" "True" "$ORDER2_URGENT"

# TC-4.10: Get order by ID (persistence check)
RESP=$(curl -s "$BASE_URL/orders/$ORDER1_ID" -H "Authorization: Bearer $ADMIN_TOKEN")
PERSIST_TOTAL=$(jq_field "$RESP" "totalAmount")
assert_eq "TC-4.10 Order persisted - total matches" "4500" "$PERSIST_TOTAL"

PERSIST_CUST=$(jq_field "$RESP" "customerName")
assert_eq "TC-4.11 Order persisted - customer name" "Sadia Bibi Khan" "$PERSIST_CUST"

# TC-4.12: Get today's orders
RESP=$(curl -s "$BASE_URL/orders/today" -H "Authorization: Bearer $ADMIN_TOKEN")
TODAY_COUNT=$(jq_len "$RESP" "")
assert_gt "TC-4.12 Today's orders list has entries" "$TODAY_COUNT" "0"

# TC-4.13: Get all orders
RESP=$(curl -s "$BASE_URL/orders" -H "Authorization: Bearer $ADMIN_TOKEN")
ALL_ORDERS=$(jq_len "$RESP" "")
assert_gt "TC-4.13 All orders list has entries" "$ALL_ORDERS" "1"

# TC-4.14: Filter orders by status
RESP=$(curl -s "$BASE_URL/orders?status=0" -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS_FILTER=$(jq_len "$RESP" "")
assert_gt "TC-4.14 Filter by status returns results" "$STATUS_FILTER" "0"

# TC-4.15: Filter orders by customer
RESP=$(curl -s "$BASE_URL/orders?customerId=$CUST1_ID" -H "Authorization: Bearer $ADMIN_TOKEN")
CUST_FILTER=$(jq_len "$RESP" "")
assert_gt "TC-4.15 Filter by customer returns results" "$CUST_FILTER" "0"

###############################################################################
echo -e "${YELLOW}[5/14] ORDER STATUS LIFECYCLE${NC}"
###############################################################################

# TC-5.1: Update status to Cutting
RESP=$(curl -s -X POST "$BASE_URL/orders/$ORDER1_ID/status" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" -d '{"status":1,"notes":"Started cutting"}')
NEW_STATUS=$(jq_field "$RESP" "status")
assert_eq "TC-5.1 Status updated to Cutting (1)" "1" "$NEW_STATUS"

# TC-5.2: Update to Stitching
RESP=$(curl -s -X POST "$BASE_URL/orders/$ORDER1_ID/status" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" -d '{"status":2,"notes":"Stitching in progress"}')
assert_eq "TC-5.2 Status updated to Stitching (2)" "2" "$(jq_field "$RESP" "status")"

# TC-5.3: Update to Finishing
RESP=$(curl -s -X POST "$BASE_URL/orders/$ORDER1_ID/status" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" -d '{"status":3}')
assert_eq "TC-5.3 Status updated to Finishing (3)" "3" "$(jq_field "$RESP" "status")"

# TC-5.4: Update to Ready
RESP=$(curl -s -X POST "$BASE_URL/orders/$ORDER1_ID/status" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" -d '{"status":4,"notes":"Ready for pickup"}')
assert_eq "TC-5.4 Status updated to Ready (4)" "4" "$(jq_field "$RESP" "status")"

# TC-5.5: Update to Delivered
RESP=$(curl -s -X POST "$BASE_URL/orders/$ORDER1_ID/status" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" -d '{"status":5,"notes":"Delivered to customer"}')
assert_eq "TC-5.5 Status updated to Delivered (5)" "5" "$(jq_field "$RESP" "status")"

# TC-5.6: Verify delivery date set
RESP=$(curl -s "$BASE_URL/orders/$ORDER1_ID" -H "Authorization: Bearer $ADMIN_TOKEN")
DEL_DATE=$(jq_field "$RESP" "deliveryDate")
assert_not_empty "TC-5.6 Delivery date set on Delivered" "$DEL_DATE"

###############################################################################
echo -e "${YELLOW}[6/14] PAYMENTS${NC}"
###############################################################################

# TC-6.1: Create payment for order
RESP=$(curl -s "$BASE_URL/payments" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"orderId\":\"$ORDER1_ID\",\"amount\":2000,\"method\":0,\"notes\":\"Cash payment\"}")
PAY1_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-6.1 Payment created" "$PAY1_ID"

PAY1_AMT=$(jq_field "$RESP" "amount")
assert_eq "TC-6.2 Payment amount correct" "2000" "$PAY1_AMT"

# TC-6.3: Verify order balance updated
RESP=$(curl -s "$BASE_URL/orders/$ORDER1_ID" -H "Authorization: Bearer $ADMIN_TOKEN")
UPD_PAID=$(jq_field "$RESP" "paidAmount")
assert_eq "TC-6.3 Order paid updated (1000+2000=3000)" "3000" "$UPD_PAID"

UPD_BAL=$(jq_field "$RESP" "balanceAmount")
assert_eq "TC-6.4 Order balance updated (4500-3000=1500)" "1500" "$UPD_BAL"

# TC-6.5: Create final payment
RESP=$(curl -s "$BASE_URL/payments" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"orderId\":\"$ORDER1_ID\",\"amount\":1500,\"method\":1,\"notes\":\"Bank transfer final\"}")
PAY2_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-6.5 Final payment created" "$PAY2_ID"

# TC-6.6: Verify fully paid
RESP=$(curl -s "$BASE_URL/orders/$ORDER1_ID" -H "Authorization: Bearer $ADMIN_TOKEN")
FINAL_BAL=$(jq_field "$RESP" "balanceAmount")
assert_eq "TC-6.6 Order fully paid - balance is 0" "0" "$FINAL_BAL"

FINAL_PAID=$(jq_field "$RESP" "paidAmount")
assert_eq "TC-6.7 Total paid equals total (4500)" "4500" "$FINAL_PAID"

# TC-6.8: Get payments by order
RESP=$(curl -s "$BASE_URL/payments/by-order/$ORDER1_ID" -H "Authorization: Bearer $ADMIN_TOKEN")
PAY_COUNT=$(jq_len "$RESP" "")
assert_gt "TC-6.8 Order has multiple payments" "$PAY_COUNT" "1"

# TC-6.9: Get all payments
RESP=$(curl -s "$BASE_URL/payments" -H "Authorization: Bearer $ADMIN_TOKEN")
ALL_PAY=$(jq_len "$RESP" "")
assert_gt "TC-6.9 All payments list populated" "$ALL_PAY" "0"

###############################################################################
echo -e "${YELLOW}[7/14] INVOICES${NC}"
###############################################################################

# TC-7.1: Generate invoice from order
RESP=$(curl -s "$BASE_URL/invoices/generate" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"orderId\":\"$ORDER1_ID\",\"notes\":\"Thank you for choosing us\"}")
INV_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-7.1 Invoice generated" "$INV_ID"

INV_NUM=$(jq_field "$RESP" "invoiceNumber")
assert_not_empty "TC-7.2 Invoice has number" "$INV_NUM"

INV_TOTAL=$(jq_field "$RESP" "totalAmount")
assert_eq "TC-7.3 Invoice total matches order" "4500" "$INV_TOTAL"

# TC-7.4: Invoice has line items
INV_LINES=$(jq_len "$RESP" "lines")
assert_gt "TC-7.4 Invoice has line items" "$INV_LINES" "0"

# TC-7.5: Get invoice PDF
CODE=$(http_code "$BASE_URL/invoices/$INV_ID/pdf" -H "Authorization: Bearer $ADMIN_TOKEN")
assert_eq "TC-7.5 Invoice PDF returns 200" "200" "$CODE"

# TC-7.6: Get invoice by ID (persistence)
RESP=$(curl -s "$BASE_URL/invoices/$INV_ID" -H "Authorization: Bearer $ADMIN_TOKEN")
PERSIST_INV=$(jq_field "$RESP" "invoiceNumber")
assert_eq "TC-7.6 Invoice persisted" "$INV_NUM" "$PERSIST_INV"

# TC-7.7: Mark invoice as printed
CODE=$(http_code -X POST "$BASE_URL/invoices/$INV_ID/mark-printed" -H "Authorization: Bearer $ADMIN_TOKEN")
assert_eq "TC-7.7 Mark printed returns 200" "200" "$CODE"

# TC-7.8: Get all invoices
RESP=$(curl -s "$BASE_URL/invoices" -H "Authorization: Bearer $ADMIN_TOKEN")
ALL_INV=$(jq_len "$RESP" "")
assert_gt "TC-7.8 Invoice list populated" "$ALL_INV" "0"

# TC-7.9: Generate second invoice for second order
RESP=$(curl -s "$BASE_URL/invoices/generate" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"orderId\":\"$ORDER2_ID\"}")
INV2_NUM=$(jq_field "$RESP" "invoiceNumber")
assert_not_empty "TC-7.9 Second invoice generated with different number" "$INV2_NUM"

# TC-7.10: Invoice numbers are sequential
echo "  INFO: Invoice 1=$INV_NUM, Invoice 2=$INV2_NUM"

###############################################################################
echo -e "${YELLOW}[8/14] ASSETS${NC}"
###############################################################################

# TC-8.1: Create asset (should be PendingApproval)
RESP=$(curl -s "$BASE_URL/assets" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Industrial Sewing Machine","description":"Singer brand","assetType":"Sewing Machine","quantity":2,"unitValue":25000,"ownership":2,"notes":"Bought from market"}')
ASSET1_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-8.1 Asset created" "$ASSET1_ID"

ASSET_STATUS=$(jq_field "$RESP" "approvalStatus")
assert_eq "TC-8.2 Asset starts as PendingApproval (0)" "0" "$ASSET_STATUS"

ASSET_TOTAL=$(jq_field "$RESP" "totalValue")
assert_eq "TC-8.3 Asset total = qty * unitValue (2*25000=50000)" "50000" "$ASSET_TOTAL"

# TC-8.4: Create second asset
RESP=$(curl -s "$BASE_URL/assets" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Steam Iron","assetType":"Iron","quantity":1,"unitValue":5000,"ownership":0}')
ASSET2_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-8.4 Second asset created" "$ASSET2_ID"

# TC-8.5: Get all assets
RESP=$(curl -s "$BASE_URL/assets" -H "Authorization: Bearer $ADMIN_TOKEN")
ASSET_COUNT=$(jq_len "$RESP" "")
assert_gt "TC-8.5 Asset list has entries" "$ASSET_COUNT" "0"

# TC-8.6: Filter by approval status
RESP=$(curl -s "$BASE_URL/assets?status=0" -H "Authorization: Bearer $ADMIN_TOKEN")
PENDING_ASSETS=$(jq_len "$RESP" "")
assert_gt "TC-8.6 Pending assets filter works" "$PENDING_ASSETS" "0"

# TC-8.7: Approve asset
CODE=$(http_code -X POST "$BASE_URL/assets/$ASSET1_ID/approve" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"comment":"Looks good, approved"}')
assert_eq "TC-8.7 Approve asset returns 200" "200" "$CODE"

# TC-8.8: Verify approval persisted
RESP=$(curl -s "$BASE_URL/assets/$ASSET1_ID" -H "Authorization: Bearer $ADMIN_TOKEN")
APP_STATUS=$(jq_field "$RESP" "approvalStatus")
assert_eq "TC-8.8 Asset now Approved (1)" "1" "$APP_STATUS"

# TC-8.9: Reject second asset
CODE=$(http_code -X POST "$BASE_URL/assets/$ASSET2_ID/reject" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"comment":"Too expensive, rejected"}')
assert_eq "TC-8.9 Reject asset returns 200" "200" "$CODE"

# TC-8.10: Verify rejection persisted
RESP=$(curl -s "$BASE_URL/assets/$ASSET2_ID" -H "Authorization: Bearer $ADMIN_TOKEN")
REJ_STATUS=$(jq_field "$RESP" "approvalStatus")
assert_eq "TC-8.10 Asset now Rejected (2)" "2" "$REJ_STATUS"

# TC-8.11: Update asset
RESP=$(curl -s -X PUT "$BASE_URL/assets/$ASSET1_ID" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Industrial Sewing Machine v2","assetType":"Sewing Machine","quantity":3,"unitValue":25000,"ownership":2}')
UPD_QTY=$(jq_field "$RESP" "quantity")
assert_eq "TC-8.11 Asset quantity updated to 3" "3" "$UPD_QTY"

UPD_TOTAL=$(jq_field "$RESP" "totalValue")
assert_eq "TC-8.12 Updated total = 3*25000=75000" "75000" "$UPD_TOTAL"

###############################################################################
echo -e "${YELLOW}[9/14] INVENTORY${NC}"
###############################################################################

# TC-9.1: Create inventory item
RESP=$(curl -s "$BASE_URL/inventory/items" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Chiffon Fabric","description":"Premium quality","category":"Fabric","unit":"meters","currentStock":100,"unitCost":800}')
INV_ITEM_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-9.1 Inventory item created" "$INV_ITEM_ID"

INV_STOCK=$(jq_field "$RESP" "currentStock")
assert_eq "TC-9.2 Initial stock is 100" "100" "$INV_STOCK"

# TC-9.3: Create purchase transaction (pending approval)
RESP=$(curl -s "$BASE_URL/inventory/transactions" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"inventoryItemId\":\"$INV_ITEM_ID\",\"type\":0,\"quantity\":50,\"unitCost\":750,\"notes\":\"Bulk purchase\"}")
TX_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-9.3 Purchase transaction created" "$TX_ID"

TX_STATUS=$(jq_field "$RESP" "approvalStatus")
assert_eq "TC-9.4 Purchase starts as PendingApproval (0)" "0" "$TX_STATUS"

# TC-9.5: Stock should NOT change before approval
RESP=$(curl -s "$BASE_URL/inventory/items" -H "Authorization: Bearer $ADMIN_TOKEN")
STOCK_BEFORE=$(echo "$RESP" | python3 -c "
import sys,json
items = json.load(sys.stdin)
for i in items:
    if i.get('id') == '$INV_ITEM_ID':
        print(int(i.get('currentStock',0)))
        break
" 2>/dev/null)
assert_eq "TC-9.5 Stock unchanged before approval (100)" "100" "$STOCK_BEFORE"

# TC-9.6: Approve purchase
CODE=$(http_code -X POST "$BASE_URL/inventory/transactions/$TX_ID/approve" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"comment":"Approved"}')
assert_eq "TC-9.6 Approve purchase returns 200" "200" "$CODE"

# TC-9.7: Stock should increase after approval
RESP=$(curl -s "$BASE_URL/inventory/items" -H "Authorization: Bearer $ADMIN_TOKEN")
STOCK_AFTER=$(echo "$RESP" | python3 -c "
import sys,json
items = json.load(sys.stdin)
for i in items:
    if i.get('id') == '$INV_ITEM_ID':
        print(int(i.get('currentStock',0)))
        break
" 2>/dev/null)
assert_eq "TC-9.7 Stock increased after approval (100+50=150)" "150" "$STOCK_AFTER"

# TC-9.8: Create and reject a purchase
RESP=$(curl -s "$BASE_URL/inventory/transactions" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"inventoryItemId\":\"$INV_ITEM_ID\",\"type\":0,\"quantity\":200,\"unitCost\":900,\"notes\":\"Too expensive\"}")
TX2_ID=$(jq_field "$RESP" "id")
CODE=$(http_code -X POST "$BASE_URL/inventory/transactions/$TX2_ID/reject" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"comment":"Price too high"}')
assert_eq "TC-9.8 Reject purchase returns 200" "200" "$CODE"

# TC-9.9: Stock should NOT change after rejection
RESP=$(curl -s "$BASE_URL/inventory/items" -H "Authorization: Bearer $ADMIN_TOKEN")
STOCK_REJ=$(echo "$RESP" | python3 -c "
import sys,json
items = json.load(sys.stdin)
for i in items:
    if i.get('id') == '$INV_ITEM_ID':
        print(int(i.get('currentStock',0)))
        break
" 2>/dev/null)
assert_eq "TC-9.9 Stock unchanged after rejection (still 150)" "150" "$STOCK_REJ"

# TC-9.10: Add inventory usage to order
CODE=$(http_code -X POST "$BASE_URL/orders/$ORDER2_ID/inventory-usage" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d "{\"inventoryItemId\":\"$INV_ITEM_ID\",\"quantity\":5,\"unitCost\":800,\"notes\":\"Used for kurti\"}")
assert_eq "TC-9.10 Add inventory usage returns 200" "200" "$CODE"

###############################################################################
echo -e "${YELLOW}[10/14] EXPENSES${NC}"
###############################################################################

# TC-10.1: Create expense (pending approval)
RESP=$(curl -s "$BASE_URL/expenses" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"description":"Monthly rent payment","category":0,"amount":20000,"notes":"April rent"}')
EXP1_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-10.1 Expense created" "$EXP1_ID"

EXP_STATUS=$(jq_field "$RESP" "approvalStatus")
assert_eq "TC-10.2 Expense starts as PendingApproval (0)" "0" "$EXP_STATUS"

# TC-10.3: Create second expense
RESP=$(curl -s "$BASE_URL/expenses" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"description":"Electricity bill","category":1,"amount":5000}')
EXP2_ID=$(jq_field "$RESP" "id")
assert_not_empty "TC-10.3 Second expense created" "$EXP2_ID"

# TC-10.4: Approve first expense
CODE=$(http_code -X POST "$BASE_URL/expenses/$EXP1_ID/approve" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"comment":"Verified receipt"}')
assert_eq "TC-10.4 Approve expense returns 200" "200" "$CODE"

# TC-10.5: Verify approval persisted
RESP=$(curl -s "$BASE_URL/expenses?status=1" -H "Authorization: Bearer $ADMIN_TOKEN")
APP_EXP=$(jq_len "$RESP" "")
assert_gt "TC-10.5 Approved expenses filter works" "$APP_EXP" "0"

# TC-10.6: Reject second expense
CODE=$(http_code -X POST "$BASE_URL/expenses/$EXP2_ID/reject" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"comment":"Need receipt photo"}')
assert_eq "TC-10.6 Reject expense returns 200" "200" "$CODE"

# TC-10.7: Get all expenses
RESP=$(curl -s "$BASE_URL/expenses" -H "Authorization: Bearer $ADMIN_TOKEN")
ALL_EXP=$(jq_len "$RESP" "")
assert_gt "TC-10.7 Expense list populated" "$ALL_EXP" "1"

###############################################################################
echo -e "${YELLOW}[11/14] REPORTS & BUSINESS CALCULATIONS${NC}"
###############################################################################

# TC-11.1: Dashboard
RESP=$(curl -s "$BASE_URL/reports/dashboard" -H "Authorization: Bearer $ADMIN_TOKEN")
DASH_PENDING=$(jq_field "$RESP" "pendingOrders")
assert_not_empty "TC-11.1 Dashboard returns pendingOrders" "$DASH_PENDING"

DASH_INV_VAL=$(jq_field "$RESP" "inventoryValue")
assert_gt "TC-11.2 Dashboard inventory value > 0" "$DASH_INV_VAL" "0"

DASH_ASSET_VAL=$(jq_field "$RESP" "assetValue")
assert_gt "TC-11.3 Dashboard asset value > 0 (approved assets)" "$DASH_ASSET_VAL" "0"

DASH_LABOUR=$(jq_field "$RESP" "labourPayable")
assert_gt "TC-11.4 Dashboard labour payable > 0" "$DASH_LABOUR" "0"

# TC-11.5: Profit Summary
TODAY=$(date +%Y-%m-%d)
RESP=$(curl -s "$BASE_URL/reports/profit-summary?from=2020-01-01&to=2030-12-31" -H "Authorization: Bearer $ADMIN_TOKEN")
REVENUE=$(jq_field "$RESP" "totalRevenue")
assert_gt "TC-11.5 Profit report has revenue" "$REVENUE" "0"

LABOUR=$(jq_field "$RESP" "totalLabour")
assert_gt "TC-11.6 Profit report has labour cost" "$LABOUR" "0"

NET_PROFIT=$(jq_field "$RESP" "netProfit")
assert_not_empty "TC-11.7 Profit report has net profit" "$NET_PROFIT"

# TC-11.8: Verify profit formula: Revenue - Labour - InventoryCost - Expenses = Net Profit
TOTAL_EXP=$(jq_field "$RESP" "totalExpenses")
INV_COST=$(jq_field "$RESP" "totalInventoryCost")
EXPECTED_PROFIT=$(python3 -c "print($REVENUE - $LABOUR - $INV_COST - $TOTAL_EXP)" 2>/dev/null)
assert_eq "TC-11.8 Net profit formula correct" "$EXPECTED_PROFIT" "$NET_PROFIT"

# TC-11.9: Partner profit split
PARTNER_COUNT=$(jq_len "$RESP" "partnerProfits")
assert_gt "TC-11.9 Partner profit split shown" "$PARTNER_COUNT" "0"

# TC-11.10: Labour Report
RESP=$(curl -s "$BASE_URL/reports/labour-payable" -H "Authorization: Bearer $ADMIN_TOKEN")
LAB_TOTAL=$(jq_field "$RESP" "totalLabour")
assert_gt "TC-11.10 Labour report total > 0" "$LAB_TOTAL" "0"

LAB_ITEMS=$(jq_len "$RESP" "items")
assert_gt "TC-11.11 Labour report has items" "$LAB_ITEMS" "0"

# TC-11.12: Labour is only on stitching amount, NOT material
FIRST_LAB_STITCH=$(jq_field "$RESP" "items.0.stitchingAmount")
FIRST_LAB_PCT=$(jq_field "$RESP" "items.0.labourPercentage")
FIRST_LAB_AMT=$(jq_field "$RESP" "items.0.labourAmount")
EXPECTED_LAB=$(python3 -c "print($FIRST_LAB_STITCH * $FIRST_LAB_PCT / 100)" 2>/dev/null)
assert_eq "TC-11.12 Labour = stitching * percentage (not material)" "$EXPECTED_LAB" "$FIRST_LAB_AMT"

# TC-11.13: Inventory value report
RESP=$(curl -s "$BASE_URL/reports/inventory-value" -H "Authorization: Bearer $ADMIN_TOKEN")
INV_VAL=$(jq_field "$RESP" "value")
assert_gt "TC-11.13 Inventory value > 0" "$INV_VAL" "0"

# TC-11.14: Asset value report
RESP=$(curl -s "$BASE_URL/reports/assets-value" -H "Authorization: Bearer $ADMIN_TOKEN")
ASSET_VAL=$(jq_field "$RESP" "value")
assert_gt "TC-11.14 Asset value > 0" "$ASSET_VAL" "0"

###############################################################################
echo -e "${YELLOW}[12/14] SYNC (Mobile Offline Push)${NC}"
###############################################################################

# TC-12.1: Sync push customer
RESP=$(curl -s "$BASE_URL/sync/push" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"items":[{"entityType":"customer","operation":"create","localId":"00000000-0000-0000-0000-000000000101","payloadJson":"{\"name\":\"Sync Test Customer\",\"phone\":\"03401111111\"}","fileRefs":[]}]}')
SYNC_OK=$(jq_field "$RESP" "results.0.success")
assert_eq "TC-12.1 Sync push customer succeeds" "True" "$SYNC_OK"

SYNC_SRV_ID=$(jq_field "$RESP" "results.0.serverId")
assert_not_empty "TC-12.2 Sync returns server ID" "$SYNC_SRV_ID"

# TC-12.3: Verify synced customer persisted
RESP=$(curl -s "$BASE_URL/customers?search=Sync+Test" -H "Authorization: Bearer $ADMIN_TOKEN")
SYNC_CUST=$(jq_field "$RESP" "0.name")
assert_eq "TC-12.3 Synced customer persisted" "Sync Test Customer" "$SYNC_CUST"

# TC-12.4: Sync push order
RESP=$(curl -s "$BASE_URL/sync/push" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"items":[{"entityType":"order","operation":"create","localId":"00000000-0000-0000-0000-000000000102","payloadJson":"{\"customerName\":\"Sync Test Customer\",\"customerPhone\":\"03401111111\",\"orderType\":\"Kurti\",\"stitchingAmount\":2500,\"materialAmount\":1500}","fileRefs":[]}]}')
SYNC_ORDER=$(jq_field "$RESP" "results.0.success")
assert_eq "TC-12.4 Sync push order succeeds" "True" "$SYNC_ORDER"

# TC-12.5: Sync push asset
RESP=$(curl -s "$BASE_URL/sync/push" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"items":[{"entityType":"asset","operation":"create","localId":"00000000-0000-0000-0000-000000000103","payloadJson":"{\"name\":\"Overlock Machine\",\"type\":\"Overlock Machine\",\"quantity\":1,\"unitValue\":35000,\"owner\":\"Company\"}","fileRefs":[]}]}')
SYNC_ASSET=$(jq_field "$RESP" "results.0.success")
assert_eq "TC-12.5 Sync push asset succeeds" "True" "$SYNC_ASSET"

# TC-12.6: Sync push expense
RESP=$(curl -s "$BASE_URL/sync/push" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"items":[{"entityType":"expense","operation":"create","localId":"00000000-0000-0000-0000-000000000104","payloadJson":"{\"category\":\"Transport\",\"amount\":500,\"description\":\"Delivery transport\"}","fileRefs":[]}]}')
SYNC_EXP=$(jq_field "$RESP" "results.0.success")
assert_eq "TC-12.6 Sync push expense succeeds" "True" "$SYNC_EXP"

# TC-12.7: Sync push payment
RESP=$(curl -s "$BASE_URL/sync/push" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"items":[{"entityType":"payment","operation":"create","localId":"00000000-0000-0000-0000-000000000105","payloadJson":"{\"amount\":500,\"method\":\"Cash\",\"notes\":\"Advance\"}","fileRefs":[]}]}')
SYNC_PAY=$(jq_field "$RESP" "results.0.success")
assert_eq "TC-12.7 Sync push payment succeeds" "True" "$SYNC_PAY"

# TC-12.8: Sync push inventory
RESP=$(curl -s "$BASE_URL/sync/push" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"items":[{"entityType":"inventory","operation":"create","localId":"00000000-0000-0000-0000-000000000106","payloadJson":"{\"itemName\":\"Silk Thread\",\"quantity\":20,\"costPerUnit\":100,\"unit\":\"spools\"}","fileRefs":[]}]}')
SYNC_INV=$(jq_field "$RESP" "results.0.success")
assert_eq "TC-12.8 Sync push inventory succeeds" "True" "$SYNC_INV"

# TC-12.9: Sync push multiple items at once
RESP=$(curl -s "$BASE_URL/sync/push" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"items":[
    {"entityType":"customer","operation":"create","localId":"00000000-0000-0000-0000-000000000201","payloadJson":"{\"name\":\"Batch Customer 1\",\"phone\":\"03501111111\"}","fileRefs":[]},
    {"entityType":"customer","operation":"create","localId":"00000000-0000-0000-0000-000000000202","payloadJson":"{\"name\":\"Batch Customer 2\",\"phone\":\"03501111112\"}","fileRefs":[]}
  ]}')
BATCH1=$(jq_field "$RESP" "results.0.success")
BATCH2=$(jq_field "$RESP" "results.1.success")
assert_eq "TC-12.9a Batch sync item 1 succeeds" "True" "$BATCH1"
assert_eq "TC-12.9b Batch sync item 2 succeeds" "True" "$BATCH2"

# TC-12.10: Sync pull
RESP=$(curl -s "$BASE_URL/sync/pull" -H "Authorization: Bearer $ADMIN_TOKEN")
PULL_ITEMS=$(jq_len "$RESP" "items")
assert_gt "TC-12.10 Sync pull returns items" "$PULL_ITEMS" "0"

###############################################################################
echo -e "${YELLOW}[13/14] SETTINGS${NC}"
###############################################################################

# TC-13.1: Get business profile
RESP=$(curl -s "$BASE_URL/settings/business-profile" -H "Authorization: Bearer $ADMIN_TOKEN")
BIZ_NAME=$(jq_field "$RESP" "businessName")
assert_not_empty "TC-13.1 Business profile has name" "$BIZ_NAME"

BIZ_LABOUR=$(jq_field "$RESP" "defaultLabourSharePercentage")
assert_eq "TC-13.2 Default labour share is 35" "35" "$BIZ_LABOUR"

BIZ_CURRENCY=$(jq_field "$RESP" "currency")
assert_eq "TC-13.3 Currency is PKR" "PKR" "$BIZ_CURRENCY"

# TC-13.4: Update business profile
CODE=$(http_code -X PUT "$BASE_URL/settings/business-profile" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"businessName":"Elegance Tailoring","phone":"03001112233","email":"info@elegance.pk","address":"Mall Road, Lahore","defaultLabourSharePercentage":40,"invoicePrefix":"ELG","invoiceFooter":"Thank you - Elegance Tailoring","currency":"PKR"}')
assert_eq "TC-13.4 Update business profile returns 200" "200" "$CODE"

# TC-13.5: Verify update persisted
RESP=$(curl -s "$BASE_URL/settings/business-profile" -H "Authorization: Bearer $ADMIN_TOKEN")
UPD_BIZ=$(jq_field "$RESP" "businessName")
assert_eq "TC-13.5 Business name updated" "Elegance Tailoring" "$UPD_BIZ"

UPD_LABOUR=$(jq_field "$RESP" "defaultLabourSharePercentage")
assert_eq "TC-13.6 Labour share updated to 40" "40" "$UPD_LABOUR"

# TC-13.7: Restore original settings
curl -s -X PUT "$BASE_URL/settings/business-profile" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"businessName":"Ladies Tailoring & Garments","phone":"03001234567","email":"info@tailorshop.com","address":"Shop #1, Main Market, Lahore","defaultLabourSharePercentage":35,"invoicePrefix":"INV","invoiceFooter":"Thank you for choosing us!","currency":"PKR"}' > /dev/null

###############################################################################
echo -e "${YELLOW}[14/14] PARTNERS${NC}"
###############################################################################

# TC-14.1: Get partners
RESP=$(curl -s "$BASE_URL/partners" -H "Authorization: Bearer $ADMIN_TOKEN")
PARTNER_LIST=$(jq_len "$RESP" "")
assert_gt "TC-14.1 Partners list has entries" "$PARTNER_LIST" "0"

PARTNER_ID=$(jq_field "$RESP" "0.id")
assert_not_empty "TC-14.2 Partner has ID" "$PARTNER_ID"

PARTNER_SHARE=$(jq_field "$RESP" "0.profitSharePercentage")
assert_eq "TC-14.3 Partner profit share is 50%" "50" "$PARTNER_SHARE"

# TC-14.4: Add capital contribution
CODE=$(http_code -X POST "$BASE_URL/partners/$PARTNER_ID/contribution" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"amount":100000,"date":"2026-04-01","description":"Initial investment"}')
assert_eq "TC-14.4 Add contribution returns 200" "200" "$CODE"

# TC-14.5: Add withdrawal
CODE=$(http_code -X POST "$BASE_URL/partners/$PARTNER_ID/withdrawal" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"amount":10000,"date":"2026-04-15","description":"Monthly salary"}')
assert_eq "TC-14.5 Add withdrawal returns 200" "200" "$CODE"

# TC-14.6: Get users list
RESP=$(curl -s "$BASE_URL/users" -H "Authorization: Bearer $ADMIN_TOKEN")
USER_COUNT=$(jq_len "$RESP" "")
assert_gt "TC-14.6 Users list has entries" "$USER_COUNT" "1"

###############################################################################
# FINAL REPORT
###############################################################################
echo ""
echo "======================================================================"
echo "  TEST RESULTS"
echo "======================================================================"
echo -e "  Total:  $TOTAL"
echo -e "  ${GREEN}Passed: $PASS${NC}"
echo -e "  ${RED}Failed: $FAIL${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
  echo -e "${RED}FAILURES:${NC}"
  echo -e "$FAILURES"
  echo ""
fi

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}ALL TESTS PASSED!${NC}"
else
  echo -e "${RED}$FAIL TEST(S) FAILED${NC}"
fi
echo ""
