using Microsoft.EntityFrameworkCore;
using TailorShop.Application.DTOs;
using TailorShop.Domain.Entities;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Application.Services;

public class CustomerService
{
    private readonly AppDbContext _db;
    private readonly AuditService _audit;

    public CustomerService(AppDbContext db, AuditService audit)
    {
        _db = db;
        _audit = audit;
    }

    public async Task<List<CustomerDto>> GetCustomersAsync(string? search = null)
    {
        var query = _db.Customers.Include(c => c.Orders).AsQueryable();
        if (!string.IsNullOrEmpty(search))
            query = query.Where(c => c.Name.Contains(search) || c.Phone.Contains(search));

        var customers = await query.OrderByDescending(c => c.CreatedAt).ToListAsync();
        return customers.Select(c => new CustomerDto(
            c.Id, c.Name, c.Phone, c.Email, c.Address, c.Notes,
            c.Orders?.Count ?? 0, c.CreatedAt)).ToList();
    }

    public async Task<CustomerDto> CreateCustomerAsync(CreateCustomerRequest request, Guid userId)
    {
        var customer = new Customer
        {
            Name = request.Name,
            Phone = request.Phone,
            Email = request.Email,
            Address = request.Address,
            Notes = request.Notes,
            CreatedBy = userId
        };

        _db.Customers.Add(customer);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("Customer", customer.Id, "Create", userId);
        return new CustomerDto(customer.Id, customer.Name, customer.Phone,
            customer.Email, customer.Address, customer.Notes, 0, customer.CreatedAt);
    }

    public async Task<CustomerDto?> UpdateCustomerAsync(Guid id, UpdateCustomerRequest request, Guid userId)
    {
        var customer = await _db.Customers.FindAsync(id);
        if (customer == null) return null;

        customer.Name = request.Name;
        customer.Phone = request.Phone;
        customer.Email = request.Email;
        customer.Address = request.Address;
        customer.Notes = request.Notes;
        customer.UpdatedAt = DateTime.UtcNow;
        customer.UpdatedBy = userId;

        await _db.SaveChangesAsync();
        await _audit.LogAsync("Customer", id, "Update", userId);
        return new CustomerDto(customer.Id, customer.Name, customer.Phone,
            customer.Email, customer.Address, customer.Notes, 0, customer.CreatedAt);
    }

    public async Task<List<MeasurementDto>> GetMeasurementsAsync(Guid customerId)
    {
        var measurements = await _db.CustomerMeasurements
            .Where(m => m.CustomerId == customerId)
            .OrderByDescending(m => m.CreatedAt)
            .ToListAsync();
        return measurements.Select(MapMeasurement).ToList();
    }

    public async Task<MeasurementDto> CreateMeasurementAsync(CreateMeasurementRequest request, Guid userId)
    {
        var m = new CustomerMeasurement
        {
            CustomerId = request.CustomerId,
            Label = request.Label,
            Length = request.Length, Shoulder = request.Shoulder,
            Chest = request.Chest, Waist = request.Waist, Hip = request.Hip,
            SleeveLength = request.SleeveLength, SleeveWidth = request.SleeveWidth,
            Armhole = request.Armhole, Neck = request.Neck,
            TrouserLength = request.TrouserLength, TrouserWaist = request.TrouserWaist,
            Inseam = request.Inseam, ThighWidth = request.ThighWidth,
            BottomWidth = request.BottomWidth, DamanWidth = request.DamanWidth,
            FrontDrop = request.FrontDrop, BackDrop = request.BackDrop,
            CustomFieldsJson = request.CustomFieldsJson, Notes = request.Notes,
            CreatedBy = userId
        };

        _db.CustomerMeasurements.Add(m);
        await _db.SaveChangesAsync();
        return MapMeasurement(m);
    }

    private static MeasurementDto MapMeasurement(CustomerMeasurement m) => new(
        m.Id, m.CustomerId, m.Label, m.Length, m.Shoulder, m.Chest, m.Waist, m.Hip,
        m.SleeveLength, m.SleeveWidth, m.Armhole, m.Neck,
        m.TrouserLength, m.TrouserWaist, m.Inseam, m.ThighWidth,
        m.BottomWidth, m.DamanWidth, m.FrontDrop, m.BackDrop,
        m.CustomFieldsJson, m.Notes);
}
