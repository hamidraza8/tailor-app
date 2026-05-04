using TailorShop.Domain.Enums;

namespace TailorShop.Domain.Entities;

public class FileAttachment : BaseEntity
{
    public string FileName { get; set; } = string.Empty;
    public string OriginalFileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long FileSize { get; set; }
    public string StoragePath { get; set; } = string.Empty;
    public FileCategory Category { get; set; }
    public Guid? EntityId { get; set; } // Related entity ID
    public string? EntityType { get; set; } // "Asset", "Order", etc.
    public string? ThumbnailPath { get; set; }
}
