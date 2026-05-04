using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TailorShop.Api.Extensions;
using TailorShop.Application.DTOs;
using TailorShop.Application.Services;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/capital-transactions")]
[Authorize]
public class CapitalTransactionsController : ControllerBase
{
    private readonly CapitalTransactionService _service;

    public CapitalTransactionsController(CapitalTransactionService service)
        => _service = service;

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var txs = await _service.GetAllAsync();
        return Ok(txs);
    }

    [HttpGet("partner/{partnerId}")]
    public async Task<IActionResult> GetByPartner(Guid partnerId)
    {
        var txs = await _service.GetByPartnerAsync(partnerId);
        return Ok(txs);
    }

    [HttpPost("partner/{partnerId}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create(Guid partnerId, [FromBody] CreateCapitalTransactionRequest request)
    {
        try
        {
            var tx = await _service.CreateAsync(partnerId, request, User.GetUserId());
            return Created($"/api/capital-transactions/partner/{partnerId}", tx);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.InnerException?.Message ?? ex.Message });
        }
    }
}
