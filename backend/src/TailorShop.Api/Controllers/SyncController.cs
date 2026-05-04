using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TailorShop.Api.Extensions;
using TailorShop.Application.DTOs;
using TailorShop.Domain.Entities;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/sync")]
[Authorize]
public class SyncController : ControllerBase
{
    private readonly AppDbContext _db;

    public SyncController(AppDbContext db) => _db = db;

    [HttpPost("push")]
    public async Task<IActionResult> Push([FromBody] SyncPushRequest request)
    {
        var results = new List<SyncPushResult>();
        var userId = User.GetUserId();
        var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

        foreach (var item in request.Items)
        {
            try
            {
                Guid? serverId = null;
                var json = JsonDocument.Parse(item.PayloadJson);
                var root = json.RootElement;

                // Handle delete operations for any entity type
                if (item.Operation.ToLower() == "delete")
                {
                    var idStr = GetString(root, "id");
                    if (Guid.TryParse(idStr, out var deleteId))
                    {
                        var now = DateTime.UtcNow;
                        switch (item.EntityType.ToLower())
                        {
                            case "order":
                                var delOrder = await _db.Orders.FindAsync(deleteId);
                                if (delOrder != null) { delOrder.IsDeleted = true; delOrder.UpdatedBy = userId; delOrder.UpdatedAt = now; }
                                break;
                            case "spending": case "expense":
                                var delSpending = await _db.Spendings.FindAsync(deleteId);
                                if (delSpending != null) { delSpending.IsDeleted = true; delSpending.UpdatedBy = userId; delSpending.UpdatedAt = now; }
                                break;
                            case "asset":
                                var delAsset = await _db.Assets.FindAsync(deleteId);
                                if (delAsset != null) { delAsset.IsDeleted = true; delAsset.UpdatedBy = userId; delAsset.UpdatedAt = now; }
                                break;
                            case "inventory":
                                var delTx = await _db.InventoryTransactions.FindAsync(deleteId);
                                if (delTx != null) { delTx.IsDeleted = true; delTx.UpdatedBy = userId; delTx.UpdatedAt = now; }
                                break;
                            case "payment":
                                var delPayment = await _db.Payments.FindAsync(deleteId);
                                if (delPayment != null) { delPayment.IsDeleted = true; delPayment.UpdatedBy = userId; delPayment.UpdatedAt = now; }
                                break;
                            case "partner":
                                var delPartner = await _db.Partners.FindAsync(deleteId);
                                if (delPartner != null) { delPartner.IsDeleted = true; delPartner.UpdatedBy = userId; delPartner.UpdatedAt = now; }
                                break;
                        }
                        await _db.SaveChangesAsync();
                        serverId = deleteId;
                    }
                    else throw new Exception("Invalid or missing id in delete payload");
                }
                else if (item.Operation.ToLower() == "approve" || item.Operation.ToLower() == "reject")
                {
                    var idStr = GetString(root, "id");
                    if (Guid.TryParse(idStr, out var approveId))
                    {
                        var approve = item.Operation.ToLower() == "approve";
                        var newStatus = approve ? ApprovalStatus.Approved : ApprovalStatus.Rejected;
                        var now = DateTime.UtcNow;
                        switch (item.EntityType.ToLower())
                        {
                            case "spending": case "expense":
                                var spending = await _db.Spendings.FindAsync(approveId);
                                if (spending != null) { spending.ApprovalStatus = newStatus; spending.UpdatedBy = userId; spending.UpdatedAt = now; spending.ApprovedAt = now; }
                                break;
                            case "asset":
                                var asset = await _db.Assets.FindAsync(approveId);
                                if (asset != null) { asset.ApprovalStatus = newStatus; asset.UpdatedBy = userId; asset.UpdatedAt = now; }
                                break;
                            case "inventory":
                                var invTx = await _db.InventoryTransactions.FindAsync(approveId);
                                if (invTx != null) { invTx.ApprovalStatus = newStatus; invTx.UpdatedBy = userId; invTx.UpdatedAt = now; }
                                break;
                        }
                        await _db.SaveChangesAsync();
                        serverId = approveId;
                    }
                    else throw new Exception("Invalid or missing id in approve/reject payload");
                }
                else if (item.Operation.ToLower() == "update")
                {
                    var idStr = GetString(root, "id");
                    if (Guid.TryParse(idStr, out var updateId))
                    {
                        var now = DateTime.UtcNow;
                        switch (item.EntityType.ToLower())
                        {
                            case "order":
                                var order = await _db.Orders.FindAsync(updateId);
                                if (order != null)
                                {
                                    var stitching = GetDecimal(root, "stitchingAmount");
                                    var material = GetDecimal(root, "materialAmount");
                                    var discount = GetDecimal(root, "discount");
                                    var notes = GetString(root, "notes");
                                    var dueDate = GetDateTime(root, "dueDate");
                                    var statusStr = GetString(root, "status");
                                    if (stitching != 0) order.StitchingAmount = stitching;
                                    if (material != 0) order.MaterialAmount = material;
                                    order.Discount = discount;
                                    if (notes != null) order.DesignNotes = notes;
                                    if (dueDate.HasValue) order.DueDate = dueDate;
                                    if (statusStr != null && Enum.TryParse<OrderStatus>(statusStr, true, out var os)) order.Status = os;
                                    order.UpdatedBy = userId; order.UpdatedAt = now;
                                }
                                break;
                            case "asset":
                                var asset = await _db.Assets.FindAsync(updateId);
                                if (asset != null)
                                {
                                    var name = GetString(root, "name");
                                    var type = GetString(root, "assetType");
                                    var qty = GetInt(root, "quantity");
                                    var value = GetDecimal(root, "unitValue");
                                    var notes = GetString(root, "notes");
                                    if (name != null) asset.Name = name;
                                    if (type != null) asset.AssetType = type;
                                    if (qty != 0) asset.Quantity = qty;
                                    if (value != 0) asset.UnitValue = value;
                                    if (notes != null) asset.Notes = notes;
                                    asset.UpdatedBy = userId; asset.UpdatedAt = now;
                                }
                                break;
                            case "inventory":
                                var invTx = await _db.InventoryTransactions.FindAsync(updateId);
                                if (invTx != null)
                                {
                                    var costPerUnit = GetDecimal(root, "costPerUnit");
                                    var notes = GetString(root, "notes");
                                    if (costPerUnit != 0) invTx.UnitCost = costPerUnit;
                                    if (notes != null) invTx.Notes = notes;
                                    invTx.UpdatedBy = userId; invTx.UpdatedAt = now;
                                }
                                break;
                            case "partner":
                                var partner = await _db.Partners.FindAsync(updateId);
                                if (partner != null)
                                {
                                    var profit = GetDecimal(root, "profitSharePercentage");
                                    var labour = GetDecimal(root, "labourSharePercentage");
                                    var notes = GetString(root, "notes");
                                    if (profit != 0) partner.ProfitSharePercentage = profit;
                                    if (labour != 0) partner.LabourSharePercentage = labour;
                                    if (notes != null) partner.Notes = notes;
                                    partner.UpdatedBy = userId; partner.UpdatedAt = now;
                                }
                                break;
                        }
                        await _db.SaveChangesAsync();
                        serverId = updateId;
                    }
                    // No valid id — skip silently (malformed/legacy queue item)
                }
                else switch (item.EntityType.ToLower())
                {
                    case "customer":
                        var customer = new Customer
                        {
                            Name = GetString(root, "name") ?? "",
                            Phone = GetString(root, "phone") ?? "",
                            Email = GetString(root, "email"),
                            Address = GetString(root, "address"),
                            Notes = GetString(root, "notes"),
                            CreatedBy = userId
                        };
                        _db.Customers.Add(customer);
                        await _db.SaveChangesAsync();
                        serverId = customer.Id;
                        break;

                    case "order":
                        // Find customer by name/phone if no valid GUID
                        Guid customerId = Guid.Empty;
                        var custName = GetString(root, "customerName") ?? GetString(root, "customer_name");
                        var custPhone = GetString(root, "customerPhone") ?? GetString(root, "customer_phone");

                        if (!string.IsNullOrEmpty(custName))
                        {
                            var existingCust = await _db.Customers
                                .FirstOrDefaultAsync(c => c.Name == custName || c.Phone == (custPhone ?? ""));
                            if (existingCust != null)
                                customerId = existingCust.Id;
                            else
                            {
                                var newCust = new Customer { Name = custName, Phone = custPhone ?? "", CreatedBy = userId };
                                _db.Customers.Add(newCust);
                                await _db.SaveChangesAsync();
                                customerId = newCust.Id;
                            }
                        }

                        // Fallback: create a walk-in customer if none found
                        if (customerId == Guid.Empty)
                        {
                            var walkIn = await _db.Customers.FirstOrDefaultAsync(c => c.Name == "Walk-in Customer");
                            if (walkIn == null)
                            {
                                walkIn = new Customer { Name = "Walk-in Customer", Phone = "", CreatedBy = userId };
                                _db.Customers.Add(walkIn);
                                await _db.SaveChangesAsync();
                            }
                            customerId = walkIn.Id;
                        }

                        var orderTypeStr = GetString(root, "orderType") ?? "Suit";
                        var orderType = Enum.TryParse<OrderType>(orderTypeStr, true, out var ot)
                            ? ot : OrderType.Other;

                        var profile = await _db.BusinessProfiles.FirstOrDefaultAsync();
                        var orderNumber = $"ORD-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString()[..6].ToUpper()}";

                        var order = new Order
                        {
                            OrderNumber = orderNumber,
                            CustomerId = customerId,
                            OrderType = orderType,
                            StitchingAmount = GetDecimal(root, "stitchingAmount"),
                            MaterialAmount = GetDecimal(root, "materialAmount"),
                            Discount = GetDecimal(root, "discount"),
                            DueDate = GetDateTime(root, "dueDate"),
                            DesignNotes = GetString(root, "notes") ?? GetString(root, "designNotes"),
                            LabourSharePercentage = profile?.DefaultLabourSharePercentage ?? 35m,
                            PaidAmount = GetDecimal(root, "paidAmount"),
                            CreatedBy = userId,
                        };
                        _db.Orders.Add(order);
                        await _db.SaveChangesAsync();
                        serverId = order.Id;
                        break;

                    case "payment":
                        var paymentOrderId = GetGuid(root, "orderId");
                        // Try to find order by local ID or by most recent order for this user
                        if (paymentOrderId == Guid.Empty)
                        {
                            // Try matching by customer name if provided
                            var payCustomerName = GetString(root, "customerName");
                            if (!string.IsNullOrEmpty(payCustomerName))
                            {
                                var matchedOrder = await _db.Orders
                                    .Include(o => o.Customer)
                                    .Where(o => o.Customer != null && o.Customer.Name == payCustomerName)
                                    .OrderByDescending(o => o.CreatedAt)
                                    .FirstOrDefaultAsync();
                                if (matchedOrder != null) paymentOrderId = matchedOrder.Id;
                            }

                            // Fallback: get the most recent order created by this user
                            if (paymentOrderId == Guid.Empty)
                            {
                                var latestOrder = await _db.Orders
                                    .Where(o => o.CreatedBy == userId)
                                    .OrderByDescending(o => o.CreatedAt)
                                    .FirstOrDefaultAsync();
                                if (latestOrder != null) paymentOrderId = latestOrder.Id;
                            }
                        }

                        if (paymentOrderId != Guid.Empty)
                        {
                            var payOrder = await _db.Orders.Include(o => o.Customer).FirstOrDefaultAsync(o => o.Id == paymentOrderId);

                            // Resolve CustomerId — required FK
                            var payCustomerId = payOrder?.CustomerId ?? Guid.Empty;
                            if (payCustomerId == Guid.Empty)
                            {
                                var payCustomerName = GetString(root, "customerName");
                                if (!string.IsNullOrEmpty(payCustomerName))
                                {
                                    var cust = await _db.Customers.FirstOrDefaultAsync(c => c.Name == payCustomerName);
                                    if (cust != null) payCustomerId = cust.Id;
                                }
                            }
                            // Last resort: use the order's customer if still empty
                            if (payCustomerId == Guid.Empty && payOrder?.Customer != null)
                                payCustomerId = payOrder.Customer.Id;

                            if (payCustomerId == Guid.Empty)
                                throw new Exception("Could not resolve customer for payment");

                            var payment = new Payment
                            {
                                OrderId = paymentOrderId,
                                CustomerId = payCustomerId,
                                Amount = GetDecimal(root, "amount"),
                                Method = Enum.TryParse<PaymentMethod>(GetString(root, "method") ?? "Cash", true, out var pm)
                                    ? pm : PaymentMethod.Cash,
                                Notes = GetString(root, "notes"),
                                CreatedBy = userId,
                            };
                            _db.Payments.Add(payment);

                            if (payOrder != null)
                                payOrder.PaidAmount += payment.Amount;

                            await _db.SaveChangesAsync();
                            serverId = payment.Id;
                        }
                        else
                        {
                            throw new Exception("Could not find order to attach payment to");
                        }
                        break;

                    case "expense":
                        var syncSpending = new Spending
                        {
                            SpendingNo = $"SPD-SYNC-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString()[..4].ToUpper()}",
                            Category = SpendingCategory.Misc,
                            Description = GetString(root, "description") ?? GetString(root, "category") ?? "",
                            TotalAmount = GetDecimal(root, "amount"),
                            SpendingDate = GetDateTime(root, "expenseDate") ?? DateTime.UtcNow,
                            Notes = GetString(root, "notes"),
                            ResultType = SpendingResultType.Expense,
                            OwnershipApplicable = false,
                            ApprovalStatus = ApprovalStatus.PendingApproval,
                            CreatedBy = userId
                        };
                        _db.Spendings.Add(syncSpending);
                        await _db.SaveChangesAsync();
                        serverId = syncSpending.Id;
                        break;

                    case "asset":
                        var asset = new Asset
                        {
                            Name = GetString(root, "name") ?? "",
                            AssetType = GetString(root, "type") ?? GetString(root, "assetType") ?? "",
                            Quantity = GetInt(root, "quantity"),
                            UnitValue = GetDecimal(root, "unitValue") != 0 ? GetDecimal(root, "unitValue") : GetDecimal(root, "unit_value"),
                            Ownership = Enum.TryParse<LegacyAssetOwnership>(GetString(root, "owner") ?? "Company", true, out var ao)
                                ? ao : LegacyAssetOwnership.Company,
                            Notes = GetString(root, "notes"),
                            ApprovalStatus = ApprovalStatus.PendingApproval,
                            CreatedBy = userId
                        };
                        if (asset.Quantity == 0) asset.Quantity = 1;
                        _db.Assets.Add(asset);
                        await _db.SaveChangesAsync();
                        serverId = asset.Id;
                        break;

                    case "inventory":
                        var invItem = await _db.InventoryItems
                            .FirstOrDefaultAsync(i => i.Name == (GetString(root, "itemName") ?? ""));
                        if (invItem == null)
                        {
                            invItem = new InventoryItem
                            {
                                Name = GetString(root, "itemName") ?? GetString(root, "item_name") ?? "Unknown",
                                Category = "General",
                                Unit = GetString(root, "unit") ?? "pcs",
                                CurrentStock = 0,
                                UnitCost = GetDecimal(root, "costPerUnit") != 0 ? GetDecimal(root, "costPerUnit") : GetDecimal(root, "cost_per_unit"),
                                CreatedBy = userId
                            };
                            _db.InventoryItems.Add(invItem);
                            await _db.SaveChangesAsync();
                        }

                        var txQty = GetDecimal(root, "quantity");
                        var txUnitCost = GetDecimal(root, "costPerUnit") != 0
                            ? GetDecimal(root, "costPerUnit")
                            : invItem.UnitCost;
                        var tx = new InventoryTransaction
                        {
                            InventoryItemId = invItem.Id,
                            Type = InventoryTransactionType.Purchase,
                            Quantity = txQty,
                            UnitCost = txUnitCost,
                            Notes = GetString(root, "notes"),
                            ApprovalStatus = ApprovalStatus.PendingApproval,
                            CreatedBy = userId
                        };
                        _db.InventoryTransactions.Add(tx);
                        await _db.SaveChangesAsync();
                        serverId = tx.Id;
                        break;

                    case "capital":
                        var capitalPartnerId = GetGuid(root, "partnerId");
                        if (capitalPartnerId != Guid.Empty)
                        {
                            var capitalTypeStr = GetString(root, "transactionType") ?? "AdditionalCapital";
                            var capitalTx = new CapitalTransaction
                            {
                                PartnerId = capitalPartnerId,
                                Type = Enum.TryParse<CapitalTransactionType>(capitalTypeStr, true, out var ct) ? ct : CapitalTransactionType.AdditionalCapital,
                                Amount = GetDecimal(root, "amount"),
                                TransactionDate = GetDateTime(root, "transactionDate") ?? DateTime.UtcNow,
                                Notes = GetString(root, "notes"),
                                ApprovalStatus = ApprovalStatus.PendingApproval,
                                CreatedBy = userId
                            };
                            _db.CapitalTransactions.Add(capitalTx);
                            await _db.SaveChangesAsync();
                            serverId = capitalTx.Id;
                        }
                        break;

                    case "partner":
                        var partnerEmail = GetString(root, "email") ?? "";
                        var partnerUser = !string.IsNullOrEmpty(partnerEmail)
                            ? await _db.Users.FirstOrDefaultAsync(u => u.Email == partnerEmail)
                            : null;
                        if (partnerUser == null)
                        {
                            var rawPassword = GetString(root, "password");
                            partnerUser = new User
                            {
                                FullName = GetString(root, "fullName") ?? GetString(root, "name") ?? "",
                                Email = partnerEmail,
                                Phone = GetString(root, "phone") ?? "",
                                PasswordHash = BCrypt.Net.BCrypt.HashPassword(
                                    string.IsNullOrEmpty(rawPassword) ? "TempPass123!" : rawPassword),
                                Role = UserRole.Partner,
                                IsActive = true,
                                CreatedBy = userId
                            };
                            _db.Users.Add(partnerUser);
                            await _db.SaveChangesAsync();
                        }
                        var newPartner = new Partner
                        {
                            UserId = partnerUser.Id,
                            ProfitSharePercentage = GetDecimal(root, "profitSharePercentage"),
                            LabourSharePercentage = GetDecimal(root, "labourSharePercentage"),
                            Notes = GetString(root, "notes"),
                            IsActive = true,
                            CreatedBy = userId
                        };
                        _db.Partners.Add(newPartner);
                        await _db.SaveChangesAsync();
                        serverId = newPartner.Id;
                        break;
                }

                _db.SyncLogs.Add(new SyncLog
                {
                    DeviceId = Guid.Empty,
                    EntityType = item.EntityType,
                    Operation = item.Operation,
                    LocalId = item.LocalId,
                    ServerId = serverId,
                    Status = SyncStatus.Synced
                });

                results.Add(new SyncPushResult(item.LocalId, serverId, true, null));
            }
            catch (Exception ex)
            {
                results.Add(new SyncPushResult(item.LocalId, null, false, ex.Message));
            }
        }

        await _db.SaveChangesAsync();
        return Ok(new SyncPushResponse(results));
    }

