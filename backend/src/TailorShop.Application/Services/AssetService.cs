using Microsoft.EntityFrameworkCore;
using TailorShop.Application.DTOs;
using TailorShop.Domain.Entities;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Application.Services;

public class AssetService
{
    private readonly AppDbContext _db;
    private readonly AuditService _audit;

    public AssetService(AppDbContext db, AuditService audit)
    {
        _db = db;
        _audit = audit;
    }

    public async Task<List<AssetDto>> GetAssetsAsync(ApprovalStatus? status = null)
    {
        var query = _db.Assets.Include(a => a.Photos).AsQueryable();
        if (status.HasValue) query = query.Where(a => a.ApprovalStatus == status.Value);

        var assets = await query.OrderByDescending(a => a.CreatedAt).ToListAsync();
        return assets.Select(MapAsset).ToList();
    }

    public async Task<AssetDto?> GetAssetByIdAsync(Guid id)
    {
        var asset = await _db.Assets.Include(a => a.Photos).FirstOrDefaultAsync(a => a.Id == id);
        return asset == null ? null : MapAsset(asset);
    }

    public async Task<AssetDto> CreateAssetAsync(CreateAssetRequest request, Guid userId)
    {
        var asset = new Asset
        {
            Name = request.Name,
            Description = request.Description,
            AssetType = request.AssetType,
            Quantity = request.Quantity,
            UnitValue = request.UnitValue,
            Ownership = request.Ownership,
            OwnerId = request.OwnerId,
            Notes = request.Notes,
            ApprovalStatus = ApprovalStatus.PendingApproval,
            CreatedBy = userId
        };

        _db.Assets.Add(asset);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("Asset", asset.Id, "Create", userId);
        return MapAsset(asset);
    }

    public async Task<AssetDto?> UpdateAssetAsync(Guid id, UpdateAssetRequest request, Guid userId)
    {
        var asset = await _db.Assets.Include(a => a.Photos).FirstOrDefaultAsync(a => a.Id == id);
        if (asset == null) return null;

        asset.Name = request.Name;
        asset.Description = request.Description;
        asset.AssetType = request.AssetType;
        asset.Quantity = request.Quantity;
        asset.UnitValue = request.UnitValue;
        asset.Ownership = request.Ownership;
        asset.OwnerId = request.OwnerId;
        asset.Notes = request.Notes;
        asset.UpdatedAt = DateTime.UtcNow;
        asset.UpdatedBy = userId;

        await _db.SaveChangesAsync();
        await _audit.LogAsync("Asset", id, "Update", userId);
        return MapAsset(asset);
    }

    public async Task<bool> ApproveAsync(Guid id, string? comment, Guid userId)
    {
        var asset = await _db.Assets.FindAsync(id);
        if (asset == null) return false;

        asset.ApprovalStatus = ApprovalStatus.Approved;
        asset.ApprovalComment = comment;
        asset.ApprovedBy = userId;
        asset.ApprovedAt = DateTime.UtcNow;
        asset.UpdatedAt = DateTime.UtcNow;
        asset.UpdatedBy = userId;

        await _db.SaveChangesAsync();
        await _audit.LogAsync("Asset", id, "Approve", userId);
        return true;
    }

    public async Task<bool> RejectAsync(Guid id, string? comment, Guid userId)
    {
        var asset = await _db.Assets.FindAsync(id);
        if (asset == null) return false;

        asset.ApprovalStatus = ApprovalStatus.Rejected;
        asset.ApprovalComment = comment;
        asset.ApprovedBy = userId;
        asset.ApprovedAt = DateTime.UtcNow;
        asset.UpdatedAt = DateTime.UtcNow;
        asset.UpdatedBy = userId;

        await _db.SaveChangesAsync();
        await _audit.LogAsync("Asset", id, "Reject", userId);
        return true;
    }

    private static AssetDto MapAsset(Asset a) => new(
        a.Id, a.Name, a.Description, a.AssetType, a.Quantity, a.UnitValue,
        a.TotalValue, a.Ownership, a.OwnerId, a.ApprovalStatus, a.Notes,
        a.Photos?.Select(FileService.MapFile).ToList() ?? new(), a.CreatedAt);
}
