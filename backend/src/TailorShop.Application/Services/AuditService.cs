using TailorShop.Domain.Entities;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Application.Services;

public class AuditService
{
    private readonly AppDbContext _db;

    public AuditService(AppDbContext db) => _db = db;

    public async Task LogAsync(string entityType, Guid entityId, string action,
        Guid? userId = null, string? oldValues = null, string? newValues = null)
    {
        var log = new AuditLog
        {
            EntityType = entityType,
            EntityId = entityId,
            Action = action,
            UserId = userId,
            OldValues = oldValues,
            NewValues = newValues
        };

        _db.AuditLogs.Add(log);
        await _db.SaveChangesAsync();
    }
}
