using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TailorShop.Api.Extensions;
using TailorShop.Application.DTOs;
using TailorShop.Application.Services;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/invoices")]
[Authorize]
public class InvoicesController : ControllerBase
{
    private readonly InvoiceService _invoiceService;
    private readonly EmailService _emailService;

    public InvoicesController(InvoiceService invoiceService, EmailService emailService)
    {
        _invoiceService = invoiceService;
        _emailService = emailService;
    }

    [HttpGet]
    public async Task<IActionResult> GetInvoices()
    {
        var invoices = await _invoiceService.GetInvoicesAsync();
        return Ok(invoices);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetInvoice(Guid id)
    {
        var invoice = await _invoiceService.GetInvoiceByIdAsync(id);
        return invoice == null ? NotFound() : Ok(invoice);
    }

    [HttpPost("generate")]
    public async Task<IActionResult> GenerateInvoice([FromBody] GenerateInvoiceRequest request)
    {
        var invoice = await _invoiceService.GenerateInvoiceAsync(request, User.GetUserId());
        return Created($"/api/invoices/{invoice.Id}", invoice);
    }

    [HttpGet("{id}/pdf")]
    public async Task<IActionResult> GetPdf(Guid id)
    {
        var pdfBytes = await _invoiceService.GeneratePdfAsync(id);
        return File(pdfBytes, "application/pdf", $"invoice-{id}.pdf");
    }

    [HttpPost("{id}/email")]
    public async Task<IActionResult> EmailInvoice(Guid id, [FromBody] EmailInvoiceRequest request)
    {
        var pdfBytes = await _invoiceService.GeneratePdfAsync(id);
        var result = await _emailService.SendInvoiceEmailAsync(id, request.RecipientEmail, pdfBytes);
        return result ? Ok(new { message = "Email sent" }) : BadRequest(new { message = "Failed to send email" });
    }

    [HttpPost("{id}/mark-printed")]
    public async Task<IActionResult> MarkPrinted(Guid id)
    {
        var result = await _invoiceService.MarkPrintedAsync(id, User.GetUserId());
        return result ? Ok() : NotFound();
    }
}
