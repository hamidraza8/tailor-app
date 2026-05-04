using Microsoft.EntityFrameworkCore;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using TailorShop.Application.DTOs;
using TailorShop.Domain.Entities;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Application.Services;

public class InvoiceService
{
    private readonly AppDbContext _db;
    private readonly AuditService _audit;

    public InvoiceService(AppDbContext db, AuditService audit)
    {
        _db = db;
        _audit = audit;
    }

    public async Task<InvoiceDto> GenerateInvoiceAsync(GenerateInvoiceRequest request, Guid userId)
    {
        var order = await _db.Orders
            .Include(o => o.Customer)
            .Include(o => o.Payments)
            .FirstOrDefaultAsync(o => o.Id == request.OrderId);

        if (order == null) throw new Exception("Order not found");

        var profile = await _db.BusinessProfiles.FirstOrDefaultAsync();
        var invoiceNumber = $"{profile?.InvoicePrefix ?? "INV"}-{(profile?.NextInvoiceNumber ?? 1):D5}";

        if (profile != null)
        {
            profile.NextInvoiceNumber++;
            _db.BusinessProfiles.Update(profile);
        }

        var invoice = new Invoice
        {
            InvoiceNumber = invoiceNumber,
            OrderId = order.Id,
            CustomerId = order.CustomerId,
            SubTotal = order.StitchingAmount + order.MaterialAmount,
            Discount = order.Discount,
            TotalAmount = order.TotalAmount,
            PaidAmount = order.PaidAmount,
            Notes = request.Notes,
            CreatedBy = userId,
            Lines = new List<InvoiceLine>()
        };

        if (order.StitchingAmount > 0)
        {
            invoice.Lines.Add(new InvoiceLine
            {
                Description = $"Stitching - {order.OrderType}",
                Quantity = 1,
                UnitPrice = order.StitchingAmount
            });
        }

        if (order.MaterialAmount > 0)
        {
            invoice.Lines.Add(new InvoiceLine
            {
                Description = "Material/Fabric",
                Quantity = 1,
                UnitPrice = order.MaterialAmount
            });
        }

        _db.Invoices.Add(invoice);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("Invoice", invoice.Id, "Create", userId);

        return MapInvoice(invoice, order.Customer, order);
    }

