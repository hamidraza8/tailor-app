using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TailorShop.Api.Extensions;
using TailorShop.Application.DTOs;
using TailorShop.Application.Services;
using TailorShop.Domain.Entities;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;
using System.Text.RegularExpressions;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/ocr")]
[Authorize]
public class OcrController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly FileService _fileService;
    private readonly AuditService _audit;

    public OcrController(AppDbContext db, FileService fileService, AuditService audit)
    {
        _db = db;
        _fileService = fileService;
        _audit = audit;
    }

    [HttpPost("extract")]
    public async Task<IActionResult> Extract(IFormFile file)
    {
        // Save the file
        using var stream = file.OpenReadStream();
        var fileDto = await _fileService.UploadFileAsync(stream, file.FileName,
            file.ContentType, file.Length, FileCategory.OcrDocument, null, "OcrDocument", User.GetUserId());

        // In production, this would call Tesseract OCR.
        // For MVP, we simulate basic extraction with placeholder logic.
        var rawText = "[OCR placeholder - Tesseract integration needed]\n"
            + "In production, this would process the uploaded image through Tesseract OCR.\n"
            + "The raw text would then be parsed for supplier, date, items, and amounts.";

        var ocrDoc = new OcrDocument
        {
            FileAttachmentId = fileDto.Id,
            RawText = rawText,
            CreatedBy = User.GetUserId(),
            ExtractedFields = new List<OcrExtractedField>
            {
                new() { FieldName = "supplier", ExtractedValue = "", Confidence = 0 },
                new() { FieldName = "date", ExtractedValue = DateTime.UtcNow.ToString("yyyy-MM-dd"), Confidence = 0.5m },
                new() { FieldName = "total_amount", ExtractedValue = "0", Confidence = 0 },
            }
        };

        _db.OcrDocuments.Add(ocrDoc);
        await _db.SaveChangesAsync();

        return Ok(new OcrResultDto(ocrDoc.Id, rawText,
            ocrDoc.ExtractedFields.Select(f => new OcrFieldDto(f.FieldName, f.ExtractedValue, f.Confidence)).ToList()));
    }

    [HttpPost("{id}/confirm")]
    public async Task<IActionResult> Confirm(Guid id, [FromBody] OcrConfirmRequest request)
    {
        var doc = await _db.OcrDocuments.Include(d => d.ExtractedFields)
            .FirstOrDefaultAsync(d => d.Id == id);
        if (doc == null) return NotFound();

        foreach (var correction in request.Corrections)
        {
            var field = doc.ExtractedFields.FirstOrDefault(f => f.FieldName == correction.FieldName);
            if (field != null)
                field.CorrectedValue = correction.CorrectedValue;
        }

        doc.IsConfirmed = true;
        doc.ConfirmedAt = DateTime.UtcNow;
        doc.ConfirmedBy = User.GetUserId();

        await _db.SaveChangesAsync();
        await _audit.LogAsync("OcrDocument", id, "Confirm", User.GetUserId());
        return Ok();
    }
}
