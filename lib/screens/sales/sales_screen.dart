import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/sale_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/sale_repository.dart';
import 'add_sale_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({
    super.key,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final BusinessRepository _businessRepository = BusinessRepository();

  final SaleRepository _saleRepository = SaleRepository();

  final TextEditingController _searchController =
      TextEditingController();

  BusinessModel? _business;

  bool _loadingBusiness = true;
  String? _businessError;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBusiness();

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        _searchQuery =
            _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // BUSINESS
  // ===========================================================================

  Future<void> _loadBusiness() async {
    if (!mounted) return;

    setState(() {
      _loadingBusiness = true;
      _businessError = null;
    });

    try {
      final BusinessModel? business =
          await _businessRepository.getBusinessForCurrentUser();

      if (!mounted) return;

      if (business == null) {
        setState(() {
          _business = null;
          _loadingBusiness = false;
          _businessError =
              'Business profile not found. Please complete business setup.';
        });
        return;
      }

      setState(() {
        _business = business;
        _loadingBusiness = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingBusiness = false;
        _businessError = e.toString();
      });
    }
  }

  // ===========================================================================
  // ADD SALE
  // ===========================================================================

  Future<void> _openAddSale() async {
    if (_business == null) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddSaleScreen(),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              sale.invoiceNumber.isEmpty
                                  ? 'Sale'
                                  : sale.invoiceNumber,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat(
                                'dd MMM yyyy, hh:mm a',
                              ).format(sale.date),
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
                        ),
                      ),
                      _StatusChip(
                        status: sale.paymentStatus,
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _DetailSection(
                    title: 'Customer',
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sale.customerName.isEmpty
                                ? 'Walk-in Customer'
                                : sale.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  _DetailSection(
                    title: 'Items',
                    child: Column(
                      children: sale.items.map(
                        (item) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${_formatNumber(item.quantity)} ${item.unit} × ${_formatCurrency(item.sellingRate)}',
                                        style:
                                            Theme.of(context)
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
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatCurrency(item.total),
                                  style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ).toList(),
                    ),
                  ),

                  const SizedBox(height: 6),

                  _SummaryCard(
                    subtotal: sale.subtotal,
                    discount: sale.discount,
                    tax: sale.tax,
                    total: sale.total,
                    paid: sale.paidAmount,
                  ),

                  const SizedBox(height: 16),

                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Payment Method',
                    value: sale.paymentMethod.isEmpty
                        ? 'Not specified'
                        : sale.paymentMethod,
                  ),

                  if (sale.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.notes_rounded,
                      label: 'Notes',
                      value: sale.notes,
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
  // DELETE
  // ===========================================================================

  Future<void> _deleteSale(
    SaleModel sale,
  ) async {
    final BusinessModel? business = _business;

    if (business == null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Sale?',
          ),
          content: Text(
            'Are you sure you want to delete '
            '${sale.invoiceNumber.isEmpty ? 'this sale' : sale.invoiceNumber}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _saleRepository.deleteSale(
        businessId: business.id,
        saleId: sale.id,
      );

      if (!mounted) return;

      _showMessage(
        'Sale deleted successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to delete sale: $e',
        isError: true,
      );
    }
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  List<SaleModel> _filterSales(
    List<SaleModel> sales,
  ) {
    if (_searchQuery.isEmpty) {
      return sales;
    }

    return sales.where(
      (sale) {
        final String invoice =
            sale.invoiceNumber.toLowerCase();

        final String customer =
            sale.customerName.toLowerCase();

        final String notes =
            sale.notes.toLowerCase();

        final bool productMatch = sale.items.any(
          (item) => item.productName
              .toLowerCase()
              .contains(_searchQuery),
        );

        return invoice.contains(_searchQuery) ||
            customer.contains(_searchQuery) ||
            notes.contains(_searchQuery) ||
            productMatch;
      },
    ).toList();
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
          content: Text(message),
          backgroundColor: isError
              ? AppColors.danger
              : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_loadingBusiness) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_businessError != null) {
      return _buildErrorState();
    }

    final BusinessModel? business = _business;

    if (business == null) {
      return _buildNoBusinessState();
    }

    return StreamBuilder<List<SaleModel>>(
      stream: _saleRepository.watchSales(
        businessId: business.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _buildStreamErrorState(
            snapshot.error.toString(),
          );
        }

        final List<SaleModel> sales =
            _filterSales(
          snapshot.data ?? <SaleModel>[],
        );

        return RefreshIndicator(
          onRefresh: () async {
            await _loadBusiness();
          },
          child: LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              final bool isDesktop =
                  constraints.maxWidth >= 900;

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
                      maxWidth: 1200,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _buildHeader(
                          isDesktop,
                        ),

                        const SizedBox(height: 20),

                        _buildSummary(
                          snapshot.data ??
                              <SaleModel>[],
                          isDesktop,
                        ),

                        const SizedBox(height: 20),

                        _buildSearchCard(),

                        const SizedBox(height: 20),

                        _buildSalesSection(
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
      },
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(
    bool isDesktop,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(
              alpha: 0.12,
            ),
            borderRadius:
                BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.point_of_sale_rounded,
            color: AppColors.success,
            size: 27,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Sales',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                'Manage sales, invoices and payments.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: Theme.of(context)
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
    List<SaleModel> sales,
    bool isDesktop,
  ) {
    double total = 0;
    double paid = 0;
    double outstanding = 0;

    for (final SaleModel sale in sales) {
      total += sale.total;
      paid += sale.paidAmount;

      final double balance =
          sale.total - sale.paidAmount;

      if (balance > 0) {
        outstanding += balance;
      }
    }

    final int count = sales.length;

    final List<Widget> cards = [
      _SummaryMetricCard(
        icon: Icons.receipt_long_rounded,
        title: 'Total Sales',
        value: _formatCurrency(total),
        subtitle:
            '$count invoice${count == 1 ? '' : 's'}',
        color: AppColors.primary,
      ),
      _SummaryMetricCard(
        icon: Icons.payments_rounded,
        title: 'Collected',
        value: _formatCurrency(paid),
        subtitle: 'Amount received',
        color: AppColors.success,
      ),
      _SummaryMetricCard(
        icon:
            Icons.account_balance_wallet_outlined,
        title: 'Outstanding',
        value: _formatCurrency(outstanding),
        subtitle: 'Amount pending',
        color: AppColors.warning,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map(
              (card) => Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.only(
                    right: 12,
                  ),
                  child: card,
                ),
              ),
            )
            .toList(),
      );
    }

    return Column(
      children: [
        cards[0],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: cards[1],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: cards[2],
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Widget _buildSearchCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: TextField(
          controller: _searchController,
          textInputAction:
              TextInputAction.search,
          decoration: InputDecoration(
            hintText:
                'Search invoice, customer or product...',
            prefixIcon: const Icon(
              Icons.search_rounded,
            ),
            suffixIcon:
                _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
            border: InputBorder.none,
            filled: false,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SALES LIST
  // ===========================================================================

  Widget _buildSalesSection(
    List<SaleModel> sales,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
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
                    _searchQuery.isEmpty
                        ? 'Recent Sales'
                        : 'Search Results',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  '${sales.length}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w600,
                        color: Theme.of(context)
                            .colorScheme
                            .primary,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (sales.isEmpty)
              _buildEmptyState()
            else
              ...sales.map(
                (sale) => _SaleListTile(
                  sale: sale,
                  onTap: () {
                    _showSaleDetails(
                      sale,
                    );
                  },
                  onDelete: () {
                    _deleteSale(
                      sale,
                    );
                  },
                ),
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
    final bool searching =
        _searchQuery.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 46,
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: 0.10,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                searching
                    ? Icons.search_off_rounded
                    : Icons.receipt_long_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              searching
                  ? 'No sales found'
                  : 'No sales yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              searching
                  ? 'Try a different invoice, customer or product.'
                  : 'Create your first sale to see it here.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
            if (!searching) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _openAddSale,
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
  // ERROR STATES
  // ===========================================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: AppColors.danger,
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load business',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _businessError ??
                  'Something went wrong.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadBusiness,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBusinessState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Business profile not found.\n'
          'Please complete business setup.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildStreamErrorState(
    String error,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: AppColors.danger,
            ),
            const SizedBox(height: 14),
            Text(
              'Unable to load sales',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow:
                  TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {});
              },
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
  // FORMATTERS
  // ===========================================================================

  String _formatCurrency(
    double value,
  ) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits:
          value.truncateToDouble() == value
              ? 0
              : 2,
    ).format(value);
  }

  String _formatNumber(
    double value,
  ) {
    return value.truncateToDouble() == value
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }
}

// =============================================================================
// SUMMARY METRIC CARD
// =============================================================================

class _SummaryMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _SummaryMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: 0.12,
                ),
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
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
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: Theme.of(context)
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
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
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

class _SaleListTile extends StatelessWidget {
  final SaleModel sale;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SaleListTile({
    required this.sale,
    required this.onTap,
    required this.onDelete,
  });

  String _formatCurrency(
    double value,
  ) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits:
          value.truncateToDouble() == value
              ? 0
              : 2,
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    final double outstanding =
        sale.total - sale.paidAmount;

    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.success,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sale.invoiceNumber.isEmpty
                              ? 'Sale'
                              : sale.invoiceNumber,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(
                        status:
                            sale.paymentStatus,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    sale.customerName.isEmpty
                        ? 'Walk-in Customer'
                        : sale.customerName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    '${DateFormat('dd MMM yyyy').format(sale.date)} • ${sale.items.length} item${sale.items.length == 1 ? '' : 's'}',
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
              ),
            ),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(
                    sale.total,
                  ),
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  outstanding > 0
                      ? 'Due ${_formatCurrency(outstanding)}'
                      : 'Paid',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                    color: outstanding > 0
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ),
              ],
            ),

            PopupMenuButton<String>(
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color:
                              AppColors.danger,
                        ),
                        SizedBox(width: 10),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// STATUS CHIP
