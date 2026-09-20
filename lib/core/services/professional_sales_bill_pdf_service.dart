import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/storage/local_logo_storage.dart';
import '../../core/storage/local_signature_storage.dart';
import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../models/sale_model.dart';

/// Shared professional sales-invoice renderer.
///
/// This is intentionally shared by the normal invoice and the customer
/// sales-bill flow so both outputs always use the same layout.
class ProfessionalSalesBillPdfService {
  ProfessionalSalesBillPdfService._();

  static Future<Uint8List> generateSingleSale({
    required BusinessModel business,
    required SaleModel sale,
    CustomerModel? customer,
  }) async {
    return _generate(
      business: business,
      customer: customer,
      sales: <SaleModel>[sale],
      title: 'Invoice ${_invoiceNumber(sale)}',
    );
  }

  static Future<Uint8List> generateSalesRange({
    required BusinessModel business,
    required CustomerModel customer,
    required List<SaleModel> sales,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final List<SaleModel> sorted = List<SaleModel>.from(sales)
      ..sort((a, b) => a.date.compareTo(b.date));

    if (sorted.isEmpty) {
      throw StateError('No sales available for the selected bill period.');
    }

    return _generate(
      business: business,
      customer: customer,
      sales: sorted,
      title: 'Customer Sales Bill',
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  static Future<Uint8List> _generate({
    required BusinessModel business,
    required CustomerModel? customer,
    required List<SaleModel> sales,
    required String title,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pw.ThemeData theme = await _pdfTheme();
    final pw.Document document = pw.Document(
      title: title,
      author: business.businessName,
      theme: theme,
    );

    final pw.MemoryImage? logo = await _loadBusinessLogo(business);
    final pw.MemoryImage? signature = await _loadBusinessSignature(business);
    final PdfColor primary = PdfColor.fromHex('#174A8B');
    final PdfColor lightBlue = PdfColor.fromHex('#DCEBFA');
    final PdfColor line = PdfColor.fromHex('#8DB7DF');
    final PdfColor text = PdfColor.fromHex('#102A43');
    final PdfColor muted = PdfColor.fromHex('#334E68');

    final double total = sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final double received = sales.fold<double>(
      0,
      (sum, sale) => sum + sale.paidAmount,
    );
    final double totalQty = sales.fold<double>(
      0,
      (sum, sale) =>
          sum +
          sale.items.fold<double>(
            0,
            (itemSum, item) => itemSum + item.quantity,
          ),
    );

    final String invoiceNumber = _rangeInvoiceNumber(sales);
    final String invoiceDate = fromDate != null && toDate != null
        ? (_sameDay(fromDate, toDate)
              ? _formatDate(fromDate)
              : '${_formatDate(fromDate)} - ${_formatDate(toDate)}')
        : _formatDate(sales.first.date);

    final CustomerModel resolvedCustomer =
        customer ??
        CustomerModel(
          id: sales.first.customerId,
          businessId: sales.first.businessId,
          name: sales.first.customerName,
          createdAt: sales.first.createdAt,
          updatedAt: sales.first.createdAt,
        );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(26, 20, 26, 24),
        build: (context) {
          return <pw.Widget>[
            _buildHeader(
              business: business,
              logo: logo,
              primary: primary,
              text: text,
              muted: muted,
            ),
            pw.SizedBox(height: 8),
            pw.Container(height: 3, color: primary),
            pw.Container(
              color: lightBlue,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              child: pw.Row(
                children: <pw.Widget>[
                  pw.Expanded(
                    child: _metaCell('Invoice No.', invoiceNumber, text),
                  ),
                  _divider(line),
                  pw.Expanded(
                    child: _metaCell('Invoice Date', invoiceDate, text),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            _buildBillTo(resolvedCustomer, text, muted),
            pw.SizedBox(height: 10),
            pw.Container(height: 2, color: primary),
            pw.SizedBox(height: 5),
            _buildItemsTable(
              sales,
              primary: primary,
              lightBlue: lightBlue,
              line: line,
              text: text,
            ),
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
                  pw.SizedBox(width: 72),
                  pw.Container(
                    width: 82,
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      _currency(total),
                      style: pw.TextStyle(
                        fontSize: 10.5,
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
                  child: _buildTerms(text: text, primary: primary),
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
                        bold: true,
                      ),
                      _amountRow(
                        'Received Amount',
                        _currency(received),
                        PdfColors.white,
                        line,
                        text,
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
                  if (signature != null)
                    pw.Container(
                      width: 120,
                      height: 42,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Image(signature, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.SizedBox(height: 42),
                  pw.SizedBox(height: 2),
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
                ],
              ),
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  static Future<pw.ThemeData> _pdfTheme() async {
    final pw.Font regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final pw.Font bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );

    return pw.ThemeData.withFont(base: regular, bold: bold);
  }

  static Future<pw.MemoryImage?> _loadBusinessLogo(
    BusinessModel business,
  ) async {
    // The business logo is device-local by design. A logo selected on an
    // Android phone stays on that phone; a logo selected in the Windows app
    // stays on that computer. It is not uploaded to Firebase Storage.
    try {
      final String businessId = business.id.trim();
      if (businessId.isNotEmpty) {
        final Uint8List? bytes = await LocalLogoStorage.read(
          businessId: businessId,
        );

        if (bytes != null && bytes.isNotEmpty) {
          return pw.MemoryImage(bytes);
        }
      }
    } catch (_) {
      // Use the built-in app icon if local storage is unavailable.
    }

    try {
      final ByteData data = await rootBundle.load('assets/icon/app_icon.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static Future<pw.MemoryImage?> _loadBusinessSignature(
    BusinessModel business,
  ) async {
    try {
      final String businessId = business.id.trim();
      if (businessId.isEmpty) {
        return null;
      }

      final Uint8List? bytes = await LocalSignatureStorage.read(
        businessId: businessId,
      );

      if (bytes != null && bytes.isNotEmpty) {
        return pw.MemoryImage(bytes);
      }
    } catch (_) {
      // A missing/corrupt signature should never block invoice generation.
    }

    return null;
  }

  static pw.Widget _buildHeader({
    required BusinessModel business,
    required pw.MemoryImage? logo,
    required PdfColor primary,
    required PdfColor text,
    required PdfColor muted,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Container(
          width: 92,
          height: 92,
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
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              if (business.address.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 5),
                  child: pw.Text(
                    business.address.trim(),
                    style: pw.TextStyle(fontSize: 9.5, color: muted),
                  ),
                ),
              if (business.mobile.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Text(
                    'Mobile: ${business.mobile.trim()}',
                    style: pw.TextStyle(fontSize: 9.5, color: muted),
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

  static pw.Widget _metaCell(String label, String value, PdfColor text) {
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

  static pw.Widget _divider(PdfColor color) =>
      pw.Container(width: 1, height: 22, color: color);

  static pw.Widget _buildBillTo(
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
        if (customer.ownerName.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'Owner: ${customer.ownerName.trim()}',
              style: pw.TextStyle(fontSize: 9, color: muted),
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
        if (customer.gstNumber.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              'GSTIN: ${customer.gstNumber.trim()}',
              style: pw.TextStyle(fontSize: 8.5, color: muted),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(
    List<SaleModel> sales, {
    required PdfColor primary,
    required PdfColor lightBlue,
    required PdfColor line,
    required PdfColor text,
  }) {
    final List<pw.TableRow> rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: lightBlue),
        children: <pw.Widget>[
          _cell('ITEMS / DATE', primary, bold: true),
          _cell('QTY.', primary, bold: true, center: true),
          _cell('RATE', primary, bold: true, right: true),
          _cell('AMOUNT', primary, bold: true, right: true),
        ],
      ),
    ];

    // Customer statement bills can contain multiple sales on different dates.
    // Keep every date as one numbered table row and put ALL products sold on
    // that date inside that same row. This prevents one sale date from being
    // scattered across many unrelated rows.
    final Map<String, List<SaleModel>> salesByDate =
        <String, List<SaleModel>>{};

    for (final SaleModel sale in sales) {
      final String dateKey =
          '${sale.date.year.toString().padLeft(4, '0')}-'
          '${sale.date.month.toString().padLeft(2, '0')}-'
          '${sale.date.day.toString().padLeft(2, '0')}';
      salesByDate.putIfAbsent(dateKey, () => <SaleModel>[]).add(sale);
    }

    int number = 1;
    for (final List<SaleModel> dateSales in salesByDate.values) {
      final List<SaleItemModel> items = dateSales
          .expand((SaleModel sale) => sale.items)
          .toList(growable: false);

      if (items.isEmpty) {
        rows.add(
          pw.TableRow(
            children: <pw.Widget>[
              _dateGroupCell(
                '${number++}. ${_formatDate(dateSales.first.date)}',
                const <String>['No items'],
                text,
                boldDate: true,
              ),
              _dateGroupCell('', const <String>['-'], text, center: true),
              _dateGroupCell('', const <String>['-'], text, right: true),
              _dateGroupCell('', const <String>['-'], text, right: true),
            ],
          ),
        );
        continue;
      }

      rows.add(
        pw.TableRow(
          children: <pw.Widget>[
            _dateGroupCell(
              '${number++}. ${_formatDate(dateSales.first.date)}',
              items
                  .map(
                    (SaleItemModel item) =>
                        '• ${_safe(item.productName, 'Product')}',
                  )
                  .toList(growable: false),
              text,
              boldDate: true,
            ),
            _dateGroupCell(
              '',
              items
                  .map(
                    (SaleItemModel item) =>
                        '${_number(item.quantity)} ${item.unit.trim()}'.trim(),
                  )
                  .toList(growable: false),
              text,
              center: true,
            ),
            _dateGroupCell(
              '',
              items
                  .map((SaleItemModel item) => _currency(item.sellingRate))
                  .toList(growable: false),
              text,
              right: true,
            ),
            _dateGroupCell(
              '',
              items
                  .map((SaleItemModel item) => _currency(item.total))
                  .toList(growable: false),
              text,
              right: true,
            ),
          ],
        ),
      );
    }

    if (salesByDate.isEmpty) {
      rows.add(
        pw.TableRow(
          children: <pw.Widget>[
            _cell('No items', text),
            _cell('-', text, center: true),
            _cell('-', text, right: true),
            _cell('-', text, right: true),
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

  static pw.Widget _dateGroupCell(
    String dateLabel,
    List<String> lines,
    PdfColor color, {
    bool boldDate = false,
    bool center = false,
    bool right = false,
  }) {
    final pw.Alignment alignment = center
        ? pw.Alignment.center
        : right
        ? pw.Alignment.centerRight
        : pw.Alignment.centerLeft;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Column(
        crossAxisAlignment: center
            ? pw.CrossAxisAlignment.center
            : right
            ? pw.CrossAxisAlignment.end
            : pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          if (dateLabel.isNotEmpty)
            pw.Align(
              alignment: alignment,
              child: pw.Text(
                dateLabel,
                style: pw.TextStyle(
                  fontSize: 8.8,
                  color: color,
                  fontWeight: boldDate
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            )
          else
            pw.SizedBox(height: 11),
          if (dateLabel.isNotEmpty && lines.isNotEmpty) pw.SizedBox(height: 3),
          ...lines.map(
            (String value) => pw.Align(
              alignment: alignment,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  value,
                  textAlign: center
                      ? pw.TextAlign.center
                      : right
                      ? pw.TextAlign.right
                      : pw.TextAlign.left,
                  style: pw.TextStyle(fontSize: 8.6, color: color),
                ),
              ),
            ),
          ),
        ],
      ),
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
    PdfColor text, {
    bool bold = false,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: background,
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

  static pw.Widget _buildTerms({
    required PdfColor text,
    required PdfColor primary,
  }) {
    return pw.Column(
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
    );
  }

  static String _rangeInvoiceNumber(List<SaleModel> sales) {
    final List<String> numbers = sales
        .map(_invoiceNumber)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    if (numbers.length == 1) return numbers.first;
    if (numbers.isEmpty) return 'N/A';
    return 'Multiple';
  }

  static String _invoiceNumber(SaleModel sale) {
    final String number = sale.invoiceNumber.trim();
    return number.isEmpty ? sale.id.trim() : number;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _currency(double value) {
    return '₹ ${_formatIndianNumber(value.round().toString())}';
  }

  static String _formatIndianNumber(String value) {
    if (value.length <= 3) return value;

    final String lastThree = value.substring(value.length - 3);
    String remaining = value.substring(0, value.length - 3);
    final List<String> groups = <String>[];

    while (remaining.length > 2) {
      groups.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }

    if (remaining.isNotEmpty) groups.insert(0, remaining);
    return '${groups.join(',')},$lastThree';
  }

  static String _number(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String _safe(String value, String fallback) =>
      value.trim().isEmpty ? fallback : value.trim();

  static String _amountInWords(double amount) {
    final int value = amount.round();
    if (value == 0) return 'Zero';

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
      if (n > 0) parts.add(ones[n]);
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
    if (n > 0) parts.add(underThousand(n));
    return parts.join(' ');
  }
}
