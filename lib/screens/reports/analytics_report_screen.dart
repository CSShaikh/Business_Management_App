import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../core/widgets/app_date_picker.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:public_file_saver/public_file_saver.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/expense_model.dart';
import '../../models/payment_model.dart';
import '../../models/purchase_model.dart';
import '../../models/sale_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/purchase_repository.dart';
import '../../repositories/sale_repository.dart';

class AnalyticsReportScreen extends StatefulWidget {
  const AnalyticsReportScreen({
    super.key,
  });

  @override
  State<AnalyticsReportScreen> createState() =>
      _AnalyticsReportScreenState();
}

enum _AnalyticsPeriod {
  daily,
  weekly,
  monthly,
}

class _AnalyticsReportScreenState
    extends State<AnalyticsReportScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final SaleRepository _saleRepository =
      SaleRepository();

  final PurchaseRepository _purchaseRepository =
      PurchaseRepository();

  final ExpenseRepository _expenseRepository =
      ExpenseRepository();

  final PaymentRepository _paymentRepository =
      PaymentRepository();

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _downloadingPdf = false;
  String? _errorMessage;
  BusinessModel? _business;

  _AnalyticsPeriod _period =
      _AnalyticsPeriod.daily;

  DateTime? _startDate;
  DateTime? _endDate;

  List<SaleModel> _sales = <SaleModel>[];
  List<PurchaseModel> _purchases =
      <PurchaseModel>[];
  List<ExpenseModel> _expenses =
      <ExpenseModel>[];
  List<PaymentModel> _payments =
      <PaymentModel>[];

  @override
  void initState() {
    super.initState();
    _setDefaultDateRange();
    _loadAnalytics();
  }

  void _setDefaultDateRange() {
    final DateTime now = DateTime.now();

    _startDate = DateTime(
      now.year,
      now.month,
      now.day,
    );

    _endDate = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
      999,
    );
  }

  Future<void> _loadAnalytics({
    bool showLoader = true,
  }) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isRefreshing = true;
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

      final results = await Future.wait<dynamic>([
        _saleRepository.getSales(
          businessId: business.id,
        ),
        _purchaseRepository.getPurchases(
          businessId: business.id,
        ),
        _expenseRepository.getExpenses(
          businessId: business.id,
        ),
        _paymentRepository.getPayments(
          businessId: business.id,
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _business = business;
        _sales =
            results[0] as List<SaleModel>;
        _purchases =
            results[1] as List<PurchaseModel>;
        _expenses =
            results[2] as List<ExpenseModel>;
        _payments =
            results[3] as List<PaymentModel>;

        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage =
            _cleanError(e);
      });
    }
  }

  Future<void> _refreshAnalytics() async {
    await _loadAnalytics(
      showLoader: false,
    );
  }

  String _cleanError(Object error) {
    final String message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  List<SaleModel> get _filteredSales {
    return _sales.where(_isSaleInDateRange).toList();
  }

  List<PurchaseModel> get _filteredPurchases {
    return _purchases
        .where(_isPurchaseInDateRange)
        .toList();
  }

  List<ExpenseModel> get _filteredExpenses {
    return _expenses
        .where(_isExpenseInDateRange)
        .toList();
  }

  List<PaymentModel> get _filteredPayments {
    return _payments
        .where(_isPaymentInDateRange)
        .toList();
  }

  bool _isSaleInDateRange(SaleModel sale) {
    return _isDateInRange(sale.date);
  }

  bool _isPurchaseInDateRange(
    PurchaseModel purchase,
  ) {
    return _isDateInRange(purchase.date);
  }

  bool _isExpenseInDateRange(
    ExpenseModel expense,
  ) {
    return _isDateInRange(expense.date);
  }

  bool _isPaymentInDateRange(
    PaymentModel payment,
  ) {
    return _isDateInRange(payment.date);
  }

  bool _isDateInRange(DateTime date) {
    final DateTime? start = _startDate;
    final DateTime? end = _endDate;

    if (start == null || end == null) {
      return true;
    }

    return !date.isBefore(start) &&
        !date.isAfter(end);
  }

  Future<void> _selectDateRange() async {
    final DateTime now = DateTime.now();

    final DateTimeRange? selected =
        await AppDatePicker.showDateRangePicker(
      context: context,
      
      initialEntryMode: DatePickerEntryMode.calendar,
      firstDate: DateTime(2020),
      lastDate: DateTime(
        now.year + 2,
        12,
        31,
      ),
      initialDateRange:
          _startDate != null &&
                  _endDate != null
              ? DateTimeRange(
                  start: _startDate!,
                  end: _endDate!,
                )
              : DateTimeRange(
                  start: DateTime(
                    now.year,
                    now.month,
                    1,
                  ),
                  end: now,
                ),
      helpText:
          'Select Analytics Period',
      saveText: 'Apply',
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _startDate = DateTime(
        selected.start.year,
        selected.start.month,
        selected.start.day,
      );

      _endDate = DateTime(
        selected.end.year,
        selected.end.month,
        selected.end.day,
        23,
        59,
        59,
        999,
      );
    });
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  void _setDateRange(DateTime start, DateTime end) {
    setState(() {
      _startDate = DateTime(start.year, start.month, start.day);
      _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    });
  }

  void _setToday() {
    final DateTime now = DateTime.now();
    _setDateRange(now, now);
  }

  void _setThisWeek() {
    final DateTime today = DateTime.now();
    final DateTime start = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    _setDateRange(start, start.add(const Duration(days: 6)));
  }

  void _setThisMonth() {
    final DateTime now = DateTime.now();
    _setDateRange(
      DateTime(now.year, now.month, 1),
      DateTime(now.year, now.month + 1, 0),
    );
  }

  void _setLastMonth() {
    final DateTime now = DateTime.now();
    _setDateRange(
      DateTime(now.year, now.month - 1, 1),
      DateTime(now.year, now.month, 0),
    );
  }

  String _pdfPeriodText() {
    if (_startDate == null || _endDate == null) return 'All available data';
    final DateFormat format = DateFormat('dd MMM yyyy');
    return '${format.format(_startDate!)} - ${format.format(_endDate!)}';
  }

  String _pdfMoney(double value) => 'Rs. ${value.toStringAsFixed(2)}';

  Future<void> _downloadPdf() async {
    if (_downloadingPdf || !mounted) return;
    final BusinessModel? business = _business;
    if (business == null) {
      _showMessage('Business information is not available.', isError: true);
      return;
    }

    setState(() => _downloadingPdf = true);
    try {
      final List<SaleModel> sales = _filteredSales;
      final List<PurchaseModel> purchases = _filteredPurchases;
      final List<ExpenseModel> expenses = _filteredExpenses;
      final List<PaymentModel> payments = _filteredPayments;
      final double salesTotal = _totalSales(sales);
      final double purchaseTotal = _totalPurchases(purchases);
      final double expenseTotal = _totalExpenses(expenses);
      final double paymentTotal = _totalSeparatePayments(payments);
      final double grossProfit = salesTotal - purchaseTotal;
      final double netProfit = grossProfit - expenseTotal;
      final double pending = salesTotal - paymentTotal;

      final pw.Document document = pw.Document();
      final pw.TextStyle small = const pw.TextStyle(fontSize: 9);
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Business Management App • Page ${context.pageNumber}',
              style: small,
            ),
          ),
          build: (context) => <pw.Widget>[
            pw.Text(
              business.businessName.trim().isEmpty
                  ? 'Business Report'
                  : business.businessName.trim(),
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            if (business.businessType.trim().isNotEmpty)
              pw.Text(business.businessType.trim(), style: small),
            if (business.address.trim().isNotEmpty)
              pw.Text(business.address.trim(), style: small),
            if (business.mobile.trim().isNotEmpty)
              pw.Text('Mobile: ${business.mobile.trim()}', style: small),
            if (business.email.trim().isNotEmpty)
              pw.Text('Email: ${business.email.trim()}', style: small),
            if (business.gstNumber.trim().isNotEmpty)
              pw.Text('GSTIN: ${business.gstNumber.trim()}', style: small),
            pw.SizedBox(height: 14),
            pw.Text('Analytics Report', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.Text('Period: ${_pdfPeriodText()}', style: small),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: const <String>['Metric', 'Value'],
              data: <List<String>>[
                <String>['Sales', _pdfMoney(salesTotal)],
                <String>['Purchases', _pdfMoney(purchaseTotal)],
                <String>['Expenses', _pdfMoney(expenseTotal)],
                <String>['Payments Received', _pdfMoney(paymentTotal)],
                <String>['Pending Collection', _pdfMoney(pending)],
                <String>['Gross Profit', _pdfMoney(grossProfit)],
                <String>['Net Profit', _pdfMoney(netProfit)],
                <String>['Sales Invoices', '${sales.length}'],
                <String>['Purchase Invoices', '${purchases.length}'],
                <String>['Expenses Count', '${expenses.length}'],
                <String>['Payments Count', '${payments.length}'],
              ],
              cellStyle: small,
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Trend Mode: ${_periodLabel()} • Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style: small,
            ),
          ],
        ),
      );

      final Uint8List bytes = Uint8List.fromList(await document.save());
      final String stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final PublicSavedFile? saved = await PublicFileSaver().saveBytes(
        bytes: bytes,
        fileName: 'analytics_report_$stamp.pdf',
        mimeType: 'application/pdf',
        subDir: 'Business Management Reports',
      );
      if (!mounted) return;
      _showMessage(
        saved?.isSuccess == true
            ? 'Analytics PDF saved to Downloads.'
            : 'Unable to save Analytics PDF.',
        isError: saved?.isSuccess != true,
      );
    } catch (e) {
      if (mounted) _showMessage('PDF download failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.danger : AppColors.success,
        ),
      );
  }

  void _setPeriod(
    _AnalyticsPeriod period,
  ) {
    final DateTime now = DateTime.now();

    setState(() {
      _period = period;

      switch (period) {
        case _AnalyticsPeriod.daily:
          _startDate = DateTime(
            now.year,
            now.month,
            now.day,
          );
          _endDate = DateTime(
            now.year,
            now.month,
            now.day,
            23,
            59,
            59,
            999,
          );
          break;

        case _AnalyticsPeriod.weekly:
          final DateTime today = DateTime(
            now.year,
            now.month,
            now.day,
          );

          final int daysFromMonday =
              today.weekday - 1;

          final DateTime monday =
              today.subtract(
            Duration(
              days: daysFromMonday,
            ),
          );

          _startDate = monday;
          _endDate = DateTime(
            monday.year,
            monday.month,
            monday.day + 6,
            23,
            59,
            59,
            999,
          );
          break;

        case _AnalyticsPeriod.monthly:
          _startDate = DateTime(
            now.year,
            now.month,
            1,
          );

          _endDate = DateTime(
            now.year,
            now.month + 1,
            0,
            23,
            59,
            59,
            999,
          );
          break;
      }
    });
  }

  double _totalSales(
    List<SaleModel> sales,
  ) {
    return sales.fold<double>(
      0,
      (sum, sale) =>
          sum + sale.total,
    );
  }

  double _totalPurchases(
    List<PurchaseModel> purchases,
  ) {
    return purchases.fold<double>(
      0,
      (sum, purchase) =>
          sum + purchase.total,
    );
  }

  double _totalExpenses(
    List<ExpenseModel> expenses,
  ) {
    return expenses.fold<double>(
      0,
      (sum, expense) =>
          sum + expense.amount,
    );
  }

  double _totalSalePaid(
    List<SaleModel> sales,
  ) {
    return sales.fold<double>(
      0,
      (sum, sale) =>
          sum + sale.paidAmount,
    );
  }

  double _totalSeparatePayments(
    List<PaymentModel> payments,
  ) {
    return payments.fold<double>(
      0,
      (sum, payment) =>
          sum + payment.amount,
    );
  }

  double _totalCollected(
    List<SaleModel> sales,
    List<PaymentModel> payments,
  ) {
    return _totalSalePaid(sales) +
        _totalSeparatePayments(
          payments,
        );
  }

  double _totalOutstanding(
    List<SaleModel> sales,
    List<PaymentModel> payments,
  ) {
    final double outstanding =
        _totalSales(sales) -
            _totalCollected(
              sales,
              payments,
            );

    return outstanding > 0
        ? outstanding
        : 0;
  }

  double _saleCost(
    SaleModel sale,
  ) {
    return sale.items.fold<double>(
      0,
      (sum, item) =>
          sum +
          item.quantity *
              item.costPrice,
    );
  }

  double _saleGrossProfit(
    SaleModel sale,
  ) {
    return sale.total -
        _saleCost(sale);
  }

  double _totalCost(
    List<SaleModel> sales,
  ) {
    return sales.fold<double>(
      0,
      (sum, sale) =>
          sum + _saleCost(sale),
    );
  }

  double _totalGrossProfit(
    List<SaleModel> sales,
  ) {
    return sales.fold<double>(
      0,
      (sum, sale) =>
          sum +
          _saleGrossProfit(
            sale,
          ),
    );
  }

  double _netProfit(
    List<SaleModel> sales,
    List<ExpenseModel> expenses,
  ) {
    return _totalGrossProfit(
          sales,
        ) -
        _totalExpenses(
          expenses,
        );
  }

  double _collectionRate(
    List<SaleModel> sales,
    List<PaymentModel> payments,
  ) {
    final double salesAmount =
        _totalSales(sales);

    if (salesAmount <= 0) {
      return 0;
    }

    return (_totalCollected(
              sales,
              payments,
            ) /
            salesAmount) *
        100;
  }

  double _profitMargin(
    List<SaleModel> sales,
  ) {
    final double salesAmount =
        _totalSales(sales);

    if (salesAmount <= 0) {
      return 0;
    }

    return (_totalGrossProfit(
              sales,
            ) /
            salesAmount) *
        100;
  }

  double _averageSale(
    List<SaleModel> sales,
  ) {
    if (sales.isEmpty) {
      return 0;
    }

    return _totalSales(sales) /
        sales.length;
  }

  double _averagePurchase(
    List<PurchaseModel> purchases,
  ) {
    if (purchases.isEmpty) {
      return 0;
    }

    return _totalPurchases(
          purchases,
        ) /
        purchases.length;
  }

  double _totalQuantity(
    List<SaleModel> sales,
  ) {
    return sales.fold<double>(
      0,
      (sum, sale) =>
          sum +
          sale.items.fold<double>(
            0,
            (
              itemSum,
              item,
            ) =>
                itemSum +
                item.quantity,
          ),
    );
  }


  Map<String, double> _expensesByCategory(
    List<ExpenseModel> expenses,
  ) {
    final Map<String, double> result =
        <String, double>{};

    for (final expense in expenses) {
      final String category =
          expense.category.trim().isEmpty
              ? 'Other'
              : expense.category.trim();

      result[category] =
          (result[category] ?? 0) +
              expense.amount;
    }

    return result;
  }

  Map<String, double> _paymentByMethod(
    List<PaymentModel> payments,
  ) {
    final Map<String, double> result =
        <String, double>{};

    for (final payment in payments) {
      final String method =
          payment.paymentMethod.trim().isEmpty
              ? 'Other'
              : payment.paymentMethod.trim();

      result[method] =
          (result[method] ?? 0) +
              payment.amount;
    }

    return result;
  }

  List<_MetricPoint> _buildTrendPoints(
    List<SaleModel> sales,
  ) {
    final Map<DateTime, double> values =
        <DateTime, double>{};

    for (final sale in sales) {
      DateTime key;

      switch (_period) {
        case _AnalyticsPeriod.daily:
          key = DateTime(
            sale.date.year,
            sale.date.month,
            sale.date.day,
          );
          break;

        case _AnalyticsPeriod.weekly:
          final DateTime date = DateTime(
            sale.date.year,
            sale.date.month,
            sale.date.day,
          );

          key = date.subtract(
            Duration(
              days: date.weekday - 1,
            ),
          );
          break;

        case _AnalyticsPeriod.monthly:
          key = DateTime(
            sale.date.year,
            sale.date.month,
          );
          break;
      }

      values[key] =
          (values[key] ?? 0) +
              sale.total;
    }

    final List<DateTime> dates =
        values.keys.toList()
          ..sort();

    return dates.map(
      (date) {
        String label;

        switch (_period) {
          case _AnalyticsPeriod.daily:
            label = DateFormat(
              'dd MMM',
            ).format(date);
            break;

          case _AnalyticsPeriod.weekly:
            label = DateFormat(
              'dd MMM',
            ).format(date);
            break;

          case _AnalyticsPeriod.monthly:
            label = DateFormat(
              'MMM',
            ).format(date);
            break;
        }

        return _MetricPoint(
          label: label,
          value: values[date] ?? 0,
        );
      },
    ).toList();
  }

  List<_MetricPoint> _buildPurchaseTrendPoints(
    List<PurchaseModel> purchases,
  ) {
    final Map<DateTime, double> values =
        <DateTime, double>{};

    for (final purchase in purchases) {
      DateTime key;

      switch (_period) {
        case _AnalyticsPeriod.daily:
          key = DateTime(
            purchase.date.year,
            purchase.date.month,
            purchase.date.day,
          );
          break;

        case _AnalyticsPeriod.weekly:
          final DateTime date = DateTime(
            purchase.date.year,
            purchase.date.month,
            purchase.date.day,
          );

          key = date.subtract(
            Duration(
              days: date.weekday - 1,
            ),
          );
          break;

        case _AnalyticsPeriod.monthly:
          key = DateTime(
            purchase.date.year,
            purchase.date.month,
          );
          break;
      }

      values[key] =
          (values[key] ?? 0) +
              purchase.total;
    }

    final List<DateTime> dates =
        values.keys.toList()
          ..sort();

    return dates.map(
      (date) {
        String label;

        switch (_period) {
          case _AnalyticsPeriod.daily:
          case _AnalyticsPeriod.weekly:
            label = DateFormat(
              'dd MMM',
            ).format(date);
            break;

          case _AnalyticsPeriod.monthly:
            label = DateFormat(
              'MMM',
            ).format(date);
            break;
        }

        return _MetricPoint(
          label: label,
          value:
              values[date] ?? 0,
        );
      },
    ).toList();
  }

  String _currency(
    double value,
  ) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  String _compactCurrency(
    double value,
  ) {
    if (value.abs() >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)}Cr';
    }

    if (value.abs() >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)}L';
    }

    if (value.abs() >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    }

    return _currency(value);
  }

  String _number(
    double value,
  ) {
    return NumberFormat(
      '#,##0.##',
      'en_IN',
    ).format(value);
  }

  String _dateRangeText() {
    if (_startDate == null ||
        _endDate == null) {
      return 'All Dates';
    }

    return '${DateFormat('dd MMM yyyy').format(_startDate!)}'
        ' - '
        '${DateFormat('dd MMM yyyy').format(_endDate!)}';
  }

  String _periodLabel() {
    switch (_period) {
      case _AnalyticsPeriod.daily:
        return 'Daily';

      case _AnalyticsPeriod.weekly:
        return 'Weekly';

      case _AnalyticsPeriod.monthly:
        return 'Monthly';
    }
  }

  Color _profitColor(
    double value,
  ) {
    return value >= 0
        ? AppColors.success
        : AppColors.danger;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(
        theme,
      );
    }

    final List<SaleModel> sales =
        _filteredSales;

    final List<PurchaseModel> purchases =
        _filteredPurchases;

    final List<ExpenseModel> expenses =
        _filteredExpenses;

    final List<PaymentModel> payments =
        _filteredPayments;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Analytics Report'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isRefreshing ? null : _refreshAnalytics,
            icon: _isRefreshing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Download PDF',
            onPressed: _downloadingPdf ? null : _downloadPdf,
            icon: _downloadingPdf
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAnalytics,
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final bool isDesktop =
              constraints.maxWidth >=
                  1000;

          final bool isTablet =
              constraints.maxWidth >= 650 &&
                  constraints.maxWidth < 1000;

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
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 1250,
                ),
                child: Column(
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
                    _buildDateFilter(
                      theme,
                    ),
                    const SizedBox(height: 10),
                    _buildDatePresets(theme),
                    const SizedBox(height: 20),
                    _buildSummaryCards(
                      theme,
                      sales,
                      purchases,
                      expenses,
                      payments,
                      isDesktop,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildPeriodSelector(
                      theme,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildSalesPurchaseChart(
                      theme,
                      sales,
                      purchases,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildProfitOverview(
                      theme,
                      sales,
                      expenses,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildPaymentOverview(
                      theme,
                      sales,
                      payments,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildExpenseOverview(
                      theme,
                      expenses,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildQuickMetrics(
                      theme,
                      sales,
                      purchases,
                      expenses,
                      payments,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    bool isDesktop,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Analytics',
                style:
                    theme.textTheme.headlineSmall
                        ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: 6,
              ),
              Text(
                'Track sales, purchases, profit, expenses and customer collections.',
                style:
                    theme.textTheme.bodyMedium
                        ?.copyWith(
                  color: theme
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(
                    alpha: 0.70,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(
          width: 12,
        ),
        if (isDesktop)
          OutlinedButton.icon(
            onPressed:
                _isRefreshing
                    ? null
                    : _refreshAnalytics,
            icon:
                _isRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons
                            .refresh_rounded,
                      ),
            label:
                const Text('Refresh'),
          )
        else
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _isRefreshing
                    ? null
                    : _refreshAnalytics,
            icon:
                _isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
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
      ],
    );
  }

  Widget _buildDateFilter(
    ThemeData theme,
  ) {
    return _AnalyticsCard(
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap:
                  _selectDateRange,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              child: Container(
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                decoration:
                    BoxDecoration(
                  border:
                      Border.all(
                    color:
                        theme.dividerColor,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .calendar_month_rounded,
                      size: 21,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'Date Range',
                            style:
                                theme
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            _dateRangeText(),
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                theme
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          if (_startDate != null ||
              _endDate != null)
            IconButton(
              tooltip:
                  'Clear date range',
              onPressed:
                  _clearDateRange,
              icon:
                  const Icon(
                Icons.clear_rounded,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDatePresets(ThemeData theme) {
    return _AnalyticsCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.today_rounded, size: 16),
            label: const Text('Today'),
            onPressed: _setToday,
          ),
          ActionChip(
            avatar: const Icon(Icons.view_week_rounded, size: 16),
            label: const Text('This Week'),
            onPressed: _setThisWeek,
          ),
          ActionChip(
            avatar: const Icon(Icons.calendar_month_rounded, size: 16),
            label: const Text('This Month'),
            onPressed: _setThisMonth,
          ),
          ActionChip(
            avatar: const Icon(Icons.history_rounded, size: 16),
            label: const Text('Last Month'),
            onPressed: _setLastMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(
    ThemeData theme,
  ) {
    return _AnalyticsCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _PeriodChip(
            label: 'Daily',
            icon:
                Icons.today_rounded,
            selected:
                _period ==
                    _AnalyticsPeriod.daily,
            onTap: () {
              _setPeriod(
                _AnalyticsPeriod.daily,
              );
            },
          ),
          _PeriodChip(
            label: 'Weekly',
            icon:
                Icons.view_week_rounded,
            selected:
                _period ==
                    _AnalyticsPeriod.weekly,
            onTap: () {
              _setPeriod(
                _AnalyticsPeriod.weekly,
              );
            },
          ),
          _PeriodChip(
            label: 'Monthly',
            icon:
                Icons.calendar_month_rounded,
            selected:
                _period ==
                    _AnalyticsPeriod.monthly,
            onTap: () {
              _setPeriod(
                _AnalyticsPeriod.monthly,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
    ThemeData theme,
    List<SaleModel> sales,
    List<PurchaseModel> purchases,
    List<ExpenseModel> expenses,
    List<PaymentModel> payments,
    bool isDesktop,
  ) {
    final double totalSales =
        _totalSales(sales);

    final double totalPurchases =
        _totalPurchases(purchases);

    final double grossProfit =
        _totalGrossProfit(sales);

    final double netProfit =
        _netProfit(
      sales,
      expenses,
    );

    final double collected =
        _totalCollected(
      sales,
      payments,
    );

    final double outstanding =
        _totalOutstanding(
      sales,
      payments,
    );

    final List<_AnalyticsSummaryItem>
        items = [
      _AnalyticsSummaryItem(
        title: 'Total Sales',
        value:
            _compactCurrency(
          totalSales,
        ),
        subtitle:
            '${sales.length} invoices',
        icon:
            Icons
                .point_of_sale_rounded,
        color:
            AppColors.success,
      ),
      _AnalyticsSummaryItem(
        title: 'Total Purchase',
        value:
            _compactCurrency(
          totalPurchases,
        ),
        subtitle:
            '${purchases.length} purchases',
        icon:
            Icons.shopping_cart_rounded,
        color:
            AppColors.info,
      ),
      _AnalyticsSummaryItem(
        title: 'Gross Profit',
        value:
            _compactCurrency(
          grossProfit,
        ),
        subtitle:
            '${_profitMargin(sales).toStringAsFixed(1)}% margin',
        icon:
            Icons.trending_up_rounded,
        color:
            _profitColor(
          grossProfit,
        ),
      ),
      _AnalyticsSummaryItem(
        title: 'Net Profit',
        value:
            _compactCurrency(
          netProfit,
        ),
        subtitle:
            '${expenses.length} expenses',
        icon:
            Icons.account_balance_wallet_rounded,
        color:
            _profitColor(
          netProfit,
        ),
      ),
      _AnalyticsSummaryItem(
        title: 'Collected',
        value:
            _compactCurrency(
          collected,
        ),
        subtitle:
            '${_collectionRate(sales, payments).toStringAsFixed(1)}% collection',
        icon:
            Icons.payments_rounded,
        color:
            AppColors.success,
      ),
      _AnalyticsSummaryItem(
        title: 'Outstanding',
        value:
            _compactCurrency(
          outstanding,
        ),
        subtitle:
            'Customer receivable',
        icon:
            Icons.pending_actions_rounded,
        color:
            outstanding > 0
                ? AppColors.warning
                : AppColors.success,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            isDesktop ? 3 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent:
            isDesktop ? 180 : 156,
      ),
      itemBuilder:
          (context, index) {
        final item = items[index];

        return _AnalyticsSummaryCard(
          item: item,
        );
      },
    );
  }

  Widget _buildSalesPurchaseChart(
    ThemeData theme,
    List<SaleModel> sales,
    List<PurchaseModel> purchases,
  ) {
    final List<_MetricPoint> salesPoints =
        _buildTrendPoints(
      sales,
    );

    final List<_MetricPoint>
        purchasePoints =
        _buildPurchaseTrendPoints(
      purchases,
    );

    final List<_MetricPoint> allPoints =
        [
      ...salesPoints,
      ...purchasePoints,
    ];

    double maxValue = 0;

    for (final point in allPoints) {
      if (point.value > maxValue) {
        maxValue = point.value;
      }
    }

    return _AnalyticsCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.show_chart_rounded,
            title:
                'Sales vs Purchase',
            subtitle:
                '${_periodLabel()} performance trend',
          ),
          const SizedBox(
            height: 18,
          ),
          if (allPoints.isEmpty)
            const _EmptyAnalytics(
              icon:
                  Icons.show_chart_rounded,
              message:
                  'No sales or purchase data available for the selected period.',
            )
          else
            SizedBox(
              height: 250,
              child: _TrendChart(
                sales:
                    salesPoints,
                purchases:
                    purchasePoints,
                maxValue:
                    maxValue,
                currency:
                    _compactCurrency,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfitOverview(
    ThemeData theme,
    List<SaleModel> sales,
    List<ExpenseModel> expenses,
  ) {
    final double grossProfit =
        _totalGrossProfit(sales);

    final double totalExpenses =
        _totalExpenses(expenses);

    final double netProfit =
        grossProfit -
            totalExpenses;

    return _AnalyticsCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons
                    .account_balance_rounded,
            title:
                'Profit Overview',
            subtitle:
                'Gross profit after business expenses',
          ),
          const SizedBox(
            height: 18,
          ),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _ProfitMetric(
                label:
                    'Sales Revenue',
                value:
                    _currency(
                  _totalSales(
                    sales,
                  ),
                ),
                color:
                    AppColors.info,
              ),
              _ProfitMetric(
                label:
                    'Sales Cost',
                value:
                    _currency(
                  _totalCost(
                    sales,
                  ),
                ),
                color:
                    AppColors.warning,
              ),
              _ProfitMetric(
                label:
                    'Gross Profit',
                value:
                    _currency(
                  grossProfit,
                ),
                color:
                    _profitColor(
                  grossProfit,
                ),
              ),
              _ProfitMetric(
                label:
                    'Expenses',
                value:
                    _currency(
                  totalExpenses,
                ),
                color:
                    AppColors.danger,
              ),
              _ProfitMetric(
                label:
                    'Net Profit',
                value:
                    _currency(
                  netProfit,
                ),
                color:
                    _profitColor(
                  netProfit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOverview(
    ThemeData theme,
    List<SaleModel> sales,
    List<PaymentModel> payments,
  ) {
    final double salePaid =
        _totalSalePaid(
      sales,
    );

    final double separatePayments =
        _totalSeparatePayments(
      payments,
    );

    final double collected =
        salePaid +
            separatePayments;

    final double outstanding =
        _totalOutstanding(
      sales,
      payments,
    );

    final Map<String, double>
        methods =
        _paymentByMethod(
      payments,
    );

    return _AnalyticsCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.payments_rounded,
            title:
                'Payment Analytics',
            subtitle:
                'Customer collections and outstanding receivables',
          ),
          const SizedBox(
            height: 18,
          ),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _ProfitMetric(
                label:
                    'Sale Payments',
                value:
                    _currency(
                  salePaid,
                ),
                color:
                    AppColors.info,
              ),
              _ProfitMetric(
                label:
                    'Separate Payments',
                value:
                    _currency(
                  separatePayments,
                ),
                color:
                    AppColors.success,
              ),
              _ProfitMetric(
                label:
                    'Total Collected',
                value:
                    _currency(
                  collected,
                ),
                color:
                    AppColors.success,
              ),
              _ProfitMetric(
                label:
                    'Outstanding',
                value:
                    _currency(
                  outstanding,
                ),
                color:
                    outstanding > 0
                        ? AppColors.warning
                        : AppColors.success,
              ),
            ],
          ),
          if (methods.isNotEmpty) ...[
            const SizedBox(
              height: 18,
            ),
            Text(
              'Separate Payment Methods',
              style:
                  theme.textTheme.titleSmall
                      ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  methods.entries
                      .map(
                (entry) {
                  return _TagMetric(
                    label:
                        entry.key,
                    value:
                        _currency(
                      entry.value,
                    ),
                  );
                },
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpenseOverview(
    ThemeData theme,
    List<ExpenseModel> expenses,
  ) {
    final Map<String, double>
        categories =
        _expensesByCategory(
      expenses,
    );

    final List<MapEntry<String, double>>
        sorted =
        categories.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(
              a.value,
            ),
          );

    return _AnalyticsCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.money_off_rounded,
            title:
                'Expense Distribution',
            subtitle:
                'Business expenses by category',
          ),
          const SizedBox(
            height: 18,
          ),
          if (sorted.isEmpty)
            const _EmptyAnalytics(
              icon:
                  Icons.money_off_rounded,
              message:
                  'No expenses available for the selected period.',
            )
          else
            Column(
              children:
                  sorted.take(10).map(
                (entry) {
                  final double total =
                      _totalExpenses(
                    expenses,
                  );

                  final double percentage =
                      total > 0
                          ? (entry.value /
                                  total) *
                              100
                          : 0;

                  return Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style:
                                    theme
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              _currency(
                                entry.value,
                              ),
                              style:
                                  theme
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style:
                                  theme
                                      .textTheme
                                      .bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 7,
                        ),
                        ClipRRect(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            6,
                          ),
                          child:
                              LinearProgressIndicator(
                            value:
                                (percentage /
                                        100)
                                    .clamp(
                              0.0,
                              1.0,
                            ),
                            minHeight:
                                7,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickMetrics(
    ThemeData theme,
    List<SaleModel> sales,
    List<PurchaseModel> purchases,
    List<ExpenseModel> expenses,
    List<PaymentModel> payments,
  ) {
    final List<_QuickMetric> metrics = [
      _QuickMetric(
        label:
            'Average Sale',
        value:
            _currency(
          _averageSale(
            sales,
          ),
        ),
        icon:
            Icons.receipt_long_rounded,
      ),
      _QuickMetric(
        label:
            'Average Purchase',
        value:
            _currency(
          _averagePurchase(
            purchases,
          ),
        ),
        icon:
            Icons.shopping_cart_rounded,
      ),
      _QuickMetric(
        label:
            'Items Sold',
        value:
            _number(
          _totalQuantity(
            sales,
          ),
        ),
        icon:
            Icons.inventory_2_rounded,
      ),
      _QuickMetric(
        label:
            'Profit Margin',
        value:
            '${_profitMargin(sales).toStringAsFixed(2)}%',
        icon:
            Icons.percent_rounded,
      ),
      _QuickMetric(
        label:
            'Collection Rate',
        value:
            '${_collectionRate(sales, payments).toStringAsFixed(2)}%',
        icon:
            Icons
                .account_balance_wallet_rounded,
      ),
      _QuickMetric(
        label:
            'Expense Total',
        value:
            _currency(
          _totalExpenses(
            expenses,
          ),
        ),
        icon:
            Icons.money_off_rounded,
      ),
    ];

    return _AnalyticsCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.insights_rounded,
            title:
                'Key Metrics',
            subtitle:
                'Quick performance indicators',
          ),
          const SizedBox(
            height: 18,
          ),
          GridView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            itemCount:
                metrics.length,
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 250,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemBuilder:
                (
              context,
              index,
            ) {
              return _QuickMetricTile(
                metric:
                    metrics[index],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: _AnalyticsCard(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .error_outline_rounded,
                size: 52,
                color:
                    AppColors.danger,
              ),
              const SizedBox(
                height: 12,
              ),
              Text(
                'Unable to load analytics',
                style:
                    theme.textTheme.titleMedium
                        ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
                textAlign:
                    TextAlign.center,
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                _errorMessage ??
                    'Something went wrong.',
                style:
                    theme.textTheme.bodyMedium,
                textAlign:
                    TextAlign.center,
              ),
              const SizedBox(
                height: 16,
              ),
              ElevatedButton.icon(
                onPressed:
                    () => _loadAnalytics(),
                icon:
                    const Icon(
                  Icons.refresh_rounded,
                ),
                label:
                    const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MODELS
// =============================================================================

class _AnalyticsSummaryItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _AnalyticsSummaryItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _MetricPoint {
  final String label;
  final double value;

  const _MetricPoint({
    required this.label,
    required this.value,
  });
}

class _QuickMetric {
  final String label;
  final String value;
  final IconData icon;

  const _QuickMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
}

// =============================================================================
// ANALYTICS CARD
// =============================================================================

class _AnalyticsCard
    extends StatelessWidget {
  final Widget child;

  const _AnalyticsCard({
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color:
            theme.cardColor,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              theme.dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius: 18,
            offset:
                const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}

// =============================================================================
// SUMMARY CARD
// =============================================================================

class _AnalyticsSummaryCard
    extends StatelessWidget {
  final _AnalyticsSummaryItem item;

  const _AnalyticsSummaryCard({
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
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color:
            item.color.withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border:
            Border.all(
          color:
              item.color.withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color:
                  item.color.withValues(
                alpha: 0.12,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              item.icon,
              color:
                  item.color,
              size: 22,
            ),
          ),
          const SizedBox(
            width: 11,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      theme.textTheme.labelMedium
                          ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      theme.textTheme.titleMedium
                          ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                    color:
                        item.color,
                  ),
                ),
                const SizedBox(
                  height: 1,
                ),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      theme.textTheme.labelSmall
                          ?.copyWith(
                    color:
                        theme
                            .textTheme
                            .labelSmall
                            ?.color
                            ?.withValues(
                      alpha: 0.65,
                    ),
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
          width: 40,
          height: 40,
          decoration:
              BoxDecoration(
            color:
                theme.colorScheme.primary
                    .withValues(
              alpha: 0.10,
            ),
            borderRadius:
                BorderRadius.circular(
              11,
            ),
          ),
          child: Icon(
            icon,
            size: 21,
            color:
                theme.colorScheme.primary,
          ),
        ),
        const SizedBox(
          width: 11,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    theme.textTheme.titleMedium
                        ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: 3,
              ),
              Text(
                subtitle,
                style:
                    theme.textTheme.bodySmall
                        ?.copyWith(
                  color:
                      theme
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(
                    alpha: 0.65,
                  ),
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
// PERIOD CHIP
// =============================================================================

class _PeriodChip
    extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final Color color =
        theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(
        10,
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 9,
        ),
        decoration:
            BoxDecoration(
          color:
              selected
                  ? color.withValues(
                      alpha: 0.10,
                    )
                  : Colors.transparent,
          border:
              Border.all(
            color:
                selected
                    ? color.withValues(
                        alpha: 0.35,
                      )
                    : theme.dividerColor,
          ),
          borderRadius:
              BorderRadius.circular(
            10,
          ),
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color:
                  selected
                      ? color
                      : null,
            ),
            const SizedBox(
              width: 7,
            ),
            Text(
              label,
              style:
                  theme.textTheme.bodyMedium
                      ?.copyWith(
                fontWeight:
                    selected
                        ? FontWeight.w800
                        : FontWeight.w600,
                color:
                    selected
                        ? color
                        : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PROFIT METRIC
// =============================================================================

class _ProfitMetric
    extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ProfitMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      constraints:
          const BoxConstraints(
        minWidth: 150,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border:
            Border.all(
          color:
              color.withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                theme.textTheme.labelSmall
                    ?.copyWith(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            value,
            style:
                theme.textTheme.titleSmall
                    ?.copyWith(
              color: color,
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
// TAG METRIC
// =============================================================================

class _TagMetric
    extends StatelessWidget {
  final String label;
  final String value;

  const _TagMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration:
          BoxDecoration(
        color:
            theme.colorScheme.primary
                .withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border:
            Border.all(
          color:
              theme.colorScheme.primary
                  .withValues(
            alpha: 0.15,
          ),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Text(
            label,
            style:
                theme.textTheme.bodySmall
                    ?.copyWith(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(
            width: 7,
          ),
          Text(
            value,
            style:
                theme.textTheme.bodySmall
                    ?.copyWith(
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
// QUICK METRIC TILE
// =============================================================================

class _QuickMetricTile
    extends StatelessWidget {
  final _QuickMetric metric;

  const _QuickMetricTile({
    required this.metric,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.all(13),
      decoration:
          BoxDecoration(
        border:
            Border.all(
          color:
              theme.dividerColor,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(
              color:
                  theme.colorScheme.primary
                      .withValues(
                alpha: 0.08,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              metric.icon,
              size: 19,
              color:
                  theme.colorScheme.primary,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      theme.textTheme.labelSmall
                          ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      theme.textTheme.bodyMedium
                          ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
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
// EMPTY STATE
// =============================================================================

class _EmptyAnalytics
    extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyAnalytics({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 28,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 42,
              color:
                  theme
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(
                alpha: 0.45,
              ),
            ),
            const SizedBox(
              height: 9,
            ),
            Text(
              message,
              textAlign:
                  TextAlign.center,
              style:
                  theme.textTheme.bodySmall
                      ?.copyWith(
                color:
                    theme
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(
                  alpha: 0.65,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TREND CHART
// =============================================================================

class _TrendChart
    extends StatelessWidget {
  final List<_MetricPoint> sales;
  final List<_MetricPoint> purchases;
  final double maxValue;
  final String Function(double)
      currency;

  const _TrendChart({
    required this.sales,
    required this.purchases,
    required this.maxValue,
    required this.currency,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final int count = math.max(
      sales.length,
      purchases.length,
    );

    if (count == 0) {
      return const SizedBox.shrink();
    }

    final double safeMax =
        maxValue <= 0
            ? 1
            : maxValue;

    final double width =
        math.max(
      620,
      count * 82,
    ).toDouble();

    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,
      child: SizedBox(
        width: width,
        height: 250,
        child: CustomPaint(
          painter:
              _TrendChartPainter(
            sales:
                sales,
            purchases:
                purchases,
            maxValue:
                safeMax,
            textColor:
                theme
                    .textTheme
                    .bodySmall
                    ?.color ??
                    theme
                        .colorScheme
                        .onSurface,
            gridColor:
                theme.dividerColor,
            salesColor:
                AppColors.success,
            purchaseColor:
                AppColors.info,
          ),
        ),
      ),
    );
  }
}

class _TrendChartPainter
    extends CustomPainter {
  final List<_MetricPoint> sales;
  final List<_MetricPoint> purchases;
  final double maxValue;
  final Color textColor;
  final Color gridColor;
  final Color salesColor;
  final Color purchaseColor;

  const _TrendChartPainter({
    required this.sales,
    required this.purchases,
    required this.maxValue,
    required this.textColor,
    required this.gridColor,
    required this.salesColor,
    required this.purchaseColor,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Paint gridPaint =
        Paint()
          ..color =
              gridColor.withValues(
            alpha: 0.65,
          )
          ..strokeWidth = 1;

    final Paint salesPaint =
        Paint()
          ..color = salesColor
          ..strokeWidth = 3
          ..style =
              PaintingStyle.stroke
          ..strokeCap =
              StrokeCap.round;

    final Paint purchasePaint =
        Paint()
          ..color = purchaseColor
          ..strokeWidth = 3
          ..style =
              PaintingStyle.stroke
          ..strokeCap =
              StrokeCap.round;

    const double left =
        45;
    const double right =
        18;
    const double top =
        18;
    const double bottom =
        40;

    final double chartWidth =
        size.width -
            left -
            right;

    final double chartHeight =
        size.height -
            top -
            bottom;

    for (int i = 0; i <= 4; i++) {
      final double y =
          top +
              chartHeight *
                  (i / 4);

      canvas.drawLine(
        Offset(
          left,
          y,
        ),
        Offset(
          size.width -
              right,
          y,
        ),
        gridPaint,
      );
    }

    final int count = math.max(
      sales.length,
      purchases.length,
    );

    if (count == 0) {
      return;
    }

    double xFor(
      int index,
    ) {
      if (count == 1) {
        return left +
            chartWidth / 2;
      }

      return left +
          chartWidth *
              (index /
                  (count - 1));
    }

    double yFor(
      double value,
    ) {
      final double normalized =
          (value / maxValue)
              .clamp(
        0.0,
        1.0,
      );

      return top +
          chartHeight *
              (1 -
                  normalized);
    }

    Path? buildPath(
      List<_MetricPoint> points,
    ) {
      if (points.isEmpty) {
        return null;
      }

      final Path path =
          Path();

      for (
        int index = 0;
        index < points.length;
        index++
      ) {
        final double x =
            xFor(index);

        final double y =
            yFor(
          points[index].value,
        );

        if (index == 0) {
          path.moveTo(
            x,
            y,
          );
        } else {
          path.lineTo(
            x,
            y,
          );
        }
      }

      return path;
    }

    final Path? salesPath =
        buildPath(
      sales,
    );

    final Path? purchasePath =
        buildPath(
      purchases,
    );

    if (salesPath != null) {
      canvas.drawPath(
        salesPath,
        salesPaint,
      );
    }

    if (purchasePath != null) {
      canvas.drawPath(
        purchasePath,
        purchasePaint,
      );
    }

    final TextPainter
        textPainter =
        TextPainter(
      textDirection:
          ui.TextDirection.ltr,
    );

    final int labelCount =
        math.max(
      sales.length,
      purchases.length,
    );

    for (
      int index = 0;
      index < labelCount;
      index++
    ) {
      final String label =
          index < sales.length
              ? sales[index].label
              : index < purchases.length
                  ? purchases[index]
                      .label
                  : '';

      textPainter.text =
          TextSpan(
        text: label,
        style:
            TextStyle(
          color:
              textColor.withValues(
            alpha: 0.70,
          ),
          fontSize: 10,
          fontWeight:
              FontWeight.w600,
        ),
      );

      textPainter.layout();

      final double x =
          xFor(index) -
              textPainter.width /
                  2;

      textPainter.paint(
        canvas,
        Offset(
          x,
          size.height -
              bottom +
              10,
        ),
      );
    }

    final List<double>
        gridValues = [
      maxValue,
      maxValue * 0.75,
      maxValue * 0.50,
      maxValue * 0.25,
      0,
    ];

    for (
      int index = 0;
      index < gridValues.length;
      index++
    ) {
      final double value =
          gridValues[index];

      textPainter.text =
          TextSpan(
        text:
            _formatCompact(
          value,
        ),
        style:
            TextStyle(
          color:
              textColor.withValues(
            alpha: 0.60,
          ),
          fontSize: 9,
          fontWeight:
              FontWeight.w600,
        ),
      );

      textPainter.layout();

      final double y =
          top +
              chartHeight *
                  (index / 4) -
              textPainter.height /
                  2;

      textPainter.paint(
        canvas,
        Offset(
          0,
          y,
        ),
      );
    }

    _drawLegend(
      canvas,
      size,
      textPainter,
    );
  }

  String _formatCompact(
    double value,
  ) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    }

    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    }

    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    }

    return '₹${value.toStringAsFixed(0)}';
  }

  void _drawLegend(
    Canvas canvas,
    Size size,
    TextPainter textPainter,
  ) {
    const double y = 2;

    final Paint salesLegend =
        Paint()
          ..color = salesColor
          ..strokeWidth = 3
          ..strokeCap =
              StrokeCap.round;

    final Paint purchaseLegend =
        Paint()
          ..color = purchaseColor
          ..strokeWidth = 3
          ..strokeCap =
              StrokeCap.round;

    canvas.drawLine(
      const Offset(
        58,
        y + 8,
      ),
      const Offset(
        76,
        y + 8,
      ),
      salesLegend,
    );

    textPainter.text =
        TextSpan(
      text: 'Sales',
      style:
          TextStyle(
        color:
            textColor,
        fontSize: 10,
        fontWeight:
            FontWeight.w700,
      ),
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      const Offset(
        81,
        y + 2,
      ),
    );

    canvas.drawLine(
      Offset(
        140,
        y + 8,
      ),
      Offset(
        158,
        y + 8,
      ),
      purchaseLegend,
    );

    textPainter.text =
        TextSpan(
      text: 'Purchase',
      style:
          TextStyle(
        color:
            textColor,
        fontSize: 10,
        fontWeight:
            FontWeight.w700,
      ),
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      const Offset(
        163,
        y + 2,
      ),
    );
  }

  @override
  bool shouldRepaint(
    covariant _TrendChartPainter oldDelegate,
  ) {
    return oldDelegate.sales !=
            sales ||
        oldDelegate.purchases !=
            purchases ||
        oldDelegate.maxValue !=
            maxValue ||
        oldDelegate.textColor !=
            textColor ||
        oldDelegate.gridColor !=
            gridColor;
  }
}
