using Microsoft.EntityFrameworkCore;
using TailorShop.Domain.Entities;

namespace TailorShop.Infrastructure.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<Partner> Partners => Set<Partner>();
    public DbSet<CapitalTransaction> CapitalTransactions => Set<CapitalTransaction>();
    public DbSet<Spending> Spendings => Set<Spending>();
    public DbSet<SpendingFundingSplit> SpendingFundingSplits => Set<SpendingFundingSplit>();
    public DbSet<AssetOwnership> AssetOwnerships => Set<AssetOwnership>();
    public DbSet<Asset> Assets => Set<Asset>();
    public DbSet<InventoryItem> InventoryItems => Set<InventoryItem>();
    public DbSet<InventoryTransaction> InventoryTransactions => Set<InventoryTransaction>();
    public DbSet<Supplier> Suppliers => Set<Supplier>();
    public DbSet<Customer> Customers => Set<Customer>();
    public DbSet<CustomerMeasurement> CustomerMeasurements => Set<CustomerMeasurement>();
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OrderStatusHistory> OrderStatusHistory => Set<OrderStatusHistory>();
    public DbSet<OrderInventoryUsage> OrderInventoryUsages => Set<OrderInventoryUsage>();
    public DbSet<Invoice> Invoices => Set<Invoice>();
    public DbSet<InvoiceLine> InvoiceLines => Set<InvoiceLine>();
    public DbSet<InvoiceEmailLog> InvoiceEmailLogs => Set<InvoiceEmailLog>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<FileAttachment> FileAttachments => Set<FileAttachment>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
    public DbSet<OcrDocument> OcrDocuments => Set<OcrDocument>();
    public DbSet<OcrExtractedField> OcrExtractedFields => Set<OcrExtractedField>();
    public DbSet<SyncLog> SyncLogs => Set<SyncLog>();
    public DbSet<SyncConflict> SyncConflicts => Set<SyncConflict>();
    public DbSet<Device> Devices => Set<Device>();
    public DbSet<BusinessProfile> BusinessProfiles => Set<BusinessProfile>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Global query filter for soft delete
        modelBuilder.Entity<User>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Partner>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<CapitalTransaction>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Spending>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Asset>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<InventoryItem>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<InventoryTransaction>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Customer>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<CustomerMeasurement>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Order>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Invoice>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Payment>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<FileAttachment>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Supplier>().HasQueryFilter(e => !e.IsDeleted);

        // Concurrency tokens
        modelBuilder.Entity<User>().Property(e => e.RowVersion).IsRowVersion();
        modelBuilder.Entity<Asset>().Property(e => e.RowVersion).IsRowVersion();
        modelBuilder.Entity<InventoryItem>().Property(e => e.RowVersion).IsRowVersion();
        modelBuilder.Entity<Order>().Property(e => e.RowVersion).IsRowVersion();
        modelBuilder.Entity<Invoice>().Property(e => e.RowVersion).IsRowVersion();
        modelBuilder.Entity<Customer>().Property(e => e.RowVersion).IsRowVersion();

        // Unique constraints
        modelBuilder.Entity<User>().HasIndex(u => u.Email).IsUnique();
        modelBuilder.Entity<User>().HasIndex(u => u.Phone);
        modelBuilder.Entity<Customer>().HasIndex(c => c.Phone);
        modelBuilder.Entity<Order>().HasIndex(o => o.OrderNumber).IsUnique();
        modelBuilder.Entity<Invoice>().HasIndex(i => i.InvoiceNumber).IsUnique();
        modelBuilder.Entity<Spending>().HasIndex(s => s.SpendingNo).IsUnique();

        // Relationships — existing
        modelBuilder.Entity<Partner>()
            .HasOne(p => p.User)
            .WithOne(u => u.Partner)
            .HasForeignKey<Partner>(p => p.UserId);

        modelBuilder.Entity<Order>()
            .HasOne(o => o.Customer)
            .WithMany(c => c.Orders)
            .HasForeignKey(o => o.CustomerId);

        modelBuilder.Entity<Payment>()
            .HasOne(p => p.Order)
            .WithMany(o => o.Payments)
            .HasForeignKey(p => p.OrderId);

        modelBuilder.Entity<Invoice>()
            .HasOne(i => i.Order)
            .WithMany(o => o.Invoices)
            .HasForeignKey(i => i.OrderId);

        modelBuilder.Entity<InventoryTransaction>()
            .HasOne(t => t.InventoryItem)
            .WithMany(i => i.Transactions)
            .HasForeignKey(t => t.InventoryItemId);

        modelBuilder.Entity<OrderInventoryUsage>()
            .HasOne(u => u.Order)
            .WithMany(o => o.InventoryUsages)
            .HasForeignKey(u => u.OrderId);

        // Relationships — new entities
        modelBuilder.Entity<CapitalTransaction>()
            .HasOne(ct => ct.Partner)
            .WithMany(p => p.CapitalTransactions)
            .HasForeignKey(ct => ct.PartnerId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<SpendingFundingSplit>()
            .HasOne(sf => sf.Spending)
            .WithMany(s => s.FundingSplits)
            .HasForeignKey(sf => sf.SpendingId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<SpendingFundingSplit>()
            .HasOne(sf => sf.Partner)
            .WithMany(p => p.FundingSplits)
            .HasForeignKey(sf => sf.PartnerId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<AssetOwnership>()
            .HasOne(ao => ao.Asset)
            .WithMany(a => a.Ownerships)
            .HasForeignKey(ao => ao.AssetId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<AssetOwnership>()
            .HasOne(ao => ao.Partner)
            .WithMany(p => p.AssetOwnerships)
            .HasForeignKey(ao => ao.PartnerId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Asset>()
            .HasOne(a => a.Spending)
            .WithOne(s => s.Asset)
            .HasForeignKey<Asset>(a => a.SpendingId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<InventoryTransaction>()
            .HasOne(t => t.Spending)
            .WithMany(s => s.InventoryTransactions)
            .HasForeignKey(t => t.SpendingId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.Restrict);

        // Decimal precision
        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        {
            var decimalProperties = entityType.ClrType.GetProperties()
                .Where(p => p.PropertyType == typeof(decimal) || p.PropertyType == typeof(decimal?));
            foreach (var property in decimalProperties)
            {
                modelBuilder.Entity(entityType.Name)
                    .Property(property.Name)
                    .HasColumnType("decimal(18,2)");
            }
        }

        // Computed columns - exclude computed properties from mapping
        modelBuilder.Entity<Asset>().Ignore(a => a.TotalValue);
        modelBuilder.Entity<InventoryItem>().Ignore(i => i.TotalValue);
        modelBuilder.Entity<Order>().Ignore(o => o.TotalAmount);
        modelBuilder.Entity<Order>().Ignore(o => o.BalanceAmount);
        modelBuilder.Entity<Order>().Ignore(o => o.LabourAmount);
        modelBuilder.Entity<InventoryTransaction>().Ignore(t => t.TotalCost);
        modelBuilder.Entity<OrderInventoryUsage>().Ignore(u => u.TotalCost);
        modelBuilder.Entity<Invoice>().Ignore(i => i.BalanceAmount);
        modelBuilder.Entity<InvoiceLine>().Ignore(l => l.Amount);
    }
}
