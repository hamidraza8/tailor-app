using TailorShop.Domain.Enums;

namespace TailorShop.Domain.Entities;

public class Asset : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string AssetType { get; set; } = string.Empty; // Sewing Machine, Iron, Table, etc.
    public int Quantity { get; set; } = 1;
    public decimal UnitValue { get; set; }
    public decimal TotalValue => Quantity * UnitValue;

    // Legacy simple ownership (kept for backward compat)
    public LegacyAssetOwnership Ownership { get; set; } = LegacyAssetOwnership.Company;
    public Guid? OwnerId { get; set; }

    // Accounting module: link to spending that created this asset
    public Guid? SpendingId { get; set; }
    public Spending? Spending { get; set; }

    // New structured ownership records (sum must = 100%)
    public AssetOwnershipType OwnershipType { get; set; } = AssetOwnershipType.CompanyOwned;
    public ICollection<AssetOwnership> Ownerships { get; set; } = new List<AssetOwnership>();

    public ApprovalStatus ApprovalStatus { get; set; } = ApprovalStatus.PendingApproval;
    public string? ApprovalComment { get; set; }
    public Guid? ApprovedBy { get; set; }
    public DateTime? ApprovedAt { get; set; }
    public string? Notes { get; set; }
    public string? Location { get; set; }
    public string? Condition { get; set; }
    public DateTime? PurchaseDate { get; set; }

    public ICollection<FileAttachment> Photos { get; set; } = new List<FileAttachment>();
}
