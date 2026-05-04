using TailorShop.Domain.Enums;

namespace TailorShop.Application.DTOs;

// Capital Transactions
public record CapitalTransactionDto(
    Guid Id, Guid PartnerId, string PartnerName,
    CapitalTransactionType Type, decimal Amount,
    DateTime TransactionDate, string? Notes,
    string? ReceiptFileUrl, ApprovalStatus ApprovalStatus, DateTime CreatedAt);

public record CreateCapitalTransactionRequest(
    CapitalTransactionType Type, decimal Amount,
    DateTime? TransactionDate, string? Notes, string? ReceiptFileUrl);

// Spendings
public record SpendingDto(
    Guid Id, string SpendingNo, DateTime SpendingDate,
    SpendingCategory Category, string Description,
    decimal TotalAmount, SpendingResultType ResultType,
    bool OwnershipApplicable, string? ReceiptFileUrl,
    string? Notes, ApprovalStatus ApprovalStatus,
    string? ApprovalComment, DateTime? ApprovedAt,
    List<SpendingFundingSplitDto> FundingSplits, DateTime CreatedAt);

public record SpendingFundingSplitDto(
    Guid Id, Guid PartnerId, string PartnerName, decimal Amount, string? Notes);

public record CreateSpendingRequest(
    DateTime? SpendingDate,
    SpendingCategory Category,
    string Description,
    decimal TotalAmount,
    SpendingResultType ResultType,
    bool OwnershipApplicable,
    string? ReceiptFileUrl,
    string? Notes,
    List<CreateFundingSplitRequest> FundingSplits,
    // For asset creation (if ResultType = Asset)
    CreateSpendingAssetRequest? Asset,
    // For inventory creation (if ResultType = Inventory)
    List<CreateSpendingInventoryRequest>? InventoryItems,
    // For expense creation (if ResultType = Expense) - no extra fields needed
    string? ExpenseNotes);

public record CreateFundingSplitRequest(Guid PartnerId, decimal Amount, string? Notes);

public record CreateSpendingAssetRequest(
    string Name, string? Description, string AssetType,
    int Quantity, decimal UnitValue,
    AssetOwnershipType OwnershipType,
    List<CreateAssetOwnershipRequest> Ownerships,
    string? Location, string? Condition, string? Notes);

public record CreateAssetOwnershipRequest(
    AssetOwnerType OwnerType, Guid? PartnerId,
    decimal OwnershipPercent, decimal OwnershipValue);

public record CreateSpendingInventoryRequest(
    Guid InventoryItemId, decimal Quantity, decimal UnitCost, string? SupplierName, string? Notes);

// Asset Ownership
public record AssetOwnershipDto(
    Guid Id, Guid AssetId, AssetOwnerType OwnerType,
    Guid? PartnerId, string? PartnerName,
    decimal OwnershipPercent, decimal OwnershipValue);

// Partner Balance Report
public record PartnerBalanceReportDto(
    Guid PartnerId, string PartnerName,
    decimal TotalCapitalAdded,
    decimal TotalFundedSpendings,
    decimal TotalWithdrawals,
    decimal RemainingBalance,
    bool IsDeficit,
    decimal DeficitAmount,
    decimal AssetOwnershipValue,
    decimal InventoryFundingTotal,
    decimal ExpenseFundingTotal,
    decimal AssetFundingTotal,
    List<PartnerCapitalLineDto> CapitalLines,
    List<PartnerSpendingLineDto> SpendingLines);

public record PartnerCapitalLineDto(
    Guid Id, CapitalTransactionType Type, decimal Amount,
    DateTime TransactionDate, string? Notes);

public record PartnerSpendingLineDto(
    Guid SpendingId, string SpendingNo, SpendingCategory Category,
    string Description, decimal FundedAmount,
    SpendingResultType ResultType, DateTime SpendingDate);

// Funding Split Report
public record FundingSplitReportDto(
    Guid SpendingId, string SpendingNo, DateTime SpendingDate,
    SpendingCategory Category, string Description,
    decimal TotalAmount, SpendingResultType ResultType,
    ApprovalStatus ApprovalStatus,
    List<SpendingFundingSplitDto> Splits);

// Asset Ownership Report
public record AssetOwnershipReportDto(
    Guid AssetId, string AssetName, string AssetType,
    int Quantity, decimal UnitValue, decimal TotalValue,
    AssetOwnershipType OwnershipType,
    List<AssetOwnershipDto> Ownerships);

// Business Capital Summary
public record CapitalSummaryDto(
    decimal TotalBusinessCapital,
    decimal TotalApprovedSpendings,
    decimal TotalRemainingCapital,
    decimal TotalDeficits,
    List<PartnerBalanceReportDto> PartnerBalances);
