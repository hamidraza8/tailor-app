using Microsoft.EntityFrameworkCore;
using TailorShop.Application.DTOs;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Application.Services;

public class PartnerBalanceService
{
    private readonly AppDbContext _db;

    public PartnerBalanceService(AppDbContext db) => _db = db;

    public async Task<CapitalSummaryDto> GetCapitalSummaryAsync()
    {
        var partners = await _db.Partners
            .Include(p => p.User)
            .Where(p => p.IsActive)
            .ToListAsync();

        var balances = new List<PartnerBalanceReportDto>();
        foreach (var partner in partners)
            balances.Add(await GetPartnerBalanceAsync(partner.Id));

        var totalCapital = balances.Sum(b => b.TotalCapitalAdded);
        var totalSpent = balances.Sum(b => b.TotalFundedSpendings + b.TotalWithdrawals);
        var totalRemaining = balances.Sum(b => b.RemainingBalance);
        var totalDeficits = balances.Where(b => b.IsDeficit).Sum(b => b.DeficitAmount);

        return new CapitalSummaryDto(totalCapital, totalSpent, totalRemaining, totalDeficits, balances);
    }

    public async Task<PartnerBalanceReportDto> GetPartnerBalanceAsync(Guid partnerId)
    {
        var partner = await _db.Partners
            .Include(p => p.User)
            .FirstOrDefaultAsync(p => p.Id == partnerId)
            ?? throw new KeyNotFoundException($"Partner {partnerId} not found.");

        // Capital added (CapitalAdvance + AdditionalCapital + positive Adjustments)
        var capitalTxs = await _db.CapitalTransactions
            .Where(ct => ct.PartnerId == partnerId && ct.ApprovalStatus == ApprovalStatus.Approved)
            .ToListAsync();

        decimal capitalAdded = capitalTxs
            .Where(ct => ct.Type is CapitalTransactionType.CapitalAdvance or CapitalTransactionType.AdditionalCapital)
            .Sum(ct => ct.Amount);
        capitalAdded += capitalTxs
            .Where(ct => ct.Type == CapitalTransactionType.Adjustment && ct.Amount > 0)
            .Sum(ct => ct.Amount);

        decimal withdrawals = capitalTxs
            .Where(ct => ct.Type == CapitalTransactionType.Withdrawal)
            .Sum(ct => ct.Amount);
        withdrawals += Math.Abs(capitalTxs
            .Where(ct => ct.Type == CapitalTransactionType.Adjustment && ct.Amount < 0)
            .Sum(ct => ct.Amount));

        // Funded spendings (only approved)
        var fundingSplits = await _db.SpendingFundingSplits
            .Include(f => f.Spending)
            .Where(f => f.PartnerId == partnerId && f.Spending.ApprovalStatus == ApprovalStatus.Approved)
            .ToListAsync();

        decimal totalFunded = fundingSplits.Sum(f => f.Amount);
        decimal assetFunding = fundingSplits.Where(f => f.Spending.ResultType == SpendingResultType.Asset).Sum(f => f.Amount);
        decimal invFunding = fundingSplits.Where(f => f.Spending.ResultType == SpendingResultType.Inventory).Sum(f => f.Amount);
        decimal expFunding = fundingSplits.Where(f => f.Spending.ResultType == SpendingResultType.Expense).Sum(f => f.Amount);

        decimal remaining = capitalAdded - withdrawals - totalFunded;
        bool isDeficit = remaining < 0;
        decimal deficit = isDeficit ? Math.Abs(remaining) : 0;

        // Asset ownership value
        decimal assetOwnershipValue = await _db.AssetOwnerships
            .Where(ao => ao.PartnerId == partnerId)
            .SumAsync(ao => ao.OwnershipValue);

        // Capital lines
        var capitalLines = capitalTxs
            .Select(ct => new PartnerCapitalLineDto(ct.Id, ct.Type, ct.Amount, ct.TransactionDate, ct.Notes))
            .ToList();

        // Spending lines
        var spendingLines = fundingSplits
            .Select(f => new PartnerSpendingLineDto(
                f.SpendingId, f.Spending.SpendingNo, f.Spending.Category,
                f.Spending.Description, f.Amount, f.Spending.ResultType, f.Spending.SpendingDate))
            .ToList();

        return new PartnerBalanceReportDto(
            partnerId, partner.User?.FullName ?? "",
            capitalAdded, totalFunded, withdrawals, remaining,
            isDeficit, deficit, assetOwnershipValue,
            invFunding, expFunding, assetFunding,
            capitalLines, spendingLines);
    }

    public async Task<List<FundingSplitReportDto>> GetFundingSplitReportAsync(DateTime? from = null, DateTime? to = null)
    {
        var query = _db.Spendings
            .Include(s => s.FundingSplits).ThenInclude(f => f.Partner).ThenInclude(p => p.User)
            .AsQueryable();

        if (from.HasValue) query = query.Where(s => s.SpendingDate >= from.Value);
        if (to.HasValue) query = query.Where(s => s.SpendingDate <= to.Value);

        var spendings = await query.OrderByDescending(s => s.SpendingDate).ToListAsync();

        return spendings.Select(s => new FundingSplitReportDto(
            s.Id, s.SpendingNo, s.SpendingDate, s.Category, s.Description,
            s.TotalAmount, s.ResultType, s.ApprovalStatus,
            s.FundingSplits.Select(f => new SpendingFundingSplitDto(
                f.Id, f.PartnerId, f.Partner?.User?.FullName ?? "", f.Amount, f.Notes
            )).ToList()
        )).ToList();
    }

    public async Task<List<AssetOwnershipReportDto>> GetAssetOwnershipReportAsync()
    {
        var assets = await _db.Assets
            .Include(a => a.Ownerships).ThenInclude(o => o.Partner).ThenInclude(p => p!.User)
            .Where(a => a.SpendingId != null)
            .OrderByDescending(a => a.CreatedAt)
            .ToListAsync();

        return assets.Select(a => new AssetOwnershipReportDto(
            a.Id, a.Name, a.AssetType, a.Quantity, a.UnitValue, a.TotalValue,
            a.OwnershipType,
            a.Ownerships.Select(o => new AssetOwnershipDto(
                o.Id, o.AssetId, o.OwnerType, o.PartnerId,
                o.Partner?.User?.FullName, o.OwnershipPercent, o.OwnershipValue
            )).ToList()
        )).ToList();
    }
}
