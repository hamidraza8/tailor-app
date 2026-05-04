using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TailorShop.Api.Extensions;
using TailorShop.Application.DTOs;
using TailorShop.Application.Services;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/spendings")]
[Authorize]
public class SpendingsController : ControllerBase
{
    private readonly SpendingService _spendingService;
    private readonly AppDbContext _db;

    public SpendingsController(SpendingService spendingService, AppDbContext db)
    {
        _spendingService = spendingService;
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetSpendings(
        [FromQuery] ApprovalStatus? status,
        [FromQuery] SpendingCategory? category,
        [FromQuery] SpendingResultType? resultType,
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to)
    {
        var spendings = await _spendingService.GetSpendingsAsync(status, category, resultType, from, to);
        return Ok(spendings);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetSpending(Guid id)
    {
        var spending = await _spendingService.GetSpendingByIdAsync(id);
        if (spending == null) return NotFound();
        return Ok(spending);
    }

    [HttpPost]
    public async Task<IActionResult> CreateSpending([FromBody] CreateSpendingRequest request)
    {
        try
        {
            var (spending, warning) = await _spendingService.CreateSpendingAsync(request, User.GetUserId());
            return Created($"/api/spendings/{spending.Id}", new { spending, warning });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.InnerException?.Message ?? ex.Message });
        }
    }

    [HttpPost("{id}/approve")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Approve(Guid id, [FromBody] ApprovalRequest request)
    {
        var ok = await _spendingService.ApproveAsync(id, request.Comment, User.GetUserId());
        if (!ok) return NotFound();
        return Ok(new { message = "Spending approved." });
    }

    [HttpPost("{id}/reject")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Reject(Guid id, [FromBody] ApprovalRequest request)
    {
        var ok = await _spendingService.RejectAsync(id, request.Comment, User.GetUserId());
        if (!ok) return NotFound();
        return Ok(new { message = "Spending rejected." });
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteSpending(Guid id)
    {
        var spending = await _db.Spendings.FindAsync(id);
        if (spending == null) return NotFound();
        spending.IsDeleted = true;
        spending.UpdatedBy = User.GetUserId();
        spending.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return NoContent();
    }
}
