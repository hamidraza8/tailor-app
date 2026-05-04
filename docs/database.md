# Database Schema

## Entity Relationship Diagram

### Core Entities

```
Users ──1:1──> Partners ──1:N──> PartnerCapitalContributions
                              └──> PartnerWithdrawals

Customers ──1:N──> CustomerMeasurements
          └──1:N──> Orders ──1:N──> OrderStatusHistory
                          └──1:N──> OrderInventoryUsage ──N:1──> InventoryItems
                          └──1:N──> Payments
                          └──1:N──> Invoices ──1:N──> InvoiceLines
                          │                  └──1:N──> InvoiceEmailLogs
                          └──1:N──> FileAttachments (photos)

Assets ──1:N──> FileAttachments (photos, receipts)

InventoryItems ──1:N──> InventoryTransactions ──1:N──> FileAttachments
               └──N:1──> Suppliers

Expenses ──1:N──> FileAttachments (receipts)
```

### Supporting Entities

```
AuditLogs          - tracks all changes
SyncLogs           - tracks sync operations  
SyncConflicts      - tracks sync conflicts
Devices            - registered mobile devices
OcrDocuments       - OCR processing results
OcrExtractedFields - individual OCR fields
BusinessProfile    - business settings
```

## Key Fields

All entities inherit from BaseEntity:
- `Id` (UUID) - primary key
- `CreatedAt` (DateTime) - creation timestamp
- `CreatedBy` (UUID?) - creating user
- `UpdatedAt` (DateTime?) - last update
- `UpdatedBy` (UUID?) - updating user
- `IsDeleted` (bool) - soft delete flag
- `RowVersion` (uint) - optimistic concurrency

### Approval-enabled entities (Asset, InventoryTransaction, Expense):
- `ApprovalStatus` - PendingApproval / Approved / Rejected
- `ApprovalComment` - admin comment
- `ApprovedBy` - approving user
- `ApprovedAt` - approval timestamp

## Indexes

- `Users.Email` - unique
- `Users.Phone` - indexed
- `Customers.Phone` - indexed  
- `Orders.OrderNumber` - unique
- `Invoices.InvoiceNumber` - unique
