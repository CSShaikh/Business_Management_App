import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../models/sale_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/sale_repository.dart';

class CustomerReportScreen extends StatefulWidget {
  const CustomerReportScreen({
    super.key,
  });

  @override
  State<CustomerReportScreen> createState() =>
      _CustomerReportScreenState();
}

class _CustomerReportScreenState
    extends State<CustomerReportScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final CustomerRepository _customerRepository =
      CustomerRepository();

  final SaleRepository _saleRepository =
      SaleRepository();

  final TextEditingController _searchController =
      TextEditingController();

  bool _loading = true;
  bool _refreshing = false;

  String? _errorMessage;

  DateTime? _startDate;
  DateTime? _endDate;

  String _searchQuery = '';

  List<CustomerModel> _customers = <CustomerModel>[];
  List<SaleModel> _sales = <SaleModel>[];

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
        _customerRepository.getCustomers(
          businessId: business.id,
        ),
        _saleRepository.getSales(
          businessId: business.id,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _customers =
            results[0] as List<CustomerModel>;

        _sales =
            results[1] as List<SaleModel>;

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
    final DateTimeRange? range =
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

    if (range == null) return;

    setState(() {
      _startDate = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );

      _endDate = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
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
    return _sales.where((sale) {
      final DateTime date = sale.date;

      if (_startDate != null &&
          date.isBefore(_startDate!)) {
        return false;
      }

      if (_endDate != null &&
          date.isAfter(_endDate!)) {
        return false;
      }

      return true;
    }).toList();
  }

  List<CustomerModel> get _filteredCustomers {
    final String query =
        _searchQuery.trim().toLowerCase();

    final Set<String> customerIds =
        _filteredSales
            .map(
              (sale) => sale.customerId.trim(),
            )
            .where(
              (id) => id.isNotEmpty,
            )
            .toSet();

    final List<CustomerModel> customers =
        _customers.where((customer) {
      final bool matchesSearch =
          query.isEmpty ||
          customer.name
              .toLowerCase()
              .contains(query) ||
          customer.mobile
              .toLowerCase()
              .contains(query) ||
          customer.email
              .toLowerCase()
              .contains(query) ||
          customer.address
              .toLowerCase()
              .contains(query) ||
          customer.gstNumber
              .toLowerCase()
              .contains(query);

      if (!matchesSearch) {
        return false;
      }

      if (_startDate == null &&
          _endDate == null) {
        return true;
      }

      return customerIds.contains(
        customer.id,
      );
    }).toList();

    customers.sort(
      (a, b) => a.name
          .toLowerCase()
          .compareTo(
            b.name.toLowerCase(),
          ),
    );

    return customers;
  }

  // ===========================================================================
  // CUSTOMER SALES
  // ===========================================================================

  List<SaleModel> _customerSales(
    CustomerModel customer,
  ) {
    return _filteredSales.where((sale) {
      return sale.customerId.trim() ==
          customer.id.trim();
    }).toList();
  }

  double _customerSalesAmount(
    CustomerModel customer,
  ) {
    return _customerSales(customer).fold(
      0,
      (sum, sale) => sum + sale.total,
    );
  }

  double _customerReceivedAmount(
    CustomerModel customer,
  ) {
    return _customerSales(customer).fold(
      0,
      (sum, sale) => sum + sale.paidAmount,
    );
  }

  double _customerOutstandingAmount(
    CustomerModel customer,
  ) {
    return _customerSales(customer).fold(
      0,
      (sum, sale) {
        final double outstanding =
            sale.total - sale.paidAmount;

        return sum +
            (outstanding > 0
                ? outstanding
                : 0);
      },
    );
  }

  double _customerProfit(
    CustomerModel customer,
  ) {
    return _customerSales(customer).fold(
      0,
      (sum, sale) {
        final double saleProfit =
            sale.items.fold(
          0,
          (itemSum, item) {
            return itemSum +
                ((item.sellingRate -
                        item.costPrice) *
                    item.quantity);
          },
        );

        return sum + saleProfit;
      },
    );
  }

  int _customerInvoiceCount(
    CustomerModel customer,
  ) {
    return _customerSales(customer).length;
  }

  // ===========================================================================
  // GLOBAL CALCULATIONS
  // ===========================================================================

  double get _totalSales {
    return _filteredSales.fold(
      0,
      (sum, sale) => sum + sale.total,
    );
  }

  double get _totalReceived {
    return _filteredSales.fold(
      0,
      (sum, sale) => sum + sale.paidAmount,
    );
  }

  double get _totalOutstanding {
    return _filteredSales.fold(
      0,
      (sum, sale) {
        final double outstanding =
            sale.total - sale.paidAmount;

        return sum +
            (outstanding > 0
                ? outstanding
                : 0);
      },
    );
  }

  double get _totalProfit {
    return _filteredSales.fold(
      0,
      (sum, sale) {
        final double profit =
            sale.items.fold(
          0,
          (itemSum, item) {
            return itemSum +
                ((item.sellingRate -
                        item.costPrice) *
                    item.quantity);
          },
        );

        return sum + profit;
      },
    );
  }

  int get _activeCustomerCount {
    return _filteredCustomers.length;
  }

  double get _collectionRate {
    if (_totalSales <= 0) {
      return 0;
    }

    return (_totalReceived /
            _totalSales) *
        100;
  }

  // ===========================================================================
  // FORMATTERS
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

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(theme);
    }

    final List<CustomerModel> customers =
        _filteredCustomers;

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
                    _buildSummary(
                      isDesktop,
                    ),
                    const SizedBox(height: 20),
                    _buildHealthSection(),
                    const SizedBox(height: 20),
                    _buildFilters(theme),
                    const SizedBox(height: 20),
                    _buildCustomerList(
                      theme,
                      customers,
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
    final String dateText =
        _startDate != null &&
                _endDate != null
            ? '${_date(_startDate!)} - ${_date(_endDate!)}'
            : 'All dates';

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
              color: Colors.white.withValues(
                alpha: 0.15,
              ),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
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
                  'Customer / Hotel Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Analyse customer-wise sales, collections, outstanding amounts and profit.',
                  style: TextStyle(
                    color: Colors.white.withValues(
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
                    color:
                        Colors.white.withValues(
                      alpha: 0.14,
                    ),
                    borderRadius:
                        BorderRadius.circular(30),
                  ),
                  child: Text(
                    dateText,
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
              onPressed: _refreshing
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
  // SUMMARY
  // ===========================================================================

  Widget _buildSummary(
    bool isDesktop,
  ) {
    final List<_SummaryItem> items = [
      _SummaryItem(
        title: 'Customer Sales',
        value: _currency(_totalSales),
        subtitle:
            'Sales in selected period',
        icon:
            Icons.point_of_sale_rounded,
        color: AppColors.primary,
      ),
      _SummaryItem(
        title: 'Received',
        value:
            _currency(_totalReceived),
        subtitle:
            'Amount collected',
        icon:
            Icons.payments_rounded,
        color: AppColors.success,
      ),
      _SummaryItem(
        title: 'Outstanding',
        value:
            _currency(_totalOutstanding),
        subtitle:
            'Amount pending',
        icon:
            Icons.account_balance_wallet_rounded,
        color: AppColors.warning,
      ),
      _SummaryItem(
        title: 'Customers',
        value:
            _number(
          _activeCustomerCount.toDouble(),
        ),
        subtitle:
            'Customers in report',
        icon:
            Icons.groups_rounded,
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
        crossAxisCount:
            isDesktop ? 4 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio:
            isDesktop ? 1.85 : 1.48,
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
  // HEALTH
  // ===========================================================================

  Widget _buildHealthSection() {
    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon:
                Icons.insights_rounded,
            title: 'Customer Business Health',
            subtitle:
                'Collection and profitability overview',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              final bool compact =
                  constraints.maxWidth < 650;

              final List<Widget> cards = [
                _HealthTile(
                  title: 'Collection Rate',
                  value:
                      '${_collectionRate.toStringAsFixed(1)}%',
                  subtitle:
                      'Sales already received',
                  icon:
                      Icons.check_circle_rounded,
                  color:
                      AppColors.success,
                ),
                _HealthTile(
                  title: 'Customer Profit',
                  value:
                      _currency(_totalProfit),
                  subtitle:
                      'Gross profit from sales',
                  icon:
                      Icons.trending_up_rounded,
                  color:
                      AppColors.primary,
                ),
                _HealthTile(
                  title: 'Invoices',
                  value:
                      '${_filteredSales.length}',
                  subtitle:
                      'Sales invoices',
                  icon:
                      Icons.receipt_long_rounded,
                  color:
                      AppColors.secondary,
                ),
              ];

              if (compact) {
                return Column(
                  children: cards
                      .map(
                        (card) => Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            bottom: 10,
                          ),
                          child: card,
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: cards
                    .map(
                      (card) => Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .only(
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
      ),
    );
  }

  // ===========================================================================
  // FILTERS
  // ===========================================================================

  Widget _buildFilters(
    ThemeData theme,
  ) {
    final bool hasDateFilter =
        _startDate != null &&
            _endDate != null;

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Search & Filters',
            style: theme
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery =
                    value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText:
                  'Search customer, hotel, mobile, email or GST...',
              prefixIcon: const Icon(
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
                          icon: const Icon(
                            Icons.clear_rounded,
                          ),
                        )
                      : null,
            ),
          ),
          const SizedBox(height: 14),
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
                  hasDateFilter
                      ? '${_date(_startDate!)} - ${_date(_endDate!)}'
                      : 'Select Date Range',
                ),
              ),
              if (hasDateFilter)
                TextButton.icon(
                  onPressed:
                      _clearDateFilter,
                  icon: const Icon(
                    Icons.clear_rounded,
                  ),
                  label:
                      const Text('Clear Date'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CUSTOMER LIST
  // ===========================================================================

  Widget _buildCustomerList(
    ThemeData theme,
    List<CustomerModel> customers,
  ) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.groups_rounded,
            title:
                'Customer-wise Performance',
            subtitle:
                '${customers.length} customer${customers.length == 1 ? '' : 's'} found',
          ),
          const SizedBox(height: 18),
          if (customers.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.people_outline_rounded,
              message:
                  'No customers match the selected filters.',
            )
          else
            ...customers.map(
              (customer) {
                return _CustomerTile(
                  customer: customer,
                  sales:
                      _customerSales(customer),
                  totalSales:
                      _customerSalesAmount(
                    customer,
                  ),
                  received:
                      _customerReceivedAmount(
                    customer,
                  ),
                  outstanding:
                      _customerOutstandingAmount(
                    customer,
                  ),
                  profit:
                      _customerProfit(
                    customer,
                  ),
                  invoiceCount:
                      _customerInvoiceCount(
                    customer,
                  ),
                  currency: _currency,
                  onTap: () {
                    _showCustomerDetails(
                      customer,
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
  // CUSTOMER DETAILS
  // ===========================================================================

  void _showCustomerDetails(
    CustomerModel customer,
  ) {

    final List<SaleModel> sales =
        _customerSales(customer);

    final double salesAmount =
        _customerSalesAmount(customer);

    final double received =
        _customerReceivedAmount(customer);

    final double outstanding =
        _customerOutstandingAmount(
      customer,
    );

    final double profit =
        _customerProfit(customer);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final ThemeData sheetTheme =
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
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration:
                            BoxDecoration(
                          color: AppColors.primary
                              .withValues(
                            alpha: 0.10,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                        child: const Icon(
                          Icons
                              .business_rounded,
                          color:
                              AppColors.primary,
                          size: 25,
                        ),
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
                              customer.name,
                              style: sheetTheme
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            if (customer.mobile
                                .trim()
                                .isNotEmpty)
                              Text(
                                customer.mobile,
                                style: sheetTheme
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: sheetTheme
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _CustomerDetailSummary(
                    sales:
                        _currency(salesAmount),
                    received:
                        _currency(received),
                    outstanding:
                        _currency(
                      outstanding,
                    ),
                    profit:
                        _currency(profit),
                  ),
                  const SizedBox(height: 20),
                  _DetailRow(
                    label: 'Owner / Contact',
                    value:
                        customer.name,
                  ),
                  if (customer.mobile
                      .trim()
                      .isNotEmpty)
                    _DetailRow(
                      label: 'Mobile',
                      value:
                          customer.mobile,
                    ),
                  if (customer.email
                      .trim()
                      .isNotEmpty)
                    _DetailRow(
                      label: 'Email',
                      value:
                          customer.email,
                    ),
                  if (customer.address
                      .trim()
                      .isNotEmpty)
                    _DetailRow(
                      label: 'Address',
                      value:
                          customer.address,
                    ),
                  if (customer.gstNumber
                      .trim()
                      .isNotEmpty)
                    _DetailRow(
                      label: 'GST Number',
                      value:
                          customer.gstNumber,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Recent Sales',
                    style: sheetTheme
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (sales.isEmpty)
                    const _EmptyInline(
                      icon:
                          Icons.receipt_long_outlined,
                      message:
                          'No sales found for this customer in the selected period.',
                    )
                  else
                    ...sales.reversed
                        .take(10)
                        .map(
                      (sale) {
                        final double due =
                            sale.total -
                                sale.paidAmount;

                        return Container(
                          margin:
                              const EdgeInsets
                                  .only(
                            bottom: 8,
                          ),
                          padding:
                              const EdgeInsets
                                  .all(13),
                          decoration:
                              BoxDecoration(
                            color: sheetTheme
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(
                              alpha: 0.35,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      sale.invoiceNumber
                                              .trim()
                                              .isEmpty
                                          ? sale.id
                                          : sale.invoiceNumber,
                                      style: sheetTheme
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                        fontWeight:
                                            FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 3,
                                    ),
                                    Text(
                                      _date(
                                        sale.date,
                                      ),
                                      style: sheetTheme
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                        color: sheetTheme
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .end,
                                children: [
                                  Text(
                                    _currency(
                                      sale.total,
                                    ),
                                    style: sheetTheme
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 3,
                                  ),
                                  Text(
                                    due > 0
                                        ? 'Due ${_currency(due)}'
                                        : 'Paid',
                                    style:
                                        TextStyle(
                                      color: due > 0
                                          ? AppColors
                                              .warning
                                          : AppColors
                                              .success,
                                      fontSize:
                                          11,
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
                  'Unable to load Customer Report',
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
                      const Text('Try Again'),
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
// SUMMARY ITEM
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
// HEALTH TILE
// =============================================================================

class _HealthTile
    extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _HealthTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(
            alpha: 0.15,
          ),
        ),
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
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              color: color,
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
                      .bodySmall
                      ?.copyWith(
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: color,
                    fontWeight:
                        FontWeight.w600,
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
// CUSTOMER TILE
// =============================================================================

class _CustomerTile
    extends StatelessWidget {
  final CustomerModel customer;
  final List<SaleModel> sales;
  final double totalSales;
  final double received;
  final double outstanding;
  final double profit;
  final int invoiceCount;
  final String Function(double) currency;
  final VoidCallback onTap;

  const _CustomerTile({
    required this.customer,
    required this.sales,
    required this.totalSales,
    required this.received,
    required this.outstanding,
    required this.profit,
    required this.invoiceCount,
    required this.currency,
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
        child: Column(
          children: [
            Row(
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
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: const Icon(
                    Icons.business_rounded,
                    color:
                        AppColors.primary,
                    size: 22,
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
                        customer.name,
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
                        height: 3,
                      ),
                      Text(
                        customer.mobile
                                .trim()
                                .isEmpty
                            ? '${sales.length} invoice${sales.length == 1 ? '' : 's'}'
                            : customer.mobile,
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
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final bool compact =
                    constraints.maxWidth <
                        500;

                final List<Widget> metrics = [
                  _CustomerMetric(
                    label: 'Sales',
                    value:
                        currency(totalSales),
                    color:
                        AppColors.primary,
                  ),
                  _CustomerMetric(
                    label: 'Received',
                    value:
                        currency(received),
                    color:
                        AppColors.success,
                  ),
                  _CustomerMetric(
                    label: 'Outstanding',
                    value:
                        currency(outstanding),
                    color:
                        AppColors.warning,
                  ),
                  _CustomerMetric(
                    label: 'Profit',
                    value:
                        currency(profit),
                    color:
                        profit >= 0
                            ? AppColors.success
                            : AppColors.danger,
                  ),
                ];

                if (compact) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child:
                                metrics[0],
                          ),
                          Expanded(
                            child:
                                metrics[1],
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child:
                                metrics[2],
                          ),
                          Expanded(
                            child:
                                metrics[3],
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: metrics
                      .map(
                        (metric) =>
                            Expanded(
                          child:
                              metric,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// CUSTOMER METRIC
// =============================================================================

class _CustomerMetric
    extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CustomerMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
              .bodyMedium
              ?.copyWith(
            color: color,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// CUSTOMER DETAIL SUMMARY
// =============================================================================

class _CustomerDetailSummary
    extends StatelessWidget {
  final String sales;
  final String received;
  final String outstanding;
  final String profit;

  const _CustomerDetailSummary({
    required this.sales,
    required this.received,
    required this.outstanding,
    required this.profit,
  });

  @override
  Widget build(BuildContext context) {
    final List<_DetailMetric> items = [
      _DetailMetric(
        label: 'Sales',
        value: sales,
        color: AppColors.primary,
      ),
      _DetailMetric(
        label: 'Received',
        value: received,
        color: AppColors.success,
      ),
      _DetailMetric(
        label: 'Outstanding',
        value: outstanding,
        color: AppColors.warning,
      ),
      _DetailMetric(
        label: 'Profit',
        value: profit,
        color: AppColors.secondary,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.1,
      ),
      itemBuilder: (
        context,
        index,
      ) {
        final _DetailMetric item =
            items[index];

        return Container(
          padding:
              const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: item.color.withValues(
              alpha: 0.07,
            ),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  color: item.color,
                  fontSize: 11,
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailMetric {
  final String label;
  final String value;
  final Color color;

  const _DetailMetric({
    required this.label,
    required this.value,
    required this.color,
  });
}

// =============================================================================
// DETAIL ROW
// =============================================================================

class _DetailRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 11,
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
                fontWeight:
                    FontWeight.w600,
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