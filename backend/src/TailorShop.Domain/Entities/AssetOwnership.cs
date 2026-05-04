using TailorShop.Domain.Enums;

namespace TailorShop.Domain.Entities;

/// <summary>
/// Ownership record for an asset. Sum of OwnershipPercent across all records
/// for the same asset must equal 100.
/// OwnerType = Company → PartnerId is null.
/// OwnerType = Partner → PartnerId is set.
/// </summary>
public class AssetOwnership : BaseEntity
{
    public Guid AssetId { get; set; }
    public Asset Asset { get; set; } = null!;

    public AssetOwnerType OwnerType { get; set; }
    public Guid? PartnerId { get; set; }
    public Partner? Partner { get; set; }

    /// <summary>0–100. All records for the asset must sum to 100.</summary>
    public decimal OwnershipPercent { get; set; }

    /// <summary>Asset.TotalValue * OwnershipPercent / 100</summary>
    public decimal OwnershipValue { get; set; }
}
