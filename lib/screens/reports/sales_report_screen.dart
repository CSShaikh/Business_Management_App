import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/sale_model.dart';
import '../../models/payment_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/sale_repository.dart';
import '../../repositories/payment_repository.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({
    super.key,
  });

  @override
  State<SalesReportScreen> createState() =>
      _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final SaleRepository _saleRepository =
      SaleRepository();

  final PaymentRepository _paymentRepository =
      PaymentRepository();

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
  List<PaymentModel> _allPayments = <PaymentModel>[];

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

      final List<dynamic> result =
          await Future.wait<dynamic>([
        _saleRepository.getSales(
          businessId: business.id,
        ),
        _paymentRepository.getPayments(
          businessId: business.id,
        ),
      ]);

      final List<SaleModel> sales =
          result[0] as List<SaleModel>;

      final List<PaymentModel> payments =
          result[1] as List<PaymentModel>;

      if (!mounted) return;

      setState(() {
        _allSales = sales;
        _allPayments = payments;
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
              : null,
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
    final String query =
        _searchQuery.trim().toLowerCase();

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
          sale.invoiceNumber
              .toLowerCase()
              .contains(query);

      final bool customerMatch =
          sale.customerName
              .toLowerCase()
              .contains(query);

      final bool notesMatch =
          sale.notes
              .toLowerCase()
              .contains(query);

      final bool productMatch =
          sale.items.any(
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
  // FILTERED CUSTOMER PAYMENTS
  // ===========================================================================

  List<PaymentModel> get _filteredPayments {
    return _allPayments.where((payment) {
      if (_startDate != null &&
          payment.date.isBefore(_startDate!)) {
        return false;
      }

      if (_endDate != null &&
          payment.date.isAfter(_endDate!)) {
        return false;
      }

      return true;
    }).toList();
  }

  // ===========================================================================
  // CALCULATIONS
  // ===========================================================================

  double _totalSales(List<SaleModel> sales) {
    return sales.fold<double>(
      0,
      (sum, sale) => sum + sale.total,
    );
  }

  double _totalCollected(
    List<SaleModel> sales,
    List<PaymentModel> payments,
  ) {
    final double saleLevelPaid =
        sales.fold<double>(
      0,
      (sum, sale) => sum + sale.paidAmount,
    );

    final double separatePayments =
        payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );

    return saleLevelPaid + separatePayments;
  }

  double _totalOutstanding(
    List<SaleModel> sales,
    List<PaymentModel> payments,
  ) {
    final double totalSales =
        _totalSales(sales);

    final double collected =
        _totalCollected(
      sales,
      payments,
    );

    final double outstanding =
        totalSales - collected;

    return outstanding > 0
        ? outstanding
        : 0;
  }

  double _saleGrossProfit(
    SaleModel sale,
  ) {
    double cost = 0;

    for (final item in sale.items) {
      cost +=
          item.costPrice *
              item.quantity;
    }

    return sale.total - cost;
  }

  double _totalGrossProfit(
    List<SaleModel> sales,
  ) {
    return sales.fold<double>(
      0,
      (sum, sale) =>
          sum + _saleGrossProfit(sale),
    );
  }

  double _totalCost(
    List<SaleModel> sales,
  ) {
    double total = 0;

    for (final sale in sales) {
      for (final item in sale.items) {
        total +=
            item.costPrice *
                item.quantity;
      }
    }

    return total;
  }

  double _totalQuantity(
    List<SaleModel> sales,
  ) {
    double total = 0;

    for (final sale in sales) {
      for (final item in sale.items) {
        total += item.quantity;
      }
    }

    return total;
  }

  double _profitMargin(
    List<SaleModel> sales,
  ) {
    final double salesAmount =
        _totalSales(sales);

    if (salesAmount <= 0) {
      return 0;
    }

    return (_totalGrossProfit(sales) /
            salesAmount) *
        100;
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

  // ===========================================================================
  // GROUPING
  // ===========================================================================

  Map<String, _CustomerSalesSummary>
      _customerWiseSales(
    List<SaleModel> sales,
    List<PaymentModel> payments,
  ) {
    final Map<String, _CustomerSalesSummary>
        result =
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

      final double profit =
          _saleGrossProfit(sale);

      result[customerName] =
          _CustomerSalesSummary(
        name: customerName,
        sales:
            existing.sales +
                sale.total,
        collected:
            existing.collected +
                sale.paidAmount,
        outstanding:
            existing.outstanding +
                (outstanding > 0
                    ? outstanding
                    : 0),
        profit:
            existing.profit +
                profit,
        invoiceCount:
            existing.invoiceCount +
                1,
      );
    }

    // Separate customer-payment records are
    // added exactly once per customer.
    for (final payment in payments) {
      final String customerName =
          payment.customerName.trim().isEmpty
              ? 'Walk-in Customer'
              : payment.customerName.trim();

      final _CustomerSalesSummary existing =
          result[customerName] ??
              _CustomerSalesSummary(
                name: customerName,
              );

      final double collected =
          existing.collected +
              payment.amount;

      final double outstanding =
          existing.sales -
              collected;

      result[customerName] =
          _CustomerSalesSummary(
        name: customerName,
        sales: existing.sales,
        collected: collected,
        outstanding:
            outstanding > 0
                ? outstanding
                : 0,
        profit: existing.profit,
        invoiceCount:
            existing.invoiceCount,
      );
    }

    final List<_CustomerSalesSummary>
        values =
        result.values.toList();

    values.sort(
      (a, b) =>
          b.sales.compareTo(a.sales),
    );

    return <String,
        _CustomerSalesSummary>{
      for (final item in values)
        item.name: item,
    };
  }

  Map<String, _ProductSalesSummary>
      _productWiseSales(
    List<SaleModel> sales,
  ) {
    final Map<String, _ProductSalesSummary>
        result =
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

        final double itemRevenue =
            item.quantity *
                item.sellingRate;

        final double cost =
            item.costPrice *
                item.quantity;

        final double saleAdjustment =
            sale.total -
                sale.subtotal;

        final double allocatedAdjustment =
            sale.subtotal > 0 &&
                    sale.subtotal.isFinite
                ? saleAdjustment *
                    (itemRevenue /
                        sale.subtotal)
                : 0;

        final double revenue =
            itemRevenue +
                allocatedAdjustment;

        final double profit =
            revenue - cost;

        result[productName] =
            _ProductSalesSummary(
          name: productName,
          quantity:
              existing.quantity +
                  item.quantity,
          revenue:
              existing.revenue +
                  revenue,
          cost:
              existing.cost +
                  cost,
          profit:
              existing.profit +
                  profit,
          invoiceCount:
              existing.invoiceCount +
                  1,
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
        return sale.paymentStatus
                .toLowerCase() ==
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
        ' - '
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

    return RefreshIndicator(
      onRefresh: _refreshReport,
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

                    const SizedBox(
                      height: 20,
                    ),

                    _buildSummaryCards(
                      theme,
                      sales,
                      _filteredPayments,
                      isDesktop,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildPaymentStatusSection(
                      theme,
                      sales,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildSearchAndFilters(
                      theme,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildCustomerWiseSection(
                      theme,
                      sales,
                      _filteredPayments,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildProductWiseSection(
                      theme,
                      sales,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildInvoiceSection(
                      theme,
                      sales,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildReportFooter(
                      theme,
                      sales,
                      _filteredPayments,
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
                'Sales Report',
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
                'Analyze sales, collections, '
                'customers and product performance.',
                style:
                    theme.textTheme.bodyMedium
                        ?.copyWith(
                  color: theme
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (isDesktop)
          OutlinedButton.icon(
            onPressed:
                _refreshing
                    ? null
                    : _refreshReport,
            icon:
                _refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                      ),
            label:
                const Text('Refresh'),
          )
        else
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _refreshing
                    ? null
                    : _refreshReport,
            icon:
                _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
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
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _selectDateRange,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration:
                    BoxDecoration(
                  border: Border.all(
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
                    Icon(
                      Icons
                          .date_range_rounded,
                      size: 20,
                      color:
                          AppColors.primary,
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
                            style: theme
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                              color: theme
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(
                            height: 2,
                          ),
                          Text(
                            _dateRangeText(),
                            style: theme
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons
                          .keyboard_arrow_down_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasFilter)
            const SizedBox(width: 10),
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

  Widget _buildSummaryCards(
    ThemeData theme,
    List<SaleModel> sales,
    List<PaymentModel> payments,
    bool isDesktop,
  ) {
    final double totalSales =
        _totalSales(sales);

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

    final double profit =
        _totalGrossProfit(sales);

    final List<_SummaryItem> items = [
      _SummaryItem(
        title: 'Total Sales',
        value:
            _currency(totalSales),
        subtitle:
            '${sales.length} invoices',
        icon:
            Icons.trending_up_rounded,
        color:
            AppColors.primary,
      ),
      _SummaryItem(
        title: 'Collected',
        value:
            _currency(collected),
        subtitle:
            '${_collectionRate(sales, payments).toStringAsFixed(1)}% collection',
        icon:
            Icons.payments_rounded,
        color:
            AppColors.success,
      ),
      _SummaryItem(
        title: 'Outstanding',
        value:
            _currency(outstanding),
        subtitle:
            'Customer receivable',
        icon:
            Icons
                .account_balance_wallet_rounded,
        color:
            AppColors.warning,
      ),
      _SummaryItem(
        title: 'Gross Profit',
        value:
            _currency(profit),
        subtitle:
            '${_profitMargin(sales).toStringAsFixed(1)}% margin',
        icon:
            Icons.auto_graph_rounded,
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
            isDesktop ? 4 : 2,
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
      'paid',
    );

    final int partial =
        _countStatus(
      sales,
      'partial',
    );

    final int unpaid =
        _countStatus(
      sales,
      'unpaid',
    );

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons
                    .pie_chart_rounded,
            title:
                'Payment Status',
            subtitle:
                'Invoice-level payment status distribution',
          ),
          const SizedBox(
            height: 18,
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatusChip(
                label: 'Paid',
                count: paid,
                color:
                    AppColors.success,
              ),
              _StatusChip(
                label: 'Partial',
                count: partial,
                color:
                    AppColors.warning,
              ),
              _StatusChip(
                label: 'Unpaid',
                count: unpaid,
                color:
                    AppColors.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEARCH + FILTERS
  // ===========================================================================

  Widget _buildSearchAndFilters(
    ThemeData theme,
  ) {
    return _ReportCard(
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final bool compact =
              constraints.maxWidth <
                  700;

          final Widget search =
              TextField(
            controller:
                _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery =
                    value;
              });
            },
            decoration:
                InputDecoration(
              hintText:
                  'Search invoice, customer, notes or product',
              prefixIcon:
                  const Icon(
                Icons.search_rounded,
              ),
              suffixIcon:
                  _searchQuery.isEmpty
                      ? null
                      : IconButton(
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
                            Icons
                                .clear_rounded,
                          ),
                        ),
            ),
          );

          final Widget filter =
              DropdownButtonFormField<
                  String>(
            initialValue:
                _paymentFilter,
            decoration:
                const InputDecoration(
              labelText:
                  'Payment Status',
              prefixIcon:
                  Icon(
                Icons
                    .filter_alt_rounded,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'All',
                child:
                    Text('All'),
              ),
              DropdownMenuItem(
                value: 'Paid',
                child:
                    Text('Paid'),
              ),
              DropdownMenuItem(
                value: 'Partial',
                child:
                    Text('Partial'),
              ),
              DropdownMenuItem(
                value: 'Unpaid',
                child:
                    Text('Unpaid'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _paymentFilter =
                    value;
              });
            },
          );

          if (compact) {
            return Column(
              children: [
                search,
                const SizedBox(
                  height: 12,
                ),
                filter,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 2,
                child: search,
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: filter,
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // CUSTOMER-WISE
  // ===========================================================================

  Widget _buildCustomerWiseSection(
    ThemeData theme,
    List<SaleModel> sales,
    List<PaymentModel> payments,
  ) {
    final Map<String,
            _CustomerSalesSummary>
        customers =
        _customerWiseSales(
      sales,
      payments,
    );

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
          const SizedBox(
            height: 18,
          ),
          if (values.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.groups_outlined,
              message:
                  'No customer sales available for the selected filters.',
            )
          else
            ...values
                .take(10)
                .map(
              (customer) {
                return _CustomerSalesTile(
                  summary:
                      customer,
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
    final Map<String,
            _ProductSalesSummary>
        products =
        _productWiseSales(sales);

    final List<_ProductSalesSummary>
        values =
        products.values.toList()
          ..sort(
            (a, b) =>
                b.revenue.compareTo(
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
                Icons
                    .inventory_2_rounded,
            title:
                'Product-wise Sales',
            subtitle:
                'Revenue, quantity and profit by product',
          ),
          const SizedBox(
            height: 18,
          ),
          if (values.isEmpty)
            const _EmptyInline(
              icon:
                  Icons
                      .inventory_2_outlined,
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
                    columnSpacing:
                        28,
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
                                product
                                    .name,
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
                                      FontWeight
                                          .w700,
                                ),
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
                'Invoice Details',
            subtitle:
                'Detailed sales invoice performance',
          ),
          const SizedBox(
            height: 18,
          ),
          if (sales.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.receipt_long_outlined,
              message:
                  'No sales available for the selected filters.',
            )
          else
            ...sales
                .take(30)
                .map(
              (sale) {
                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: _InvoiceTile(
                    sale: sale,
                    currency:
                        _currency,
                    date: _date,
                    statusColor:
                        _statusColor,
                    onTap: () =>
                        _showSaleDetails(
                      sale,
                    ),
                  ),
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
            _saleGrossProfit(sale);

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
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    sale.invoiceNumber
                            .trim()
                            .isEmpty
                        ? 'Sale Details'
                        : sale.invoiceNumber,
                    style: theme
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    _date(sale.date),
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color: theme
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(
                    height: 18,
                  ),
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
                    label: 'Payment Method',
                    value:
                        sale.paymentMethod
                                .trim()
                                .isEmpty
                            ? 'Not specified'
                            : sale.paymentMethod,
                  ),
                  _DetailInfoRow(
                    label: 'Payment Status',
                    value:
                        sale.paymentStatus,
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
                  if (sale.notes
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Notes',
                      style: theme
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
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
                  const SizedBox(
                    height: 18,
                  ),
                  Text(
                    'Items',
                    style: theme
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  ...sale.items.map(
                    (item) {
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
                          border: Border.all(
                            color: theme
                                .dividerColor,
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
                                          FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ),
                                  Text(
                                    '${_number(item.quantity)} ${item.unit} × ${_currency(item.sellingRate)}',
                                    style: theme
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                      color: theme
                                          .textTheme
                                          .bodySmall
                                          ?.color
                                          ?.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            Text(
                              _currency(
                                item.total,
                              ),
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
  // FOOTER
  // ===========================================================================

  Widget _buildReportFooter(
    ThemeData theme,
    List<SaleModel> sales,
    List<PaymentModel> payments,
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
            label: 'Customer Payments',
            value:
                _currency(
              payments.fold<double>(
                0,
                (sum, payment) =>
                    sum + payment.amount,
              ),
            ),
          ),
          _FooterMetric(
            label: 'Collection Rate',
            value:
                '${_collectionRate(sales, payments).toStringAsFixed(2)}%',
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
        child: _ReportCard(
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
                'Unable to load sales report',
                style: theme
                    .textTheme
                    .titleMedium
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
                style: theme
                    .textTheme
                    .bodyMedium,
                textAlign:
                    TextAlign.center,
              ),
              const SizedBox(
                height: 16,
              ),
              ElevatedButton.icon(
                onPressed:
                    _loadReport,
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

// =============================================================================
// SUMMARY MODEL
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

// =============================================================================
// CUSTOMER SUMMARY
// =============================================================================

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

// =============================================================================
// PRODUCT SUMMARY
// =============================================================================

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

// =============================================================================
// REPORT CARD
// =============================================================================

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
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: theme
            .cardColor,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color:
              theme.dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.04,
            ),
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
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color: item.color
                      .withValues(
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
                  size: 21,
                ),
              ),
              const Spacer(),
              Icon(
                Icons
                    .arrow_outward_rounded,
                size: 18,
                color: theme
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(
                  alpha: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.title,
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              fontWeight:
                  FontWeight.w600,
              color: theme
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(
                alpha: 0.7,
              ),
            ),
          ),
          const SizedBox(
            height: 4,
          ),
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
          const SizedBox(
            height: 2,
          ),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              color: theme
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(
                alpha: 0.6,
              ),
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
          width: 42,
          height: 42,
          decoration:
              BoxDecoration(
            color: AppColors.primary
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
                AppColors.primary,
            size: 21,
          ),
        ),
        const SizedBox(
          width: 12,
        ),
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
              const SizedBox(
                height: 3,
              ),
              Text(
                subtitle,
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: theme
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
// STATUS CHIP
// =============================================================================

class _StatusChip
    extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(alpha: 0.10),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color:
              color.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration:
                BoxDecoration(
              color: color,
              shape:
                  BoxShape.circle,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
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
// CUSTOMER TILE
// =============================================================================

class _CustomerSalesTile
    extends StatelessWidget {
  final _CustomerSalesSummary
      summary;

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
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        border: Border.all(
          color:
              theme.dividerColor,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final bool compact =
              constraints.maxWidth <
                  600;

          final Widget customer =
              Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  summary.name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  '${summary.invoiceCount} invoice${summary.invoiceCount == 1 ? '' : 's'}',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: theme
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
          );

          final Widget metrics =
              compact
                  ? Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 12,
                      ),
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 10,
                        children: [
                          _MiniMetric(
                            label: 'Sales',
                            value:
                                _currency(
                              summary.sales,
                            ),
                          ),
                          _MiniMetric(
                            label:
                                'Collected',
                            value:
                                _currency(
                              summary
                                  .collected,
                            ),
                          ),
                          _MiniMetric(
                            label:
                                'Outstanding',
                            value:
                                _currency(
                              summary
                                  .outstanding,
                            ),
                          ),
                          _MiniMetric(
                            label: 'Profit',
                            value:
                                _currency(
                              summary.profit,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        _MiniMetric(
                          label: 'Sales',
                          value:
                              _currency(
                            summary.sales,
                          ),
                        ),
                        const SizedBox(
                          width: 22,
                        ),
                        _MiniMetric(
                          label: 'Collected',
                          value:
                              _currency(
                            summary
                                .collected,
                          ),
                        ),
                        const SizedBox(
                          width: 22,
                        ),
                        _MiniMetric(
                          label:
                              'Outstanding',
                          value:
                              _currency(
                            summary
                                .outstanding,
                          ),
                        ),
                        const SizedBox(
                          width: 22,
                        ),
                        _MiniMetric(
                          label: 'Profit',
                          value:
                              _currency(
                            summary.profit,
                          ),
                        ),
                      ],
                    );

          if (compact) {
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                customer,
                metrics,
              ],
            );
          }

          return Row(
            children: [
              customer,
              metrics,
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// PRODUCT TILE
// =============================================================================

class _ProductSalesTile
    extends StatelessWidget {
  final _ProductSalesSummary
      summary;

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
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        border: Border.all(
          color:
              theme.dividerColor,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Text(
            summary.name,
            style: theme
                .textTheme
                .bodyMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _MiniMetric(
                label: 'Quantity',
                value:
                    '${_number(summary.quantity)} ${summary.unit}',
              ),
              _MiniMetric(
                label: 'Revenue',
                value:
                    _currency(
                  summary.revenue,
                ),
              ),
              _MiniMetric(
                label: 'Cost',
                value:
                    _currency(
                  summary.cost,
                ),
              ),
              _MiniMetric(
                label: 'Profit',
                value:
                    _currency(
                  summary.profit,
                ),
                valueColor:
                    summary.profit >= 0
                        ? AppColors.success
                        : AppColors.danger,
              ),
            ],
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
  final Color? valueColor;

  const _MiniMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme
              .textTheme
              .labelSmall
              ?.copyWith(
            color: theme
                .textTheme
                .labelSmall
                ?.color
                ?.withValues(
              alpha: 0.65,
            ),
          ),
        ),
        const SizedBox(
          height: 2,
        ),
        Text(
          value,
          style: theme
              .textTheme
              .bodySmall
              ?.copyWith(
            fontWeight:
                FontWeight.w800,
            color:
                valueColor,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// INVOICE TILE
// =============================================================================

class _InvoiceTile
    extends StatelessWidget {
  final SaleModel sale;
  final String Function(double)
      currency;
  final String Function(DateTime)
      date;
  final Color Function(String)
      statusColor;
  final VoidCallback onTap;

  const _InvoiceTile({
    required this.sale,
    required this.currency,
    required this.date,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final Color color =
        statusColor(
      sale.paymentStatus,
    );

    final double outstanding =
        sale.total -
            sale.paidAmount;

    final String customer =
        sale.customerName
                .trim()
                .isEmpty
            ? 'Walk-in Customer'
            : sale.customerName;

    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(
        14,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          14,
        ),
        decoration:
            BoxDecoration(
          border: Border.all(
            color:
                theme.dividerColor,
          ),
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool compact =
                constraints.maxWidth <
                    650;

            final Widget mainInfo =
                Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sale.invoiceNumber
                                  .trim()
                                  .isEmpty
                              ? 'Invoice'
                              : sale.invoiceNumber,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: theme
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
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
                            8,
                          ),
                        ),
                        child: Text(
                          sale.paymentStatus,
                          style:
                              TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    customer,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: theme
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(
                        alpha: 0.70,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    date(sale.date),
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: theme
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(
                        alpha: 0.60,
                      ),
                    ),
                  ),
                ],
              ),
            );

            final Widget financials =
                compact
                    ? Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          top: 12,
                        ),
                        child: Wrap(
                          spacing: 18,
                          runSpacing: 10,
                          children: [
                            _MiniMetric(
                              label: 'Total',
                              value:
                                  currency(
                                sale.total,
                              ),
                            ),
                            _MiniMetric(
                              label: 'Paid',
                              value:
                                  currency(
                                sale.paidAmount,
                              ),
                            ),
                            _MiniMetric(
                              label:
                                  'Outstanding',
                              value:
                                  currency(
                                outstanding >
                                        0
                                    ? outstanding
                                    : 0,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          _MiniMetric(
                            label: 'Total',
                            value:
                                currency(
                              sale.total,
                            ),
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          _MiniMetric(
                            label: 'Paid',
                            value:
                                currency(
                              sale.paidAmount,
                            ),
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          _MiniMetric(
                            label:
                                'Outstanding',
                            value:
                                currency(
                              outstanding >
                                      0
                                  ? outstanding
                                  : 0,
                            ),
                          ),
                        ],
                      );

            if (compact) {
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  mainInfo,
                  financials,
                ],
              );
            }

            return Row(
              children: [
                mainInfo,
                financials,
                const SizedBox(
                  width: 12,
                ),
                const Icon(
                  Icons
                      .chevron_right_rounded,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// DETAIL INFO ROW
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
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
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
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(
                      alpha: 0.70,
                    ),
              ),
            ),
          ),
          const SizedBox(
            width: 16,
          ),
          Flexible(
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                fontWeight:
                    bold
                        ? FontWeight.w800
                        : FontWeight.w600,
                color:
                    valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EMPTY INLINE
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
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 28,
        horizontal: 18,
      ),
      decoration:
          BoxDecoration(
        border: Border.all(
          color:
              theme.dividerColor,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 38,
            color: theme
                .textTheme
                .bodySmall
                ?.color
                ?.withValues(
              alpha: 0.45,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            message,
            textAlign:
                TextAlign.center,
            style: theme
                .textTheme
                .bodyMedium
                ?.copyWith(
              color: theme
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withValues(
              alpha: 0.65,
            ),
          ),),
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
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme
              .textTheme
              .labelSmall
              ?.copyWith(
            color: theme
                .textTheme
                .labelSmall
                ?.color
                ?.withValues(
              alpha: 0.65,
            ),
          ),
        ),
        const SizedBox(
          height: 3,
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
    );
  }
}