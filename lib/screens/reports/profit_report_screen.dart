import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      for (final item in sale.items) {
        profit +=
            (item.sellingRate -
                    item.costPrice) *
                item.quantity;
      }
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

        final double revenue =
            item.quantity *
                item.sellingRate;

        final double cost =
            item.quantity *
                item.costPrice;

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

  String _date(DateTime value) {
    return DateFormat(
      'dd MMM yyyy',
    ).format(value);
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
      return 'All Dates';
    }

    return '${DateFormat('dd MMM yyyy').format(_startDate!)}'
        ' → '
        '${DateFormat('dd MMM yyyy').format(_endDate!)}';
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
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
                  'Understand gross profit, net profit, margins and business performance.',
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
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 9,
            ),
            decoration:
                BoxDecoration(
              color: theme
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Text(
              _dateRangeText(),
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed:
                _selectDateRange,
            icon: const Icon(
              Icons.calendar_month_rounded,
              size: 18,
            ),
            label: Text(
              hasFilter
                  ? 'Change Period'
                  : 'Select Period',
            ),
          ),
          if (hasFilter)
            OutlinedButton.icon(
              onPressed:
                  _clearDateFilter,
              icon: const Icon(
                Icons.clear_rounded,
                size: 18,
              ),
              label:
                  const Text('Clear'),
            ),
        ],
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

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            isDesktop ? 3 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio:
            isDesktop ? 2.0 : 1.48,
      ),
      itemBuilder: (
        context,
        index,
      ) {
        return _SummaryCard(
          item: items[index],
        );
      },
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
        controller:
            _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery =
                value.trim().toLowerCase();
          });
        },
        decoration:
            InputDecoration(
          hintText:
              'Search invoice, customer or product...',
          prefixIcon:
              const Icon(
            Icons.search_rounded,
          ),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController
                            .clear();

                        setState(() {
                          _searchQuery =
                              '';
                        });
                      },
                      icon:
                          const Icon(
                        Icons.clear_rounded,
                      ),
                    )
                  : null,
        ),
      ),
    );
  }

  // ===========================================================================
  // MONTHLY
  // ===========================================================================

  Widget _buildMonthlySection(
    ThemeData theme,
    List<SaleModel> sales,
    List<ExpenseModel> expenses,
  ) {
    final Map<String, _MonthlyProfitData>
        data =
        _monthlyProfitData(
      sales,
      expenses,
    );

    final List<_MonthlyProfitData>
        months =
        data.values.toList()
          ..sort(
            (a, b) {
              final DateTime da =
                  DateTime(
                a.year,
                a.month,
              );

              final DateTime db =
                  DateTime(
                b.year,
                b.month,
              );

              return db.compareTo(da);
            },
          );

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon:
                Icons.calendar_view_month_rounded,
            title:
                'Monthly Profit Performance',
            subtitle:
                'Sales, gross profit, expenses and net profit',
          ),
          const SizedBox(height: 18),
          if (months.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.analytics_outlined,
              message:
                  'No profit data available for this period.',
            )
          else
            ...months.map(
              (month) {
                final double net =
                    month.grossProfit -
                        month.expenses;

                return _MonthlyTile(
                  month: month,
                  netProfit: net,
                  monthName:
                      _monthName(
                    month.year,
                    month.month,
                  ),
                  currency:
                      _currency,
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
    final Map<String, _ProductProfitData>
        map =
        _productProfitData(sales);

    final List<_ProductProfitData>
        products =
        map.values.toList()
          ..sort(
            (a, b) =>
                b.profit.compareTo(
              a.profit,
            ),
          );

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon:
                Icons.inventory_2_rounded,
            title:
                'Product-wise Profit',
            subtitle:
                'Profit generated by each sold product',
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
            ...products.map(
              (product) {
                final double margin =
                    product.revenue > 0
                        ? (product.profit /
                                product.revenue) *
                            100
                        : 0;

                return _ProductProfitTile(
                  data: product,
                  margin: margin,
                  currency:
                      _currency,
                  number: _number,
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
    final Map<String, _CustomerProfitData>
        map =
        _customerProfitData(sales);

    final List<_CustomerProfitData>
        customers =
        map.values.toList()
          ..sort(
            (a, b) =>
                b.profit.compareTo(
              a.profit,
            ),
          );

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon:
                Icons.people_alt_rounded,
            title:
                'Customer-wise Profit',
            subtitle:
                'Profit contribution from each customer',
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
            ...customers.map(
              (customer) {
                final double margin =
                    customer.sales > 0
                        ? (customer.profit /
                                customer.sales) *
                            100
                        : 0;

                return _CustomerProfitTile(
                  data: customer,
                  margin: margin,
                  currency:
                      _currency,
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
          const _SectionHeader(
            icon:
                Icons.receipt_long_rounded,
            title:
                'Invoice-wise Profit',
            subtitle:
                'Profit calculated using each sale item cost',
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
            ...sales.map(
              (sale) {
                double cost = 0;

                for (final item
                    in sale.items) {
                  cost +=
                      item.quantity *
                          item.costPrice;
                }

                final double gross =
                    sale.total - cost;

                return _SaleProfitTile(
                  sale: sale,
                  cost: cost,
                  profit: gross,
                  currency:
                      _currency,
                  date: _date,
                  onTap: () {
                    _showSaleProfitDetails(
                      sale,
                      cost,
                      gross,
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
  // EXPENSE IMPACT
  // ===========================================================================

  Widget _buildExpenseImpactSection(
    ThemeData theme,
    List<ExpenseModel> expenses,
  ) {
    final Map<String, double> categoryTotals =
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
        entries =
        categoryTotals.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(
              a.value,
            ),
          );

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon:
                Icons.money_off_csred_rounded,
            title:
                'Expense Impact',
            subtitle:
                'Expenses deducted from gross profit',
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.money_off_rounded,
              message:
                  'No expenses available for this period.',
            )
          else
            ...entries.map(
              (entry) {
                return _ExpenseImpactTile(
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
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SALE DETAILS
  // ===========================================================================

  void _showSaleProfitDetails(
    SaleModel sale,
    double cost,
    double profit,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final ThemeData theme =
            Theme.of(sheetContext);

        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profit Details',
                    style: theme
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sale.invoiceNumber,
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
                  _DetailRow(
                    label: 'Customer',
                    value:
                        sale.customerName,
                  ),
                  _DetailRow(
                    label: 'Date',
                    value:
                        _date(sale.date),
                  ),
                  _DetailRow(
                    label: 'Sales Amount',
                    value:
                        _currency(
                      sale.total,
                    ),
                  ),
                  _DetailRow(
                    label:
                        'Cost of Goods',
                    value:
                        _currency(cost),
                  ),
                  _DetailRow(
                    label:
                        'Gross Profit',
                    value:
                        _currency(profit),
                    bold: true,
                    valueColor:
                        profit >= 0
                            ? AppColors.success
                            : AppColors.danger,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Items',
                    style: theme
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...sale.items.map(
                    (item) {
                      final double itemCost =
                          item.quantity *
                              item.costPrice;

                      final double itemRevenue =
                          item.quantity *
                              item.sellingRate;

                      final double itemProfit =
                          itemRevenue -
                              itemCost;

                      return Container(
                        margin:
                            const EdgeInsets
                                .only(
                          bottom: 8,
                        ),
                        padding:
                            const EdgeInsets
                                .all(12),
                        decoration:
                            BoxDecoration(
                          color: theme
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(
                            alpha: 0.35,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: theme
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                    ),
                                  ),
                                  const SizedBox(
                                      height: 3),
                                  Text(
                                    '${_number(item.quantity)} ${item.unit} × ${_currency(item.sellingRate)}',
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
                              _currency(
                                itemProfit,
                              ),
                              style: theme
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                color: itemProfit >=
                                        0
                                    ? AppColors
                                        .success
                                    : AppColors
                                        .danger,
                                fontWeight:
                                    FontWeight
                                        .w800,
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
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 500,
          ),
          child: _ReportCard(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.danger
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
                  'Unable to load Profit Report',
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
                      () => _loadReport(),
                  icon: const Icon(
                    Icons.refresh_rounded,
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
// DATA CLASSES
// =============================================================================

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
// REPORT CARD
// =============================================================================

class _ReportCard
    extends StatelessWidget {
  final Widget child;

  const _ReportCard({
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
// SUMMARY CARD
// =============================================================================

class _SummaryCard
    extends StatelessWidget {
  final _SummaryItem item;

  const _SummaryCard({
    required this.item,
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
          color:
              item.color.withValues(
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
                      item.color.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: 21,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_outward_rounded,
                color:
                    item.color.withValues(
                  alpha: 0.65,
                ),
                size: 18,
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.title,
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
              fontWeight:
                  FontWeight.w600,
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
                .titleLarge
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
              color: item.color,
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
// MONTHLY TILE
// =============================================================================

class _MonthlyTile
    extends StatelessWidget {
  final _MonthlyProfitData month;
  final double netProfit;
  final String monthName;
  final String Function(double) currency;

  const _MonthlyTile({
    required this.month,
    required this.netProfit,
    required this.monthName,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    final double margin =
        month.sales > 0
            ? (netProfit /
                    month.sales) *
                100
            : 0;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.40,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthName,
                  style: theme
                      .textTheme
                      .bodyLarge
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
                  color: netProfit >= 0
                      ? AppColors.success
                      : AppColors.danger,
                  fontWeight:
                      FontWeight.w800,
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
                    currency(month.sales),
              ),
              _MiniMetric(
                label: 'Cost',
                value:
                    currency(month.cost),
              ),
              _MiniMetric(
                label: 'Gross',
                value: currency(
                  month.grossProfit,
                ),
              ),
              _MiniMetric(
                label: 'Expenses',
                value:
                    currency(month.expenses),
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

// =============================================================================
// PRODUCT PROFIT TILE
// =============================================================================

class _ProductProfitTile
    extends StatelessWidget {
  final _ProductProfitData data;
  final double margin;
  final String Function(double) currency;
  final String Function(double) number;

  const _ProductProfitTile({
    required this.data,
    required this.margin,
    required this.currency,
    required this.number,
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
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.40,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration:
                          BoxDecoration(
                        color:
                            AppColors.success
                                .withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color:
                            AppColors.success,
                        size: 20,
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        data.productName,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style: theme
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                currency(data.profit),
                style: theme
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                  color:
                      data.profit >= 0
                          ? AppColors
                              .success
                          : AppColors
                              .danger,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
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
                    currency(
                  data.revenue,
                ),
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

// =============================================================================
// CUSTOMER PROFIT TILE
// =============================================================================

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
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.40,
        ),
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
              color:
                  AppColors.primary
                      .withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color:
                  AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
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
                      .bodyLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.invoiceCount} invoice${data.invoiceCount == 1 ? '' : 's'} • ${margin.toStringAsFixed(1)}% margin',
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
          Text(
            currency(data.profit),
            style: theme
                .textTheme
                .bodyLarge
                ?.copyWith(
              color:
                  data.profit >= 0
                      ? AppColors.success
                      : AppColors.danger,
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
// SALE PROFIT TILE
// =============================================================================

class _SaleProfitTile
    extends StatelessWidget {
  final SaleModel sale;
  final double cost;
  final double profit;
  final String Function(double) currency;
  final String Function(DateTime) date;
  final VoidCallback onTap;

  const _SaleProfitTile({
    required this.sale,
    required this.cost,
    required this.profit,
    required this.currency,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(14),
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
            const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme
              .colorScheme
              .surfaceContainerHighest
              .withValues(
            alpha: 0.40,
          ),
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration:
                  BoxDecoration(
                color:
                    AppColors.success
                        .withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  11,
                ),
              ),
              child: const Icon(
                Icons.receipt_rounded,
                color:
                    AppColors.success,
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
                    sale.invoiceNumber,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: theme
                        .textTheme
                        .bodyLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sale.customerName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: theme
                        .textTheme
                        .bodySmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${date(sale.date)} • Cost ${currency(cost)}',
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
                  currency(profit),
                  style: theme
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                    color: profit >= 0
                        ? AppColors.success
                        : AppColors.danger,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// EXPENSE IMPACT TILE
// =============================================================================

class _ExpenseImpactTile
    extends StatelessWidget {
  final String category;
  final double amount;
  final double total;
  final String Function(double) currency;

  const _ExpenseImpactTile({
    required this.category,
    required this.amount,
    required this.total,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    final double percentage =
        total > 0
            ? (amount / total) * 100
            : 0;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.40,
        ),
        borderRadius:
            BorderRadius.circular(14),
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
                      .bodyLarge
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
                    .bodyLarge
                    ?.copyWith(
                  color:
                      AppColors.danger,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(20),
            child:
                LinearProgressIndicator(
              value: (percentage / 100)
                  .clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: theme
                  .colorScheme
                  .outlineVariant
                  .withValues(
                alpha: 0.35,
              ),
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                AppColors.danger,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Align(
            alignment:
                Alignment.centerRight,
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color:
                    AppColors.danger,
                fontWeight:
                    FontWeight.w700,
              ),
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

  const _MiniMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
                FontWeight.w800,
          ),
        ),
      ],
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
  final bool bold;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign:
                  TextAlign.end,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: valueColor,
                fontWeight:
                    bold
                        ? FontWeight.w800
                        : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EMPTY
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
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.35,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 34,
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(height: 10),
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