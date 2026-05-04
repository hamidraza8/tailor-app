using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TailorShop.Application.DTOs;
using TailorShop.Domain.Entities;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/settings")]
[Authorize]
public class SettingsController : ControllerBase
{
    private readonly AppDbContext _db;

    public SettingsController(AppDbContext db) => _db = db;

    [HttpGet("business-profile")]
    public async Task<IActionResult> GetProfile()
    {
        var p = await _db.BusinessProfiles.FirstOrDefaultAsync();
        if (p == null) return NotFound();
        return Ok(new BusinessProfileDto(p.BusinessName, p.Phone, p.Email, p.Address,
            p.LogoFileId, p.DefaultLabourSharePercentage, p.InvoicePrefix, p.InvoiceFooter, p.Currency));
    }

    [HttpPut("business-profile")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateBusinessProfileRequest request)
    {
        var p = await _db.BusinessProfiles.FirstOrDefaultAsync();
        if (p == null)
        {
            p = new BusinessProfile();
            _db.BusinessProfiles.Add(p);
        }

        p.BusinessName = request.BusinessName;
        p.Phone = request.Phone;
        p.Email = request.Email;
        p.Address = request.Address;
        p.DefaultLabourSharePercentage = request.DefaultLabourSharePercentage;
        p.InvoicePrefix = request.InvoicePrefix;
        p.InvoiceFooter = request.InvoiceFooter;
        p.Currency = request.Currency;
        p.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return Ok();
    }
}
