using Microsoft.EntityFrameworkCore;
using TailorShop.Application.DTOs;
using TailorShop.Domain.Entities;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Application.Services;

public class ReportService
{
    private readonly AppDbContext _db;

    public ReportService(AppDbContext db) => _db = db;

    public async Task<DashboardDto> GetDashboardAsync()
    {
        var today = DateTime.UtcNow.Date;
        var tomorrow = today.AddDays(1);

        var todaySales = await _db.Payments
            .Where(p => p.PaymentDate >= today && p.PaymentDate < tomorrow)
            .SumAsync(p => p.Amount);

        var pendingOrders = await _db.Orders
            .CountAsync(o => o.Status != OrderStatus.Delivered && o.Status != OrderStatus.Cancelled);

        var pendingAssets = await _db.Assets.CountAsync(a => a.ApprovalStatus == ApprovalStatus.PendingApproval);
        var pendingExpenses = await _db.Spendings.CountAsync(s => s.ResultType == SpendingResultType.Expense && s.ApprovalStatus == ApprovalStatus.PendingApproval);
        var pendingInventory = await _db.InventoryTransactions.CountAsync(t => t.ApprovalStatus == ApprovalStatus.PendingApproval);
        var pendingApprovals = pendingAssets + pendingExpenses + pendingInventory;

        var cashReceived = await _db.Payments
            .Where(p => p.PaymentDate >= today && p.PaymentDate < tomorrow && p.Method == PaymentMethod.Cash)
            .SumAsync(p => p.Amount);

        var inventoryValue = await _db.InventoryItems.SumAsync(i => i.CurrentStock * i.UnitCost);

        var assetValue = await _db.Assets
            .Where(a => a.ApprovalStatus == ApprovalStatus.Approved)
            .SumAsync(a => a.Quantity * a.UnitValue);

        var labourPayable = await _db.Orders
            .Where(o => o.Status != OrderStatus.Cancelled)
            .SumAsync(o => o.StitchingAmount * o.LabourSharePercentage / 100m);

        var totalRevenue = await _db.Orders
            .Where(o => o.Status != OrderStatus.Cancelled)
            .SumAsync(o => o.StitchingAmount + o.MaterialAmount - o.Discount);

        var totalExpenses = await _db.Spendings
            .Where(s => s.ResultType == SpendingResultType.Expense && s.ApprovalStatus == ApprovalStatus.Approved)
            .SumAsync(s => s.TotalAmount);

        var inventoryCost = await _db.OrderInventoryUsages.SumAsync(u => u.Quantity * u.UnitCost);

        var netProfit = totalRevenue - labourPayable - totalExpenses - inventoryCost;

        return new DashboardDto(todaySales, pendingOrders, pendingApprovals,
            cashReceived, inventoryValue, assetValue, labourPayable, netProfit);
    }

    public async Task<ProfitSummaryDto> GetProfitSummaryAsync(DateTime from, DateTime to)
    {
        // Ensure UTC kind for PostgreSQL compatibility
        if (from.Kind == DateTimeKind.Unspecified) from = DateTime.SpecifyKind(from, DateTimeKind.Utc);
        if (to.Kind == DateTimeKind.Unspecified) to = DateTime.SpecifyKind(to, DateTimeKind.Utc);

        var orders = await _db.Orders
            .Where(o => o.OrderDate >= from && o.OrderDate <= to && o.Status != OrderStatus.Cancelled)
            .ToListAsync();

        var totalRevenue = orders.Sum(o => o.TotalAmount);
        var totalLabour = orders.Sum(o => o.LabourAmount);

        var inventoryCost = await _db.OrderInventoryUsages
            .Where(u => u.CreatedAt >= from && u.CreatedAt <= to)
            .SumAsync(u => u.Quantity * u.UnitCost);

        var totalExpenses = await _db.Spendings
            .Where(s => s.ResultType == SpendingResultType.Expense
                && s.ApprovalStatus == ApprovalStatus.Approved
                && s.SpendingDate >= from && s.SpendingDate <= to)
            .SumAsync(s => s.TotalAmount);

        var netProfit = totalRevenue - totalLabour - inventoryCost - totalExpenses;

        var partners = await _db.Partners.Include(p => p.User).ToListAsync();
        var partnerProfits = partners.Select(p => new PartnerProfitDto(
            p.Id, p.User?.FullName ?? "", p.ProfitSharePercentage,
            netProfit * p.ProfitSharePercentage / 100m)).ToList();

        return new ProfitSummaryDto(totalRevenue, totalLabour, inventoryCost,
            totalExpenses, netProfit, partnerProfits, from, to);
    }

    public async Task<LabourReportDto> GetLabourReportAsync(DateTime? from = null, DateTime? to = null)
    {
        if (from.HasValue && from.Value.Kind == DateTimeKind.Unspecified)
            from = DateTime.SpecifyKind(from.Value, DateTimeKind.Utc);
        if (to.HasValue && to.Value.Kind == DateTimeKind.Unspecified)
            to = DateTime.SpecifyKind(to.Value, DateTimeKind.Utc);

        var query = _db.Orders
            .Include(o => o.Customer)
            .Where(o => o.Status != OrderStatus.Cancelled);

        if (from.HasValue) query = query.Where(o => o.OrderDate >= from.Value);
        if (to.HasValue) query = query.Where(o => o.OrderDate <= to.Value);

        var orders = await query.OrderByDescending(o => o.OrderDate).ToListAsync();

        var items = orders.Select(o => new LabourItemDto(
            o.Id, o.OrderNumber, o.Customer?.Name ?? "",
            o.StitchingAmount, o.LabourSharePercentage, o.LabourAmount, o.OrderDate)).ToList();

        return new LabourReportDto(items, items.Sum(i => i.LabourAmount));
    }

    public async Task<decimal> GetInventoryValueAsync()
    {
        return await _db.InventoryItems.SumAsync(i => i.CurrentStock * i.UnitCost);
    }

    public async Task<decimal> GetAssetValueAsync()
    {
        return await _db.Assets
            .Where(a => a.ApprovalStatus == ApprovalStatus.Approved)
            .SumAsync(a => a.Quantity * a.UnitValue);
    }
}
