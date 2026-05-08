using Microsoft.EntityFrameworkCore;
using TailorShop.Application.DTOs;
using TailorShop.Domain.Entities;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Application.Services;

public class OrderService
{
    private readonly AppDbContext _db;
    private readonly AuditService _audit;

    public OrderService(AppDbContext db, AuditService audit)
    {
        _db = db;
        _audit = audit;
    }

    public async Task<List<OrderDto>> GetOrdersAsync(DateTime? from = null, DateTime? to = null,
        OrderStatus? status = null, Guid? customerId = null)
    {
        var query = _db.Orders
            .Include(o => o.Customer)
            .Include(o => o.Photos)
            .AsQueryable();

        if (from.HasValue) query = query.Where(o => o.OrderDate >= from.Value);
        if (to.HasValue) query = query.Where(o => o.OrderDate <= to.Value);
        if (status.HasValue) query = query.Where(o => o.Status == status.Value);
        if (customerId.HasValue) query = query.Where(o => o.CustomerId == customerId.Value);

        var orders = await query.OrderByDescending(o => o.CreatedAt).ToListAsync();
        return orders.Select(MapOrder).ToList();
    }

    public async Task<List<OrderDto>> GetTodaysOrdersAsync()
    {
        var pkt = TimeZoneInfo.FindSystemTimeZoneById("Asia/Karachi");
        var today = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, pkt).Date;
        var fromUtc = TimeZoneInfo.ConvertTimeToUtc(today, pkt);
        var toUtc = TimeZoneInfo.ConvertTimeToUtc(today.AddDays(1), pkt);
        return await GetOrdersAsync(from: fromUtc, to: toUtc);
    }

    public async Task<OrderDto?> GetOrderByIdAsync(Guid id)
    {
        var order = await _db.Orders
            .Include(o => o.Customer)
            .Include(o => o.Photos)
            .Include(o => o.Payments)
            .Include(o => o.InventoryUsages).ThenInclude(u => u.InventoryItem)
            .Include(o => o.StatusHistory)
            .FirstOrDefaultAsync(o => o.Id == id);
        return order == null ? null : MapOrder(order);
    }

    public async Task<OrderDto> CreateOrderAsync(CreateOrderRequest request, Guid userId)
    {
        var profile = await _db.BusinessProfiles.FirstOrDefaultAsync();
        var orderNumber = await GenerateOrderNumber();

        var order = new Order
        {
            OrderNumber = orderNumber,
            CustomerId = request.CustomerId,
            OrderType = request.OrderType,
            CustomOrderType = request.CustomOrderType,
            MeasurementId = request.MeasurementId,
            StitchingAmount = request.StitchingAmount,
            MaterialAmount = request.MaterialAmount,
            Discount = request.Discount,
            DueDate = request.DueDate.HasValue
                ? DateTime.SpecifyKind(request.DueDate.Value, DateTimeKind.Utc)
                : null,
            DesignNotes = request.DesignNotes,
            SpecialInstructions = request.SpecialInstructions,
            IsUrgent = request.IsUrgent,
            LabourSharePercentage = request.LabourSharePercentage ??
                profile?.DefaultLabourSharePercentage ?? 35m,
            CreatedBy = userId,
            StatusHistory = new List<OrderStatusHistory>
            {
                new()
                {
                    FromStatus = OrderStatus.Received,
                    ToStatus = OrderStatus.Received,
                    Notes = "Order created",
                    CreatedBy = userId
                }
            }
        };

        // Handle advance payment
        if (request.AdvancePayment.HasValue && request.AdvancePayment > 0)
        {
            order.PaidAmount = request.AdvancePayment.Value;
            order.Payments.Add(new Payment
            {
                OrderId = order.Id,
                CustomerId = request.CustomerId,
                Amount = request.AdvancePayment.Value,
                Method = PaymentMethod.Cash,
                Notes = "Advance payment",
                CreatedBy = userId
            });
        }

        _db.Orders.Add(order);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("Order", order.Id, "Create", userId);

        return (await GetOrderByIdAsync(order.Id))!;
    }

    public async Task<OrderDto?> UpdateOrderAsync(Guid id, UpdateOrderRequest request, Guid userId)
    {
        var order = await _db.Orders.FindAsync(id);
        if (order == null) return null;

        order.OrderType = request.OrderType;
        order.CustomOrderType = request.CustomOrderType;
        order.MeasurementId = request.MeasurementId;
        order.StitchingAmount = request.StitchingAmount;
        order.MaterialAmount = request.MaterialAmount;
        order.Discount = request.Discount;
        order.DueDate = request.DueDate;
        order.DesignNotes = request.DesignNotes;
        order.SpecialInstructions = request.SpecialInstructions;
        order.IsUrgent = request.IsUrgent;
        if (request.LabourSharePercentage.HasValue)
            order.LabourSharePercentage = request.LabourSharePercentage.Value;
        order.UpdatedAt = DateTime.UtcNow;
        order.UpdatedBy = userId;

        await _db.SaveChangesAsync();
        await _audit.LogAsync("Order", id, "Update", userId);
        return await GetOrderByIdAsync(id);
    }

    public async Task<OrderDto?> UpdateStatusAsync(Guid id, UpdateOrderStatusRequest request, Guid userId)
    {
        var order = await _db.Orders.FindAsync(id);
        if (order == null) return null;

        var history = new OrderStatusHistory
        {
            OrderId = id,
            FromStatus = order.Status,
            ToStatus = request.Status,
            Notes = request.Notes,
            CreatedBy = userId
        };

        order.Status = request.Status;
        if (request.Status == OrderStatus.Delivered)
            order.DeliveryDate = DateTime.UtcNow;
        order.UpdatedAt = DateTime.UtcNow;
        order.UpdatedBy = userId;

        _db.OrderStatusHistory.Add(history);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("Order", id, "StatusChange", userId);
        return await GetOrderByIdAsync(id);
    }

    public async Task AddInventoryUsageAsync(Guid orderId, OrderInventoryUsageRequest request, Guid userId)
    {
        var usage = new OrderInventoryUsage
        {
            OrderId = orderId,
            InventoryItemId = request.InventoryItemId,
            Quantity = request.Quantity,
            UnitCost = request.UnitCost,
            Notes = request.Notes,
            CreatedBy = userId
        };

        // Update inventory stock
        var item = await _db.InventoryItems.FindAsync(request.InventoryItemId);
        if (item != null)
        {
            item.CurrentStock -= request.Quantity;
            item.UpdatedAt = DateTime.UtcNow;
        }

        _db.OrderInventoryUsages.Add(usage);
        await _db.SaveChangesAsync();
    }

    private async Task<string> GenerateOrderNumber()
    {
        var today = DateTime.UtcNow;
        var prefix = $"ORD-{today:yyyyMMdd}";
        var count = await _db.Orders.CountAsync(o => o.OrderNumber.StartsWith(prefix));
        return $"{prefix}-{(count + 1):D3}";
    }

    public static OrderDto MapOrder(Order o) => new(
        o.Id, o.OrderNumber, o.CustomerId,
        o.Customer?.Name ?? "", o.Customer?.Phone ?? "",
        o.OrderType, o.CustomOrderType, o.Status, o.MeasurementId,
        o.StitchingAmount, o.MaterialAmount, o.Discount,
        o.TotalAmount, o.PaidAmount, o.BalanceAmount,
        o.OrderDate, o.DueDate, o.DeliveryDate,
        o.DesignNotes, o.SpecialInstructions, o.IsUrgent,
        o.LabourSharePercentage, o.LabourAmount,
        o.Photos?.Select(FileService.MapFile).ToList() ?? new(),
        o.CreatedAt);
}
