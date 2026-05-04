using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TailorShop.Api.Extensions;
using TailorShop.Application.DTOs;
using TailorShop.Application.Services;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/inventory")]
[Authorize]
public class InventoryController : ControllerBase
{
    private readonly InventoryService _inventoryService;
    private readonly FileService _fileService;
    private readonly AppDbContext _db;

    public InventoryController(InventoryService inventoryService, FileService fileService, AppDbContext db)
    {
        _inventoryService = inventoryService;
        _fileService = fileService;
        _db = db;
    }

    [HttpGet("items")]
    public async Task<IActionResult> GetItems()
    {
        var items = await _inventoryService.GetItemsAsync();
        return Ok(items);
    }

    [HttpPost("items")]
    public async Task<IActionResult> CreateItem([FromBody] CreateInventoryItemRequest request)
    {
        var item = await _inventoryService.CreateItemAsync(request, User.GetUserId());
        return Created($"/api/inventory/items/{item.Id}", item);
    }

    [HttpPost("transactions")]
    public async Task<IActionResult> CreateTransaction([FromBody] CreateInventoryTransactionRequest request)
    {
        var tx = await _inventoryService.CreateTransactionAsync(request, User.GetUserId());
        return Created("", tx);
    }

    [HttpPost("transactions/{id}/approve")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> ApproveTransaction(Guid id, [FromBody] ApprovalRequest request)
    {
        var result = await _inventoryService.ApproveTransactionAsync(id, request.Comment, User.GetUserId());
        return result ? Ok() : NotFound();
    }

    [HttpPost("transactions/{id}/reject")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> RejectTransaction(Guid id, [FromBody] ApprovalRequest request)
    {
        var result = await _inventoryService.RejectTransactionAsync(id, request.Comment, User.GetUserId());
        return result ? Ok() : NotFound();
    }

    [HttpPost("transactions/{id}/photos")]
    public async Task<IActionResult> UploadPhoto(Guid id, IFormFile file)
    {
        using var stream = file.OpenReadStream();
        var fileDto = await _fileService.UploadFileAsync(stream, file.FileName,
            file.ContentType, file.Length, FileCategory.InventoryReceipt, id, "InventoryTransaction", User.GetUserId());
        return Ok(fileDto);
    }

    [HttpDelete("items/{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteInventoryItem(Guid id)
    {
        var item = await _db.InventoryItems.FindAsync(id);
        if (item == null) return NotFound();
        item.IsDeleted = true;
        item.UpdatedBy = User.GetUserId();
        item.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("transactions/{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteTransaction(Guid id)
    {
        var tx = await _db.InventoryTransactions.FindAsync(id);
        if (tx == null) return NotFound();
        tx.IsDeleted = true;
        tx.UpdatedBy = User.GetUserId();
        tx.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return NoContent();
    }
}
