using TailorShop.Domain.Enums;

namespace TailorShop.Domain.Entities;

public class Order : BaseEntity
{
    public string OrderNumber { get; set; } = string.Empty;
    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = null!;
    public OrderType OrderType { get; set; }
    public string? CustomOrderType { get; set; }
    public OrderStatus Status { get; set; } = OrderStatus.Received;
    public Guid? MeasurementId { get; set; }
    public CustomerMeasurement? Measurement { get; set; }

    public decimal StitchingAmount { get; set; }
    public decimal MaterialAmount { get; set; }
    public decimal Discount { get; set; }
    public decimal TotalAmount => StitchingAmount + MaterialAmount - Discount;
    public decimal PaidAmount { get; set; }
    public decimal BalanceAmount => TotalAmount - PaidAmount;

    public DateTime OrderDate { get; set; } = DateTime.UtcNow;
    public DateTime? DueDate { get; set; }
    public DateTime? DeliveryDate { get; set; }

    public string? DesignNotes { get; set; }
    public string? VoiceNoteUrl { get; set; }
    public string? SpecialInstructions { get; set; }
    public bool IsUrgent { get; set; }

    public decimal LabourSharePercentage { get; set; } = 35m;
    public decimal LabourAmount => StitchingAmount * LabourSharePercentage / 100m;

    public ICollection<OrderStatusHistory> StatusHistory { get; set; } = new List<OrderStatusHistory>();
    public ICollection<OrderInventoryUsage> InventoryUsages { get; set; } = new List<OrderInventoryUsage>();
    public ICollection<Payment> Payments { get; set; } = new List<Payment>();
    public ICollection<FileAttachment> Photos { get; set; } = new List<FileAttachment>();
    public ICollection<Invoice> Invoices { get; set; } = new List<Invoice>();
}

public class OrderStatusHistory : BaseEntity
{
    public Guid OrderId { get; set; }
    public Order Order { get; set; } = null!;
    public OrderStatus FromStatus { get; set; }
    public OrderStatus ToStatus { get; set; }
    public string? Notes { get; set; }
    public DateTime ChangedAt { get; set; } = DateTime.UtcNow;
}

public class OrderInventoryUsage : BaseEntity
{
    public Guid OrderId { get; set; }
    public Order Order { get; set; } = null!;
    public Guid InventoryItemId { get; set; }
    public InventoryItem InventoryItem { get; set; } = null!;
    public decimal Quantity { get; set; }
    public decimal UnitCost { get; set; }
    public decimal TotalCost => Quantity * UnitCost;
    public string? Notes { get; set; }
}