    // Helper methods to safely extract values from JsonElement
    private static string? GetString(JsonElement el, string prop)
    {
        if (el.TryGetProperty(prop, out var val) && val.ValueKind == JsonValueKind.String)
            return val.GetString();
        // Try camelCase and snake_case variants
        var camel = char.ToLower(prop[0]) + prop[1..];
        if (el.TryGetProperty(camel, out val) && val.ValueKind == JsonValueKind.String)
            return val.GetString();
        return null;
    }

    private static decimal GetDecimal(JsonElement el, string prop)
    {
        if (el.TryGetProperty(prop, out var val))
        {
            if (val.ValueKind == JsonValueKind.Number) return val.GetDecimal();
            if (val.ValueKind == JsonValueKind.String && decimal.TryParse(val.GetString(), out var d)) return d;
        }
        return 0m;
    }

    private static int GetInt(JsonElement el, string prop)
    {
        if (el.TryGetProperty(prop, out var val))
        {
            if (val.ValueKind == JsonValueKind.Number) return val.GetInt32();
            if (val.ValueKind == JsonValueKind.String && int.TryParse(val.GetString(), out var i)) return i;
        }
        return 0;
    }

    private static Guid GetGuid(JsonElement el, string prop)
    {
        if (el.TryGetProperty(prop, out var val) && val.ValueKind == JsonValueKind.String)
        {
            if (Guid.TryParse(val.GetString(), out var g)) return g;
        }
        return Guid.Empty;
    }

