using Microsoft.EntityFrameworkCore;
using TailorShop.Application.DTOs;
using TailorShop.Domain.Entities;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Application.Services;

public class InventoryService
{
    private readonly AppDbContext _db;
    private readonly AuditService _audit;

    public InventoryService(AppDbContext db, AuditService audit)
    {
        _db = db;
        _audit = audit;
    }

    public async Task<List<InventoryItemDto>> GetItemsAsync()
    {
        var items = await _db.InventoryItems
            .Include(i => i.Supplier)
            .Include(i => i.Photos)
            .OrderByDescending(i => i.CreatedAt)
            .ToListAsync();
        return items.Select(MapItem).ToList();
    }

    public async Task<InventoryItemDto> CreateItemAsync(CreateInventoryItemRequest request, Guid userId)
    {
        var item = new InventoryItem
        {
            Name = request.Name,
            Description = request.Description,
            Category = request.Category,
            Unit = request.Unit,
            CurrentStock = request.CurrentStock,
            UnitCost = request.UnitCost,
            SupplierId = request.SupplierId,
            CreatedBy = userId
        };

        _db.InventoryItems.Add(item);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("InventoryItem", item.Id, "Create", userId);
        return MapItem(item);
    }

    public async Task<InventoryTransactionDto> CreateTransactionAsync(
        CreateInventoryTransactionRequest request, Guid userId)
    {
        var tx = new InventoryTransaction
        {
            InventoryItemId = request.InventoryItemId,
            Type = request.Type,
            Quantity = request.Quantity,
            UnitCost = request.UnitCost,
            OrderId = request.OrderId,
            Notes = request.Notes,
            ApprovalStatus = request.Type == InventoryTransactionType.Purchase
                ? ApprovalStatus.PendingApproval
                : ApprovalStatus.Approved,
            CreatedBy = userId
        };

        // Update stock for non-purchase transactions (purchases update on approval)
        if (request.Type != InventoryTransactionType.Purchase)
        {
            var item = await _db.InventoryItems.FindAsync(request.InventoryItemId);
            if (item != null)
            {
                item.CurrentStock += request.Type == InventoryTransactionType.Return
                    ? request.Quantity : -request.Quantity;
                item.UpdatedAt = DateTime.UtcNow;
            }
        }

        _db.InventoryTransactions.Add(tx);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("InventoryTransaction", tx.Id, "Create", userId);

        return await GetTransactionByIdAsync(tx.Id) ?? throw new Exception("Transaction not found after creation");
    }

    public async Task<bool> ApproveTransactionAsync(Guid id, string? comment, Guid userId)
    {
        var tx = await _db.InventoryTransactions.FindAsync(id);
        if (tx == null) return false;

        tx.ApprovalStatus = ApprovalStatus.Approved;
        tx.ApprovalComment = comment;
        tx.ApprovedBy = userId;
        tx.ApprovedAt = DateTime.UtcNow;

        // Update stock on purchase approval
        if (tx.Type == InventoryTransactionType.Purchase)
        {
            var item = await _db.InventoryItems.FindAsync(tx.InventoryItemId);
            if (item != null)
            {
                item.CurrentStock += tx.Quantity;
                item.UnitCost = tx.UnitCost; // Update latest cost
                item.UpdatedAt = DateTime.UtcNow;
            }
        }

        await _db.SaveChangesAsync();
        await _audit.LogAsync("InventoryTransaction", id, "Approve", userId);
        return true;
    }

    public async Task<bool> RejectTransactionAsync(Guid id, string? comment, Guid userId)
    {
        var tx = await _db.InventoryTransactions.FindAsync(id);
        if (tx == null) return false;

        tx.ApprovalStatus = ApprovalStatus.Rejected;
        tx.ApprovalComment = comment;
        tx.ApprovedBy = userId;
        tx.ApprovedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        await _audit.LogAsync("InventoryTransaction", id, "Reject", userId);
        return true;
    }

    private async Task<InventoryTransactionDto?> GetTransactionByIdAsync(Guid id)
    {
        var tx = await _db.InventoryTransactions
            .Include(t => t.InventoryItem)
            .Include(t => t.Photos)
            .FirstOrDefaultAsync(t => t.Id == id);
        return tx == null ? null : MapTransaction(tx);
    }

    private static InventoryItemDto MapItem(InventoryItem i) => new(
        i.Id, i.Name, i.Description, i.Category, i.Unit,
        i.CurrentStock, i.UnitCost, i.TotalValue,
        i.SupplierId, i.Supplier?.Name,
        i.Photos?.Select(FileService.MapFile).ToList() ?? new(), i.CreatedAt);

    private static InventoryTransactionDto MapTransaction(InventoryTransaction t) => new(
        t.Id, t.InventoryItemId, t.InventoryItem?.Name ?? "",
        t.Type, t.Quantity, t.UnitCost, t.TotalCost,
        t.OrderId, t.Notes, t.ApprovalStatus,
        t.Photos?.Select(FileService.MapFile).ToList() ?? new(), t.CreatedAt);
}
