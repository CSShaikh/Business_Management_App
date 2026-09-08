import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/product_model.dart';
import '../../repositories/product_repository.dart';
import 'add_product_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;

    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  String? get _businessId {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    return user.uid;
  }

  List<ProductModel> _filterProducts(
    List<ProductModel> products,
  ) {
    if (_searchQuery.isEmpty) {
      return products;
    }

    return products.where((product) {
      return product.name.toLowerCase().contains(_searchQuery) ||
          product.category.toLowerCase().contains(_searchQuery) ||
          product.unit.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _openAddProduct() async {
    final String? businessId = _businessId;

    if (businessId == null) {
      _showMessage(
        'Please login first.',
        isError: true,
      );
      return;
    }

    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          businessId: businessId,
        ),
      ),
    );

    if (result == true && mounted) {
      _showMessage(
        'Product added successfully.',
      );
    }
  }

  Future<void> _openEditProduct(
    ProductModel product,
  ) async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          businessId: product.businessId,
          product: product,
        ),
      ),
    );

    if (result == true && mounted) {
      _showMessage(
        'Product updated successfully.',
      );
    }
  }

  Future<void> _deleteProduct(
    ProductModel product,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Product?',
          ),
          content: Text(
            'Are you sure you want to delete "${product.name}"?',
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

    if (confirmed != true) {
      return;
    }

    try {
      await _productRepository.deleteProduct(
        product.businessId,
        product.id,
      );

      if (!mounted) return;

      _showMessage(
        'Product deleted successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to delete product.',
        isError: true,
      );
    }
  }

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
          backgroundColor:
              isError ? AppColors.danger : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final String? businessId = _businessId;

    if (businessId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Products'),
        ),
        body: const _LoginRequiredState(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Products',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProduct,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Add Product',
        ),
      ),
      body: StreamBuilder<List<ProductModel>>(
        stream: _productRepository.watchProducts(
          businessId,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(
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

          final List<ProductModel> products =
              snapshot.data ?? <ProductModel>[];

          final List<ProductModel> filteredProducts =
              _filterProducts(products);

          return LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop =
                  constraints.maxWidth >= 1000;

              final bool isTablet =
                  constraints.maxWidth >= 650 &&
                  constraints.maxWidth < 1000;

              return RefreshIndicator(
                onRefresh: () async {
                  await _productRepository
                      .getProducts(businessId);
                },
                child: CustomScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isDesktop ? 32 : 16,
                          20,
                          isDesktop ? 32 : 16,
                          12,
                        ),
                        child: _ProductsHeader(
                          totalProducts: products.length,
                          activeProducts: products
                              .where(
                                (product) =>
                                    product.isActive,
                              )
                              .length,
                          lowStockProducts: products
                              .where(
                                (product) =>
                                    product.isActive &&
                                    product.currentStock <=
                                        product.minimumStock,
                              )
                              .length,
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              isDesktop ? 32 : 16,
                        ),
                        child: _SearchField(
                          controller: _searchController,
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(
                        height: 16,
                      ),
                    ),

                    if (products.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyProductsState(),
                      )
                    else if (filteredProducts.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _NoSearchResultState(),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 100,
                        ),
                        sliver: isDesktop
                            ? SliverGrid(
                                delegate:
                                    SliverChildBuilderDelegate(
                                  (context, index) {
                                    final ProductModel product =
                                        filteredProducts[index];

                                    return _ProductCard(
                                      product: product,
                                      onEdit: () =>
                                          _openEditProduct(
                                        product,
                                      ),
                                      onDelete: () =>
                                          _deleteProduct(
                                        product,
                                      ),
                                    );
                                  },
                                  childCount:
                                      filteredProducts.length,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 420,
                                  mainAxisExtent: 220,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                              )
                            : SliverList(
                                delegate:
                                    SliverChildBuilderDelegate(
                                  (context, index) {
                                    final ProductModel product =
                                        filteredProducts[index];

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _ProductCard(
                                        product: product,
                                        compact: isTablet,
                                        onEdit: () =>
                                            _openEditProduct(
                                          product,
                                        ),
                                        onDelete: () =>
                                            _deleteProduct(
                                          product,
                                        ),
                                      ),
                                    );
                                  },
                                  childCount:
                                      filteredProducts.length,
                                ),
                              ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// PRODUCTS HEADER
// ============================================================

class _ProductsHeader extends StatelessWidget {
  final int totalProducts;
  final int activeProducts;
  final int lowStockProducts;

  const _ProductsHeader({
    required this.totalProducts,
    required this.activeProducts,
    required this.lowStockProducts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Management',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        Text(
          'Manage products, prices and inventory.',
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
        const SizedBox(
          height: 18,
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SummaryChip(
              icon: Icons.inventory_2_outlined,
              label: 'Total',
              value: totalProducts.toString(),
            ),
            _SummaryChip(
              icon: Icons.check_circle_outline,
              label: 'Active',
              value: activeProducts.toString(),
            ),
            _SummaryChip(
              icon: Icons.warning_amber_rounded,
              label: 'Low Stock',
              value: lowStockProducts.toString(),
              warning: lowStockProducts > 0,
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// SUMMARY CHIP
// ============================================================

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool warning;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = warning
        ? AppColors.warning
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 19,
            color: color,
          ),
          const SizedBox(
            width: 8,
          ),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SEARCH FIELD
// ============================================================

class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText:
            'Search product, category or unit...',
        prefixIcon: const Icon(
          Icons.search_rounded,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                onPressed: controller.clear,
                icon: const Icon(
                  Icons.clear_rounded,
                ),
              )
            : null,
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context)
                .dividerColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context)
                .dividerColor,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PRODUCT CARD
// ============================================================

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool compact;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    this.compact = false,
  });

  bool get isLowStock {
    return product.isActive &&
        product.currentStock <=
            product.minimumStock;
  }

  @override
  Widget build(BuildContext context) {
    final Color stockColor = !product.isActive
        ? Theme.of(context)
            .colorScheme
            .onSurfaceVariant
        : isLowStock
            ? AppColors.warning
            : AppColors.success;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
                    Icons.inventory_2_outlined,
                    color: AppColors.primary,
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
                        product.name,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      if (product.category
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          product.category,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: AppColors.danger,
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            const Divider(
              height: 1,
            ),

            const SizedBox(
              height: 14,
            ),

            Row(
              children: [
                Expanded(
                  child: _ProductInfo(
                    label: 'Purchase',
                    value:
                        '₹${product.purchasePrice.toStringAsFixed(2)}',
                  ),
                ),
                Expanded(
                  child: _ProductInfo(
                    label: 'Selling',
                    value:
                        '₹${product.sellingPrice.toStringAsFixed(2)}',
                  ),
                ),
                Expanded(
                  child: _ProductInfo(
                    label: 'Unit',
                    value: product.unit,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: stockColor
                    .withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    isLowStock
                        ? Icons.warning_amber_rounded
                        : Icons.inventory_2_outlined,
                    size: 18,
                    color: stockColor,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: Text(
                      'Stock: ${_formatNumber(product.currentStock)} ${product.unit}',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                        color: stockColor,
                      ),
                    ),
                  ),
                  if (isLowStock)
                    const Text(
                      'Low Stock',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            AppColors.warning,
                      ),
                    ),
                  if (!product.isActive)
                    const Text(
                      'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w800,
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

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}

// ============================================================
// PRODUCT INFO
// ============================================================

class _ProductInfo extends StatelessWidget {
  final String label;
  final String value;

  const _ProductInfo({
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
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context)
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
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// EMPTY PRODUCTS
// ============================================================

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppColors.primary
                    .withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            const Text(
              'No Products Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Add your first product to start managing inventory.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// NO SEARCH RESULT
// ============================================================

class _NoSearchResultState extends StatelessWidget {
  const _NoSearchResultState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(
              height: 14,
            ),
            const Text(
              'No Matching Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            Text(
              'Try searching with another product name or category.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ERROR STATE
// ============================================================

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.danger,
            ),
            const SizedBox(
              height: 14,
            ),
            const Text(
              'Unable to Load Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            FilledButton.icon(
              onPressed: onRetry,
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
}

// ============================================================
// LOGIN REQUIRED
// ============================================================

class _LoginRequiredState extends StatelessWidget {
  const _LoginRequiredState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 56,
            ),
            const SizedBox(
              height: 16,
            ),
            const Text(
              'Login Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            const Text(
              'Please login to manage your products.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}