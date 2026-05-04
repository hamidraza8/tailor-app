using Microsoft.EntityFrameworkCore;
using TailorShop.Domain.Entities;
using TailorShop.Domain.Enums;

namespace TailorShop.Infrastructure.Data;

public static class DbSeeder
{
    public static async Task SeedAsync(AppDbContext db)
    {
        if (db.Users.Any()) return;

        // Create admin user
        var admin = new User
        {
            FullName = "Admin User",
            Email = "admin@tailorshop.com",
            Phone = "03001234567",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("Admin@123"),
            Role = UserRole.Admin,
            IsActive = true
        };

        // Create partner user
        var partner = new User
        {
            FullName = "Tailor Partner",
            Email = "partner@tailorshop.com",
            Phone = "03009876543",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("Partner@123"),
            Role = UserRole.Partner,
            IsActive = true
        };

        db.Users.AddRange(admin, partner);
        await db.SaveChangesAsync();

        // Create partner record
        var partnerRecord = new Partner
        {
            UserId = partner.Id,
            ProfitSharePercentage = 50m,
            LabourSharePercentage = 35m,
            Notes = "Master tailor and shop manager"
        };
        db.Partners.Add(partnerRecord);

        // Business profile
        var profile = new BusinessProfile
        {
            BusinessName = "Ladies Tailoring & Garments",
            Phone = "03001234567",
            Email = "info@tailorshop.com",
            Address = "Shop #1, Main Market, Lahore",
            DefaultLabourSharePercentage = 35m,
            InvoicePrefix = "INV",
            NextInvoiceNumber = 1,
            Currency = "PKR",
            InvoiceFooter = "Thank you for choosing us! Your satisfaction is our priority."
        };
        db.BusinessProfiles.Add(profile);

        // Sample customers
        var customers = new[]
        {
            new Customer { Name = "Ayesha Khan", Phone = "03011111111", Address = "Model Town, Lahore" },
            new Customer { Name = "Fatima Ali", Phone = "03022222222", Address = "DHA Phase 5, Lahore" },
            new Customer { Name = "Zainab Malik", Phone = "03033333333", Address = "Gulberg III, Lahore" },
        };
        db.Customers.AddRange(customers);

        // Sample suppliers
        var supplier = new Supplier { Name = "Cloth Market Supplier", Phone = "03044444444", Address = "Azam Cloth Market, Lahore" };
        db.Suppliers.Add(supplier);

        await db.SaveChangesAsync();

        // Sample measurements
        db.CustomerMeasurements.Add(new CustomerMeasurement
        {
            CustomerId = customers[0].Id,
            Label = "Default",
            Length = 40, Shoulder = 14, Chest = 34, Waist = 28, Hip = 38,
            SleeveLength = 22, Neck = 14, TrouserLength = 38, TrouserWaist = 28
        });

        // Sample inventory
        var inventoryItems = new[]
        {
            new InventoryItem { Name = "Cotton Fabric", Category = "Fabric", Unit = "meters", CurrentStock = 50, UnitCost = 500, SupplierId = supplier.Id },
            new InventoryItem { Name = "Silk Thread", Category = "Thread", Unit = "spools", CurrentStock = 100, UnitCost = 50, SupplierId = supplier.Id },
            new InventoryItem { Name = "Buttons (Pearl)", Category = "Button", Unit = "pcs", CurrentStock = 200, UnitCost = 10 },
            new InventoryItem { Name = "Lace Trim", Category = "Lace", Unit = "meters", CurrentStock = 30, UnitCost = 200 },
        };
        db.InventoryItems.AddRange(inventoryItems);

        await db.SaveChangesAsync();

        // ── Accounting seed data ─────────────────────────────────
        // Find the partner record
        var partnerRecord2 = await db.Partners.FirstOrDefaultAsync();
        if (partnerRecord2 != null && !db.CapitalTransactions.Any())
        {
            // Also create an "admin as investor" partner record
            var adminUser = await db.Users.FirstOrDefaultAsync(u => u.Email == "admin@tailorshop.com");
            var adminPartner = new Partner
            {
                UserId = adminUser!.Id,
                ProfitSharePercentage = 50m,
                LabourSharePercentage = 0m,
                OwnershipPercent = 60m,
                Notes = "Investor/Admin partner",
                IsActive = true
            };
            db.Partners.Add(adminPartner);
            await db.SaveChangesAsync();

            // Update existing partner ownership
            partnerRecord2.OwnershipPercent = 40m;
            partnerRecord2.IsActive = true;
            await db.SaveChangesAsync();

            // Seed capital transactions
            db.CapitalTransactions.AddRange(new[]
            {
                new CapitalTransaction
                {
                    PartnerId = adminPartner.Id,
                    Type = CapitalTransactionType.CapitalAdvance,
                    Amount = 200000m,
                    TransactionDate = DateTime.UtcNow.AddMonths(-3),
                    Notes = "Initial capital contribution - Investor",
                    ApprovalStatus = ApprovalStatus.Approved,
                    ApprovedAt = DateTime.UtcNow.AddMonths(-3)
                },
                new CapitalTransaction
                {
                    PartnerId = partnerRecord2.Id,
                    Type = CapitalTransactionType.CapitalAdvance,
                    Amount = 100000m,
                    TransactionDate = DateTime.UtcNow.AddMonths(-3),
                    Notes = "Initial capital contribution - Tailor Partner",
                    ApprovalStatus = ApprovalStatus.Approved,
                    ApprovedAt = DateTime.UtcNow.AddMonths(-3)
                }
            });
            await db.SaveChangesAsync();

            // Seed: Machine purchase spending (Partner A funded 50,000)
            var machineSpending = new Spending
            {
                SpendingNo = "SPD-SEED-001",
                SpendingDate = DateTime.UtcNow.AddMonths(-2),
                Category = SpendingCategory.AssetPurchase,
                Description = "Industrial Sewing Machine Purchase",
                TotalAmount = 50000m,
                ResultType = SpendingResultType.Asset,
                OwnershipApplicable = true,
                ApprovalStatus = ApprovalStatus.Approved,
                ApprovedAt = DateTime.UtcNow.AddMonths(-2)
            };
            db.Spendings.Add(machineSpending);
            await db.SaveChangesAsync();

            db.SpendingFundingSplits.Add(new SpendingFundingSplit
            {
                SpendingId = machineSpending.Id,
                PartnerId = adminPartner.Id,
                Amount = 50000m,
                Notes = "Fully funded by investor partner"
            });

            var machine = new Asset
            {
                Name = "Industrial Sewing Machine",
                AssetType = "Sewing Machine",
                Quantity = 1,
                UnitValue = 50000m,
                SpendingId = machineSpending.Id,
                OwnershipType = AssetOwnershipType.PartnerOwned,
                ApprovalStatus = ApprovalStatus.Approved,
                PurchaseDate = DateTime.UtcNow.AddMonths(-2),
                Location = "Main Workshop",
                Condition = "New"
            };
            db.Assets.Add(machine);
            await db.SaveChangesAsync();

            db.AssetOwnerships.Add(new AssetOwnership
            {
                AssetId = machine.Id,
                OwnerType = AssetOwnerType.Partner,
                PartnerId = adminPartner.Id,
                OwnershipPercent = 100m,
                OwnershipValue = 50000m
            });

            // Seed: Rent expense spending
            var rentSpending = new Spending
            {
                SpendingNo = "SPD-SEED-002",
                SpendingDate = DateTime.UtcNow.AddMonths(-2),
                Category = SpendingCategory.Rent,
                Description = "Shop Rent - Month 1",
                TotalAmount = 12000m,
                ResultType = SpendingResultType.Expense,
                OwnershipApplicable = false,
                ApprovalStatus = ApprovalStatus.Approved,
                ApprovedAt = DateTime.UtcNow.AddMonths(-2)
            };
            db.Spendings.Add(rentSpending);
            await db.SaveChangesAsync();

            db.SpendingFundingSplits.AddRange(new[]
            {
                new SpendingFundingSplit { SpendingId = rentSpending.Id, PartnerId = adminPartner.Id, Amount = 8000m },
                new SpendingFundingSplit { SpendingId = rentSpending.Id, PartnerId = partnerRecord2.Id, Amount = 4000m }
            });

            await db.SaveChangesAsync();
        }
    }
}
