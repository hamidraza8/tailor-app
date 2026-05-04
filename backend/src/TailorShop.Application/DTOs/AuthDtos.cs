using TailorShop.Domain.Enums;

namespace TailorShop.Application.DTOs;

public record LoginRequest(string Email, string Password);
public record LoginResponse(string Token, string RefreshToken, UserDto User);
public record RefreshRequest(string RefreshToken);

public record UserDto(
    Guid Id, string FullName, string Email, string Phone,
    UserRole Role, bool IsActive);

public record CreateUserRequest(
    string FullName, string Email, string Phone,
    string Password, UserRole Role);

public record UpdateUserRequest(
    string FullName, string Phone, bool IsActive);
