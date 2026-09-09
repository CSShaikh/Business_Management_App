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

  int _totalProducts = 0;
  int _lowStockProducts = 0;

  List<SaleModel> _recentSales = <SaleModel>[];
  List<PurchaseModel> _recentPurchases =
      <PurchaseModel>[];
  List<PaymentModel> _recentPayments =
      <PaymentModel>[];
  List<ExpenseModel> _recentExpenses =
      <ExpenseModel>[];

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
          'Business profile not found. Please complete business setup first.',
        );
      }

      final String businessId =
          business.id.trim();

      if (businessId.isEmpty) {
        throw Exception(
          'Business ID is missing.',
        );
      }

      final results = await Future.wait<dynamic>([
        _saleRepository.getTodaySalesTotal(
          businessId: businessId,
        ),
        _purchaseRepository.getTodayPurchasesTotal(
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
        _purchaseRepository.getTodayPurchases(
          businessId: businessId,
        ),
        _paymentRepository.getTodayPayments(
          businessId: businessId,
        ),
        _expenseRepository.getTodayExpenses(
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

      final List<PurchaseModel>
          todayPurchaseList =
          List<PurchaseModel>.from(
        results[10] as List,
      );

      final List<PaymentModel>
          todayPaymentList =
          List<PaymentModel>.from(
        results[11] as List,
      );

      final List<ExpenseModel>
          todayExpenseList =
          List<ExpenseModel>.from(
        results[12] as List,
      );

      final List<SaleModel> allSales =
          List<SaleModel>.from(
        results[13] as List,
      );

      final List<PurchaseModel> allPurchases =
          List<PurchaseModel>.from(
        results[14] as List,
      );

      final List<PaymentModel> allPayments =
          List<PaymentModel>.from(
        results[15] as List,
      );

      final List<ExpenseModel> allExpenses =
          List<ExpenseModel>.from(
        results[16] as List,
      );

      final double todayProfit =
          _calculateProfit(todaySalesList);

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

        _totalProducts = products.length;
        _lowStockProducts =
            lowStock.length;

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

        _loading = false;
        _errorMessage = null;
      });

      // These local variables intentionally ensure that
      // today's data is fetched together with dashboard data.
      // They are also useful when debugging dashboard calculations.
      todayPaymentList.length;
      todayExpenseList.length;
      todayPurchaseList.length;
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

  double _safeDouble(
    dynamic value,
  ) {
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

  String _formatCurrency(
    double value,
  ) {
    return _currencyFormat.format(
      value,
    );
  }

  String _formatDate(
    DateTime date,
  ) {
    return DateFormat(
      'dd MMM yyyy',
    ).format(date);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(
        context,
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
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
                  _buildHeader(
                    context,
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                  _buildTodayOverview(
                    context,
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                  _buildBusinessSummary(
                    context,
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                  _buildQuickStats(
                    context,
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                  _buildRecentActivity(
                    context,
                  ),
                  const SizedBox(
                    height: 24,
                  ),
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

  Widget _buildHeader(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final String businessName =
        _business?.businessName.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: 0.14),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons
                  .dashboard_rounded,
              color: Colors.white,
              size: 28,
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
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.w800,
                      ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  'Here is your business overview for today.',
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: Colors.white
                            .withValues(
                          alpha: 0.82,
                        ),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 8,
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
                fontWeight:
                    FontWeight.w800,
              ),
        ),
        const SizedBox(
          height: 14,
        ),
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool compact =
                constraints.maxWidth < 700;

            final int columns =
                compact ? 2 : 3;

            return GridView.count(
              crossAxisCount:
                  columns,
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio:
                  compact ? 1.45 : 1.85,
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
                  title:
                      "Today's Purchase",
                  value: _formatCurrency(
                    _todayPurchase,
                  ),
                  subtitle:
                      'Purchases recorded today',
                  icon:
                      Icons.shopping_cart_outlined,
                  color:
                      AppColors.info,
                ),
                _MetricCard(
                  title:
                      "Today's Profit",
                  value: _formatCurrency(
                    _todayProfit,
                  ),
                  subtitle:
                      'Gross product profit',
                  icon:
                      Icons
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

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Business Summary',
          style: theme
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
        ),
        const SizedBox(
          height: 14,
        ),
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool compact =
                constraints.maxWidth < 700;

            final cards = [
              _MetricCard(
                title: 'Total Sales',
                value:
                    _formatCurrency(
                  _totalSales,
                ),
                subtitle:
                    'All recorded sales',
                icon:
                    Icons.receipt_long_rounded,
                color:
                    AppColors.success,
              ),
              _MetricCard(
                title: 'Total Purchase',
                value:
                    _formatCurrency(
                  _totalPurchase,
                ),
                subtitle:
                    'All recorded purchases',
                icon:
                    Icons.inventory_2_outlined,
                color:
                    AppColors.info,
              ),
              _MetricCard(
                title: 'Expenses',
                value:
                    _formatCurrency(
                  _totalExpenses,
                ),
                subtitle:
                    'Business expenses',
                icon:
                    Icons.money_off_csred_outlined,
                color:
                    AppColors.danger,
              ),
              _MetricCard(
                title: 'Received',
                value:
                    _formatCurrency(
                  _totalReceived,
                ),
                subtitle:
                    'Customer payments',
                icon:
                    Icons.payments_rounded,
                color:
                    AppColors.success,
              ),
              _MetricCard(
                title: 'Outstanding',
                value:
                    _formatCurrency(
                  _totalOutstanding,
                ),
                subtitle:
                    'Customer pending',
                icon:
                    Icons
                        .account_balance_wallet_outlined,
                color:
                    AppColors.warning,
              ),
              _MetricCard(
                title: 'Stock Value',
                value:
                    _formatCurrency(
                  _stockValue,
                ),
                subtitle:
                    'Current inventory value',
                icon:
                    Icons.warehouse_outlined,
                color:
                    AppColors.primary,
              ),
            ];

            if (!compact) {
              return GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.75,
                children: cards,
              );
            }

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: cards,
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

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
                fontWeight:
                    FontWeight.w800,
              ),
        ),
        const SizedBox(
          height: 14,
        ),
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool compact =
                constraints.maxWidth < 700;

            final cards = [
              _HealthCard(
                icon:
                    Icons.inventory_2_rounded,
                title:
                    'Products',
                value:
                    '$_totalProducts',
                subtitle:
                    'Active inventory items',
                color:
                    AppColors.primary,
              ),
              _HealthCard(
                icon:
                    Icons.warning_amber_rounded,
                title:
                    'Low Stock',
                value:
                    '$_lowStockProducts',
                subtitle:
                    _lowStockProducts == 0
                        ? 'Stock levels are healthy'
                        : 'Products need attention',
                color:
                    _lowStockProducts == 0
                        ? AppColors.success
                        : AppColors.warning,
              ),
              _HealthCard(
                icon:
                    Icons.trending_up_rounded,
                title:
                    'Net Profit',
                value:
                    _formatCurrency(
                  _totalSales -
                      _calculateHistoricalCost(),
                ),
                subtitle:
                    'Before business expenses',
                color:
                    AppColors.success,
              ),
              _HealthCard(
                icon:
                    Icons.account_balance_outlined,
                title:
                    'Net After Expenses',
                value:
                    _formatCurrency(
                  _totalSales -
                      _calculateHistoricalCost() -
                      _totalExpenses,
                ),
                subtitle:
                    'Business performance',
                color:
                    AppColors.info,
              ),
            ];

            if (compact) {
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: cards,
              );
            }

            return Row(
              children: cards
                  .map(
                    (card) => Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.only(
                          right: 10,
                        ),
                        child: card,
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

  double _calculateHistoricalCost() {
    double cost = 0;

    for (final SaleModel sale
        in _recentSales) {
      for (final item in sale.items) {
        final double itemCost =
            item.quantity *
                item.costPrice;

        if (itemCost.isFinite &&
            itemCost >= 0) {
          cost += itemCost;
        }
      }
    }

    return cost;
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
                      fontWeight:
                          FontWeight.w800,
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
        const SizedBox(
          height: 14,
        ),
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
                          icon:
                              Icons
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
                          icon:
                              Icons
                                  .shopping_cart_rounded,
                          title:
                              'Purchase',
                          subtitle:
                              purchase
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
                          icon:
                              Icons
                                  .payments_rounded,
                          title:
                              'Payment Received',
                          subtitle:
                              payment
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
                          icon:
                              Icons
                                  .money_off_rounded,
                          title:
                              expense.category,
                          subtitle:
                              expense.description
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
              color:
                  AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Text(
            'No recent activity',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight:
                      FontWeight.w700,
                ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            'Sales, purchases, payments and expenses will appear here.',
            textAlign:
                TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: Theme.of(
                    context,
                  )
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
                fontWeight:
                    FontWeight.w800,
              ),
        ),
        const SizedBox(
          height: 14,
        ),
        Card(
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
                    color: (hasLowStock
                            ? AppColors.warning
                            : AppColors.success)
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                  child: Icon(
                    hasLowStock
                        ? Icons
                            .warning_amber_rounded
                        : Icons
                            .inventory_2_rounded,
                    color: hasLowStock
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ),
                const SizedBox(
                  width: 14,
                ),
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
                            ? '$_lowStockProducts product${_lowStockProducts == 1 ? '' : 's'} are below the minimum stock level.'
                            : 'No products are currently below their minimum stock level.',
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
                const SizedBox(
                  width: 12,
                ),
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
                    const SizedBox(
                      height: 3,
                    ),
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    BuildContext context,
  ) {
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
                decoration:
                    BoxDecoration(
                  color: AppColors.danger
                      .withValues(
                    alpha: 0.10,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .error_outline_rounded,
                  color:
                      AppColors.danger,
                  size: 36,
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              Text(
                'Unable to load dashboard',
                style: Theme.of(context)
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
                    'Something went wrong while loading dashboard data.',
                textAlign:
                    TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
              const SizedBox(
                height: 20,
              ),
              FilledButton.icon(
                onPressed:
                    _loadDashboard,
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
        color: theme
            .colorScheme
            .surface,
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
            decoration:
                BoxDecoration(
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
          const SizedBox(
            width: 11,
          ),
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
                const SizedBox(
                  height: 3,
                ),
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
                const SizedBox(
                  height: 2,
                ),
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
        color: theme
            .colorScheme
            .surface,
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
                decoration:
                    BoxDecoration(
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
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            title,
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
            decoration:
                BoxDecoration(
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
                const SizedBox(
                  height: 3,
                ),
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
          const SizedBox(
            width: 10,
          ),
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
              const SizedBox(
                height: 3,
              ),
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