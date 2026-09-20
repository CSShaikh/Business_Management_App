import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../models/sale_model.dart';

class CustomerSalesBillPdfService {
  CustomerSalesBillPdfService._();

  static const String _regularFontAsset = 'assets/fonts/NotoSans-Regular.ttf';
  static const String _boldFontAsset = 'assets/fonts/NotoSans-Bold.ttf';

  static Future<Uint8List> generateSalesBillPdf({
    required BusinessModel business,
    required CustomerModel customer,
    required List<SaleModel> sales,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final pw.Font regularFont = pw.Font.ttf(
      await rootBundle.load(_regularFontAsset),
    );
    final pw.Font boldFont = pw.Font.ttf(await rootBundle.load(_boldFontAsset));

    final pw.Document document = pw.Document(
      title: 'Customer Sales Bill',
      author: business.businessName,
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    final List<SaleModel> sortedSales = List<SaleModel>.from(sales)
      ..sort((a, b) => a.date.compareTo(b.date));

    final pw.MemoryImage? logo = await _loadBusinessLogo(business);

    final double total = sortedSales.fold<double>(
      0,
      (sum, sale) => sum + sale.total,
    );
    final double received = sortedSales.fold<double>(
      0,
      (sum, sale) => sum + sale.paidAmount,
    );
    final double pending = (total - received)
        .clamp(0, double.infinity)
        .toDouble();
    final double totalQty = sortedSales.fold<double>(
      0,
      (sum, sale) =>
          sum +
          sale.items.fold<double>(
            0,
            (itemSum, item) => itemSum + item.quantity,
          ),
    );

    final List<String> invoiceNumbers = sortedSales
        .map(
          (sale) => sale.invoiceNumber.trim().isEmpty
              ? sale.id
              : sale.invoiceNumber.trim(),
        )
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    final String invoiceNumber = invoiceNumbers.length == 1
        ? invoiceNumbers.first
        : invoiceNumbers.isEmpty
        ? 'N/A'
        : invoiceNumbers.join(', ');

    final String invoiceDate = sortedSales.isEmpty
        ? _formatDate(fromDate)
        : _sameDay(sortedSales.first.date, sortedSales.last.date)
        ? _formatDate(sortedSales.first.date)
        : '${_formatDate(sortedSales.first.date)} - '
              '${_formatDate(sortedSales.last.date)}';

    final PdfColor primary = PdfColor.fromInt(0xFF174A8B);
    final PdfColor lightBlue = PdfColor.fromInt(0xFFDCEBFA);
    final PdfColor line = PdfColor.fromInt(0xFF8DB7DF);
    final PdfColor text = PdfColor.fromInt(0xFF102A43);
    final PdfColor muted = PdfColor.fromInt(0xFF4A5568);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(26, 24, 26, 24),
        build: (pw.Context context) {
          return <pw.Widget>[
            _header(business, logo, primary, text, muted),
            pw.SizedBox(height: 8),
            pw.Container(height: 2, color: primary),

            // Invoice number + invoice date only.
            // Due Date is intentionally not included anywhere in the bill.
            pw.Container(
              color: lightBlue,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              child: pw.Row(
                children: <pw.Widget>[
                  pw.Expanded(child: _info('Invoice No.', invoiceNumber, text)),
                  _verticalDivider(line),
                  pw.Expanded(child: _info('Invoice Date', invoiceDate, text)),
                ],
              ),
            ),

            pw.SizedBox(height: 12),
            _billTo(customer, text, muted),
            pw.SizedBox(height: 10),
            pw.Container(height: 1.5, color: primary),
            pw.SizedBox(height: 6),

            _itemsTable(sortedSales, primary, lightBlue, line, text, muted),

            pw.Container(
              color: lightBlue,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              child: pw.Row(
                children: <pw.Widget>[
                  pw.Expanded(
                    child: pw.Text(
                      'SUBTOTAL',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: text,
                      ),
                    ),
                  ),
                  pw.Container(
                    width: 62,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      _number(totalQty),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: text,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 62),
                  pw.Container(
                    width: 82,
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      _currency(total),
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: text,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 14),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Expanded(
                  flex: 6,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        'TERMS AND CONDITIONS',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: primary,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        '1. Goods once sold will not be taken back or exchanged.',
                        style: pw.TextStyle(fontSize: 8.5, color: text),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '2. All disputes are subject to local jurisdiction only.',
                        style: pw.TextStyle(fontSize: 8.5, color: text),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 18),
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    children: <pw.Widget>[
                      _amountRow(
                        'Total Amount',
                        _currency(total),
                        lightBlue,
                        line,
                        text,
                        true,
                      ),
                      _amountRow(
                        'Received Amount',
                        _currency(received),
                        PdfColors.white,
                        line,
                        text,
                        false,
                      ),
                      _amountRow(
                        'Pending Amount',
                        _currency(pending),
                        PdfColors.white,
                        line,
                        text,
                        false,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 14),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: <pw.Widget>[
                  pw.Text(
                    'Total Amount (in words)',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${_amountInWords(total)} Rupees Only',
                    style: pw.TextStyle(fontSize: 9, color: text),
                  ),
                  pw.SizedBox(height: 26),
                  pw.Text(
                    'AUTHORISED SIGNATORY FOR',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    _safe(business.businessName, 'Business'),
                    style: pw.TextStyle(fontSize: 9, color: text),
                  ),
                  if (business.ownerName.trim().isNotEmpty) ...<pw.Widget>[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      business.ownerName.trim(),
                      style: pw.TextStyle(fontSize: 8.5, color: muted),
                    ),
                  ],
                ],
              ),
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  static Future<pw.MemoryImage?> _loadBusinessLogo(
    BusinessModel business,
  ) async {
    try {
      final String url = business.logoUrl.trim();
      if (url.isNotEmpty) {
        final Uint8List? bytes = await FirebaseStorage.instance
            .refFromURL(url)
            .getData(2 * 1024 * 1024);
        if (bytes != null && bytes.isNotEmpty) {
          return pw.MemoryImage(bytes);
        }
      }
    } catch (_) {
      // Fall back to the local app logo below.
    }

    try {
      final ByteData data = await rootBundle.load('assets/icon/app_icon.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _header(
    BusinessModel business,
    pw.MemoryImage? logo,
    PdfColor primary,
    PdfColor text,
    PdfColor muted,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Container(
          width: 82,
          height: 82,
          alignment: pw.Alignment.center,
          child: logo == null
              ? pw.Text(
                  'LOGO',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: primary,
                  ),
                )
              : pw.Image(logo, fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                _safe(business.businessName, 'Business'),
                style: pw.TextStyle(
                  fontSize: 21,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              if (business.businessType.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    business.businessType.trim(),
                    style: pw.TextStyle(fontSize: 9.5, color: text),
                  ),
                ),
              if (business.address.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    business.address.trim(),
                    style: pw.TextStyle(fontSize: 9.5, color: text),
                  ),
                ),
              if (business.mobile.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    'Mobile: ${business.mobile.trim()}',
                    style: pw.TextStyle(fontSize: 9.5, color: text),
                  ),
                ),
              if (business.email.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Text(
                    'Email: ${business.email.trim()}',
                    style: pw.TextStyle(fontSize: 8.5, color: muted),
                  ),
                ),
              if (business.gstNumber.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Text(
                    'GSTIN: ${business.gstNumber.trim()}',
                    style: pw.TextStyle(fontSize: 8.5, color: muted),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _info(String label, String value, PdfColor text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Text(
            '$label: ',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: text,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 9, color: text),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _verticalDivider(PdfColor color) {
    return pw.Container(width: 1, height: 22, color: color);
  }

  static pw.Widget _billTo(
    CustomerModel customer,
    PdfColor text,
    PdfColor muted,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          'BILL TO',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: text,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          _safe(customer.name, 'Customer'),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: text,
          ),
        ),
        if (customer.address.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              customer.address.trim(),
              style: pw.TextStyle(fontSize: 9, color: muted),
            ),
          ),
        if (customer.mobile.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              'Mobile: ${customer.mobile.trim()}',
              style: pw.TextStyle(fontSize: 9, color: muted),
            ),
          ),
        if (customer.email.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              'Email: ${customer.email.trim()}',
              style: pw.TextStyle(fontSize: 8.5, color: muted),
            ),
          ),
      ],
    );
  }

  static pw.Widget _itemsTable(
    List<SaleModel> sales,
    PdfColor primary,
    PdfColor lightBlue,
    PdfColor line,
    PdfColor text,
    PdfColor muted,
  ) {
    final List<pw.TableRow> rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: lightBlue),
        children: <pw.Widget>[
          _cell('ITEMS', primary, bold: true),
          _cell('QTY.', primary, bold: true, center: true),
          _cell('RATE', primary, bold: true, right: true),
          _cell('AMOUNT', primary, bold: true, right: true),
        ],
      ),
    ];

    int number = 1;
    for (final SaleModel sale in sales) {
      for (final SaleItemModel item in sale.items) {
        rows.add(
          pw.TableRow(
            children: <pw.Widget>[
              _cell('$number. ${_safe(item.productName, 'Product')}', text),
              _cell(
                '${_number(item.quantity)} ${_safe(item.unit, '')}'.trim(),
                text,
                center: true,
              ),
              _cell(_currency(item.sellingRate), text, right: true),
              _cell(_currency(item.total), text, right: true),
            ],
          ),
        );
        number++;
      }
    }

    if (number == 1) {
      rows.add(
        pw.TableRow(
          children: <pw.Widget>[
            _cell('No items', muted),
            _cell('-', muted, center: true),
            _cell('-', muted, right: true),
            _cell(_currency(0), muted, right: true),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: line, width: 0.6),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(4.8),
        1: pw.FixedColumnWidth(62),
        2: pw.FixedColumnWidth(72),
        3: pw.FixedColumnWidth(82),
      },
      children: rows,
    );
  }

  static pw.Widget _cell(
    String value,
    PdfColor color, {
    bool bold = false,
    bool center = false,
    bool right = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Align(
        alignment: center
            ? pw.Alignment.center
            : right
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
        child: pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 8.8,
            color: color,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  static pw.Widget _amountRow(
    String label,
    String value,
    PdfColor background,
    PdfColor border,
    PdfColor text,
    bool bold,
  ) {
    return pw.Container(
      color: background,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: border, width: 0.5),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: text,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _currency(double value) {
    final int rounded = value.round();
    final String grouped = _indianGrouping(rounded.abs().toString());
    final String sign = rounded < 0 ? '-' : '';
    return '$sign₹ $grouped';
  }

  static String _indianGrouping(String value) {
    if (value.length <= 3) {
      return value;
    }

    final String lastThree = value.substring(value.length - 3);
    String remaining = value.substring(0, value.length - 3);
    final List<String> groups = <String>[];

    while (remaining.length > 2) {
      groups.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }

    if (remaining.isNotEmpty) {
      groups.insert(0, remaining);
    }

    return '${groups.join(',')},$lastThree';
  }

  static String _number(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  static String _safe(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value.trim();
  }

  static String _amountInWords(double amount) {
    final int value = amount.round();
    if (value == 0) {
      return 'Zero';
    }

    final List<String> ones = <String>[
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    final List<String> tens = <String>[
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    String underThousand(int n) {
      final List<String> parts = <String>[];
      if (n >= 100) {
        parts.add('${ones[n ~/ 100]} Hundred');
        n %= 100;
      }
      if (n >= 20) {
        parts.add(tens[n ~/ 10]);
        n %= 10;
      }
      if (n > 0) {
        parts.add(ones[n]);
      }
      return parts.join(' ');
    }

    int n = value;
    final List<String> parts = <String>[];
    if (n >= 10000000) {
      parts.add('${underThousand(n ~/ 10000000)} Crore');
      n %= 10000000;
    }
    if (n >= 100000) {
      parts.add('${underThousand(n ~/ 100000)} Lakh');
      n %= 100000;
    }
    if (n >= 1000) {
      parts.add('${underThousand(n ~/ 1000)} Thousand');
      n %= 1000;
    }
    if (n > 0) {
      parts.add(underThousand(n));
    }
    return parts.join(' ');
  }
}
