using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TailorShop.Api.Extensions;
using TailorShop.Application.DTOs;
using TailorShop.Application.Services;
using TailorShop.Domain.Entities;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/partners")]
[Authorize]
public class PartnersController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly AuditService _audit;

    public PartnersController(AppDbContext db, AuditService audit)
    {
        _db = db;
        _audit = audit;
    }

    [HttpGet]
    public async Task<IActionResult> GetPartners()
    {
        var partners = await _db.Partners.Include(p => p.User).ToListAsync();
        return Ok(partners.Select(p => new PartnerDto(
            p.Id, p.UserId, p.User?.FullName ?? "", p.ProfitSharePercentage,
            p.LabourSharePercentage, p.Notes)));
    }

    [HttpPost]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> CreatePartner([FromBody] CreatePartnerRequest request)
    {
        var partner = new Partner
        {
            UserId = request.UserId,
            ProfitSharePercentage = request.ProfitSharePercentage,
            LabourSharePercentage = request.LabourSharePercentage,
            Notes = request.Notes,
            CreatedBy = User.GetUserId()
        };

        _db.Partners.Add(partner);
        await _db.SaveChangesAsync();
        return Created($"/api/partners/{partner.Id}", partner);
    }

    [HttpPost("{id}/capital-transactions")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> AddCapitalTransaction(Guid id, [FromBody] CreateCapitalTransactionRequest request)
    {
        try
        {
            var transaction = new CapitalTransaction
            {
                PartnerId = id,
                Type = request.Type,
                Amount = request.Amount,
                TransactionDate = request.TransactionDate.HasValue
                    ? DateTime.SpecifyKind(request.TransactionDate.Value, DateTimeKind.Utc)
                    : DateTime.UtcNow,
                Notes = request.Notes,
                ReceiptFileUrl = request.ReceiptFileUrl,
                ApprovalStatus = ApprovalStatus.Approved,
                ApprovedBy = User.GetUserId(),
                ApprovedAt = DateTime.UtcNow,
                CreatedBy = User.GetUserId()
            };

            _db.CapitalTransactions.Add(transaction);
            await _db.SaveChangesAsync();
            await _audit.LogAsync("CapitalTransaction", transaction.Id, "Create", User.GetUserId());
            return Ok(new { transaction.Id, transaction.Type, transaction.Amount, transaction.TransactionDate, transaction.Notes });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.InnerException?.Message ?? ex.Message });
        }
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeletePartner(Guid id)
    {
        var partner = await _db.Partners.FindAsync(id);
        if (partner == null) return NotFound();
        partner.IsDeleted = true;
        partner.UpdatedBy = User.GetUserId();
        partner.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdatePartner(Guid id, [FromBody] UpdatePartnerRequest request)
    {
        var partner = await _db.Partners.FindAsync(id);
        if (partner == null) return NotFound();
        if (request.ProfitSharePercentage.HasValue) partner.ProfitSharePercentage = request.ProfitSharePercentage.Value;
        if (request.LabourSharePercentage.HasValue) partner.LabourSharePercentage = request.LabourSharePercentage.Value;
        if (request.Notes != null) partner.Notes = request.Notes;
        partner.UpdatedBy = User.GetUserId();
        partner.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return Ok(new PartnerDto(partner.Id, partner.UserId, "", partner.ProfitSharePercentage, partner.LabourSharePercentage, partner.Notes));
    }
}
