import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/purchase_stock_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/purchase_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/purchase_repository.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({
    super.key,
  });

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final PurchaseRepository _purchaseRepository =
      PurchaseRepository();

  final PurchaseStockService _purchaseStockService =
      PurchaseStockService();

  final TextEditingController _searchController =
      TextEditingController();

  BusinessModel? _business;
  bool _isLoadingBusiness = true;
  String? _businessError;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    setState(() {
      _isLoadingBusiness = true;
      _businessError = null;
    });

    try {
      final business =
          await _businessRepository.getBusinessForCurrentUser();

      if (!mounted) {
        return;
      }

      if (business == null) {
        setState(() {
          _business = null;
          _isLoadingBusiness = false;
          _businessError =
              'Business information was not found.';
        });
        return;
      }

      setState(() {
        _business = business;
        _isLoadingBusiness = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingBusiness = false;
        _businessError =
            'Unable to load business information.';
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  List<PurchaseModel> _filterPurchases(
    List<PurchaseModel> purchases,
  ) {
    final query =
        _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return purchases;
    }

    return purchases.where((purchase) {
      final supplierName =
          purchase.supplierName.toLowerCase();

      final supplierId =
          purchase.supplierId.toLowerCase();

      final paymentStatus =
          purchase.paymentStatus.toLowerCase();

      final paymentMethod =
          purchase.paymentMethod.toLowerCase();

      final notes =
          purchase.notes.toLowerCase();

      final itemNames = purchase.items
          .map(
            (item) => item.productName.toLowerCase(),
          )
          .join(' ');

      return supplierName.contains(query) ||
          supplierId.contains(query) ||
          paymentStatus.contains(query) ||
          paymentMethod.contains(query) ||
          notes.contains(query) ||
          itemNames.contains(query);
    }).toList();
  }

  Future<void> _deletePurchase(
    PurchaseModel purchase,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Purchase?',
          ),
          content: Text(
            'Are you sure you want to delete this purchase '
            'from ${purchase.supplierName.isEmpty ? 'this supplier' : purchase.supplierName}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || _business == null) {
      return;
    }

    try {
      // Reverse the stock that was added when this purchase was created.
      // The purchase is deleted only after stock reversal succeeds.
      await _purchaseStockService.reversePurchaseStock(
        purchase: purchase,
      );

      await _purchaseRepository.deletePurchase(
        businessId: _business!.id,
        purchaseId: purchase.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Purchase deleted and stock reversed successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete purchase: $e',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showPurchaseDetails(
    PurchaseModel purchase,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: SingleChildScrollView(
              child: _PurchaseDetails(
                purchase: purchase,
                onDelete: () {
                  Navigator.pop(context);
                  _deletePurchase(purchase);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _openAddPurchase() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Purchase entry screen will be connected next.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBusiness) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_businessError != null) {
      return _ErrorState(
        message: _businessError!,
        onRetry: _loadBusiness,
      );
    }

    if (_business == null) {
      return _ErrorState(
        message:
            'Business information is not available.',
        onRetry: _loadBusiness,
      );
    }

    return StreamBuilder<List<PurchaseModel>>(
      stream: _purchaseRepository.watchPurchases(
        businessId: _business!.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            message:
                'Unable to load purchases.',
            onRetry: () {
              setState(() {});
            },
          );
        }

        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final allPurchases =
            snapshot.data ?? <PurchaseModel>[];

        final purchases =
            _filterPurchases(allPurchases);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop =
                constraints.maxWidth >= 1000;

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: CustomScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 28 : 16,
                      20,
                      isDesktop ? 28 : 16,
                      28,
                    ),
                    sliver: SliverList(
                      delegate:
                          SliverChildListDelegate([
                        _buildHeader(
                          context,
                          isDesktop,
                          allPurchases.length,
                        ),
                        const SizedBox(height: 20),
                        _buildSummary(
                          allPurchases,
                          isDesktop,
                        ),
                        const SizedBox(height: 20),
                        _buildSearch(
                          isDesktop,
                        ),
                        const SizedBox(height: 20),
                        if (purchases.isEmpty)
                          _EmptyPurchases(
                            hasSearch: _searchController
                                .text
                                .trim()
                                .isNotEmpty,
                            onAdd: _openAddPurchase,
                          )
                        else
                          ...purchases.map(
                            (purchase) => Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom: 12,
                              ),
                              child:
                                  _PurchaseCard(
                                purchase: purchase,
                                onTap: () =>
                                    _showPurchaseDetails(
                                  purchase,
                                ),
                                onDelete: () =>
                                    _deletePurchase(
                                  purchase,
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDesktop,
    int purchaseCount,
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
                'Purchases',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                '$purchaseCount purchase${purchaseCount == 1 ? '' : 's'} recorded',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: AppColors.lightTextSecondary,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _openAddPurchase,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Purchase'),
        ),
      ],
    );
  }

  Widget _buildSummary(
    List<PurchaseModel> purchases,
    bool isDesktop,
  ) {
    final totalPurchases = purchases.fold<double>(
      0,
      (sum, purchase) => sum + purchase.total,
    );

    final totalPaid = purchases.fold<double>(
      0,
      (sum, purchase) => sum + purchase.paidAmount,
    );

    final totalOutstanding =
        totalPurchases - totalPaid;

    final cards = [
      _SummaryCardData(
        title: 'Total Purchase',
        value: _currency(totalPurchases),
        icon: Icons.shopping_cart_rounded,
        color: AppColors.primary,
      ),
      _SummaryCardData(
        title: 'Paid',
        value: _currency(totalPaid),
        icon: Icons.payments_rounded,
        color: AppColors.success,
      ),
      _SummaryCardData(
        title: 'Outstanding',
        value: _currency(
          totalOutstanding < 0
              ? 0
              : totalOutstanding,
        ),
        icon: Icons.pending_actions_rounded,
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
                      const EdgeInsets.only(right: 12),
                  child: _SummaryCard(
                    data: card,
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    return Column(
      children: cards
          .map(
            (card) => Padding(
              padding:
                  const EdgeInsets.only(bottom: 12),
              child: _SummaryCard(
                data: card,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSearch(
    bool isDesktop,
  ) {
    return TextField(
      controller: _searchController,
      onChanged: (_) {
        setState(() {});
      },
      decoration: InputDecoration(
        hintText:
            'Search supplier, product, payment status...',
        prefixIcon: const Icon(
          Icons.search_rounded,
        ),
        suffixIcon:
            _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: _clearSearch,
                    icon: const Icon(
                      Icons.clear_rounded,
                    ),
                  ),
        filled: true,
      ),
    );
  }

  String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }
}

class _PurchaseCard extends StatelessWidget {
  final PurchaseModel purchase;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PurchaseCard({
    required this.purchase,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        _statusColor(purchase.paymentStatus);

    final outstanding =
        purchase.total - purchase.paidAmount;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          purchase.supplierName
                                  .trim()
                                  .isEmpty
                              ? 'Supplier not specified'
                              : purchase.supplierName,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(purchase.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors
                                .lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
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
                                Icons.delete_outline,
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
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _CardMetric(
                      label: 'Items',
                      value:
                          '${purchase.items.length}',
                    ),
                  ),
                  Expanded(
                    child: _CardMetric(
                      label: 'Total',
                      value: _currency(
                        purchase.total,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _CardMetric(
                      label: 'Paid',
                      value: _currency(
                        purchase.paidAmount,
                      ),
                    ),
                  ),
                ],
              ),
              if (outstanding > 0) ...[
                const SizedBox(height: 12),
                Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Outstanding: ${_currency(outstanding)}',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatusChip(
                    label:
                        purchase.paymentStatus,
                    color: statusColor,
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(
    String status,
  ) {
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

  static String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }
}

class _PurchaseDetails extends StatelessWidget {
  final PurchaseModel purchase;
  final VoidCallback onDelete;

  const _PurchaseDetails({
    required this.purchase,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final outstanding =
        purchase.total - purchase.paidAmount;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Purchase Details',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: 'Delete',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DetailRow(
          label: 'Supplier',
          value: purchase.supplierName
                  .trim()
                  .isEmpty
              ? 'Not specified'
              : purchase.supplierName,
        ),
        _DetailRow(
          label: 'Purchase Date',
          value: DateFormat(
            'dd MMM yyyy, hh:mm a',
          ).format(purchase.date),
        ),
        _DetailRow(
          label: 'Payment Method',
          value: purchase.paymentMethod
                  .trim()
                  .isEmpty
              ? 'Not specified'
              : purchase.paymentMethod,
        ),
        _DetailRow(
          label: 'Payment Status',
          value: purchase.paymentStatus,
        ),
        const SizedBox(height: 20),
        const Text(
          'Products',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ...purchase.items.map(
          (item) => Container(
            margin:
                const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightBackground,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName
                                .trim()
                                .isEmpty
                            ? 'Product'
                            : item.productName,
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatNumber(item.quantity)} ${item.unit} × ${_currency(item.purchaseRate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors
                              .lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _currency(item.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AmountRow(
          label: 'Subtotal',
          value: purchase.subtotal,
        ),
        if (purchase.discount > 0)
          _AmountRow(
            label: 'Discount',
            value: -purchase.discount,
          ),
        if (purchase.tax > 0)
          _AmountRow(
            label: 'Tax',
            value: purchase.tax,
          ),
        const Divider(height: 24),
        _AmountRow(
          label: 'Total',
          value: purchase.total,
          isBold: true,
        ),
        _AmountRow(
          label: 'Paid',
          value: purchase.paidAmount,
        ),
        _AmountRow(
          label: 'Outstanding',
          value: outstanding < 0
              ? 0
              : outstanding,
          isBold: true,
        ),
        if (purchase.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            'Notes',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            purchase.notes,
            style: const TextStyle(
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ],
    );
  }

  static String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}

class _SummaryCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _SummaryCard extends StatelessWidget {
  final _SummaryCardData data;

  const _SummaryCard({
    required this.data,
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
                color: data.color
                    .withValues(alpha: 0.10),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                data.icon,
                color: data.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors
                          .lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.value,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
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

class _CardMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CardMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color:
                    AppColors.lightTextSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;

  const _AmountRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
          ),
          Text(
            NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹',
              decimalDigits: 2,
            ).format(value),
            style: TextStyle(
              fontWeight: isBold
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPurchases extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onAdd;

  const _EmptyPurchases({
    required this.hasSearch,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary
                    .withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'No purchases found'
                  : 'No purchases yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try a different supplier, product or payment search.'
                  : 'Start recording your purchases to build your purchase history.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:
                    AppColors.lightTextSecondary,
              ),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(
                  Icons.add_rounded,
                ),
                label: const Text(
                  'Add Purchase',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
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
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
