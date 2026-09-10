import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/business_model.dart';
import '../../models/sale_model.dart';

class InvoicePdfService {
  InvoicePdfService._();

  // ---------------------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------------------

  /// Generates the invoice PDF as raw bytes.
  static Future<Uint8List> generateInvoicePdf({
    required BusinessModel business,
    required SaleModel sale,
  }) async {
    final pw.Document document = pw.Document(
      title: 'Invoice ${sale.invoiceNumber}',
      author: business.businessName,
      subject: 'Sales Invoice',
    );

    final PdfColor primaryColor = PdfColor.fromHex('#1565C0');
    final PdfColor darkColor = PdfColor.fromHex('#1F2937');
    final PdfColor mutedColor = PdfColor.fromHex('#6B7280');
    final PdfColor borderColor = PdfColor.fromHex('#D1D5DB');
    final PdfColor lightBackground = PdfColor.fromHex('#F3F4F6');
    final PdfColor successColor = PdfColor.fromHex('#15803D');
    final PdfColor warningColor = PdfColor.fromHex('#B45309');
    final PdfColor dangerColor = PdfColor.fromHex('#B91C1C');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          32,
          32,
          32,
          36,
        ),
        header: (pw.Context context) {
          return _buildPageHeader(
            business: business,
            sale: sale,
            primaryColor: primaryColor,
            mutedColor: mutedColor,
          );
        },
        footer: (pw.Context context) {
          return _buildFooter(
            context,
            mutedColor: mutedColor,
          );
        },
        build: (pw.Context context) {
          return <pw.Widget>[
            pw.SizedBox(height: 16),

            _buildCustomerSection(
              business: business,
              sale: sale,
              darkColor: darkColor,
              mutedColor: mutedColor,
              borderColor: borderColor,
              lightBackground: lightBackground,
            ),

            pw.SizedBox(height: 18),

            _buildItemsTable(
              sale: sale,
              darkColor: darkColor,
              mutedColor: mutedColor,
              borderColor: borderColor,
              primaryColor: primaryColor,
            ),

            pw.SizedBox(height: 18),

            _buildTotalsSection(
              sale: sale,
              darkColor: darkColor,
              mutedColor: mutedColor,
              borderColor: borderColor,
              lightBackground: lightBackground,
              successColor: successColor,
              warningColor: warningColor,
              dangerColor: dangerColor,
            ),

            pw.SizedBox(height: 20),

            if (sale.notes.trim().isNotEmpty)
              _buildNotesSection(
                sale: sale,
                darkColor: darkColor,
                mutedColor: mutedColor,
                borderColor: borderColor,
                lightBackground: lightBackground,
              ),

            if (sale.notes.trim().isNotEmpty)
              pw.SizedBox(height: 18),

            _buildTermsSection(
              business: business,
              sale: sale,
              darkColor: darkColor,
              mutedColor: mutedColor,
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  /// Opens the native print / preview screen for the invoice.
  static Future<void> printInvoice({
    required BusinessModel business,
    required SaleModel sale,
  }) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return generateInvoicePdf(
          business: business,
          sale: sale,
        );
      },
      name: _invoiceFileName(sale),
    );
  }

