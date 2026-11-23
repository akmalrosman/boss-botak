import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/shop_config.dart';
import '../core/format.dart';
import '../models/order.dart';

/// Generates a digital invoice (PDF) for an order and opens the share sheet.
class InvoiceService {
  const InvoiceService();

  static const _green = PdfColor.fromInt(0xFF1F5C30);
  static const _yellow = PdfColor.fromInt(0xFFFFCB2E);

  Future<void> share(Order order) async {
    final bytes = await build(order);
    await Printing.sharePdf(bytes: bytes, filename: 'Invoice-${order.code}.pdf');
  }

  Future<Uint8List> build(Order order) async {
    final doc = pw.Document(
      title: 'Invoice ${order.code}',
      author: ShopConfig.name,
    );

    pw.Widget row(String label, String value, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null)),
              pw.Text(value, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null)),
            ],
          ),
        );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: const pw.BoxDecoration(color: _green),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BOSS BOTAK',
                          style: pw.TextStyle(
                              color: _yellow, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Otak-Otak & Pepes',
                          style: const pw.TextStyle(color: PdfColors.white)),
                      pw.Text('WhatsApp / Call: ${ShopConfig.displayPhone}',
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(order.code, style: const pw.TextStyle(color: PdfColors.white)),
                      pw.Text(formatDate(order.createdAt),
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO',
                          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.Text(order.customerName,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      if (order.customerPhone.isNotEmpty) pw.Text(order.customerPhone),
                      if (order.address.isNotEmpty)
                        pw.Text(order.address, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('${order.fulfilment.label}'
                          '${order.scheduledFor != null ? ' on ${formatDate(order.scheduledFor!)}' : ''}'),
                      pw.Text('Payment: ${order.paymentMethod.label}',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(order.paymentStatus.label.toUpperCase(),
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: order.isPaid ? _green : PdfColors.red800)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Item', 'Qty', 'Unit price', 'Amount'],
              data: [
                for (final i in order.items)
                  [i.productName, '${i.quantity}', rm(i.unitPrice), rm(i.lineTotal)],
              ],
              headerDecoration: const pw.BoxDecoration(color: _yellow),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignments: {
                1: pw.Alignment.center,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.symmetric(
                  inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 220,
                child: pw.Column(children: [
                  row('Subtotal', rm(order.subtotal)),
                  if (order.discount > 0) row('Open House discount', '- ${rm(order.discount)}'),
                  if (order.fulfilment == Fulfilment.delivery)
                    row('Delivery fee', order.deliveryFee == 0 ? 'FREE' : rm(order.deliveryFee)),
                  pw.Divider(),
                  row('TOTAL', rm(order.total), bold: true),
                ]),
              ),
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
            pw.Center(
              child: pw.Text('Terima kasih! ${ShopConfig.tagline}',
                  style: pw.TextStyle(color: _green, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Center(
              child: pw.Text('This is a computer-generated invoice. No signature required.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}
