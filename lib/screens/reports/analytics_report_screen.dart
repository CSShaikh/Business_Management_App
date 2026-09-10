import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  String? _errorMessage;

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
    ).subtract(
      const Duration(days: 6),
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

      final results = await Future.wait([
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

      if (!mounted) return;

      setState(() {
        _sales = results[0] as List<SaleModel>;
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
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _refreshAnalytics() async {
    await _loadAnalytics(
      showLoader: false,
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? selected =
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

  void _setPeriod(_AnalyticsPeriod period) {
    setState(() {
      _period = period;
    });
  }

  List<SaleModel> get _filteredSales {
    return _sales.where((sale) {
      return _isDateInRange(sale.date);
    }).toList();
  }

  List<PurchaseModel> get _filteredPurchases {
    return _purchases.where((purchase) {
      return _isDateInRange(purchase.date);
    }).toList();
  }

  List<ExpenseModel> get _filteredExpenses {
    return _expenses.where((expense) {
      return _isDateInRange(expense.date);
    }).toList();
  }

  List<PaymentModel> get _filteredPayments {
    return _payments.where((payment) {
      return _isDateInRange(payment.date);
    }).toList();
  }

  bool _isDateInRange(DateTime date) {
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
    double total = 0;

    for (final SaleModel sale
        in _filteredSales) {
      for (final item in sale.items) {
        total +=
            (item.sellingRate -
                    item.costPrice) *
                item.quantity;
      }
    }

    return total;
  }

  double get _netProfit {
    return _grossProfit - _totalExpenses;
  }

  double get _outstanding {
    double total = 0;

    for (final SaleModel sale
        in _filteredSales) {
      final double amount =
          sale.total - sale.paidAmount;

      if (amount > 0) {
        total += amount;
      }
    }

    return total;
  }

  double get _collectionRate {
    if (_totalSales <= 0) {
      return 0;
    }

    return (_totalPayments / _totalSales) * 100;
  }

  double get _profitMargin {
    if (_totalSales <= 0) {
      return 0;
    }

    return (_netProfit / _totalSales) * 100;
  }

  List<_ChartPoint> get _salesChart {
    return _buildChart(
      (date) {
        double value = 0;

        for (final sale in _filteredSales) {
          if (_sameBucket(
            sale.date,
            date,
          )) {
            value += sale.total;
          }
        }

        return value;
      },
    );
  }

  List<_ChartPoint> get _purchaseChart {
    return _buildChart(
      (date) {
        double value = 0;

        for (final purchase
            in _filteredPurchases) {
          if (_sameBucket(
            purchase.date,
            date,
          )) {
            value += purchase.total;
          }
        }

        return value;
      },
    );
  }

  List<_ChartPoint> get _expenseChart {
    return _buildChart(
      (date) {
        double value = 0;

        for (final expense
            in _filteredExpenses) {
          if (_sameBucket(
            expense.date,
            date,
          )) {
            value += expense.amount;
          }
        }

        return value;
      },
    );
  }

  List<_ChartPoint> get _paymentChart {
    return _buildChart(
      (date) {
        double value = 0;

        for (final payment
            in _filteredPayments) {
          if (_sameBucket(
            payment.date,
            date,
          )) {
            value += payment.amount;
          }
        }

        return value;
      },
    );
  }

  List<_ChartPoint> _buildChart(
    double Function(DateTime) valueBuilder,
  ) {
    if (_startDate == null ||
        _endDate == null) {
      return <_ChartPoint>[];
    }

    final List<_ChartPoint> points =
        <_ChartPoint>[];

    if (_period == _AnalyticsPeriod.daily) {
      DateTime current = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      );

      final DateTime end = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
      );

      while (!current.isAfter(end)) {
        points.add(
          _ChartPoint(
            date: current,
            value: valueBuilder(current),
          ),
        );

        current = current.add(
          const Duration(days: 1),
        );
      }
    } else if (_period ==
        _AnalyticsPeriod.weekly) {
      DateTime current = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      );

      while (!current.isAfter(
        _endDate!,
      )) {
        points.add(
          _ChartPoint(
            date: current,
            value: valueBuilder(current),
          ),
        );

        current = current.add(
          const Duration(days: 7),
        );
      }
    } else {
      DateTime current = DateTime(
        _startDate!.year,
        _startDate!.month,
        1,
      );

      final DateTime end = DateTime(
        _endDate!.year,
        _endDate!.month,
        1,
      );

      while (!current.isAfter(end)) {
        points.add(
          _ChartPoint(
            date: current,
            value: valueBuilder(current),
          ),
        );

        current = DateTime(
          current.year,
          current.month + 1,
          1,
        );
      }
    }

    return points;
  }

  bool _sameBucket(
    DateTime date,
    DateTime bucket,
  ) {
    if (_period == _AnalyticsPeriod.daily) {
      return date.year == bucket.year &&
          date.month == bucket.month &&
          date.day == bucket.day;
    }

    if (_period == _AnalyticsPeriod.weekly) {
      final DateTime start = DateTime(
        bucket.year,
        bucket.month,
        bucket.day,
      );

      final DateTime end = start.add(
        const Duration(days: 7),
      );

      return !date.isBefore(start) &&
          date.isBefore(end);
    }

    return date.year == bucket.year &&
        date.month == bucket.month;
  }

  String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(value);
  }

  String _shortCurrency(double value) {
    if (value.abs() >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    }

    if (value.abs() >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    }

    if (value.abs() >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    }

    return '₹${value.toStringAsFixed(0)}';
  }

  String _date(DateTime value) {
    return DateFormat(
      'dd MMM yyyy',
    ).format(value);
  }

  String _chartDate(DateTime value) {
    if (_period == _AnalyticsPeriod.monthly) {
      return DateFormat(
        'MMM yy',
      ).format(value);
    }

    return DateFormat(
      'dd MMM',
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(theme);
    }

    return RefreshIndicator(
      onRefresh: _refreshAnalytics,
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final bool isDesktop =
              constraints.maxWidth >= 1050;

          final bool isTablet =
              constraints.maxWidth >= 650 &&
                  constraints.maxWidth < 1050;

          return SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
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
                    _buildSummaryCards(
                      isDesktop,
                    ),
                    const SizedBox(height: 20),
                    _buildPeriodAndDateFilter(
                      theme,
                    ),
                    const SizedBox(height: 20),
                    _buildPerformanceChart(
                      theme,
                    ),
                    const SizedBox(height: 20),
                    _buildFinancialCharts(
                      theme,
                      isDesktop,
                    ),
                    const SizedBox(height: 20),
                    _buildProfitAnalysis(
                      theme,
                    ),
                    const SizedBox(height: 20),
                    _buildBusinessInsights(
                      theme,
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
            AppColors.primary,
            AppColors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(
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
              Icons.analytics_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analytics & Insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Visualise sales, purchases, expenses, collections and profitability.',
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
                _headerDateBadge(),
              ],
            ),
          ),
          if (isDesktop)
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isRefreshing
                  ? null
                  : _refreshAnalytics,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                    ),
            ),
        ],
      ),
    );
  }

  Widget _headerDateBadge() {
    final String text =
        _startDate != null &&
                _endDate != null
            ? '${_date(_startDate!)} - ${_date(_endDate!)}'
            : 'All dates';

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.14,
        ),
        borderRadius:
            BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSummaryCards(
    bool isDesktop,
  ) {
    final List<_AnalyticsSummary> cards = [
      _AnalyticsSummary(
        title: 'Sales',
        value: _currency(_totalSales),
        subtitle:
            '${_filteredSales.length} invoices',
        icon: Icons.point_of_sale_rounded,
        color: AppColors.primary,
      ),
      _AnalyticsSummary(
        title: 'Purchases',
        value:
            _currency(_totalPurchases),
        subtitle:
            '${_filteredPurchases.length} purchases',
        icon:
            Icons.shopping_cart_rounded,
        color: AppColors.secondary,
      ),
      _AnalyticsSummary(
        title: 'Net Profit',
        value: _currency(_netProfit),
        subtitle:
            '${_profitMargin.toStringAsFixed(1)}% margin',
        icon: Icons.trending_up_rounded,
        color: _netProfit >= 0
            ? AppColors.success
            : AppColors.danger,
      ),
      _AnalyticsSummary(
        title: 'Collected',
        value:
            _currency(_totalPayments),
        subtitle:
            '${_collectionRate.toStringAsFixed(1)}% collection',
        icon: Icons.payments_rounded,
        color: AppColors.info,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            isDesktop ? 4 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio:
            isDesktop ? 1.9 : 1.5,
      ),
      itemBuilder: (
        context,
        index,
      ) {
        return _AnalyticsSummaryCard(
          data: cards[index],
        );
      },
    );
  }

  Widget _buildPeriodAndDateFilter(
    ThemeData theme,
  ) {
    return _AnalyticsCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics Filters',
            style: theme
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _periodChip(
                'Daily',
                _AnalyticsPeriod.daily,
              ),
              _periodChip(
                'Weekly',
                _AnalyticsPeriod.weekly,
              ),
              _periodChip(
                'Monthly',
                _AnalyticsPeriod.monthly,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed:
                    _selectDateRange,
                icon: const Icon(
                  Icons.date_range_rounded,
                ),
                label: Text(
                  _startDate != null &&
                          _endDate != null
                      ? '${_date(_startDate!)} - ${_date(_endDate!)}'
                      : 'Select Date Range',
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _setDefaultDateRange();
                  });
                },
                icon: const Icon(
                  Icons.restart_alt_rounded,
                ),
                label:
                    const Text('Last 7 Days'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodChip(
    String label,
    _AnalyticsPeriod period,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: _period == period,
      onSelected: (_) {
        _setPeriod(period);
      },
    );
  }

  Widget _buildPerformanceChart(
    ThemeData theme,
  ) {
    final List<_ChartPoint> points =
        _salesChart;

    return _AnalyticsCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _AnalyticsSectionHeader(
            icon: Icons.show_chart_rounded,
            title: 'Sales Performance',
            subtitle:
                'Sales trend for the selected period',
          ),
          const SizedBox(height: 20),
          if (_hasChartData(points))
            _LineChart(
              points: points,
              lineColor: AppColors.primary,
              fillColor:
                  AppColors.primary.withValues(
                alpha: 0.08,
              ),
              labelBuilder: _chartDate,
              valueFormatter:
                  _shortCurrency,
              height: 280,
            )
          else
            const _ChartEmptyState(
              message:
                  'No sales data available for this period.',
            ),
        ],
      ),
    );
  }

  Widget _buildFinancialCharts(
    ThemeData theme,
    bool isDesktop,
  ) {
    final Widget purchaseChart =
        _buildMiniChartCard(
      title: 'Purchase Trend',
      subtitle: 'Purchase amount',
      icon: Icons.shopping_cart_rounded,
      color: AppColors.secondary,
      points: _purchaseChart,
    );

    final Widget expenseChart =
        _buildMiniChartCard(
      title: 'Expense Trend',
      subtitle: 'Expense amount',
      icon: Icons.money_off_rounded,
      color: AppColors.warning,
      points: _expenseChart,
    );

    final Widget paymentChart =
        _buildMiniChartCard(
      title: 'Collection Trend',
      subtitle: 'Payments received',
      icon: Icons.payments_rounded,
      color: AppColors.success,
      points: _paymentChart,
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: purchaseChart,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: expenseChart,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: paymentChart,
          ),
        ],
      );
    }

    return Column(
      children: [
        purchaseChart,
        const SizedBox(height: 14),
        expenseChart,
        const SizedBox(height: 14),
        paymentChart,
      ],
    );
  }

  Widget _buildMiniChartCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<_ChartPoint> points,
  }) {
    return _AnalyticsCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(
                  color: color.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 21,
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
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_hasChartData(points))
            _LineChart(
              points: points,
              lineColor: color,
              fillColor:
                  color.withValues(
                alpha: 0.08,
              ),
              labelBuilder: _chartDate,
              valueFormatter:
                  _shortCurrency,
              height: 190,
              compact: true,
            )
          else
            const _ChartEmptyState(
              message: 'No data.',
              compact: true,
            ),
        ],
      ),
    );
  }

  Widget _buildProfitAnalysis(
    ThemeData theme,
  ) {
    return _AnalyticsCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _AnalyticsSectionHeader(
            icon: Icons.account_balance_rounded,
            title: 'Profit Analysis',
            subtitle:
                'Understand gross profit, expenses and net profit',
          ),
          const SizedBox(height: 20),
          _ProfitRow(
            label: 'Total Sales',
            value: _currency(_totalSales),
            color: AppColors.primary,
          ),
          _ProfitRow(
            label: 'Gross Profit',
            value: _currency(_grossProfit),
            color: AppColors.success,
          ),
          _ProfitRow(
            label: 'Expenses',
            value: _currency(_totalExpenses),
            color: AppColors.warning,
          ),
          const Divider(height: 24),
          _ProfitRow(
            label: 'Net Profit',
            value: _currency(_netProfit),
            color: _netProfit >= 0
                ? AppColors.success
                : AppColors.danger,
            isBold: true,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SmallStat(
                  title: 'Margin',
                  value:
                      '${_profitMargin.toStringAsFixed(1)}%',
                  icon:
                      Icons.percent_rounded,
                  color:
                      _profitMargin >= 0
                          ? AppColors.success
                          : AppColors.danger,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallStat(
                  title: 'Outstanding',
                  value:
                      _currency(_outstanding),
                  icon:
                      Icons.pending_actions_rounded,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallStat(
                  title: 'Collection',
                  value:
                      '${_collectionRate.toStringAsFixed(1)}%',
                  icon:
                      Icons.task_alt_rounded,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessInsights(
    ThemeData theme,
  ) {
    final List<_Insight> insights =
        _generateInsights();

    return _AnalyticsCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _AnalyticsSectionHeader(
            icon: Icons.lightbulb_rounded,
            title: 'Business Insights',
            subtitle:
                'Quick observations from your current data',
          ),
          const SizedBox(height: 16),
          if (insights.isEmpty)
            const _ChartEmptyState(
              message:
                  'Not enough data to generate insights.',
            )
          else
            ...insights.map(
              (insight) => _InsightTile(
                insight: insight,
              ),
            ),
        ],
      ),
    );
  }

  List<_Insight> _generateInsights() {
    final List<_Insight> insights =
        <_Insight>[];

    if (_totalSales > 0) {
      if (_profitMargin >= 20) {
        insights.add(
          const _Insight(
            title: 'Healthy profit margin',
            description:
                'Your current net profit margin is above 20%.',
            icon:
                Icons.trending_up_rounded,
            color: AppColors.success,
          ),
        );
      } else if (_profitMargin >= 0) {
        insights.add(
          const _Insight(
            title: 'Profit can improve',
            description:
                'Sales are profitable, but there is room to improve your margin.',
            icon:
                Icons.trending_flat_rounded,
            color: AppColors.warning,
          ),
        );
      } else {
        insights.add(
          const _Insight(
            title: 'Negative net profit',
            description:
                'Expenses are currently higher than your gross profit.',
            icon:
                Icons.trending_down_rounded,
            color: AppColors.danger,
          ),
        );
      }
    }

    if (_outstanding > 0) {
      insights.add(
        _Insight(
          title: 'Outstanding payments',
          description:
              '${_currency(_outstanding)} is still outstanding from sales.',
          icon:
              Icons.pending_actions_rounded,
          color: AppColors.warning,
        ),
      );
    }

    if (_totalPurchases > _totalSales &&
        _totalPurchases > 0) {
      insights.add(
        const _Insight(
          title: 'Purchases are high',
          description:
              'Purchase value is currently higher than sales value for this period.',
          icon:
              Icons.shopping_cart_rounded,
          color: AppColors.secondary,
        ),
      );
    }

    if (_totalPayments > 0 &&
        _collectionRate >= 80) {
      insights.add(
        const _Insight(
          title: 'Strong collections',
          description:
              'Most of the sales value is being collected.',
          icon:
              Icons.payments_rounded,
          color: AppColors.success,
        ),
      );
    }

    if (_totalExpenses > _grossProfit &&
        _grossProfit > 0) {
      insights.add(
        const _Insight(
          title: 'Review expenses',
          description:
              'Current expenses are consuming more than the gross profit generated.',
          icon:
              Icons.warning_rounded,
          color: AppColors.danger,
        ),
      );
    }

    return insights;
  }

  bool _hasChartData(
    List<_ChartPoint> points,
  ) {
    return points.any(
      (point) => point.value > 0,
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
              Container(
                width: 64,
                height: 64,
                decoration:
                    BoxDecoration(
                  color: AppColors.danger
                      .withValues(
                    alpha: 0.10,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color:
                      AppColors.danger,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load Analytics',
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
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed:
                    () => _loadAnalytics(),
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label:
                    const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DATA CLASSES
// =============================================================================

class _ChartPoint {
  final DateTime date;
  final double value;

  const _ChartPoint({
    required this.date,
    required this.value,
  });
}

class _AnalyticsSummary {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _AnalyticsSummary({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _Insight {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _Insight({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// =============================================================================
// SUMMARY CARD
// =============================================================================

class _AnalyticsSummaryCard
    extends StatelessWidget {
  final _AnalyticsSummary data;

  const _AnalyticsSummaryCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: data.color.withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(
                  color:
                      data.color.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  data.icon,
                  color: data.color,
                  size: 21,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_outward_rounded,
                color:
                    data.color.withValues(
                  alpha: 0.60,
                ),
                size: 18,
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.title,
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
          const SizedBox(height: 3),
          Text(
            data.value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: theme
                .textTheme
                .titleLarge
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.subtitle,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              color: data.color,
              fontSize: 11,
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
// CARD
// =============================================================================

class _AnalyticsCard
    extends StatelessWidget {
  final Widget child;

  const _AnalyticsCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: theme
              .colorScheme
              .outlineVariant
              .withValues(
            alpha: 0.55,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha:
                  theme.brightness ==
                          Brightness.dark
                      ? 0.08
                      : 0.035,
            ),
            blurRadius: 16,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// =============================================================================
// SECTION HEADER
// =============================================================================

class _AnalyticsSectionHeader
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AnalyticsSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration:
              BoxDecoration(
            color: theme
                .colorScheme
                .primary
                .withValues(
              alpha: 0.10,
            ),
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
          child: Icon(
            icon,
            color:
                theme.colorScheme.primary,
            size: 22,
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

// =============================================================================
// LINE CHART
// =============================================================================

class _LineChart
    extends StatelessWidget {
  final List<_ChartPoint> points;
  final Color lineColor;
  final Color fillColor;
  final String Function(DateTime) labelBuilder;
  final String Function(double) valueFormatter;
  final double height;
  final bool compact;

  const _LineChart({
    required this.points,
    required this.lineColor,
    required this.fillColor,
    required this.labelBuilder,
    required this.valueFormatter,
    required this.height,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    final double maxValue = points.fold(
      0,
      (max, point) =>
          math.max(max, point.value),
    );

    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineChartPainter(
              points: points,
              maxValue:
                  maxValue <= 0
                      ? 1
                      : maxValue,
              lineColor: lineColor,
              fillColor: fillColor,
              gridColor: theme
                  .colorScheme
                  .outlineVariant
                  .withValues(
                alpha: 0.35,
              ),
              textColor: theme
                  .colorScheme
                  .onSurfaceVariant,
              valueFormatter:
                  valueFormatter,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ChartLabels(
          points: points,
          labelBuilder: labelBuilder,
          compact: compact,
        ),
      ],
    );
  }
}

class _LineChartPainter
    extends CustomPainter {
  final List<_ChartPoint> points;
  final double maxValue;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color textColor;
  final String Function(double) valueFormatter;

  _LineChartPainter({
    required this.points,
    required this.maxValue,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.textColor,
    required this.valueFormatter,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (points.isEmpty) return;

    const double left = 55;
    const double right = 14;
    const double top = 14;
    const double bottom = 18;

    final double chartWidth =
        math.max(
      1,
      size.width - left - right,
    );

    final double chartHeight =
        math.max(
      1,
      size.height - top - bottom,
    );

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final TextPainter textPainter =
        TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    for (int i = 0; i <= 4; i++) {
      final double y =
          top +
              chartHeight -
              (chartHeight * i / 4);

      canvas.drawLine(
        Offset(left, y),
        Offset(
          left + chartWidth,
          y,
        ),
        gridPaint,
      );

      final double value =
          maxValue * i / 4;

      textPainter.text =
          TextSpan(
        text: valueFormatter(value),
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight:
              FontWeight.w500,
        ),
      );

      textPainter.layout(
        maxWidth: left - 7,
      );

      textPainter.paint(
        canvas,
        Offset(
          left -
              textPainter.width -
              7,
          y -
              textPainter.height /
                  2,
        ),
      );
    }

    final Path linePath = Path();
    final Path fillPath = Path();

    final List<Offset> offsets =
        <Offset>[];

    for (int i = 0;
        i < points.length;
        i++) {
      final double x =
          points.length == 1
              ? left +
                  chartWidth / 2
              : left +
                  chartWidth *
                      i /
                      (points.length - 1);

      final double normalized =
          points[i].value /
              maxValue;

      final double y =
          top +
              chartHeight -
              chartHeight *
                  normalized.clamp(
                    0.0,
                    1.0,
                  );

      offsets.add(
        Offset(x, y),
      );
    }

    if (offsets.isEmpty) return;

    linePath.moveTo(
      offsets.first.dx,
      offsets.first.dy,
    );

    for (int i = 1;
        i < offsets.length;
        i++) {
      final Offset previous =
          offsets[i - 1];

      final Offset current =
          offsets[i];

      final double controlX =
          (previous.dx +
                  current.dx) /
              2;

      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    fillPath.addPath(
      linePath,
      Offset.zero,
    );

    fillPath.lineTo(
      offsets.last.dx,
      top + chartHeight,
    );

    fillPath.lineTo(
      offsets.first.dx,
      top + chartHeight,
    );

    fillPath.close();

    canvas.drawPath(
      fillPath,
      fillPaint,
    );

    canvas.drawPath(
      linePath,
      linePaint,
    );

    final Paint dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final Paint dotInnerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final int maxDots =
        offsets.length > 31
            ? 0
            : offsets.length;

    for (int i = 0;
        i < maxDots;
        i++) {
      canvas.drawCircle(
        offsets[i],
        4.2,
        dotPaint,
      );

      canvas.drawCircle(
        offsets[i],
        1.8,
        dotInnerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _LineChartPainter oldDelegate,
  ) {
    return oldDelegate.points != points ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lineColor != lineColor;
  }
}

// =============================================================================
// CHART LABELS
// =============================================================================

class _ChartLabels
    extends StatelessWidget {
  final List<_ChartPoint> points;
  final String Function(DateTime) labelBuilder;
  final bool compact;

  const _ChartLabels({
    required this.points,
    required this.labelBuilder,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme =
        Theme.of(context);

    final int count = points.length;

    final List<int> indexes =
        <int>[];

    if (count <= 7) {
      for (int i = 0; i < count; i++) {
        indexes.add(i);
      }
    } else if (count <= 14) {
      for (int i = 0; i < count; i += 2) {
        indexes.add(i);
      }

      if (indexes.last != count - 1) {
        indexes.add(count - 1);
      }
    } else {
      indexes.add(0);
      indexes.add(count ~/ 2);
      indexes.add(count - 1);
    }

    return Row(
      children: List.generate(
        indexes.length,
        (index) {
          final int pointIndex =
              indexes[index];

          final String label =
              labelBuilder(
            points[pointIndex].date,
          );

          return Expanded(
            child: Text(
              label,
              textAlign:
                  index == 0
                      ? TextAlign.left
                      : index ==
                              indexes.length -
                                  1
                          ? TextAlign.right
                          : TextAlign.center,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
                fontSize:
                    compact ? 9 : 10,
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// PROFIT ROW
// =============================================================================

class _ProfitRow
    extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  const _ProfitRow({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration:
                BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                fontWeight: isBold
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: theme
                .textTheme
                .bodyMedium
                ?.copyWith(
              color: color,
              fontWeight:
                  isBold
                      ? FontWeight.w900
                      : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SMALL STAT
// =============================================================================

class _SmallStat
    extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SmallStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
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
// INSIGHT
// =============================================================================

class _InsightTile
    extends StatelessWidget {
  final _Insight insight;

  const _InsightTile({
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            insight.color.withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color:
              insight.color.withValues(
            alpha: 0.14,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color:
                  insight.color.withValues(
                alpha: 0.10,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              insight.icon,
              color: insight.color,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.description,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                    height: 1.35,
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
// CHART EMPTY
// =============================================================================

class _ChartEmptyState
    extends StatelessWidget {
  final String message;
  final bool compact;

  const _ChartEmptyState({
    required this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      height: compact ? 110 : 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.30,
        ),
        borderRadius:
            BorderRadius.circular(13),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: compact ? 28 : 36,
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign:
                TextAlign.center,
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
    );
  }
}