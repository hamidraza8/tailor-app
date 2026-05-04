using TailorShop.Domain.Enums;

namespace TailorShop.Domain.Entities;

/// <summary>
/// Central spending record. Every business spend — asset purchase, inventory,
/// rent, salary, etc. — starts here. Reduces partner capital via FundingSplits.
/// </summary>
public class Spending : BaseEntity
{
    public string SpendingNo { get; set; } = string.Empty;
    public DateTime SpendingDate { get; set; } = DateTime.UtcNow;
    public SpendingCategory Category { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal TotalAmount { get; set; }

    /// <summary>What this spending created: Asset / Inventory / Expense.</summary>
    public SpendingResultType ResultType { get; set; }

    /// <summary>True for Asset purchases. False for Rent/Bills/Salary etc.</summary>
    public bool OwnershipApplicable { get; set; }

    public string? ReceiptFileUrl { get; set; }
    public string? Notes { get; set; }

    public ApprovalStatus ApprovalStatus { get; set; } = ApprovalStatus.PendingApproval;
    public string? ApprovalComment { get; set; }
    public Guid? ApprovedBy { get; set; }
    public DateTime? ApprovedAt { get; set; }

    // Navigation
    public ICollection<SpendingFundingSplit> FundingSplits { get; set; } = new List<SpendingFundingSplit>();
    public Asset? Asset { get; set; }
    public ICollection<InventoryTransaction> InventoryTransactions { get; set; } = new List<InventoryTransaction>();
}

/// <summary>
/// Exact funding contribution per partner for a single spending.
/// SUM(Amount) across all splits must equal Spending.TotalAmount.
/// A partner's capital balance is reduced by their split amount on approval.
/// Negative partner balance is allowed — shown as deficit.
/// </summary>
public class SpendingFundingSplit : BaseEntity
{
    public Guid SpendingId { get; set; }
    public Spending Spending { get; set; } = null!;

    public Guid PartnerId { get; set; }
    public Partner Partner { get; set; } = null!;

    public decimal Amount { get; set; }
    public string? Notes { get; set; }
}
