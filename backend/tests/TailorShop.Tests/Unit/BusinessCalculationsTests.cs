using TailorShop.Domain.Entities;
using TailorShop.Domain.Enums;
using Xunit;

namespace TailorShop.Tests.Unit;

public class BusinessCalculationsTests
{
    [Fact]
    public void Asset_TotalValue_ShouldBeQuantityTimesUnitValue()
    {
        var asset = new Asset { Quantity = 3, UnitValue = 15000m };
        Assert.Equal(45000m, asset.TotalValue);
    }

    [Fact]
    public void InventoryItem_TotalValue_ShouldBeStockTimesUnitCost()
    {
        var item = new InventoryItem { CurrentStock = 50, UnitCost = 500m };
        Assert.Equal(25000m, item.TotalValue);
    }

    [Fact]
    public void Order_TotalAmount_ShouldBeStitchingPlusMaterialMinusDiscount()
    {
        var order = new Order
        {
            StitchingAmount = 3000m,
            MaterialAmount = 2000m,
            Discount = 500m
        };
        Assert.Equal(4500m, order.TotalAmount);
    }

    [Fact]
    public void Order_BalanceAmount_ShouldBeTotalMinusPaid()
    {
        var order = new Order
        {
            StitchingAmount = 5000m,
            MaterialAmount = 3000m,
            Discount = 0m,
            PaidAmount = 3000m
        };
        Assert.Equal(5000m, order.BalanceAmount);
    }

    [Fact]
    public void Order_LabourAmount_ShouldBeStitchingTimesPercentage()
    {
        var order = new Order
        {
            StitchingAmount = 3000m,
            LabourSharePercentage = 35m
        };
        Assert.Equal(1050m, order.LabourAmount);
    }

    [Fact]
    public void Order_LabourAmount_ShouldNotIncludeMaterialAmount()
    {
        var order = new Order
        {
            StitchingAmount = 3000m,
            MaterialAmount = 5000m,
            LabourSharePercentage = 35m
        };
        // Labour is ONLY on stitching, not on material
        Assert.Equal(1050m, order.LabourAmount);
    }

    [Fact]
    public void NetProfit_Calculation()
    {
        // Revenue
        decimal stitching = 10000m;
        decimal material = 5000m;
        decimal discount = 500m;
        decimal revenue = stitching + material - discount; // 14500

        // Labour (only on stitching)
        decimal labourPercentage = 35m;
        decimal labour = stitching * labourPercentage / 100m; // 3500

        // Costs
        decimal inventoryCost = 2000m;
        decimal expenses = 1000m;

        decimal netProfit = revenue - labour - inventoryCost - expenses;
        Assert.Equal(8000m, netProfit);
    }

    [Fact]
    public void PartnerProfitSplit_ShouldBeCorrect()
    {
        decimal netProfit = 10000m;
        decimal partnerShare = 50m;

        decimal partnerProfit = netProfit * partnerShare / 100m;
        Assert.Equal(5000m, partnerProfit);
    }

    [Fact]
    public void InventoryTransaction_TotalCost_ShouldBeQuantityTimesUnitCost()
    {
        var tx = new InventoryTransaction { Quantity = 10, UnitCost = 500m };
        Assert.Equal(5000m, tx.TotalCost);
    }

    [Fact]
    public void OrderInventoryUsage_TotalCost_ShouldBeCorrect()
    {
        var usage = new OrderInventoryUsage { Quantity = 2.5m, UnitCost = 800m };
        Assert.Equal(2000m, usage.TotalCost);
    }

    [Fact]
    public void Invoice_BalanceAmount_ShouldBeTotalMinusPaid()
    {
        var invoice = new Invoice { TotalAmount = 8000m, PaidAmount = 3000m };
        Assert.Equal(5000m, invoice.BalanceAmount);
    }

    [Fact]
    public void InvoiceLine_Amount_ShouldBeQuantityTimesUnitPrice()
    {
        var line = new InvoiceLine { Quantity = 2, UnitPrice = 3000m };
        Assert.Equal(6000m, line.Amount);
    }
}
