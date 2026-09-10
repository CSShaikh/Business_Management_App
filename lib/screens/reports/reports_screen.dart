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

  final DateFormat _shortDateFormat =
      DateFormat('dd MMM');

  BusinessModel? _business;

  List<SaleModel> _sales = [];
  List<PurchaseModel> _purchases = [];
  List<ExpenseModel> _expenses = [];
  List<PaymentModel> _payments = [];
  List<ProductModel> _products = [];

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

      _business = business;

      final String businessId =
          business.id.trim();

      if (businessId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Business ID is missing.';
        });
        return;
      }

      final results = await Future.wait([
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
        _sales = results[0] as List<SaleModel>;
        _purchases =
            results[1] as List<PurchaseModel>;
        _expenses =
            results[2] as List<ExpenseModel>;
        _payments =
            results[3] as List<PaymentModel>;
        _products =
            results[4] as List<ProductModel>;

        _isLoading = false;
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

      final results = await Future.wait([
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
        _sales = results[0] as List<SaleModel>;
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
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to refresh reports.',
          ),
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

    if (selected == null) {
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

  // ===========================================================================
  // DATE FILTER
  // ===========================================================================

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
    return _sales.where(
      (sale) {
        return _isDateInRange(sale.date);
      },
    ).toList();
  }

  List<PurchaseModel> get _filteredPurchases {
    return _purchases.where(
      (purchase) {
        return _isDateInRange(purchase.date);
      },
    ).toList();
  }

  List<ExpenseModel> get _filteredExpenses {
    return _expenses.where(
      (expense) {
        return _isDateInRange(expense.date);
      },
    ).toList();
  }

  List<PaymentModel> get _filteredPayments {
    return _payments.where(
      (payment) {
        return _isDateInRange(payment.date);
      },
    ).toList();
  }

  // ===========================================================================
  // CALCULATIONS
  // ===========================================================================

  double get _totalSales {
    return _filteredSales.fold(
      0,
      (sum, sale) => sum + sale.total,
    );
  }

  double get _totalPurchases {
    return _filteredPurchases.fold(
      0,
      (sum, purchase) => sum + purchase.total,
    );
  }

  double get _totalExpenses {
    return _filteredExpenses.fold(
      0,
      (sum, expense) => sum + expense.amount,
    );
  }

  double get _totalPayments {
    return _filteredPayments.fold(
      0,
      (sum, payment) => sum + payment.amount,
    );
  }

  double get _grossProfit {
    double profit = 0;

    for (final sale in _filteredSales) {
      for (final item in sale.items) {
        profit +=
            (item.sellingRate - item.costPrice) *
                item.quantity;
      }
    }

    return profit;
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

  double get _outstandingSales {
    double amount = 0;

    for (final sale in _filteredSales) {
      final double outstanding =
          sale.total - sale.paidAmount;

      if (outstanding > 0) {
        amount += outstanding;
      }
    }

    return amount;
  }

  double get _stockValue {
    return _products.fold(
      0,
      (sum, product) =>
          sum +
          (product.currentStock *
              product.purchasePrice),
    );
  }

  int get _lowStockCount {
    return _products.where(
      (product) {
        return product.currentStock <=
            product.minimumStock;
      },
    ).length;
  }

  int get _outOfStockCount {
    return _products.where(
      (product) {
        return product.currentStock <= 0;
      },
    ).length;
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void _openReport(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ReportDetailScreen(
          title: title,
          description: description,
          icon: icon,
          color: color,
          sales: _filteredSales,
          purchases: _filteredPurchases,
          expenses: _filteredExpenses,
          payments: _filteredPayments,
          products: _products,
        ),
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
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(theme);
    }

    if (_business == null) {
      return _buildEmptyBusinessState(theme);
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(theme),
          const SizedBox(height: 16),
          _buildDateFilter(theme),
          const SizedBox(height: 20),
          _buildFinancialOverview(theme),
          const SizedBox(height: 24),
          _buildReportCategories(theme),
          const SizedBox(height: 24),
          _buildBusinessHealth(theme),
          const SizedBox(height: 24),
          _buildQuickSummary(theme),
          const SizedBox(height: 24),
          _buildReportTips(theme),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.16,
              ),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _business?.businessName ??
                      'Business Reports',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Track your business performance',
                  style: TextStyle(
                    color:
                        Colors.white.withValues(
                      alpha: 0.82,
                    ),
                    fontSize: 13,
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

  Widget _buildDateFilter(ThemeData theme) {
    final bool hasDateFilter =
        _startDate != null ||
            _endDate != null;

    String label = 'All time';

    if (_startDate != null &&
        _endDate != null) {
      label =
          '${_shortDateFormat.format(_startDate!)} - '
          '${_shortDateFormat.format(_endDate!)}';
    } else if (_startDate != null) {
      label =
          'From ${_dateFormat.format(_startDate!)}';
    } else if (_endDate != null) {
      label =
          'Until ${_dateFormat.format(_endDate!)}';
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary
                    .withValues(alpha: 0.10),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.date_range_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report Period',
                    style: theme
                        .textTheme
                        .labelMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: theme
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
            if (hasDateFilter)
              IconButton(
                tooltip: 'Clear',
                onPressed: _clearDateRange,
                icon: const Icon(
                  Icons.close_rounded,
                ),
              ),
            FilledButton.icon(
              onPressed: _selectDateRange,
              icon: const Icon(
                Icons.calendar_month_rounded,
                size: 18,
              ),
              label: const Text('Select'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FINANCIAL OVERVIEW
  // ===========================================================================

  Widget _buildFinancialOverview(
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          'Financial Overview',
          'Your selected-period business numbers',
          Icons.account_balance_wallet_rounded,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final double width =
                constraints.maxWidth;

            int columns = 2;

            if (width >= 1100) {
              columns = 4;
            } else if (width >= 700) {
              columns = 3;
            }

            final double spacing = 12;
            final double cardWidth =
                (width -
                        ((columns - 1) *
                            spacing)) /
                    columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _metricCard(
                    title: 'Sales',
                    value: _currency(
                      _totalSales,
                    ),
                    icon:
                        Icons.trending_up_rounded,
                    color: AppColors.success,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _metricCard(
                    title: 'Purchases',
                    value: _currency(
                      _totalPurchases,
                    ),
                    icon:
                        Icons.shopping_cart_rounded,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _metricCard(
                    title: 'Expenses',
                    value: _currency(
                      _totalExpenses,
                    ),
                    icon:
                        Icons.receipt_long_rounded,
                    color: AppColors.warning,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _metricCard(
                    title: 'Net Profit',
                    value: _currency(
                      _netProfit,
                    ),
                    icon:
                        Icons.auto_graph_rounded,
                    color: _netProfit >= 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ],
            );
          },
        ),
      ],
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
          'Reports',
          'Open detailed reports for each business area',
          Icons.assessment_rounded,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final double width =
                constraints.maxWidth;

            int columns = 1;

            if (width >= 1000) {
              columns = 3;
            } else if (width >= 650) {
              columns = 2;
            }

            final double spacing = 12;

            final double cardWidth =
                (width -
                        ((columns - 1) *
                            spacing)) /
                    columns;

            final reports = [
              _ReportItem(
                title: 'Sales Report',
                description:
                    'Analyze sales, invoices, customers and collections.',
                icon:
                    Icons.point_of_sale_rounded,
                color: AppColors.success,
              ),
              _ReportItem(
                title: 'Purchase Report',
                description:
                    'Track purchases, suppliers and purchase spending.',
                icon:
                    Icons.shopping_bag_rounded,
                color: AppColors.primary,
              ),
              _ReportItem(
                title: 'Expense Report',
                description:
                    'Review business expenses and spending categories.',
                icon:
                    Icons.receipt_long_rounded,
                color: AppColors.warning,
              ),
              _ReportItem(
                title: 'Profit Report',
                description:
                    'Understand gross profit, expenses and net profit.',
                icon:
                    Icons.bar_chart_rounded,
                color: AppColors.secondary,
              ),
              _ReportItem(
                title: 'Payment Report',
                description:
                    'Track received payments and outstanding amounts.',
                icon:
                    Icons.payments_rounded,
                color: AppColors.info,
              ),
              _ReportItem(
                title: 'Stock Report',
                description:
                    'Review stock value, low stock and inventory position.',
                icon:
                    Icons.inventory_2_rounded,
                color: AppColors.danger,
              ),
            ];

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: reports.map(
                (report) {
                  return SizedBox(
                    width: cardWidth,
                    child: _reportCard(
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _openReport(
            report.title,
            report.description,
            report.icon,
            report.color,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: report.color
                      .withValues(alpha: 0.10),
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: Icon(
                  report.icon,
                  color: report.color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: theme
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      report.description,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
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
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color:
                    theme.colorScheme.onSurface
                        .withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BUSINESS HEALTH
  // ===========================================================================

  Widget _buildBusinessHealth(
    ThemeData theme,
  ) {
    final double collectionRate =
        _totalSales <= 0
            ? 0
            : (_totalPayments /
                    _totalSales) *
                100;

    final double expenseRatio =
        _totalSales <= 0
            ? 0
            : (_totalExpenses /
                    _totalSales) *
                100;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          'Business Health',
          'Key indicators for the selected period',
          Icons.favorite_rounded,
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _healthRow(
                  theme,
                  title: 'Profit Margin',
                  value:
                      '${_profitMargin.toStringAsFixed(1)}%',
                  progress:
                      (_profitMargin / 100)
                          .clamp(0.0, 1.0),
                  color: _profitMargin >= 0
                      ? AppColors.success
                      : AppColors.danger,
                  icon:
                      Icons.percent_rounded,
                ),
                const SizedBox(height: 18),
                _healthRow(
                  theme,
                  title: 'Collection Rate',
                  value:
                      '${collectionRate.toStringAsFixed(1)}%',
                  progress:
                      (collectionRate / 100)
                          .clamp(0.0, 1.0),
                  color: AppColors.info,
                  icon:
                      Icons.payments_outlined,
                ),
                const SizedBox(height: 18),
                _healthRow(
                  theme,
                  title: 'Expense Ratio',
                  value:
                      '${expenseRatio.toStringAsFixed(1)}%',
                  progress:
                      (expenseRatio / 100)
                          .clamp(0.0, 1.0),
                  color: expenseRatio > 50
                      ? AppColors.danger
                      : AppColors.warning,
                  icon:
                      Icons.money_off_rounded,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _healthRow(
    ThemeData theme, {
    required String title,
    required String value,
    required double progress,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: 0.10,
            ),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w700,
                          ),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(20),
                child:
                    LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor:
                      color.withValues(
                    alpha: 0.10,
                  ),
                  valueColor:
                      AlwaysStoppedAnimation<
                          Color>(
                    color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
                _currency(_totalPayments),
                Icons.payments_rounded,
                AppColors.success,
              ),
              const Divider(height: 1),
              _summaryRow(
                theme,
                'Outstanding',
                _currency(
                  _outstandingSales,
                ),
                Icons.pending_actions_rounded,
                AppColors.warning,
              ),
              const Divider(height: 1),
              _summaryRow(
                theme,
                'Stock Value',
                _currency(_stockValue),
                Icons.inventory_2_rounded,
                AppColors.primary,
              ),
              const Divider(height: 1),
              _summaryRow(
                theme,
                'Low Stock Products',
                _lowStockCount.toString(),
                Icons.warning_amber_rounded,
                AppColors.warning,
              ),
              const Divider(height: 1),
              _summaryRow(
                theme,
                'Out of Stock',
                _outOfStockCount.toString(),
                Icons.remove_shopping_cart_rounded,
                AppColors.danger,
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
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
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
      color: AppColors.primary.withValues(
        alpha: 0.06,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lightbulb_rounded,
              color: AppColors.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
                  const SizedBox(height: 5),
                  Text(
                    'Use the date filter to compare a specific period. '
                    'Detailed sales, purchase, expense, payment and stock '
                    'reports will use the same selected period.',
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
          decoration: BoxDecoration(
            color: AppColors.primary
                .withValues(alpha: 0.10),
            borderRadius:
                BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
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
              const SizedBox(height: 2),
              Text(
                subtitle,
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

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 21,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.danger
                    .withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Something went wrong.',
              textAlign: TextAlign.center,
              style: theme
                  .textTheme
                  .bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _initialize,
              icon: const Icon(
                Icons.refresh_rounded,
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

  Widget _buildEmptyBusinessState(
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.business_outlined,
              size: 60,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 8),
            const Text(
              'Complete your business profile before viewing reports.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
}

// =============================================================================
// REPORT ITEM
// =============================================================================

class _ReportItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _ReportItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// =============================================================================
// REPORT DETAIL SCREEN
// =============================================================================

class _ReportDetailScreen extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  final List<SaleModel> sales;
  final List<PurchaseModel> purchases;
  final List<ExpenseModel> expenses;
  final List<PaymentModel> payments;
  final List<ProductModel> products;

  const _ReportDetailScreen({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.sales,
    required this.purchases,
    required this.expenses,
    required this.payments,
    required this.products,
  });

  double get totalSales {
    return sales.fold(
      0,
      (sum, sale) => sum + sale.total,
    );
  }

  double get totalPurchases {
    return purchases.fold(
      0,
      (sum, purchase) => sum + purchase.total,
    );
  }

  double get totalExpenses {
    return expenses.fold(
      0,
      (sum, expense) => sum + expense.amount,
    );
  }

  double get totalPayments {
    return payments.fold(
      0,
      (sum, payment) => sum + payment.amount,
    );
  }

  double get grossProfit {
    double profit = 0;

    for (final sale in sales) {
      for (final item in sale.items) {
        profit +=
            (item.sellingRate - item.costPrice) *
                item.quantity;
      }
    }

    return profit;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(theme),
          const SizedBox(height: 20),
          _buildSummary(theme),
          const SizedBox(height: 20),
          _buildInformation(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: color,
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(ThemeData theme) {
    final List<_DetailMetric> metrics =
        [
      _DetailMetric(
        'Sales',
        totalSales,
        Icons.point_of_sale_rounded,
        AppColors.success,
      ),
      _DetailMetric(
        'Purchases',
        totalPurchases,
        Icons.shopping_cart_rounded,
        AppColors.primary,
      ),
      _DetailMetric(
        'Expenses',
        totalExpenses,
        Icons.receipt_long_rounded,
        AppColors.warning,
      ),
      _DetailMetric(
        'Payments',
        totalPayments,
        Icons.payments_rounded,
        AppColors.info,
      ),
      _DetailMetric(
        'Gross Profit',
        grossProfit,
        Icons.auto_graph_rounded,
        grossProfit >= 0
            ? AppColors.success
            : AppColors.danger,
      ),
    ];

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Summary',
          style: theme
              .textTheme
              .titleMedium
              ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        ...metrics.map(
          (metric) {
            return Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              child: Card(
                elevation: 0,
                child: ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration:
                        BoxDecoration(
                      color:
                          metric.color
                              .withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(12),
                    ),
                    child: Icon(
                      metric.icon,
                      color:
                          metric.color,
                    ),
                  ),
                  title: Text(
                    metric.title,
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  trailing: Text(
                    _currency(
                      metric.value,
                    ),
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInformation(
    ThemeData theme,
  ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Report Data',
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            _infoRow(
              theme,
              'Sales Transactions',
              sales.length.toString(),
            ),
            _infoRow(
              theme,
              'Purchase Transactions',
              purchases.length.toString(),
            ),
            _infoRow(
              theme,
              'Expense Transactions',
              expenses.length.toString(),
            ),
            _infoRow(
              theme,
              'Payment Transactions',
              payments.length.toString(),
            ),
            _infoRow(
              theme,
              'Products',
              products.length.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    ThemeData theme,
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme
                  .textTheme
                  .bodyMedium,
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

  String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }
}

// =============================================================================
// DETAIL METRIC
// =============================================================================

class _DetailMetric {
  final String title;
  final double value;
  final IconData icon;
  final Color color;

  const _DetailMetric(
    this.title,
    this.value,
    this.icon,
    this.color,
  );
}

