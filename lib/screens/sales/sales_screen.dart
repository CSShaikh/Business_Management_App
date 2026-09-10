import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/invoice_pdf_service.dart';
import '../../core/services/sale_stock_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
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
  // PRINT INVOICE
  // ===========================================================================

  Future<void> _printInvoice(
    SaleModel sale,
  ) async {
    final BusinessModel? business =
        context.read<BusinessProvider>().business;

    if (business == null) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );

      return;
    }

    try {
      await InvoicePdfService.printInvoice(
        business: business,
        sale: sale,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to print invoice: ${_cleanError(e)}',
        isError: true,
      );
    }
  }

  // ===========================================================================
  // SHARE INVOICE
  // ===========================================================================

  Future<void> _shareInvoice(
    SaleModel sale,
  ) async {
    final BusinessModel? business =
        context.read<BusinessProvider>().business;

    if (business == null) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );

      return;
    }

    try {
      await InvoicePdfService.shareInvoice(
        business: business,
        sale: sale,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to share invoice: ${_cleanError(e)}',
        isError: true,
      );
    }
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

          // -------------------------------------------------------------------
          // PRINT INVOICE
          // -------------------------------------------------------------------

          onPrintInvoice: () {
            Navigator.pop(context);

            Future<void>.delayed(
              Duration.zero,
              () {
                if (mounted) {
                  _printInvoice(sale);
                }
              },
            );
          },

          // -------------------------------------------------------------------
          // SHARE INVOICE
          // -------------------------------------------------------------------

          onShareInvoice: () {
            Navigator.pop(context);

            Future<void>.delayed(
              Duration.zero,
              () {
                if (mounted) {
                  _shareInvoice(sale);
                }
              },
            );
          },

          // -------------------------------------------------------------------
          // EDIT
          // -------------------------------------------------------------------

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

          // -------------------------------------------------------------------
          // DELETE
          // -------------------------------------------------------------------

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
                height: 5,
              ),
              Text(
                'Manage sales, invoices and customer transactions.',
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
          width: 12,
        ),
        FilledButton.icon(
          onPressed: _openAddSale,
          icon: const Icon(
            Icons.add_rounded,
          ),
          label: Text(
            isDesktop
                ? 'Add Sale'
                : 'Sale',
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummary(
    SaleProvider saleProvider,
    bool isDesktop,
  ) {
    final List<SaleModel> sales =
        _filteredSales(
      saleProvider.sales,
    );

    double totalSales = 0;
    double totalReceived = 0;
    double totalPending = 0;

    for (final SaleModel sale in sales) {
      totalSales += sale.total;
      totalReceived += sale.paidAmount;

      final double pending =
          sale.total - sale.paidAmount;

      if (pending > 0) {
        totalPending += pending;
      }
    }

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final double width =
            constraints.maxWidth;

        int columns;

        if (width >= 1000) {
          columns = 4;
        } else if (width >= 650) {
          columns = 2;
        } else {
          columns = 1;
        }

        final double spacing =
            columns == 1 ? 0 : 12;

        final double cardWidth =
            columns == 1
                ? width
                : (width -
                        spacing *
                            (columns - 1)) /
                    columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon:
                    Icons.receipt_long_rounded,
                title: 'Total Sales',
                value:
                    _formatCurrency(
                  totalSales,
                ),
                color:
                    AppColors.success,
                subtitle:
                    '${sales.length} sale${sales.length == 1 ? '' : 's'}',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon:
                    Icons.account_balance_wallet_outlined,
                title: 'Received',
                value:
                    _formatCurrency(
                  totalReceived,
                ),
                color:
                    AppColors.info,
                subtitle:
                    'Paid amount',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon:
                    Icons.pending_actions_rounded,
                title: 'Pending',
                value:
                    _formatCurrency(
                  totalPending,
                ),
                color:
                    AppColors.warning,
                subtitle:
                    'Outstanding',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon:
                    Icons.trending_up_rounded,
                title: 'Collection Rate',
                value:
                    totalSales <= 0
                        ? '0%'
                        : '${((totalReceived / totalSales) * 100).clamp(0, 100).toStringAsFixed(1)}%',
                color:
                    AppColors.purple,
                subtitle:
                    'Received / sales',
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // FILTER SECTION
  // ===========================================================================

  Widget _buildFilterSection() {
    final ThemeData theme =
        Theme.of(context);

    final bool hasFilters =
        _searchQuery.isNotEmpty ||
            _paymentFilter != 'All' ||
            _startDate != null ||
            _endDate != null;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.35,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color: theme
              .colorScheme
              .outline
              .withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons
                    .filter_alt_outlined,
                size: 19,
                color: theme
                    .colorScheme
                    .primary,
              ),
              const SizedBox(
                width: 8,
              ),
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
          LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              final bool compact =
                  constraints.maxWidth < 700;

              if (compact) {
                return Column(
                  children: [
                    _buildSearchField(),
                    const SizedBox(
                      height: 12,
                    ),
                    _buildPaymentDropdown(),
                    const SizedBox(
                      height: 12,
                    ),
                    _buildDateButtons(),
                  ],
                );
              }

              return Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child:
                        _buildSearchField(),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child:
                        _buildPaymentDropdown(),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child:
                        _buildDateButtons(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction:
          TextInputAction.search,
      decoration:
          InputDecoration(
        hintText:
            'Search invoice, customer or product',
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
                    },
                    icon:
                        const Icon(
                      Icons
                          .clear_rounded,
                    ),
                  )
                : null,
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _paymentFilter,
      decoration:
          InputDecoration(
        labelText:
            'Payment Status',
        prefixIcon:
            const Icon(
          Icons
              .payments_outlined,
        ),
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: 'All',
          child: Text(
            'All',
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
      onChanged:
          (value) {
        if (value == null) return;
        _setPaymentFilter(
          value,
        );
      },
    );
  }

  Widget _buildDateButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                _selectStartDate,
            icon: const Icon(
              Icons
                  .calendar_today_outlined,
              size: 17,
            ),
            label: Text(
              _startDate == null
                  ? 'From'
                  : DateFormat(
                      'dd MMM',
                    ).format(
                      _startDate!,
                    ),
              overflow:
                  TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(
          width: 8,
        ),
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                _selectEndDate,
            icon: const Icon(
              Icons
                  .event_outlined,
              size: 17,
            ),
            label: Text(
              _endDate == null
                  ? 'To'
                  : DateFormat(
                      'dd MMM',
                    ).format(
                      _endDate!,
                    ),
              overflow:
                  TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SALES SECTION
  // ===========================================================================

  Widget _buildSalesSection(
    List<SaleModel> sales,
  ) {
    final ThemeData theme =
        Theme.of(context);

    if (sales.isEmpty) {
      return _buildEmptySalesState();
    }

    return Container(
      width: double.infinity,
      decoration:
          BoxDecoration(
        color: theme
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color: theme
              .colorScheme
              .outline
              .withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              12,
            ),
            child: Row(
              children: [
                Text(
                  'Sales History',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${sales.length} record${sales.length == 1 ? '' : 's'}',
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
          const Divider(
            height: 1,
          ),
          ListView.separated(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            padding:
                const EdgeInsets.all(
              12,
            ),
            itemCount:
                sales.length,
            separatorBuilder:
                (_, _) =>
                    const SizedBox(
              height: 8,
            ),
            itemBuilder:
                (context, index) {
              return _SaleListTile(
                sale:
                    sales[index],
                onTap:
                    () {
                  _showSaleDetails(
                    sales[index],
                  );
                },
                onEdit:
                    () {
                  _openEditSale(
                    sales[index],
                  );
                },
                onDelete:
                    () {
                  _deleteSale(
                    sales[index],
                  );
                },
                onPrintInvoice:
                    () {
                  _printInvoice(
                    sales[index],
                  );
                },
                onShareInvoice:
                    () {
                  _shareInvoice(
                    sales[index],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySalesState() {
    final ThemeData theme =
        Theme.of(context);

    final bool hasFilters =
        _searchQuery.isNotEmpty ||
            _paymentFilter != 'All' ||
            _startDate != null ||
            _endDate != null;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 48,
      ),
      decoration:
          BoxDecoration(
        color: theme
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color: theme
              .colorScheme
              .outline
              .withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration:
                BoxDecoration(
              color: theme
                  .colorScheme
                  .primary
                  .withValues(
                alpha: 0.10,
              ),
              shape:
                  BoxShape.circle,
            ),
            child: Icon(
              hasFilters
                  ? Icons
                      .search_off_rounded
                  : Icons
                      .receipt_long_outlined,
              size: 34,
              color: theme
                  .colorScheme
                  .primary,
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          Text(
            hasFilters
                ? 'No matching sales'
                : 'No sales yet',
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
            hasFilters
                ? 'Try changing the search or filters.'
                : 'Create your first sale to start tracking invoices and payments.',
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
          if (!hasFilters) ...[
            const SizedBox(
              height: 18,
            ),
            FilledButton.icon(
              onPressed:
                  _openAddSale,
              icon:
                  const Icon(
                Icons.add_rounded,
              ),
              label:
                  const Text(
                'Add Sale',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================

  Widget _buildErrorState(
    String message,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons
                  .error_outline_rounded,
              size: 52,
              color:
                  AppColors.danger,
            ),
            const SizedBox(
              height: 14,
            ),
            Text(
              'Something went wrong',
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
            const SizedBox(
              height: 18,
            ),
            FilledButton.icon(
              onPressed:
                  _initialize,
              icon:
                  const Icon(
                Icons.refresh_rounded,
              ),
              label:
                  const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // NO BUSINESS STATE
  // ===========================================================================

  Widget _buildNoBusinessState() {
    final ThemeData theme =
        Theme.of(context);

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons
                  .business_outlined,
              size: 54,
              color: theme
                  .colorScheme
                  .primary,
            ),
            const SizedBox(
              height: 14,
            ),
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
            const SizedBox(
              height: 8,
            ),
            Text(
              'Please complete your business setup before managing sales.',
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
      ),
    );
  }

  // ===========================================================================
  // HELPERS
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
// SUMMARY CARD
// =============================================================================

class _SummaryCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final String subtitle;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color: theme
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color: theme
              .colorScheme
              .outline
              .withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration:
                BoxDecoration(
              color: color.withValues(
                alpha: 0.12,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: Icon(
              icon,
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
                    fontWeight:
                        FontWeight.w600,
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
  final VoidCallback onPrintInvoice;
  final VoidCallback onShareInvoice;

  const _SaleListTile({
    required this.sale,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onPrintInvoice,
    required this.onShareInvoice,
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

    final double pending =
        (sale.total -
                sale.paidAmount)
            .clamp(
      0,
      double.infinity,
    );

    return Material(
      color: theme
          .colorScheme
          .surfaceContainerHighest
          .withValues(
        alpha: 0.22,
      ),
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(
            14,
          ),
          child: Row(
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
                    14,
                  ),
                ),
                child: const Icon(
                  Icons
                      .receipt_long_rounded,
                  color:
                      AppColors.success,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
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
                                .titleSmall
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
                            vertical: 5,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                statusColor
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
                            style:
                                TextStyle(
                              color:
                                  statusColor,
                              fontSize: 10,
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
                      sale.customerName
                              .trim()
                              .isEmpty
                          ? 'Walk-in Customer'
                          : sale
                              .customerName,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(sale.date)} • ${sale.items.length} item${sale.items.length == 1 ? '' : 's'}',
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
                width: 12,
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
                        .titleSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    pending > 0
                        ? 'Due ${_formatCurrency(pending)}'
                        : 'Paid',
                    style: TextStyle(
                      color: pending > 0
                          ? AppColors.warning
                          : AppColors.success,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                width: 4,
              ),
              PopupMenuButton<String>(
                tooltip:
                    'Sale actions',
                onSelected:
                    (value) {
                  switch (value) {
                    case 'view':
                      onTap();
                      break;

                    case 'print':
                      onPrintInvoice();
                      break;

                    case 'share':
                      onShareInvoice();
                      break;

                    case 'edit':
                      onEdit();
                      break;

                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder:
                    (context) {
                  return const [
                    PopupMenuItem(
                      value: 'view',
                      child: ListTile(
                        leading: Icon(
                          Icons
                              .visibility_outlined,
                        ),
                        title: Text(
                          'View Details',
                        ),
                        contentPadding:
                            EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'print',
                      child: ListTile(
                        leading: Icon(
                          Icons
                              .print_outlined,
                        ),
                        title: Text(
                          'Print Invoice',
                        ),
                        contentPadding:
                            EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: ListTile(
                        leading: Icon(
                          Icons
                              .share_outlined,
                        ),
                        title: Text(
                          'Share Invoice',
                        ),
                        contentPadding:
                            EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(
                          Icons
                              .edit_outlined,
                        ),
                        title: Text(
                          'Edit Sale',
                        ),
                        contentPadding:
                            EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons
                              .delete_outline_rounded,
                        ),
                        title: Text(
                          'Delete Sale',
                        ),
                        contentPadding:
                            EdgeInsets.zero,
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SALE DETAILS SHEET
// =============================================================================

class _SaleDetailsSheet
    extends StatelessWidget {
  final SaleModel sale;
  final VoidCallback onPrintInvoice;
  final VoidCallback onShareInvoice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SaleDetailsSheet({
    required this.sale,
    required this.onPrintInvoice,
    required this.onShareInvoice,
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
            // INVOICE ACTIONS
            // -------------------------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        onPrintInvoice,
                    icon: const Icon(
                      Icons.print_outlined,
                    ),
                    label: const Text(
                      'Print Invoice',
                    ),
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        onShareInvoice,
                    icon: const Icon(
                      Icons.share_outlined,
                    ),
                    label: const Text(
                      'Share Invoice',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            // -------------------------------------------------------------------
            // EDIT / DELETE
            // -------------------------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
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
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
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
    final ThemeData theme =
        Theme.of(context);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme
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
  final bool bold;
  final Color? valueColor;

  const _AmountRow({
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

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme
                .textTheme
                .bodyMedium
                ?.copyWith(
              fontWeight:
                  bold
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
            fontWeight:
                bold
                    ? FontWeight.w800
                    : FontWeight.w600,
            color:
                valueColor,
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
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration:
          BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.28,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: theme
                .colorScheme
                .primary,
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
                  label,
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
                  height: 3,
                ),
                Text(
                  value,
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
        ],
      ),
    );
  }
}