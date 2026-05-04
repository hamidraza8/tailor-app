using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TailorShop.Api.Extensions;
using TailorShop.Application.DTOs;
using TailorShop.Application.Services;

namespace TailorShop.Api.Controllers;

[ApiController]
[Route("api/customers")]
[Authorize]
public class CustomersController : ControllerBase
{
    private readonly CustomerService _customerService;

    public CustomersController(CustomerService customerService) => _customerService = customerService;

    [HttpGet]
    public async Task<IActionResult> GetCustomers([FromQuery] string? search)
    {
        var customers = await _customerService.GetCustomersAsync(search);
        return Ok(customers);
    }

    [HttpPost]
    public async Task<IActionResult> CreateCustomer([FromBody] CreateCustomerRequest request)
    {
        var customer = await _customerService.CreateCustomerAsync(request, User.GetUserId());
        return Created($"/api/customers/{customer.Id}", customer);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateCustomer(Guid id, [FromBody] UpdateCustomerRequest request)
    {
        var customer = await _customerService.UpdateCustomerAsync(id, request, User.GetUserId());
        return customer == null ? NotFound() : Ok(customer);
    }

    [HttpGet("{customerId}/measurements")]
    public async Task<IActionResult> GetMeasurements(Guid customerId)
    {
        var measurements = await _customerService.GetMeasurementsAsync(customerId);
        return Ok(measurements);
    }

    [HttpPost("measurements")]
    public async Task<IActionResult> CreateMeasurement([FromBody] CreateMeasurementRequest request)
    {
        var measurement = await _customerService.CreateMeasurementAsync(request, User.GetUserId());
        return Created("", measurement);
    }
}
