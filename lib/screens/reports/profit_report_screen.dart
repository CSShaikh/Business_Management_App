import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:public_file_saver/public_file_saver.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/expense_model.dart';
import '../../models/sale_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/sale_repository.dart';

class ProfitReportScreen extends StatefulWidget {
  const ProfitReportScreen({
    super.key,
  });

  @override
  State<ProfitReportScreen> createState() =>
      _ProfitReportScreenState();
}

class _ProfitReportScreenState
    extends State<ProfitReportScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final SaleRepository _saleRepository =
      SaleRepository();

  final ExpenseRepository _expenseRepository =
      ExpenseRepository();

  final ProductRepository _productRepository =
      ProductRepository();

  final TextEditingController _searchController =
      TextEditingController();

  bool _loading = true;
  bool _refreshing = false;
  bool _downloadingPdf = false;

  BusinessModel? _business;
  String? _errorMessage;
  String _searchQuery = '';

  DateTime? _startDate;
  DateTime? _endDate;

  List<SaleModel> _allSales = <SaleModel>[];
  List<ExpenseModel> _allExpenses = <ExpenseModel>[];

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
  // LOAD REPORT
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
        _saleRepository.getSales(
          businessId: business.id,
        ),
        _expenseRepository.getExpenses(
          businessId: business.id,
        ),
        _productRepository.getProducts(
          business.id,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _business = business;
        _allSales =
            results[0] as List<SaleModel>;

        _allExpenses =
            results[1] as List<ExpenseModel>;

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
    final DateTime now = DateTime.now();

    final DateTimeRange? selected =
        await showDateRangePicker(
      context: context,
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
      helpText: 'Select Profit Report Period',
      saveText: 'Apply',
    );

    if (selected == null) return;

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

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
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
    final int difference = now.weekday - DateTime.monday;
    final DateTime start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: difference));
    _setDateRange(start, now);
  }

  void _setThisMonth() {
    final DateTime now = DateTime.now();
    _setDateRange(
      DateTime(now.year, now.month, 1),
      now,
    );
  }

  void _setLastMonth() {
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(now.year, now.month - 1, 1);
    final DateTime last = DateTime(now.year, now.month, 0);
    _setDateRange(first, last);
  }

  // ===========================================================================
  // FILTERED SALES
  // ===========================================================================

  List<SaleModel> get _filteredSales {
    final String query =
        _searchQuery.trim().toLowerCase();

    final List<SaleModel> result =
        _allSales.where((sale) {
      if (_startDate != null &&
          sale.date.isBefore(_startDate!)) {
        return false;
      }

      if (_endDate != null &&
          sale.date.isAfter(_endDate!)) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return sale.customerName
              .toLowerCase()
              .contains(query) ||
          sale.invoiceNumber
              .toLowerCase()
              .contains(query) ||
          sale.notes
              .toLowerCase()
              .contains(query) ||
          sale.items.any(
            (item) => item.productName
                .toLowerCase()
                .contains(query),
          );
    }).toList();

    result.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return result;
  }

  // ===========================================================================
  // FILTERED EXPENSES
  // ===========================================================================

  List<ExpenseModel> get _filteredExpenses {
    return _allExpenses.where((expense) {
      if (_startDate != null &&
          expense.date.isBefore(_startDate!)) {
        return false;
      }

      if (_endDate != null &&
          expense.date.isAfter(_endDate!)) {
        return false;
      }

      return true;
    }).toList();
  }

  // ===========================================================================
  // SALES CALCULATIONS
  // ===========================================================================

  double _totalSales(
    List<SaleModel> sales,
  ) {
    return sales.fold(
      0,
      (sum, sale) => sum + sale.total,
    );
  }

  double _totalCost(
    List<SaleModel> sales,
  ) {
    double total = 0;

    for (final sale in sales) {
      for (final item in sale.items) {
        total +=
            item.quantity * item.costPrice;
      }
    }

    return total;
  }

  double _grossProfit(
    List<SaleModel> sales,
  ) {
    double profit = 0;

    for (final sale in sales) {
      double saleCost = 0;

      for (final item in sale.items) {
        final double quantity = item.quantity.isFinite
            ? item.quantity
            : 0;

        final double costPrice =
            item.costPrice.isFinite
                ? item.costPrice
                : 0;

        saleCost += quantity * costPrice;
      }

      // Gross profit is based on the actual invoice total,
      // after sale-level discount/tax adjustments, less the
      // historical cost of the goods sold.
      profit += sale.total - saleCost;
    }

    return profit;
  }

  double _totalExpenses(
    List<ExpenseModel> expenses,
  ) {
    return expenses.fold(
      0,
      (sum, expense) =>
          sum + expense.amount,
    );
  }

  double _profitMargin(
    double netProfit,
    double sales,
  ) {
    if (sales <= 0) return 0;

    return (netProfit / sales) * 100;
  }

  double _grossMargin(
    double grossProfit,
    double sales,
  ) {
    if (sales <= 0) return 0;

    return (grossProfit / sales) * 100;
  }

  // ===========================================================================
  // PRODUCT-WISE PROFIT
  // ===========================================================================

  Map<String, _ProductProfitData>
      _productProfitData(
    List<SaleModel> sales,
  ) {
    final Map<String, _ProductProfitData>
        result =
        <String, _ProductProfitData>{};

    for (final sale in sales) {
      for (final item in sale.items) {
        final String productId =
            item.productId;

        final String productName =
            item.productName.trim().isEmpty
                ? 'Unknown Product'
                : item.productName;

        final double itemRevenue =
            item.quantity *
                item.sellingRate;

        final double cost =
            item.quantity *
                item.costPrice;

        // Sale-level discount/tax is stored on SaleModel
        // rather than on individual SaleItemModel records.
        // Allocate that adjustment proportionally so the
        // product-wise profit reconciles with invoice-level
        // gross profit.
        final double subtotal =
            sale.subtotal;

        final double saleAdjustment =
            sale.total - subtotal;

        final double allocatedAdjustment =
            subtotal > 0 &&
                    subtotal.isFinite
                ? saleAdjustment *
                    (itemRevenue / subtotal)
                : 0;

        final double revenue =
            itemRevenue +
                allocatedAdjustment;

        final double profit =
            revenue - cost;

        if (result.containsKey(productId)) {
          final _ProductProfitData old =
              result[productId]!;

          result[productId] =
              _ProductProfitData(
            productId: productId,
            productName: productName,
            quantity:
                old.quantity + item.quantity,
            revenue:
                old.revenue + revenue,
            cost:
                old.cost + cost,
            profit:
                old.profit + profit,
          );
        } else {
          result[productId] =
              _ProductProfitData(
            productId: productId,
            productName: productName,
            quantity: item.quantity,
            revenue: revenue,
            cost: cost,
            profit: profit,
          );
        }
      }
    }

    return result;
  }

  // ===========================================================================
  // CUSTOMER-WISE PROFIT
  // ===========================================================================

  Map<String, _CustomerProfitData>
      _customerProfitData(
    List<SaleModel> sales,
  ) {
    final Map<String, _CustomerProfitData>
        result =
        <String, _CustomerProfitData>{};

    for (final sale in sales) {
      double saleCost = 0;

      for (final item in sale.items) {
        saleCost +=
            item.quantity *
                item.costPrice;
      }

      final double profit =
          sale.total - saleCost;

      final String customerId =
          sale.customerId.trim();

      final String customerName =
          sale.customerName.trim().isEmpty
              ? 'Walk-in Customer'
              : sale.customerName;

      final String key = customerId.isEmpty
          ? customerName
          : customerId;

      if (result.containsKey(key)) {
        final _CustomerProfitData old =
            result[key]!;

        result[key] =
            _CustomerProfitData(
          customerName: customerName,
          sales:
              old.sales + sale.total,
          cost:
              old.cost + saleCost,
          profit:
              old.profit + profit,
          invoiceCount:
              old.invoiceCount + 1,
        );
      } else {
        result[key] =
            _CustomerProfitData(
          customerName: customerName,
          sales: sale.total,
          cost: saleCost,
          profit: profit,
          invoiceCount: 1,
        );
      }
    }

    return result;
  }

  // ===========================================================================
  // MONTHLY PROFIT
  // ===========================================================================

  Map<String, _MonthlyProfitData>
      _monthlyProfitData(
    List<SaleModel> sales,
    List<ExpenseModel> expenses,
  ) {
    final Map<String, _MonthlyProfitData>
        result =
        <String, _MonthlyProfitData>{};

    for (final sale in sales) {
      final String key =
          '${sale.date.year}-${sale.date.month.toString().padLeft(2, '0')}';

      double cost = 0;

      for (final item in sale.items) {
        cost +=
            item.quantity *
                item.costPrice;
      }

      final double gross =
          sale.total - cost;

      final _MonthlyProfitData old =
          result[key] ??
              _MonthlyProfitData(
                year: sale.date.year,
                month: sale.date.month,
              );

      result[key] =
          _MonthlyProfitData(
        year: sale.date.year,
        month: sale.date.month,
        sales:
            old.sales + sale.total,
        cost:
            old.cost + cost,
        grossProfit:
            old.grossProfit + gross,
        expenses:
            old.expenses,
      );
    }

    for (final expense in expenses) {
      final String key =
          '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';

      final _MonthlyProfitData old =
          result[key] ??
              _MonthlyProfitData(
                year: expense.date.year,
                month: expense.date.month,
              );

      result[key] =
          _MonthlyProfitData(
        year: expense.date.year,
        month: expense.date.month,
        sales: old.sales,
        cost: old.cost,
        grossProfit:
            old.grossProfit,
        expenses:
            old.expenses +
                expense.amount,
      );
    }

    return result;
  }

  // ===========================================================================
  // FORMATTING
  // ===========================================================================

  String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  String _number(double value) {
    return NumberFormat(
      '#,##0.##',
      'en_IN',
    ).format(value);
  }

  String _date(DateTime date) {
    return DateFormat(
      'dd MMM yyyy',
    ).format(date);
  }

  String _monthName(
    int year,
    int month,
  ) {
    return DateFormat(
      'MMM yyyy',
    ).format(
      DateTime(year, month),
    );
  }

  String _dateRangeText() {
    if (_startDate == null ||
        _endDate == null) {
      return 'Current Report Period';
    }

    return '${_date(_startDate!)} → ${_date(_endDate!)}';
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  Future<void> _downloadPdf() async {
    if (_downloadingPdf) return;

    setState(() => _downloadingPdf = true);

    try {
      final List<SaleModel> sales = _filteredSales;
      final List<ExpenseModel> expenses = _filteredExpenses;
      final double salesTotal = _totalSales(sales);
      final double costTotal = _totalCost(sales);
      final double grossProfit = _grossProfit(sales);
      final double expenseTotal = _totalExpenses(expenses);
      final double netProfit = grossProfit - expenseTotal;

      final List<_MonthlyProfitData> monthly =
          _monthlyProfitData(sales, expenses).values.toList()
            ..sort((a, b) => DateTime(a.year, a.month)
                .compareTo(DateTime(b.year, b.month)));
      final List<_ProductProfitData> products =
          _productProfitData(sales).values.toList()
            ..sort((a, b) => b.profit.compareTo(a.profit));
      final List<_CustomerProfitData> customers =
          _customerProfitData(sales).values.toList()
            ..sort((a, b) => b.profit.compareTo(a.profit));

      final pw.Document document = pw.Document();
      final String businessName =
          _business?.businessName.trim().isNotEmpty == true
              ? _business!.businessName.trim()
              : 'Business Management App';

      pw.Widget text(String value, {bool bold = false, double size = 9}) {
        return pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        );
      }

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              text(businessName, bold: true, size: 18),
              if ((_business?.businessType ?? '').trim().isNotEmpty)
                text(_business!.businessType.trim(), size: 9),
              if ((_business?.address ?? '').trim().isNotEmpty)
                text(_business!.address.trim(), size: 8),
              if ((_business?.mobile ?? '').trim().isNotEmpty ||
                  (_business?.email ?? '').trim().isNotEmpty)
                text(
                  '${_business?.mobile ?? ''}${(_business?.mobile ?? '').isNotEmpty && (_business?.email ?? '').isNotEmpty ? '  |  ' : ''}${_business?.email ?? ''}',
                  size: 8,
                ),
              if ((_business?.gstNumber ?? '').trim().isNotEmpty)
                text('GSTIN: ${_business!.gstNumber.trim()}', size: 8),
              pw.SizedBox(height: 8),
              pw.Divider(),
              text('Profit & Loss Report', bold: true, size: 15),
              text('Period: ${_dateRangeText()}', size: 9),
              pw.SizedBox(height: 10),
            ],
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: text('Page ${context.pageNumber}', size: 8),
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: const ['Metric', 'Amount'],
              data: [
                ['Total Sales', 'Rs. ${_pdfNumber(salesTotal)}'],
                ['Cost of Goods Sold', 'Rs. ${_pdfNumber(costTotal)}'],
                ['Gross Profit', 'Rs. ${_pdfNumber(grossProfit)}'],
                ['Operating Expenses', 'Rs. ${_pdfNumber(expenseTotal)}'],
                ['Net Profit', 'Rs. ${_pdfNumber(netProfit)}'],
                ['Net Margin', '${_pdfNumber(_profitMargin(netProfit, salesTotal))}%'],
              ],
            ),
            pw.SizedBox(height: 18),
            text('Monthly Profit', bold: true, size: 12),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const ['Month', 'Sales', 'Cost', 'Gross Profit', 'Expenses', 'Net Profit'],
              data: monthly.map((m) => [
                _monthName(m.year, m.month),
                'Rs. ${_pdfNumber(m.sales)}',
                'Rs. ${_pdfNumber(m.cost)}',
                'Rs. ${_pdfNumber(m.grossProfit)}',
                'Rs. ${_pdfNumber(m.expenses)}',
                'Rs. ${_pdfNumber(m.grossProfit - m.expenses)}',
              ]).toList(),
            ),
            pw.SizedBox(height: 18),
            text('Product-wise Profit', bold: true, size: 12),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const ['Product', 'Qty', 'Revenue', 'Cost', 'Profit'],
              data: products.map((p) => [
                p.productName,
                _pdfNumber(p.quantity),
                'Rs. ${_pdfNumber(p.revenue)}',
                'Rs. ${_pdfNumber(p.cost)}',
                'Rs. ${_pdfNumber(p.profit)}',
              ]).toList(),
            ),
            pw.SizedBox(height: 18),
            text('Customer-wise Profit', bold: true, size: 12),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const ['Customer', 'Invoices', 'Sales', 'Cost', 'Profit'],
              data: customers.map((c) => [
                c.customerName,
                c.invoiceCount.toString(),
                'Rs. ${_pdfNumber(c.sales)}',
                'Rs. ${_pdfNumber(c.cost)}',
                'Rs. ${_pdfNumber(c.profit)}',
              ]).toList(),
            ),
            pw.SizedBox(height: 18),
            text('Expense Impact', bold: true, size: 12),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Category', 'Amount', 'Payment'],
              data: expenses.map((e) => [
                _date(e.date),
                e.category,
                'Rs. ${_pdfNumber(e.amount)}',
                e.paymentMethod,
              ]).toList(),
            ),
          ],
        ),
      );

      final Uint8List bytes = Uint8List.fromList(await document.save());
      final String stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final PublicSavedFile? saved = await PublicFileSaver().saveBytes(
        bytes: bytes,
        fileName: 'profit_report_$stamp.pdf',
        mimeType: 'application/pdf',
        subDir: 'Business Management Reports',
      );

      if (!mounted) return;
      if (saved?.isSuccess == true) {
        _showMessage('Profit report PDF saved successfully.');
      } else {
        _showMessage('Unable to save the Profit report PDF.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('PDF download failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  String _pdfNumber(double value) => value.toStringAsFixed(2);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Profit Report'),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            onPressed: _downloadingPdf || _loading ? null : _downloadPdf,
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
            onPressed: _refreshing ? null : _refreshReport,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildProfitReportBody(context),
    );
  }

  Widget _buildProfitReportBody(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(theme);
    }

    final List<SaleModel> sales =
        _filteredSales;

    final List<ExpenseModel> expenses =
        _filteredExpenses;

    return RefreshIndicator(
      onRefresh: _refreshReport,
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final bool isDesktop =
              constraints.maxWidth >= 1000;

          final bool isTablet =
              constraints.maxWidth >= 650 &&
                  constraints.maxWidth < 1000;

          return SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding:
                EdgeInsets.symmetric(
              horizontal: isDesktop
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
                    const SizedBox(height: 20),
                    _buildDateFilter(theme),
                    const SizedBox(height: 20),
                    _buildSummary(
                      theme,
                      sales,
                      expenses,
                      isDesktop,
                    ),
                    const SizedBox(height: 20),
                    _buildSearch(theme),
                    const SizedBox(height: 20),
                    _buildMonthlySection(
                      theme,
                      sales,
                      expenses,
                    ),
                    const SizedBox(height: 20),
                    _buildProductProfitSection(
                      theme,
                      sales,
                    ),
                    const SizedBox(height: 20),
                    _buildCustomerProfitSection(
                      theme,
                      sales,
                    ),
                    const SizedBox(height: 20),
                    _buildSalesProfitSection(
                      theme,
                      sales,
                    ),
                    const SizedBox(height: 20),
                    _buildExpenseImpactSection(
                      theme,
                      expenses,
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isDesktop ? 26 : 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success,
            AppColors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.all(
          Radius.circular(22),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color:
                  Colors.white.withValues(
                alpha: 0.15,
              ),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profit Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Analyze sales profitability, product margins and operating expenses.',
                  style: TextStyle(
                    color:
                        Colors.white.withValues(
                      alpha: 0.82,
                    ),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white.withValues(
                      alpha: 0.14,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      30,
                    ),
                  ),
                  child: Text(
                    _dateRangeText(),
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
                        color:
                            Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color:
                          Colors.white,
                    ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DATE FILTER
  // ===========================================================================

  Widget _buildDateFilter(
    ThemeData theme,
  ) {
    final bool hasFilter =
        _startDate != null &&
            _endDate != null;

    return _ReportCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment:
            WrapCrossAlignment.center,
        children: [
          const Icon(
            Icons.date_range_rounded,
            size: 21,
          ),
          Text(
            'Report Period',
            style:
                theme.textTheme.titleMedium
                    ?.copyWith(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          ActionChip(
            label: const Text('Today'),
            onPressed: _setToday,
          ),
          ActionChip(
            label: const Text('This Week'),
            onPressed: _setThisWeek,
          ),
          ActionChip(
            label: const Text('This Month'),
            onPressed: _setThisMonth,
          ),
          ActionChip(
            label: const Text('Last Month'),
            onPressed: _setLastMonth,
          ),
          OutlinedButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(
              Icons.calendar_month_rounded,
            ),
            label: Text(
              hasFilter
                  ? '${_date(_startDate!)} - ${_date(_endDate!)}'
                  : 'Select Date Range',
            ),
          ),
          if (hasFilter)
            TextButton.icon(
              onPressed: _clearDateFilter,
              icon: const Icon(
                Icons.clear_rounded,
              ),
              label: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Widget _buildSearch(
    ThemeData theme,
  ) {
    return _ReportCard(
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration:
            InputDecoration(
          hintText:
              'Search customer, invoice or product...',
          prefixIcon:
              const Icon(
            Icons.search_rounded,
          ),
          suffixIcon:
              _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(
                        Icons.clear_rounded,
                      ),
                    ),
          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummary(
    ThemeData theme,
    List<SaleModel> sales,
    List<ExpenseModel> expenses,
    bool isDesktop,
  ) {
    final double salesAmount =
        _totalSales(sales);

    final double cost =
        _totalCost(sales);

    final double gross =
        _grossProfit(sales);

    final double expenseAmount =
        _totalExpenses(expenses);

    final double net =
        gross - expenseAmount;

    final double margin =
        _profitMargin(
      net,
      salesAmount,
    );

    final List<_SummaryItem> items = [
      _SummaryItem(
        title: 'Total Sales',
        value: _currency(salesAmount),
        subtitle:
            '${sales.length} invoice${sales.length == 1 ? '' : 's'}',
        icon:
            Icons.point_of_sale_rounded,
        color:
            AppColors.primary,
      ),
      _SummaryItem(
        title: 'Cost of Goods',
        value: _currency(cost),
        subtitle:
            'Historical sale cost',
        icon:
            Icons.inventory_2_rounded,
        color:
            AppColors.warning,
      ),
      _SummaryItem(
        title: 'Gross Profit',
        value: _currency(gross),
        subtitle:
            '${_grossMargin(gross, salesAmount).toStringAsFixed(1)}% gross margin',
        icon:
            Icons.show_chart_rounded,
        color:
            AppColors.success,
      ),
      _SummaryItem(
        title: 'Expenses',
        value:
            _currency(expenseAmount),
        subtitle:
            'Operating expenses',
        icon:
            Icons.receipt_long_rounded,
        color:
            AppColors.danger,
      ),
      _SummaryItem(
        title: 'Net Profit',
        value: _currency(net),
        subtitle:
            '${margin.toStringAsFixed(1)}% net margin',
        icon:
            Icons.trending_up_rounded,
        color: net >= 0
            ? AppColors.success
            : AppColors.danger,
      ),
      _SummaryItem(
        title: 'Profit / Invoice',
        value: _currency(
          sales.isEmpty
              ? 0
              : net / sales.length,
        ),
        subtitle:
            'Average net profit',
        icon:
            Icons.analytics_rounded,
        color:
            AppColors.secondary,
      ),
    ];

    if (isDesktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics:
            const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.9,
        ),
        itemBuilder:
            (context, index) {
          return _SummaryCard(
            item: items[index],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final int columns =
            constraints.maxWidth >= 650
                ? 2
                : 1;

        final double ratio =
            columns == 2 ? 2.0 : 2.5;

        return GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio:
                ratio,
          ),
          itemBuilder:
              (context, index) {
            return _SummaryCard(
              item: items[index],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // MONTHLY SECTION
  // ===========================================================================

  Widget _buildMonthlySection(
    ThemeData theme,
    List<SaleModel> sales,
    List<ExpenseModel> expenses,
  ) {
    final Map<String, _MonthlyProfitData>
        monthly =
        _monthlyProfitData(
      sales,
      expenses,
    );

    final List<_MonthlyProfitData>
        values =
        monthly.values.toList();

    values.sort(
      (a, b) {
        final DateTime aDate =
            DateTime(a.year, a.month);

        final DateTime bDate =
            DateTime(b.year, b.month);

        return bDate.compareTo(aDate);
      },
    );

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.calendar_view_month_rounded,
            title:
                'Monthly Profit Overview',
            subtitle:
                'Sales, cost, gross profit and expenses',
          ),
          const SizedBox(height: 18),
          if (values.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.bar_chart_rounded,
              message:
                  'No profit data available for the selected period.',
            )
          else
            ...values.take(12).map(
              (item) {
                final double net =
                    item.grossProfit -
                        item.expenses;

                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child:
                      _MonthlyProfitTile(
                    data: item,
                    month:
                        _monthName(
                      item.year,
                      item.month,
                    ),
                    netProfit: net,
                    currency:
                        _currency,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PRODUCT PROFIT
  // ===========================================================================

  Widget _buildProductProfitSection(
    ThemeData theme,
    List<SaleModel> sales,
  ) {
    final List<_ProductProfitData>
        products =
        _productProfitData(
      sales,
    ).values.toList();

    products.sort(
      (a, b) => b.profit.compareTo(
        a.profit,
      ),
    );

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.inventory_2_rounded,
            title:
                'Product-wise Profit',
            subtitle:
                'Revenue, cost and profit by product',
          ),
          const SizedBox(height: 18),
          if (products.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.inventory_2_outlined,
              message:
                  'No product profit data available.',
            )
          else
            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                if (constraints.maxWidth <
                    650) {
                  return Column(
                    children:
                        products.take(15).map(
                      (product) {
                        return Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            bottom: 10,
                          ),
                          child:
                              _ProductProfitTile(
                            data: product,
                            currency:
                                _currency,
                            number:
                                _number,
                          ),
                        );
                      },
                    ).toList(),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 28,
                    columns: const [
                      DataColumn(
                        label:
                            Text('Product'),
                      ),
                      DataColumn(
                        label:
                            Text('Quantity'),
                      ),
                      DataColumn(
                        label:
                            Text('Revenue'),
                      ),
                      DataColumn(
                        label:
                            Text('Cost'),
                      ),
                      DataColumn(
                        label:
                            Text('Profit'),
                      ),
                      DataColumn(
                        label:
                            Text('Margin'),
                      ),
                    ],
                    rows: products
                        .take(20)
                        .map(
                      (product) {
                        final double margin =
                            product.revenue <=
                                    0
                                ? 0
                                : (product.profit /
                                        product.revenue) *
                                    100;

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                product
                                    .productName,
                              ),
                            ),
                            DataCell(
                              Text(
                                _number(
                                  product
                                      .quantity,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _currency(
                                  product
                                      .revenue,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _currency(
                                  product
                                      .cost,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _currency(
                                  product
                                      .profit,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${margin.toStringAsFixed(1)}%',
                              ),
                            ),
                          ],
                        );
                      },
                    ).toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CUSTOMER PROFIT
  // ===========================================================================

  Widget _buildCustomerProfitSection(
    ThemeData theme,
    List<SaleModel> sales,
  ) {
    final List<_CustomerProfitData>
        customers =
        _customerProfitData(
      sales,
    ).values.toList();

    customers.sort(
      (a, b) => b.profit.compareTo(
        a.profit,
      ),
    );

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.people_alt_rounded,
            title:
                'Customer-wise Profit',
            subtitle:
                'Profit contribution by customer',
          ),
          const SizedBox(height: 18),
          if (customers.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.people_outline_rounded,
              message:
                  'No customer profit data available.',
            )
          else
            ...customers.take(15).map(
              (customer) {
                final double margin =
                    customer.sales <= 0
                        ? 0
                        : (customer.profit /
                                customer.sales) *
                            100;

                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child:
                      _CustomerProfitTile(
                    data: customer,
                    margin: margin,
                    currency:
                        _currency,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SALES PROFIT
  // ===========================================================================

  Widget _buildSalesProfitSection(
    ThemeData theme,
    List<SaleModel> sales,
  ) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.receipt_long_rounded,
            title:
                'Sale-wise Profit',
            subtitle:
                '${sales.length} matching sale${sales.length == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 18),
          if (sales.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.receipt_long_outlined,
              message:
                  'No sales found for the selected filters.',
            )
          else
            ...sales.take(50).map(
              (sale) {
                double cost = 0;

                for (final item
                    in sale.items) {
                  cost +=
                      item.quantity *
                          item.costPrice;
                }

                final double profit =
                    sale.total - cost;

                final double margin =
                    sale.total <= 0
                        ? 0
                        : (profit /
                                sale.total) *
                            100;

                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child:
                      _SaleProfitTile(
                    sale: sale,
                    cost: cost,
                    profit: profit,
                    margin: margin,
                    currency:
                        _currency,
                    date: _date,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EXPENSE IMPACT
  // ===========================================================================

  Widget _buildExpenseImpactSection(
    ThemeData theme,
    List<ExpenseModel> expenses,
  ) {
    final Map<String, double>
        categoryTotals =
        <String, double>{};

    for (final expense in expenses) {
      final String category =
          expense.category.trim().isEmpty
              ? 'Other'
              : expense.category.trim();

      categoryTotals[category] =
          (categoryTotals[category] ?? 0) +
              expense.amount;
    }

    final List<MapEntry<String, double>>
        categories =
        categoryTotals.entries.toList();

    categories.sort(
      (a, b) => b.value.compareTo(
        a.value,
      ),
    );

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.account_balance_wallet_rounded,
            title:
                'Expense Impact',
            subtitle:
                'Operating expenses reducing net profit',
          ),
          const SizedBox(height: 18),
          if (categories.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.receipt_long_outlined,
              message:
                  'No expenses found for the selected period.',
            )
          else
            ...categories.map(
              (entry) {
                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child:
                      _ExpenseCategoryTile(
                    category:
                        entry.key,
                    amount:
                        entry.value,
                    total:
                        _totalExpenses(
                      expenses,
                    ),
                    currency:
                        _currency,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================

  Widget _buildErrorState(
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: _ReportCard(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons
                    .error_outline_rounded,
                size: 52,
                color:
                    AppColors.danger,
              ),
              const SizedBox(height: 14),
              Text(
                'Unable to Load Profit Report',
                textAlign:
                    TextAlign.center,
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ??
                    'Something went wrong.',
                textAlign:
                    TextAlign.center,
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed:
                    _refreshReport,
                icon: const Icon(
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

// ============================================================================
// SUMMARY MODEL
// ============================================================================

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

// ============================================================================
// PRODUCT MODEL
// ============================================================================

class _ProductProfitData {
  final String productId;
  final String productName;
  final double quantity;
  final double revenue;
  final double cost;
  final double profit;

  const _ProductProfitData({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.revenue,
    required this.cost,
    required this.profit,
  });
}

// ============================================================================
// CUSTOMER MODEL
// ============================================================================

class _CustomerProfitData {
  final String customerName;
  final double sales;
  final double cost;
  final double profit;
  final int invoiceCount;

  const _CustomerProfitData({
    required this.customerName,
    required this.sales,
    required this.cost,
    required this.profit,
    required this.invoiceCount,
  });
}

// ============================================================================
// MONTHLY MODEL
// ============================================================================

class _MonthlyProfitData {
  final int year;
  final int month;
  final double sales;
  final double cost;
  final double grossProfit;
  final double expenses;

  const _MonthlyProfitData({
    required this.year,
    required this.month,
    this.sales = 0,
    this.cost = 0,
    this.grossProfit = 0,
    this.expenses = 0,
  });
}

// ============================================================================
// REPORT CARD
// ============================================================================

class _ReportCard extends StatelessWidget {
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
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: theme
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.04),
            blurRadius: 18,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================

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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme
                .colorScheme
                .primary
                .withValues(alpha: 0.10),
            borderRadius:
                BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color:
                theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SUMMARY CARD
// ============================================================================

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
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              item.color.withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration:
                BoxDecoration(
              color:
                  item.color.withValues(
                alpha: 0.11,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: Icon(
              item.icon,
              color: item.color,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
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
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w600,
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    fontSize: 10,
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
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

// ============================================================================
// MONTHLY TILE
// ============================================================================

class _MonthlyProfitTile
    extends StatelessWidget {
  final _MonthlyProfitData data;
  final String month;
  final double netProfit;
  final String Function(double) currency;

  const _MonthlyProfitTile({
    required this.data,
    required this.month,
    required this.netProfit,
    required this.currency,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  month,
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              Text(
                currency(netProfit),
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                  color: netProfit >= 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _MiniMetric(
                label: 'Sales',
                value:
                    currency(data.sales),
              ),
              _MiniMetric(
                label: 'Cost',
                value:
                    currency(data.cost),
              ),
              _MiniMetric(
                label: 'Gross',
                value:
                    currency(
                  data.grossProfit,
                ),
              ),
              _MiniMetric(
                label: 'Expenses',
                value:
                    currency(
                  data.expenses,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PRODUCT TILE
// ============================================================================

class _ProductProfitTile
    extends StatelessWidget {
  final _ProductProfitData data;
  final String Function(double) currency;
  final String Function(double) number;

  const _ProductProfitTile({
    required this.data,
    required this.currency,
    required this.number,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final double margin =
        data.revenue <= 0
            ? 0
            : (data.profit /
                    data.revenue) *
                100;

    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.productName,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                currency(data.profit),
                style: theme
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                  color: data.profit >= 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 7,
            children: [
              _MiniMetric(
                label: 'Qty',
                value:
                    number(data.quantity),
              ),
              _MiniMetric(
                label: 'Revenue',
                value:
                    currency(data.revenue),
              ),
              _MiniMetric(
                label: 'Cost',
                value:
                    currency(data.cost),
              ),
              _MiniMetric(
                label: 'Margin',
                value:
                    '${margin.toStringAsFixed(1)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOMER TILE
// ============================================================================

class _CustomerProfitTile
    extends StatelessWidget {
  final _CustomerProfitData data;
  final double margin;
  final String Function(double) currency;

  const _CustomerProfitTile({
    required this.data,
    required this.margin,
    required this.currency,
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
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color: theme
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.10),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              Icons.person_rounded,
              color:
                  theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  data.customerName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.invoiceCount} invoice${data.invoiceCount == 1 ? '' : 's'} • Margin ${margin.toStringAsFixed(1)}%',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            currency(data.profit),
            style: theme
                .textTheme
                .titleSmall
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
              color: data.profit >= 0
                  ? AppColors.success
                  : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SALE TILE
// ============================================================================

class _SaleProfitTile
    extends StatelessWidget {
  final SaleModel sale;
  final double cost;
  final double profit;
  final double margin;
  final String Function(double) currency;
  final String Function(DateTime) date;

  const _SaleProfitTile({
    required this.sale,
    required this.cost,
    required this.profit,
    required this.margin,
    required this.currency,
    required this.date,
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
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sale.invoiceNumber
                          .trim()
                          .isEmpty
                      ? 'Sale'
                      : sale.invoiceNumber,
                  style: theme
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              Text(
                currency(profit),
                style: theme
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                  color: profit >= 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            sale.customerName.trim().isEmpty
                ? 'Walk-in Customer'
                : sale.customerName,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: theme
                .textTheme
                .bodyMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date(sale.date),
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _MiniMetric(
                label: 'Sales',
                value:
                    currency(sale.total),
              ),
              _MiniMetric(
                label: 'Cost',
                value:
                    currency(cost),
              ),
              _MiniMetric(
                label: 'Margin',
                value:
                    '${margin.toStringAsFixed(1)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXPENSE TILE
// ============================================================================

class _ExpenseCategoryTile
    extends StatelessWidget {
  final String category;
  final double amount;
  final double total;
  final String Function(double) currency;

  const _ExpenseCategoryTile({
    required this.category,
    required this.amount,
    required this.total,
    required this.currency,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final double percentage =
        total <= 0
            ? 0
            : (amount / total) * 100;

    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category,
                  style: theme
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
              Text(
                currency(amount),
                style: theme
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            child:
                LinearProgressIndicator(
              value:
                  percentage.clamp(
                0,
                100,
              ) /
                      100,
              minHeight: 7,
              backgroundColor:
                  theme
                      .colorScheme
                      .outlineVariant
                      .withValues(
                    alpha: 0.35,
                  ),
              color:
                  AppColors.danger,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment:
                Alignment.centerRight,
            child: Text(
              '${percentage.toStringAsFixed(1)}% of total expenses',
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MINI METRIC
// ============================================================================

class _MiniMetric
    extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: theme
              .textTheme
              .bodySmall
              ?.copyWith(
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme
              .textTheme
              .bodySmall
              ?.copyWith(
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// EMPTY INLINE
// ============================================================================

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
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.25),
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 38,
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(height: 9),
          Text(
            message,
            textAlign:
                TextAlign.center,
            style: theme
                .textTheme
                .bodyMedium
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}