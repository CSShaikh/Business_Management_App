import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../models/ledger_transaction_model.dart';

class CustomerStatementPdfService {
  CustomerStatementPdfService._();

  // ===========================================================================
  // GENERATE PDF
  // ===========================================================================

  static Future<Uint8List> generateStatementPdf({
    required BusinessModel business,
    required CustomerModel customer,
    required List<LedgerTransactionModel> transactions,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pw.Document document = pw.Document();

    final List<LedgerTransactionModel> sortedTransactions =
        List<LedgerTransactionModel>.from(transactions)
          ..sort(
            (a, b) => a.date.compareTo(b.date),
          );

    double totalSales = 0;
    double totalPayments = 0;

    for (final LedgerTransactionModel transaction
        in sortedTransactions) {
      final String type =
          transaction.transactionType.trim().toUpperCase();

      if (type == 'SALE') {
        totalSales += transaction.amount;
      } else if (type == 'PAYMENT') {
        totalPayments += transaction.amount;
      }
    }

    final double outstanding =
        sortedTransactions.isEmpty
            ? 0
            : sortedTransactions.last.balanceAfter;

    final PdfColor primaryColor =
        PdfColor.fromHex('#2563EB');

    final PdfColor successColor =
        PdfColor.fromHex('#16A34A');

    final PdfColor dangerColor =
        PdfColor.fromHex('#DC2626');

    final PdfColor greyColor =
        PdfColor.fromHex('#64748B');

    final PdfColor lightGreyColor =
        PdfColor.fromHex('#F1F5F9');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          32,
          32,
          32,
          36,
        ),
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(
              top: 12,
            ),
            child: pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Customer Statement',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: greyColor,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: greyColor,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // =================================================================
            // HEADER
            // =================================================================

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
                          fontSize: 22,
                          fontWeight:
                              pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      if (business.address
                          .trim()
                          .isNotEmpty)
                        pw.Padding(
                          padding:
                              const pw.EdgeInsets.only(
                            top: 5,
                          ),
                          child: pw.Text(
                            business.address.trim(),
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: greyColor,
                            ),
                          ),
                        ),
                      if (business.mobile
                          .trim()
                          .isNotEmpty)
                        pw.Padding(
                          padding:
                              const pw.EdgeInsets.only(
                            top: 3,
                          ),
                          child: pw.Text(
                            'Mobile: ${business.mobile.trim()}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: greyColor,
                            ),
                          ),
                        ),
                      if (business.email
                          .trim()
                          .isNotEmpty)
                        pw.Padding(
                          padding:
                              const pw.EdgeInsets.only(
                            top: 3,
                          ),
                          child: pw.Text(
                            'Email: ${business.email.trim()}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: greyColor,
                            ),
                          ),
                        ),
                      if (business.gstNumber
                          .trim()
                          .isNotEmpty)
                        pw.Padding(
                          padding:
                              const pw.EdgeInsets.only(
                            top: 3,
                          ),
                          child: pw.Text(
                            'GST: ${business.gstNumber.trim()}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: greyColor,
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
                    color: primaryColor,
                    borderRadius:
                        pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'CUSTOMER\nSTATEMENT',
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

            pw.SizedBox(height: 22),

            pw.Divider(
              color: PdfColor.fromHex('#CBD5E1'),
            ),

            pw.SizedBox(height: 16),

            // =================================================================
            // CUSTOMER INFORMATION
            // =================================================================

            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: lightGreyColor,
                borderRadius:
                    pw.BorderRadius.circular(8),
                border: pw.Border.all(
                  color:
                      PdfColor.fromHex('#E2E8F0'),
                ),
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
                        pw.Text(
                          'CUSTOMER',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight:
                                pw.FontWeight.bold,
                            color: greyColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _safeText(
                            customer.name,
                            'Customer',
                          ),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight:
                                pw.FontWeight.bold,
                          ),
                        ),
                        if (customer.ownerName
                            .trim()
                            .isNotEmpty)
                          pw.Padding(
                            padding:
                                const pw.EdgeInsets.only(
                              top: 3,
                            ),
                            child: pw.Text(
                              'Owner: ${customer.ownerName.trim()}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: greyColor,
                              ),
                            ),
                          ),
                        if (customer.mobile
                            .trim()
                            .isNotEmpty)
                          pw.Padding(
                            padding:
                                const pw.EdgeInsets.only(
                              top: 3,
                            ),
                            child: pw.Text(
                              'Mobile: ${customer.mobile.trim()}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: greyColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        if (customer.address
                            .trim()
                            .isNotEmpty)
                          _infoRow(
                            'Address',
                            customer.address.trim(),
                            greyColor,
                          ),
                        if (customer.email
                            .trim()
                            .isNotEmpty)
                          _infoRow(
                            'Email',
                            customer.email.trim(),
                            greyColor,
                          ),
                        if (customer.gstNumber
                            .trim()
                            .isNotEmpty)
                          _infoRow(
                            'GST',
                            customer.gstNumber.trim(),
                            greyColor,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // =================================================================
            // PERIOD
            // =================================================================

            pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Statement Period',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight:
                        pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  _formatPeriod(
                    fromDate,
                    toDate,
                  ),
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: greyColor,
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 14),

            // =================================================================
            // SUMMARY
            // =================================================================

            pw.Row(
              children: [
                pw.Expanded(
                  child: _summaryBox(
                    title: 'Total Sales',
                    value: _formatCurrency(
                      totalSales,
                    ),
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _summaryBox(
                    title: 'Payments Received',
                    value: _formatCurrency(
                      totalPayments,
                    ),
                    color: successColor,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _summaryBox(
                    title: 'Outstanding',
                    value: _formatCurrency(
                      outstanding,
                    ),
                    color: outstanding > 0
                        ? dangerColor
                        : successColor,
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // =================================================================
            // TRANSACTION TABLE
            // =================================================================

            pw.Text(
              'Transaction History',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 9),

            if (sortedTransactions.isEmpty)
              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color:
                        PdfColor.fromHex('#E2E8F0'),
                  ),
                  borderRadius:
                      pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'No transactions found for this customer.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: greyColor,
                  ),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(
                  color:
                      PdfColor.fromHex('#E2E8F0'),
                  width: 0.6,
                ),
                columnWidths: const {
                  0: pw.FixedColumnWidth(55),
                  1: pw.FixedColumnWidth(65),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1),
                  4: pw.FlexColumnWidth(1),
                  5: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        pw.BoxDecoration(
                      color: primaryColor,
                    ),
                    children: [
                      _headerCell('Date'),
                      _headerCell('Type'),
                      _headerCell('Description'),
                      _headerCell('Debit'),
                      _headerCell('Credit'),
                      _headerCell('Balance'),
                    ],
                  ),
                  ...sortedTransactions.map(
                    (
                      LedgerTransactionModel transaction,
                    ) {
                      final String type =
                          transaction.transactionType
                              .trim()
                              .toUpperCase();

                      final bool isSale =
                          type == 'SALE';

                      final bool isPayment =
                          type == 'PAYMENT';

                      final double debit =
                          isSale
                              ? transaction.amount
                              : 0;

                      final double credit =
                          isPayment
                              ? transaction.amount
                              : 0;

                      return pw.TableRow(
                        children: [
                          _bodyCell(
                            _formatDate(
                              transaction.date,
                            ),
                          ),
                          _bodyCell(
                            _transactionLabel(type),
                          ),
                          _bodyCell(
                            transaction.notes
                                    .trim()
                                    .isNotEmpty
                                ? transaction.notes
                                    .trim()
                                : transaction.referenceId
                                        .trim()
                                        .isNotEmpty
                                    ? 'Ref: ${transaction.referenceId.trim()}'
                                    : '-',
                          ),
                          _bodyCell(
                            debit > 0
                                ? _formatCurrency(
                                    debit,
                                  )
                                : '-',
                            align:
                                pw.TextAlign.right,
                          ),
                          _bodyCell(
                            credit > 0
                                ? _formatCurrency(
                                    credit,
                                  )
                                : '-',
                            align:
                                pw.TextAlign.right,
                          ),
                          _bodyCell(
                            _formatCurrency(
                              transaction.balanceAfter,
                            ),
                            align:
                                pw.TextAlign.right,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),

            pw.SizedBox(height: 18),

            // =================================================================
            // BALANCE NOTE
            // =================================================================

            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: outstanding > 0
                    ? PdfColor.fromHex('#FEF2F2')
                    : PdfColor.fromHex('#F0FDF4'),
                borderRadius:
                    pw.BorderRadius.circular(7),
                border: pw.Border.all(
                  color: outstanding > 0
                      ? PdfColor.fromHex('#FECACA')
                      : PdfColor.fromHex('#BBF7D0'),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      outstanding > 0
                          ? 'Outstanding amount payable by customer'
                          : 'No outstanding balance',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight:
                            pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Text(
                    _formatCurrency(
                      outstanding,
                    ),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight:
                          pw.FontWeight.bold,
                      color: outstanding > 0
                          ? dangerColor
                          : successColor,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 28),

            // =================================================================
            // FOOT NOTE
            // =================================================================

            pw.Center(
              child: pw.Text(
                'This statement is generated from the business ledger records.',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: greyColor,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  // ===========================================================================
  // PRINT
  // ===========================================================================

  static Future<void> printStatement({
    required BusinessModel business,
    required CustomerModel customer,
    required List<LedgerTransactionModel> transactions,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final Uint8List pdfBytes =
        await generateStatementPdf(
      business: business,
      customer: customer,
      transactions: transactions,
      fromDate: fromDate,
      toDate: toDate,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return pdfBytes;
      },
    );
  }

  // ===========================================================================
  // SHARE
  // ===========================================================================

  static Future<void> shareStatement({
    required BusinessModel business,
    required CustomerModel customer,
    required List<LedgerTransactionModel> transactions,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final Uint8List pdfBytes =
        await generateStatementPdf(
      business: business,
      customer: customer,
      transactions: transactions,
      fromDate: fromDate,
      toDate: toDate,
    );

    final String customerName =
        _sanitizeFileName(
      customer.name.trim().isEmpty
          ? 'Customer'
          : customer.name.trim(),
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename:
          'Customer_Statement_$customerName.pdf',
    );
  }

  // ===========================================================================
  // PDF HELPERS
  // ===========================================================================

  static pw.Widget _infoRow(
    String label,
    String value,
    PdfColor greyColor,
  ) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight:
                    pw.FontWeight.bold,
                color: greyColor,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                fontSize: 8,
                color: greyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _summaryBox({
    required String title,
    required String value,
    required PdfColor color,
  }) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      decoration: pw.BoxDecoration(
        color: color.shade(0.95),
        borderRadius:
            pw.BorderRadius.circular(7),
        border: pw.Border.all(
          color: color.shade(0.75),
          width: 0.7,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 7.5,
              color: color.shade(0.25),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight:
                  pw.FontWeight.bold,
              color: color.shade(0.15),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _headerCell(
    String text,
  ) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 7,
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight:
              pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _bodyCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 6,
      ),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
        ),
      ),
    );
  }

  static String _transactionLabel(
    String type,
  ) {
    switch (type) {
      case 'SALE':
        return 'Sale';

      case 'PAYMENT':
        return 'Payment';

      case 'RETURN':
        return 'Return';

      case 'ADJUSTMENT':
        return 'Adjustment';

      default:
        return type.isEmpty
            ? 'Transaction'
            : _capitalize(type);
    }
  }

  static String _capitalize(
    String value,
  ) {
    if (value.isEmpty) {
      return value;
    }

    return value[0].toUpperCase() +
        value.substring(1).toLowerCase();
  }

  static String _formatDate(
    DateTime date,
  ) {
    final DateTime local = date.toLocal();

    final String day =
        local.day.toString().padLeft(2, '0');

    final String month =
        local.month.toString().padLeft(2, '0');

    return '$day/$month/${local.year}';
  }

  static String _formatPeriod(
    DateTime? fromDate,
    DateTime? toDate,
  ) {
    if (fromDate == null && toDate == null) {
      return 'All Transactions';
    }

    if (fromDate != null && toDate != null) {
      return '${_formatDate(fromDate)} - ${_formatDate(toDate)}';
    }

    if (fromDate != null) {
      return 'From ${_formatDate(fromDate)}';
    }

    return 'Until ${_formatDate(toDate!)}';
  }

  static String _formatCurrency(
    double value,
  ) {
    final double rounded =
        double.parse(value.toStringAsFixed(2));

    final bool negative = rounded < 0;
    final double absolute =
        rounded.abs();

    final String fixed =
        absolute.toStringAsFixed(2);

    final List<String> parts =
        fixed.split('.');

    String integerPart = parts[0];

    final StringBuffer formatted =
        StringBuffer();

    int count = 0;

    for (int i = integerPart.length - 1;
        i >= 0;
        i--) {
      formatted.write(integerPart[i]);
      count++;

      if (count == 3 &&
          i != 0) {
        formatted.write(',');
        count = 0;
      } else if (count > 3 &&
          (count - 3) % 2 == 0 &&
          i != 0) {
        formatted.write(',');
      }
    }

    integerPart =
        formatted.toString().split('').reversed.join();

    return '${negative ? '-' : ''}Rs. $integerPart.${parts[1]}';
  }

  static String _safeText(
    String value,
    String fallback,
  ) {
    final String trimmed = value.trim();

    return trimmed.isEmpty
        ? fallback
        : trimmed;
  }

  static String _sanitizeFileName(
    String value,
  ) {
    final String sanitized = value
        .replaceAll(
          RegExp(r'[<>:"/\\|?*]'),
          '_',
        )
        .replaceAll(
          RegExp(r'\s+'),
          '_',
        );

    return sanitized.isEmpty
        ? 'Customer'
        : sanitized;
  }
}