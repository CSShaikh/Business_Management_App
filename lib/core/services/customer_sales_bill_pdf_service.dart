import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../models/sale_model.dart';

class CustomerSalesBillPdfService {
  CustomerSalesBillPdfService._();

  static Future<Uint8List> generateSalesBillPdf({
    required BusinessModel business,
    required CustomerModel customer,
    required List<SaleModel> sales,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final pw.Document document = pw.Document();

    final List<SaleModel> sortedSales =
        List<SaleModel>.from(sales)
          ..sort(
            (SaleModel a, SaleModel b) =>
                a.date.compareTo(b.date),
          );

    double totalBill = 0;
    double totalPaid = 0;
    double totalPending = 0;
    double totalDiscount = 0;
    double totalTax = 0;

    for (final SaleModel sale in sortedSales) {
      totalBill += sale.total;
      totalPaid += sale.paidAmount;
      totalPending += sale.pendingAmount;
      totalDiscount += sale.discount;
      totalTax += sale.tax;
    }

    final PdfColor primary =
        PdfColor.fromHex('#2563EB');
    final PdfColor success =
        PdfColor.fromHex('#16A34A');
    final PdfColor danger =
        PdfColor.fromHex('#DC2626');
    final PdfColor grey =
        PdfColor.fromHex('#64748B');
    final PdfColor light =
        PdfColor.fromHex('#F8FAFC');
    final PdfColor border =
        PdfColor.fromHex('#E2E8F0');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          30,
          30,
          30,
          38,
        ),
        footer: (pw.Context context) {
          return pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Customer Sales Bill',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: grey,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber}',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: grey,
                ),
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.Row(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _safeText(
                          business.businessName,
                          'Business',
                        ),
                        style: pw.TextStyle(
                          fontSize: 21,
                          fontWeight:
                              pw.FontWeight.bold,
                          color: primary,
                        ),
                      ),
                      if (business.address
                          .trim()
                          .isNotEmpty)
                        pw.Padding(
                          padding:
                              const pw.EdgeInsets.only(top: 4),
                          child: pw.Text(
                            business.address.trim(),
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              color: grey,
                            ),
                          ),
                        ),
                      if (business.mobile
                          .trim()
                          .isNotEmpty)
                        pw.Padding(
                          padding:
                              const pw.EdgeInsets.only(top: 3),
                          child: pw.Text(
                            'Mobile: ${business.mobile.trim()}',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              color: grey,
                            ),
                          ),
                        ),
                      if (business.email
                          .trim()
                          .isNotEmpty)
                        pw.Padding(
                          padding:
                              const pw.EdgeInsets.only(top: 3),
                          child: pw.Text(
                            'Email: ${business.email.trim()}',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              color: grey,
                            ),
                          ),
                        ),
                      if (business.gstNumber
                          .trim()
                          .isNotEmpty)
                        pw.Padding(
                          padding:
                              const pw.EdgeInsets.only(top: 3),
                          child: pw.Text(
                            'GST: ${business.gstNumber.trim()}',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              color: grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: pw.BoxDecoration(
                    color: primary,
                    borderRadius:
                        pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'CUSTOMER\nSALES BILL',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight:
                          pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(color: border),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: light,
                borderRadius:
                    pw.BorderRadius.circular(7),
                border: pw.Border.all(color: border),
              ),
              child: pw.Row(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        _labelText('BILL TO', grey),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _safeText(
                            customer.name,
                            'Customer',
                          ),
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight:
                                pw.FontWeight.bold,
                          ),
                        ),
                        if (customer.mobile
                            .trim()
                            .isNotEmpty)
                          pw.Padding(
                            padding:
                                const pw.EdgeInsets.only(top: 3),
                            child: pw.Text(
                              customer.mobile.trim(),
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                color: grey,
                              ),
                            ),
                          ),
                        if (customer.address
                            .trim()
                            .isNotEmpty)
                          pw.Padding(
                            padding:
                                const pw.EdgeInsets.only(top: 3),
                            child: pw.Text(
                              customer.address.trim(),
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                color: grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 18),
                  pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.end,
                    children: [
                      _labelText('BILL PERIOD', grey),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${_formatDate(fromDate)} - ${_formatDate(toDate)}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight:
                              pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${sortedSales.length} invoice${sortedSales.length == 1 ? '' : 's'}',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          color: grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              children: [
                pw.Expanded(
                  child: _summaryBox(
                    'Total Bill',
                    _currency(totalBill),
                    primary,
                  ),
                ),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: _summaryBox(
                    'Received',
                    _currency(totalPaid),
                    success,
                  ),
                ),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: _summaryBox(
                    'Pending',
                    _currency(totalPending),
                    totalPending > 0 ? danger : success,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Sales Details',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Date',
                'Invoice',
                'Products',
                'Total',
                'Paid',
                'Pending',
              ],
              data: sortedSales.map((SaleModel sale) {
                final String products = sale.items
                    .map(
                      (SaleItemModel item) =>
                          '${_safeText(item.productName, 'Product')} x ${_number(item.quantity)}',
                    )
                    .join('\n');

                return <String>[
                  _formatDate(sale.date),
                  sale.invoiceNumber.trim().isEmpty
                      ? sale.id
                      : sale.invoiceNumber.trim(),
                  products.isEmpty ? '-' : products,
                  _currency(sale.total),
                  _currency(sale.paidAmount),
                  _currency(sale.pendingAmount),
                ];
              }).toList(growable: false),
              headerStyle: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration:
                  pw.BoxDecoration(color: primary),
              cellStyle: const pw.TextStyle(fontSize: 7),
              border: pw.TableBorder.all(
                color: border,
                width: 0.5,
              ),
              cellPadding:
                  const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 5,
              ),
              columnWidths: const {
                0: pw.FixedColumnWidth(52),
                1: pw.FixedColumnWidth(65),
                2: pw.FlexColumnWidth(2),
                3: pw.FixedColumnWidth(58),
                4: pw.FixedColumnWidth(58),
                5: pw.FixedColumnWidth(58),
              },
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: light,
                borderRadius:
                    pw.BorderRadius.circular(6),
                border: pw.Border.all(color: border),
              ),
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Discount: ${_currency(totalDiscount)}  •  Tax: ${_currency(totalTax)}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: grey,
                    ),
                  ),
                  pw.Text(
                    'TOTAL: ${_currency(totalBill)}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              totalPending > 0
                  ? 'Outstanding amount for this period: ${_currency(totalPending)}'
                  : 'No outstanding amount for this selected period.',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: totalPending > 0 ? danger : success,
              ),
            ),
            pw.SizedBox(height: 22),
            pw.Center(
              child: pw.Text(
                'Generated from the customer sales records of the business.',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: grey,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  static pw.Widget _labelText(
    String text,
    PdfColor color,
  ) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: color,
      ),
    );
  }

  static pw.Widget _summaryBox(
    String title,
    String value,
    PdfColor color,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 7.5,
              color: color,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static String _currency(double value) {
    final double rounded =
        double.parse(value.toStringAsFixed(2));
    final bool negative = rounded < 0;
    final String fixed =
        rounded.abs().toStringAsFixed(2);
    return '${negative ? '-' : ''}Rs. $fixed';
  }

  static String _number(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static String _formatDate(DateTime date) {
    final DateTime local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  static String _safeText(
    String value,
    String fallback,
  ) {
    final String text = value.trim();
    return text.isEmpty ? fallback : text;
  }
}
