import 'dart:ui' as ui;

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

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({
    super.key,
  });

  @override
  State<DashboardHomeScreen> createState() =>
      _DashboardHomeScreenState();
}

class _DashboardHomeScreenState
    extends State<DashboardHomeScreen> {
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

  final NumberFormat _currencyFormat =
      NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  BusinessModel? _business;

  bool _loading = true;
  String? _errorMessage;

  double _todaySales = 0;
  double _todayPurchase = 0;
  double _todayProfit = 0;

  double _totalSales = 0;
  double _totalPurchase = 0;
  double _totalExpenses = 0;
  double _totalReceived = 0;
  double _totalOutstanding = 0;
  double _stockValue = 0;
  double _totalProfit = 0;

  int _totalProducts = 0;
  int _lowStockProducts = 0;

  List<SaleModel> _recentSales = <SaleModel>[];
  List<PurchaseModel> _recentPurchases =
      <PurchaseModel>[];
  List<PaymentModel> _recentPayments =
      <PaymentModel>[];
  List<ExpenseModel> _recentExpenses =
      <ExpenseModel>[];

  List<SaleModel> _chartSales = <SaleModel>[];
  List<PurchaseModel> _chartPurchases =
      <PurchaseModel>[];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

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

      final results =
          await Future.wait<dynamic>([
        _saleRepository.getTodaySalesTotal(
          businessId: businessId,
        ),
        _purchaseRepository
            .getTodayPurchasesTotal(
          businessId: businessId,
        ),
        _saleRepository.getTotalSales(
          businessId: businessId,
        ),
        _purchaseRepository.getTotalPurchases(
          businessId: businessId,
        ),
        _expenseRepository.getTotalExpenses(
          businessId: businessId,
        ),
        _saleRepository.getTotalPaid(
          businessId: businessId,
        ),
        _saleRepository.getTotalOutstanding(
          businessId: businessId,
        ),
        _productRepository.getProducts(
          businessId,
        ),
        _productRepository.getLowStockProducts(
          businessId,
        ),
        _saleRepository.getTodaySales(
          businessId: businessId,
        ),
        _saleRepository.getSales(
          businessId: businessId,
        ),
        _purchaseRepository.getPurchases(
          businessId: businessId,
        ),
        _paymentRepository.getPayments(
          businessId: businessId,
        ),
        _expenseRepository.getExpenses(
          businessId: businessId,
        ),
      ]);

      final double todaySales =
          _safeDouble(results[0]);

      final double todayPurchase =
          _safeDouble(results[1]);

      final double totalSales =
          _safeDouble(results[2]);

      final double totalPurchase =
          _safeDouble(results[3]);

      final double totalExpenses =
          _safeDouble(results[4]);

      final double totalReceived =
          _safeDouble(results[5]);

      final double totalOutstanding =
          _safeDouble(results[6]);

      final List<ProductModel> products =
          List<ProductModel>.from(
        results[7] as List,
      );

      final List<ProductModel> lowStock =
          List<ProductModel>.from(
        results[8] as List,
      );

      final List<SaleModel> todaySalesList =
          List<SaleModel>.from(
        results[9] as List,
      );

      final List<SaleModel> allSales =
          List<SaleModel>.from(
        results[10] as List,
      );

      final List<PurchaseModel> allPurchases =
          List<PurchaseModel>.from(
        results[11] as List,
      );

      final List<PaymentModel> allPayments =
          List<PaymentModel>.from(
        results[12] as List,
      );

      final List<ExpenseModel> allExpenses =
          List<ExpenseModel>.from(
        results[13] as List,
      );

      final double todayProfit =
          _calculateProfit(todaySalesList);

      final double totalProfit =
          _calculateProfit(allSales);

      final double stockValue =
          _calculateStockValue(products);

      allSales.sort(
        (a, b) => b.date.compareTo(a.date),
      );

      allPurchases.sort(
        (a, b) => b.date.compareTo(a.date),
      );

      allPayments.sort(
        (a, b) => b.date.compareTo(a.date),
      );

      allExpenses.sort(
        (a, b) => b.date.compareTo(a.date),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _business = business;

        _todaySales = todaySales;
        _todayPurchase = todayPurchase;
        _todayProfit = todayProfit;

        _totalSales = totalSales;
        _totalPurchase = totalPurchase;
        _totalExpenses = totalExpenses;
        _totalReceived = totalReceived;
        _totalOutstanding =
            totalOutstanding;

        _stockValue = stockValue;
        _totalProfit = totalProfit;

        _totalProducts = products.length;
        _lowStockProducts = lowStock.length;

        _recentSales = allSales
            .take(5)
            .toList();

        _recentPurchases = allPurchases
            .take(5)
            .toList();

        _recentPayments = allPayments
            .take(5)
            .toList();

        _recentExpenses = allExpenses
            .take(5)
            .toList();

        _chartSales =
            List<SaleModel>.from(allSales);

        _chartPurchases =
            List<PurchaseModel>.from(
          allPurchases,
        );

        _loading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage =
            'Unable to load dashboard data.';
      });
    }
  }

  double _safeDouble(dynamic value) {
    if (value is num) {
      final double result =
          value.toDouble();

      if (result.isFinite) {
        return result;
      }
    }

    return 0;
  }

  double _calculateProfit(
    List<SaleModel> sales,
  ) {
    double profit = 0;

    for (final SaleModel sale in sales) {
      for (final item in sale.items) {
        final double revenue =
            item.quantity *
                item.sellingRate;

        final double cost =
            item.quantity *
                item.costPrice;

        profit += revenue - cost;
      }
    }

    return profit;
  }

  double _calculateStockValue(
    List<ProductModel> products,
  ) {
    double value = 0;

    for (final ProductModel product
        in products) {
      final double stock =
          product.currentStock;

      final double cost =
          product.purchasePrice;

      if (stock.isFinite &&
          cost.isFinite &&
          stock >= 0 &&
          cost >= 0) {
        value += stock * cost;
      }
    }

    return value;
  }

  String _formatCurrency(double value) {
    return _currencyFormat.format(value);
  }

  String _formatDate(DateTime date) {
    return DateFormat(
      'dd MMM yyyy',
    ).format(date);
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(context);
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 1200,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),

                  const SizedBox(height: 24),

                  _buildTodayOverview(context),

                  const SizedBox(height: 24),

                  _buildBusinessSummary(context),

                  const SizedBox(height: 24),

                  _buildBusinessHealth(context),

                  const SizedBox(height: 24),

                  _buildPerformanceOverview(
                    context,
                  ),

                  const SizedBox(height: 24),

                  _buildRecentActivity(context),

                  const SizedBox(height: 24),

                  _buildInventoryOverview(
                    context,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    final String businessName =
        _business?.businessName.trim() ?? '';

    final String ownerName =
        _business?.ownerName.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary
                .withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: 0.14),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  businessName.isEmpty
                      ? 'Business Dashboard'
                      : businessName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  ownerName.isEmpty
                      ? 'Business overview'
                      : 'Welcome, $ownerName',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    color: Colors.white
                        .withValues(alpha: 0.82),
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  DateFormat(
                    'EEEE, dd MMM yyyy',
                  ).format(DateTime.now()),
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: Colors.white
                        .withValues(alpha: 0.70),
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadDashboard,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayOverview(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Overview",
          style: theme
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool compact =
                constraints.maxWidth < 700;

            return GridView.count(
              crossAxisCount:
                  compact ? 2 : 3,
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio:
                  compact ? 1.42 : 1.80,
              children: [
                _MetricCard(
                  title: "Today's Sales",
                  value: _formatCurrency(
                    _todaySales,
                  ),
                  subtitle:
                      'Sales recorded today',
                  icon:
                      Icons.trending_up_rounded,
                  color:
                      AppColors.success,
                ),
                _MetricCard(
                  title: "Today's Purchase",
                  value: _formatCurrency(
                    _todayPurchase,
                  ),
                  subtitle:
                      'Purchases today',
                  icon:
                      Icons.shopping_cart_outlined,
                  color: AppColors.info,
                ),
                _MetricCard(
                  title: "Today's Profit",
                  value: _formatCurrency(
                    _todayProfit,
                  ),
                  subtitle:
                      'Gross product profit',
                  icon: Icons
                      .account_balance_wallet_outlined,
                  color:
                      AppColors.primary,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBusinessSummary(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final List<_MetricData> metrics = [
      _MetricData(
        title: 'Total Sales',
        value:
            _formatCurrency(_totalSales),
        subtitle: 'All recorded sales',
        icon:
            Icons.receipt_long_rounded,
        color: AppColors.success,
      ),
      _MetricData(
        title: 'Total Purchase',
        value:
            _formatCurrency(_totalPurchase),
        subtitle:
            'All recorded purchases',
        icon:
            Icons.inventory_2_outlined,
        color: AppColors.info,
      ),
      _MetricData(
        title: 'Expenses',
        value:
            _formatCurrency(_totalExpenses),
        subtitle: 'Business expenses',
        icon:
            Icons.money_off_csred_outlined,
        color: AppColors.danger,
      ),
      _MetricData(
        title: 'Received',
        value:
            _formatCurrency(_totalReceived),
        subtitle: 'Customer payments',
        icon: Icons.payments_rounded,
        color: AppColors.success,
      ),
      _MetricData(
        title: 'Outstanding',
        value:
            _formatCurrency(_totalOutstanding),
        subtitle: 'Customer pending',
        icon:
            Icons.account_balance_wallet_outlined,
        color: AppColors.warning,
      ),
      _MetricData(
        title: 'Stock Value',
        value:
            _formatCurrency(_stockValue),
        subtitle:
            'Current inventory value',
        icon: Icons.warehouse_outlined,
        color: AppColors.primary,
      ),
    ];

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Financial Overview',
          style: theme
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool compact =
                constraints.maxWidth < 700;

            return GridView.builder(
              itemCount: metrics.length,
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    compact ? 2 : 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio:
                    compact ? 1.42 : 1.80,
              ),
              itemBuilder: (
                context,
                index,
              ) {
                final _MetricData item =
                    metrics[index];

                return _MetricCard(
                  title: item.title,
                  value: item.value,
                  subtitle: item.subtitle,
                  icon: item.icon,
                  color: item.color,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildBusinessHealth(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final double netAfterExpenses =
        _totalProfit - _totalExpenses;

    final double margin =
        _totalSales <= 0
            ? 0
            : (_totalProfit /
                    _totalSales) *
                100;

    final List<_HealthData> cards = [
      _HealthData(
        icon: Icons.inventory_2_rounded,
        title: 'Products',
        value: '$_totalProducts',
        subtitle:
            'Inventory products',
        color: AppColors.primary,
      ),
      _HealthData(
        icon:
            Icons.warning_amber_rounded,
        title: 'Low Stock',
        value:
            '$_lowStockProducts',
        subtitle: _lowStockProducts == 0
            ? 'Stock levels are healthy'
            : 'Products need attention',
        color: _lowStockProducts == 0
            ? AppColors.success
            : AppColors.warning,
      ),
      _HealthData(
        icon:
            Icons.trending_up_rounded,
        title: 'Gross Profit',
        value:
            _formatCurrency(_totalProfit),
        subtitle:
            'Before business expenses',
        color: AppColors.success,
      ),
      _HealthData(
        icon:
            Icons.account_balance_outlined,
        title: 'Net After Expenses',
        value:
            _formatCurrency(netAfterExpenses),
        subtitle:
            'After business expenses',
        color: AppColors.info,
      ),
    ];

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Business Health',
          style: theme
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool compact =
                constraints.maxWidth < 700;

            return Column(
              children: [
                GridView.builder(
                  itemCount: cards.length,
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        compact ? 2 : 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio:
                        compact ? 1.35 : 1.20,
                  ),
                  itemBuilder: (
                    context,
                    index,
                  ) {
                    final _HealthData item =
                        cards[index];

                    return _HealthCard(
                      icon: item.icon,
                      title: item.title,
                      value: item.value,
                      subtitle: item.subtitle,
                      color: item.color,
                    );
                  },
                ),

                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration:
                              BoxDecoration(
                            color: AppColors
                                .success
                                .withValues(
                              alpha: 0.10,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              13,
                            ),
                          ),
                          child: const Icon(
                            Icons.percent_rounded,
                            color:
                                AppColors.success,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                'Profit Margin',
                                style: theme
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                'Gross profit compared with total sales',
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

                        Text(
                          '${margin.toStringAsFixed(1)}%',
                          style: theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            color:
                                AppColors.success,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPerformanceOverview(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final List<_PerformanceBarData> data =
        _buildLastSevenDayData();

    double maxValue = 0;

    for (final item in data) {
      if (item.sales > maxValue) {
        maxValue = item.sales;
      }

      if (item.purchase > maxValue) {
        maxValue = item.purchase;
      }
    }

    final double chartMax = maxValue <= 0
        ? 100
        : (maxValue * 1.25).ceilToDouble();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Performance Overview',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: theme
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Text(
                'Last 7 days',
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color:
                      theme.colorScheme.primary,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              14,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const _LegendDot(
                      color: AppColors.success,
                      label: 'Sales',
                    ),
                    const SizedBox(width: 18),
                    const _LegendDot(
                      color: AppColors.info,
                      label: 'Purchase',
                    ),
                    const Spacer(),
                    Text(
                      _formatCurrency(
                        _totalProfit,
                      ),
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        color:
                            AppColors.success,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'profit',
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

                const SizedBox(height: 20),

                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: _PerformanceChart(
                    data: data,
                    maxValue: chartMax,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<_PerformanceBarData>
      _buildLastSevenDayData() {
    final DateTime today = DateTime.now();

    final List<_PerformanceBarData>
        result = <_PerformanceBarData>[];

    for (int offset = 6;
        offset >= 0;
        offset--) {
      final DateTime day = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(
        Duration(days: offset),
      );

      double sales = 0;
      double purchase = 0;

      for (final SaleModel sale
          in _chartSales) {
        if (_isSameDay(
          sale.date,
          day,
        )) {
          sales += sale.total;
        }
      }

      for (final PurchaseModel item
          in _chartPurchases) {
        if (_isSameDay(
          item.date,
          day,
        )) {
          purchase += item.total;
        }
      }

      result.add(
        _PerformanceBarData(
          label:
              DateFormat('EEE').format(day),
          sales: sales,
          purchase: purchase,
        ),
      );
    }

    return result;
  }

  bool _isSameDay(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  Widget _buildRecentActivity(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent Activity',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'Latest transactions',
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

        const SizedBox(height: 14),

        Card(
          child: Padding(
            padding:
                const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_recentSales.isNotEmpty)
                  ..._recentSales
                      .take(2)
                      .map(
                        (sale) =>
                            _ActivityTile(
                          icon: Icons
                              .receipt_long_rounded,
                          title:
                              sale.invoiceNumber
                                      .trim()
                                      .isEmpty
                                  ? 'Sale'
                                  : sale
                                      .invoiceNumber,
                          subtitle:
                              sale.customerName
                                      .trim()
                                      .isEmpty
                                  ? 'Customer'
                                  : sale
                                      .customerName,
                          amount:
                              _formatCurrency(
                            sale.total,
                          ),
                          date:
                              _formatDate(
                            sale.date,
                          ),
                          color:
                              AppColors.success,
                        ),
                      ),

                if (_recentPurchases.isNotEmpty)
                  ..._recentPurchases
                      .take(2)
                      .map(
                        (purchase) =>
                            _ActivityTile(
                          icon: Icons
                              .shopping_cart_rounded,
                          title: 'Purchase',
                          subtitle:
                              purchase
                                  .supplierName
                                  .trim()
                                  .isEmpty
                              ? 'Supplier'
                              : purchase
                                  .supplierName,
                          amount:
                              _formatCurrency(
                            purchase.total,
                          ),
                          date:
                              _formatDate(
                            purchase.date,
                          ),
                          color:
                              AppColors.info,
                        ),
                      ),

                if (_recentPayments.isNotEmpty)
                  ..._recentPayments
                      .take(2)
                      .map(
                        (payment) =>
                            _ActivityTile(
                          icon: Icons
                              .payments_rounded,
                          title:
                              'Payment Received',
                          subtitle:
                              payment
                                      .customerName
                                      .trim()
                                      .isEmpty
                                  ? 'Customer'
                                  : payment
                                      .customerName,
                          amount:
                              _formatCurrency(
                            payment.amount,
                          ),
                          date:
                              _formatDate(
                            payment.date,
                          ),
                          color:
                              AppColors.success,
                        ),
                      ),

                if (_recentExpenses.isNotEmpty)
                  ..._recentExpenses
                      .take(2)
                      .map(
                        (expense) =>
                            _ActivityTile(
                          icon: Icons
                              .money_off_rounded,
                          title:
                              expense.category
                                      .trim()
                                      .isEmpty
                                  ? 'Expense'
                                  : expense
                                      .category,
                          subtitle:
                              expense
                                      .description
                                      .trim()
                                      .isEmpty
                                  ? 'Business expense'
                                  : expense
                                      .description,
                          amount:
                              _formatCurrency(
                            expense.amount,
                          ),
                          date:
                              _formatDate(
                            expense.date,
                          ),
                          color:
                              AppColors.danger,
                        ),
                      ),

                if (_recentSales.isEmpty &&
                    _recentPurchases.isEmpty &&
                    _recentPayments.isEmpty &&
                    _recentExpenses.isEmpty)
                  _buildNoActivityState(
                    context,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoActivityState(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 30,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary
                  .withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'No recent activity',
            style: theme
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Sales, purchases, payments and expenses will appear here.',
            textAlign: TextAlign.center,
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

  Widget _buildInventoryOverview(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final bool hasLowStock =
        _lowStockProducts > 0;

    final Color statusColor =
        hasLowStock
            ? AppColors.warning
            : AppColors.success;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Inventory Overview',
          style: theme
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 14),

        Card(
          child: Padding(
            padding:
                const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final bool compact =
                    constraints.maxWidth <
                        600;

                final Widget stockValue =
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(
                        _stockValue,
                      ),
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Stock Value',
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
                );

                final Widget content =
                    Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasLowStock
                            ? 'Low Stock Alert'
                            : 'Inventory Looks Good',
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        hasLowStock
                            ? '$_lowStockProducts product${_lowStockProducts == 1 ? '' : 's'} need restocking attention.'
                            : 'No products are below the minimum stock level.',
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

                if (compact) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _InventoryIcon(
                            color: statusColor,
                            icon: hasLowStock
                                ? Icons
                                    .warning_amber_rounded
                                : Icons
                                    .inventory_2_rounded,
                          ),
                          const SizedBox(
                            width: 14,
                          ),
                          content,
                        ],
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      stockValue,
                    ],
                  );
                }

                return Row(
                  children: [
                    _InventoryIcon(
                      color: statusColor,
                      icon: hasLowStock
                          ? Icons
                              .warning_amber_rounded
                          : Icons
                              .inventory_2_rounded,
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    content,
                    const SizedBox(
                      width: 16,
                    ),
                    stockValue,
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return SafeArea(
      child: Center(
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
                decoration: BoxDecoration(
                  color: AppColors.danger
                      .withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .error_outline_rounded,
                  color: AppColors.danger,
                  size: 36,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Unable to load dashboard',
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
                    'Something went wrong while loading dashboard data.',
                textAlign: TextAlign.center,
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
                onPressed: _loadDashboard,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label:
                    const Text('TRY AGAIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// METRIC DATA
// =============================================================================

class _MetricData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

// =============================================================================
// METRIC CARD
// =============================================================================

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
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
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: theme
              .colorScheme
              .outline
              .withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
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
                  subtitle,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: color,
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
// HEALTH DATA
// =============================================================================

class _HealthData {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _HealthData({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });
}

// =============================================================================
// HEALTH CARD
// =============================================================================

class _HealthCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _HealthCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
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
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: theme
              .colorScheme
              .outline
              .withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Row(
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

              const Spacer(),

              Flexible(
                child: Text(
                  value,
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
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            title,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: theme
                .textTheme
                .bodyMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            subtitle,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
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

// =============================================================================
// PERFORMANCE DATA
// =============================================================================

class _PerformanceBarData {
  final String label;
  final double sales;
  final double purchase;

  const _PerformanceBarData({
    required this.label,
    required this.sales,
    required this.purchase,
  });
}

// =============================================================================
// LEGEND DOT
// =============================================================================

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// PERFORMANCE CHART
// =============================================================================

class _PerformanceChart
    extends StatelessWidget {
  final List<_PerformanceBarData> data;
  final double maxValue;

  const _PerformanceChart({
    required this.data,
    required this.maxValue,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return CustomPaint(
      painter: _PerformanceChartPainter(
        data: data,
        maxValue: maxValue,
        textStyle:
            theme.textTheme.bodySmall ??
                const TextStyle(),
        gridColor: theme
            .colorScheme
            .outlineVariant
            .withValues(alpha: 0.35),
        labelColor: theme
            .colorScheme
            .onSurfaceVariant,
      ),
    );
  }
}

// =============================================================================
// PERFORMANCE CHART PAINTER
// =============================================================================

class _PerformanceChartPainter
    extends CustomPainter {
  final List<_PerformanceBarData> data;
  final double maxValue;
  final TextStyle textStyle;
  final Color gridColor;
  final Color labelColor;

  const _PerformanceChartPainter({
    required this.data,
    required this.maxValue,
    required this.textStyle,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    const double left = 8;
    const double right = 8;
    const double top = 8;
    const double bottom = 28;

    final double chartHeight =
        size.height - top - bottom;

    final double chartWidth =
        size.width - left - right;

    if (chartHeight <= 0 ||
        chartWidth <= 0) {
      return;
    }

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final double y =
          top +
              chartHeight -
              (chartHeight * i / 4);

      canvas.drawLine(
        Offset(left, y),
        Offset(
          size.width - right,
          y,
        ),
        gridPaint,
      );
    }

    if (data.isEmpty) {
      return;
    }

    final double safeMax =
        maxValue <= 0 ? 1 : maxValue;

    final double groupWidth =
        chartWidth / data.length;

    final double barWidth =
        (groupWidth * 0.22)
            .clamp(8.0, 22.0)
            .toDouble();

    final Paint salesPaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.fill;

    final Paint purchasePaint = Paint()
      ..color = AppColors.info
      ..style = PaintingStyle.fill;

    for (int i = 0;
        i < data.length;
        i++) {
      final _PerformanceBarData item =
          data[i];

      final double centerX =
          left +
              groupWidth * i +
              groupWidth / 2;

      final double salesRatio =
          (item.sales / safeMax)
              .clamp(0.0, 1.0)
              .toDouble();

      final double purchaseRatio =
          (item.purchase / safeMax)
              .clamp(0.0, 1.0)
              .toDouble();

      final double salesHeight =
          chartHeight * salesRatio;

      final double purchaseHeight =
          chartHeight * purchaseRatio;

      final RRect salesRect =
          RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - barWidth - 2,
          top +
              chartHeight -
              salesHeight,
          barWidth,
          salesHeight,
        ),
        const Radius.circular(5),
      );

      final RRect purchaseRect =
          RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX + 2,
          top +
              chartHeight -
              purchaseHeight,
          barWidth,
          purchaseHeight,
        ),
        const Radius.circular(5),
      );

      canvas.drawRRect(
        salesRect,
        salesPaint,
      );

      canvas.drawRRect(
        purchaseRect,
        purchasePaint,
      );

      final TextPainter labelPainter =
          TextPainter(
        text: TextSpan(
          text: item.label,
          style: textStyle.copyWith(
            color: labelColor,
            fontSize: 10,
            fontWeight:
                FontWeight.w600,
          ),
        ),

        // IMPORTANT:
        // Use ui.TextDirection to avoid
        // TextDirection name conflicts.
        textDirection: ui.TextDirection.ltr,
      )..layout();

      labelPainter.paint(
        canvas,
        Offset(
          centerX -
              labelPainter.width / 2,
          size.height -
              bottom +
              8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _PerformanceChartPainter
        oldDelegate,
  ) {
    return oldDelegate.data != data ||
        oldDelegate.maxValue !=
            maxValue ||
        oldDelegate.gridColor !=
            gridColor ||
        oldDelegate.labelColor !=
            labelColor;
  }
}

// =============================================================================
// INVENTORY ICON
// =============================================================================

class _InventoryIcon
    extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _InventoryIcon({
    required this.color,
    required this.icon,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 50,
      height: 50,
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
        size: 25,
      ),
    );
  }
}

// =============================================================================
// ACTIVITY TILE
// =============================================================================

class _ActivityTile
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final String date;
  final Color color;

  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.color,
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
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
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
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  subtitle,
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
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: color,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                date,
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
        ],
      ),
    );
  }
}