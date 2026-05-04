using Microsoft.EntityFrameworkCore;
using TailorShop.Application.DTOs;
using TailorShop.Domain.Entities;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Application.Services;

public class SpendingService
{
    private readonly AppDbContext _db;
    private readonly AuditService _audit;

    public SpendingService(AppDbContext db, AuditService audit)
    {
        _db = db;
        _audit = audit;
    }

    public async Task<List<SpendingDto>> GetSpendingsAsync(
        ApprovalStatus? status = null,
        SpendingCategory? category = null,
        SpendingResultType? resultType = null,
        DateTime? from = null,
        DateTime? to = null)
    {
        var query = _db.Spendings
            .Include(s => s.FundingSplits).ThenInclude(f => f.Partner).ThenInclude(p => p.User)
            .AsQueryable();

        if (status.HasValue) query = query.Where(s => s.ApprovalStatus == status.Value);
        if (category.HasValue) query = query.Where(s => s.Category == category.Value);
        if (resultType.HasValue) query = query.Where(s => s.ResultType == resultType.Value);
        if (from.HasValue) query = query.Where(s => s.SpendingDate >= from.Value);
        if (to.HasValue) query = query.Where(s => s.SpendingDate <= to.Value);

        var spendings = await query.OrderByDescending(s => s.SpendingDate).ToListAsync();
        return spendings.Select(MapSpending).ToList();
    }

    public async Task<SpendingDto?> GetSpendingByIdAsync(Guid id)
    {
        var spending = await _db.Spendings
            .Include(s => s.FundingSplits).ThenInclude(f => f.Partner).ThenInclude(p => p.User)
            .FirstOrDefaultAsync(s => s.Id == id);
        return spending == null ? null : MapSpending(spending);
    }

    public async Task<(SpendingDto spending, string? warning)> CreateSpendingAsync(CreateSpendingRequest request, Guid userId)
    {
        // Validate funding split total (allow ±1 for rounding from mobile)
        var splitTotal = request.FundingSplits.Sum(f => f.Amount);
        if (Math.Abs(splitTotal - request.TotalAmount) > 1m)
            throw new InvalidOperationException($"Funding split total ({splitTotal}) must equal spending total ({request.TotalAmount}).");

        // Validate asset ownership if applicable
        if (request.ResultType == SpendingResultType.Asset && request.Asset != null)
        {
            var ownershipTotal = request.Asset.Ownerships.Sum(o => o.OwnershipPercent);
            if (Math.Abs(ownershipTotal - 100m) > 0.01m)
                throw new InvalidOperationException($"Asset ownership percentages must total 100%. Current total: {ownershipTotal}%.");
        }

        string? warning = null;

        // Check for negative balances (warn but allow)
        foreach (var split in request.FundingSplits)
        {
            var balance = await GetPartnerBalanceAsync(split.PartnerId);
            var afterBalance = balance - split.Amount;
            if (afterBalance < 0)
                warning = (warning == null ? "" : warning + " | ") +
                    $"Partner balance will become negative after this spending.";
        }

        // Generate spending number
        var spendingNo = await GenerateSpendingNoAsync();

        var spending = new Spending
        {
            SpendingNo = spendingNo,
            SpendingDate = request.SpendingDate.HasValue
                ? DateTime.SpecifyKind(request.SpendingDate.Value, DateTimeKind.Utc)
                : DateTime.UtcNow,
            Category = request.Category,
            Description = request.Description,
            TotalAmount = request.TotalAmount,
            ResultType = request.ResultType,
            OwnershipApplicable = request.OwnershipApplicable,
            ReceiptFileUrl = request.ReceiptFileUrl,
            Notes = request.Notes,
            ApprovalStatus = ApprovalStatus.PendingApproval,
            CreatedBy = userId
        };

        _db.Spendings.Add(spending);
        await _db.SaveChangesAsync();

        // Add funding splits
        foreach (var splitReq in request.FundingSplits)
        {
            var split = new SpendingFundingSplit
            {
                SpendingId = spending.Id,
                PartnerId = splitReq.PartnerId,
                Amount = splitReq.Amount,
                Notes = splitReq.Notes,
                CreatedBy = userId
            };
            _db.SpendingFundingSplits.Add(split);
        }

        // Create result record based on type
        if (request.ResultType == SpendingResultType.Asset && request.Asset != null)
        {
            var assetReq = request.Asset;
            var asset = new Asset
            {
                Name = assetReq.Name,
                Description = assetReq.Description,
                AssetType = assetReq.AssetType,
                Quantity = assetReq.Quantity,
                UnitValue = assetReq.UnitValue,
                OwnershipType = assetReq.OwnershipType,
                SpendingId = spending.Id,
                Location = assetReq.Location,
                Condition = assetReq.Condition,
                Notes = assetReq.Notes,
                PurchaseDate = spending.SpendingDate,
                ApprovalStatus = ApprovalStatus.PendingApproval,
                CreatedBy = userId
            };
            _db.Assets.Add(asset);
            await _db.SaveChangesAsync();

            foreach (var ownerReq in assetReq.Ownerships)
            {
                _db.AssetOwnerships.Add(new AssetOwnership
                {
                    AssetId = asset.Id,
                    OwnerType = ownerReq.OwnerType,
                    PartnerId = ownerReq.PartnerId,
                    OwnershipPercent = ownerReq.OwnershipPercent,
                    OwnershipValue = ownerReq.OwnershipValue,
                    CreatedBy = userId
                });
            }
        }
        else if (request.ResultType == SpendingResultType.Inventory && request.InventoryItems != null)
        {
            foreach (var invReq in request.InventoryItems)
            {
                _db.InventoryTransactions.Add(new InventoryTransaction
                {
                    SpendingId = spending.Id,
                    InventoryItemId = invReq.InventoryItemId,
                    Type = InventoryTransactionType.Purchase,
                    Quantity = invReq.Quantity,
                    UnitCost = invReq.UnitCost,
                    SupplierName = invReq.SupplierName,
                    Notes = invReq.Notes,
                    ApprovalStatus = ApprovalStatus.PendingApproval,
                    CreatedBy = userId
                });
            }
        }
        await _db.SaveChangesAsync();
        await _audit.LogAsync("Spending", spending.Id, "Create", userId);

        var result = await GetSpendingByIdAsync(spending.Id);
        return (result!, warning);
    }

