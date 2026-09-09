import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/product_model.dart';
import '../../models/stock_transaction_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/stock_repository.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final ProductRepository _productRepository =
      ProductRepository();

  final StockRepository _stockRepository =
      StockRepository();

  final TextEditingController _searchController =
      TextEditingController();

  String? _businessId;

  bool _isLoadingBusiness = true;

  String _searchQuery = '';

  String _selectedFilter = 'All';

  final List<String> _filters = const [
    'All',
    'Low Stock',
    'Out of Stock',
  ];

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
    try {
      final business =
          await _businessRepository.getBusinessForCurrentUser();

      if (!mounted) {
        return;
      }

      setState(() {
        _businessId = business?.id;
        _isLoadingBusiness = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingBusiness = false;
      });
    }
  }

  List<ProductModel> _filterProducts(
    List<ProductModel> products,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    return products.where(
      (product) {
        final matchesSearch =
            query.isEmpty ||
                product.name.toLowerCase().contains(query) ||
                product.category.toLowerCase().contains(query) ||
                product.unit.toLowerCase().contains(query);

        if (!matchesSearch) {
          return false;
        }

        switch (_selectedFilter) {
          case 'Low Stock':
            return product.currentStock <= product.minimumStock &&
                product.currentStock > 0;

          case 'Out of Stock':
            return product.currentStock <= 0;

          case 'All':
          default:
            return true;
        }
      },
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoadingBusiness) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_businessId == null || _businessId!.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Inventory'),
        ),
        body: _buildNoBusinessState(theme),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            tooltip: 'Stock History',
            onPressed: _openStockHistory,
            icon: const Icon(
              Icons.history_rounded,
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ProductModel>>(
        stream: _productRepository.watchProducts(
          _businessId!,
        ),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(
              theme,
              snapshot.error.toString(),
            );
          }

          final products =
              snapshot.data ?? <ProductModel>[];

          final filteredProducts =
              _filterProducts(products);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                100,
              ),
              children: [
                _buildHeader(
                  theme,
                  products,
                ),
                const SizedBox(height: 20),
                _buildSearchAndFilter(
                  theme,
                ),
                const SizedBox(height: 20),
                _buildInventoryList(
                  theme,
                  products,
                  filteredProducts,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _openStockAdjustment,
        icon: const Icon(
          Icons.inventory_2_outlined,
        ),
        label: const Text(
          'Adjust Stock',
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }

    setState(() {});
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    List<ProductModel> products,
  ) {
    final activeProducts = products
        .where(
          (product) => product.isActive,
        )
        .length;

    final lowStockProducts = products
        .where(
          (product) =>
              product.isActive &&
              product.currentStock <= product.minimumStock &&
              product.currentStock > 0,
        )
        .length;

    final outOfStockProducts = products
        .where(
          (product) =>
              product.isActive &&
              product.currentStock <= 0,
        )
        .length;

    final stockValue = products
        .where(
          (product) => product.isActive,
        )
        .fold<double>(
          0,
          (total, product) =>
              total +
              (product.currentStock *
                  product.purchasePrice),
        );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Inventory Management',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Monitor stock, low-stock alerts and stock value.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final compact =
                constraints.maxWidth < 700;

            if (compact) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          theme,
                          title: 'Products',
                          value:
                              activeProducts.toString(),
                          icon: Icons.inventory_2_outlined,
                          iconColor:
                              AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          theme,
                          title: 'Low Stock',
                          value:
                              lowStockProducts.toString(),
                          icon: Icons.warning_amber_rounded,
                          iconColor:
                              AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          theme,
                          title: 'Out of Stock',
                          value:
                              outOfStockProducts.toString(),
                          icon: Icons.remove_shopping_cart_outlined,
                          iconColor:
                              AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          theme,
                          title: 'Stock Value',
                          value:
                              _formatCurrency(stockValue),
                          icon: Icons.currency_rupee_rounded,
                          iconColor:
                              AppColors.success,
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
                  child: _buildSummaryCard(
                    theme,
                    title: 'Products',
                    value:
                        activeProducts.toString(),
                    icon: Icons.inventory_2_outlined,
                    iconColor:
                        AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildSummaryCard(
                    theme,
                    title: 'Low Stock',
                    value:
                        lowStockProducts.toString(),
                    icon: Icons.warning_amber_rounded,
                    iconColor:
                        AppColors.warning,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildSummaryCard(
                    theme,
                    title: 'Out of Stock',
                    value:
                        outOfStockProducts.toString(),
                    icon: Icons.remove_shopping_cart_outlined,
                    iconColor:
                        AppColors.danger,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildSummaryCard(
                    theme,
                    title: 'Stock Value',
                    value:
                        _formatCurrency(stockValue),
                    icon: Icons.currency_rupee_rounded,
                    iconColor:
                        AppColors.success,
                  ),
                ),
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
    required Color iconColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(
                  alpha: 0.12,
                ),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
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
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        theme.textTheme.bodySmall?.copyWith(
                      color: theme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        theme.textTheme.titleLarge?.copyWith(
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

  Widget _buildSearchAndFilter(
    ThemeData theme,
  ) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        if (constraints.maxWidth < 650) {
          return Column(
            children: [
              _buildSearchField(theme),
              const SizedBox(height: 12),
              _buildFilter(theme),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildSearchField(theme),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 190,
              child: _buildFilter(theme),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchField(
    ThemeData theme,
  ) {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText:
            'Search product, category or unit...',
        prefixIcon: const Icon(
          Icons.search_rounded,
        ),
        suffixIcon:
            _searchQuery.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();

                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    icon: const Icon(
                      Icons.clear_rounded,
                    ),
                  )
                : null,
        filled: true,
      ),
    );
  }

  Widget _buildFilter(
    ThemeData theme,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedFilter,
      decoration: const InputDecoration(
        labelText: 'Filter',
        prefixIcon: Icon(
          Icons.filter_list_rounded,
        ),
      ),
      items: _filters
          .map(
            (filter) => DropdownMenuItem<String>(
              value: filter,
              child: Text(filter),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _selectedFilter = value;
        });
      },
    );
  }

  Widget _buildInventoryList(
    ThemeData theme,
    List<ProductModel> allProducts,
    List<ProductModel> filteredProducts,
  ) {
    if (allProducts.isEmpty) {
      return _buildEmptyState(theme);
    }

    if (filteredProducts.isEmpty) {
      return _buildNoResultsState(theme);
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Stock Overview',
                style:
                    theme.textTheme.titleLarge?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${filteredProducts.length} products',
              style:
                  theme.textTheme.bodySmall?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...filteredProducts.map(
          (product) => _buildProductCard(
            theme,
            product,
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(
    ThemeData theme,
    ProductModel product,
  ) {
    final bool outOfStock =
        product.currentStock <= 0;

    final bool lowStock =
        !outOfStock &&
            product.currentStock <=
                product.minimumStock;

    final Color statusColor = outOfStock
        ? AppColors.danger
        : lowStock
            ? AppColors.warning
            : AppColors.success;

    final String statusText = outOfStock
        ? 'Out of Stock'
        : lowStock
            ? 'Low Stock'
            : 'In Stock';

    final double stockValue =
        product.currentStock *
            product.purchasePrice;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _openProductDetails(product);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color:
                          AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        if (product
                            .category
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            product.category,
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    statusText,
                    statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (
                  context,
                  constraints,
                ) {
                  final compact =
                      constraints.maxWidth < 500;

                  if (compact) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child:
                                  _buildStockInfo(
                                theme,
                                'Current Stock',
                                _formatNumber(
                                  product.currentStock,
                                ),
                                product.unit,
                                statusColor,
                              ),
                            ),
                            Expanded(
                              child:
                                  _buildStockInfo(
                                theme,
                                'Minimum',
                                _formatNumber(
                                  product.minimumStock,
                                ),
                                product.unit,
                                AppColors.warning,
                              ),
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
                                  _buildStockInfo(
                                theme,
                                'Purchase Price',
                                _formatCurrency(
                                  product.purchasePrice,
                                ),
                                '',
                                AppColors.info,
                              ),
                            ),
                            Expanded(
                              child:
                                  _buildStockInfo(
                                theme,
                                'Stock Value',
                                _formatCurrency(
                                  stockValue,
                                ),
                                '',
                                AppColors.success,
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
                        child: _buildStockInfo(
                          theme,
                          'Current Stock',
                          _formatNumber(
                            product.currentStock,
                          ),
                          product.unit,
                          statusColor,
                        ),
                      ),
                      Expanded(
                        child: _buildStockInfo(
                          theme,
                          'Minimum',
                          _formatNumber(
                            product.minimumStock,
                          ),
                          product.unit,
                          AppColors.warning,
                        ),
                      ),
                      Expanded(
                        child: _buildStockInfo(
                          theme,
                          'Purchase Price',
                          _formatCurrency(
                            product.purchasePrice,
                          ),
                          '',
                          AppColors.info,
                        ),
                      ),
                      Expanded(
                        child: _buildStockInfo(
                          theme,
                          'Stock Value',
                          _formatCurrency(
                            stockValue,
                          ),
                          '',
                          AppColors.success,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _openStockAdjustment(
                          product: product,
                        );
                      },
                      icon: const Icon(
                        Icons.swap_vert_rounded,
                      ),
                      label: const Text(
                        'Adjust Stock',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Stock History',
                    onPressed: () {
                      _openProductHistory(
                        product,
                      );
                    },
                    icon: const Icon(
                      Icons.history_rounded,
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

  Widget _buildStockInfo(
    ThemeData theme,
    String label,
    String value,
    String unit,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        right: 8,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                theme.textTheme.bodySmall?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 50,
        ),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style:
                  theme.textTheme.titleLarge?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add products first to start managing inventory.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodyMedium?.copyWith(
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

  Widget _buildNoResultsState(
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 40,
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 54,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'No matching products',
              style:
                  theme.textTheme.titleMedium?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try another search or filter.',
              style:
                  theme.textTheme.bodyMedium?.copyWith(
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

  Widget _buildErrorState(
    ThemeData theme,
    String error,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.danger,
            ),
            const SizedBox(height: 14),
            Text(
              'Unable to load inventory',
              style:
                  theme.textTheme.titleLarge?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadBusiness,
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

  Widget _buildNoBusinessState(
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.business_outlined,
              size: 60,
              color: AppColors.warning,
            ),
            const SizedBox(height: 16),
            Text(
              'Business not found',
              style:
                  theme.textTheme.titleLarge?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please complete your business setup first.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodyMedium?.copyWith(
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

  // ---------------------------------------------------------------------------
  // STOCK ADJUSTMENT
  // ---------------------------------------------------------------------------

  Future<void> _openStockAdjustment({
    ProductModel? product,
  }) async {
    if (_businessId == null) {
      return;
    }

    ProductModel? selectedProduct = product;

    final quantityController =
        TextEditingController();

    final unitCostController =
        TextEditingController(
      text: product?.purchasePrice
              .toStringAsFixed(2) ??
          '0',
    );

    final notesController =
        TextEditingController();

    String operation = 'IN';

    bool isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              context,
              setDialogState,
            ) {
              final theme =
                  Theme.of(context);

              final currentStock =
                  selectedProduct?.currentStock ??
                      0;

              final unit =
                  selectedProduct?.unit ?? '';

              return AlertDialog(
                title: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
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
                        Icons.swap_vert_rounded,
                        color:
                            AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Adjust Stock',
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        if (selectedProduct ==
                            null)
                          _buildProductSelector(
                            context,
                            selectedProduct,
                            (value) {
                              setDialogState(() {
                                selectedProduct =
                                    value;

                                unitCostController
                                    .text = value
                                        .purchasePrice
                                        .toStringAsFixed(
                                  2,
                                );
                              });
                            },
                          )
                        else
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
                            child: Row(
                              children: [
                                const Icon(
                                  Icons
                                      .inventory_2_outlined,
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
                                        selectedProduct!
                                            .name,
                                        style: theme
                                            .textTheme
                                            .titleSmall
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
                                        'Current: ${_formatNumber(currentStock)} $unit',
                                        style: theme
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'IN',
                              label:
                                  Text('Stock In'),
                              icon: Icon(
                                Icons
                                    .arrow_downward_rounded,
                              ),
                            ),
                            ButtonSegment<String>(
                              value: 'OUT',
                              label:
                                  Text('Stock Out'),
                              icon: Icon(
                                Icons
                                    .arrow_upward_rounded,
                              ),
                            ),
                          ],
                          selected: {
                            operation,
                          },
                          onSelectionChanged:
                              (selection) {
                            setDialogState(() {
                              operation =
                                  selection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller:
                              quantityController,
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              InputDecoration(
                            labelText:
                                'Quantity',
                            suffixText: unit,
                            prefixIcon:
                                const Icon(
                              Icons
                                  .format_list_numbered_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller:
                              unitCostController,
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Unit Cost',
                            prefixIcon:
                                Icon(
                              Icons
                                  .currency_rupee_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller:
                              notesController,
                          maxLines: 3,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Notes',
                            hintText:
                                'Optional stock adjustment note',
                            prefixIcon:
                                Icon(
                              Icons
                                  .notes_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            Navigator.pop(
                              dialogContext,
                            );
                          },
                    child: const Text(
                      'Cancel',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (selectedProduct ==
                                null) {
                              _showMessage(
                                'Please select a product.',
                                isError: true,
                              );
                              return;
                            }

                            final quantity =
                                double.tryParse(
                                      quantityController
                                          .text
                                          .trim(),
                                    ) ??
                                    0;

                            final unitCost =
                                double.tryParse(
                                      unitCostController
                                          .text
                                          .trim(),
                                    ) ??
                                    0;

                            if (quantity <= 0) {
                              _showMessage(
                                'Enter a valid quantity.',
                                isError: true,
                              );
                              return;
                            }

                            if (unitCost < 0) {
                              _showMessage(
                                'Unit cost cannot be negative.',
                                isError: true,
                              );
                              return;
                            }

                            if (operation ==
                                    'OUT' &&
                                quantity >
                                    selectedProduct!
                                        .currentStock) {
                              _showMessage(
                                'Insufficient stock. Available: ${_formatNumber(selectedProduct!.currentStock)} ${selectedProduct!.unit}',
                                isError: true,
                              );
                              return;
                            }

                            setDialogState(() {
                              isSaving = true;
                            });

                            try {
                              if (operation ==
                                  'IN') {
                                await _stockRepository
                                    .stockIn(
                                  businessId:
                                      _businessId!,
                                  productId:
                                      selectedProduct!
                                          .id,
                                  quantity:
                                      quantity,
                                  unitCost:
                                      unitCost,
                                  notes:
                                      notesController
                                          .text
                                          .trim(),
                                );
                              } else {
                                await _stockRepository
                                    .stockOut(
                                  businessId:
                                      _businessId!,
                                  productId:
                                      selectedProduct!
                                          .id,
                                  quantity:
                                      quantity,
                                  unitCost:
                                      unitCost,
                                  notes:
                                      notesController
                                          .text
                                          .trim(),
                                );
                              }

                              if (!context.mounted) {
                                return;
                              }

                              Navigator.pop(
                                dialogContext,
                              );

                              _showMessage(
                                operation == 'IN'
                                    ? 'Stock added successfully.'
                                    : 'Stock removed successfully.',
                              );
                            } catch (e) {
                              setDialogState(() {
                                isSaving = false;
                              });

                              _showMessage(
                                _cleanErrorMessage(
                                  e,
                                ),
                                isError: true,
                              );
                            }
                          },
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.check_rounded,
                          ),
                    label: Text(
                      isSaving
                          ? 'Saving...'
                          : 'Save',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      quantityController.dispose();
      unitCostController.dispose();
      notesController.dispose();
    }
  }

  Widget _buildProductSelector(
    BuildContext context,
    ProductModel? selectedProduct,
    ValueChanged<ProductModel> onSelected,
  ) {
    return FutureBuilder<List<ProductModel>>(
      future: _productRepository.getActiveProducts(
        _businessId!,
      ),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Product',
            ),
            child: SizedBox(
              height: 24,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          );
        }

        final products =
            snapshot.data ?? <ProductModel>[];

        return DropdownButtonFormField<String>(
          initialValue:
              selectedProduct?.id,
          decoration: const InputDecoration(
            labelText: 'Product',
            prefixIcon: Icon(
              Icons.inventory_2_outlined,
            ),
          ),
          items: products
              .map(
                (product) =>
                    DropdownMenuItem<String>(
                  value: product.id,
                  child: Text(
                    product.name,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }

            final selected =
                products.firstWhere(
              (item) => item.id == value,
            );

            onSelected(selected);
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // PRODUCT DETAILS
  // ---------------------------------------------------------------------------

  Future<void> _openProductDetails(
    ProductModel product,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);

        final bool outOfStock =
            product.currentStock <= 0;

        final bool lowStock =
            !outOfStock &&
                product.currentStock <=
                    product.minimumStock;

        final Color statusColor =
            outOfStock
                ? AppColors.danger
                : lowStock
                    ? AppColors.warning
                    : AppColors.success;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                        Icons.inventory_2_outlined,
                        color:
                            AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: theme
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          if (product.category
                              .trim()
                              .isNotEmpty)
                            Text(
                              product.category,
                              style: theme
                                  .textTheme
                                  .bodySmall,
                            ),
                        ],
                      ),
                    ),
                    _buildStatusChip(
                      outOfStock
                          ? 'Out of Stock'
                          : lowStock
                              ? 'Low Stock'
                              : 'In Stock',
                      statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _buildDetailRow(
                  theme,
                  'Current Stock',
                  '${_formatNumber(product.currentStock)} ${product.unit}',
                ),
                _buildDetailRow(
                  theme,
                  'Minimum Stock',
                  '${_formatNumber(product.minimumStock)} ${product.unit}',
                ),
                _buildDetailRow(
                  theme,
                  'Purchase Price',
                  _formatCurrency(
                    product.purchasePrice,
                  ),
                ),
                _buildDetailRow(
                  theme,
                  'Selling Price',
                  _formatCurrency(
                    product.sellingPrice,
                  ),
                ),
                _buildDetailRow(
                  theme,
                  'Stock Value',
                  _formatCurrency(
                    product.currentStock *
                        product.purchasePrice,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                      _openStockAdjustment(
                        product: product,
                      );
                    },
                    icon: const Icon(
                      Icons.swap_vert_rounded,
                    ),
                    label: const Text(
                      'Adjust Stock',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style:
                theme.textTheme.bodyMedium?.copyWith(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STOCK HISTORY
  // ---------------------------------------------------------------------------

  Future<void> _openStockHistory() async {
    if (_businessId == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SizedBox(
          height:
              MediaQuery.sizeOf(context).height *
                  0.85,
          child: _StockHistorySheet(
            repository: _stockRepository,
            businessId: _businessId!,
          ),
        );
      },
    );
  }

  Future<void> _openProductHistory(
    ProductModel product,
  ) async {
    if (_businessId == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SizedBox(
          height:
              MediaQuery.sizeOf(context).height *
                  0.85,
          child: _StockHistorySheet(
            repository: _stockRepository,
            businessId: _businessId!,
            productId: product.id,
            productName: product.name,
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

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

  String _cleanErrorMessage(
    Object error,
  ) {
    final message = error.toString();

    if (message.startsWith(
      'Bad state:',
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
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          backgroundColor: isError
              ? AppColors.danger
              : null,
        ),
      );
  }
}

// =============================================================================
// STOCK HISTORY SHEET
// =============================================================================

class _StockHistorySheet extends StatelessWidget {
  final StockRepository repository;
  final String businessId;
  final String? productId;
  final String? productName;

  const _StockHistorySheet({
    required this.repository,
    required this.businessId,
    this.productId,
    this.productName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Stream<List<StockTransactionModel>>
        stream = productId == null
            ? repository.watchStockTransactions(
                businessId: businessId,
              )
            : repository
                .watchProductStockTransactions(
                businessId: businessId,
                productId: productId!,
              );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            4,
            20,
            14,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.history_rounded,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  productName == null
                      ? 'Stock History'
                      : '${productName!} History',
                  style:
                      theme.textTheme.titleLarge?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<
              List<StockTransactionModel>>(
            stream: stream,
            builder: (
              context,
              snapshot,
            ) {
              if (snapshot.connectionState ==
                      ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(24),
                    child: Text(
                      snapshot.error.toString(),
                      textAlign:
                          TextAlign.center,
                    ),
                  ),
                );
              }

              final transactions =
                  snapshot.data ??
                      <StockTransactionModel>[];

              if (transactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 56,
                        color: theme
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      Text(
                        'No stock transactions yet.',
                        style: theme
                            .textTheme
                            .titleMedium,
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  30,
                ),
                itemCount:
                    transactions.length,
                separatorBuilder:
                    (_, _) =>
                        const SizedBox(
                  height: 10,
                ),
                itemBuilder:
                    (context, index) {
                  final transaction =
                      transactions[index];

                  return _buildTransactionCard(
                    context,
                    transaction,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    StockTransactionModel transaction,
  ) {
    final theme = Theme.of(context);

    final bool isIn =
        transaction.transactionType ==
                StockRepository.stockInType ||
            transaction.transactionType ==
                '${StockRepository.adjustmentType} IN';

    final Color color = isIn
        ? AppColors.success
        : AppColors.danger;

    final IconData icon = isIn
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;

    final dateFormat =
        DateFormat('dd MMM yyyy, hh:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(12),
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
                    transaction.productName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: theme
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.transactionType,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: color,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(
                      transaction.date,
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
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIn ? '+' : '-'}${_formatNumber(transaction.quantity)}',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    color: color,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatNumber(transaction.stockBefore)} → ${_formatNumber(transaction.stockAfter)}',
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
          ],
        ),
      ),
    );
  }

  String _formatNumber(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}