namespace TailorShop.Domain.Entities;

public class Partner : BaseEntity
{
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public decimal ProfitSharePercentage { get; set; } = 50m;
    public decimal LabourSharePercentage { get; set; } = 35m;
    public decimal OwnershipPercent { get; set; } = 0m;
    public string? Notes { get; set; }
    public bool IsActive { get; set; } = true;

    // Accounting module
    public ICollection<CapitalTransaction> CapitalTransactions { get; set; } = new List<CapitalTransaction>();
    public ICollection<SpendingFundingSplit> FundingSplits { get; set; } = new List<SpendingFundingSplit>();
    public ICollection<AssetOwnership> AssetOwnerships { get; set; } = new List<AssetOwnership>();
}
