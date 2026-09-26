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
import 'stock_report_screen.dart';
import 'supplier_report_screen.dart';
import 'purchase_report_screen.dart';
import 'sales_report_screen.dart';
import '../../core/widgets/app_responsive_page.dart';
import '../../core/widgets/app_metric_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final BusinessRepository _businessRepository = BusinessRepository();

  final SaleRepository _saleRepository = SaleRepository();

  final PurchaseRepository _purchaseRepository = PurchaseRepository();

  final ExpenseRepository _expenseRepository = ExpenseRepository();

  final PaymentRepository _paymentRepository = PaymentRepository();

  final ProductRepository _productRepository = ProductRepository();

  BusinessModel? _business;

  List<SaleModel> _sales = <SaleModel>[];
  List<PurchaseModel> _purchases = <PurchaseModel>[];
  List<ExpenseModel> _expenses = <ExpenseModel>[];
  List<PaymentModel> _payments = <PaymentModel>[];
  List<ProductModel> _products = <ProductModel>[];

  bool _isLoading = true;
  bool _isRefreshing = false;

  String? _errorMessage;

  String _selectedPeriod = 'Today';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  Future<void> _initialize() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final BusinessModel? business = await _businessRepository
          .getBusinessForCurrentUser();

      if (!mounted) {
        return;
      }

      if (business == null) {
        setState(() {
          _business = null;
          _isLoading = false;
          _errorMessage =
              'Business profile not found. Please complete business setup.';
        });
        return;
      }

      final String businessId = business.id.trim();

      if (businessId.isEmpty) {
        setState(() {
          _business = business;
          _isLoading = false;
          _errorMessage = 'Business ID is missing.';
        });
        return;
      }

      final List<dynamic> results = await Future.wait<dynamic>([
        _saleRepository.getSales(businessId: businessId),
        _purchaseRepository.getPurchases(businessId: businessId),
        _expenseRepository.getExpenses(businessId: businessId),
        _paymentRepository.getPayments(businessId: businessId),
        _productRepository.getProducts(businessId),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _business = business;
        _sales = results[0] as List<SaleModel>;
        _purchases = results[1] as List<PurchaseModel>;
        _expenses = results[2] as List<ExpenseModel>;
        _payments = results[3] as List<PaymentModel>;
        _products = results[4] as List<ProductModel>;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load reports. Please try again.';
      });
    }
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<void> _refresh() async {
    if (_isRefreshing || !mounted) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      final BusinessModel? business = await _businessRepository
          .getBusinessForCurrentUser();

      if (business == null) {
        throw Exception('Business profile not found.');
      }

      final String businessId = business.id.trim();

      if (businessId.isEmpty) {
        throw Exception('Business ID is missing.');
      }

      final List<dynamic> results = await Future.wait<dynamic>([
        _saleRepository.getSales(businessId: businessId),
        _purchaseRepository.getPurchases(businessId: businessId),
        _expenseRepository.getExpenses(businessId: businessId),
        _paymentRepository.getPayments(businessId: businessId),
        _productRepository.getProducts(businessId),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _business = business;
        _sales = results[0] as List<SaleModel>;
        _purchases = results[1] as List<PurchaseModel>;
        _expenses = results[2] as List<ExpenseModel>;
        _payments = results[3] as List<PaymentModel>;
        _products = results[4] as List<ProductModel>;
        _errorMessage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Reports refreshed successfully.'),
              behavior: SnackBarBehavior.fixed,
            ),
          );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to refresh reports. Please try again.';
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to refresh reports.'),
            behavior: SnackBarBehavior.fixed,
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

  DateTime _periodStart() {
    final DateTime now = DateTime.now();
    if (_selectedPeriod == 'Weekly') {
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
    }
    if (_selectedPeriod == 'Monthly') {
      return DateTime(now.year, now.month, 1);
    }
    return DateTime(now.year, now.month, now.day);
  }

  bool _inSelectedPeriod(DateTime date) {
    final DateTime start = _periodStart();
    final DateTime end = DateTime.now();
    final DateTime local = date.toLocal();
    return !local.isBefore(start) &&
        local.isBefore(end.add(const Duration(days: 1)));
  }

  List<SaleModel> get _periodSales => _sales
      .where((item) => _inSelectedPeriod(item.date))
      .toList(growable: false);
  List<PurchaseModel> get _periodPurchases => _purchases
      .where((item) => _inSelectedPeriod(item.date))
      .toList(growable: false);
  List<ExpenseModel> get _periodExpenses => _expenses
      .where((item) => _inSelectedPeriod(item.date))
      .toList(growable: false);
  List<PaymentModel> get _periodPayments => _payments
      .where((item) => _inSelectedPeriod(item.date))
      .toList(growable: false);

  void _selectPeriod(String period) {
    if (_selectedPeriod == period) return;
    setState(() => _selectedPeriod = period);
  }

  // ===========================================================================
  // CALCULATIONS
  // ===========================================================================

  double get _totalSales {
    return _periodSales.fold<double>(0, (sum, sale) => sum + sale.total);
  }

  double get _totalPurchases {
    return _periodPurchases.fold<double>(
      0,
      (sum, purchase) => sum + purchase.total,
    );
  }

  double get _totalExpenses {
    return _periodExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
  }

  /// Total customer receipts across the available sales/payment records.
  ///
  /// Customer money can be recorded in two places:
  /// 1. paidAmount on the sale itself.
  /// 2. Separate PaymentModel transactions.
  ///
  /// Both are intentionally included here.
  double get _totalPayments {
    final double salePayments = _periodSales.fold<double>(
      0,
      (sum, sale) => sum + sale.paidAmount,
    );

    final double separatePayments = _periodPayments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );

    return salePayments + separatePayments;
  }

  double _saleCost(SaleModel sale) {
    return sale.items.fold<double>(
      0,
      (sum, item) => sum + (item.costPrice * item.quantity),
    );
  }

  /// Gross profit is based on the actual invoice total
  /// minus the actual cost of goods sold.
  double get _grossProfit {
    return _periodSales.fold<double>(
      0,
      (sum, sale) => sum + (sale.total - _saleCost(sale)),
    );
  }

  double get _netProfit {
    return _grossProfit - _totalExpenses;
  }

  double get _profitMargin {
    if (_totalSales <= 0) {
      return 0;
    }

    return (_netProfit / _totalSales) * 100;
  }

  /// Current customer outstanding based on available
  /// sales and payment records.
  double get _outstandingSales {
    final double outstanding = _totalSales - _totalPayments;

    return outstanding > 0 ? outstanding : 0;
  }

  double get _stockValue {
    return _products.fold<double>(
      0,
      (sum, product) => sum + (product.currentStock * product.purchasePrice),
    );
  }

  int get _lowStockCount {
    return _products
        .where(
          (product) =>
              product.isActive &&
              product.currentStock > 0 &&
              product.currentStock <= product.minimumStock,
        )
        .length;
  }

  int get _outOfStockCount {
    return _products
        .where((product) => product.isActive && product.currentStock <= 0)
        .length;
  }

  // ===========================================================================
  // REPORT NAVIGATION
  // ===========================================================================

  void _openSalesReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SalesReportScreen()),
    );
  }

  void _openPurchaseReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PurchaseReportScreen()),
    );
  }

  void _openExpenseReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExpenseReportScreen()),
    );
  }

  void _openProfitReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfitReportScreen()),
    );
  }

  void _openPaymentReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentReportScreen()),
    );
  }

  void _openStockReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StockReportScreen()),
    );
  }

  void _openCustomerReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerReportScreen()),
    );
  }

  void _openSupplierReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SupplierReportScreen()),
    );
  }

  void _openAnalyticsReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnalyticsReportScreen()),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Reports')),
        body: AppResponsivePage(
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Reports')),
        body: AppResponsivePage(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 54,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _initialize,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final Size size = MediaQuery.sizeOf(context);

    final bool isDesktop = size.width >= 1000;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh reports',
            onPressed: _isRefreshing ? null : _refresh,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AppResponsivePage(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxWidth = isDesktop ? 1250 : 1000;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(theme, isDesktop),
                        const SizedBox(height: 14),
                        _buildPeriodSelector(theme),
                        const SizedBox(height: 18),
                        _buildOverview(theme, isDesktop),
                        const SizedBox(height: 22),
                        _buildQuickSummary(theme),
                        const SizedBox(height: 18),
                        _buildPeriodDetails(theme),
                        const SizedBox(height: 22),
                        _buildReportGrid(theme),
                        const SizedBox(height: 22),
                        _buildInventorySnapshot(theme),
                        const SizedBox(height: 22),
                        _buildReportTips(theme),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final List<String> periods = const ['Today', 'Weekly', 'Monthly'];
            return Row(
              children: periods.map((period) {
                final bool selected = _selectedPeriod == period;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilledButton.tonal(
                      onPressed: () => _selectPeriod(period),
                      style: FilledButton.styleFrom(
                        backgroundColor: selected
                            ? theme.colorScheme.primary
                            : null,
                        foregroundColor: selected
                            ? theme.colorScheme.onPrimary
                            : null,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text(period),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(ThemeData theme, bool isDesktop) {
    final String businessName =
        _business?.businessName.trim().isNotEmpty == true
        ? _business!.businessName.trim()
        : 'Business';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.assessment_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business Reports',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  businessName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Monitor sales, purchases, expenses, '
                  'profit, collections, stock, customers '
                  'and suppliers from one place.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
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
  // OVERVIEW
  // ===========================================================================

  Widget _buildOverview(ThemeData theme, bool isDesktop) {
    final List<_MetricItem> metrics = [
      _MetricItem(
        title: 'Total Sales',
        value: _currency(_totalSales),
        icon: Icons.point_of_sale_rounded,
        color: AppColors.success,
      ),
      _MetricItem(
        title: 'Total Purchases',
        value: _currency(_totalPurchases),
        icon: Icons.shopping_bag_rounded,
        color: AppColors.primary,
      ),
      _MetricItem(
        title: 'Expenses',
        value: _currency(_totalExpenses),
        icon: Icons.receipt_long_rounded,
        color: AppColors.warning,
      ),
      _MetricItem(
        title: 'Net Profit',
        value: _currency(_netProfit),
        icon: Icons.trending_up_rounded,
        color: _netProfit >= 0 ? AppColors.success : AppColors.danger,
      ),
      _MetricItem(
        title: 'Received',
        value: _currency(_totalPayments),
        icon: Icons.payments_rounded,
        color: AppColors.info,
      ),
      _MetricItem(
        title: 'Outstanding',
        value: _currency(_outstandingSales),
        icon: Icons.pending_actions_rounded,
        color: AppColors.warning,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          'Overview',
          '$_selectedPeriod business performance',
          Icons.dashboard_rounded,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;

            int columns = width < 360 ? 1 : 2;
            if (width >= 1050) columns = 3;

            const double spacing = 12;

            final double cardWidth =
                (width - ((columns - 1) * spacing)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: metrics.map((metric) {
                return SizedBox(
                  width: cardWidth,
                  child: _metricCard(theme, metric),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _metricCard(ThemeData theme, _MetricItem metric) {
    return AppMetricCard(
      title: metric.title,
      value: metric.value,
      subtitle: _selectedPeriod,
      icon: metric.icon,
      color: metric.color,
    );
  }

  // ===========================================================================
  // QUICK SUMMARY
  // ===========================================================================

  Widget _buildQuickSummary(ThemeData theme) {
    final List<_MetricItem> metrics = [
      _MetricItem(
        title: 'Amount Received',
        value: _currency(_totalPayments),
        icon: Icons.payments_rounded,
        color: AppColors.success,
      ),
      _MetricItem(
        title: 'Outstanding',
        value: _currency(_outstandingSales),
        icon: Icons.pending_actions_rounded,
        color: AppColors.warning,
      ),
      _MetricItem(
        title: 'Gross Profit',
        value: _currency(_grossProfit),
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.secondary,
      ),
      _MetricItem(
        title: 'Profit Margin',
        value: '${_profitMargin.toStringAsFixed(1)}%',
        icon: Icons.percent_rounded,
        color: AppColors.info,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          'Quick Summary',
          '$_selectedPeriod business position',
          Icons.dashboard_customize_rounded,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final int columns = constraints.maxWidth < 360 ? 1 : 2;
            const double gap = 10;
            final double width =
                (constraints.maxWidth - (gap * (columns - 1))) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: metrics
                  .map(
                    (metric) => SizedBox(
                      width: width,
                      child: _metricCard(theme, metric),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPeriodDetails(ThemeData theme) {
    final List<_PeriodDetail> details = [
      _PeriodDetail(
        'Sales',
        _periodSales.length,
        _currency(_totalSales),
        Icons.point_of_sale_rounded,
        AppColors.success,
      ),
      _PeriodDetail(
        'Purchases',
        _periodPurchases.length,
        _currency(_totalPurchases),
        Icons.shopping_bag_rounded,
        AppColors.primary,
      ),
      _PeriodDetail(
        'Expenses',
        _periodExpenses.length,
        _currency(_totalExpenses),
        Icons.receipt_long_rounded,
        AppColors.warning,
      ),
      _PeriodDetail(
        'Received',
        _periodPayments.length,
        _currency(_totalPayments),
        Icons.payments_rounded,
        AppColors.info,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          '$_selectedPeriod Details',
          'Complete transaction totals for the selected period',
          Icons.view_column_rounded,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final int columns = constraints.maxWidth < 360
                ? 1
                : (constraints.maxWidth >= 900 ? 4 : 2);
            const double gap = 10;
            final double width =
                (constraints.maxWidth - (gap * (columns - 1))) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: details
                  .map(
                    (item) => SizedBox(
                      width: width,
                      child: AppMetricCard(
                        title: item.title,
                        value: item.amount,
                        subtitle: '${item.count} transactions',
                        icon: item.icon,
                        color: item.color,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // REPORT GRID
  // ===========================================================================

  Widget _buildReportGrid(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          'Detailed Reports',
          'Open a dedicated report for deeper analysis',
          Icons.assessment_rounded,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;

            int columns = width < 360 ? 1 : 2;
            if (width >= 1050) columns = 3;

            const double spacing = 12;

            final double cardWidth =
                (width - ((columns - 1) * spacing)) / columns;

            final List<_ReportItem> reports = [
              _ReportItem(
                title: 'Sales Report',
                description: 'Analyze sales, invoices, customers, collections and profit.',
                icon: Icons.point_of_sale_rounded,
                color: AppColors.success,
                onTap: _openSalesReport,
              ),
              _ReportItem(
                title: 'Purchase Report',
                description: 'Track purchases, suppliers, spending and outstanding amounts.',
                icon: Icons.shopping_bag_rounded,
                color: AppColors.primary,
                onTap: _openPurchaseReport,
              ),
              _ReportItem(
                title: 'Expense Report',
                description:
                    'Review business expenses, categories and payment methods.',
                icon: Icons.receipt_long_rounded,
                color: AppColors.warning,
                onTap: _openExpenseReport,
              ),
              _ReportItem(
                title: 'Profit Report',
                description: 'Understand gross profit, expenses, net profit and margins.',
                icon: Icons.bar_chart_rounded,
                color: AppColors.secondary,
                onTap: _openProfitReport,
              ),
              _ReportItem(
                title: 'Payment Report',
                description:
                    'Track received payments, methods and collection activity.',
                icon: Icons.payments_rounded,
                color: AppColors.info,
                onTap: _openPaymentReport,
              ),
              _ReportItem(
                title: 'Stock Report',
                description:
                    'Review stock value, current quantity and low-stock items.',
                icon: Icons.inventory_2_rounded,
                color: AppColors.danger,
                onTap: _openStockReport,
              ),
              _ReportItem(
                title: 'Customer Report',
                description: 'Analyze customer sales, received amount and outstanding balance.',
                icon: Icons.people_alt_rounded,
                color: const Color(0xFF0891B2),
                onTap: _openCustomerReport,
              ),
              _ReportItem(
                title: 'Supplier Report',
                description: 'Review supplier purchases, payments and outstanding amounts.',
                icon: Icons.local_shipping_rounded,
                color: const Color(0xFFEA580C),
                onTap: _openSupplierReport,
              ),
              _ReportItem(
                title: 'Analytics Report',
                description: 'Explore sales, purchases, expenses and payment trends with charts.',
                icon: Icons.analytics_rounded,
                color: const Color(0xFF7C3AED),
                onTap: _openAnalyticsReport,
              ),
            ];

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: reports.map((report) {
                return SizedBox(
                  width: cardWidth,
                  child: _reportCard(theme, report),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _reportCard(ThemeData theme, _ReportItem report) {
    return AppMetricCard(
      title: report.title,
      value: 'Open Report',
      subtitle: report.description,
      icon: report.icon,
      color: report.color,
      onTap: report.onTap,
    );
  }

  // ===========================================================================
  // INVENTORY SNAPSHOT
  // ===========================================================================

  Widget _buildInventorySnapshot(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          'Inventory Snapshot',
          'Current stock position',
          Icons.inventory_2_rounded,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;

            int columns = width < 360 ? 1 : 2;

            if (width >= 900) {
              columns = 3;
            }

            const double spacing = 12;

            final double cardWidth =
                (width - ((columns - 1) * spacing)) / columns;

            final List<_MetricItem> inventoryMetrics = [
              _MetricItem(
                title: 'Stock Value',
                value: _currency(_stockValue),
                icon: Icons.inventory_rounded,
                color: AppColors.primary,
              ),
              _MetricItem(
                title: 'Low Stock',
                value: _lowStockCount.toString(),
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
              ),
              _MetricItem(
                title: 'Out of Stock',
                value: _outOfStockCount.toString(),
                icon: Icons.remove_shopping_cart_rounded,
                color: AppColors.danger,
              ),
            ];

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: inventoryMetrics.map((metric) {
                return SizedBox(
                  width: cardWidth,
                  child: _metricCard(theme, metric),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // REPORT TIPS
  // ===========================================================================

  Widget _buildReportTips(ThemeData theme) {
    return Card(
      elevation: 0,
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reporting Tip',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Use the Detailed Reports section to open a '
                    'dedicated report. Each report provides its own '
                    'filters and reporting period so you can analyze '
                    'sales, purchases, expenses, payments, stock, '
                    'customers and suppliers in more detail.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }
}

// =============================================================================
// DATA CLASSES
// =============================================================================

class _PeriodDetail {
  final String title;
  final int count;
  final String amount;
  final IconData icon;
  final Color color;
  const _PeriodDetail(
    this.title,
    this.count,
    this.amount,
    this.icon,
    this.color,
  );
}

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
