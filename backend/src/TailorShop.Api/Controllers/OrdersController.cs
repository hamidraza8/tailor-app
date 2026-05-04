using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TailorShop.Api.Extensions;
using TailorShop.Application.DTOs;
using TailorShop.Application.Services;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/orders")]
[Authorize]
public class OrdersController : ControllerBase
{
    private readonly OrderService _orderService;
    private readonly FileService _fileService;
    private readonly AppDbContext _db;

    public OrdersController(OrderService orderService, FileService fileService, AppDbContext db)
    {
        _orderService = orderService;
        _fileService = fileService;
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetOrders([FromQuery] DateTime? from, [FromQuery] DateTime? to,
        [FromQuery] OrderStatus? status, [FromQuery] Guid? customerId)
    {
        var orders = await _orderService.GetOrdersAsync(from, to, status, customerId);
        return Ok(orders);
    }

    [HttpGet("today")]
    public async Task<IActionResult> GetTodaysOrders()
    {
        var orders = await _orderService.GetTodaysOrdersAsync();
        return Ok(orders);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetOrder(Guid id)
    {
        var order = await _orderService.GetOrderByIdAsync(id);
        return order == null ? NotFound() : Ok(order);
    }

    [HttpPost]
    public async Task<IActionResult> CreateOrder([FromBody] CreateOrderRequest request)
    {
        try
        {
            var order = await _orderService.CreateOrderAsync(request, User.GetUserId());
            return Created($"/api/orders/{order.Id}", order);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.InnerException?.Message ?? ex.Message, stack = ex.StackTrace?.Substring(0, Math.Min(500, ex.StackTrace.Length)) });
        }
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateOrder(Guid id, [FromBody] UpdateOrderRequest request)
    {
        var order = await _orderService.UpdateOrderAsync(id, request, User.GetUserId());
        return order == null ? NotFound() : Ok(order);
    }

    [HttpPost("{id}/status")]
    public async Task<IActionResult> UpdateStatus(Guid id, [FromBody] UpdateOrderStatusRequest request)
    {
        var order = await _orderService.UpdateStatusAsync(id, request, User.GetUserId());
        return order == null ? NotFound() : Ok(order);
    }

    [HttpPost("{id}/photos")]
    public async Task<IActionResult> UploadPhoto(Guid id, IFormFile file)
    {
        using var stream = file.OpenReadStream();
        var fileDto = await _fileService.UploadFileAsync(stream, file.FileName,
            file.ContentType, file.Length, FileCategory.OrderPhoto, id, "Order", User.GetUserId());
        return Ok(fileDto);
    }

    [HttpPost("{id}/inventory-usage")]
    public async Task<IActionResult> AddInventoryUsage(Guid id, [FromBody] OrderInventoryUsageRequest request)
    {
        await _orderService.AddInventoryUsageAsync(id, request, User.GetUserId());
        return Ok();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteOrder(Guid id)
    {
        var order = await _db.Orders.FindAsync(id);
        if (order == null) return NotFound();
        order.IsDeleted = true;
        order.UpdatedBy = User.GetUserId();
        order.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return NoContent();
    }
}
