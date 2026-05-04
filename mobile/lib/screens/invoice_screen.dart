import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class InvoiceScreen extends StatefulWidget {
  final int orderId;

  const InvoiceScreen({super.key, required this.orderId});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  Order? _order;
  List<Payment> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final order = await DatabaseService.getOrderById(widget.orderId);
    List<Payment> payments = [];
    if (order != null) {
      payments = await DatabaseService.getPaymentsByOrder(order.id!);
    }
    setState(() {
      _order = order;
      _payments = payments;
      _loading = false;
    });
  }

  Future<pw.Document> _buildPdf() async {
    final pdf = pw.Document();
    final order = _order!;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TAILOR SHOP',
                          style: pw.TextStyle(
                              fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('Invoice / رسید',
                          style: const pw.TextStyle(fontSize: 14)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date: ${Helpers.formatDate(order.createdAt)}',
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('Order #${order.id}',
                          style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // Customer info
              pw.Text('Customer:',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(order.customerName ?? 'N/A',
                  style: const pw.TextStyle(fontSize: 14)),
              pw.Text(order.customerPhone ?? '',
                  style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 16),

              // Order details table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Description',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount (PKR)',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  _pdfTableRow(
                      '${order.orderType} - Stitching', order.stitchingAmount),
                  if (order.materialAmount > 0)
                    _pdfTableRow('Material', order.materialAmount),
                  _pdfTableRow('TOTAL', order.totalAmount, bold: true),
                ],
              ),
              pw.SizedBox(height: 16),

              // Payments
              if (_payments.isNotEmpty) ...[
                pw.Text('Payments:',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 6),
                ..._payments.map((p) => pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                            '${p.method} - ${Helpers.formatDate(p.paidAt)}'),
                        pw.Text('Rs ${p.amount.toStringAsFixed(0)}'),
                      ],
                    )),
                pw.SizedBox(height: 8),
              ],

              pw.Divider(),
              pw.SizedBox(height: 8),

              // Balance
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Balance Due:',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.Text('Rs ${order.balanceAmount.toStringAsFixed(0)}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 16)),
                ],
              ),

              if (order.dueDate != null) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                    'Due Date: ${Helpers.formatDate(order.dueDate!)}',
                    style: const pw.TextStyle(fontSize: 12)),
              ],

              pw.SizedBox(height: 40),
              pw.Center(
                child: pw.Text('Thank you for your business!',
                    style: pw.TextStyle(
                        fontStyle: pw.FontStyle.italic, fontSize: 12)),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.TableRow _pdfTableRow(String desc, double amount, {bool bold = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(desc,
              style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text('Rs ${amount.toStringAsFixed(0)}',
              style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
              textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }

  Future<void> _printInvoice() async {
    final pdf = await _buildPdf();
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _shareInvoice() async {
    // On web, use print/download. On mobile, use sharing.
    final pdf = await _buildPdf();
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'invoice_${_order!.id}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final order = _order!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice / رسید'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareInvoice,
            tooltip: 'Share via WhatsApp',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printInvoice,
            tooltip: 'Print',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TAILOR SHOP',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('Invoice',
                            style: TextStyle(color: AppColors.textMedium)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Order #${order.id}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        Text(Helpers.formatDate(order.createdAt),
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textMedium)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 32),

                // Customer
                const Text('Customer',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMedium)),
                Text(order.customerName ?? 'N/A',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(order.customerPhone ?? '',
                    style: const TextStyle(color: AppColors.textMedium)),
                const SizedBox(height: 20),

                // Items
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _invoiceRow('${order.orderType} - Stitching',
                          order.stitchingAmount,
                          isHeader: false),
                      if (order.materialAmount > 0)
                        _invoiceRow('Material', order.materialAmount),
                      Container(
                        color: AppColors.primary.withOpacity(0.05),
                        child: _invoiceRow('TOTAL', order.totalAmount,
                            bold: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payments
                if (_payments.isNotEmpty) ...[
                  const Text('Payments Received',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  ..._payments.map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                '${p.method} - ${Helpers.formatDate(p.paidAt)}',
                                style: const TextStyle(fontSize: 13)),
                            Text(Helpers.formatCurrency(p.amount),
                                style: const TextStyle(
                                    color: AppColors.success, fontSize: 13)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                ],

                const Divider(),

                // Balance
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Balance Due',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        Helpers.formatCurrency(order.balanceAmount),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: order.balanceAmount > 0
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),

                if (order.dueDate != null)
                  Text('Due by: ${Helpers.formatDate(order.dueDate!)}',
                      style: const TextStyle(color: AppColors.textMedium)),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareInvoice,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _printInvoice,
                icon: const Icon(Icons.print),
                label: const Text('Print'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _invoiceRow(String label, double amount,
      {bool bold = false, bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 16 : 14)),
          Text(
            Helpers.formatCurrency(amount),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
