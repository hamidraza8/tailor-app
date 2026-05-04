using TailorShop.Domain.Enums;

namespace TailorShop.Domain.Entities;

public class SyncLog
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid DeviceId { get; set; }
    public string EntityType { get; set; } = string.Empty;
    public string Operation { get; set; } = string.Empty;
    public Guid? LocalId { get; set; }
    public Guid? ServerId { get; set; }
    public SyncStatus Status { get; set; }
    public string? ErrorMessage { get; set; }
    public DateTime SyncedAt { get; set; } = DateTime.UtcNow;
}

public class SyncConflict
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string EntityType { get; set; } = string.Empty;
    public Guid EntityId { get; set; }
    public string? LocalData { get; set; }
    public string? ServerData { get; set; }
    public Guid DeviceId { get; set; }
    public bool IsResolved { get; set; }
    public string? Resolution { get; set; } // "local", "server", "merged"
    public Guid? ResolvedBy { get; set; }
    public DateTime? ResolvedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class Device
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public string DeviceName { get; set; } = string.Empty;
    public string? Platform { get; set; }
    public DateTime LastSyncAt { get; set; }
    public DateTime RegisteredAt { get; set; } = DateTime.UtcNow;
}

public class BusinessProfile : BaseEntity
{
    public string BusinessName { get; set; } = "Tailor Shop";
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public string? Address { get; set; }
    public string? LogoFileId { get; set; }
    public decimal DefaultLabourSharePercentage { get; set; } = 35m;
    public string? InvoicePrefix { get; set; } = "INV";
    public int NextInvoiceNumber { get; set; } = 1;
    public string? InvoiceFooter { get; set; }
    public string? Currency { get; set; } = "PKR";
    public string? SmtpHost { get; set; }
    public int SmtpPort { get; set; } = 587;
    public string? SmtpUser { get; set; }
    public string? SmtpPassword { get; set; }
    public string? SmtpFromEmail { get; set; }
    public string? SmtpFromName { get; set; }
}