    private static DateTime? GetDateTime(JsonElement el, string prop)
    {
        if (el.TryGetProperty(prop, out var val) && val.ValueKind == JsonValueKind.String)
        {
            if (DateTime.TryParse(val.GetString(), out var dt))
                return dt.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(dt, DateTimeKind.Utc) : dt.ToUniversalTime();
        }
        return null;
    }

    [HttpGet("pull")]
    public async Task<IActionResult> Pull([FromQuery] DateTime? lastSyncAt)
    {
        var since = lastSyncAt ?? DateTime.MinValue;
        var refOpts = new JsonSerializerOptions { ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles };
        var items = new List<SyncPullItem>();

        var customers = await _db.Customers.Where(c => c.CreatedAt > since || (c.UpdatedAt != null && c.UpdatedAt > since)).ToListAsync();
        items.AddRange(customers.Select(c => new SyncPullItem("customer", c.Id,
            JsonSerializer.Serialize(c), c.UpdatedAt ?? c.CreatedAt)));

        var orders = await _db.Orders.Include(o => o.Customer)
            .Where(o => o.CreatedAt > since || (o.UpdatedAt != null && o.UpdatedAt > since)).ToListAsync();
        items.AddRange(orders.Select(o => new SyncPullItem("order", o.Id,
            JsonSerializer.Serialize(o, refOpts), o.UpdatedAt ?? o.CreatedAt)));

        var payments = await _db.Payments
            .Where(p => p.CreatedAt > since || (p.UpdatedAt != null && p.UpdatedAt > since)).ToListAsync();
        items.AddRange(payments.Select(p => new SyncPullItem("payment", p.Id,
            JsonSerializer.Serialize(p, refOpts), p.UpdatedAt ?? p.CreatedAt)));

        var assets = await _db.Assets
            .Where(a => a.CreatedAt > since || (a.UpdatedAt != null && a.UpdatedAt > since)).ToListAsync();
        items.AddRange(assets.Select(a => new SyncPullItem("asset", a.Id,
            JsonSerializer.Serialize(a, refOpts), a.UpdatedAt ?? a.CreatedAt)));

        var invTxs = await _db.InventoryTransactions.Include(t => t.InventoryItem)
            .Where(t => t.CreatedAt > since || (t.UpdatedAt != null && t.UpdatedAt > since)).ToListAsync();
        items.AddRange(invTxs.Select(t => new SyncPullItem("inventory", t.Id,
            JsonSerializer.Serialize(t, refOpts), t.UpdatedAt ?? t.CreatedAt)));

        var spendings = await _db.Spendings
            .Where(s => s.CreatedAt > since || (s.UpdatedAt != null && s.UpdatedAt > since)).ToListAsync();
        items.AddRange(spendings.Select(s => new SyncPullItem("expense", s.Id,
            JsonSerializer.Serialize(s, refOpts), s.UpdatedAt ?? s.CreatedAt)));

        return Ok(new SyncPullResponse(items, DateTime.UtcNow));
    }

    [HttpPost("resolve-conflict")]
    public async Task<IActionResult> ResolveConflict([FromBody] ResolveConflictRequest request)
    {
        var conflict = await _db.SyncConflicts.FindAsync(request.ConflictId);
        if (conflict == null) return NotFound();

        conflict.IsResolved = true;
        conflict.Resolution = request.Resolution;
        conflict.ResolvedBy = User.GetUserId();
        conflict.ResolvedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return Ok();
    }
}
