using Microsoft.EntityFrameworkCore;
using TailorShop.Application.DTOs;
using TailorShop.Domain.Entities;
using TailorShop.Domain.Enums;
using TailorShop.Domain.Interfaces;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Application.Services;

public class FileService
{
    private readonly AppDbContext _db;
    private readonly IFileStorageService _storage;

    public FileService(AppDbContext db, IFileStorageService storage)
    {
        _db = db;
        _storage = storage;
    }

    public async Task<FileDto> UploadFileAsync(Stream fileStream, string fileName,
        string contentType, long fileSize, FileCategory category,
        Guid? entityId, string? entityType, Guid userId)
    {
        var storagePath = await _storage.SaveFileAsync(fileStream, fileName, contentType);

        var attachment = new FileAttachment
        {
            FileName = Path.GetFileName(storagePath),
            OriginalFileName = fileName,
            ContentType = contentType,
            FileSize = fileSize,
            StoragePath = storagePath,
            Category = category,
            EntityId = entityId,
            EntityType = entityType,
            CreatedBy = userId
        };

        _db.FileAttachments.Add(attachment);
        await _db.SaveChangesAsync();

        return MapFile(attachment);
    }

    public async Task<(Stream? stream, string? contentType, string? fileName)> GetFileAsync(Guid id)
    {
        var attachment = await _db.FileAttachments.FindAsync(id);
        if (attachment == null) return (null, null, null);

        var stream = await _storage.GetFileAsync(attachment.StoragePath);
        return (stream, attachment.ContentType, attachment.OriginalFileName);
    }

    public async Task<List<FileDto>> GetFilesForEntityAsync(Guid entityId, string entityType)
    {
        var files = await _db.FileAttachments
            .Where(f => f.EntityId == entityId && f.EntityType == entityType)
            .OrderByDescending(f => f.CreatedAt)
            .ToListAsync();
        return files.Select(MapFile).ToList();
    }

    public static FileDto MapFile(FileAttachment f) => new(
        f.Id, f.OriginalFileName, f.ContentType, f.FileSize,
        $"/api/files/{f.Id}", f.Category, f.CreatedAt);
}