  /// Opens the platform share/print sheet for the generated PDF.
  static Future<void> shareInvoice({
    required BusinessModel business,
    required SaleModel sale,
  }) async {
    final Uint8List bytes = await generateInvoicePdf(
      business: business,
      sale: sale,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: _invoiceFileName(sale),
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE HEADER
  // ---------------------------------------------------------------------------

  static pw.Widget _buildPageHeader({
    required BusinessModel business,
    required SaleModel sale,
    required PdfColor primaryColor,
    required PdfColor mutedColor,
  }) {
    final String businessName = business.businessName.trim().isEmpty
        ? 'Business'
        : business.businessName.trim();

    final String invoiceNumber = sale.invoiceNumber.trim().isEmpty
        ? sale.id
        : sale.invoiceNumber.trim();

    return pw.Container(
      padding: const pw.EdgeInsets.only(
        bottom: 14,
      ),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: primaryColor,
            width: 2,
          ),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  businessName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                if (business.businessType.trim().isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    business.businessType.trim(),
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: mutedColor,
                    ),
                  ),
                ],
                if (business.address.trim().isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    business.address.trim(),
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: mutedColor,
                    ),
                    maxLines: 3,
                  ),
                ],
                if (business.mobile.trim().isNotEmpty ||
                    business.email.trim().isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _contactText(business),
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: mutedColor,
                    ),
                  ),
                ],
                if (business.gstNumber.trim().isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'GSTIN: ${business.gstNumber.trim()}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: mutedColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Text(
                'TAX INVOICE',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Invoice No: $invoiceNumber',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: mutedColor,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Date: ${_formatDate(sale.date)}',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: mutedColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CUSTOMER SECTION
  // ---------------------------------------------------------------------------

  static pw.Widget _buildCustomerSection({
    required BusinessModel business,
    required SaleModel sale,
    required PdfColor darkColor,
    required PdfColor mutedColor,
    required PdfColor borderColor,
    required PdfColor lightBackground,
  }) {
    final String customerName = sale.customerName.trim().isEmpty
        ? 'Walk-in Customer'
        : sale.customerName.trim();

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: lightBackground,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: borderColor,
          width: 0.7,
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'BILL TO',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: mutedColor,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  customerName,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: darkColor,
                  ),
                ),
                if (sale.customerId.trim().isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Customer ID: ${sale.customerId}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: mutedColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: <pw.Widget>[
                pw.Text(
                  'PAYMENT',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: mutedColor,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  _paymentStatusText(sale.paymentStatus),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _paymentStatusColor(
                      sale.paymentStatus,
                    ),
                  ),
                ),
                if (sale.paymentMethod.trim().isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Method: ${_displayPaymentMethod(sale.paymentMethod)}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: mutedColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ITEMS TABLE
  // ---------------------------------------------------------------------------

  static pw.Widget _buildItemsTable({
    required SaleModel sale,
    required PdfColor darkColor,
    required PdfColor mutedColor,
    required PdfColor borderColor,
    required PdfColor primaryColor,
  }) {
    final List<pw.TableRow> rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: primaryColor,
        ),
        children: <pw.Widget>[
          _tableHeader(
            '#',
            alignment: pw.Alignment.center,
          ),
          _tableHeader(
            'Product',
            alignment: pw.Alignment.centerLeft,
          ),
          _tableHeader(
            'Qty',
            alignment: pw.Alignment.center,
          ),
          _tableHeader(
            'Unit',
            alignment: pw.Alignment.center,
          ),
          _tableHeader(
            'Rate',
            alignment: pw.Alignment.centerRight,
          ),
          _tableHeader(
            'Discount',
            alignment: pw.Alignment.centerRight,
          ),
          _tableHeader(
            'Tax',
            alignment: pw.Alignment.centerRight,
          ),
          _tableHeader(
            'Amount',
            alignment: pw.Alignment.centerRight,
          ),
        ],
      ),
    ];

    for (int index = 0; index < sale.items.length; index++) {
      final SaleItemModel item = sale.items[index];

      rows.add(
        pw.TableRow(
          children: <pw.Widget>[
            _tableCell(
              '${index + 1}',
              alignment: pw.Alignment.center,
              color: mutedColor,
            ),
            _tableCell(
              item.productName.trim().isEmpty
                  ? 'Product'
                  : item.productName.trim(),
              alignment: pw.Alignment.centerLeft,
              color: darkColor,
              bold: true,
            ),
            _tableCell(
              _formatNumber(item.quantity),
              alignment: pw.Alignment.center,
              color: darkColor,
            ),
            _tableCell(
              item.unit.trim().isEmpty ? '-' : item.unit.trim(),
              alignment: pw.Alignment.center,
              color: mutedColor,
            ),
            _tableCell(
              _formatCurrency(item.sellingRate),
              alignment: pw.Alignment.centerRight,
              color: darkColor,
            ),
            _tableCell(
              _formatCurrency(item.discount),
              alignment: pw.Alignment.centerRight,
              color: mutedColor,
            ),
            _tableCell(
              _formatCurrency(item.tax),
              alignment: pw.Alignment.centerRight,
              color: mutedColor,
            ),
            _tableCell(
              _formatCurrency(item.total),
              alignment: pw.Alignment.centerRight,
              color: darkColor,
              bold: true,
            ),
          ],
        ),
      );
    }

    if (sale.items.isEmpty) {
      rows.add(
        pw.TableRow(
          children: <pw.Widget>[
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              child: pw.Text(
                'No items',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: mutedColor,
                ),
              ),
            ),
            pw.Container(),
            pw.Container(),
            pw.Container(),
            pw.Container(),
            pw.Container(),
            pw.Container(),
            pw.Container(),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder(
        top: pw.BorderSide(
          color: borderColor,
          width: 0.7,
        ),
        bottom: pw.BorderSide(
          color: borderColor,
          width: 0.7,
        ),
        left: pw.BorderSide(
          color: borderColor,
          width: 0.7,
        ),
        right: pw.BorderSide(
          color: borderColor,
          width: 0.7,
        ),
        horizontalInside: pw.BorderSide(
          color: borderColor,
          width: 0.5,
        ),
        verticalInside: pw.BorderSide(
          color: borderColor,
          width: 0.5,
        ),
      ),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(3.5),
        2: const pw.FixedColumnWidth(44),
        3: const pw.FixedColumnWidth(42),
        4: const pw.FixedColumnWidth(62),
        5: const pw.FixedColumnWidth(62),
        6: const pw.FixedColumnWidth(55),
        7: const pw.FixedColumnWidth(70),
      },
      children: rows,
    );
  }

  // ---------------------------------------------------------------------------
  // TOTALS
  // ---------------------------------------------------------------------------

  static pw.Widget _buildTotalsSection({
    required SaleModel sale,
    required PdfColor darkColor,
    required PdfColor mutedColor,
    required PdfColor borderColor,
    required PdfColor lightBackground,
    required PdfColor successColor,
    required PdfColor warningColor,
    required PdfColor dangerColor,
  }) {
    final double balanceDue =
        (sale.total - sale.paidAmount).clamp(0, double.infinity);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.only(
              top: 4,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'PAYMENT SUMMARY',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: mutedColor,
                  ),
                ),
                pw.SizedBox(height: 7),
                _summaryLine(
                  'Payment Status',
                  _paymentStatusText(sale.paymentStatus),
                  mutedColor,
                  darkColor,
                ),
                if (sale.paymentMethod.trim().isNotEmpty)
                  _summaryLine(
                    'Payment Method',
                    _displayPaymentMethod(sale.paymentMethod),
                    mutedColor,
                    darkColor,
                  ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Container(
          width: 245,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: lightBackground,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(
              color: borderColor,
              width: 0.7,
            ),
          ),
          child: pw.Column(
            children: <pw.Widget>[
              _totalLine(
                'Subtotal',
                sale.subtotal,
                mutedColor,
                darkColor,
              ),
              if (sale.discount > 0)
                _totalLine(
                  'Discount',
                  -sale.discount,
                  mutedColor,
                  darkColor,
                ),
              if (sale.tax > 0)
                _totalLine(
                  'Tax',
                  sale.tax,
                  mutedColor,
                  darkColor,
                ),
              pw.SizedBox(height: 7),
              pw.Container(
                height: 0.8,
                color: borderColor,
              ),
              pw.SizedBox(height: 7),
              _totalLine(
                'Grand Total',
                sale.total,
                mutedColor,
                darkColor,
                bold: true,
                fontSize: 12,
              ),
              pw.SizedBox(height: 6),
              _totalLine(
                'Paid',
                sale.paidAmount,
                mutedColor,
                successColor,
              ),
              pw.SizedBox(height: 4),
              _totalLine(
                'Balance Due',
                balanceDue,
                mutedColor,
                balanceDue <= 0 ? successColor : warningColor,
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // NOTES
  // ---------------------------------------------------------------------------

  static pw.Widget _buildNotesSection({
    required SaleModel sale,
    required PdfColor darkColor,
    required PdfColor mutedColor,
    required PdfColor borderColor,
    required PdfColor lightBackground,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: lightBackground,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: borderColor,
          width: 0.7,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            'NOTES',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: mutedColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            sale.notes.trim(),
            style: pw.TextStyle(
              fontSize: 9,
              color: darkColor,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TERMS / SIGNATURE
  // ---------------------------------------------------------------------------

  static pw.Widget _buildTermsSection({
    required BusinessModel business,
    required SaleModel sale,
    required PdfColor darkColor,
    required PdfColor mutedColor,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: darkColor,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'This is a computer-generated invoice.',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: mutedColor,
                ),
              ),
              if (business.ownerName.trim().isNotEmpty) ...<pw.Widget>[
                pw.SizedBox(height: 3),
                pw.Text(
                  'Authorized by: ${business.ownerName.trim()}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: mutedColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Container(
          width: 150,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: <pw.Widget>[
              pw.SizedBox(height: 30),
              pw.Container(
                height: 0.7,
                color: mutedColor,
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Authorized Signature',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: mutedColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FOOTER
  // ---------------------------------------------------------------------------

  static pw.Widget _buildFooter(
    pw.Context context, {
    required PdfColor mutedColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(
        top: 8,
      ),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColor.fromHex('#D1D5DB'),
            width: 0.6,
          ),
        ),
      ),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Text(
              'Business Management App',
              style: pw.TextStyle(
                fontSize: 7,
                color: mutedColor,
              ),
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 7,
              color: mutedColor,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TABLE HELPERS
  // ---------------------------------------------------------------------------

  static pw.Widget _tableHeader(
    String text, {
    required pw.Alignment alignment,
  }) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 7,
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    required pw.Alignment alignment,
    required PdfColor color,
    bool bold = false,
  }) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 7,
      ),
      child: pw.Text(
        text,
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: bold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY HELPERS
  // ---------------------------------------------------------------------------

  static pw.Widget _summaryLine(
    String label,
    String value,
    PdfColor labelColor,
    PdfColor valueColor,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(
        bottom: 4,
      ),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8,
                color: labelColor,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalLine(
    String label,
    double value,
    PdfColor labelColor,
    PdfColor valueColor, {
    bool bold = false,
    double fontSize = 9,
  }) {
    return pw.Row(
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight:
                  bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: labelColor,
            ),
          ),
        ),
        pw.Text(
          _formatCurrency(value.abs()),
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight:
                bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FORMATTING
  // ---------------------------------------------------------------------------

  static String _formatCurrency(double value) {
    final double rounded =
        (value * 100).roundToDouble() / 100;

    final String fixed = rounded.abs().toStringAsFixed(2);

    final List<String> parts = fixed.split('.');
    final String integerPart = parts[0];
    final String decimalPart = parts.length > 1
        ? parts[1]
        : '00';

    return 'Rs. ${_formatIndianNumber(integerPart)}.$decimalPart';
  }

  static String _formatIndianNumber(String value) {
    if (value.length <= 3) {
      return value;
    }

    final String lastThree =
        value.substring(value.length - 3);
    String remaining =
        value.substring(0, value.length - 3);

    final List<String> groups = <String>[];

    while (remaining.length > 2) {
      groups.insert(
        0,
        remaining.substring(
          remaining.length - 2,
        ),
      );

      remaining = remaining.substring(
        0,
        remaining.length - 2,
      );
    }

    if (remaining.isNotEmpty) {
      groups.insert(
        0,
        remaining,
      );
    }

    return '${groups.join(',')},$lastThree';
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  static String _formatDate(DateTime date) {
    final String day =
        date.day.toString().padLeft(2, '0');
    final String month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  static String _contactText(BusinessModel business) {
    final List<String> values = <String>[];

    if (business.mobile.trim().isNotEmpty) {
      values.add('Mobile: ${business.mobile.trim()}');
    }

    if (business.email.trim().isNotEmpty) {
      values.add('Email: ${business.email.trim()}');
    }

    return values.join('  |  ');
  }

  static String _displayPaymentMethod(String value) {
    final String normalized = value.trim().toLowerCase();

    switch (normalized) {
      case 'cash':
        return 'Cash';

      case 'upi':
        return 'UPI';

      case 'bank':
      case 'bank_transfer':
      case 'bank transfer':
        return 'Bank Transfer';

      case 'cheque':
      case 'check':
        return 'Cheque';

      case 'other':
        return 'Other';

      default:
        if (value.trim().isEmpty) {
          return '-';
        }

        return value.trim();
    }
  }

  static String _paymentStatusText(String value) {
    final String normalized = value.trim().toLowerCase();

    switch (normalized) {
      case 'paid':
      case 'full':
      case 'completed':
        return 'PAID';

      case 'partial':
      case 'partially_paid':
      case 'partially paid':
        return 'PARTIALLY PAID';

      case 'pending':
      case 'unpaid':
      case 'due':
        return 'PENDING';

      default:
        if (value.trim().isEmpty) {
          return 'PENDING';
        }

        return value.trim().toUpperCase();
    }
  }

  static PdfColor _paymentStatusColor(String value) {
    final String normalized = value.trim().toLowerCase();

    switch (normalized) {
      case 'paid':
      case 'full':
      case 'completed':
        return PdfColor.fromHex('#15803D');

      case 'partial':
      case 'partially_paid':
      case 'partially paid':
        return PdfColor.fromHex('#B45309');

      case 'pending':
      case 'unpaid':
      case 'due':
        return PdfColor.fromHex('#B91C1C');

      default:
        return PdfColor.fromHex('#B45309');
    }
  }

  static String _invoiceFileName(SaleModel sale) {
    final String invoiceNumber = sale.invoiceNumber.trim().isEmpty
        ? sale.id.trim().isEmpty
            ? 'invoice'
            : sale.id.trim()
        : sale.invoiceNumber.trim();

    final String safeName = invoiceNumber
        .replaceAll(
          RegExp(r'[^a-zA-Z0-9._-]+'),
          '_',
        )
        .replaceAll(
          RegExp(r'_+'),
          '_',
        );

    return 'Invoice_$safeName.pdf';
  }
}