import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/purchase_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/purchase_repository.dart';

class PurchaseReportScreen extends StatefulWidget {
  const PurchaseReportScreen({
    super.key,
  });

  @override
  State<PurchaseReportScreen> createState() =>
      _PurchaseReportScreenState();
}

class _PurchaseReportScreenState
    extends State<PurchaseReportScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final PurchaseRepository _purchaseRepository =
      PurchaseRepository();

  final TextEditingController _searchController =
      TextEditingController();

  bool _loading = true;
  bool _refreshing = false;

  String? _errorMessage;

  String _searchQuery = '';
  String _paymentFilter = 'All';

  DateTime? _startDate;
  DateTime? _endDate;

  List<PurchaseModel> _allPurchases =
      <PurchaseModel>[];

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
      final business =
          await _businessRepository
              .getBusinessForCurrentUser();

      if (business == null) {
        throw Exception(
          'Business information is not available.',
        );
      }

      final List<PurchaseModel> purchases =
          await _purchaseRepository.getPurchases(
        businessId: business.id,
      );

      if (!mounted) return;

      setState(() {
        _allPurchases = purchases;
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
      helpText:
          'Select Purchase Report Period',
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
  // FILTERED PURCHASES
  // ===========================================================================

  List<PurchaseModel> get _filteredPurchases {
    final String query =
        _searchQuery.trim().toLowerCase();

    final List<PurchaseModel> result =
        _allPurchases.where((purchase) {
      // -----------------------------------------------------------------------
      // DATE
      // -----------------------------------------------------------------------

      if (_startDate != null &&
          purchase.date.isBefore(_startDate!)) {
        return false;
      }

      if (_endDate != null &&
          purchase.date.isAfter(_endDate!)) {
        return false;
      }

      // -----------------------------------------------------------------------
      // PAYMENT STATUS
      // -----------------------------------------------------------------------

      if (_paymentFilter != 'All' &&
          purchase.paymentStatus
                  .toLowerCase() !=
              _paymentFilter.toLowerCase()) {
        return false;
      }

      // -----------------------------------------------------------------------
      // SEARCH
      // -----------------------------------------------------------------------

      if (query.isEmpty) {
        return true;
      }

      final bool supplierMatch =
          purchase.supplierName
              .toLowerCase()
              .contains(query);

      final bool notesMatch =
          purchase.notes
              .toLowerCase()
              .contains(query);

      final bool productMatch =
          purchase.items.any(
        (item) {
          return item.productName
              .toLowerCase()
              .contains(query);
        },
      );

      final bool idMatch =
          purchase.id
              .toLowerCase()
              .contains(query);

      return supplierMatch ||
          notesMatch ||
          productMatch ||
          idMatch;
    }).toList();

    result.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return result;
  }

  // ===========================================================================
  // CALCULATIONS
  // ===========================================================================

  double _totalPurchases(
    List<PurchaseModel> purchases,
  ) {
    return purchases.fold(
      0,
      (sum, purchase) =>
          sum + purchase.total,
    );
  }

  double _totalPaid(
    List<PurchaseModel> purchases,
  ) {
    return purchases.fold(
      0,
      (sum, purchase) =>
          sum + purchase.paidAmount,
    );
  }

  double _totalOutstanding(
    List<PurchaseModel> purchases,
  ) {
    return purchases.fold(
      0,
      (sum, purchase) {
        final double outstanding =
            purchase.total -
                purchase.paidAmount;

        return sum +
            (outstanding > 0
                ? outstanding
                : 0);
      },
    );
  }

  double _totalDiscount(
    List<PurchaseModel> purchases,
  ) {
    return purchases.fold(
      0,
      (sum, purchase) =>
          sum + purchase.discount,
    );
  }

  double _totalTax(
    List<PurchaseModel> purchases,
  ) {
    return purchases.fold(
      0,
      (sum, purchase) =>
          sum + purchase.tax,
    );
  }

  double _totalQuantity(
    List<PurchaseModel> purchases,
  ) {
    double total = 0;

    for (final purchase in purchases) {
      for (final item in purchase.items) {
        total += item.quantity;
      }
    }

    return total;
  }

  double _paymentRate(
    List<PurchaseModel> purchases,
  ) {
    final double total =
        _totalPurchases(purchases);

    if (total <= 0) {
      return 0;
    }

    return (_totalPaid(purchases) /
            total) *
        100;
  }

  // ===========================================================================
  // STATUS
  // ===========================================================================

  int _countStatus(
    List<PurchaseModel> purchases,
    String status,
  ) {
    return purchases.where(
      (purchase) {
        return purchase.paymentStatus
                .toLowerCase() ==
            status.toLowerCase();
      },
    ).length;
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
  // SUPPLIER-WISE
  // ===========================================================================

  Map<String, _SupplierPurchaseSummary>
      _supplierWisePurchases(
    List<PurchaseModel> purchases,
  ) {
    final Map<String, _SupplierPurchaseSummary>
        result =
        <String, _SupplierPurchaseSummary>{};

    for (final purchase in purchases) {
      final String supplierName =
          purchase.supplierName
                  .trim()
                  .isEmpty
              ? 'Unknown Supplier'
              : purchase.supplierName.trim();

      final _SupplierPurchaseSummary existing =
          result[supplierName] ??
              _SupplierPurchaseSummary(
                name: supplierName,
              );

      final double outstanding =
          purchase.total -
              purchase.paidAmount;

      result[supplierName] =
          _SupplierPurchaseSummary(
        name: supplierName,
        purchases:
            existing.purchases +
                purchase.total,
        paid:
            existing.paid +
                purchase.paidAmount,
        outstanding:
            existing.outstanding +
                (outstanding > 0
                    ? outstanding
                    : 0),
        invoiceCount:
            existing.invoiceCount + 1,
      );
    }

    final List<_SupplierPurchaseSummary>
        values =
        result.values.toList();

    values.sort(
      (a, b) =>
          b.purchases.compareTo(
        a.purchases,
      ),
    );

    return <String, _SupplierPurchaseSummary>{
      for (final item in values)
        item.name: item,
    };
  }

  // ===========================================================================
  // PRODUCT-WISE
  // ===========================================================================

  Map<String, _ProductPurchaseSummary>
      _productWisePurchases(
    List<PurchaseModel> purchases,
  ) {
    final Map<String, _ProductPurchaseSummary>
        result =
        <String, _ProductPurchaseSummary>{};

    for (final purchase in purchases) {
      for (final item in purchase.items) {
        final String productName =
            item.productName
                    .trim()
                    .isEmpty
                ? 'Unknown Product'
                : item.productName.trim();

        final _ProductPurchaseSummary existing =
            result[productName] ??
                _ProductPurchaseSummary(
                  name: productName,
                );

        result[productName] =
            _ProductPurchaseSummary(
          name: productName,
          quantity:
              existing.quantity +
                  item.quantity,
          amount:
              existing.amount +
                  item.total,
          invoiceCount:
              existing.invoiceCount + 1,
          unit: item.unit,
        );
      }
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

    final List<PurchaseModel> purchases =
        _filteredPurchases;

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
                      purchases,
                      isDesktop,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildPaymentStatus(
                      theme,
                      purchases,
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

                    _buildSupplierWiseSection(
                      theme,
                      purchases,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildProductWiseSection(
                      theme,
                      purchases,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildPurchaseList(
                      theme,
                      purchases,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildFooter(
                      theme,
                      purchases,
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
        gradient: const LinearGradient(
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
              color:
                  Colors.white.withValues(
                alpha: 0.15,
              ),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shopping_cart_rounded,
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
                  'Purchase Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Analyze purchases, supplier payments and inventory buying.',
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
            decoration: BoxDecoration(
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

  Widget _buildSummaryCards(
    ThemeData theme,
    List<PurchaseModel> purchases,
    bool isDesktop,
  ) {
    final List<_SummaryItem> items = [
      _SummaryItem(
        title: 'Total Purchases',
        value: _currency(
          _totalPurchases(purchases),
        ),
        subtitle:
            '${purchases.length} purchase${purchases.length == 1 ? '' : 's'}',
        icon:
            Icons.shopping_cart_checkout_rounded,
        color: AppColors.primary,
      ),
      _SummaryItem(
        title: 'Total Paid',
        value: _currency(
          _totalPaid(purchases),
        ),
        subtitle:
            '${_paymentRate(purchases).toStringAsFixed(1)}% paid',
        icon:
            Icons.payments_rounded,
        color: AppColors.success,
      ),
      _SummaryItem(
        title: 'Outstanding',
        value: _currency(
          _totalOutstanding(purchases),
        ),
        subtitle:
            'Supplier payable',
        icon:
            Icons.account_balance_wallet_rounded,
        color: AppColors.warning,
      ),
      _SummaryItem(
        title: 'Total Quantity',
        value: _number(
          _totalQuantity(purchases),
        ),
        subtitle:
            'Items purchased',
        icon:
            Icons.inventory_2_rounded,
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
            isDesktop ? 1.9 : 1.45,
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
  // PAYMENT STATUS
  // ===========================================================================

  Widget _buildPaymentStatus(
    ThemeData theme,
    List<PurchaseModel> purchases,
  ) {
    final List<_StatusItem> items = [
      _StatusItem(
        label: 'Paid',
        count:
            _countStatus(purchases, 'Paid'),
        color: AppColors.success,
        icon:
            Icons.check_circle_rounded,
      ),
      _StatusItem(
        label: 'Partial',
        count:
            _countStatus(purchases, 'Partial'),
        color: AppColors.warning,
        icon: Icons.timelapse_rounded,
      ),
      _StatusItem(
        label: 'Unpaid',
        count:
            _countStatus(purchases, 'Unpaid'),
        color: AppColors.danger,
        icon:
            Icons.pending_actions_rounded,
      ),
    ];

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
                'Supplier payment breakdown',
          ),

          const SizedBox(
            height: 18,
          ),

          LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              if (constraints.maxWidth <
                  600) {
                return Column(
                  children: items
                      .map(
                        (item) =>
                            Padding(
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
                      (item) =>
                          Expanded(
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
  // SEARCH
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
                  'Search supplier, product, purchase ID or notes...',
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

          const SizedBox(
            height: 14,
          ),

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
  // SUPPLIER WISE
  // ===========================================================================

  Widget _buildSupplierWiseSection(
    ThemeData theme,
    List<PurchaseModel> purchases,
  ) {
    final List<_SupplierPurchaseSummary>
        suppliers =
        _supplierWisePurchases(
      purchases,
    ).values.toList();

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.local_shipping_rounded,
            title:
                'Supplier-wise Purchases',
            subtitle:
                'Purchase and payment summary by supplier',
          ),

          const SizedBox(
            height: 18,
          ),

          if (suppliers.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.local_shipping_outlined,
              message:
                  'No supplier purchases available for the selected filters.',
            )
          else
            ...suppliers.take(15).map(
              (supplier) {
                return _SupplierTile(
                  summary: supplier,
                  currency: _currency,
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PRODUCT WISE
  // ===========================================================================

  Widget _buildProductWiseSection(
    ThemeData theme,
    List<PurchaseModel> purchases,
  ) {
    final List<_ProductPurchaseSummary>
        products =
        _productWisePurchases(
      purchases,
    ).values.toList()
          ..sort(
            (a, b) => b.amount.compareTo(
              a.amount,
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
                'Product-wise Purchases',
            subtitle:
                'Quantity and purchase amount by product',
          ),

          const SizedBox(
            height: 18,
          ),

          if (products.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.inventory_2_outlined,
              message:
                  'No product purchases available for the selected filters.',
            )
          else
            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                if (constraints.maxWidth <
                    650) {
                  return Column(
                    children: products
                        .take(15)
                        .map(
                          (product) =>
                              _ProductTile(
                            summary:
                                product,
                            currency:
                                _currency,
                            number:
                                _number,
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
                            Text('Purchase Amount'),
                      ),
                      DataColumn(
                        label:
                            Text('Purchases'),
                      ),
                    ],
                    rows: products
                        .take(20)
                        .map(
                          (product) {
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
                                      product.amount,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    product
                                        .invoiceCount
                                        .toString(),
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
  // PURCHASE LIST
  // ===========================================================================

  Widget _buildPurchaseList(
    ThemeData theme,
    List<PurchaseModel> purchases,
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
                'Purchase-wise Details',
            subtitle:
                '${purchases.length} matching purchase${purchases.length == 1 ? '' : 's'}',
          ),

          const SizedBox(
            height: 18,
          ),

          if (purchases.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.receipt_long_outlined,
              message:
                  'No purchases found for the selected filters.',
            )
          else
            ...purchases.map(
              (purchase) {
                return _PurchaseTile(
                  purchase: purchase,
                  currency: _currency,
                  date: _date,
                  statusColor:
                      _statusColor,
                  onTap: () {
                    _showPurchaseDetails(
                      purchase,
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
  // DETAILS
  // ===========================================================================

  void _showPurchaseDetails(
    PurchaseModel purchase,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final ThemeData theme =
            Theme.of(sheetContext);

        final double outstanding =
            purchase.total -
                purchase.paidAmount;

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
                    'Purchase Details',
                    style: theme
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    _date(purchase.date),
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
                    height: 18,
                  ),

                  _DetailRow(
                    label: 'Purchase ID',
                    value:
                        purchase.id,
                  ),

                  _DetailRow(
                    label: 'Supplier',
                    value:
                        purchase.supplierName,
                  ),

                  _DetailRow(
                    label: 'Subtotal',
                    value:
                        _currency(
                      purchase.subtotal,
                    ),
                  ),

                  _DetailRow(
                    label: 'Discount',
                    value:
                        _currency(
                      purchase.discount,
                    ),
                  ),

                  _DetailRow(
                    label: 'Tax',
                    value:
                        _currency(
                      purchase.tax,
                    ),
                  ),

                  _DetailRow(
                    label: 'Total',
                    value:
                        _currency(
                      purchase.total,
                    ),
                    bold: true,
                  ),

                  _DetailRow(
                    label: 'Paid',
                    value:
                        _currency(
                      purchase.paidAmount,
                    ),
                  ),

                  _DetailRow(
                    label: 'Outstanding',
                    value:
                        _currency(
                      outstanding > 0
                          ? outstanding
                          : 0,
                    ),
                    valueColor:
                        outstanding > 0
                            ? AppColors
                                .warning
                            : AppColors
                                .success,
                    bold: true,
                  ),

                  _DetailRow(
                    label:
                        'Payment Status',
                    value:
                        purchase
                            .paymentStatus,
                  ),

                  _DetailRow(
                    label:
                        'Payment Method',
                    value:
                        purchase
                            .paymentMethod,
                  ),

                  const SizedBox(
                    height: 18,
                  ),

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

                  const SizedBox(
                    height: 10,
                  ),

                  ...purchase.items.map(
                    (item) {
                      return Container(
                        margin:
                            const EdgeInsets
                                .only(
                          bottom: 10,
                        ),
                        padding:
                            const EdgeInsets
                                .all(13),
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
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),

                            const SizedBox(
                              height: 6,
                            ),

                            Text(
                              '${_number(item.quantity)} ${item.unit} × ${_currency(item.purchaseRate)}',
                              style: theme
                                  .textTheme
                                  .bodySmall,
                            ),

                            const SizedBox(
                              height: 5,
                            ),

                            Text(
                              'Total: ${_currency(item.total)}',
                              style: theme
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  if (purchase.notes
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 8,
                    ),

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
                      purchase.notes,
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

  Widget _buildFooter(
    ThemeData theme,
    List<PurchaseModel> purchases,
  ) {
    return _ReportCard(
      child: Wrap(
        spacing: 24,
        runSpacing: 14,
        children: [
          _FooterMetric(
            label: 'Purchases',
            value:
                purchases.length.toString(),
          ),
          _FooterMetric(
            label: 'Quantity',
            value: _number(
              _totalQuantity(purchases),
            ),
          ),
          _FooterMetric(
            label: 'Discount',
            value: _currency(
              _totalDiscount(purchases),
            ),
          ),
          _FooterMetric(
            label: 'Tax',
            value: _currency(
              _totalTax(purchases),
            ),
          ),
          _FooterMetric(
            label: 'Payment Rate',
            value:
                '${_paymentRate(purchases).toStringAsFixed(2)}%',
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

                const SizedBox(
                  height: 16,
                ),

                Text(
                  'Unable to load Purchase Report',
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

class _SupplierPurchaseSummary {
  final String name;
  final double purchases;
  final double paid;
  final double outstanding;
  final int invoiceCount;

  const _SupplierPurchaseSummary({
    required this.name,
    this.purchases = 0,
    this.paid = 0,
    this.outstanding = 0,
    this.invoiceCount = 0,
  });
}

class _ProductPurchaseSummary {
  final String name;
  final double quantity;
  final double amount;
  final int invoiceCount;
  final String unit;

  const _ProductPurchaseSummary({
    required this.name,
    this.quantity = 0,
    this.amount = 0,
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
// CARD
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
              const SizedBox(
                height: 2,
              ),
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

class _StatusTile
    extends StatelessWidget {
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
        color:
            item.color.withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              item.color.withValues(
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
          const SizedBox(
            width: 10,
          ),
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

class _FilterChip
    extends StatelessWidget {
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
      labelStyle: TextStyle(
        color: selected
            ? activeColor
            : theme
                .colorScheme
                .onSurface,
        fontWeight: selected
            ? FontWeight.w700
            : FontWeight.w500,
      ),
    );
  }
}

// =============================================================================
// SUPPLIER TILE
// =============================================================================

class _SupplierTile
    extends StatelessWidget {
  final _SupplierPurchaseSummary summary;
  final String Function(double) currency;

  const _SupplierTile({
    required this.summary,
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
              color:
                  AppColors.primary
                      .withValues(
                alpha: 0.10,
              ),
              shape:
                  BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color:
                  AppColors.primary,
              size: 22,
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
                  height: 4,
                ),
                Text(
                  '${summary.invoiceCount} purchase${summary.invoiceCount == 1 ? '' : 's'}',
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
                currency(
                  summary.purchases,
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
                height: 4,
              ),
              Text(
                'Due ${currency(summary.outstanding)}',
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

class _ProductTile
    extends StatelessWidget {
  final _ProductPurchaseSummary summary;
  final String Function(double) currency;
  final String Function(double) number;

  const _ProductTile({
    required this.summary,
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
                currency(
                  summary.amount,
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
          const SizedBox(
            height: 8,
          ),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Text(
                'Qty: ${number(summary.quantity)} ${summary.unit}',
                style: theme
                    .textTheme
                    .bodySmall,
              ),
              Text(
                '${summary.invoiceCount} purchase${summary.invoiceCount == 1 ? '' : 's'}',
                style: theme
                    .textTheme
                    .bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PURCHASE TILE
// =============================================================================

class _PurchaseTile
    extends StatelessWidget {
  final PurchaseModel purchase;
  final String Function(double) currency;
  final String Function(DateTime) date;
  final Color Function(String) statusColor;
  final VoidCallback onTap;

  const _PurchaseTile({
    required this.purchase,
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
      purchase.paymentStatus,
    );

    final double outstanding =
        purchase.total -
            purchase.paidAmount;

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
                Icons.shopping_bag_rounded,
                color: color,
                size: 22,
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
                    purchase.id,
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
                    height: 4,
                  ),
                  Text(
                    purchase.supplierName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: theme
                        .textTheme
                        .bodySmall,
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    date(purchase.date),
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
                  currency(
                    purchase.total,
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
                  height: 5,
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
                    color:
                        color.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    purchase
                        .paymentStatus,
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
              width: 5,
            ),
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
// FOOTER
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