import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/product_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/product_repository.dart';

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() =>
      _StockReportScreenState();
}

class _StockReportScreenState
    extends State<StockReportScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final ProductRepository _productRepository =
      ProductRepository();

  final TextEditingController _searchController =
      TextEditingController();

  bool _loading = true;
  bool _refreshing = false;

  String? _errorMessage;
  String _searchQuery = '';
  String _selectedStatus = 'All';

  List<ProductModel> _allProducts =
      <ProductModel>[];

  static const List<String> _statuses = [
    'All',
    'In Stock',
    'Low Stock',
    'Out of Stock',
  ];

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
      final BusinessModel? business =
          await _businessRepository
              .getBusinessForCurrentUser();

      if (business == null) {
        throw Exception(
          'Business information is not available.',
        );
      }

      final List<ProductModel> products =
          await _productRepository.getProducts(
        business.id,
      );

      if (!mounted) return;

      setState(() {
        _allProducts = products;
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
    await _loadReport(showLoader: false);
  }

  // ===========================================================================
  // FILTER
  // ===========================================================================

  List<ProductModel> get _filteredProducts {
    final String query =
        _searchQuery.trim().toLowerCase();

    final List<ProductModel> products =
        _allProducts.where((product) {
      final double stock =
          product.currentStock;

      final bool isOutOfStock =
          stock <= 0;

      final bool isLowStock =
          !isOutOfStock &&
          stock <= product.minimumStock;

      switch (_selectedStatus) {
        case 'In Stock':
          if (isOutOfStock || isLowStock) {
            return false;
          }
          break;

        case 'Low Stock':
          if (!isLowStock) {
            return false;
          }
          break;

        case 'Out of Stock':
          if (!isOutOfStock) {
            return false;
          }
          break;
      }

      if (query.isEmpty) {
        return true;
      }

      return product.name
              .toLowerCase()
              .contains(query) ||
          product.category
              .toLowerCase()
              .contains(query) ||
          product.unit
              .toLowerCase()
              .contains(query);
    }).toList();

    products.sort(
      (a, b) => a.name
          .toLowerCase()
          .compareTo(
            b.name.toLowerCase(),
          ),
    );

    return products;
  }

  // ===========================================================================
  // CALCULATIONS
  // ===========================================================================

  double _stockValue(
    ProductModel product,
  ) {
    return product.currentStock *
        product.purchasePrice;
  }

  double _potentialSalesValue(
    ProductModel product,
  ) {
    return product.currentStock *
        product.sellingPrice;
  }

  double get _totalStockValue {
    return _allProducts.fold(
      0,
      (sum, product) =>
          sum + _stockValue(product),
    );
  }

  double get _totalPotentialSalesValue {
    return _allProducts.fold(
      0,
      (sum, product) =>
          sum +
          _potentialSalesValue(product),
    );
  }

  double get _totalCurrentStock {
    return _allProducts.fold(
      0,
      (sum, product) =>
          sum + product.currentStock,
    );
  }

  int get _lowStockCount {
    return _allProducts.where(
      (product) {
        return product.currentStock > 0 &&
            product.currentStock <=
                product.minimumStock;
      },
    ).length;
  }

  int get _outOfStockCount {
    return _allProducts.where(
      (product) {
        return product.currentStock <= 0;
      },
    ).length;
  }

  int get _inStockCount {
    return _allProducts.where(
      (product) {
        return product.currentStock >
                product.minimumStock &&
            product.currentStock > 0;
      },
    ).length;
  }

  double _inventoryCoveragePercent(
    ProductModel product,
  ) {
    if (product.minimumStock <= 0) {
      return product.currentStock > 0
          ? 100
          : 0;
    }

    return ((product.currentStock /
                product.minimumStock) *
            100)
        .clamp(0, 100);
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

    final List<ProductModel> products =
        _filteredProducts;

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
                      theme,
                      isDesktop,
                    ),
                    const SizedBox(height: 20),
                    _buildStatusOverview(
                      theme,
                    ),
                    const SizedBox(height: 20),
                    _buildFilters(
                      theme,
                    ),
                    const SizedBox(height: 20),
                    _buildProductList(
                      theme,
                      products,
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
              Icons.inventory_2_rounded,
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
                  'Stock Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Monitor current inventory, stock value, low-stock products and out-of-stock items.',
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
                    '${_allProducts.length} products',
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
    ThemeData theme,
    bool isDesktop,
  ) {
    final List<_SummaryItem> items = [
      _SummaryItem(
        title: 'Stock Value',
        value: _currency(
          _totalStockValue,
        ),
        subtitle: 'Purchase value',
        icon:
            Icons.account_balance_wallet_rounded,
        color: AppColors.primary,
      ),
      _SummaryItem(
        title: 'Potential Sales',
        value: _currency(
          _totalPotentialSalesValue,
        ),
        subtitle: 'Selling value',
        icon: Icons.trending_up_rounded,
        color: AppColors.success,
      ),
      _SummaryItem(
        title: 'Current Stock',
        value: _number(
          _totalCurrentStock,
        ),
        subtitle: 'Total quantity',
        icon: Icons.inventory_2_rounded,
        color: AppColors.secondary,
      ),
      _SummaryItem(
        title: 'Low / Out',
        value:
            '$_lowStockCount / $_outOfStockCount',
        subtitle: 'Need attention',
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
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
  // STATUS OVERVIEW
  // ===========================================================================

  Widget _buildStatusOverview(
    ThemeData theme,
  ) {
    final int total =
        _allProducts.length;

    final double inStockPercentage =
        total > 0
            ? (_inStockCount / total) * 100
            : 0;

    final double lowStockPercentage =
        total > 0
            ? (_lowStockCount / total) * 100
            : 0;

    final double outStockPercentage =
        total > 0
            ? (_outOfStockCount / total) * 100
            : 0;

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.donut_small_rounded,
            title: 'Inventory Health',
            subtitle:
                'Current product stock status',
          ),
          const SizedBox(height: 18),
          _StatusBar(
            label: 'In Stock',
            count: _inStockCount,
            percentage: inStockPercentage,
            color: AppColors.success,
          ),
          const SizedBox(height: 14),
          _StatusBar(
            label: 'Low Stock',
            count: _lowStockCount,
            percentage: lowStockPercentage,
            color: AppColors.warning,
          ),
          const SizedBox(height: 14),
          _StatusBar(
            label: 'Out of Stock',
            count: _outOfStockCount,
            percentage: outStockPercentage,
            color: AppColors.danger,
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
                  'Search product, category or unit...',
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
            spacing: 8,
            runSpacing: 8,
            children:
                _statuses.map(
              (status) {
                return ChoiceChip(
                  label: Text(status),
                  selected:
                      _selectedStatus ==
                          status,
                  onSelected: (_) {
                    setState(() {
                      _selectedStatus =
                          status;
                    });
                  },
                );
              },
            ).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PRODUCT LIST
  // ===========================================================================

  Widget _buildProductList(
    ThemeData theme,
    List<ProductModel> products,
  ) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.inventory_2_rounded,
            title: 'Product-wise Stock',
            subtitle:
                '${products.length} product${products.length == 1 ? '' : 's'} found',
          ),
          const SizedBox(height: 18),
          if (products.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.inventory_2_outlined,
              message:
                  'No products match the selected filters.',
            )
          else
            ...products.map(
              (product) {
                return _ProductStockTile(
                  product: product,
                  currency: _currency,
                  number: _number,
                  stockValue:
                      _stockValue(product),
                  potentialSalesValue:
                      _potentialSalesValue(
                    product,
                  ),
                  coverage:
                      _inventoryCoveragePercent(
                    product,
                  ),
                  onTap: () {
                    _showProductDetails(
                      product,
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
  // PRODUCT DETAILS
  // ===========================================================================

  void _showProductDetails(
    ProductModel product,
  ) {
    final ThemeData theme =
        Theme.of(context);

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

    final String status =
        outOfStock
            ? 'Out of Stock'
            : lowStock
                ? 'Low Stock'
                : 'In Stock';

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
                        width: 48,
                        height: 48,
                        decoration:
                            BoxDecoration(
                          color: statusColor
                              .withValues(
                            alpha: 0.10,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                        child: Icon(
                          Icons
                              .inventory_2_rounded,
                          color:
                              statusColor,
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
                              product.name,
                              style: sheetTheme
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              product.category
                                      .trim()
                                      .isEmpty
                                  ? 'Product'
                                  : product.category,
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
                          status,
                          style: TextStyle(
                            color:
                                statusColor,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(18),
                    decoration:
                        BoxDecoration(
                      color: statusColor
                          .withValues(
                        alpha: 0.06,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                      border: Border.all(
                        color: statusColor
                            .withValues(
                          alpha: 0.16,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _number(
                            product.currentStock,
                          ),
                          style: sheetTheme
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                            color:
                                statusColor,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          product.unit,
                          style: sheetTheme
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            color: sheetTheme
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DetailRow(
                    label: 'Minimum Stock',
                    value:
                        '${_number(product.minimumStock)} ${product.unit}',
                  ),
                  _DetailRow(
                    label: 'Purchase Price',
                    value:
                        _currency(
                      product.purchasePrice,
                    ),
                  ),
                  _DetailRow(
                    label: 'Selling Price',
                    value:
                        _currency(
                      product.sellingPrice,
                    ),
                  ),
                  _DetailRow(
                    label: 'Current Stock Value',
                    value:
                        _currency(
                      _stockValue(product),
                    ),
                  ),
                  _DetailRow(
                    label:
                        'Potential Sales Value',
                    value:
                        _currency(
                      _potentialSalesValue(
                        product,
                      ),
                    ),
                  ),
                  _DetailRow(
                    label: 'Stock Coverage',
                    value:
                        '${_inventoryCoveragePercent(product).toStringAsFixed(1)}%',
                  ),
                  _DetailRow(
                    label: 'Unit',
                    value: product.unit,
                  ),
                  if (product.category
                      .trim()
                      .isNotEmpty)
                    _DetailRow(
                      label: 'Category',
                      value:
                          product.category,
                    ),
                  _DetailRow(
                    label: 'Product Status',
                    value:
                        product.isActive
                            ? 'Active'
                            : 'Inactive',
                  ),
                  const SizedBox(height: 8),
                  if (outOfStock)
                    _AlertBox(
                      color:
                          AppColors.danger,
                      icon:
                          Icons.error_outline_rounded,
                      message:
                          'This product is currently out of stock.',
                    )
                  else if (lowStock)
                    _AlertBox(
                      color:
                          AppColors.warning,
                      icon:
                          Icons.warning_amber_rounded,
                      message:
                          'Stock is at or below the minimum stock level.',
                    )
                ],
              ),
            ),
          ),
        );
      },
    );

    // Keep theme referenced for analyzer-safe local context.
    if (theme.brightness ==
        Brightness.dark) {
      // Theme is intentionally resolved
      // before opening the sheet.
    }
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
                  'Unable to load Stock Report',
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
// STATUS BAR
// =============================================================================

class _StatusBar
    extends StatelessWidget {
  final String label;
  final int count;
  final double percentage;
  final Color color;

  const _StatusBar({
    required this.label,
    required this.count,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(
                color: color,
                shape:
                    BoxShape.circle,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
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
              '$count',
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: color,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius:
              BorderRadius.circular(20),
          child:
              LinearProgressIndicator(
            value: (percentage / 100)
                .clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: theme
                .colorScheme
                .outlineVariant
                .withValues(
              alpha: 0.35,
            ),
            valueColor:
                AlwaysStoppedAnimation<
                    Color>(
              color,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// PRODUCT TILE
// =============================================================================

class _ProductStockTile
    extends StatelessWidget {
  final ProductModel product;
  final String Function(double) currency;
  final String Function(double) number;
  final double stockValue;
  final double potentialSalesValue;
  final double coverage;
  final VoidCallback onTap;

  const _ProductStockTile({
    required this.product,
    required this.currency,
    required this.number,
    required this.stockValue,
    required this.potentialSalesValue,
    required this.coverage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

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

    final String status =
        outOfStock
            ? 'Out'
            : lowStock
                ? 'Low'
                : 'Good';

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
                    color: statusColor
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      11,
                    ),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color:
                        statusColor,
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
                        product.name,
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
                        '${product.category.trim().isEmpty ? 'Product' : product.category} • ${product.unit}',
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
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color:
                          statusColor,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Current',
                    value:
                        '${number(product.currentStock)} ${product.unit}',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Minimum',
                    value:
                        '${number(product.minimumStock)} ${product.unit}',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Stock Value',
                    value:
                        currency(stockValue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    child:
                        LinearProgressIndicator(
                      value:
                          coverage / 100,
                      minHeight: 7,
                      backgroundColor:
                          theme
                              .colorScheme
                              .outlineVariant
                              .withValues(
                        alpha: 0.35,
                      ),
                      valueColor:
                          AlwaysStoppedAnimation<
                              Color>(
                        statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${coverage.toStringAsFixed(0)}%',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color:
                        statusColor,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment:
                  Alignment.centerRight,
              child: Text(
                'Potential sales: ${currency(potentialSalesValue)}',
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// METRIC
// =============================================================================

class _Metric
    extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({
    required this.label,
    required this.value,
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
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
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
// ALERT
// =============================================================================

class _AlertBox
    extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;

  const _AlertBox({
    required this.color,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
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