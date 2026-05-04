using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TailorShop.Application.Services;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/reports")]
[Authorize]
public class ReportsController : ControllerBase
{
    private readonly ReportService _reportService;
    private readonly PartnerBalanceService _partnerBalanceService;

    public ReportsController(ReportService reportService, PartnerBalanceService partnerBalanceService)
    {
        _reportService = reportService;
        _partnerBalanceService = partnerBalanceService;
    }

    [HttpGet("dashboard")]
    public async Task<IActionResult> GetDashboard()
    {
        var dashboard = await _reportService.GetDashboardAsync();
        return Ok(dashboard);
    }

    [HttpGet("profit-summary")]
    public async Task<IActionResult> GetProfitSummary([FromQuery] DateTime from, [FromQuery] DateTime to)
    {
        var summary = await _reportService.GetProfitSummaryAsync(from, to);
        return Ok(summary);
    }

    [HttpGet("labour-payable")]
    public async Task<IActionResult> GetLabourReport([FromQuery] DateTime? from, [FromQuery] DateTime? to)
    {
        var report = await _reportService.GetLabourReportAsync(from, to);
        return Ok(report);
    }

    [HttpGet("inventory-value")]
    public async Task<IActionResult> GetInventoryValue()
    {
        var value = await _reportService.GetInventoryValueAsync();
        return Ok(new { value });
    }

    [HttpGet("assets-value")]
    public async Task<IActionResult> GetAssetValue()
    {
        var value = await _reportService.GetAssetValueAsync();
        return Ok(new { value });
    }

    [HttpGet("partner-balances")]
    public async Task<IActionResult> GetPartnerBalances()
    {
        var summary = await _partnerBalanceService.GetCapitalSummaryAsync();
        return Ok(summary);
    }

    [HttpGet("partner-balances/{partnerId}")]
    public async Task<IActionResult> GetPartnerBalance(Guid partnerId)
    {
        try
        {
            var balance = await _partnerBalanceService.GetPartnerBalanceAsync(partnerId);
            return Ok(balance);
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
    }

    [HttpGet("funding-splits")]
    public async Task<IActionResult> GetFundingSplitReport([FromQuery] DateTime? from, [FromQuery] DateTime? to)
    {
        var report = await _partnerBalanceService.GetFundingSplitReportAsync(from, to);
        return Ok(report);
    }

    [HttpGet("asset-ownership")]
    public async Task<IActionResult> GetAssetOwnershipReport()
    {
        var report = await _partnerBalanceService.GetAssetOwnershipReportAsync();
        return Ok(report);
    }
}
