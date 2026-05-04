namespace TailorShop.Domain.Entities;

public class Customer : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? Address { get; set; }
    public string? Notes { get; set; }

    public ICollection<CustomerMeasurement> Measurements { get; set; } = new List<CustomerMeasurement>();
    public ICollection<Order> Orders { get; set; } = new List<Order>();
}

public class CustomerMeasurement : BaseEntity
{
    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = null!;
    public string Label { get; set; } = "Default"; // e.g. "Summer 2024", "Abaya"

    // Common measurements in inches
    public decimal? Length { get; set; }
    public decimal? Shoulder { get; set; }
    public decimal? Chest { get; set; }
    public decimal? Waist { get; set; }
    public decimal? Hip { get; set; }
    public decimal? SleeveLength { get; set; }
    public decimal? SleeveWidth { get; set; }
    public decimal? Armhole { get; set; }
    public decimal? Neck { get; set; }
    public decimal? TrouserLength { get; set; }
    public decimal? TrouserWaist { get; set; }
    public decimal? Inseam { get; set; }
    public decimal? ThighWidth { get; set; }
    public decimal? BottomWidth { get; set; }
    public decimal? DamanWidth { get; set; }
    public decimal? FrontDrop { get; set; }
    public decimal? BackDrop { get; set; }

    public string? CustomFieldsJson { get; set; } // Additional measurements as JSON
    public string? Notes { get; set; }
}
