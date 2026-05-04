using TailorShop.Domain.Enums;

namespace TailorShop.Application.DTOs;

// Partners
public record PartnerDto(Guid Id, Guid UserId, string UserName, decimal ProfitSharePercentage,
    decimal LabourSharePercentage, string? Notes);
public record CreatePartnerRequest(Guid UserId, decimal ProfitSharePercentage,
    decimal LabourSharePercentage, string? Notes);
public record UpdatePartnerRequest(decimal? ProfitSharePercentage, decimal? LabourSharePercentage, string? Notes);
public record CapitalContributionRequest(decimal Amount, DateTime Date, string? Description);
public record WithdrawalRequest(decimal Amount, DateTime Date, string? Description);

// Assets
public record AssetDto(Guid Id, string Name, string? Description, string AssetType,
    int Quantity, decimal UnitValue, decimal TotalValue, LegacyAssetOwnership Ownership,
    Guid? OwnerId, ApprovalStatus ApprovalStatus, string? Notes,
    List<FileDto> Photos, DateTime CreatedAt);
public record CreateAssetRequest(string Name, string? Description, string AssetType,
    int Quantity, decimal UnitValue, LegacyAssetOwnership Ownership, Guid? OwnerId, string? Notes);
public record UpdateAssetRequest(string Name, string? Description, string AssetType,
    int Quantity, decimal UnitValue, LegacyAssetOwnership Ownership, Guid? OwnerId, string? Notes);

// Inventory
public record InventoryItemDto(Guid Id, string Name, string? Description, string Category,
    string? Unit, decimal CurrentStock, decimal UnitCost, decimal TotalValue,
    Guid? SupplierId, string? SupplierName, List<FileDto> Photos, DateTime CreatedAt);
public record CreateInventoryItemRequest(string Name, string? Description, string Category,
    string? Unit, decimal CurrentStock, decimal UnitCost, Guid? SupplierId);
public record InventoryTransactionDto(Guid Id, Guid InventoryItemId, string ItemName,
    InventoryTransactionType Type, decimal Quantity, decimal UnitCost, decimal TotalCost,
    Guid? OrderId, string? Notes, ApprovalStatus ApprovalStatus, List<FileDto> Photos, DateTime CreatedAt);
public record CreateInventoryTransactionRequest(Guid InventoryItemId, InventoryTransactionType Type,
    decimal Quantity, decimal UnitCost, Guid? OrderId, string? Notes);

// Customers
public record CustomerDto(Guid Id, string Name, string Phone, string? Email,
    string? Address, string? Notes, int OrderCount, DateTime CreatedAt);
public record CreateCustomerRequest(string Name, string Phone, string? Email,
    string? Address, string? Notes);
public record UpdateCustomerRequest(string Name, string Phone, string? Email,
    string? Address, string? Notes);
public record MeasurementDto(Guid Id, Guid CustomerId, string Label,
    decimal? Length, decimal? Shoulder, decimal? Chest, decimal? Waist, decimal? Hip,
    decimal? SleeveLength, decimal? SleeveWidth, decimal? Armhole, decimal? Neck,
    decimal? TrouserLength, decimal? TrouserWaist, decimal? Inseam,
    decimal? ThighWidth, decimal? BottomWidth, decimal? DamanWidth,
    decimal? FrontDrop, decimal? BackDrop, string? CustomFieldsJson, string? Notes);
public record CreateMeasurementRequest(Guid CustomerId, string Label,
    decimal? Length, decimal? Shoulder, decimal? Chest, decimal? Waist, decimal? Hip,
    decimal? SleeveLength, decimal? SleeveWidth, decimal? Armhole, decimal? Neck,
    decimal? TrouserLength, decimal? TrouserWaist, decimal? Inseam,
    decimal? ThighWidth, decimal? BottomWidth, decimal? DamanWidth,
    decimal? FrontDrop, decimal? BackDrop, string? CustomFieldsJson, string? Notes);

// Orders
public record OrderDto(Guid Id, string OrderNumber, Guid CustomerId, string CustomerName,
    string CustomerPhone, OrderType OrderType, string? CustomOrderType, OrderStatus Status,
    Guid? MeasurementId, decimal StitchingAmount, decimal MaterialAmount, decimal Discount,
    decimal TotalAmount, decimal PaidAmount, decimal BalanceAmount,
    DateTime OrderDate, DateTime? DueDate, DateTime? DeliveryDate,
    string? DesignNotes, string? SpecialInstructions, bool IsUrgent,
    decimal LabourSharePercentage, decimal LabourAmount,
    List<FileDto> Photos, DateTime CreatedAt);
