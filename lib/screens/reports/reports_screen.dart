import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/expense_model.dart';
import '../../models/payment_model.dart';
import '../../models/product_model.dart';
import '../../models/purchase_model.dart';
import '../../models/sale_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/purchase_repository.dart';
import '../../repositories/sale_repository.dart';

import 'analytics_report_screen.dart';
import 'customer_report_screen.dart';
import 'expense_report_screen.dart';
import 'payment_report_screen.dart';
import 'profit_report_screen.dart';
import 'purchase_report_screen.dart';
import 'sales_report_screen.dart';
import 'stock_report_screen.dart';
import 'supplier_report_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
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

  final ProductRepository _productRepository =
      ProductRepository();

  final DateFormat _dateFormat =
      DateFormat('dd MMM yyyy');

  
  BusinessModel? _business;

  List<SaleModel> _sales = <SaleModel>[];
  List<PurchaseModel> _purchases =
      <PurchaseModel>[];
  List<ExpenseModel> _expenses =
      <ExpenseModel>[];
  List<PaymentModel> _payments =
      <PaymentModel>[];
  List<ProductModel> _products =
      <ProductModel>[];

  bool _isLoading = true;
  bool _isRefreshing = false;

  String? _errorMessage;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  Future<void> _initialize() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final BusinessModel? business =
          await _businessRepository
              .getBusinessForCurrentUser();

      if (!mounted) return;

      if (business == null) {
        setState(() {
          _business = null;
          _isLoading = false;
          _errorMessage =
              'Business profile not found. Please complete business setup.';
        });
        return;
      }

      final String businessId =
          business.id.trim();

      if (businessId.isEmpty) {
        setState(() {
          _business = business;
          _isLoading = false;
          _errorMessage =
              'Business ID is missing.';
        });
        return;
      }

      final List<dynamic> results =
          await Future.wait<dynamic>([
        _saleRepository.getSales(
          businessId: businessId,
        ),
        _purchaseRepository.getPurchases(
          businessId: businessId,
        ),
        _expenseRepository.getExpenses(
          businessId: businessId,
        ),
        _paymentRepository.getPayments(
          businessId: businessId,
        ),
        _productRepository.getProducts(
          businessId,
        ),
      ]);

      if (!mounted) return;

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
        _products =
            results[4] as List<ProductModel>;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load reports. Please try again.';
      });
    }
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<void> _refresh() async {
    if (_isRefreshing) return;

    if (!mounted) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final BusinessModel? business =
          await _businessRepository
              .getBusinessForCurrentUser();

      if (business == null) {
        throw Exception(
          'Business profile not found.',
        );
      }

      final String businessId =
          business.id.trim();

      if (businessId.isEmpty) {
        throw Exception(
          'Business ID is missing.',
        );
      }

      final List<dynamic> results =
          await Future.wait<dynamic>([
        _saleRepository.getSales(
          businessId: businessId,
        ),
        _purchaseRepository.getPurchases(
          businessId: businessId,
        ),
        _expenseRepository.getExpenses(
          businessId: businessId,
        ),
        _paymentRepository.getPayments(
          businessId: businessId,
        ),
        _productRepository.getProducts(
          businessId,
        ),
      ]);

      if (!mounted) return;

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
        _products =
            results[4] as List<ProductModel>;
        _errorMessage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Reports refreshed successfully.',
              ),
              behavior:
                  SnackBarBehavior.floating,
            ),
          );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to refresh reports.',
            ),
            behavior:
                SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // ===========================================================================
  // DATE RANGE
  // ===========================================================================

  Future<void> _selectDateRange() async {
    final DateTime now = DateTime.now();

    final DateTimeRange? selected =
        await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(
        now.year + 1,
        now.month,
        now.day,
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
      helpText: 'Select report period',
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
      );
    });
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  bool _isDateInRange(DateTime date) {
    if (_startDate == null &&
        _endDate == null) {
      return true;
    }

    if (_startDate != null &&
        date.isBefore(_startDate!)) {
      return false;
    }

    if (_endDate != null &&
        date.isAfter(_endDate!)) {
      return false;
    }

    return true;
  }

  List<SaleModel> get _filteredSales {
    return _sales
        .where(
          (sale) =>
              _isDateInRange(sale.date),
        )
        .toList();
  }

  List<PurchaseModel>
      get _filteredPurchases {
    return _purchases
        .where(
          (purchase) =>
              _isDateInRange(
            purchase.date,
          ),
        )
        .toList();
  }

  List<ExpenseModel> get _filteredExpenses {
    return _expenses
        .where(
          (expense) =>
              _isDateInRange(
            expense.date,
          ),
        )
        .toList();
  }

  List<PaymentModel> get _filteredPayments {
    return _payments
        .where(
          (payment) =>
              _isDateInRange(
            payment.date,
          ),
        )
        .toList();
  }

  // ===========================================================================
  // CALCULATIONS
  // ===========================================================================

  double get _totalSales {
    return _filteredSales.fold<double>(
      0,
      (sum, sale) =>
          sum + sale.total,
    );
  }

  double get _totalPurchases {
    return _filteredPurchases.fold<double>(
      0,
      (sum, purchase) =>
          sum + purchase.total,
    );
  }

  double get _totalExpenses {
    return _filteredExpenses.fold<double>(
      0,
      (sum, expense) =>
          sum + expense.amount,
    );
  }

  double get _totalPayments {
    return _filteredPayments.fold<double>(
      0,
      (sum, payment) =>
          sum + payment.amount,
    );
  }

  double get _grossProfit {
    double profit = 0;

    for (final SaleModel sale
        in _filteredSales) {
      for (final item in sale.items) {
        profit +=
            (item.sellingRate -
                    item.costPrice) *
                item.quantity;
      }
    }

    return profit;
  }

  double get _netProfit {
    return _grossProfit -
        _totalExpenses;
  }

  double get _profitMargin {
    if (_totalSales <= 0) {
      return 0;
    }

    return (_netProfit /
            _totalSales) *
        100;
  }

  double get _outstandingSales {
    double outstanding = 0;

    for (final SaleModel sale
        in _filteredSales) {
      final double balance =
          sale.total -
              sale.paidAmount;

      if (balance > 0) {
        outstanding += balance;
      }
    }

    return outstanding;
  }

  double get _stockValue {
    return _products.fold<double>(
      0,
      (sum, product) =>
          sum +
          (product.currentStock *
              product.purchasePrice),
    );
  }

  int get _lowStockCount {
    return _products.where(
      (product) =>
          product.isActive &&
          product.currentStock > 0 &&
          product.currentStock <=
              product.minimumStock,
    ).length;
  }

  int get _outOfStockCount {
    return _products.where(
      (product) =>
          product.isActive &&
          product.currentStock <= 0,
    ).length;
  }

  // ===========================================================================
  // REPORT NAVIGATION
  // ===========================================================================

  void _openSalesReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const SalesReportScreen(),
      ),
    );
  }

  void _openPurchaseReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const PurchaseReportScreen(),
      ),
    );
  }

  void _openExpenseReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ExpenseReportScreen(),
      ),
    );
  }

  void _openProfitReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ProfitReportScreen(),
      ),
    );
  }

  void _openPaymentReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const PaymentReportScreen(),
      ),
    );
  }

  void _openStockReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const StockReportScreen(),
      ),
    );
  }

  void _openCustomerReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CustomerReportScreen(),
      ),
    );
  }

  void _openSupplierReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const SupplierReportScreen(),
      ),
    );
  }

  void _openAnalyticsReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AnalyticsReportScreen(),
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor:
            theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Reports',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: const Center(
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
          title: const Text(
            'Reports',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: _buildErrorState(theme),
      );
    }

    if (_business == null) {
      return Scaffold(
        backgroundColor:
            theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Reports',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body:
            _buildEmptyBusinessState(
          theme,
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isRefreshing
                ? null
                : _refresh,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool isDesktop =
                constraints.maxWidth >=
                    1000;

            return SingleChildScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 28 : 16,
                20,
                isDesktop ? 28 : 16,
                40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 1250,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      _buildHeader(theme),
                      const SizedBox(
                        height: 20,
                      ),
                      _buildDateFilter(
                        theme,
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      _buildOverview(
                        theme,
                        isDesktop,
                      ),
                      const SizedBox(
                        height: 24,
                      ),
                      _buildReportCategories(
                        theme,
                      ),
                      const SizedBox(
                        height: 24,
                      ),
                      _buildQuickSummary(
                        theme,
                      ),
                      const SizedBox(
                        height: 24,
                      ),
                      _buildReportTips(
                        theme,
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

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(
    ThemeData theme,
  ) {
    final String businessName =
        _business?.businessName.trim() ??
            '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: 0.14,
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: const Icon(
              Icons.assessment_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Business Reports',
                  style: theme
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                    color:
                        Colors.white,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  businessName.isEmpty
                      ? 'Analyze your business performance'
                      : businessName,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    color: Colors.white
                        .withValues(
                      alpha: 0.88,
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

  // ===========================================================================
  // DATE FILTER
  // ===========================================================================

  Widget _buildDateFilter(
    ThemeData theme,
  ) {
    final bool hasDateRange =
        _startDate != null &&
            _endDate != null;

    String label =
        'All Dates';

    if (hasDateRange) {
      label =
          '${_dateFormat.format(_startDate!)} - '
          '${_dateFormat.format(_endDate!)}';
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool compact =
                constraints.maxWidth <
                    620;

            if (compact) {
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  _sectionTitle(
                    theme,
                    'Report Period',
                    label,
                    Icons.date_range_rounded,
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  FilledButton.icon(
                    onPressed:
                        _selectDateRange,
                    icon: const Icon(
                      Icons
                          .calendar_month_rounded,
                    ),
                    label: const Text(
                      'Select Date Range',
                    ),
                  ),
                  if (hasDateRange) ...[
                    const SizedBox(
                      height: 8,
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _clearDateRange,
                      icon: const Icon(
                        Icons
                            .clear_rounded,
                      ),
                      label: const Text(
                        'Clear Filter',
                      ),
                    ),
                  ],
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _sectionTitle(
                    theme,
                    'Report Period',
                    label,
                    Icons.date_range_rounded,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                FilledButton.icon(
                  onPressed:
                      _selectDateRange,
                  icon: const Icon(
                    Icons
                        .calendar_month_rounded,
                  ),
                  label: const Text(
                    'Select Date Range',
                  ),
                ),
                if (hasDateRange) ...[
                  const SizedBox(
                    width: 8,
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _clearDateRange,
                    icon: const Icon(
                      Icons.clear_rounded,
                    ),
                    label: const Text(
                      'Clear',
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // OVERVIEW
  // ===========================================================================

  Widget _buildOverview(
    ThemeData theme,
    bool isDesktop,
  ) {
    final List<_MetricItem> metrics =
        [
      _MetricItem(
        title: 'Total Sales',
        value: _currency(_totalSales),
        icon: Icons
            .point_of_sale_rounded,
        color: AppColors.success,
      ),
      _MetricItem(
        title: 'Total Purchases',
        value:
            _currency(_totalPurchases),
        icon: Icons
            .shopping_bag_rounded,
        color: AppColors.primary,
      ),
      _MetricItem(
        title: 'Expenses',
        value:
            _currency(_totalExpenses),
        icon: Icons
            .receipt_long_rounded,
        color: AppColors.warning,
      ),
      _MetricItem(
        title: 'Net Profit',
        value:
            _currency(_netProfit),
        icon: Icons
            .trending_up_rounded,
        color: _netProfit >= 0
            ? AppColors.success
            : AppColors.danger,
      ),
      _MetricItem(
        title: 'Received',
        value:
            _currency(_totalPayments),
        icon:
            Icons.payments_rounded,
        color: AppColors.info,
      ),
      _MetricItem(
        title: 'Outstanding',
        value:
            _currency(_outstandingSales),
        icon: Icons
            .pending_actions_rounded,
        color: AppColors.warning,
      ),
    ];

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          'Overview',
          'Financial performance for the selected period',
          Icons.insights_rounded,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final double width =
                constraints.maxWidth;

            int columns = 1;

            if (width >= 1100) {
              columns = 3;
            } else if (width >= 650) {
              columns = 2;
            }

            const double spacing =
                12;

            final double cardWidth =
                (width -
                        ((columns - 1) *
                            spacing)) /
                    columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children:
                  metrics.map(
                (metric) {
                  return SizedBox(
                    width: cardWidth,
                    child:
                        _metricCard(
                      theme,
                      metric,
                    ),
                  );
                },
              ).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _metricCard(
    ThemeData theme,
    _MetricItem metric,
  ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(
                color: metric.color
                    .withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Icon(
                metric.icon,
                color: metric.color,
                size: 24,
              ),
            ),
            const SizedBox(
              width: 13,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    metric.title,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: theme
                          .colorScheme
                          .onSurfaceVariant,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    metric.value,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style: theme
                        .textTheme
                        .titleMedium
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
      ),
    );
  }

  // ===========================================================================
  // REPORT CATEGORIES
  // ===========================================================================

  Widget _buildReportCategories(
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          'Detailed Reports',
          'Open the dedicated report for each business area',
          Icons.assessment_rounded,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final double width =
                constraints.maxWidth;

            int columns = 1;

            if (width >= 1050) {
              columns = 3;
            } else if (width >= 650) {
              columns = 2;
            }

            const double spacing =
                12;

            final double cardWidth =
                (width -
                        ((columns - 1) *
                            spacing)) /
                    columns;

            final List<_ReportItem>
                reports = [
              _ReportItem(
                title: 'Sales Report',
                description:
                    'Analyze sales, invoices, customers, collections and profit.',
                icon:
                    Icons.point_of_sale_rounded,
                color:
                    AppColors.success,
                onTap:
                    _openSalesReport,
              ),
              _ReportItem(
                title: 'Purchase Report',
                description:
                    'Track purchases, suppliers, spending and outstanding amounts.',
                icon:
                    Icons.shopping_bag_rounded,
                color:
                    AppColors.primary,
                onTap:
                    _openPurchaseReport,
              ),
              _ReportItem(
                title: 'Expense Report',
                description:
                    'Review business expenses, categories and payment methods.',
                icon:
                    Icons.receipt_long_rounded,
                color:
                    AppColors.warning,
                onTap:
                    _openExpenseReport,
              ),
              _ReportItem(
                title: 'Profit Report',
                description:
                    'Understand gross profit, expenses, net profit and margins.',
                icon:
                    Icons.bar_chart_rounded,
                color:
                    AppColors.secondary,
                onTap:
                    _openProfitReport,
              ),
              _ReportItem(
                title: 'Payment Report',
                description:
                    'Track received payments, methods and collection activity.',
                icon:
                    Icons.payments_rounded,
                color:
                    AppColors.info,
                onTap:
                    _openPaymentReport,
              ),
              _ReportItem(
                title: 'Stock Report',
                description:
                    'Review stock value, current quantity and low-stock items.',
                icon:
                    Icons.inventory_2_rounded,
                color:
                    AppColors.danger,
                onTap:
                    _openStockReport,
              ),
              _ReportItem(
                title: 'Customer Report',
                description:
                    'Analyze customer sales, received amount and outstanding balance.',
                icon:
                    Icons.people_alt_rounded,
                color:
                    const Color(0xFF0891B2),
                onTap:
                    _openCustomerReport,
              ),
              _ReportItem(
                title: 'Supplier Report',
                description:
                    'Review supplier purchases, payments and outstanding amounts.',
                icon:
                    Icons.local_shipping_rounded,
                color:
                    const Color(0xFFEA580C),
                onTap:
                    _openSupplierReport,
              ),
              _ReportItem(
                title: 'Analytics Report',
                description:
                    'Explore sales, purchases, expenses and payment trends with charts.',
                icon:
                    Icons.analytics_rounded,
                color:
                    const Color(0xFF7C3AED),
                onTap:
                    _openAnalyticsReport,
              ),
            ];

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children:
                  reports.map(
                (report) {
                  return SizedBox(
                    width: cardWidth,
                    child:
                        _reportCard(
                      theme,
                      report,
                    ),
                  );
                },
              ).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _reportCard(
    ThemeData theme,
    _ReportItem report,
  ) {
    return Card(
      elevation: 0,
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: report.onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration:
                    BoxDecoration(
                  color: report.color
                      .withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: Icon(
                  report.icon,
                  color: report.color,
                  size: 26,
                ),
              ),
              const SizedBox(
                width: 14,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      report.title,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: theme
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      report.description,
                      maxLines: 3,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Icon(
                Icons
                    .arrow_forward_ios_rounded,
                size: 15,
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // QUICK SUMMARY
  // ===========================================================================

  Widget _buildQuickSummary(
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          'Quick Summary',
          'Current business position',
          Icons.dashboard_customize_rounded,
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Column(
            children: [
              _summaryRow(
                theme,
                'Amount Received',
                _currency(
                  _totalPayments,
                ),
                Icons.payments_rounded,
                AppColors.success,
              ),
              const Divider(
                height: 1,
              ),
              _summaryRow(
                theme,
                'Outstanding',
                _currency(
                  _outstandingSales,
                ),
                Icons
                    .pending_actions_rounded,
                AppColors.warning,
              ),
              const Divider(
                height: 1,
              ),
              _summaryRow(
                theme,
                'Stock Value',
                _currency(
                  _stockValue,
                ),
                Icons
                    .inventory_2_rounded,
                AppColors.primary,
              ),
              const Divider(
                height: 1,
              ),
              _summaryRow(
                theme,
                'Low Stock Products',
                _lowStockCount
                    .toString(),
                Icons
                    .warning_amber_rounded,
                AppColors.warning,
              ),
              const Divider(
                height: 1,
              ),
              _summaryRow(
                theme,
                'Out of Stock',
                _outOfStockCount
                    .toString(),
                Icons
                    .remove_shopping_cart_rounded,
                AppColors.danger,
              ),
              const Divider(
                height: 1,
              ),
              _summaryRow(
                theme,
                'Profit Margin',
                '${_profitMargin.toStringAsFixed(1)}%',
                Icons
                    .percent_rounded,
                _profitMargin >= 0
                    ? AppColors.success
                    : AppColors.danger,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color: color.withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Text(
              title,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: theme
                .textTheme
                .bodyMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // REPORT TIPS
  // ===========================================================================

  Widget _buildReportTips(
    ThemeData theme,
  ) {
    return Card(
      elevation: 0,
      color: AppColors.primary
          .withValues(
        alpha: 0.06,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lightbulb_rounded,
              color:
                  AppColors.warning,
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    'Reporting Tip',
                    style: theme
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    'Use the date filter to review a specific period. '
                    'Detailed reports open separately so you can analyze '
                    'sales, purchases, expenses, payments, stock, customers '
                    'and suppliers in more detail.',
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // COMMON UI
  // ===========================================================================

  Widget _sectionTitle(
    ThemeData theme,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration:
              BoxDecoration(
            color: AppColors.primary
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
            color:
                AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(
          width: 11,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                title,
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: 2,
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow:
                    TextOverflow
                        .ellipsis,
                style: theme
                    .textTheme
                    .bodySmall,
              ),
            ],
          ),
        ),
      ],
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
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration:
                  BoxDecoration(
                color: AppColors
                    .danger
                    .withValues(
                  alpha: 0.10,
                ),
                shape:
                    BoxShape.circle,
              ),
              child: const Icon(
                Icons
                    .error_outline_rounded,
                color:
                    AppColors.danger,
                size: 38,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Unable to load reports',
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              _errorMessage ??
                  'Something went wrong.',
              textAlign:
                  TextAlign.center,
              style: theme
                  .textTheme
                  .bodyMedium,
            ),
            const SizedBox(
              height: 20,
            ),
            FilledButton.icon(
              onPressed:
                  _initialize,
              icon: const Icon(
                Icons
                    .refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPTY BUSINESS
  // ===========================================================================

  Widget _buildEmptyBusinessState(
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.business_outlined,
              size: 60,
              color:
                  AppColors.primary,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Business setup required',
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            const Text(
              'Complete your business profile before viewing reports.',
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FORMATTING
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
}

// =============================================================================
// METRIC ITEM
// =============================================================================

class _MetricItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

// =============================================================================
// REPORT ITEM
// =============================================================================

class _ReportItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReportItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
