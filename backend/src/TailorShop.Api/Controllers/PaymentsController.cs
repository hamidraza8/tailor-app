using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TailorShop.Api.Extensions;
using TailorShop.Application.DTOs;
using TailorShop.Application.Services;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/payments")]
[Authorize]
public class PaymentsController : ControllerBase
{
    private readonly PaymentService _paymentService;
    private readonly AppDbContext _db;

    public PaymentsController(PaymentService paymentService, AppDbContext db)
    {
        _paymentService = paymentService;
        _db = db;
    }

    [HttpPost]
    public async Task<IActionResult> CreatePayment([FromBody] CreatePaymentRequest request)
    {
        var payment = await _paymentService.CreatePaymentAsync(request, User.GetUserId());
        return Created($"/api/payments/{payment.Id}", payment);
    }

    [HttpGet("by-order/{orderId}")]
    public async Task<IActionResult> GetByOrder(Guid orderId)
    {
        var payments = await _paymentService.GetPaymentsByOrderAsync(orderId);
        return Ok(payments);
    }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] DateTime? from, [FromQuery] DateTime? to)
    {
        var payments = await _paymentService.GetAllPaymentsAsync(from, to);
        return Ok(payments);
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeletePayment(Guid id)
    {
        var payment = await _db.Payments.FindAsync(id);
        if (payment == null) return NotFound();
        payment.IsDeleted = true;
        payment.UpdatedBy = User.GetUserId();
        payment.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return NoContent();
    }
}
