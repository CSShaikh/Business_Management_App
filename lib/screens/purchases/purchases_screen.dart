import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/purchase_model.dart';
import '../../models/supplier_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/supplier_provider.dart';
import 'add_purchase_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({
    super.key,
  });

  @override
  State<PurchasesScreen> createState() =>
      _PurchasesScreenState();
}

class _PurchasesScreenState
    extends State<PurchasesScreen> {
  String? _businessId;

  bool _isInitializing = true;

  String _searchQuery = '';

  String _selectedStatus = 'All';

  String _selectedSupplierId = 'All';

  DateTime? _startDate;

  DateTime? _endDate;

  final List<String> _statusFilters = const [
    'All',
    'Paid',
    'Partial',
    'Unpaid',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _initialize();
      },
    );
  }

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  Future<void> _initialize() async {
    try {
      final BusinessProvider businessProvider =
          context.read<BusinessProvider>();

      final PurchaseProvider purchaseProvider =
          context.read<PurchaseProvider>();

      final SupplierProvider supplierProvider =
          context.read<SupplierProvider>();

      await businessProvider.loadBusiness();

      if (!mounted) {
        return;
      }

      final String businessId =
          businessProvider.business?.id.trim() ?? '';

      if (businessId.isEmpty) {
        setState(() {
          _isInitializing = false;
          _businessId = null;
        });

        return;
      }

      _businessId = businessId;

      purchaseProvider.setBusinessId(
        businessId,
      );

      supplierProvider.setBusinessId(
        businessId,
      );
await Future.wait([
  purchaseProvider.loadAndWatchPurchases(
    businessId: businessId,
  ),
  supplierProvider.loadAndWatchSuppliers(
    businessId: businessId,
  ),
]);

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _refresh() async {
    final String? businessId =
        _businessId;

    if (businessId == null ||
        businessId.trim().isEmpty) {
      await _initialize();
      return;
    }

    final PurchaseProvider purchaseProvider =
        context.read<PurchaseProvider>();

    final SupplierProvider supplierProvider =
        context.read<SupplierProvider>();

    try {
      await Future.wait([
        purchaseProvider.refresh(),
        supplierProvider.refresh(),
      ]);
    } catch (_) {
      // Providers keep their own error state.
    }
  }

  // ===========================================================================
  // FILTERING
  // ===========================================================================

  List<PurchaseModel> _getFilteredPurchases(
    List<PurchaseModel> purchases,
  ) {
    final String query =
        _searchQuery.trim().toLowerCase();

    return purchases.where(
      (purchase) {
        // ---------------------------------------------------------------
        // SEARCH
        // ---------------------------------------------------------------

        if (query.isNotEmpty) {
          final bool matchesSearch =
              purchase.supplierName
                      .toLowerCase()
                      .contains(query) ||
                  purchase.paymentMethod
                      .toLowerCase()
                      .contains(query) ||
                  purchase.paymentStatus
                      .toLowerCase()
                      .contains(query) ||
                  purchase.notes
                      .toLowerCase()
                      .contains(query) ||
                  purchase.id
                      .toLowerCase()
                      .contains(query) ||
                  purchase.items.any(
                    (item) =>
                        item.productName
                            .toLowerCase()
                            .contains(query),
                  );

          if (!matchesSearch) {
            return false;
          }
        }

        // ---------------------------------------------------------------
        // PAYMENT STATUS
        // ---------------------------------------------------------------

        if (_selectedStatus != 'All') {
          if (purchase.paymentStatus
                  .toLowerCase() !=
              _selectedStatus.toLowerCase()) {
            return false;
          }
        }

        // ---------------------------------------------------------------
        // SUPPLIER
        // ---------------------------------------------------------------

        if (_selectedSupplierId != 'All') {
          if (purchase.supplierId !=
              _selectedSupplierId) {
            return false;
          }
        }

        // ---------------------------------------------------------------
        // START DATE
        // ---------------------------------------------------------------

        if (_startDate != null) {
          final DateTime start = DateTime(
            _startDate!.year,
            _startDate!.month,
            _startDate!.day,
          );

          if (purchase.date.isBefore(start)) {
            return false;
          }
        }

        // ---------------------------------------------------------------
        // END DATE
        // ---------------------------------------------------------------

        if (_endDate != null) {
          final DateTime end = DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
            23,
            59,
            59,
            999,
          );

          if (purchase.date.isAfter(end)) {
            return false;
          }
        }

        return true;
      },
    ).toList();
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  void _onSearchChanged(
    String value,
  ) {
    setState(() {
      _searchQuery =
          value.trim().toLowerCase();
    });
  }

  // ===========================================================================
  // DATE FILTER
  // ===========================================================================

  Future<void> _selectStartDate() async {
    final DateTime initialDate =
        _startDate ??
            DateTime.now();

    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    if (_startDate != null &&
        selected.isBefore(_startDate!)) {
      _showMessage(
        'End date cannot be before start date.',
        isError: true,
      );

      return;
    }

    setState(() {
      _endDate = selected;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'All';
      _selectedSupplierId = 'All';
      _startDate = null;
      _endDate = null;
      _searchQuery = '';
    });
  }

  bool get _hasActiveFilters {
    return _selectedStatus != 'All' ||
        _selectedSupplierId != 'All' ||
        _startDate != null ||
        _endDate != null ||
        _searchQuery.isNotEmpty;
  }

  // ===========================================================================
  // ADD / EDIT PURCHASE
  // ===========================================================================

  Future<void> _openAddPurchase() async {
    final bool? result =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) =>
            const AddPurchaseScreen(),
      ),
    );

    if (result == true &&
        mounted) {
      await _refresh();
    }
  }

  Future<void> _openEditPurchase(
    PurchaseModel purchase,
  ) async {
    final bool? result =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) =>
            AddPurchaseScreen(
          purchase: purchase,
        ),
      ),
    );

    if (result == true &&
        mounted) {
      await _refresh();
    }
  }

  // ===========================================================================
  // DELETE
  // ===========================================================================

  Future<void> _deletePurchase(
    PurchaseModel purchase,
  ) async {
    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {


        return AlertDialog(
          title: const Text(
            'Delete Purchase?',
          ),
          content: Text(
            'This will delete the purchase record of '
            '${purchase.supplierName}. '
            'This action cannot be undone.',
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
                backgroundColor:
                    AppColors.danger,
                foregroundColor:
                    Colors.white,
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

    if (confirmed != true ||
        !mounted) {
      return;
    }

    final String? businessId =
        _businessId;

    if (businessId == null ||
        businessId.trim().isEmpty) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );

      return;
    }

    final PurchaseProvider
        purchaseProvider =
        context.read<PurchaseProvider>();

    try {
      await purchaseProvider.deletePurchase(
        purchaseId: purchase.id,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Purchase deleted successfully.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to delete purchase: ${_cleanError(e)}',
        isError: true,
      );
    }
  }

  // ===========================================================================
  // DETAILS
  // ===========================================================================

  Future<void> _openPurchaseDetails(
    PurchaseModel purchase,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _PurchaseDetailsSheet(
          purchase: purchase,
        );
      },
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Purchases',
          ),
        ),
        body: const Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_businessId == null ||
        _businessId!.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Purchases',
          ),
        ),
        body:
            _buildNoBusinessState(theme),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Purchases',
          style: TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: Consumer2<
          PurchaseProvider,
          SupplierProvider>(
        builder: (
          context,
          purchaseProvider,
          supplierProvider,
          child,
        ) {
          final List<PurchaseModel>
              purchases =
              purchaseProvider.purchases;

          if (purchaseProvider.isLoading &&
              purchases.isEmpty) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (purchaseProvider.errorMessage !=
                  null &&
              purchases.isEmpty) {
            return _buildErrorState(
              theme,
              purchaseProvider.errorMessage!,
            );
          }

          final List<PurchaseModel>
              filteredPurchases =
              _getFilteredPurchases(
            purchases,
          );

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                110,
              ),
              children: [
                _buildHeader(
                  theme,
                  purchases,
                ),
                const SizedBox(
                  height: 20,
                ),
                _buildSearchField(
                  theme,
                ),
                const SizedBox(
                  height: 12,
                ),
                _buildFilters(
                  theme,
                  supplierProvider
                      .suppliers,
                ),
                const SizedBox(
                  height: 20,
                ),
                _buildPurchaseList(
                  theme,
                  purchases,
                  filteredPurchases,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _openAddPurchase,
        icon: const Icon(
          Icons.add_shopping_cart_rounded,
        ),
        label: const Text(
          'Add Purchase',
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(
    ThemeData theme,
    List<PurchaseModel> purchases,
  ) {
    double total =
        0;

    double paid =
        0;

    double outstanding =
        0;

    int partial =
        0;

    int unpaid =
        0;

    for (final PurchaseModel purchase
        in purchases) {
      total += purchase.total;
      paid += purchase.paidAmount;

      final double pending =
          purchase.total -
              purchase.paidAmount;

      if (pending > 0) {
        outstanding += pending;
      }

      if (purchase.paymentStatus
              .toLowerCase() ==
          'partial') {
        partial++;
      }

      if (purchase.paymentStatus
              .toLowerCase() ==
          'unpaid') {
        unpaid++;
      }
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Purchase Management',
          style: theme
              .textTheme
              .headlineSmall
              ?.copyWith(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        const SizedBox(
          height: 5,
        ),
        Text(
          'Track purchases, supplier payments and outstanding amounts.',
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
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool compact =
                constraints.maxWidth <
                    760;

            final List<Widget>
                cards = [
              _buildSummaryCard(
                theme,
                title: 'Total Purchase',
                value:
                    _formatCurrency(total),
                icon: Icons
                    .shopping_cart_checkout_rounded,
                color:
                    AppColors.primary,
              ),
              _buildSummaryCard(
                theme,
                title: 'Paid',
                value:
                    _formatCurrency(paid),
                icon: Icons
                    .check_circle_outline_rounded,
                color:
                    AppColors.success,
              ),
              _buildSummaryCard(
                theme,
                title: 'Outstanding',
                value:
                    _formatCurrency(
                  outstanding,
                ),
                icon: Icons
                    .pending_actions_rounded,
                color:
                    AppColors.warning,
              ),
              _buildSummaryCard(
                theme,
                title: 'Partial / Unpaid',
                value:
                    '${partial + unpaid}',
                icon: Icons
                    .receipt_long_outlined,
                color:
                    AppColors.danger,
              ),
            ];

            if (compact) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child:
                            cards[0],
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child:
                            cards[1],
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
                            cards[2],
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child:
                            cards[3],
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                for (int i = 0;
                    i < cards.length;
                    i++) ...[
                  Expanded(
                    child:
                        cards[i],
                  ),
                  if (i <
                      cards.length - 1)
                    const SizedBox(
                      width: 12,
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
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
                    height: 4,
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: theme
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
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

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Widget _buildSearchField(
    ThemeData theme,
  ) {
    return TextField(
      onChanged:
          _onSearchChanged,
      decoration:
          InputDecoration(
        hintText:
            'Search supplier, product, payment or purchase...',
        prefixIcon:
            const Icon(
          Icons.search_rounded,
        ),
        suffixIcon:
            _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    onPressed: () {
                      _onSearchChanged('');
                    },
                    icon:
                        const Icon(
                      Icons.clear_rounded,
                    ),
                  ),
        filled: true,
      ),
    );
  }

  // ===========================================================================
  // FILTERS
  // ===========================================================================

  Widget _buildFilters(
    ThemeData theme,
    List<SupplierModel> suppliers,
  ) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            if (constraints.maxWidth <
                650) {
              return Column(
                children: [
                  _buildStatusDropdown(
                    theme,
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  _buildSupplierDropdown(
                    theme,
                    suppliers,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child:
                      _buildStatusDropdown(
                    theme,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child:
                      _buildSupplierDropdown(
                    theme,
                    suppliers,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(
          height: 12,
        ),
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            if (constraints.maxWidth <
                650) {
              return Column(
                children: [
                  _buildDateButton(
                    theme,
                    label:
                        'Start Date',
                    date: _startDate,
                    onPressed:
                        _selectStartDate,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  _buildDateButton(
                    theme,
                    label:
                        'End Date',
                    date: _endDate,
                    onPressed:
                        _selectEndDate,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child:
                      _buildDateButton(
                    theme,
                    label:
                        'Start Date',
                    date: _startDate,
                    onPressed:
                        _selectStartDate,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child:
                      _buildDateButton(
                    theme,
                    label:
                        'End Date',
                    date: _endDate,
                    onPressed:
                        _selectEndDate,
                  ),
                ),
              ],
            );
          },
        ),
        if (_hasActiveFilters) ...[
          const SizedBox(
            height: 10,
          ),
          Align(
            alignment:
                Alignment.centerRight,
            child:
                TextButton.icon(
              onPressed:
                  _clearFilters,
              icon: const Icon(
                Icons.clear_all_rounded,
              ),
              label:
                  const Text(
                'Clear Filters',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusDropdown(
    ThemeData theme,
  ) {
    return DropdownButtonFormField<String>(
      initialValue:
          _selectedStatus,
      decoration:
          const InputDecoration(
        labelText:
            'Payment Status',
        prefixIcon:
            Icon(
          Icons
              .account_balance_wallet_outlined,
        ),
      ),
      items: _statusFilters
          .map(
            (status) =>
                DropdownMenuItem<
                    String>(
              value: status,
              child: Text(status),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _selectedStatus =
              value;
        });
      },
    );
  }

  Widget _buildSupplierDropdown(
    ThemeData theme,
    List<SupplierModel> suppliers,
  ) {
    final bool supplierExists =
        _selectedSupplierId ==
                'All' ||
            suppliers.any(
              (supplier) =>
                  supplier.id ==
                  _selectedSupplierId,
            );

    final String currentValue =
        supplierExists
            ? _selectedSupplierId
            : 'All';

    return DropdownButtonFormField<String>(
      initialValue:
          currentValue,
      isExpanded: true,
      decoration:
          const InputDecoration(
        labelText: 'Supplier',
        prefixIcon:
            Icon(
          Icons
              .local_shipping_outlined,
        ),
      ),
      items: [
        const DropdownMenuItem<
            String>(
          value: 'All',
          child: Text(
            'All Suppliers',
          ),
        ),
        ...suppliers.map(
          (supplier) =>
              DropdownMenuItem<
                  String>(
            value:
                supplier.id,
            child: Text(
              supplier.name,
              overflow:
                  TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _selectedSupplierId =
              value;
        });
      },
    );
  }

  Widget _buildDateButton(
    ThemeData theme, {
    required String label,
    required DateTime? date,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius:
          BorderRadius.circular(12),
      child: InputDecorator(
        decoration:
            InputDecoration(
          labelText: label,
          prefixIcon:
              const Icon(
            Icons
                .calendar_month_rounded,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date == null
                    ? 'Select date'
                    : DateFormat(
                        'dd MMM yyyy',
                      ).format(date),
              ),
            ),
            if (date != null)
              IconButton(
                tooltip:
                    'Clear date',
                visualDensity:
                    VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    if (label ==
                        'Start Date') {
                      _startDate =
                          null;
                    } else {
                      _endDate = null;
                    }
                  });
                },
                icon:
                    const Icon(
                  Icons.clear_rounded,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PURCHASE LIST
  // ===========================================================================

  Widget _buildPurchaseList(
    ThemeData theme,
    List<PurchaseModel> allPurchases,
    List<PurchaseModel> filteredPurchases,
  ) {
    if (allPurchases.isEmpty) {
      return _buildEmptyState(
        theme,
      );
    }

    if (filteredPurchases.isEmpty) {
      return _buildNoResultsState(
        theme,
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Purchase History',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${filteredPurchases.length} records',
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
          height: 12,
        ),
        ...filteredPurchases.map(
          (purchase) =>
              _buildPurchaseCard(
            theme,
            purchase,
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseCard(
    ThemeData theme,
    PurchaseModel purchase,
  ) {
    final double outstanding =
        (purchase.total -
                purchase.paidAmount)
            .clamp(
      0,
      double.infinity,
    );

    final Color statusColor =
        _paymentStatusColor(
      purchase.paymentStatus,
    );

    final String itemCount =
        purchase.items.length == 1
            ? '1 item'
            : '${purchase.items.length} items';

    final String products =
        purchase.items
            .map(
              (item) =>
                  '${item.productName} × ${_formatNumber(item.quantity)} ${item.unit}',
            )
            .join(', ');

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _openPurchaseDetails(
            purchase,
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration:
                        BoxDecoration(
                      color: AppColors
                          .primary
                          .withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons
                          .shopping_cart_outlined,
                      color:
                          AppColors.primary,
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
                          purchase
                              .supplierName
                              .trim()
                              .isEmpty
                              ? 'Unknown Supplier'
                              : purchase
                                  .supplierName,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          DateFormat(
                            'dd MMM yyyy',
                          ).format(
                            purchase.date,
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
                  const SizedBox(
                    width: 8,
                  ),
                  _buildStatusChip(
                    purchase
                        .paymentStatus,
                    statusColor,
                  ),
                ],
              ),
              const SizedBox(
                height: 14,
              ),
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  12,
                ),
                decoration:
                    BoxDecoration(
                  color: theme
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(
                    alpha: 0.55,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Icon(
                      Icons
                          .inventory_2_outlined,
                      size: 19,
                    ),
                    const SizedBox(
                      width: 9,
                    ),
                    Expanded(
                      child: Text(
                        products,
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style: theme
                            .textTheme
                            .bodyMedium,
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(
                      itemCount,
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
                height: 14,
              ),
              LayoutBuilder(
                builder: (
                  context,
                  constraints,
                ) {
                  final bool compact =
                      constraints.maxWidth <
                          500;

                  if (compact) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child:
                                  _buildAmountInfo(
                                theme,
                                'Total',
                                _formatCurrency(
                                  purchase
                                      .total,
                                ),
                                AppColors
                                    .primary,
                              ),
                            ),
                            Expanded(
                              child:
                                  _buildAmountInfo(
                                theme,
                                'Paid',
                                _formatCurrency(
                                  purchase
                                      .paidAmount,
                                ),
                                AppColors
                                    .success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child:
                                  _buildAmountInfo(
                                theme,
                                'Outstanding',
                                _formatCurrency(
                                  outstanding,
                                ),
                                outstanding >
                                        0
                                    ? AppColors
                                        .warning
                                    : AppColors
                                        .success,
                              ),
                            ),
                            Expanded(
                              child:
                                  _buildAmountInfo(
                                theme,
                                'Method',
                                purchase
                                    .paymentMethod,
                                AppColors
                                    .info,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child:
                            _buildAmountInfo(
                          theme,
                          'Total',
                          _formatCurrency(
                            purchase
                                .total,
                          ),
                          AppColors
                              .primary,
                        ),
                      ),
                      Expanded(
                        child:
                            _buildAmountInfo(
                          theme,
                          'Paid',
                          _formatCurrency(
                            purchase
                                .paidAmount,
                          ),
                          AppColors
                              .success,
                        ),
                      ),
                      Expanded(
                        child:
                            _buildAmountInfo(
                          theme,
                          'Outstanding',
                          _formatCurrency(
                            outstanding,
                          ),
                          outstanding >
                                  0
                              ? AppColors
                                  .warning
                              : AppColors
                                  .success,
                        ),
                      ),
                      Expanded(
                        child:
                            _buildAmountInfo(
                          theme,
                          'Method',
                          purchase
                              .paymentMethod,
                          AppColors
                              .info,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(
                height: 14,
              ),
              Row(
                children: [
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed: () {
                        _openPurchaseDetails(
                          purchase,
                        );
                      },
                      icon:
                          const Icon(
                        Icons
                            .visibility_outlined,
                      ),
                      label:
                          const Text(
                        'Details',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () {
                      _openEditPurchase(
                        purchase,
                      );
                    },
                    icon:
                        const Icon(
                      Icons
                          .edit_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () {
                      _deletePurchase(
                        purchase,
                      );
                    },
                    icon:
                        const Icon(
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

  Widget _buildAmountInfo(
    ThemeData theme,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        right: 8,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
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
            height: 4,
          ),
          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: theme
                .textTheme
                .bodyMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    String status,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(
          30,
        ),
      ),
      child: Text(
        status.isEmpty
            ? 'Unknown'
            : status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }

  // ===========================================================================
  // PURCHASE DETAILS
  // ===========================================================================

  

  
  // ===========================================================================
  // STATES
  // ===========================================================================

  Widget _buildEmptyState(
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 50,
        ),
        child: Column(
          children: [
            Icon(
              Icons
                  .shopping_cart_outlined,
              size: 64,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'No purchases yet',
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 7,
            ),
            Text(
              'Start recording your purchases to maintain purchase history and stock.',
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
                  _openAddPurchase,
              icon:
                  const Icon(
                Icons
                    .add_shopping_cart_rounded,
              ),
              label:
                  const Text(
                'Add Purchase',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 40,
        ),
        child: Column(
          children: [
            Icon(
              Icons
                  .search_off_rounded,
              size: 56,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(
              height: 14,
            ),
            Text(
              'No matching purchases',
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            Text(
              'Try changing your search or filters.',
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
              height: 12,
            ),
            TextButton.icon(
              onPressed:
                  _clearFilters,
              icon:
                  const Icon(
                Icons.clear_all_rounded,
              ),
              label:
                  const Text(
                'Clear Filters',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    ThemeData theme,
    String error,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              size: 56,
              color:
                  AppColors.danger,
            ),
            const SizedBox(
              height: 14,
            ),
            Text(
              'Unable to load purchases',
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 7,
            ),
            Text(
              error,
              textAlign:
                  TextAlign.center,
              maxLines: 3,
              overflow:
                  TextOverflow.ellipsis,
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

  Widget _buildNoBusinessState(
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .business_outlined,
              size: 60,
              color:
                  AppColors.warning,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Business not found',
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Please complete your business setup before recording purchases.',
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

  Color _paymentStatusColor(
    String status,
  ) {
    switch (status
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
    if (value ==
        value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(
      2,
    );
  }

  String _cleanError(
    Object error,
  ) {
    final String message =
        error.toString();

    if (message.startsWith(
      'Bad state: ',
    )) {
      return message.replaceFirst(
        'Bad state: ',
        '',
      );
    }

    if (message.startsWith(
      'Invalid argument(s): ',
    )) {
      return message.replaceFirst(
        'Invalid argument(s): ',
        '',
      );
    }

    return message;
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(message),
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              isError
                  ? AppColors.danger
                  : null,
        ),
      );
  }
}

// =============================================================================
// PURCHASE DETAILS SHEET
// =============================================================================

class _PurchaseDetailsSheet
    extends StatelessWidget {
  final PurchaseModel purchase;

  const _PurchaseDetailsSheet({
    required this.purchase,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final double outstanding =
        (purchase.total -
                purchase.paidAmount)
            .clamp(
      0,
      double.infinity,
    );

    final Color statusColor =
        _statusColor(
      purchase.paymentStatus,
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
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration:
                        BoxDecoration(
                      color: AppColors
                          .primary
                          .withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons
                          .shopping_cart_outlined,
                      color:
                          AppColors.primary,
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
                          'Purchase Details',
                          style: theme
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          purchase
                              .supplierName,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: theme
                              .textTheme
                              .bodyMedium,
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
                        30,
                      ),
                    ),
                    child: Text(
                      purchase
                          .paymentStatus,
                      style: TextStyle(
                        color:
                            statusColor,
                        fontWeight:
                            FontWeight
                                .w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 22,
              ),
              _detailRow(
                theme,
                'Supplier',
                purchase
                    .supplierName,
              ),
              _detailRow(
                theme,
                'Purchase Date',
                DateFormat(
                  'dd MMM yyyy, hh:mm a',
                ).format(
                  purchase.date,
                ),
              ),
              _detailRow(
                theme,
                'Payment Method',
                purchase
                    .paymentMethod,
              ),
              const SizedBox(
                height: 16,
              ),
              Text(
                'Purchased Products',
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              ...purchase.items.map(
                (item) =>
                    _itemCard(
                  theme,
                  item,
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              Card(
                margin:
                    EdgeInsets.zero,
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  child: Column(
                    children: [
                      _detailRow(
                        theme,
                        'Subtotal',
                        _formatCurrency(
                          purchase
                              .subtotal,
                        ),
                      ),
                      if (purchase
                              .discount >
                          0)
                        _detailRow(
                          theme,
                          'Discount',
                          '- ${_formatCurrency(purchase.discount)}',
                        ),
                      if (purchase.tax >
                          0)
                        _detailRow(
                          theme,
                          'Tax',
                          _formatCurrency(
                            purchase.tax,
                          ),
                        ),
                      const Divider(),
                      _detailRow(
                        theme,
                        'Total',
                        _formatCurrency(
                          purchase.total,
                        ),
                        isBold:
                            true,
                      ),
                      _detailRow(
                        theme,
                        'Paid',
                        _formatCurrency(
                          purchase
                              .paidAmount,
                        ),
                        valueColor:
                            AppColors
                                .success,
                      ),
                      _detailRow(
                        theme,
                        'Outstanding',
                        _formatCurrency(
                          outstanding,
                        ),
                        valueColor:
                            outstanding >
                                    0
                                ? AppColors
                                    .warning
                                : AppColors
                                    .success,
                      ),
                    ],
                  ),
                ),
              ),
              if (purchase.notes
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 16,
                ),
                Text(
                  'Notes',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  decoration:
                      BoxDecoration(
                    color: theme
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Text(
                    purchase.notes,
                    style: theme
                        .textTheme
                        .bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemCard(
    ThemeData theme,
    PurchaseItemModel item,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        border: Border.all(
          color: theme
              .colorScheme
              .outlineVariant,
        ),
        borderRadius:
            BorderRadius.circular(
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
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  '${_formatNumber(item.quantity)} ${item.unit} × ${_formatCurrency(item.purchaseRate)}',
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
            _formatCurrency(
              item.total,
            ),
            style: theme
                .textTheme
                .titleSmall
                ?.copyWith(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    ThemeData theme,
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 9,
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
          const SizedBox(
            width: 12,
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
                fontWeight: isBold
                    ? FontWeight.bold
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

  static Color _statusColor(
    String status,
  ) {
    switch (status
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

  static String _formatCurrency(
    double value,
  ) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  static String _formatNumber(
    double value,
  ) {
    if (value ==
        value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(
      2,
    );
  }
}