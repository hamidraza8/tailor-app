namespace TailorShop.Domain.Entities;

public class OcrDocument : BaseEntity
{
    public Guid FileAttachmentId { get; set; }
    public FileAttachment FileAttachment { get; set; } = null!;
    public string? RawText { get; set; }
    public bool IsConfirmed { get; set; }
    public DateTime? ConfirmedAt { get; set; }
    public Guid? ConfirmedBy { get; set; }

    public ICollection<OcrExtractedField> ExtractedFields { get; set; } = new List<OcrExtractedField>();
}

public class OcrExtractedField : BaseEntity
{
    public Guid OcrDocumentId { get; set; }
    public OcrDocument OcrDocument { get; set; } = null!;
    public string FieldName { get; set; } = string.Empty; // supplier, date, total, item_1_name, etc.
    public string? ExtractedValue { get; set; }
    public string? CorrectedValue { get; set; }
    public decimal Confidence { get; set; }
}
