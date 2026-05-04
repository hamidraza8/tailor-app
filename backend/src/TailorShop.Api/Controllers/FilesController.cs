using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TailorShop.Api.Extensions;
using TailorShop.Application.DTOs;
using TailorShop.Application.Services;
using TailorShop.Domain.Enums;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/files")]
[Authorize]
public class FilesController : ControllerBase
{
    private readonly FileService _fileService;

    public FilesController(FileService fileService) => _fileService = fileService;

    [HttpPost("upload")]
    public async Task<IActionResult> Upload(IFormFile file, [FromQuery] FileCategory category,
        [FromQuery] Guid? entityId, [FromQuery] string? entityType)
    {
        using var stream = file.OpenReadStream();
        var fileDto = await _fileService.UploadFileAsync(stream, file.FileName,
            file.ContentType, file.Length, category, entityId, entityType, User.GetUserId());
        return Ok(fileDto);
    }

    [HttpGet("{id}")]
    [AllowAnonymous]
    public async Task<IActionResult> GetFile(Guid id)
    {
        var (stream, contentType, fileName) = await _fileService.GetFileAsync(id);
        if (stream == null) return NotFound();
        return File(stream, contentType ?? "application/octet-stream", fileName);
    }
}