public record CreateOrderRequest(Guid CustomerId, OrderType OrderType, string? CustomOrderType,
    Guid? MeasurementId, decimal StitchingAmount, decimal MaterialAmount, decimal Discount,
    DateTime? DueDate, string? DesignNotes, string? SpecialInstructions, bool IsUrgent,
    decimal? LabourSharePercentage, decimal? AdvancePayment);
public record UpdateOrderRequest(OrderType OrderType, string? CustomOrderType,
    Guid? MeasurementId, decimal StitchingAmount, decimal MaterialAmount, decimal Discount,
    DateTime? DueDate, string? DesignNotes, string? SpecialInstructions, bool IsUrgent,
    decimal? LabourSharePercentage);
public record UpdateOrderStatusRequest(OrderStatus Status, string? Notes);
public record OrderInventoryUsageRequest(Guid InventoryItemId, decimal Quantity, decimal UnitCost, string? Notes);

// Invoices
public record InvoiceDto(Guid Id, string InvoiceNumber, Guid OrderId, string OrderNumber,
    Guid CustomerId, string CustomerName, DateTime InvoiceDate,
    decimal SubTotal, decimal Discount, decimal TotalAmount, decimal PaidAmount, decimal BalanceAmount,
    string? Notes, bool IsPrinted, List<InvoiceLineDto> Lines, DateTime CreatedAt);
public record InvoiceLineDto(Guid Id, string Description, decimal Quantity, decimal UnitPrice, decimal Amount);
public record GenerateInvoiceRequest(Guid OrderId, string? Notes);
public record EmailInvoiceRequest(string RecipientEmail);

// Payments
public record PaymentDto(Guid Id, Guid OrderId, string OrderNumber, Guid CustomerId,
    string CustomerName, decimal Amount, PaymentMethod Method,
    DateTime PaymentDate, string? Notes, DateTime CreatedAt);
public record CreatePaymentRequest(Guid OrderId, decimal Amount, PaymentMethod Method,
    DateTime? PaymentDate, string? Notes);

// Files
public record FileDto(Guid Id, string FileName, string ContentType, long FileSize,
    string Url, FileCategory Category, DateTime CreatedAt);

// Approvals
public record ApprovalRequest(string? Comment);

// Sync
public record SyncPushRequest(List<SyncPushItem> Items);
public record SyncPushItem(string EntityType, string Operation, Guid LocalId,
    string PayloadJson, List<string>? FileRefs);
public record SyncPushResponse(List<SyncPushResult> Results);
public record SyncPushResult(Guid LocalId, Guid? ServerId, bool Success, string? Error);
public record SyncPullRequest(DateTime? LastSyncAt);
public record SyncPullResponse(List<SyncPullItem> Items, DateTime ServerTime);
public record SyncPullItem(string EntityType, Guid Id, string PayloadJson, DateTime UpdatedAt);
public record ResolveConflictRequest(Guid ConflictId, string Resolution);

// OCR
public record OcrResultDto(Guid Id, string? RawText, List<OcrFieldDto> Fields);
public record OcrFieldDto(string FieldName, string? ExtractedValue, decimal Confidence);
public record OcrConfirmRequest(Guid DocumentId, List<OcrFieldCorrection> Corrections);
public record OcrFieldCorrection(string FieldName, string CorrectedValue);

// Reports
public record DashboardDto(decimal TodaySales, int PendingOrders, int PendingApprovals,
    decimal CashReceived, decimal InventoryValue, decimal AssetValue,
    decimal LabourPayable, decimal NetProfitEstimate);
public record ProfitSummaryDto(decimal TotalRevenue, decimal TotalLabour,
    decimal TotalInventoryCost, decimal TotalExpenses, decimal NetProfit,
    List<PartnerProfitDto> PartnerProfits, DateTime FromDate, DateTime ToDate);
public record PartnerProfitDto(Guid PartnerId, string PartnerName,
    decimal SharePercentage, decimal ProfitShare);
public record LabourReportDto(List<LabourItemDto> Items, decimal TotalLabour);
public record LabourItemDto(Guid OrderId, string OrderNumber, string CustomerName,
    decimal StitchingAmount, decimal LabourPercentage, decimal LabourAmount, DateTime OrderDate);

// Settings
public record BusinessProfileDto(string BusinessName, string? Phone, string? Email,
    string? Address, string? LogoFileId, decimal DefaultLabourSharePercentage,
    string? InvoicePrefix, string? InvoiceFooter, string? Currency);
public record UpdateBusinessProfileRequest(string BusinessName, string? Phone, string? Email,
    string? Address, decimal DefaultLabourSharePercentage,
    string? InvoicePrefix, string? InvoiceFooter, string? Currency);

// Suppliers
public record SupplierDto(Guid Id, string Name, string? Phone, string? Address, string? Notes);
public record CreateSupplierRequest(string Name, string? Phone, string? Address, string? Notes);