    public async Task<byte[]> GeneratePdfAsync(Guid invoiceId)
    {
        var invoice = await _db.Invoices
            .Include(i => i.Lines)
            .Include(i => i.Order)
            .Include(i => i.Customer)
            .FirstOrDefaultAsync(i => i.Id == invoiceId);

        if (invoice == null) throw new Exception("Invoice not found");

        var profile = await _db.BusinessProfiles.FirstOrDefaultAsync();

        QuestPDF.Settings.License = LicenseType.Community;

        var document = Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(30);
                page.DefaultTextStyle(x => x.FontSize(10));

                page.Header().Column(col =>
                {
                    col.Item().Row(row =>
                    {
                        row.RelativeItem().Column(c =>
                        {
                            c.Item().Text(profile?.BusinessName ?? "Tailor Shop")
                                .FontSize(20).Bold();
                            if (!string.IsNullOrEmpty(profile?.Phone))
                                c.Item().Text($"Phone: {profile.Phone}");
                            if (!string.IsNullOrEmpty(profile?.Address))
                                c.Item().Text(profile.Address);
                        });
                        row.RelativeItem().AlignRight().Column(c =>
                        {
                            c.Item().Text("INVOICE").FontSize(16).Bold();
                            c.Item().Text($"#{invoice.InvoiceNumber}");
                            c.Item().Text($"Date: {invoice.InvoiceDate:dd/MM/yyyy}");
                        });
                    });
                    col.Item().PaddingVertical(10).LineHorizontal(1);
                });

                page.Content().Column(col =>
                {
                    // Customer info
                    col.Item().PaddingBottom(10).Column(c =>
                    {
                        c.Item().Text("Bill To:").Bold();
                        c.Item().Text(invoice.Customer?.Name ?? "");
                        c.Item().Text(invoice.Customer?.Phone ?? "");
                    });

                    // Order info
                    col.Item().PaddingBottom(10).Column(c =>
                    {
                        c.Item().Text($"Order: {invoice.Order?.OrderNumber}");
                        c.Item().Text($"Type: {invoice.Order?.OrderType}");
                        if (invoice.Order?.DueDate.HasValue == true)
                            c.Item().Text($"Delivery Date: {invoice.Order.DueDate:dd/MM/yyyy}");
                    });

                    // Line items table
                    col.Item().Table(table =>
                    {
                        table.ColumnsDefinition(columns =>
                        {
                            columns.RelativeColumn(3);
                            columns.RelativeColumn(1);
                            columns.RelativeColumn(1);
                            columns.RelativeColumn(1);
                        });

                        table.Header(header =>
                        {
                            header.Cell().Background(Colors.Grey.Lighten3).Padding(5).Text("Description").Bold();
                            header.Cell().Background(Colors.Grey.Lighten3).Padding(5).AlignRight().Text("Qty").Bold();
                            header.Cell().Background(Colors.Grey.Lighten3).Padding(5).AlignRight().Text("Rate").Bold();
                            header.Cell().Background(Colors.Grey.Lighten3).Padding(5).AlignRight().Text("Amount").Bold();
                        });

                        foreach (var line in invoice.Lines)
                        {
                            table.Cell().Padding(5).Text(line.Description);
                            table.Cell().Padding(5).AlignRight().Text(line.Quantity.ToString());
                            table.Cell().Padding(5).AlignRight().Text($"Rs {line.UnitPrice:N0}");
                            table.Cell().Padding(5).AlignRight().Text($"Rs {line.Amount:N0}");
                        }
                    });

                    // Totals
                    col.Item().PaddingTop(10).AlignRight().Column(c =>
                    {
                        c.Item().Row(r =>
                        {
                            r.RelativeItem().AlignRight().Text("Sub Total:");
                            r.ConstantItem(100).AlignRight().Text($"Rs {invoice.SubTotal:N0}");
                        });
                        if (invoice.Discount > 0)
                        {
                            c.Item().Row(r =>
                            {
                                r.RelativeItem().AlignRight().Text("Discount:");
                                r.ConstantItem(100).AlignRight().Text($"Rs {invoice.Discount:N0}");
                            });
                        }
                        c.Item().Row(r =>
                        {
                            r.RelativeItem().AlignRight().Text("Total:").Bold();
                            r.ConstantItem(100).AlignRight().Text($"Rs {invoice.TotalAmount:N0}").Bold();
                        });
                        c.Item().Row(r =>
                        {
                            r.RelativeItem().AlignRight().Text("Paid:");
                            r.ConstantItem(100).AlignRight().Text($"Rs {invoice.PaidAmount:N0}");
                        });
                        c.Item().Row(r =>
                        {
                            r.RelativeItem().AlignRight().Text("Balance:").Bold();
                            r.ConstantItem(100).AlignRight().Text($"Rs {invoice.BalanceAmount:N0}").Bold();
                        });
                    });

                    if (!string.IsNullOrEmpty(invoice.Notes))
                    {
                        col.Item().PaddingTop(20).Column(c =>
                        {
                            c.Item().Text("Notes:").Bold();
                            c.Item().Text(invoice.Notes);
                        });
                    }
                });

                page.Footer().AlignCenter().Text(text =>
                {
                    text.Span(profile?.InvoiceFooter ?? "Thank you for your business!");
                });
            });
        });

        return document.GeneratePdf();
    }

    public async Task<bool> MarkPrintedAsync(Guid id, Guid userId)
    {
        var invoice = await _db.Invoices.FindAsync(id);
        if (invoice == null) return false;

        invoice.IsPrinted = true;
        invoice.PrintedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return true;
    }

    public async Task<InvoiceDto?> GetInvoiceByIdAsync(Guid id)
    {
        var invoice = await _db.Invoices
            .Include(i => i.Lines)
            .Include(i => i.Order)
            .Include(i => i.Customer)
            .FirstOrDefaultAsync(i => i.Id == id);
        return invoice == null ? null : MapInvoice(invoice, invoice.Customer, invoice.Order);
    }

    public async Task<List<InvoiceDto>> GetInvoicesAsync()
    {
        var invoices = await _db.Invoices
            .Include(i => i.Lines)
            .Include(i => i.Order)
            .Include(i => i.Customer)
            .OrderByDescending(i => i.CreatedAt)
            .ToListAsync();
        return invoices.Select(i => MapInvoice(i, i.Customer, i.Order)).ToList();
    }

    private static InvoiceDto MapInvoice(Invoice i, Customer? customer, Order? order) => new(
        i.Id, i.InvoiceNumber, i.OrderId, order?.OrderNumber ?? "",
        i.CustomerId, customer?.Name ?? "", i.InvoiceDate,
        i.SubTotal, i.Discount, i.TotalAmount, i.PaidAmount, i.BalanceAmount,
        i.Notes, i.IsPrinted,
        i.Lines?.Select(l => new InvoiceLineDto(l.Id, l.Description, l.Quantity, l.UnitPrice, l.Amount)).ToList() ?? new(),
        i.CreatedAt);
}