// =============================================================================

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({
    required this.status,
  });

  Color _color() {
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

  String _label() {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'partial':
        return 'Partial';
      case 'unpaid':
        return 'Unpaid';
      default:
        if (status.trim().isEmpty) {
          return 'Unknown';
        }

        return status[0].toUpperCase() +
            status.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _color();

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          fontSize: 11,
          fontWeight:
              FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// =============================================================================
// DETAIL SECTION
// =============================================================================

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
                    FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// =============================================================================
// SUMMARY CARD
// =============================================================================

class _SummaryCard extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paid;

  const _SummaryCard({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paid,
  });

  String _currency(
    double value,
  ) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits:
          value.truncateToDouble() == value
              ? 0
              : 2,
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    final double outstanding =
        total - paid;

    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _row(
            context,
            'Subtotal',
            _currency(subtotal),
          ),
          if (discount > 0)
            _row(
              context,
              'Discount',
              '- ${_currency(discount)}',
            ),
          if (tax > 0)
            _row(
              context,
              'Tax',
              _currency(tax),
            ),
          const Divider(height: 20),
          _row(
            context,
            'Total',
            _currency(total),
            bold: true,
          ),
          const SizedBox(height: 8),
          _row(
            context,
            'Paid',
            _currency(paid),
            valueColor:
                AppColors.success,
          ),
          const SizedBox(height: 8),
          _row(
            context,
            'Outstanding',
            _currency(
              outstanding > 0
                  ? outstanding
                  : 0,
            ),
            valueColor:
                outstanding > 0
                    ? AppColors.warning
                    : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight:
                  bold
                      ? FontWeight.bold
                      : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight:
                bold
                    ? FontWeight.bold
                    : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// INFO ROW
// =============================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight:
                FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
          ),
        ),
      ],
    );
  }
}
