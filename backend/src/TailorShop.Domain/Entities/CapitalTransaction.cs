using TailorShop.Domain.Enums;

namespace TailorShop.Domain.Entities;

/// <summary>
/// Records every rupee given to or taken from the business by a partner.
/// Type CapitalAdvance / AdditionalCapital → increases partner balance.
/// Type Withdrawal / NegativeAdjustment → decreases partner balance.
/// </summary>
public class CapitalTransaction : BaseEntity
{
    public Guid PartnerId { get; set; }
    public Partner Partner { get; set; } = null!;

    public CapitalTransactionType Type { get; set; }
    public decimal Amount { get; set; }
    public DateTime TransactionDate { get; set; } = DateTime.UtcNow;
    public string? Notes { get; set; }
    public string? ReceiptFileUrl { get; set; }

    public ApprovalStatus ApprovalStatus { get; set; } = ApprovalStatus.Approved;
    public string? ApprovalComment { get; set; }
    public Guid? ApprovedBy { get; set; }
    public DateTime? ApprovedAt { get; set; }
}
