using Microsoft.EntityFrameworkCore;
using TailorShop.Application.DTOs;
using TailorShop.Domain.Entities;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Application.Services;

public class CapitalTransactionService
{
    private readonly AppDbContext _db;
    private readonly AuditService _audit;

    public CapitalTransactionService(AppDbContext db, AuditService audit)
    {
        _db = db;
        _audit = audit;
    }

    public async Task<List<CapitalTransactionDto>> GetByPartnerAsync(Guid partnerId)
    {
        var txs = await _db.CapitalTransactions
            .Include(ct => ct.Partner).ThenInclude(p => p.User)
            .Where(ct => ct.PartnerId == partnerId)
            .OrderByDescending(ct => ct.TransactionDate)
            .ToListAsync();

        return txs.Select(MapTransaction).ToList();
    }

    public async Task<List<CapitalTransactionDto>> GetAllAsync()
    {
        var txs = await _db.CapitalTransactions
            .Include(ct => ct.Partner).ThenInclude(p => p.User)
            .OrderByDescending(ct => ct.TransactionDate)
            .ToListAsync();
        return txs.Select(MapTransaction).ToList();
    }

    public async Task<CapitalTransactionDto> CreateAsync(Guid partnerId, CreateCapitalTransactionRequest request, Guid userId)
    {
        var tx = new CapitalTransaction
        {
            PartnerId = partnerId,
            Type = request.Type,
            Amount = request.Amount,
            TransactionDate = request.TransactionDate.HasValue
                ? DateTime.SpecifyKind(request.TransactionDate.Value, DateTimeKind.Utc)
                : DateTime.UtcNow,
            Notes = request.Notes,
            ReceiptFileUrl = request.ReceiptFileUrl,
            ApprovalStatus = ApprovalStatus.Approved,
            ApprovedBy = userId,
            ApprovedAt = DateTime.UtcNow,
            CreatedBy = userId
        };

        _db.CapitalTransactions.Add(tx);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("CapitalTransaction", tx.Id, "Create", userId);

        await _db.Entry(tx).Reference(t => t.Partner).LoadAsync();
        await _db.Entry(tx.Partner).Reference(p => p.User).LoadAsync();
        return MapTransaction(tx);
    }

    private static CapitalTransactionDto MapTransaction(CapitalTransaction ct) => new(
        ct.Id, ct.PartnerId, ct.Partner?.User?.FullName ?? "",
        ct.Type, ct.Amount, ct.TransactionDate,
        ct.Notes, ct.ReceiptFileUrl, ct.ApprovalStatus, ct.CreatedAt);
}
