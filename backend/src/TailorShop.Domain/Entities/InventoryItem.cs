namespace TailorShop.Domain.Entities;

public class InventoryItem : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string Category { get; set; } = string.Empty; // Fabric, Thread, Button, Lace, etc.
    public string? Unit { get; set; } = "pcs"; // pcs, meters, yards, kg
    public decimal CurrentStock { get; set; }
    public decimal UnitCost { get; set; }
    public decimal TotalValue => CurrentStock * UnitCost;
    public decimal? ReorderLevel { get; set; }
    public Guid? SupplierId { get; set; }
    public Supplier? Supplier { get; set; }

    public ICollection<InventoryTransaction> Transactions { get; set; } = new List<InventoryTransaction>();
    public ICollection<FileAttachment> Photos { get; set; } = new List<FileAttachment>();
}

public class Supplier : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? Notes { get; set; }

    public ICollection<InventoryItem> Items { get; set; } = new List<InventoryItem>();
}
