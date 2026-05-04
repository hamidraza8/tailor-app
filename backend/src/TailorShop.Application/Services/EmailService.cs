using System.Net;
using System.Net.Mail;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using TailorShop.Domain.Entities;
using TailorShop.Infrastructure.Data;

namespace TailorShop.Application.Services;

public class EmailService
{
    private readonly AppDbContext _db;
    private readonly ILogger<EmailService> _logger;

    public EmailService(AppDbContext db, ILogger<EmailService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<bool> SendInvoiceEmailAsync(Guid invoiceId, string recipientEmail, byte[] pdfBytes)
    {
        var invoice = await _db.Invoices
            .Include(i => i.Customer)
            .FirstOrDefaultAsync(i => i.Id == invoiceId);

        if (invoice == null) return false;

        var profile = await _db.BusinessProfiles.FirstOrDefaultAsync();
        if (profile == null || string.IsNullOrEmpty(profile.SmtpHost))
        {
            _logger.LogWarning("SMTP not configured");
            return false;
        }

        var log = new InvoiceEmailLog
        {
            InvoiceId = invoiceId,
            RecipientEmail = recipientEmail,
        };

        try
        {
            using var client = new SmtpClient(profile.SmtpHost, profile.SmtpPort)
            {
                Credentials = new NetworkCredential(profile.SmtpUser, profile.SmtpPassword),
                EnableSsl = true
            };

            var message = new MailMessage
            {
                From = new MailAddress(profile.SmtpFromEmail ?? profile.SmtpUser ?? "", profile.SmtpFromName ?? profile.BusinessName),
                Subject = $"Invoice {invoice.InvoiceNumber} - {profile.BusinessName}",
                Body = $"Dear {invoice.Customer?.Name},\n\nPlease find attached your invoice {invoice.InvoiceNumber}.\n\nTotal: Rs {invoice.TotalAmount:N0}\nPaid: Rs {invoice.PaidAmount:N0}\nBalance: Rs {invoice.BalanceAmount:N0}\n\nThank you for choosing {profile.BusinessName}!",
                IsBodyHtml = false
            };
            message.To.Add(recipientEmail);

            using var ms = new MemoryStream(pdfBytes);
            message.Attachments.Add(new Attachment(ms, $"{invoice.InvoiceNumber}.pdf", "application/pdf"));

            await client.SendMailAsync(message);

            log.IsSuccess = true;
            _logger.LogInformation("Invoice email sent to {Email}", recipientEmail);
        }
        catch (Exception ex)
        {
            log.IsSuccess = false;
            log.FailureReason = ex.Message;
            _logger.LogError(ex, "Failed to send invoice email to {Email}", recipientEmail);
        }

        _db.InvoiceEmailLogs.Add(log);
        await _db.SaveChangesAsync();
        return log.IsSuccess;
    }
}
