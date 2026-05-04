using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TailorShop.Api.Extensions;
using TailorShop.Application.DTOs;
using TailorShop.Application.Services;
using TailorShop.Domain.Enums;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/assets")]
[Authorize]
public class AssetsController : ControllerBase
{
    private readonly AssetService _assetService;
    private readonly FileService _fileService;
    private readonly AppDbContext _db;

    public AssetsController(AssetService assetService, FileService fileService, AppDbContext db)
    {
        _assetService = assetService;
        _fileService = fileService;
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetAssets([FromQuery] ApprovalStatus? status)
    {
        var assets = await _assetService.GetAssetsAsync(status);
        return Ok(assets);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetAsset(Guid id)
    {
        var asset = await _assetService.GetAssetByIdAsync(id);
        return asset == null ? NotFound() : Ok(asset);
    }

    [HttpPost]
    public async Task<IActionResult> CreateAsset([FromBody] CreateAssetRequest request)
    {
        var asset = await _assetService.CreateAssetAsync(request, User.GetUserId());
        return Created($"/api/assets/{asset.Id}", asset);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateAsset(Guid id, [FromBody] UpdateAssetRequest request)
    {
        var asset = await _assetService.UpdateAssetAsync(id, request, User.GetUserId());
        return asset == null ? NotFound() : Ok(asset);
    }

    [HttpPost("{id}/photos")]
    public async Task<IActionResult> UploadPhoto(Guid id, IFormFile file)
    {
        using var stream = file.OpenReadStream();
        var fileDto = await _fileService.UploadFileAsync(stream, file.FileName,
            file.ContentType, file.Length, FileCategory.AssetPhoto, id, "Asset", User.GetUserId());
        return Ok(fileDto);
    }

    [HttpPost("{id}/approve")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Approve(Guid id, [FromBody] ApprovalRequest request)
    {
        var result = await _assetService.ApproveAsync(id, request.Comment, User.GetUserId());
        return result ? Ok() : NotFound();
    }

    [HttpPost("{id}/reject")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Reject(Guid id, [FromBody] ApprovalRequest request)
    {
        var result = await _assetService.RejectAsync(id, request.Comment, User.GetUserId());
        return result ? Ok() : NotFound();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteAsset(Guid id)
    {
        var asset = await _db.Assets.FindAsync(id);
        if (asset == null) return NotFound();
        asset.IsDeleted = true;
        asset.UpdatedBy = User.GetUserId();
        asset.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return NoContent();
    }
}
