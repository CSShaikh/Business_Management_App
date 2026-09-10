import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/sale_stock_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/sale_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/sale_provider.dart';
import 'add_sale_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({
    super.key,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  final SaleStockService _saleStockService =
      SaleStockService();

  String _searchQuery = '';

  String _paymentFilter = 'All';

  DateTime? _startDate;
  DateTime? _endDate;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _onSearchChanged,
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _initialize();
      },
    );
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();

    super.dispose();
  }

  // ===========================================================================
  // INITIALIZE
  // ===========================================================================

  Future<void> _initialize() async {
    if (!mounted) return;

    final BusinessProvider businessProvider =
        context.read<BusinessProvider>();

    final SaleProvider saleProvider =
        context.read<SaleProvider>();

    try {
      await businessProvider.loadBusiness();

      if (!mounted) return;

      final String businessId =
          businessProvider.business?.id.trim() ?? '';

      if (businessId.isEmpty) {
        setState(() {
          _initialized = true;
        });

        saleProvider.setBusinessId('');

        return;
      }

      saleProvider.setBusinessId(
        businessId,
      );

      await saleProvider.loadAndWatchSales(
        businessId: businessId,
      );

      if (!mounted) return;

      setState(() {
        _initialized = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _initialized = true;
      });
    }
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<void> _refresh() async {
    final BusinessProvider businessProvider =
        context.read<BusinessProvider>();

    final SaleProvider saleProvider =
        context.read<SaleProvider>();

    try {
      await businessProvider.refresh();

      if (!mounted) return;

      final String businessId =
          businessProvider.business?.id.trim() ?? '';

      if (businessId.isEmpty) {
        saleProvider.setBusinessId('');
        return;
      }

      saleProvider.setBusinessId(
        businessId,
      );

      await saleProvider.refresh();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to refresh sales.',
        isError: true,
      );
    }
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  void _onSearchChanged() {
    if (!mounted) return;

    setState(() {
      _searchQuery =
          _searchController.text.trim().toLowerCase();
    });
  }

  // ===========================================================================
  // FILTER SALES
  // ===========================================================================

  List<SaleModel> _filteredSales(
    List<SaleModel> sales,
  ) {
    return sales.where(
      (sale) {
        // ---------------------------------------------------------------------
        // SEARCH
        // ---------------------------------------------------------------------

        if (_searchQuery.isNotEmpty) {
          final String invoice =
              sale.invoiceNumber
                  .trim()
                  .toLowerCase();

          final String customer =
              sale.customerName
                  .trim()
                  .toLowerCase();

          final String notes =
              sale.notes
                  .trim()
                  .toLowerCase();

          final bool productMatch =
              sale.items.any(
            (item) {
              return item.productName
                  .trim()
                  .toLowerCase()
                  .contains(_searchQuery);
            },
          );

          final bool searchMatch =
              invoice.contains(_searchQuery) ||
                  customer.contains(_searchQuery) ||
                  notes.contains(_searchQuery) ||
                  productMatch;

          if (!searchMatch) {
            return false;
          }
        }

        // ---------------------------------------------------------------------
        // PAYMENT STATUS
        // ---------------------------------------------------------------------

        if (_paymentFilter != 'All') {
          final String status =
              sale.paymentStatus
                  .trim()
                  .toLowerCase();

          if (status !=
              _paymentFilter.toLowerCase()) {
            return false;
          }
        }

        // ---------------------------------------------------------------------
        // DATE RANGE
        // ---------------------------------------------------------------------

        final DateTime saleDate =
            DateTime(
          sale.date.year,
          sale.date.month,
          sale.date.day,
        );

        if (_startDate != null) {
          final DateTime start =
              DateTime(
            _startDate!.year,
            _startDate!.month,
            _startDate!.day,
          );

          if (saleDate.isBefore(start)) {
            return false;
          }
        }

        if (_endDate != null) {
          final DateTime end =
              DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
          );

          if (saleDate.isAfter(end)) {
            return false;
          }
        }

        return true;
      },
    ).toList();
  }

  // ===========================================================================
  // OPEN ADD SALE
  // ===========================================================================

  Future<void> _openAddSale() async {
    final BusinessProvider businessProvider =
        context.read<BusinessProvider>();

    if (businessProvider.business == null) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );

      return;
    }

    final dynamic result =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddSaleScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await context.read<SaleProvider>().refresh();

      if (!mounted) return;

      _showMessage(
        'Sale created successfully.',
      );
    }
  }

  // ===========================================================================
  // OPEN EDIT SALE
  // ===========================================================================

  Future<void> _openEditSale(
    SaleModel sale,
  ) async {
    final BusinessProvider businessProvider =
        context.read<BusinessProvider>();

    if (businessProvider.business == null) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );

      return;
    }

    final dynamic result =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSaleScreen(
          sale: sale,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await context.read<SaleProvider>().refresh();

      if (!mounted) return;

      _showMessage(
        'Sale updated successfully.',
      );
    }
  }

  // ===========================================================================
  // DELETE SALE
  // ===========================================================================

  Future<void> _deleteSale(
    SaleModel sale,
  ) async {
    final BusinessProvider businessProvider =
        context.read<BusinessProvider>();

    final SaleProvider saleProvider =
        context.read<SaleProvider>();

    final String businessId =
        businessProvider.business?.id.trim() ?? '';

    if (businessId.isEmpty) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );

      return;
    }

    final String saleName =
        sale.invoiceNumber.trim().isEmpty
            ? 'this sale'
            : sale.invoiceNumber.trim();

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Sale?',
          ),
          content: Text(
            'Are you sure you want to delete $saleName?\n\n'
            'The stock deducted by this sale will be restored.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      // -----------------------------------------------------------------------
      // IMPORTANT:
      // Sale stock was deducted during sale creation.
      // Restore it before deleting the sale.
      // -----------------------------------------------------------------------

      await _saleStockService.reverseSaleStock(
        sale: sale,
      );

      // -----------------------------------------------------------------------
      // DELETE SALE
      // -----------------------------------------------------------------------

      await saleProvider.deleteSale(
        saleId: sale.id,
      );

      if (!mounted) return;

      _showMessage(
        'Sale deleted and stock restored successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to delete sale: ${_cleanError(e)}',
        isError: true,
      );
    }
  }

  // ===========================================================================
  // PAYMENT FILTER
  // ===========================================================================

  void _setPaymentFilter(
    String value,
  ) {
    setState(() {
      _paymentFilter = value;
    });
  }

  // ===========================================================================
  // DATE FILTER
  // ===========================================================================

  Future<void> _selectStartDate() async {
    final DateTime initialDate =
        _startDate ?? DateTime.now();

    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _startDate = selected;

      if (_endDate != null &&
          _endDate!.isBefore(selected)) {
        _endDate = selected;
      }
    });
  }

  Future<void> _selectEndDate() async {
    final DateTime initialDate =
        _endDate ??
            _startDate ??
            DateTime.now();

    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _endDate = selected;
    });
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _paymentFilter = 'All';
      _startDate = null;
      _endDate = null;
    });
  }

  // ===========================================================================
  // SHOW DETAILS
  // ===========================================================================

  void _showSaleDetails(
    SaleModel sale,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor:
          Theme.of(context).colorScheme.surface,
      builder: (_) {
        return _SaleDetailsSheet(
          sale: sale,
          onEdit: () {
            Navigator.pop(context);

            Future<void>.delayed(
              Duration.zero,
              () {
                if (mounted) {
                  _openEditSale(sale);
                }
              },
            );
          },
          onDelete: () {
            Navigator.pop(context);

            Future<void>.delayed(
              Duration.zero,
              () {
                if (mounted) {
                  _deleteSale(sale);
                }
              },
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
          backgroundColor:
              isError
                  ? AppColors.danger
                  : AppColors.success,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  // ===========================================================================
  // ERROR CLEANER
  // ===========================================================================

  String _cleanError(
    Object error,
  ) {
    final String message =
        error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final BusinessProvider businessProvider =
        context.watch<BusinessProvider>();

    final SaleProvider saleProvider =
        context.watch<SaleProvider>();

    if (!_initialized ||
        businessProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (businessProvider.errorMessage != null) {
      return _buildErrorState(
        businessProvider.errorMessage!,
      );
    }

    if (businessProvider.business == null) {
      return _buildNoBusinessState();
    }

    if (saleProvider.isLoading &&
        saleProvider.sales.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (saleProvider.errorMessage != null &&
        saleProvider.sales.isEmpty) {
      return _buildErrorState(
        saleProvider.errorMessage!,
      );
    }

    final List<SaleModel> filteredSales =
        _filteredSales(
      saleProvider.sales,
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final bool isDesktop =
              constraints.maxWidth >= 1000;

          return SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal:
                  isDesktop ? 28 : 16,
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
                      isDesktop,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildSummary(
                      saleProvider,
                      isDesktop,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildFilterSection(),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildSalesSection(
                      filteredSales,
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
    bool isDesktop,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color:
                AppColors.success.withValues(
              alpha: 0.12,
            ),
            borderRadius:
                BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.point_of_sale_rounded,
            color: AppColors.success,
            size: 28,
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
                'Sales',
                style: theme
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                'Manage sales, invoices, customers and payments.',
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
        ),

        if (isDesktop)
          FilledButton.icon(
            onPressed: _openAddSale,
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text(
              'New Sale',
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummary(
    SaleProvider provider,
    bool isDesktop,
  ) {
    final List<_SummaryData> items = [
      _SummaryData(
        title: 'Total Sales',
        value: _formatCurrency(
          provider.totalSalesAmount,
        ),
        subtitle:
            '${provider.saleCount} invoice${provider.saleCount == 1 ? '' : 's'}',
        icon:
            Icons.receipt_long_rounded,
        color: AppColors.primary,
      ),
      _SummaryData(
        title: 'Collected',
        value: _formatCurrency(
          provider.totalReceivedAmount,
        ),
        subtitle: 'Amount received',
        icon:
            Icons.payments_rounded,
        color: AppColors.success,
      ),
      _SummaryData(
        title: 'Outstanding',
        value: _formatCurrency(
          provider.todayPendingAmount,
        ),
        subtitle: 'Amount pending',
        icon:
            Icons.account_balance_wallet_outlined,
        color: AppColors.warning,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: items.map(
          (item) {
            return Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.only(
                  right: 12,
                ),
                child:
                    _SummaryMetricCard(
                  data: item,
                ),
              ),
            );
          },
        ).toList(),
      );
    }

    return Column(
      children: [
        _SummaryMetricCard(
          data: items[0],
        ),
        const SizedBox(
          height: 12,
        ),
        Row(
          children: [
            Expanded(
              child:
                  _SummaryMetricCard(
                data: items[1],
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child:
                  _SummaryMetricCard(
                data: items[2],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // FILTER SECTION
  // ===========================================================================

  Widget _buildFilterSection() {
    final bool hasFilters =
        _searchQuery.isNotEmpty ||
            _paymentFilter != 'All' ||
            _startDate != null ||
            _endDate != null;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.filter_alt_outlined,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  'Search & Filters',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (hasFilters)
                  TextButton(
                    onPressed:
                        _clearFilters,
                    child: const Text(
                      'Clear',
                    ),
                  ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            TextField(
              controller:
                  _searchController,
              textInputAction:
                  TextInputAction.search,
              decoration:
                  InputDecoration(
                hintText:
                    'Search invoice, customer, product...',
                prefixIcon:
                    const Icon(
                  Icons.search_rounded,
                ),
                suffixIcon:
                    _searchController
                            .text
                            .isEmpty
                        ? null
                        : IconButton(
                            tooltip:
                                'Clear search',
                            onPressed: () {
                              _searchController
                                  .clear();
                            },
                            icon:
                                const Icon(
                              Icons
                                  .close_rounded,
                            ),
                          ),
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
                if (constraints.maxWidth >=
                    700) {
                  return Row(
                    children: [
                      Expanded(
                        child:
                            _buildPaymentFilter(),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child:
                            _buildStartDateButton(),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child:
                            _buildEndDateButton(),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildPaymentFilter(),
                    const SizedBox(
                      height: 12,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child:
                              _buildStartDateButton(),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child:
                              _buildEndDateButton(),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            if (_startDate != null ||
                _endDate != null) ...[
              const SizedBox(
                height: 12,
              ),
              _buildDateSummary(),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PAYMENT FILTER
  // ===========================================================================

  Widget _buildPaymentFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _paymentFilter,
      decoration:
          const InputDecoration(
        labelText: 'Payment Status',
        prefixIcon:
            Icon(
          Icons.payments_outlined,
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: 'All',
          child: Text(
            'All Payments',
          ),
        ),
        DropdownMenuItem(
          value: 'Paid',
          child: Text(
            'Paid',
          ),
        ),
        DropdownMenuItem(
          value: 'Partial',
          child: Text(
            'Partial',
          ),
        ),
        DropdownMenuItem(
          value: 'Unpaid',
          child: Text(
            'Unpaid',
          ),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;

        _setPaymentFilter(
          value,
        );
      },
    );
  }

  // ===========================================================================
  // START DATE
  // ===========================================================================

  Widget _buildStartDateButton() {
    return OutlinedButton.icon(
      onPressed: _selectStartDate,
      icon: const Icon(
        Icons.calendar_today_outlined,
      ),
      label: Text(
        _startDate == null
            ? 'Start Date'
            : DateFormat(
                'dd MMM yyyy',
              ).format(
                _startDate!,
              ),
        overflow:
            TextOverflow.ellipsis,
      ),
    );
  }

  // ===========================================================================
  // END DATE
  // ===========================================================================

  Widget _buildEndDateButton() {
    return OutlinedButton.icon(
      onPressed: _selectEndDate,
      icon: const Icon(
        Icons.event_outlined,
      ),
      label: Text(
        _endDate == null
            ? 'End Date'
            : DateFormat(
                'dd MMM yyyy',
              ).format(
                _endDate!,
              ),
        overflow:
            TextOverflow.ellipsis,
      ),
    );
  }

  // ===========================================================================
  // DATE SUMMARY
  // ===========================================================================

  Widget _buildDateSummary() {
    String text = 'Date: ';

    if (_startDate != null &&
        _endDate != null) {
      text +=
          '${DateFormat('dd MMM yyyy').format(_startDate!)}'
          ' → '
          '${DateFormat('dd MMM yyyy').format(_endDate!)}';
    } else if (_startDate != null) {
      text +=
          'From ${DateFormat('dd MMM yyyy').format(_startDate!)}';
    } else if (_endDate != null) {
      text +=
          'Until ${DateFormat('dd MMM yyyy').format(_endDate!)}';
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color:
            AppColors.primary.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.date_range_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SALES SECTION
  // ===========================================================================

  Widget _buildSalesSection(
    List<SaleModel> sales,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          18,
          16,
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _searchQuery.isNotEmpty ||
                            _paymentFilter !=
                                'All' ||
                            _startDate !=
                                null ||
                            _endDate != null
                        ? 'Filtered Sales'
                        : 'Recent Sales',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration:
                      BoxDecoration(
                    color: AppColors
                        .primary
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    '${sales.length}',
                    style: const TextStyle(
                      color:
                          AppColors.primary,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            if (sales.isEmpty)
              _buildEmptyState()
            else
              ...sales.map(
                (sale) {
                  return Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      bottom: 10,
                    ),
                    child:
                        _SaleListTile(
                      sale: sale,
                      onTap: () {
                        _showSaleDetails(
                          sale,
                        );
                      },
                      onEdit: () {
                        _openEditSale(
                          sale,
                        );
                      },
                      onDelete: () {
                        _deleteSale(
                          sale,
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmptyState() {
    final bool hasFilters =
        _searchQuery.isNotEmpty ||
            _paymentFilter != 'All' ||
            _startDate != null ||
            _endDate != null;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 50,
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration:
                  BoxDecoration(
                color:
                    AppColors.primary
                        .withValues(
                  alpha: 0.10,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters
                    ? Icons
                        .search_off_rounded
                    : Icons
                        .receipt_long_outlined,
                size: 36,
                color:
                    AppColors.primary,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              hasFilters
                  ? 'No sales found'
                  : 'No sales yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 7,
            ),

            Text(
              hasFilters
                  ? 'Try changing the search or filters.'
                  : 'Create your first sale to see it here.',
              textAlign:
                  TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            if (!hasFilters) ...[
              const SizedBox(
                height: 18,
              ),
              FilledButton.icon(
                onPressed:
                    _openAddSale,
                icon: const Icon(
                  Icons.add_rounded,
                ),
                label: const Text(
                  'Create Sale',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================

  Widget _buildErrorState(
    String message,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 54,
              color: AppColors.danger,
            ),

            const SizedBox(
              height: 14,
            ),

            Text(
              'Unable to load sales',
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
              message,
              textAlign:
                  TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),

            const SizedBox(
              height: 18,
            ),

            FilledButton.icon(
              onPressed: _initialize,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // NO BUSINESS
  // ===========================================================================

  Widget _buildNoBusinessState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.business_outlined,
              size: 58,
              color: AppColors.warning,
            ),

            const SizedBox(
              height: 14,
            ),

            Text(
              'Business profile not found',
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

            const Text(
              'Please complete your business setup first.',
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FORMAT CURRENCY
  // ===========================================================================

  String _formatCurrency(
    double value,
  ) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }
}

// =============================================================================
// SUMMARY DATA
// =============================================================================

class _SummaryData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryData({
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

class _SummaryMetricCard
    extends StatelessWidget {
  final _SummaryData data;

  const _SummaryMetricCard({
    required this.data,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(
                color:
                    data.color.withValues(
                  alpha: 0.12,
                ),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Icon(
                data.icon,
                color: data.color,
              ),
            ),

            const SizedBox(
              width: 13,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
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

                  const SizedBox(
                    height: 4,
                  ),

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

                  const SizedBox(
                    height: 3,
                  ),

                  Text(
                    data.subtitle,
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
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SALE LIST TILE
// =============================================================================

class _SaleListTile
    extends StatelessWidget {
  final SaleModel sale;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SaleListTile({
    required this.sale,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  Color _statusColor() {
    switch (sale.paymentStatus
        .trim()
        .toLowerCase()) {
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

  String _statusText() {
    final String value =
        sale.paymentStatus.trim();

    if (value.isEmpty) {
      return 'Unknown';
    }

    return value[0].toUpperCase() +
        value.substring(1).toLowerCase();
  }

  String _formatCurrency(
    double value,
  ) {
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

    final Color statusColor =
        _statusColor();

    final double outstanding =
        (sale.total -
                sale.paidAmount)
            .clamp(
      0,
      double.infinity,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(16),
        child: Padding(
          padding:
              const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
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
                      Icons
                          .receipt_long_rounded,
                      color:
                          AppColors.success,
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
                          sale.invoiceNumber
                                  .trim()
                                  .isEmpty
                              ? 'Sale'
                              : sale
                                  .invoiceNumber,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          sale.customerName
                                  .trim()
                                  .isEmpty
                              ? 'Walk-in Customer'
                              : sale
                                  .customerName,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
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
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(
                          sale.total,
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
                        height: 6,
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration:
                            BoxDecoration(
                          color: statusColor
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
                          _statusText(),
                          style: TextStyle(
                            color:
                                statusColor,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(
                height: 14,
              ),

              Divider(
                height: 1,
                color: theme
                    .dividerColor
                    .withValues(
                  alpha: 0.6,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _MiniInfo(
                    icon:
                        Icons.calendar_today_outlined,
                    text: DateFormat(
                      'dd MMM yyyy',
                    ).format(
                      sale.date,
                    ),
                  ),
                  _MiniInfo(
                    icon:
                        Icons.inventory_2_outlined,
                    text:
                        '${sale.items.length} item${sale.items.length == 1 ? '' : 's'}',
                  ),
                  _MiniInfo(
                    icon:
                        Icons.payments_outlined,
                    text:
                        'Paid ${_formatCurrency(sale.paidAmount)}',
                  ),
                  if (outstanding > 0)
                    _MiniInfo(
                      icon: Icons
                          .account_balance_wallet_outlined,
                      text:
                          'Due ${_formatCurrency(outstanding)}',
                    ),
                ],
              ),

              const SizedBox(
                height: 10,
              ),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(
                      Icons
                          .visibility_outlined,
                      size: 18,
                    ),
                    label:
                        const Text(
                      'View',
                    ),
                  ),

                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                    ),
                    label:
                        const Text(
                      'Edit',
                    ),
                  ),

                  IconButton(
                    tooltip:
                        'Delete sale',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons
                          .delete_outline_rounded,
                      color:
                          AppColors.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MINI INFO
// =============================================================================

class _MiniInfo
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniInfo({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant,
        ),
        const SizedBox(
          width: 5,
        ),
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SALE DETAILS SHEET
// =============================================================================

class _SaleDetailsSheet
    extends StatelessWidget {
  final SaleModel sale;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SaleDetailsSheet({
    required this.sale,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatCurrency(
    double value,
  ) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  String _formatNumber(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  Color _statusColor() {
    switch (sale.paymentStatus
        .trim()
        .toLowerCase()) {
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

  String _statusText() {
    final String value =
        sale.paymentStatus.trim();

    if (value.isEmpty) {
      return 'Unknown';
    }

    return value[0].toUpperCase() +
        value.substring(1).toLowerCase();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final Color statusColor =
        _statusColor();

    final double outstanding =
        (sale.total -
                sale.paidAmount)
            .clamp(
      0,
      double.infinity,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          4,
          20,
          28,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------------------------
            // HEADER
            // -------------------------------------------------------------------

            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                      BoxDecoration(
                    color: AppColors
                        .success
                        .withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .receipt_long_rounded,
                    color:
                        AppColors.success,
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
                        sale.invoiceNumber
                                .trim()
                                .isEmpty
                            ? 'Sale Details'
                            : sale
                                .invoiceNumber,
                        style: theme
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        DateFormat(
                          'dd MMM yyyy, hh:mm a',
                        ).format(
                          sale.date,
                        ),
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

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color: statusColor
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    _statusText(),
                    style: TextStyle(
                      color:
                          statusColor,
                      fontWeight:
                          FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 22,
            ),

            // -------------------------------------------------------------------
            // CUSTOMER
            // -------------------------------------------------------------------

            _DetailSection(
              title: 'Customer',
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 21,
                    child: Icon(
                      Icons
                          .person_outline_rounded,
                    ),
                  ),
                  const SizedBox(
                    width: 11,
                  ),
                  Expanded(
                    child: Text(
                      sale.customerName
                              .trim()
                              .isEmpty
                          ? 'Walk-in Customer'
                          : sale
                              .customerName,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            // -------------------------------------------------------------------
            // ITEMS
            // -------------------------------------------------------------------

            _DetailSection(
              title: 'Items',
              child: Column(
                children:
                    sale.items.map(
                  (item) {
                    return Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        bottom: 13,
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Expanded(
                            child:
                                Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  item.productName,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  '${_formatNumber(item.quantity)} ${item.unit} × ${_formatCurrency(item.sellingRate)}',
                                  style:
                                      theme
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
                          Text(
                            _formatCurrency(
                              item.total,
                            ),
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ).toList(),
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // -------------------------------------------------------------------
            // AMOUNT SUMMARY
            // -------------------------------------------------------------------

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(
                16,
              ),
              decoration:
                  BoxDecoration(
                color: theme
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(
                  alpha: 0.45,
                ),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Column(
                children: [
                  _AmountRow(
                    label: 'Subtotal',
                    value:
                        _formatCurrency(
                      sale.subtotal,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  _AmountRow(
                    label: 'Discount',
                    value:
                        '- ${_formatCurrency(sale.discount)}',
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  _AmountRow(
                    label: 'Tax',
                    value:
                        _formatCurrency(
                      sale.tax,
                    ),
                  ),
                  const Divider(
                    height: 20,
                  ),
                  _AmountRow(
                    label: 'Total',
                    value:
                        _formatCurrency(
                      sale.total,
                    ),
                    bold: true,
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  _AmountRow(
                    label: 'Paid',
                    value:
                        _formatCurrency(
                      sale.paidAmount,
                    ),
                    valueColor:
                        AppColors.success,
                  ),
                  if (outstanding > 0) ...[
                    const SizedBox(
                      height: 8,
                    ),
                    _AmountRow(
                      label:
                          'Outstanding',
                      value:
                          _formatCurrency(
                        outstanding,
                      ),
                      valueColor:
                          AppColors.warning,
                      bold: true,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // -------------------------------------------------------------------
            // PAYMENT METHOD
            // -------------------------------------------------------------------

            _InfoRow(
              icon:
                  Icons.payments_outlined,
              label: 'Payment Method',
              value:
                  sale.paymentMethod
                          .trim()
                          .isEmpty
                      ? 'Not specified'
                      : sale.paymentMethod,
            ),

            if (sale.notes
                .trim()
                .isNotEmpty) ...[
              const SizedBox(
                height: 12,
              ),
              _InfoRow(
                icon:
                    Icons.notes_rounded,
                label: 'Notes',
                value: sale.notes,
              ),
            ],

            const SizedBox(
              height: 22,
            ),

            // -------------------------------------------------------------------
            // ACTIONS
            // -------------------------------------------------------------------

            Row(
              children: [
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                    ),
                    label: const Text(
                      'Edit Sale',
                    ),
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child:
                      FilledButton.icon(
                    style: FilledButton
                        .styleFrom(
                      backgroundColor:
                          AppColors.danger,
                    ),
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons
                          .delete_outline_rounded,
                    ),
                    label: const Text(
                      'Delete',
                    ),
                  ),
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
// DETAIL SECTION
// =============================================================================

class _DetailSection
    extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(
            fontWeight:
                FontWeight.w800,
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        child,
      ],
    );
  }
}

// =============================================================================
// AMOUNT ROW
// =============================================================================

class _AmountRow
    extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _AmountRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
              fontWeight: bold
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
            color: valueColor,
            fontWeight: bold
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// INFO ROW
// =============================================================================

class _InfoRow
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context)
              .colorScheme
              .primary,
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const SizedBox(
                height: 3,
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}