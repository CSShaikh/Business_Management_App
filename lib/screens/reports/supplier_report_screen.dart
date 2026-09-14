import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:public_file_saver/public_file_saver.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/purchase_model.dart';
import '../../models/supplier_model.dart';
import '../../models/supplier_payment_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/purchase_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../repositories/supplier_payment_repository.dart';

class SupplierReportScreen extends StatefulWidget {
  const SupplierReportScreen({
    super.key,
  });

  @override
  State<SupplierReportScreen> createState() =>
      _SupplierReportScreenState();
}

class _SupplierReportScreenState
    extends State<SupplierReportScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final SupplierRepository _supplierRepository =
      SupplierRepository();

  final PurchaseRepository _purchaseRepository =
      PurchaseRepository();

  final SupplierPaymentRepository _supplierPaymentRepository =
      SupplierPaymentRepository();

  final TextEditingController _searchController =
      TextEditingController();

  bool _loading = true;
  bool _refreshing = false;
  bool _downloadingPdf = false;

  String? _errorMessage;
  BusinessModel? _business;

  String _searchQuery = '';
  String _selectedPaymentStatus = 'All';

  DateTime? _startDate;
  DateTime? _endDate;

  List<SupplierModel> _suppliers =
      <SupplierModel>[];

  List<PurchaseModel> _purchases =
      <PurchaseModel>[];

  List<SupplierPaymentModel> _supplierPayments =
      <SupplierPaymentModel>[];

  static const List<String> _paymentStatuses = [
    'All',
    'Paid',
    'Partial',
    'Unpaid',
  ];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // LOAD
  // ===========================================================================

  Future<void> _loadReport({
    bool showLoader = true,
  }) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _refreshing = true;
        _errorMessage = null;
      });
    }

    try {
      final BusinessModel? business =
          await _businessRepository
              .getBusinessForCurrentUser();

      if (business == null) {
        throw Exception(
          'Business information is not available.',
        );
      }

      final results = await Future.wait([
        _supplierRepository.getSuppliers(
          business.id,
        ),
        _purchaseRepository.getPurchases(
          businessId: business.id,
        ),
        _supplierPaymentRepository.getPayments(
          businessId: business.id,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _business = business;

        _suppliers =
            results[0] as List<SupplierModel>;

        _purchases =
            results[1] as List<PurchaseModel>;

        _supplierPayments =
            results[2] as List<SupplierPaymentModel>;

        _loading = false;
        _refreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _refreshing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _refreshReport() async {
    await _loadReport(
      showLoader: false,
    );
  }

  // ===========================================================================
  // DATE FILTER
  // ===========================================================================

  Future<void> _selectDateRange() async {
    final DateTimeRange? range =
        await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
      initialDateRange:
          _startDate != null &&
                  _endDate != null
              ? DateTimeRange(
                  start: _startDate!,
                  end: _endDate!,
                )
              : null,
    );

    if (range == null) return;

    setState(() {
      _startDate = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );

      _endDate = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
        999,
      );
    });
  }

  void _setDateRange(DateTime start, DateTime end) {
    setState(() {
      _startDate = DateTime(start.year, start.month, start.day);
      _endDate = DateTime(
        end.year,
        end.month,
        end.day,
        23,
        59,
        59,
        999,
      );
    });
  }

  void _setToday() {
    final DateTime now = DateTime.now();
    _setDateRange(now, now);
  }

  void _setThisWeek() {
    final DateTime now = DateTime.now();
    final int daysFromMonday = now.weekday - DateTime.monday;
    final DateTime start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysFromMonday));
    _setDateRange(start, start.add(const Duration(days: 6)));
  }

  void _setThisMonth() {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, 1);
    final DateTime end = DateTime(now.year, now.month + 1, 0);
    _setDateRange(start, end);
  }

  void _setLastMonth() {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month - 1, 1);
    final DateTime end = DateTime(now.year, now.month, 0);
    _setDateRange(start, end);
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  // ===========================================================================
  // FILTERED PURCHASES
  // ===========================================================================

  List<PurchaseModel> get _filteredPurchases {
    return _purchases.where((purchase) {
      final DateTime date = purchase.date;

      if (_startDate != null &&
          date.isBefore(_startDate!)) {
        return false;
      }

      if (_endDate != null &&
          date.isAfter(_endDate!)) {
        return false;
      }

      if (_selectedPaymentStatus != 'All' &&
          purchase.paymentStatus.toLowerCase() !=
              _selectedPaymentStatus.toLowerCase()) {
        return false;
      }

      return true;
    }).toList();
  }

  // ===========================================================================
  // FILTERED SUPPLIER PAYMENTS
  // ===========================================================================

  List<SupplierPaymentModel>
      get _filteredSupplierPayments {
    return _supplierPayments.where((payment) {
      final DateTime date = payment.date;

      if (_startDate != null &&
          date.isBefore(_startDate!)) {
        return false;
      }

      if (_endDate != null &&
          date.isAfter(_endDate!)) {
        return false;
      }

      return true;
    }).toList();
  }

  List<SupplierPaymentModel> _supplierPaymentsFor(
    SupplierModel supplier,
  ) {
    return _filteredSupplierPayments.where((payment) {
      return payment.supplierId.trim() ==
          supplier.id.trim();
    }).toList();
  }

  // ===========================================================================
  // FILTERED SUPPLIERS
  // ===========================================================================

  List<SupplierModel> get _filteredSuppliers {
    final String query =
        _searchQuery.trim().toLowerCase();

    final Set<String> supplierIds = <String>{
      ..._filteredPurchases
          .map(
            (purchase) =>
                purchase.supplierId.trim(),
          )
          .where(
            (id) => id.isNotEmpty,
          ),
      ..._filteredSupplierPayments
          .map(
            (payment) =>
                payment.supplierId.trim(),
          )
          .where(
            (id) => id.isNotEmpty,
          ),
    };

    final List<SupplierModel> suppliers =
        _suppliers.where((supplier) {
      final bool matchesSearch =
          query.isEmpty ||
          supplier.name
              .toLowerCase()
              .contains(query) ||
          supplier.contactPerson
              .toLowerCase()
              .contains(query) ||
          supplier.mobile
              .toLowerCase()
              .contains(query) ||
          supplier.email
              .toLowerCase()
              .contains(query) ||
          supplier.address
              .toLowerCase()
              .contains(query) ||
          supplier.gstNumber
              .toLowerCase()
              .contains(query);

      if (!matchesSearch) {
        return false;
      }

      if (_startDate == null &&
          _endDate == null &&
          _selectedPaymentStatus == 'All') {
        return true;
      }

      return supplierIds.contains(
        supplier.id,
      );
    }).toList();

    suppliers.sort(
      (a, b) => a.name
          .toLowerCase()
          .compareTo(
            b.name.toLowerCase(),
          ),
    );

    return suppliers;
  }

  // ===========================================================================
  // SUPPLIER PURCHASES
  // ===========================================================================

  List<PurchaseModel> _supplierPurchases(
    SupplierModel supplier,
  ) {
    return _filteredPurchases.where((purchase) {
      return purchase.supplierId.trim() ==
          supplier.id.trim();
    }).toList();
  }

  double _supplierPurchaseAmount(
    SupplierModel supplier,
  ) {
    return _supplierPurchases(supplier).fold(
      0,
      (sum, purchase) =>
          sum + purchase.total,
    );
  }

  double _supplierPurchasePaidAmount(
    SupplierModel supplier,
  ) {
    return _supplierPurchases(supplier).fold(
      0,
      (sum, purchase) =>
          sum + purchase.paidAmount,
    );
  }

  double _supplierPaymentAmount(
    SupplierModel supplier,
  ) {
    return _supplierPaymentsFor(supplier).fold(
      0,
      (sum, payment) =>
          sum + payment.amount,
    );
  }

  double _supplierPaidAmount(
    SupplierModel supplier,
  ) {
    return _supplierPurchasePaidAmount(
          supplier,
        ) +
        _supplierPaymentAmount(
          supplier,
        );
  }

  double _supplierOutstandingAmount(
    SupplierModel supplier,
  ) {
    final double outstanding =
        _supplierPurchaseAmount(
          supplier,
        ) -
        _supplierPaidAmount(
          supplier,
        );

    return outstanding > 0
        ? outstanding
        : 0;
  }

  double _supplierQuantity(
    SupplierModel supplier,
  ) {
    return _supplierPurchases(supplier).fold(
      0,
      (sum, purchase) {
        return sum +
            purchase.items.fold(
              0,
              (itemSum, item) =>
                  itemSum + item.quantity,
            );
      },
    );
  }

  int _supplierPurchaseCount(
    SupplierModel supplier,
  ) {
    return _supplierPurchases(supplier).length;
  }

  // ===========================================================================
  // GLOBAL CALCULATIONS
  // ===========================================================================

  double get _totalPurchases {
    return _filteredPurchases.fold(
      0,
      (sum, purchase) =>
          sum + purchase.total,
    );
  }

  double get _totalPurchasePaid {
    return _filteredPurchases.fold(
      0,
      (sum, purchase) =>
          sum + purchase.paidAmount,
    );
  }

  double get _totalSupplierPayments {
    return _filteredSupplierPayments.fold(
      0,
      (sum, payment) =>
          sum + payment.amount,
    );
  }

  double get _totalPaid {
    return _totalPurchasePaid +
        _totalSupplierPayments;
  }

  double get _totalOutstanding {
    final double outstanding =
        _totalPurchases -
            _totalPaid;

    return outstanding > 0
        ? outstanding
        : 0;
  }

  int get _paidPurchaseCount {
    return _filteredPurchases.where(
      (purchase) =>
          purchase.paymentStatus
              .toLowerCase() ==
          'paid',
    ).length;
  }

  int get _partialPurchaseCount {
    return _filteredPurchases.where(
      (purchase) =>
          purchase.paymentStatus
              .toLowerCase() ==
          'partial',
    ).length;
  }

  int get _unpaidPurchaseCount {
    return _filteredPurchases.where(
      (purchase) =>
          purchase.paymentStatus
              .toLowerCase() ==
          'unpaid',
    ).length;
  }

  double get _paymentRate {
    if (_totalPurchases <= 0) {
      return 0;
    }

    return (_totalPaid /
            _totalPurchases) *
        100;
  }

  // ===========================================================================
  // FORMATTERS
  // ===========================================================================

  String _currency(
    double value,
  ) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  String _number(
    double value,
  ) {
    if (value ==
        value.roundToDouble()) {
      return value
          .toInt()
          .toString();
    }

    return value.toStringAsFixed(2);
  }

  String _date(
    DateTime date,
  ) {
    return DateFormat(
      'dd MMM yyyy',
    ).format(date);
  }

  // ===========================================================================
  // PDF EXPORT
  // ===========================================================================

  String _pdfMoney(double value) {
    return 'Rs. ${NumberFormat('#,##0.00', 'en_IN').format(value)}';
  }

  Future<void> _downloadPdf() async {
    if (_downloadingPdf) return;

    setState(() {
      _downloadingPdf = true;
    });

    try {
      final pw.Document document = pw.Document();
      final BusinessModel? business = _business;
      final List<SupplierModel> suppliers = _filteredSuppliers;

      final String period = _startDate != null && _endDate != null
          ? '${_date(_startDate!)} - ${_date(_endDate!)}'
          : 'All dates';

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          build: (context) => [
            pw.Text(
              business?.businessName.trim().isNotEmpty == true
                  ? business!.businessName
                  : 'Business Management App',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (business != null && business.businessType.trim().isNotEmpty)
              pw.Text(business.businessType),
            if (business != null && business.address.trim().isNotEmpty)
              pw.Text(business.address),
            if (business != null && business.mobile.trim().isNotEmpty)
              pw.Text('Mobile: ${business.mobile}'),
            if (business != null && business.email.trim().isNotEmpty)
              pw.Text('Email: ${business.email}'),
            if (business != null && business.gstNumber.trim().isNotEmpty)
              pw.Text('GSTIN: ${business.gstNumber}'),
            pw.SizedBox(height: 14),
            pw.Text(
              'Supplier Report',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text('Report period: $period'),
            if (_selectedPaymentStatus != 'All')
              pw.Text('Payment status: $_selectedPaymentStatus'),
            if (_searchQuery.trim().isNotEmpty)
              pw.Text('Search: ${_searchQuery.trim()}'),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: const ['Metric', 'Value'],
              data: [
                ['Suppliers', '${suppliers.length}'],
                ['Purchase Amount', _pdfMoney(_totalPurchases)],
                ['Purchase Paid', _pdfMoney(_totalPurchasePaid)],
                ['Supplier Payments', _pdfMoney(_totalSupplierPayments)],
                ['Total Paid', _pdfMoney(_totalPaid)],
                ['Outstanding', _pdfMoney(_totalOutstanding)],
                ['Payment Rate', '${_paymentRate.toStringAsFixed(1)}%'],
                ['Paid Purchases', '$_paidPurchaseCount'],
                ['Partial Purchases', '$_partialPurchaseCount'],
                ['Unpaid Purchases', '$_unpaidPurchaseCount'],
              ],
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellPadding: const pw.EdgeInsets.all(5),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Supplier-wise Summary',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            if (suppliers.isEmpty)
              pw.Text('No supplier records found for the selected filters.')
            else
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Supplier',
                  'Purchases',
                  'Qty',
                  'Paid',
                  'Payments',
                  'Outstanding',
                  'Invoices',
                ],
                data: suppliers.map((supplier) {
                  return [
                    supplier.name,
                    _pdfMoney(_supplierPurchaseAmount(supplier)),
                    _number(_supplierQuantity(supplier)),
                    _pdfMoney(_supplierPurchasePaidAmount(supplier)),
                    _pdfMoney(_supplierPaymentAmount(supplier)),
                    _pdfMoney(_supplierOutstandingAmount(supplier)),
                    '${_supplierPurchaseCount(supplier)}',
                  ];
                }).toList(),
                cellStyle: const pw.TextStyle(fontSize: 7),
                headerStyle: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellPadding: const pw.EdgeInsets.all(4),
              ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Supplier Payment Details',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            if (_filteredSupplierPayments.isEmpty)
              pw.Text('No supplier payment records found for the selected period.')
            else
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Date',
                  'Supplier',
                  'Method',
                  'Reference',
                  'Amount',
                ],
                data: _filteredSupplierPayments.map((payment) {
                  return [
                    _date(payment.date),
                    payment.supplierName,
                    payment.paymentMethod,
                    payment.transactionReference,
                    _pdfMoney(payment.amount),
                  ];
                }).toList(),
                cellStyle: const pw.TextStyle(fontSize: 7),
                headerStyle: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellPadding: const pw.EdgeInsets.all(4),
              ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Generated by Business Management App',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      );

      final Uint8List bytes = Uint8List.fromList(
        await document.save(),
      );

      final String safeName = (business?.businessName ?? 'Business')
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');

      final String fileName =
          '${safeName.isEmpty ? 'Business' : safeName}_Supplier_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

      final PublicSavedFile? result = await PublicFileSaver().saveBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/pdf',
        subDir: 'Business Management Reports',
      );

      if (!mounted) return;

      if (result?.isSuccess == true) {
        _showMessage('Supplier report PDF saved to Downloads.');
      } else {
        _showMessage('Unable to save the PDF.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        'PDF download failed: ${e.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingPdf = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.danger : Colors.green,
        ),
      );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor:
            theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title:
              const Text(
            'Supplier Report',
          ),
        ),
        body:
            const Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor:
            theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title:
              const Text(
            'Supplier Report',
          ),
        ),
        body:
            _buildErrorState(theme),
      );
    }

    final List<SupplierModel>
        suppliers =
        _filteredSuppliers;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title:
            const Text(
          'Supplier Report',
        ),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            onPressed: _downloadingPdf ? null : _downloadPdf,
            icon: _downloadingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _refreshing
                    ? null
                    : _refreshReport,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons
                        .refresh_rounded,
                  ),
          ),
          const SizedBox(
            width: 4,
          ),
        ],
      ),
      body:
          LayoutBuilder(
        builder:
            (
          context,
          constraints,
        ) {
          final bool isDesktop =
              constraints.maxWidth >=
                  1000;

          final bool isTablet =
              constraints.maxWidth >=
                      650 &&
                  constraints.maxWidth <
                      1000;

          return SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding:
                EdgeInsets.symmetric(
              horizontal:
                  isDesktop
                      ? 28
                      : isTablet
                          ? 22
                          : 16,
              vertical: 20,
            ),
            child:
                Center(
              child:
                  ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 1250,
                ),
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildHeader(
                      theme,
                      isDesktop,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildSummary(
                      isDesktop,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildPaymentOverview(),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildFilters(
                      theme,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildSupplierList(
                      theme,
                      suppliers,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(
    ThemeData theme,
    bool isDesktop,
  ) {
    final String dateText =
        _startDate != null &&
                _endDate != null
            ? '${_date(_startDate!)} - ${_date(_endDate!)}'
            : 'All dates';

    return Container(
      width:
          double.infinity,
      padding:
          EdgeInsets.all(
        isDesktop
            ? 26
            : 20,
      ),
      decoration:
          const BoxDecoration(
        gradient:
            LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.secondary,
          ],
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.all(
          Radius.circular(
            22,
          ),
        ),
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: 0.15,
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child:
                const Icon(
              Icons
                  .local_shipping_rounded,
              color:
                  Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(
            width: 16,
          ),
          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Supplier Report',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        24,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  'Analyse supplier-wise purchases, payments, outstanding balances and purchase activity.',
                  style:
                      TextStyle(
                    color: Colors
                        .white
                        .withValues(
                      alpha:
                          0.82,
                    ),
                    fontSize:
                        13,
                    height:
                        1.4,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        11,
                    vertical:
                        6,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors
                        .white
                        .withValues(
                      alpha:
                          0.14,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      30,
                    ),
                  ),
                  child:
                      Text(
                    dateText,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop)
            IconButton(
              tooltip:
                  'Refresh',
              onPressed:
                  _refreshing
                      ? null
                      : _refreshReport,
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2,
                        color:
                            Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons
                          .refresh_rounded,
                      color:
                          Colors.white,
                    ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummary(
    bool isDesktop,
  ) {
    final List<_SummaryItem>
        items = [
      _SummaryItem(
        title:
            'Total Purchases',
        value:
            _currency(
          _totalPurchases,
        ),
        subtitle:
            'Purchase amount',
        icon:
            Icons
                .shopping_cart_rounded,
        color:
            AppColors.primary,
      ),
      _SummaryItem(
        title:
            'Paid',
        value:
            _currency(
          _totalPaid,
        ),
        subtitle:
            'Purchase + supplier payments',
        icon:
            Icons.payments_rounded,
        color:
            AppColors.success,
      ),
      _SummaryItem(
        title:
            'Outstanding',
        value:
            _currency(
          _totalOutstanding,
        ),
        subtitle:
            'Supplier payable',
        icon:
            Icons
                .account_balance_wallet_rounded,
        color:
            AppColors.warning,
      ),
      _SummaryItem(
        title:
            'Suppliers',
        value:
            '${_filteredSuppliers.length}',
        subtitle:
            'Suppliers in report',
        icon:
            Icons
                .local_shipping_rounded,
        color:
            AppColors.secondary,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount:
          items.length,
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            isDesktop
                ? 4
                : 2,
        crossAxisSpacing:
            14,
        mainAxisSpacing:
            14,
        childAspectRatio:
            isDesktop
                ? 1.85
                : 1.48,
      ),
      itemBuilder:
          (
        context,
        index,
      ) {
        return _SummaryCard(
          item:
              items[index],
        );
      },
    );
  }

  // ===========================================================================
  // PAYMENT OVERVIEW
  // ===========================================================================

  Widget _buildPaymentOverview() {
    return _ReportCard(
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon:
                Icons.payments_rounded,
            title:
                'Supplier Payment Overview',
            subtitle:
                'Purchase payment status and supplier payment activity',
          ),
          const SizedBox(
            height: 18,
          ),
          LayoutBuilder(
            builder:
                (
              context,
              constraints,
            ) {
              final bool compact =
                  constraints.maxWidth <
                      650;

              final List<Widget>
                  items = [
                _PaymentStatusTile(
                  title:
                      'Paid',
                  count:
                      _paidPurchaseCount,
                  color:
                      AppColors.success,
                ),
                _PaymentStatusTile(
                  title:
                      'Partial',
                  count:
                      _partialPurchaseCount,
                  color:
                      AppColors.warning,
                ),
                _PaymentStatusTile(
                  title:
                      'Unpaid',
                  count:
                      _unpaidPurchaseCount,
                  color:
                      AppColors.danger,
                ),
              ];

              if (compact) {
                return Column(
                  children:
                      items
                          .map(
                            (
                              item,
                            ) =>
                                Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom:
                                    10,
                              ),
                              child:
                                  item,
                            ),
                          )
                          .toList(),
                );
              }

              return Row(
                children:
                    items
                        .map(
                          (
                            item,
                          ) =>
                              Expanded(
                            child:
                                Padding(
                              padding:
                                  const EdgeInsets.only(
                                right:
                                    10,
                              ),
                              child:
                                  item,
                            ),
                          ),
                        )
                        .toList(),
              );
            },
          ),
          const SizedBox(
            height: 16,
          ),
          Row(
            children: [
              Expanded(
                child:
                    ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  child:
                      LinearProgressIndicator(
                    value:
                        (_paymentRate /
                                100)
                            .clamp(
                      0.0,
                      1.0,
                    ),
                    minHeight:
                        8,
                    backgroundColor:
                        Theme.of(
                          context,
                        )
                            .colorScheme
                            .outlineVariant
                            .withValues(
                          alpha:
                              0.35,
                        ),
                    valueColor:
                        const AlwaysStoppedAnimation<
                            Color>(
                      AppColors.success,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Text(
                '${_paymentRate.toStringAsFixed(1)}% paid',
                style:
                    const TextStyle(
                  color:
                      AppColors.success,
                  fontWeight:
                      FontWeight.w700,
                  fontSize:
                      12,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          Row(
            children: [
              Expanded(
                child:
                    _MiniMetric(
                  label:
                      'Purchase Payments',
                  value:
                      _currency(
                    _totalPurchasePaid,
                  ),
                  icon:
                      Icons
                          .receipt_long_outlined,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child:
                    _MiniMetric(
                  label:
                      'Supplier Payments',
                  value:
                      _currency(
                    _totalSupplierPayments,
                  ),
                  icon:
                      Icons
                          .account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FILTERS
  // ===========================================================================

  Widget _buildFilters(
    ThemeData theme,
  ) {
    final bool hasDateFilter =
        _startDate != null &&
            _endDate != null;

    return _ReportCard(
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Search & Filters',
            style:
                theme.textTheme.titleMedium?.copyWith(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: 13,
          ),
          TextField(
            controller:
                _searchController,
            onChanged:
                (value) {
              setState(() {
                _searchQuery =
                    value
                        .trim()
                        .toLowerCase();
              });
            },
            decoration:
                InputDecoration(
              hintText:
                  'Search supplier, contact, mobile, email or GST...',
              prefixIcon:
                  const Icon(
                Icons
                    .search_rounded,
              ),
              suffixIcon:
                  _searchQuery
                          .isNotEmpty
                      ? IconButton(
                          onPressed:
                              () {
                            _searchController
                                .clear();

                            setState(
                              () {
                                _searchQuery =
                                    '';
                              },
                            );
                          },
                          icon:
                              const Icon(
                            Icons
                                .clear_rounded,
                          ),
                        )
                      : null,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          Wrap(
            spacing:
                8,
            runSpacing:
                8,
            children:
                _paymentStatuses
                    .map(
              (
                status,
              ) {
                return ChoiceChip(
                  label:
                      Text(
                    status,
                  ),
                  selected:
                      _selectedPaymentStatus ==
                          status,
                  onSelected:
                      (_) {
                    setState(
                      () {
                        _selectedPaymentStatus =
                            status;
                      },
                    );
                  },
                );
              },
            ).toList(),
          ),
          const SizedBox(
            height: 12,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _setToday,
                child: const Text('Today'),
              ),
              OutlinedButton(
                onPressed: _setThisWeek,
                child: const Text('This Week'),
              ),
              OutlinedButton(
                onPressed: _setThisMonth,
                child: const Text('This Month'),
              ),
              OutlinedButton(
                onPressed: _setLastMonth,
                child: const Text('Last Month'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing:
                10,
            runSpacing:
                10,
            children: [
              OutlinedButton.icon(
                onPressed:
                    _selectDateRange,
                icon:
                    const Icon(
                  Icons
                      .date_range_rounded,
                ),
                label:
                    Text(
                  hasDateFilter
                      ? '${_date(_startDate!)} - ${_date(_endDate!)}'
                      : 'Select Date Range',
                ),
              ),
              if (hasDateFilter)
                TextButton.icon(
                  onPressed:
                      _clearDateFilter,
                  icon:
                      const Icon(
                    Icons
                        .clear_rounded,
                  ),
                  label:
                      const Text(
                    'Clear Date',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUPPLIER LIST
  // ===========================================================================

  Widget _buildSupplierList(
    ThemeData theme,
    List<SupplierModel>
        suppliers,
  ) {
    return _ReportCard(
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons
                    .local_shipping_rounded,
            title:
                'Supplier-wise Performance',
            subtitle:
                '${suppliers.length} supplier${suppliers.length == 1 ? '' : 's'} found',
          ),
          const SizedBox(
            height: 18,
          ),
          if (suppliers.isEmpty)
            const _EmptyInline(
              icon:
                  Icons
                      .local_shipping_outlined,
              message:
                  'No suppliers match the selected filters.',
            )
          else
            ...suppliers.map(
              (
                supplier,
              ) {
                return _SupplierTile(
                  supplier:
                      supplier,
                  purchaseCount:
                      _supplierPurchaseCount(
                    supplier,
                  ),
                  quantity:
                      _supplierQuantity(
                    supplier,
                  ),
                  totalPurchases:
                      _supplierPurchaseAmount(
                    supplier,
                  ),
                  paid:
                      _supplierPaidAmount(
                    supplier,
                  ),
                  outstanding:
                      _supplierOutstandingAmount(
                    supplier,
                  ),
                  currency:
                      _currency,
                  number:
                      _number,
                  onTap:
                      () {
                    _showSupplierDetails(
                      supplier,
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUPPLIER DETAILS
  // ===========================================================================

  void _showSupplierDetails(
    SupplierModel supplier,
  ) {
    final List<PurchaseModel>
        purchases =
        _supplierPurchases(
      supplier,
    );

    final List<SupplierPaymentModel>
        supplierPayments =
        _supplierPaymentsFor(
      supplier,
    );

    final double total =
        _supplierPurchaseAmount(
      supplier,
    );

    final double paid =
        _supplierPaidAmount(
      supplier,
    );

    final double separatePayments =
        _supplierPaymentAmount(
      supplier,
    );

    final double outstanding =
        _supplierOutstandingAmount(
      supplier,
    );

    showModalBottomSheet<void>(
      context:
          context,
      isScrollControlled:
          true,
      showDragHandle:
          true,
      builder:
          (sheetContext) {
        final ThemeData theme =
            Theme.of(
          sheetContext,
        );

        return SafeArea(
          child:
              Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child:
                SingleChildScrollView(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width:
                            50,
                        height:
                            50,
                        decoration:
                            BoxDecoration(
                          color:
                              AppColors.primary
                                  .withValues(
                            alpha:
                                0.10,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                        child:
                            const Icon(
                          Icons
                              .local_shipping_rounded,
                          color:
                              AppColors.primary,
                          size:
                              25,
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplier.name,
                              style:
                                  theme.textTheme.headlineSmall?.copyWith(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            if (supplier
                                .contactPerson
                                .trim()
                                .isNotEmpty)
                              Text(
                                supplier.contactPerson,
                                style:
                                    theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  _SupplierDetailSummary(
                    total:
                        _currency(
                      total,
                    ),
                    paid:
                        _currency(
                      paid,
                    ),
                    outstanding:
                        _currency(
                      outstanding,
                    ),
                    purchases:
                        '${purchases.length}',
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  _MiniMetric(
                    label:
                        'Separate Supplier Payments',
                    value:
                        _currency(
                      separatePayments,
                    ),
                    icon:
                        Icons
                            .payments_outlined,
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  if (supplier
                      .contactPerson
                      .trim()
                      .isNotEmpty)
                    _DetailRow(
                      label:
                          'Contact Person',
                      value:
                          supplier.contactPerson,
                    ),
                  if (supplier.mobile
                      .trim()
                      .isNotEmpty)
                    _DetailRow(
                      label:
                          'Mobile',
                      value:
                          supplier.mobile,
                    ),
                  if (supplier.email
                      .trim()
                      .isNotEmpty)
                    _DetailRow(
                      label:
                          'Email',
                      value:
                          supplier.email,
                    ),
                  if (supplier.address
                      .trim()
                      .isNotEmpty)
                    _DetailRow(
                      label:
                          'Address',
                      value:
                          supplier.address,
                    ),
                  if (supplier.gstNumber
                      .trim()
                      .isNotEmpty)
                    _DetailRow(
                      label:
                          'GST Number',
                      value:
                          supplier.gstNumber,
                    ),
                  const SizedBox(
                    height: 12,
                  ),
                  Text(
                    'Recent Purchases',
                    style:
                        theme.textTheme.titleMedium?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  if (purchases.isEmpty)
                    const _EmptyInline(
                      icon:
                          Icons
                              .shopping_cart_outlined,
                      message:
                          'No purchases found for this supplier in the selected period.',
                    )
                  else
                    ...purchases.reversed
                        .take(
                          10,
                        )
                        .map(
                      (
                        purchase,
                      ) {
                        final double due =
                            purchase.total -
                                purchase.paidAmount;

                        return Container(
                          margin:
                              const EdgeInsets.only(
                            bottom:
                                8,
                          ),
                          padding:
                              const EdgeInsets.all(
                            13,
                          ),
                          decoration:
                              BoxDecoration(
                            color: theme
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(
                              alpha:
                                  0.35,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),
                          child:
                              Row(
                            children: [
                              Expanded(
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      purchase.id,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight:
                                            FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(
                                      height:
                                          3,
                                    ),
                                    Text(
                                      _date(
                                        purchase.date,
                                      ),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width:
                                    12,
                              ),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _currency(
                                      purchase.total,
                                    ),
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(
                                    height:
                                        3,
                                  ),
                                  Text(
                                    due >
                                            0
                                        ? 'Due ${_currency(due)}'
                                        : 'Paid',
                                    style:
                                        TextStyle(
                                      color:
                                          due > 0
                                              ? AppColors.warning
                                              : AppColors.success,
                                      fontSize:
                                          11,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(
                    height: 20,
                  ),
                  Text(
                    'Supplier Payments',
                    style:
                        theme.textTheme.titleMedium?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  if (supplierPayments.isEmpty)
                    const _EmptyInline(
                      icon:
                          Icons
                              .payments_outlined,
                      message:
                          'No supplier payments found in the selected period.',
                    )
                  else
                    ...supplierPayments
                        .toList()
                        .reversed
                        .take(
                          10,
                        )
                        .map(
                      (
                        payment,
                      ) {
                        return Container(
                          margin:
                              const EdgeInsets.only(
                            bottom:
                                8,
                          ),
                          padding:
                              const EdgeInsets.all(
                            13,
                          ),
                          decoration:
                              BoxDecoration(
                            color: theme
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(
                              alpha:
                                  0.35,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),
                          child:
                              Row(
                            children: [
                              Container(
                                width:
                                    38,
                                height:
                                    38,
                                decoration:
                                    BoxDecoration(
                                  color:
                                      AppColors.success.withValues(
                                    alpha:
                                        0.10,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(
                                    11,
                                  ),
                                ),
                                child:
                                    const Icon(
                                  Icons
                                      .arrow_upward_rounded,
                                  color:
                                      AppColors.success,
                                  size:
                                      20,
                                ),
                              ),
                              const SizedBox(
                                width:
                                    11,
                              ),
                              Expanded(
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _date(
                                        payment.date,
                                      ),
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight:
                                            FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(
                                      height:
                                          3,
                                    ),
                                    Text(
                                      payment.paymentMethod
                                              .trim()
                                              .isEmpty
                                          ? 'Other'
                                          : payment.paymentMethod,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (payment
                                        .transactionReference
                                        .trim()
                                        .isNotEmpty)
                                      Text(
                                        payment.transactionReference,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color:
                                              theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                _currency(
                                  payment.amount,
                                ),
                                style:
                                    const TextStyle(
                                  color:
                                      AppColors.success,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  Widget _buildErrorState(
    ThemeData theme,
  ) {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child:
            ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth:
                500,
          ),
          child:
              _ReportCard(
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width:
                      64,
                  height:
                      64,
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.danger.withValues(
                      alpha:
                          0.10,
                    ),
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      const Icon(
                    Icons
                        .error_outline_rounded,
                    color:
                        AppColors.danger,
                    size:
                        32,
                  ),
                ),
                const SizedBox(
                  height:
                      16,
                ),
                Text(
                  'Unable to load Supplier Report',
                  textAlign:
                      TextAlign.center,
                  style:
                      theme.textTheme.titleLarge?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height:
                      8,
                ),
                Text(
                  _errorMessage ??
                      'Something went wrong.',
                  textAlign:
                      TextAlign.center,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height:
                      20,
                ),
                FilledButton.icon(
                  onPressed:
                      () => _loadReport(),
                  icon:
                      const Icon(
                    Icons
                        .refresh_rounded,
                  ),
                  label:
                      const Text(
                    'Try Again',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SUMMARY ITEM
// =============================================================================

class _SummaryItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

// =============================================================================
// SUMMARY CARD
// =============================================================================

class _SummaryCard
    extends StatelessWidget {
  final _SummaryItem item;

  const _SummaryCard({
    required this.item,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.all(
        17,
      ),
      decoration:
          BoxDecoration(
        color:
            theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        border:
            Border.all(
          color:
              item.color.withValues(
            alpha:
                0.20,
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:
                    40,
                height:
                    40,
                decoration:
                    BoxDecoration(
                  color:
                      item.color.withValues(
                    alpha:
                        0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child:
                    Icon(
                  item.icon,
                  color:
                      item.color,
                  size:
                      21,
                ),
              ),
              const Spacer(),
              Icon(
                Icons
                    .arrow_outward_rounded,
                color:
                    item.color.withValues(
                  alpha:
                      0.65,
                ),
                size:
                    18,
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.title,
            maxLines:
                1,
            overflow:
                TextOverflow.ellipsis,
            style:
                theme.textTheme.bodySmall?.copyWith(
              color:
                  theme.colorScheme.onSurfaceVariant,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(
            height:
                3,
          ),
          Text(
            item.value,
            maxLines:
                1,
            overflow:
                TextOverflow.ellipsis,
            style:
                theme.textTheme.titleLarge?.copyWith(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(
            height:
                2,
          ),
          Text(
            item.subtitle,
            maxLines:
                1,
            overflow:
                TextOverflow.ellipsis,
            style:
                theme.textTheme.bodySmall?.copyWith(
              color:
                  item.color,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PAYMENT STATUS TILE
// =============================================================================

class _PaymentStatusTile
    extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _PaymentStatusTile({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha:
              0.06,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
          color:
              color.withValues(
            alpha:
                0.15,
          ),
        ),
      ),
      child:
          Row(
        children: [
          Container(
            width:
                40,
            height:
                40,
            decoration:
                BoxDecoration(
              color:
                  color.withValues(
                alpha:
                    0.10,
              ),
              shape:
                  BoxShape.circle,
            ),
            child:
                Icon(
              title == 'Paid'
                  ? Icons
                      .check_rounded
                  : title == 'Partial'
                      ? Icons
                          .remove_rounded
                      : Icons
                          .close_rounded,
              color:
                  color,
              size:
                  21,
            ),
          ),
          const SizedBox(
            width:
                11,
          ),
          Expanded(
            child:
                Text(
              title,
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$count',
            style:
                theme.textTheme.titleMedium?.copyWith(
              color:
                  color,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SUPPLIER TILE
// =============================================================================

class _SupplierTile
    extends StatelessWidget {
  final SupplierModel supplier;
  final int purchaseCount;
  final double quantity;
  final double totalPurchases;
  final double paid;
  final double outstanding;
  final String Function(double) currency;
  final String Function(double) number;
  final VoidCallback onTap;

  const _SupplierTile({
    required this.supplier,
    required this.purchaseCount,
    required this.quantity,
    required this.totalPurchases,
    required this.paid,
    required this.outstanding,
    required this.currency,
    required this.number,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            12,
      ),
      decoration:
          BoxDecoration(
        color:
            theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              theme.colorScheme.outlineVariant.withValues(
            alpha:
                0.45,
          ),
        ),
      ),
      child:
          Material(
        color:
            Colors.transparent,
        child:
            InkWell(
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          onTap:
              onTap,
          child:
              Padding(
            padding:
                const EdgeInsets.all(
              16,
            ),
            child:
                Column(
              children: [
                Row(
                  children: [
                    Container(
                      width:
                          48,
                      height:
                          48,
                      decoration:
                          BoxDecoration(
                        color:
                            AppColors.primary.withValues(
                          alpha:
                              0.10,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .local_shipping_rounded,
                        color:
                            AppColors.primary,
                      ),
                    ),
                    const SizedBox(
                      width:
                          12,
                    ),
                    Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplier.name,
                            maxLines:
                                1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                theme.textTheme.titleMedium?.copyWith(
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                          const SizedBox(
                            height:
                                3,
                          ),
                          Text(
                            supplier.mobile
                                    .trim()
                                    .isEmpty
                                ? supplier
                                    .contactPerson
                                : supplier.mobile,
                            maxLines:
                                1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width:
                          8,
                    ),
                    const Icon(
                      Icons
                          .chevron_right_rounded,
                    ),
                  ],
                ),
                const SizedBox(
                  height:
                      14,
                ),
                LayoutBuilder(
                  builder:
                      (
                    context,
                    constraints,
                  ) {
                    final bool compact =
                        constraints.maxWidth <
                            520;

                    final List<Widget>
                        metrics = [
                      _SupplierMetric(
                        label:
                            'Purchases',
                        value:
                            currency(
                          totalPurchases,
                        ),
                        icon:
                            Icons
                                .shopping_cart_outlined,
                        color:
                            AppColors.primary,
                      ),
                      _SupplierMetric(
                        label:
                            'Paid',
                        value:
                            currency(
                          paid,
                        ),
                        icon:
                            Icons
                                .payments_outlined,
                        color:
                            AppColors.success,
                      ),
                      _SupplierMetric(
                        label:
                            'Outstanding',
                        value:
                            currency(
                          outstanding,
                        ),
                        icon:
                            Icons
                                .account_balance_wallet_outlined,
                        color:
                            outstanding >
                                    0
                                ? AppColors.warning
                                : AppColors.success,
                      ),
                    ];

                    if (compact) {
                      return Column(
                        children:
                            metrics
                                .map(
                                  (
                                    metric,
                                  ) =>
                                      Padding(
                                    padding:
                                        const EdgeInsets.only(
                                      bottom:
                                          8,
                                    ),
                                    child:
                                        metric,
                                  ),
                                )
                                .toList(),
                      );
                    }

                    return Row(
                      children:
                          metrics
                              .map(
                                (
                                  metric,
                                ) =>
                                    Expanded(
                                  child:
                                      Padding(
                                    padding:
                                        const EdgeInsets.only(
                                      right:
                                          8,
                                    ),
                                    child:
                                        metric,
                                  ),
                                ),
                              )
                              .toList(),
                    );
                  },
                ),
                const SizedBox(
                  height:
                      10,
                ),
                Row(
                  children: [
                    Icon(
                      Icons
                          .inventory_2_outlined,
                      size:
                          16,
                      color:
                          theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(
                      width:
                          6,
                    ),
                    Text(
                      '${number(quantity)} quantity • $purchaseCount purchase${purchaseCount == 1 ? '' : 's'}',
                      style:
                          theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SUPPLIER METRIC
// =============================================================================

class _SupplierMetric
    extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SupplierMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            12,
        vertical:
            11,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha:
              0.05,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child:
          Row(
        children: [
          Icon(
            icon,
            size:
                18,
            color:
                color,
          ),
          const SizedBox(
            width:
                8,
          ),
          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height:
                      2,
                ),
                Text(
                  value,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MINI METRIC
// =============================================================================

class _MiniMetric
    extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(
          alpha:
              0.35,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child:
          Row(
        children: [
          Icon(
            icon,
            size:
                18,
            color:
                AppColors.primary,
          ),
          const SizedBox(
            width:
                8,
          ),
          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height:
                      2,
                ),
                Text(
                  value,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SUPPLIER DETAIL SUMMARY
// =============================================================================

class _SupplierDetailSummary
    extends StatelessWidget {
  final String total;
  final String paid;
  final String outstanding;
  final String purchases;

  const _SupplierDetailSummary({
    required this.total,
    required this.paid,
    required this.outstanding,
    required this.purchases,
  });

  @override
  Widget build(
    BuildContext context,
  ) {

    return GridView.count(
      shrinkWrap:
          true,
      physics:
          const NeverScrollableScrollPhysics(),
      crossAxisCount:
          2,
      crossAxisSpacing:
          10,
      mainAxisSpacing:
          10,
      childAspectRatio:
          1.7,
      children: [
        _DetailMetric(
          label:
              'Purchases',
          value:
              total,
          icon:
              Icons
                  .shopping_cart_outlined,
          color:
              AppColors.primary,
        ),
        _DetailMetric(
          label:
              'Paid',
          value:
              paid,
          icon:
              Icons
                  .payments_outlined,
          color:
              AppColors.success,
        ),
        _DetailMetric(
          label:
              'Outstanding',
          value:
              outstanding,
          icon:
              Icons
                  .account_balance_wallet_outlined,
          color:
              outstanding ==
                      '₹0.00'
                  ? AppColors.success
                  : AppColors.warning,
        ),
        _DetailMetric(
          label:
              'Purchase Count',
          value:
              purchases,
          icon:
              Icons
                  .receipt_long_outlined,
          color:
              AppColors.secondary,
        ),
      ],
    );
  }
}

// =============================================================================
// DETAIL METRIC
// =============================================================================

class _DetailMetric
    extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DetailMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha:
              0.06,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
          color:
              color.withValues(
            alpha:
                0.14,
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color:
                color,
            size:
                19,
          ),
          const Spacer(),
          Text(
            label,
            maxLines:
                1,
            overflow:
                TextOverflow.ellipsis,
            style:
                theme.textTheme.bodySmall?.copyWith(
              color:
                  theme.colorScheme.onSurfaceVariant,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(
            height:
                2,
          ),
          Text(
            value,
            maxLines:
                1,
            overflow:
                TextOverflow.ellipsis,
            style:
                theme.textTheme.titleSmall?.copyWith(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DETAIL ROW
// =============================================================================

class _DetailRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom:
            9,
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width:
                125,
            child:
                Text(
              label,
              style:
                  theme.textTheme.bodySmall?.copyWith(
                color:
                    theme.colorScheme.onSurfaceVariant,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child:
                Text(
              value,
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// REPORT CARD
// =============================================================================

class _ReportCard
    extends StatelessWidget {
  final Widget child;

  const _ReportCard({
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              theme.colorScheme.outlineVariant.withValues(
            alpha:
                0.45,
          ),
        ),
      ),
      child:
          child,
    );
  }
}

// =============================================================================
// SECTION HEADER
// =============================================================================

class _SectionHeader
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width:
              42,
          height:
              42,
          decoration:
              BoxDecoration(
            color:
                AppColors.primary.withValues(
              alpha:
                  0.10,
            ),
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
          child:
              Icon(
            icon,
            color:
                AppColors.primary,
            size:
                21,
          ),
        ),
        const SizedBox(
          width:
              11,
        ),
        Expanded(
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    theme.textTheme.titleMedium?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(
                height:
                    3,
              ),
              Text(
                subtitle,
                style:
                    theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// EMPTY INLINE
// =============================================================================

class _EmptyInline
    extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyInline({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        22,
      ),
      decoration:
          BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(
          alpha:
              0.30,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child:
          Column(
        children: [
          Icon(
            icon,
            size:
                32,
            color:
                theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(
            height:
                8,
          ),
          Text(
            message,
            textAlign:
                TextAlign.center,
            style:
                theme.textTheme.bodyMedium?.copyWith(
              color:
                  theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}