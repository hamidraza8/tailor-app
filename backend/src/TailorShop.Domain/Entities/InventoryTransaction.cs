using TailorShop.Domain.Enums;

namespace TailorShop.Domain.Entities;

public class InventoryTransaction : BaseEntity
{
    public Guid InventoryItemId { get; set; }
    public InventoryItem InventoryItem { get; set; } = null!;
    public InventoryTransactionType Type { get; set; }
    public decimal Quantity { get; set; }
    public decimal UnitCost { get; set; }
    public decimal TotalCost => Quantity * UnitCost;
    public Guid? OrderId { get; set; }
    public Order? Order { get; set; }
    public string? Notes { get; set; }
    public ApprovalStatus ApprovalStatus { get; set; } = ApprovalStatus.PendingApproval;
    public string? ApprovalComment { get; set; }
    public Guid? ApprovedBy { get; set; }
    public DateTime? ApprovedAt { get; set; }

    // Accounting module: link to spending that created this transaction
    public Guid? SpendingId { get; set; }
    public Spending? Spending { get; set; }
    public string? SupplierName { get; set; }

    public ICollection<FileAttachment> Photos { get; set; } = new List<FileAttachment>();
}
