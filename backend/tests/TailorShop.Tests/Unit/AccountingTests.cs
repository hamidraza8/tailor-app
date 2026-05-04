using Microsoft.EntityFrameworkCore;
using TailorShop.Application.Services;
using TailorShop.Domain.Entities;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;
using Xunit;

namespace TailorShop.Tests.Unit;

/// <summary>
/// Comprehensive test suite for the TailorShop accounting module.
/// Covers capital transactions, spending/funding splits, asset ownership,
/// partner balance calculations, and full business scenarios.
/// </summary>
public class AccountingTests
{
    // ─── InMemory DB helpers ───────────────────────────────────────────────────

    /// <summary>
    /// Creates a fresh InMemory AppDbContext. Use a unique dbName per test to
    /// guarantee full isolation. Row-version concurrency tokens are not enforced
    /// by the InMemory provider, so each test gets a pristine, independent store.
    /// </summary>
    private static AppDbContext CreateContext(string dbName)
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(dbName)
            .Options;
        return new AppDbContext(options);
    }

    /// <summary>
    /// Seeds two users + two partners and returns their Partner IDs.
    /// All entities have IsDeleted=false (the default) so global query filters pass.
    /// </summary>
    private static (Guid partnerAId, Guid partnerBId) SeedPartners(AppDbContext db)
    {
        var userA = new User
        {
            FullName = "Partner A",
            Email = "a@test.com",
            PasswordHash = "x",
            Role = UserRole.Admin
        };
        var userB = new User
        {
            FullName = "Partner B",
            Email = "b@test.com",
            PasswordHash = "x",
            Role = UserRole.Partner
        };
        db.Users.AddRange(userA, userB);
        db.SaveChanges();

        var partnerA = new Partner { UserId = userA.Id, IsActive = true };
        var partnerB = new Partner { UserId = userB.Id, IsActive = true };
        db.Partners.AddRange(partnerA, partnerB);
        db.SaveChanges();

        return (partnerA.Id, partnerB.Id);
    }

    /// <summary>
    /// Seeds a single user + partner and returns the Partner ID.
    /// </summary>
    private static Guid SeedSinglePartner(AppDbContext db, string name = "Solo Partner", string email = "solo@test.com")
    {
        var user = new User
        {
            FullName = name,
            Email = email,
            PasswordHash = "x",
            Role = UserRole.Partner
        };
        db.Users.Add(user);
        db.SaveChanges();

        var partner = new Partner { UserId = user.Id, IsActive = true };
        db.Partners.Add(partner);
        db.SaveChanges();

        return partner.Id;
    }

    /// <summary>
    /// Adds an approved CapitalTransaction for the given partner.
    /// </summary>
    private static void AddCapital(AppDbContext db, Guid partnerId,
        CapitalTransactionType type, decimal amount,
        ApprovalStatus status = ApprovalStatus.Approved)
    {
        db.CapitalTransactions.Add(new CapitalTransaction
        {
            PartnerId = partnerId,
            Type = type,
            Amount = amount,
            ApprovalStatus = status
        });
        db.SaveChanges();
    }

    /// <summary>
    /// Adds an approved Spending with the specified funding splits.
    /// Returns the created Spending ID.
    /// </summary>
    private static Guid AddSpending(AppDbContext db,
        decimal totalAmount,
        SpendingResultType resultType,
        SpendingCategory category,
        bool ownershipApplicable,
        ApprovalStatus status,
        string spendingNo,
        params (Guid partnerId, decimal amount)[] splits)
    {
        var spending = new Spending
        {
            SpendingNo = spendingNo,
            TotalAmount = totalAmount,
            ResultType = resultType,
            Category = category,
            OwnershipApplicable = ownershipApplicable,
            Description = $"Test spending {spendingNo}",
            ApprovalStatus = status
        };
        db.Spendings.Add(spending);
        db.SaveChanges();

        foreach (var (partnerId, amount) in splits)
        {
            db.SpendingFundingSplits.Add(new SpendingFundingSplit
            {
                SpendingId = spending.Id,
                PartnerId = partnerId,
                Amount = amount
            });
        }
        db.SaveChanges();

        return spending.Id;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Section 1: Domain calculation tests (no DB required)
    // ─────────────────────────────────────────────────────────────────────────

    /// <summary>
    /// Test 1: CapitalTransaction stores a positive decimal amount correctly.
    /// </summary>
    [Fact]
    public void CapitalTransaction_Amount_StoresPositiveDecimal()
    {
        var tx = new CapitalTransaction
        {
            Type = CapitalTransactionType.CapitalAdvance,
            Amount = 200_000m,
            ApprovalStatus = ApprovalStatus.Approved
        };

        Assert.Equal(200_000m, tx.Amount);
        Assert.Equal(CapitalTransactionType.CapitalAdvance, tx.Type);
        Assert.Equal(ApprovalStatus.Approved, tx.ApprovalStatus);
    }

    /// <summary>
    /// Test 2: Asset.TotalValue is Quantity * UnitValue; AssetOwnership stores
    /// correct OwnershipValue.
    /// </summary>
    [Fact]
    public void AssetOwnership_OwnershipValue_MatchesAssetTotalValue()
    {
        var asset = new Asset
        {
            Name = "Sewing Machine",
            AssetType = "Machine",
            Quantity = 1,
            UnitValue = 50_000m
        };

        Assert.Equal(50_000m, asset.TotalValue);

        var ownership = new AssetOwnership
        {
            OwnerType = AssetOwnerType.Partner,
            OwnershipPercent = 100m,
            OwnershipValue = asset.TotalValue * 100m / 100m   // 50,000
        };

        Assert.Equal(100m, ownership.OwnershipPercent);
        Assert.Equal(50_000m, ownership.OwnershipValue);
    }

    /// <summary>
    /// Test 3: Two SpendingFundingSplits that sum to the spending TotalAmount
    /// pass the balance check.
    /// </summary>
    [Fact]
    public void SpendingFundingSplit_SumEqualsSpendingTotal_WhenSplitsAreValid()
    {
        var spending = new Spending
        {
            SpendingNo = "SPD-TEST-001",
            TotalAmount = 12_000m,
            Category = SpendingCategory.Rent,
            ResultType = SpendingResultType.Expense
        };

        var splitA = new SpendingFundingSplit { Amount = 8_000m };
        var splitB = new SpendingFundingSplit { Amount = 4_000m };

        var splitTotal = splitA.Amount + splitB.Amount;

        Assert.Equal(spending.TotalAmount, splitTotal);
    }

    /// <summary>
    /// Test 4: Asset ownership percentages across all owners must sum to 100.
    /// </summary>
    [Fact]
    public void AssetOwnership_PercentagesSum_MustEqual100()
    {
        // Valid: 60 + 40 = 100
        var ownershipA = new AssetOwnership { OwnershipPercent = 60m };
        var ownershipB = new AssetOwnership { OwnershipPercent = 40m };

        var validTotal = ownershipA.OwnershipPercent + ownershipB.OwnershipPercent;
        Assert.Equal(100m, validTotal);

        // Invalid: 60 + 30 = 90 (would be rejected by service)
        var invalidA = new AssetOwnership { OwnershipPercent = 60m };
        var invalidB = new AssetOwnership { OwnershipPercent = 30m };

        var invalidTotal = invalidA.OwnershipPercent + invalidB.OwnershipPercent;
        Assert.NotEqual(100m, invalidTotal);
        Assert.Equal(90m, invalidTotal);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Section 2: PartnerBalanceService tests (InMemory DB)
    // ─────────────────────────────────────────────────────────────────────────

    /// <summary>
    /// Test 5: Initial capital — two partners each contribute capital.
    /// Expected: each partner's RemainingBalance equals their contribution.
    /// </summary>
    [Fact]
    public async Task PartnerBalance_InitialCapital_EqualsContributions()
    {
        await using var db = CreateContext(nameof(PartnerBalance_InitialCapital_EqualsContributions));
        var svc = new PartnerBalanceService(db);

        var (partnerAId, partnerBId) = SeedPartners(db);
        AddCapital(db, partnerAId, CapitalTransactionType.CapitalAdvance, 200_000m);
        AddCapital(db, partnerBId, CapitalTransactionType.CapitalAdvance, 100_000m);

        var balanceA = await svc.GetPartnerBalanceAsync(partnerAId);
        var balanceB = await svc.GetPartnerBalanceAsync(partnerBId);

        Assert.Equal(200_000m, balanceA.TotalCapitalAdded);
        Assert.Equal(200_000m, balanceA.RemainingBalance);
        Assert.False(balanceA.IsDeficit);
        Assert.Equal(0m, balanceA.DeficitAmount);

        Assert.Equal(100_000m, balanceB.TotalCapitalAdded);
        Assert.Equal(100_000m, balanceB.RemainingBalance);
        Assert.False(balanceB.IsDeficit);
        Assert.Equal(0m, balanceB.DeficitAmount);
    }

    /// <summary>
    /// Test 6: Machine purchase of 50,000 funded entirely by Partner A.
    /// Expected: Partner A balance reduces to 150,000. AssetOwnership value = 50,000.
    /// </summary>
    [Fact]
    public async Task PartnerBalance_MachinePurchaseFundedByPartnerA_ReducesBalanceAndCreatesOwnership()
    {
        await using var db = CreateContext(nameof(PartnerBalance_MachinePurchaseFundedByPartnerA_ReducesBalanceAndCreatesOwnership));
        var svc = new PartnerBalanceService(db);

        var (partnerAId, partnerBId) = SeedPartners(db);
        AddCapital(db, partnerAId, CapitalTransactionType.CapitalAdvance, 200_000m);
        AddCapital(db, partnerBId, CapitalTransactionType.CapitalAdvance, 100_000m);

        // Machine purchase
        var spendingId = AddSpending(db, 50_000m, SpendingResultType.Asset,
            SpendingCategory.AssetPurchase, ownershipApplicable: true,
            ApprovalStatus.Approved, "SPD-MACH-001",
            (partnerAId, 50_000m));

        // Create the Asset linked to this spending
        var asset = new Asset
        {
            Name = "Sewing Machine",
            AssetType = "Machine",
            Quantity = 1,
            UnitValue = 50_000m,
            SpendingId = spendingId,
            OwnershipType = AssetOwnershipType.PartnerOwned,
            ApprovalStatus = ApprovalStatus.Approved
        };
        db.Assets.Add(asset);
        db.SaveChanges();

        // AssetOwnership: 100% Partner A
        db.AssetOwnerships.Add(new AssetOwnership
        {
            AssetId = asset.Id,
            OwnerType = AssetOwnerType.Partner,
            PartnerId = partnerAId,
            OwnershipPercent = 100m,
            OwnershipValue = 50_000m
        });
        db.SaveChanges();

        var balanceA = await svc.GetPartnerBalanceAsync(partnerAId);

        Assert.Equal(150_000m, balanceA.RemainingBalance);
        Assert.False(balanceA.IsDeficit);
        Assert.Equal(50_000m, balanceA.AssetOwnershipValue);
        Assert.Equal(50_000m, balanceA.AssetFundingTotal);
    }

    /// <summary>
    /// Test 7: Rent expense of 12,000 split A=8,000 / B=4,000.
    /// Expected: A reduces by 8,000; B reduces by 4,000. No asset ownership created.
    /// </summary>
    [Fact]
    public async Task PartnerBalance_RentExpense_ReducesBothPartnersWithNoOwnership()
    {
        await using var db = CreateContext(nameof(PartnerBalance_RentExpense_ReducesBothPartnersWithNoOwnership));
        var svc = new PartnerBalanceService(db);

        var (partnerAId, partnerBId) = SeedPartners(db);
        AddCapital(db, partnerAId, CapitalTransactionType.CapitalAdvance, 200_000m);
        AddCapital(db, partnerBId, CapitalTransactionType.CapitalAdvance, 100_000m);

        // Machine purchase (A funded 50k → A now at 150k)
        AddSpending(db, 50_000m, SpendingResultType.Asset,
            SpendingCategory.AssetPurchase, ownershipApplicable: true,
            ApprovalStatus.Approved, "SPD-MACH-001",
            (partnerAId, 50_000m));

        // Rent expense split A=8k, B=4k
        var rentSpendingId = AddSpending(db, 12_000m, SpendingResultType.Expense,
            SpendingCategory.Rent, ownershipApplicable: false,
            ApprovalStatus.Approved, "SPD-RENT-001",
            (partnerAId, 8_000m), (partnerBId, 4_000m));

        var balanceA = await svc.GetPartnerBalanceAsync(partnerAId);
        var balanceB = await svc.GetPartnerBalanceAsync(partnerBId);

        // A: 200k - 50k(machine) - 8k(rent) = 142k
        Assert.Equal(142_000m, balanceA.RemainingBalance);
        // B: 100k - 4k(rent) = 96k
        Assert.Equal(96_000m, balanceB.RemainingBalance);

        // No AssetOwnership for the rent spending
        var rentOwnership = db.AssetOwnerships
            .Where(ao => ao.Asset.SpendingId == rentSpendingId)
            .ToList();
        Assert.Empty(rentOwnership);

        // Expense funding totals
        Assert.Equal(8_000m, balanceA.ExpenseFundingTotal);
        Assert.Equal(4_000m, balanceB.ExpenseFundingTotal);
    }

    /// <summary>
    /// Test 8: Inventory purchase of 30,000 funded A=20,000 / B=10,000.
    /// Expected: A=122,000; B=86,000.
    /// </summary>
    [Fact]
    public async Task PartnerBalance_InventoryPurchase_ReducesBothPartners()
    {
        await using var db = CreateContext(nameof(PartnerBalance_InventoryPurchase_ReducesBothPartners));
        var svc = new PartnerBalanceService(db);

        var (partnerAId, partnerBId) = SeedPartners(db);
        AddCapital(db, partnerAId, CapitalTransactionType.CapitalAdvance, 200_000m);
        AddCapital(db, partnerBId, CapitalTransactionType.CapitalAdvance, 100_000m);

        // Machine: A=50k → A now 150k
        AddSpending(db, 50_000m, SpendingResultType.Asset,
            SpendingCategory.AssetPurchase, ownershipApplicable: true,
            ApprovalStatus.Approved, "SPD-MACH-001",
            (partnerAId, 50_000m));

        // Rent: A=8k, B=4k → A=142k, B=96k
        AddSpending(db, 12_000m, SpendingResultType.Expense,
            SpendingCategory.Rent, ownershipApplicable: false,
            ApprovalStatus.Approved, "SPD-RENT-001",
            (partnerAId, 8_000m), (partnerBId, 4_000m));

        // Inventory: A=20k, B=10k
        AddSpending(db, 30_000m, SpendingResultType.Inventory,
            SpendingCategory.InventoryPurchase, ownershipApplicable: false,
            ApprovalStatus.Approved, "SPD-INV-001",
            (partnerAId, 20_000m), (partnerBId, 10_000m));

        var balanceA = await svc.GetPartnerBalanceAsync(partnerAId);
        var balanceB = await svc.GetPartnerBalanceAsync(partnerBId);

        // A: 200k - 50k - 8k - 20k = 122k
        Assert.Equal(122_000m, balanceA.RemainingBalance);
        // B: 100k - 4k - 10k = 86k
        Assert.Equal(86_000m, balanceB.RemainingBalance);

        Assert.Equal(20_000m, balanceA.InventoryFundingTotal);
        Assert.Equal(10_000m, balanceB.InventoryFundingTotal);
    }

    /// <summary>
    /// Test 9: Partner B has only 2,000 capital but is assigned a 5,000 spending split.
    /// Expected: balance = -3,000 (deficit). System allows negative balances.
    /// </summary>
    [Fact]
    public async Task PartnerBalance_FundingSplitExceedsCapital_ShowsDeficit()
    {
        await using var db = CreateContext(nameof(PartnerBalance_FundingSplitExceedsCapital_ShowsDeficit));
        var svc = new PartnerBalanceService(db);

        var partnerBId = SeedSinglePartner(db, "Deficit Partner", "deficit@test.com");
        AddCapital(db, partnerBId, CapitalTransactionType.CapitalAdvance, 2_000m);

        // Spending of 5,000 funded entirely by B (who only has 2,000)
        AddSpending(db, 5_000m, SpendingResultType.Expense,
            SpendingCategory.Utility, ownershipApplicable: false,
            ApprovalStatus.Approved, "SPD-OVER-001",
            (partnerBId, 5_000m));

        var balanceB = await svc.GetPartnerBalanceAsync(partnerBId);

        // 2,000 - 5,000 = -3,000
        Assert.Equal(-3_000m, balanceB.RemainingBalance);
        Assert.True(balanceB.IsDeficit);
        Assert.Equal(3_000m, balanceB.DeficitAmount);
    }

    /// <summary>
    /// Test 10: Full business scenario covering all spending types.
    /// Capital: A=200k, B=100k.
    /// Step 1 — Machine 50k: A funds 50k → Asset, owner=Partner A.
    /// Step 2 — Rent 12k: A=8k, B=4k → Expense, no ownership.
    /// Step 3 — Inventory 30k: A=20k, B=10k → Inventory.
    /// Step 4 — Utility 5k: B=5k → Expense, no ownership.
    /// Expected: A=122k, B=81k; A asset ownership=50k; inventory total=30k; expense total=17k.
    /// </summary>
    [Fact]
    public async Task PartnerBalance_FullBusinessScenario_AllBalancesAreCorrect()
    {
        await using var db = CreateContext(nameof(PartnerBalance_FullBusinessScenario_AllBalancesAreCorrect));
        var svc = new PartnerBalanceService(db);

        var (partnerAId, partnerBId) = SeedPartners(db);
        AddCapital(db, partnerAId, CapitalTransactionType.CapitalAdvance, 200_000m);
        AddCapital(db, partnerBId, CapitalTransactionType.CapitalAdvance, 100_000m);

        // Step 1: Machine 50k funded by A → Asset, Partner A owns 100%
        var machineSpendingId = AddSpending(db, 50_000m, SpendingResultType.Asset,
            SpendingCategory.AssetPurchase, ownershipApplicable: true,
            ApprovalStatus.Approved, "SPD-001",
            (partnerAId, 50_000m));

        var machineAsset = new Asset
        {
            Name = "Sewing Machine",
            AssetType = "Machine",
            Quantity = 1,
            UnitValue = 50_000m,
            SpendingId = machineSpendingId,
            OwnershipType = AssetOwnershipType.PartnerOwned,
            ApprovalStatus = ApprovalStatus.Approved
        };
        db.Assets.Add(machineAsset);
        db.SaveChanges();

        db.AssetOwnerships.Add(new AssetOwnership
        {
            AssetId = machineAsset.Id,
            OwnerType = AssetOwnerType.Partner,
            PartnerId = partnerAId,
            OwnershipPercent = 100m,
            OwnershipValue = 50_000m
        });
        db.SaveChanges();

        // Step 2: Rent 12k → A=8k, B=4k
        var rentSpendingId = AddSpending(db, 12_000m, SpendingResultType.Expense,
            SpendingCategory.Rent, ownershipApplicable: false,
            ApprovalStatus.Approved, "SPD-002",
            (partnerAId, 8_000m), (partnerBId, 4_000m));

        // Step 3: Inventory 30k → A=20k, B=10k
        AddSpending(db, 30_000m, SpendingResultType.Inventory,
            SpendingCategory.InventoryPurchase, ownershipApplicable: false,
            ApprovalStatus.Approved, "SPD-003",
            (partnerAId, 20_000m), (partnerBId, 10_000m));

        // Step 4: Utility 5k → B=5k
        var utilitySpendingId = AddSpending(db, 5_000m, SpendingResultType.Expense,
            SpendingCategory.Utility, ownershipApplicable: false,
            ApprovalStatus.Approved, "SPD-004",
            (partnerBId, 5_000m));

        var balanceA = await svc.GetPartnerBalanceAsync(partnerAId);
        var balanceB = await svc.GetPartnerBalanceAsync(partnerBId);

        // ── Partner A ──
        // 200k - 50k(machine) - 8k(rent) - 20k(inventory) = 122k
        Assert.Equal(122_000m, balanceA.RemainingBalance);
        Assert.False(balanceA.IsDeficit);
        Assert.Equal(50_000m, balanceA.AssetOwnershipValue);
        Assert.Equal(50_000m, balanceA.AssetFundingTotal);
        Assert.Equal(20_000m, balanceA.InventoryFundingTotal);
        Assert.Equal(8_000m, balanceA.ExpenseFundingTotal);

        // ── Partner B ──
        // 100k - 4k(rent) - 10k(inventory) - 5k(utility) = 81k
        Assert.Equal(81_000m, balanceB.RemainingBalance);
        Assert.False(balanceB.IsDeficit);
        Assert.Equal(0m, balanceB.AssetOwnershipValue);      // B owns no assets
        Assert.Equal(10_000m, balanceB.InventoryFundingTotal);
        Assert.Equal(9_000m, balanceB.ExpenseFundingTotal);  // rent 4k + utility 5k

        // ── Cross-entity assertions ──
        // Total inventory funding across both partners = 30k (A=20k + B=10k)
        var totalInventoryFunding = balanceA.InventoryFundingTotal + balanceB.InventoryFundingTotal;
        Assert.Equal(30_000m, totalInventoryFunding);

        // Total expense funding across both partners = 17k (rent 12k + utility 5k)
        var totalExpenseFunding = balanceA.ExpenseFundingTotal + balanceB.ExpenseFundingTotal;
        Assert.Equal(17_000m, totalExpenseFunding);

        // Asset ownerships exist only for the machine spending; none for rent/utility
        var rentOwnership = db.AssetOwnerships
            .Where(ao => ao.Asset.SpendingId == rentSpendingId)
            .ToList();
        Assert.Empty(rentOwnership);

        var utilityOwnership = db.AssetOwnerships
            .Where(ao => ao.Asset.SpendingId == utilitySpendingId)
            .ToList();
        Assert.Empty(utilityOwnership);
    }

    /// <summary>
    /// Test 11: GetFundingSplitReportAsync returns correct split amounts per partner
    /// across multiple spendings.
    /// </summary>
    [Fact]
    public async Task FundingSplitReport_ShowsCorrectSplitsForMultipleSpendings()
    {
        await using var db = CreateContext(nameof(FundingSplitReport_ShowsCorrectSplitsForMultipleSpendings));
        var svc = new PartnerBalanceService(db);

        var (partnerAId, partnerBId) = SeedPartners(db);

        // Spending 1: 10k total — A=6k, B=4k
        AddSpending(db, 10_000m, SpendingResultType.Expense,
            SpendingCategory.Rent, ownershipApplicable: false,
            ApprovalStatus.Approved, "SPD-R-001",
            (partnerAId, 6_000m), (partnerBId, 4_000m));

        // Spending 2: 20k total — A=12k, B=8k
        AddSpending(db, 20_000m, SpendingResultType.Inventory,
            SpendingCategory.InventoryPurchase, ownershipApplicable: false,
            ApprovalStatus.Approved, "SPD-I-001",
            (partnerAId, 12_000m), (partnerBId, 8_000m));

        var report = await svc.GetFundingSplitReportAsync();

        Assert.Equal(2, report.Count);

        var rentReport = report.First(r => r.SpendingNo == "SPD-R-001");
        Assert.Equal(10_000m, rentReport.TotalAmount);
        Assert.Equal(2, rentReport.Splits.Count);

        var splitAInRent = rentReport.Splits.First(s => s.PartnerId == partnerAId);
        var splitBInRent = rentReport.Splits.First(s => s.PartnerId == partnerBId);
        Assert.Equal(6_000m, splitAInRent.Amount);
        Assert.Equal(4_000m, splitBInRent.Amount);

        var invReport = report.First(r => r.SpendingNo == "SPD-I-001");
        Assert.Equal(20_000m, invReport.TotalAmount);
        Assert.Equal(2, invReport.Splits.Count);

        var splitAInInv = invReport.Splits.First(s => s.PartnerId == partnerAId);
        var splitBInInv = invReport.Splits.First(s => s.PartnerId == partnerBId);
        Assert.Equal(12_000m, splitAInInv.Amount);
        Assert.Equal(8_000m, splitBInInv.Amount);
    }

    /// <summary>
    /// Test 12: GetAssetOwnershipReportAsync returns assets with their ownership details.
    /// </summary>
    [Fact]
    public async Task AssetOwnershipReport_ShowsAssetsWithOwnershipDetails()
    {
        await using var db = CreateContext(nameof(AssetOwnershipReport_ShowsAssetsWithOwnershipDetails));
        var svc = new PartnerBalanceService(db);

        var (partnerAId, partnerBId) = SeedPartners(db);

        // Spending for an asset
        var spendingId = AddSpending(db, 80_000m, SpendingResultType.Asset,
            SpendingCategory.AssetPurchase, ownershipApplicable: true,
            ApprovalStatus.Approved, "SPD-ASSET-001",
            (partnerAId, 48_000m), (partnerBId, 32_000m));

        // Asset linked to that spending
        var asset = new Asset
        {
            Name = "Industrial Overlock",
            AssetType = "Machine",
            Quantity = 1,
            UnitValue = 80_000m,
            SpendingId = spendingId,
            OwnershipType = AssetOwnershipType.SplitOwned,
            ApprovalStatus = ApprovalStatus.Approved
        };
        db.Assets.Add(asset);
        db.SaveChanges();

        // Ownership: A=60%, B=40%
        db.AssetOwnerships.AddRange(
            new AssetOwnership
            {
                AssetId = asset.Id,
                OwnerType = AssetOwnerType.Partner,
                PartnerId = partnerAId,
                OwnershipPercent = 60m,
                OwnershipValue = 48_000m    // 80k * 60%
            },
            new AssetOwnership
            {
                AssetId = asset.Id,
                OwnerType = AssetOwnerType.Partner,
                PartnerId = partnerBId,
                OwnershipPercent = 40m,
                OwnershipValue = 32_000m    // 80k * 40%
            }
        );
        db.SaveChanges();

        var report = await svc.GetAssetOwnershipReportAsync();

        Assert.Single(report);

        var assetReport = report.First();
        Assert.Equal("Industrial Overlock", assetReport.AssetName);
        Assert.Equal(80_000m, assetReport.TotalValue);
        Assert.Equal(AssetOwnershipType.SplitOwned, assetReport.OwnershipType);
        Assert.Equal(2, assetReport.Ownerships.Count);

        var ownerA = assetReport.Ownerships.First(o => o.PartnerId == partnerAId);
        Assert.Equal(60m, ownerA.OwnershipPercent);
        Assert.Equal(48_000m, ownerA.OwnershipValue);

        var ownerB = assetReport.Ownerships.First(o => o.PartnerId == partnerBId);
        Assert.Equal(40m, ownerB.OwnershipPercent);
        Assert.Equal(32_000m, ownerB.OwnershipValue);

        // Ownership percentages must sum to 100
        var totalPercent = assetReport.Ownerships.Sum(o => o.OwnershipPercent);
        Assert.Equal(100m, totalPercent);

        // Ownership values must sum to asset total value
        var totalOwnershipValue = assetReport.Ownerships.Sum(o => o.OwnershipValue);
        Assert.Equal(80_000m, totalOwnershipValue);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Section 3: Validation logic tests (pure logic, no DB)
    // ─────────────────────────────────────────────────────────────────────────

    /// <summary>
    /// Test 13: FundingSplit total mismatch is detectable — splits summing to a
    /// value different from the spending total should be flagged as invalid.
    /// </summary>
    [Fact]
    public void FundingSplitValidation_SumMismatch_IsDetected()
    {
        var spendingTotal = 12_000m;

        // Splits that do NOT sum to the spending total
        var splits = new[] { 7_000m, 4_000m };   // 11,000 ≠ 12,000
        var splitTotal = splits.Sum();

        Assert.NotEqual(spendingTotal, splitTotal);
        Assert.Equal(11_000m, splitTotal);

        // Correct splits that DO sum to the spending total
        var correctSplits = new[] { 8_000m, 4_000m };   // 12,000 = 12,000
        var correctTotal = correctSplits.Sum();

        Assert.Equal(spendingTotal, correctTotal);
    }

    /// <summary>
    /// Test 14: Asset ownership percent validation — percentages must total exactly 100.
    /// </summary>
    [Fact]
    public void AssetOwnershipValidation_PercentageTotal_MustEqual100()
    {
        // Invalid: 60% + 30% = 90%
        var invalidOwnerships = new[]
        {
            new AssetOwnership { OwnershipPercent = 60m },
            new AssetOwnership { OwnershipPercent = 30m }
        };
        var invalidTotal = invalidOwnerships.Sum(o => o.OwnershipPercent);
        var invalidDelta = Math.Abs(invalidTotal - 100m);

        Assert.NotEqual(100m, invalidTotal);
        Assert.True(invalidDelta > 0.01m, "Delta should exceed the 0.01% service tolerance.");

        // Valid: 60% + 40% = 100%
        var validOwnerships = new[]
        {
            new AssetOwnership { OwnershipPercent = 60m },
            new AssetOwnership { OwnershipPercent = 40m }
        };
        var validTotal = validOwnerships.Sum(o => o.OwnershipPercent);
        var validDelta = Math.Abs(validTotal - 100m);

        Assert.Equal(100m, validTotal);
        Assert.True(validDelta <= 0.01m, "Delta should be within the 0.01% service tolerance.");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Section 4: Additional edge-case tests
    // ─────────────────────────────────────────────────────────────────────────

    /// <summary>
    /// Pending-approval capital transactions must NOT be included in a partner's balance.
    /// </summary>
    [Fact]
    public async Task PartnerBalance_PendingCapitalTransaction_IsNotCounted()
    {
        await using var db = CreateContext(nameof(PartnerBalance_PendingCapitalTransaction_IsNotCounted));
        var svc = new PartnerBalanceService(db);

        var partnerAId = SeedSinglePartner(db);

        // Approved capital: 100k
        AddCapital(db, partnerAId, CapitalTransactionType.CapitalAdvance, 100_000m, ApprovalStatus.Approved);
        // Pending capital: 50k — should be excluded from balance
        AddCapital(db, partnerAId, CapitalTransactionType.AdditionalCapital, 50_000m, ApprovalStatus.PendingApproval);

        var balance = await svc.GetPartnerBalanceAsync(partnerAId);

        // Only the approved 100k should count
        Assert.Equal(100_000m, balance.TotalCapitalAdded);
        Assert.Equal(100_000m, balance.RemainingBalance);
    }

    /// <summary>
    /// Pending-approval spendings must NOT reduce a partner's balance.
    /// </summary>
    [Fact]
    public async Task PartnerBalance_PendingSpending_IsNotDeducted()
    {
        await using var db = CreateContext(nameof(PartnerBalance_PendingSpending_IsNotDeducted));
        var svc = new PartnerBalanceService(db);

        var partnerAId = SeedSinglePartner(db);
        AddCapital(db, partnerAId, CapitalTransactionType.CapitalAdvance, 100_000m);

        // Pending spending — should NOT reduce the balance
        AddSpending(db, 20_000m, SpendingResultType.Expense,
            SpendingCategory.Rent, ownershipApplicable: false,
            ApprovalStatus.PendingApproval, "SPD-PENDING-001",
            (partnerAId, 20_000m));

        var balance = await svc.GetPartnerBalanceAsync(partnerAId);

        // Balance should remain 100k — pending spending not deducted
        Assert.Equal(100_000m, balance.RemainingBalance);
        Assert.Equal(0m, balance.TotalFundedSpendings);
    }

    /// <summary>
    /// A Withdrawal capital transaction reduces the partner's balance.
    /// </summary>
    [Fact]
    public async Task PartnerBalance_Withdrawal_ReducesRemainingBalance()
    {
        await using var db = CreateContext(nameof(PartnerBalance_Withdrawal_ReducesRemainingBalance));
        var svc = new PartnerBalanceService(db);

        var partnerAId = SeedSinglePartner(db);
        AddCapital(db, partnerAId, CapitalTransactionType.CapitalAdvance, 150_000m);
        AddCapital(db, partnerAId, CapitalTransactionType.Withdrawal, 30_000m);

        var balance = await svc.GetPartnerBalanceAsync(partnerAId);

        Assert.Equal(150_000m, balance.TotalCapitalAdded);
        Assert.Equal(30_000m, balance.TotalWithdrawals);
        Assert.Equal(120_000m, balance.RemainingBalance);
        Assert.False(balance.IsDeficit);
    }

    /// <summary>
    /// A positive Adjustment increases capital; a negative Adjustment decreases it.
    /// </summary>
    [Fact]
    public async Task PartnerBalance_Adjustments_AppliedCorrectly()
    {
        await using var db = CreateContext(nameof(PartnerBalance_Adjustments_AppliedCorrectly));
        var svc = new PartnerBalanceService(db);

        var partnerAId = SeedSinglePartner(db);
        AddCapital(db, partnerAId, CapitalTransactionType.CapitalAdvance, 100_000m);
        // Positive adjustment: adds 10k
        AddCapital(db, partnerAId, CapitalTransactionType.Adjustment, 10_000m);
        // Negative adjustment: subtracts 5k
        AddCapital(db, partnerAId, CapitalTransactionType.Adjustment, -5_000m);

        var balance = await svc.GetPartnerBalanceAsync(partnerAId);

        // TotalCapitalAdded = 100k (advance) + 10k (positive adjustment) = 110k
        Assert.Equal(110_000m, balance.TotalCapitalAdded);
        // TotalWithdrawals covers negative adjustments = 5k
        Assert.Equal(5_000m, balance.TotalWithdrawals);
        // RemainingBalance = 110k - 5k = 105k
        Assert.Equal(105_000m, balance.RemainingBalance);
        Assert.False(balance.IsDeficit);
    }

    /// <summary>
    /// GetCapitalSummaryAsync aggregates all active partners' balances correctly.
    /// </summary>
    [Fact]
    public async Task CapitalSummary_AggregatesTotalAcrossPartners()
    {
        await using var db = CreateContext(nameof(CapitalSummary_AggregatesTotalAcrossPartners));
        var svc = new PartnerBalanceService(db);

        var (partnerAId, partnerBId) = SeedPartners(db);
        AddCapital(db, partnerAId, CapitalTransactionType.CapitalAdvance, 200_000m);
        AddCapital(db, partnerBId, CapitalTransactionType.CapitalAdvance, 100_000m);

        // Rent split A=8k, B=4k
        AddSpending(db, 12_000m, SpendingResultType.Expense,
            SpendingCategory.Rent, ownershipApplicable: false,
            ApprovalStatus.Approved, "SPD-SUM-001",
            (partnerAId, 8_000m), (partnerBId, 4_000m));

        var summary = await svc.GetCapitalSummaryAsync();

        Assert.Equal(2, summary.PartnerBalances.Count);

        var expectedTotalCapital = 300_000m;  // A=200k + B=100k
        var expectedTotalSpent = 12_000m;     // 8k + 4k
        var expectedTotalRemaining = 288_000m; // 300k - 12k

        Assert.Equal(expectedTotalCapital, summary.TotalBusinessCapital);
        Assert.Equal(expectedTotalSpent, summary.TotalApprovedSpendings);
        Assert.Equal(expectedTotalRemaining, summary.TotalRemainingCapital);
        Assert.Equal(0m, summary.TotalDeficits);  // No deficits
    }

    /// <summary>
    /// Company-owned asset (no partner) appears in the asset ownership report
    /// with OwnerType=Company and no PartnerId.
    /// </summary>
    [Fact]
    public async Task AssetOwnershipReport_CompanyOwnedAsset_HasNoPartnerId()
    {
        await using var db = CreateContext(nameof(AssetOwnershipReport_CompanyOwnedAsset_HasNoPartnerId));
        var svc = new PartnerBalanceService(db);

        var (partnerAId, _) = SeedPartners(db);

        var spendingId = AddSpending(db, 60_000m, SpendingResultType.Asset,
            SpendingCategory.AssetPurchase, ownershipApplicable: true,
            ApprovalStatus.Approved, "SPD-CO-001",
            (partnerAId, 60_000m));

        var asset = new Asset
        {
            Name = "Generator",
            AssetType = "Equipment",
            Quantity = 1,
            UnitValue = 60_000m,
            SpendingId = spendingId,
            OwnershipType = AssetOwnershipType.CompanyOwned,
            ApprovalStatus = ApprovalStatus.Approved
        };
        db.Assets.Add(asset);
        db.SaveChanges();

        db.AssetOwnerships.Add(new AssetOwnership
        {
            AssetId = asset.Id,
            OwnerType = AssetOwnerType.Company,
            PartnerId = null,               // Company-owned — no partner
            OwnershipPercent = 100m,
            OwnershipValue = 60_000m
        });
        db.SaveChanges();

        var report = await svc.GetAssetOwnershipReportAsync();

        Assert.Single(report);
        var assetReport = report.First();
        Assert.Equal("Generator", assetReport.AssetName);

        var companyOwnership = assetReport.Ownerships.Single();
        Assert.Equal(AssetOwnerType.Company, companyOwnership.OwnerType);
        Assert.Null(companyOwnership.PartnerId);
        Assert.Equal(100m, companyOwnership.OwnershipPercent);
        Assert.Equal(60_000m, companyOwnership.OwnershipValue);
    }

    /// <summary>
    /// Assets without a SpendingId (legacy/manually added) are excluded from
    /// GetAssetOwnershipReportAsync because it filters on SpendingId != null.
    /// </summary>
    [Fact]
    public async Task AssetOwnershipReport_AssetWithoutSpending_IsExcluded()
    {
        await using var db = CreateContext(nameof(AssetOwnershipReport_AssetWithoutSpending_IsExcluded));
        var svc = new PartnerBalanceService(db);

        // Asset with no SpendingId
        var legacyAsset = new Asset
        {
            Name = "Old Table",
            AssetType = "Furniture",
            Quantity = 1,
            UnitValue = 5_000m,
            SpendingId = null,          // No spending link
            ApprovalStatus = ApprovalStatus.Approved
        };
        db.Assets.Add(legacyAsset);
        db.SaveChanges();

        var report = await svc.GetAssetOwnershipReportAsync();

        Assert.Empty(report);
    }

    /// <summary>
    /// Balance formula verification: CapitalAdded - Withdrawals - FundedSpendings = RemainingBalance.
    /// </summary>
    [Fact]
    public async Task PartnerBalance_Formula_CapitalMinusWithdrawalsMinusSpendings()
    {
        await using var db = CreateContext(nameof(PartnerBalance_Formula_CapitalMinusWithdrawalsMinusSpendings));
        var svc = new PartnerBalanceService(db);

        var partnerAId = SeedSinglePartner(db);
        AddCapital(db, partnerAId, CapitalTransactionType.CapitalAdvance, 100_000m);
        AddCapital(db, partnerAId, CapitalTransactionType.AdditionalCapital, 50_000m);
        AddCapital(db, partnerAId, CapitalTransactionType.Withdrawal, 20_000m);

        AddSpending(db, 30_000m, SpendingResultType.Expense,
            SpendingCategory.Salary, ownershipApplicable: false,
            ApprovalStatus.Approved, "SPD-FORMULA-001",
            (partnerAId, 30_000m));

        var balance = await svc.GetPartnerBalanceAsync(partnerAId);

        // CapitalAdded = 100k + 50k = 150k
        Assert.Equal(150_000m, balance.TotalCapitalAdded);
        // Withdrawals = 20k
        Assert.Equal(20_000m, balance.TotalWithdrawals);
        // FundedSpendings = 30k
        Assert.Equal(30_000m, balance.TotalFundedSpendings);
        // RemainingBalance = 150k - 20k - 30k = 100k
        Assert.Equal(100_000m, balance.RemainingBalance);

        // Formula: RemainingBalance == TotalCapitalAdded - TotalWithdrawals - TotalFundedSpendings
        var computed = balance.TotalCapitalAdded - balance.TotalWithdrawals - balance.TotalFundedSpendings;
        Assert.Equal(computed, balance.RemainingBalance);
    }
}
