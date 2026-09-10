import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/sale_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/sale_repository.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({
    super.key,
  });

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final BusinessRepository _businessRepository = BusinessRepository();
  final SaleRepository _saleRepository = SaleRepository();

  final TextEditingController _searchController =
      TextEditingController();

  bool _loading = true;
  bool _refreshing = false;

  String? _errorMessage;
  String _searchQuery = '';

  DateTime? _startDate;
  DateTime? _endDate;

  String _paymentFilter = 'All';

  List<SaleModel> _allSales = <SaleModel>[];

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
      final business =
          await _businessRepository.getBusinessForCurrentUser();

      if (business == null) {
        throw Exception(
          'Business information is not available.',
        );
      }

      final List<SaleModel> sales =
          await _saleRepository.getSales(
        businessId: business.id,
      );

      if (!mounted) return;

      setState(() {
        _allSales = sales;
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
          _startDate != null && _endDate != null
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
      helpText: 'Select Sales Report Period',
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
    final String query = _searchQuery.trim().toLowerCase();

    return _allSales.where((sale) {
      // -----------------------------------------------------------------------
      // DATE
      // -----------------------------------------------------------------------

      if (_startDate != null) {
        if (sale.date.isBefore(_startDate!)) {
          return false;
        }
      }

      if (_endDate != null) {
        if (sale.date.isAfter(_endDate!)) {
          return false;
        }
      }

      // -----------------------------------------------------------------------
      // PAYMENT STATUS
      // -----------------------------------------------------------------------

      if (_paymentFilter != 'All') {
        if (sale.paymentStatus.toLowerCase() !=
            _paymentFilter.toLowerCase()) {
          return false;
        }
      }

      // -----------------------------------------------------------------------
      // SEARCH
      // -----------------------------------------------------------------------

      if (query.isEmpty) {
        return true;
      }

      final bool invoiceMatch =
          sale.invoiceNumber.toLowerCase().contains(query);

      final bool customerMatch =
          sale.customerName.toLowerCase().contains(query);

      final bool notesMatch =
          sale.notes.toLowerCase().contains(query);

      final bool productMatch = sale.items.any(
        (item) {
          return item.productName
              .toLowerCase()
              .contains(query);
        },
      );

      return invoiceMatch ||
          customerMatch ||
          notesMatch ||
          productMatch;
    }).toList()
      ..sort(
        (a, b) => b.date.compareTo(a.date),
      );
  }

  // ===========================================================================
  // CALCULATIONS
  // ===========================================================================

  double _totalSales(List<SaleModel> sales) {
    return sales.fold(
      0,
      (sum, sale) => sum + sale.total,
    );
  }

  double _totalCollected(List<SaleModel> sales) {
    return sales.fold(
      0,
      (sum, sale) => sum + sale.paidAmount,
    );
  }

  double _totalOutstanding(List<SaleModel> sales) {
    return sales.fold(
      0,
      (sum, sale) {
        final double outstanding =
            sale.total - sale.paidAmount;

        return sum +
            (outstanding > 0 ? outstanding : 0);
      },
    );
  }

  double _totalGrossProfit(List<SaleModel> sales) {
    double total = 0;

    for (final sale in sales) {
      for (final item in sale.items) {
        total +=
            (item.sellingRate - item.costPrice) *
                item.quantity;
      }
    }

    return total;
  }

  double _totalCost(List<SaleModel> sales) {
    double total = 0;

    for (final sale in sales) {
      for (final item in sale.items) {
        total +=
            item.costPrice * item.quantity;
      }
    }

    return total;
  }

  double _totalQuantity(List<SaleModel> sales) {
    double total = 0;

    for (final sale in sales) {
      for (final item in sale.items) {
        total += item.quantity;
      }
    }

    return total;
  }

  double _profitMargin(List<SaleModel> sales) {
    final double salesAmount = _totalSales(sales);

    if (salesAmount <= 0) {
      return 0;
    }

    return (_totalGrossProfit(sales) /
            salesAmount) *
        100;
  }

  double _collectionRate(List<SaleModel> sales) {
    final double salesAmount = _totalSales(sales);

    if (salesAmount <= 0) {
      return 0;
    }

    return (_totalCollected(sales) /
            salesAmount) *
        100;
  }

  // ===========================================================================
  // GROUPING
  // ===========================================================================

  Map<String, _CustomerSalesSummary> _customerWiseSales(
    List<SaleModel> sales,
  ) {
    final Map<String, _CustomerSalesSummary> result =
        <String, _CustomerSalesSummary>{};

    for (final sale in sales) {
      final String customerName =
          sale.customerName.trim().isEmpty
              ? 'Walk-in Customer'
              : sale.customerName.trim();

      final _CustomerSalesSummary existing =
          result[customerName] ??
              _CustomerSalesSummary(
                name: customerName,
              );

      final double outstanding =
          sale.total - sale.paidAmount;

      double profit = 0;

      for (final item in sale.items) {
        profit +=
            (item.sellingRate - item.costPrice) *
                item.quantity;
      }

      result[customerName] =
          _CustomerSalesSummary(
        name: customerName,
        sales: existing.sales + sale.total,
        collected:
            existing.collected + sale.paidAmount,
        outstanding:
            existing.outstanding +
                (outstanding > 0 ? outstanding : 0),
        profit: existing.profit + profit,
        invoiceCount:
            existing.invoiceCount + 1,
      );
    }

    final List<_CustomerSalesSummary> values =
        result.values.toList();

    values.sort(
      (a, b) => b.sales.compareTo(a.sales),
    );

    return <String, _CustomerSalesSummary>{
      for (final item in values) item.name: item,
    };
  }

  Map<String, _ProductSalesSummary> _productWiseSales(
    List<SaleModel> sales,
  ) {
    final Map<String, _ProductSalesSummary> result =
        <String, _ProductSalesSummary>{};

    for (final sale in sales) {
      for (final item in sale.items) {
        final String productName =
            item.productName.trim().isEmpty
                ? 'Unknown Product'
                : item.productName.trim();

        final _ProductSalesSummary existing =
            result[productName] ??
                _ProductSalesSummary(
                  name: productName,
                );

        final double revenue =
            item.total;

        final double cost =
            item.costPrice * item.quantity;

        final double profit =
            revenue - cost;

        result[productName] =
            _ProductSalesSummary(
          name: productName,
          quantity:
              existing.quantity + item.quantity,
          revenue:
              existing.revenue + revenue,
          cost:
              existing.cost + cost,
          profit:
              existing.profit + profit,
          invoiceCount:
              existing.invoiceCount + 1,
          unit: item.unit,
        );
      }
    }

    return result;
  }

  // ===========================================================================
  // STATUS COUNTS
  // ===========================================================================

  int _countStatus(
    List<SaleModel> sales,
    String status,
  ) {
    return sales.where(
      (sale) {
        return sale.paymentStatus.toLowerCase() ==
            status.toLowerCase();
      },
    ).length;
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

  String _dateRangeText() {
    if (_startDate == null ||
        _endDate == null) {
      return 'All Dates';
    }

    return '${DateFormat('dd MMM yyyy').format(_startDate!)}'
        ' → '
        '${DateFormat('dd MMM yyyy').format(_endDate!)}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppColors.success;

      case 'partial':
        return AppColors.warning;

      case 'unpaid':
        return AppColors.danger;

      default:
        return AppColors.info;
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(theme);
    }

    final List<SaleModel> sales = _filteredSales;

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

                    _buildDateFilter(
                      theme,
                    ),

                    const SizedBox(height: 20),

                    _buildSummaryCards(
                      theme,
                      sales,
                      isDesktop,
                    ),

                    const SizedBox(height: 20),

                    _buildPaymentStatusSection(
                      theme,
                      sales,
                    ),

                    const SizedBox(height: 20),

                    _buildSearchAndFilters(
                      theme,
                    ),

                    const SizedBox(height: 20),

                    _buildCustomerWiseSection(
                      theme,
                      sales,
                    ),

                    const SizedBox(height: 20),

                    _buildProductWiseSection(
                      theme,
                      sales,
                    ),

                    const SizedBox(height: 20),

                    _buildInvoiceSection(
                      theme,
                      sales,
                    ),

                    const SizedBox(height: 20),

                    _buildReportFooter(
                      theme,
                      sales,
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.15,
              ),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
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
                  'Sales Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Analyze sales, collection, profit and customer performance.',
                  style: TextStyle(
                    color: Colors.white
                        .withValues(
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
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withValues(
                      alpha: 0.14,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      30,
                    ),
                  ),
                  child: Text(
                    _dateRangeText(),
                    style: const TextStyle(
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
            style: theme.textTheme.titleMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(width: 4),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Text(
              _dateRangeText(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          FilledButton.icon(
            onPressed: _selectDateRange,
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
              onPressed: _clearDateFilter,
              icon: const Icon(
                Icons.clear_rounded,
                size: 18,
              ),
              label: const Text(
                'Clear',
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummaryCards(
    ThemeData theme,
    List<SaleModel> sales,
    bool isDesktop,
  ) {
    final double totalSales =
        _totalSales(sales);

    final double collected =
        _totalCollected(sales);

    final double outstanding =
        _totalOutstanding(sales);

    final double profit =
        _totalGrossProfit(sales);

    final List<_SummaryItem> items = [
      _SummaryItem(
        title: 'Total Sales',
        value: _currency(totalSales),
        subtitle:
            '${sales.length} invoices',
        icon: Icons.trending_up_rounded,
        color: AppColors.primary,
      ),
      _SummaryItem(
        title: 'Collected',
        value: _currency(collected),
        subtitle:
            '${_collectionRate(sales).toStringAsFixed(1)}% collection',
        icon: Icons.payments_rounded,
        color: AppColors.success,
      ),
      _SummaryItem(
        title: 'Outstanding',
        value: _currency(outstanding),
        subtitle:
            'Customer receivable',
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.warning,
      ),
      _SummaryItem(
        title: 'Gross Profit',
        value: _currency(profit),
        subtitle:
            '${_profitMargin(sales).toStringAsFixed(1)}% margin',
        icon: Icons.auto_graph_rounded,
        color: AppColors.secondary,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop
            ? 4
            : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio:
            isDesktop ? 1.9 : 1.45,
      ),
      itemBuilder: (
        context,
        index,
      ) {
        final _SummaryItem item =
            items[index];

        return _SummaryCard(
          item: item,
        );
      },
    );
  }

  // ===========================================================================
  // PAYMENT STATUS
  // ===========================================================================

  Widget _buildPaymentStatusSection(
    ThemeData theme,
    List<SaleModel> sales,
  ) {
    final int paid =
        _countStatus(
      sales,
      'Paid',
    );

    final int partial =
        _countStatus(
      sales,
      'Partial',
    );

    final int unpaid =
        _countStatus(
      sales,
      'Unpaid',
    );

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.payments_outlined,
            title:
                'Payment Status',
            subtitle:
                'Sales payment collection breakdown',
          ),

          const SizedBox(height: 18),

          LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              final bool compact =
                  constraints.maxWidth < 600;

              final List<_StatusItem> items = [
                _StatusItem(
                  label: 'Paid',
                  count: paid,
                  color:
                      AppColors.success,
                  icon:
                      Icons.check_circle_rounded,
                ),
                _StatusItem(
                  label: 'Partial',
                  count: partial,
                  color:
                      AppColors.warning,
                  icon:
                      Icons.timelapse_rounded,
                ),
                _StatusItem(
                  label: 'Unpaid',
                  count: unpaid,
                  color:
                      AppColors.danger,
                  icon:
                      Icons.pending_actions_rounded,
                ),
              ];

              if (compact) {
                return Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            bottom: 10,
                          ),
                          child:
                              _StatusTile(
                            item: item,
                          ),
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: items
                    .map(
                      (item) => Expanded(
                        child:
                            Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            right: 10,
                          ),
                          child:
                              _StatusTile(
                            item: item,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEARCH / FILTERS
  // ===========================================================================

  Widget _buildSearchAndFilters(
    ThemeData theme,
  ) {
    return _ReportCard(
      child: Column(
        children: [
          TextField(
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
                  'Search invoice, customer, product or notes...',
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

          const SizedBox(height: 14),

          Align(
            alignment:
                Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'All',
                  selected:
                      _paymentFilter ==
                          'All',
                  onSelected: () {
                    setState(() {
                      _paymentFilter =
                          'All';
                    });
                  },
                ),
                _FilterChip(
                  label: 'Paid',
                  selected:
                      _paymentFilter ==
                          'Paid',
                  color:
                      AppColors.success,
                  onSelected: () {
                    setState(() {
                      _paymentFilter =
                          'Paid';
                    });
                  },
                ),
                _FilterChip(
                  label: 'Partial',
                  selected:
                      _paymentFilter ==
                          'Partial',
                  color:
                      AppColors.warning,
                  onSelected: () {
                    setState(() {
                      _paymentFilter =
                          'Partial';
                    });
                  },
                ),
                _FilterChip(
                  label: 'Unpaid',
                  selected:
                      _paymentFilter ==
                          'Unpaid',
                  color:
                      AppColors.danger,
                  onSelected: () {
                    setState(() {
                      _paymentFilter =
                          'Unpaid';
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CUSTOMER-WISE
  // ===========================================================================

  Widget _buildCustomerWiseSection(
    ThemeData theme,
    List<SaleModel> sales,
  ) {
    final Map<String, _CustomerSalesSummary>
        customers =
        _customerWiseSales(sales);

    final List<_CustomerSalesSummary>
        values =
        customers.values.toList();

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.groups_rounded,
            title:
                'Customer-wise Sales',
            subtitle:
                'Sales and collection by hotel/customer',
          ),

          const SizedBox(height: 18),

          if (values.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.groups_outlined,
              message:
                  'No customer sales available for the selected filters.',
            )
          else
            ...values.take(10).map(
              (customer) {
                return _CustomerSalesTile(
                  summary: customer,
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PRODUCT-WISE
  // ===========================================================================

  Widget _buildProductWiseSection(
    ThemeData theme,
    List<SaleModel> sales,
  ) {
    final Map<String, _ProductSalesSummary>
        products =
        _productWiseSales(sales);

    final List<_ProductSalesSummary>
        values =
        products.values.toList()
          ..sort(
            (a, b) => b.revenue.compareTo(
              a.revenue,
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
                'Product-wise Sales',
            subtitle:
                'Revenue, quantity and profit by product',
          ),

          const SizedBox(height: 18),

          if (values.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.inventory_2_outlined,
              message:
                  'No product sales available for the selected filters.',
            )
          else
            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final bool compact =
                    constraints.maxWidth <
                        650;

                if (compact) {
                  return Column(
                    children: values
                        .take(15)
                        .map(
                          (
                            product,
                          ) =>
                              _ProductSalesTile(
                            summary:
                                product,
                          ),
                        )
                        .toList(),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 28,
                    headingTextStyle:
                        theme
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w700,
                        ),
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
                    ],
                    rows: values
                        .take(20)
                        .map(
                          (
                            product,
                          ) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    product.name,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${_number(product.quantity)} ${product.unit}',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _currency(
                                      product.revenue,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _currency(
                                      product.cost,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _currency(
                                      product.profit,
                                    ),
                                    style:
                                        TextStyle(
                                      color:
                                          product.profit >=
                                                  0
                                              ? AppColors
                                                  .success
                                              : AppColors
                                                  .danger,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                        .toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // INVOICE LIST
  // ===========================================================================

  Widget _buildInvoiceSection(
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
                'Invoice-wise Sales',
            subtitle:
                '${sales.length} matching invoice${sales.length == 1 ? '' : 's'}',
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
                return _InvoiceTile(
                  sale: sale,
                  currency: _currency,
                  date: _date,
                  statusColor:
                      _statusColor,
                  onTap: () {
                    _showSaleDetails(
                      sale,
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
  // SALE DETAILS
  // ===========================================================================

  void _showSaleDetails(
    SaleModel sale,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final ThemeData theme =
            Theme.of(sheetContext);

        final double profit =
            sale.items.fold(
          0,
          (sum, item) {
            return sum +
                (item.sellingRate -
                        item.costPrice) *
                    item.quantity;
          },
        );

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
                    sale.invoiceNumber
                            .trim()
                            .isEmpty
                        ? 'Sale Details'
                        : sale.invoiceNumber,
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
                    _date(sale.date),
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

                  _DetailInfoRow(
                    label: 'Customer',
                    value:
                        sale.customerName
                                .trim()
                                .isEmpty
                            ? 'Walk-in Customer'
                            : sale.customerName,
                  ),

                  _DetailInfoRow(
                    label: 'Subtotal',
                    value:
                        _currency(
                      sale.subtotal,
                    ),
                  ),

                  _DetailInfoRow(
                    label: 'Discount',
                    value:
                        _currency(
                      sale.discount,
                    ),
                  ),

                  _DetailInfoRow(
                    label: 'Tax',
                    value:
                        _currency(
                      sale.tax,
                    ),
                  ),

                  _DetailInfoRow(
                    label: 'Total',
                    value:
                        _currency(
                      sale.total,
                    ),
                    bold: true,
                  ),

                  _DetailInfoRow(
                    label: 'Paid',
                    value:
                        _currency(
                      sale.paidAmount,
                    ),
                  ),

                  _DetailInfoRow(
                    label: 'Outstanding',
                    value:
                        _currency(
                      sale.total -
                          sale.paidAmount >
                          0
                          ? sale.total -
                              sale.paidAmount
                          : 0,
                    ),
                  ),

                  _DetailInfoRow(
                    label:
                        'Gross Profit',
                    value:
                        _currency(profit),
                    valueColor:
                        profit >= 0
                            ? AppColors
                                .success
                            : AppColors
                                .danger,
                    bold: true,
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Products',
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
                      final double
                          itemProfit =
                          (item.sellingRate -
                                  item.costPrice) *
                              item.quantity;

                      return Container(
                        margin:
                            const EdgeInsets
                                .only(
                          bottom: 10,
                        ),
                        padding:
                            const EdgeInsets.all(
                          13,
                        ),
                        decoration:
                            BoxDecoration(
                          color: theme
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),

                            const SizedBox(
                              height: 6,
                            ),

                            Text(
                              '${_number(item.quantity)} ${item.unit} × ${_currency(item.sellingRate)}',
                              style:
                                  theme.textTheme.bodySmall,
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Total: ${_currency(item.total)}',
                                  ),
                                ),
                                Text(
                                  'Profit: ${_currency(itemProfit)}',
                                  style:
                                      TextStyle(
                                    color: itemProfit >=
                                            0
                                        ? AppColors
                                            .success
                                        : AppColors
                                            .danger,
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

                  if (sale.notes
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 8),

                    Text(
                      'Notes',
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      sale.notes,
                      style: theme
                          .textTheme
                          .bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // FOOTER
  // ===========================================================================

  Widget _buildReportFooter(
    ThemeData theme,
    List<SaleModel> sales,
  ) {
    return _ReportCard(
      child: Wrap(
        spacing: 24,
        runSpacing: 14,
        children: [
          _FooterMetric(
            label: 'Invoices',
            value:
                sales.length.toString(),
          ),
          _FooterMetric(
            label: 'Items Sold',
            value:
                _number(
              _totalQuantity(sales),
            ),
          ),
          _FooterMetric(
            label: 'Sales Cost',
            value:
                _currency(
              _totalCost(sales),
            ),
          ),
          _FooterMetric(
            label: 'Profit Margin',
            value:
                '${_profitMargin(sales).toStringAsFixed(2)}%',
          ),
          _FooterMetric(
            label: 'Collection Rate',
            value:
                '${_collectionRate(sales).toStringAsFixed(2)}%',
          ),
        ],
      ),
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

                const SizedBox(
                  height: 16,
                ),

                Text(
                  'Unable to load Sales Report',
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
                      .bodyMedium
                      ?.copyWith(
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

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

class _CustomerSalesSummary {
  final String name;
  final double sales;
  final double collected;
  final double outstanding;
  final double profit;
  final int invoiceCount;

  const _CustomerSalesSummary({
    required this.name,
    this.sales = 0,
    this.collected = 0,
    this.outstanding = 0,
    this.profit = 0,
    this.invoiceCount = 0,
  });
}

class _ProductSalesSummary {
  final String name;
  final double quantity;
  final double revenue;
  final double cost;
  final double profit;
  final int invoiceCount;
  final String unit;

  const _ProductSalesSummary({
    required this.name,
    this.quantity = 0,
    this.revenue = 0,
    this.cost = 0,
    this.profit = 0,
    this.invoiceCount = 0,
    this.unit = '',
  });
}

class _StatusItem {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatusItem({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });
}

// =============================================================================
// COMMON CARD
// =============================================================================

class _ReportCard extends StatelessWidget {
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
        color: theme
            .colorScheme
            .surface,
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
            color: Colors.black
                .withValues(
              alpha: theme.brightness ==
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

class _SummaryCard extends StatelessWidget {
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
        color: theme
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: item.color.withValues(
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
                  color: item.color
                      .withValues(
                    alpha: 0.10,
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
                  size: 21,
                ),
              ),

              const Spacer(),

              Icon(
                Icons.arrow_outward_rounded,
                color: item.color
                    .withValues(
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

class _SectionHeader extends StatelessWidget {
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
            color: theme
                .colorScheme
                .primary,
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
// STATUS TILE
// =============================================================================

class _StatusTile extends StatelessWidget {
  final _StatusItem item;

  const _StatusTile({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.color.withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: item.color.withValues(
            alpha: 0.16,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            item.icon,
            color: item.color,
            size: 23,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              item.label,
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
            item.count.toString(),
            style: theme
                .textTheme
                .titleMedium
                ?.copyWith(
              color: item.color,
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
// FILTER CHIP
// =============================================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    final Color activeColor =
        color ??
            theme.colorScheme.primary;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) =>
          onSelected(),
      selectedColor:
          activeColor.withValues(
        alpha: 0.14,
      ),
      side: BorderSide(
        color: selected
            ? activeColor
            : theme
                .colorScheme
                .outlineVariant,
      ),
      labelStyle:
          TextStyle(
        color: selected
            ? activeColor
            : theme
                .colorScheme
                .onSurface,
        fontWeight:
            selected
                ? FontWeight.w700
                : FontWeight.w500,
      ),
    );
  }
}

// =============================================================================
// CUSTOMER TILE
// =============================================================================

class _CustomerSalesTile
    extends StatelessWidget {
  final _CustomerSalesSummary summary;

  const _CustomerSalesTile({
    required this.summary,
  });

  String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

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
          alpha: 0.42,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(
              color: AppColors.primary
                  .withValues(
                alpha: 0.10,
              ),
              shape:
                  BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color:
                  AppColors.primary,
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
                  summary.name,
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

                const SizedBox(
                    height: 4),

                Text(
                  '${summary.invoiceCount} invoice${summary.invoiceCount == 1 ? '' : 's'}',
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

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                _currency(
                  summary.sales,
                ),
                style: theme
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                  height: 3),

              Text(
                'Pending ${_currency(summary.outstanding)}',
                style: TextStyle(
                  color:
                      summary.outstanding >
                              0
                          ? AppColors
                              .warning
                          : AppColors
                              .success,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PRODUCT TILE
// =============================================================================

class _ProductSalesTile
    extends StatelessWidget {
  final _ProductSalesSummary summary;

  const _ProductSalesTile({
    required this.summary,
  });

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
          alpha: 0.42,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.name,
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
                _currency(
                  summary.revenue,
                ),
                style: theme
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                'Qty: ${_number(summary.quantity)} ${summary.unit}',
                style: theme
                    .textTheme
                    .bodySmall,
              ),
              Text(
                'Cost: ${_currency(summary.cost)}',
                style: theme
                    .textTheme
                    .bodySmall,
              ),
              Text(
                'Profit: ${_currency(summary.profit)}',
                style: TextStyle(
                  color: summary.profit >=
                          0
                      ? AppColors.success
                      : AppColors.danger,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// INVOICE TILE
// =============================================================================

class _InvoiceTile
    extends StatelessWidget {
  final SaleModel sale;
  final String Function(double) currency;
  final String Function(DateTime) date;
  final Color Function(String) statusColor;
  final VoidCallback onTap;

  const _InvoiceTile({
    required this.sale,
    required this.currency,
    required this.date,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    final Color color =
        statusColor(
      sale.paymentStatus,
    );

    final double outstanding =
        sale.total - sale.paidAmount;

    final String customer =
        sale.customerName
                .trim()
                .isEmpty
            ? 'Walk-in Customer'
            : sale.customerName;

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
        decoration:
            BoxDecoration(
          color: theme
              .colorScheme
              .surfaceContainerHighest
              .withValues(
            alpha: 0.40,
          ),
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          border: Border.all(
            color: theme
                .colorScheme
                .outlineVariant
                .withValues(
              alpha: 0.35,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(
                color:
                    color.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: color,
                size: 22,
              ),
            ),

            const SizedBox(
                width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    sale.invoiceNumber
                            .trim()
                            .isEmpty
                        ? 'Sale'
                        : sale.invoiceNumber,
                    style: theme
                        .textTheme
                        .bodyLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                      height: 4),

                  Text(
                    customer,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style: theme
                        .textTheme
                        .bodySmall,
                  ),

                  const SizedBox(
                      height: 3),

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
                ],
              ),
            ),

            const SizedBox(
                width: 10),

            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  currency(
                    sale.total,
                  ),
                  style: theme
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                    height: 5),

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration:
                      BoxDecoration(
                    color: color
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),
                  ),
                  child: Text(
                    sale.paymentStatus,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),

                if (outstanding > 0)
                  Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      top: 4,
                    ),
                    child: Text(
                      'Due ${currency(outstanding)}',
                      style:
                          const TextStyle(
                        color:
                            AppColors.warning,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(
                width: 5),

            const Icon(
              Icons.chevron_right_rounded,
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DETAIL ROW
// =============================================================================

class _DetailInfoRow
    extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _DetailInfoRow({
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
        bottom: 9,
      ),
      child: Row(
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
          Text(
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
          const SizedBox(
              height: 10),
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

// =============================================================================
// FOOTER METRIC
// =============================================================================

class _FooterMetric
    extends StatelessWidget {
  final String label;
  final String value;

  const _FooterMetric({
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