using Microsoft.EntityFrameworkCore;
using TailorShop.Application.DTOs;
using TailorShop.Domain.Entities;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Application.Services;

public class PaymentService
{
    private readonly AppDbContext _db;
    private readonly AuditService _audit;

    public PaymentService(AppDbContext db, AuditService audit)
    {
        _db = db;
        _audit = audit;
    }

    public async Task<PaymentDto> CreatePaymentAsync(CreatePaymentRequest request, Guid userId)
    {
        var order = await _db.Orders.Include(o => o.Customer).FirstOrDefaultAsync(o => o.Id == request.OrderId);
        if (order == null) throw new Exception("Order not found");

        var payment = new Payment
        {
            OrderId = request.OrderId,
            CustomerId = order.CustomerId,
            Amount = request.Amount,
            Method = request.Method,
            PaymentDate = request.PaymentDate ?? DateTime.UtcNow,
            Notes = request.Notes,
            ReceivedByUserId = userId.ToString(),
            CreatedBy = userId
        };

        order.PaidAmount += request.Amount;
        order.UpdatedAt = DateTime.UtcNow;

        _db.Payments.Add(payment);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("Payment", payment.Id, "Create", userId);

        return new PaymentDto(payment.Id, payment.OrderId, order.OrderNumber,
            payment.CustomerId, order.Customer?.Name ?? "", payment.Amount,
            payment.Method, payment.PaymentDate, payment.Notes, payment.CreatedAt);
    }

    public async Task<List<PaymentDto>> GetPaymentsByOrderAsync(Guid orderId)
    {
        var payments = await _db.Payments
            .Include(p => p.Order)
            .Include(p => p.Customer)
            .Where(p => p.OrderId == orderId)
            .OrderByDescending(p => p.CreatedAt)
            .ToListAsync();

        return payments.Select(p => new PaymentDto(
            p.Id, p.OrderId, p.Order?.OrderNumber ?? "",
            p.CustomerId, p.Customer?.Name ?? "", p.Amount,
            p.Method, p.PaymentDate, p.Notes, p.CreatedAt)).ToList();
    }

    public async Task<List<PaymentDto>> GetAllPaymentsAsync(DateTime? from = null, DateTime? to = null)
    {
        var query = _db.Payments
            .Include(p => p.Order)
            .Include(p => p.Customer)
            .AsQueryable();

        if (from.HasValue) query = query.Where(p => p.PaymentDate >= from.Value);
        if (to.HasValue) query = query.Where(p => p.PaymentDate <= to.Value);

        var payments = await query.OrderByDescending(p => p.CreatedAt).ToListAsync();
        return payments.Select(p => new PaymentDto(
            p.Id, p.OrderId, p.Order?.OrderNumber ?? "",
            p.CustomerId, p.Customer?.Name ?? "", p.Amount,
            p.Method, p.PaymentDate, p.Notes, p.CreatedAt)).ToList();
    }
}