    public async Task<bool> ApproveAsync(Guid id, string? comment, Guid userId)
    {
        var spending = await _db.Spendings
            .Include(s => s.FundingSplits)
            .FirstOrDefaultAsync(s => s.Id == id);
        if (spending == null) return false;

        spending.ApprovalStatus = ApprovalStatus.Approved;
        spending.ApprovalComment = comment;
        spending.ApprovedBy = userId;
        spending.ApprovedAt = DateTime.UtcNow;
        spending.UpdatedAt = DateTime.UtcNow;
        spending.UpdatedBy = userId;

        // Approve child records too
        var asset = await _db.Assets.FirstOrDefaultAsync(a => a.SpendingId == id);
        if (asset != null)
        {
            asset.ApprovalStatus = ApprovalStatus.Approved;
            asset.ApprovedBy = userId;
            asset.ApprovedAt = DateTime.UtcNow;
        }

        var invTransactions = await _db.InventoryTransactions.Where(t => t.SpendingId == id).ToListAsync();
        foreach (var tx in invTransactions)
        {
            tx.ApprovalStatus = ApprovalStatus.Approved;
            tx.ApprovedBy = userId;
            tx.ApprovedAt = DateTime.UtcNow;

            // Update stock
            var item = await _db.InventoryItems.FindAsync(tx.InventoryItemId);
            if (item != null)
            {
                item.CurrentStock += tx.Quantity;
                item.UnitCost = tx.UnitCost; // Update with latest cost
            }
        }

        await _db.SaveChangesAsync();
        await _audit.LogAsync("Spending", id, "Approve", userId);
        return true;
    }

    public async Task<bool> RejectAsync(Guid id, string? comment, Guid userId)
    {
        var spending = await _db.Spendings.FindAsync(id);
        if (spending == null) return false;

        spending.ApprovalStatus = ApprovalStatus.Rejected;
        spending.ApprovalComment = comment;
        spending.ApprovedBy = userId;
        spending.ApprovedAt = DateTime.UtcNow;
        spending.UpdatedAt = DateTime.UtcNow;
        spending.UpdatedBy = userId;

        await _db.SaveChangesAsync();
        await _audit.LogAsync("Spending", id, "Reject", userId);
        return true;
    }

    // Calculate a partner's current capital balance
    public async Task<decimal> GetPartnerBalanceAsync(Guid partnerId)
    {
        var capitalAdded = await _db.CapitalTransactions
            .Where(ct => ct.PartnerId == partnerId
                && ct.ApprovalStatus == ApprovalStatus.Approved
                && (ct.Type == CapitalTransactionType.CapitalAdvance
                    || ct.Type == CapitalTransactionType.AdditionalCapital))
            .SumAsync(ct => ct.Amount);

        var positiveAdj = await _db.CapitalTransactions
            .Where(ct => ct.PartnerId == partnerId
                && ct.ApprovalStatus == ApprovalStatus.Approved
                && ct.Type == CapitalTransactionType.Adjustment
                && ct.Amount > 0)
            .SumAsync(ct => ct.Amount);

        var withdrawals = await _db.CapitalTransactions
            .Where(ct => ct.PartnerId == partnerId
                && ct.ApprovalStatus == ApprovalStatus.Approved
                && ct.Type == CapitalTransactionType.Withdrawal)
            .SumAsync(ct => ct.Amount);

        var negativeAdj = await _db.CapitalTransactions
            .Where(ct => ct.PartnerId == partnerId
                && ct.ApprovalStatus == ApprovalStatus.Approved
                && ct.Type == CapitalTransactionType.Adjustment
                && ct.Amount < 0)
            .SumAsync(ct => (decimal?)ct.Amount) ?? 0m;

        var fundedSpendings = await _db.SpendingFundingSplits
            .Where(f => f.PartnerId == partnerId
                && f.Spending.ApprovalStatus == ApprovalStatus.Approved)
            .SumAsync(f => f.Amount);

        return capitalAdded + positiveAdj - withdrawals - Math.Abs(negativeAdj) - fundedSpendings;
    }

    private Task<string> GenerateSpendingNoAsync()
    {
        var date = DateTime.UtcNow;
        var suffix = Guid.NewGuid().ToString()[..6].ToUpper();
        return Task.FromResult($"SPD-{date:yyyyMMdd}-{suffix}");
    }

    public static SpendingDto MapSpending(Spending s) => new(
        s.Id, s.SpendingNo, s.SpendingDate, s.Category, s.Description,
        s.TotalAmount, s.ResultType, s.OwnershipApplicable,
        s.ReceiptFileUrl, s.Notes, s.ApprovalStatus, s.ApprovalComment,
        s.ApprovedAt,
        s.FundingSplits?.Select(f => new SpendingFundingSplitDto(
            f.Id, f.PartnerId, f.Partner?.User?.FullName ?? "", f.Amount, f.Notes
        )).ToList() ?? new(),
        s.CreatedAt);
}
