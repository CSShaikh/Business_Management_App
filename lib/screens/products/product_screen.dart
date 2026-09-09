import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/product_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/product_repository.dart';
import 'add_product_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final BusinessRepository _businessRepository = BusinessRepository();

  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  BusinessModel? _business;
  bool _loadingBusiness = true;
  String? _businessError;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    _loadBusiness();
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
      _searchQuery =
          _searchController.text.trim().toLowerCase();
    });
  }

  String? get _businessId => _business?.id;

  Future<void> _loadBusiness() async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loadingBusiness = false;
        _businessError = 'User session not found.';
      });

      return;
    }

    setState(() {
      _loadingBusiness = true;
      _businessError = null;
    });

    try {
      final BusinessModel? business =
          await _businessRepository.getBusinessForOwner(
        user.uid,
      );

      if (!mounted) return;

      if (business == null) {
        setState(() {
          _loadingBusiness = false;
          _businessError =
              'Business profile not found. Please complete business setup.';
        });

        return;
      }

      setState(() {
        _business = business;
        _loadingBusiness = false;
        _businessError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingBusiness = false;
        _businessError =
            'Unable to load business information.';
      });
    }
  }

  Future<void> _openAddProduct() async {
    final String? businessId = _businessId;

    if (businessId == null) {
      _showMessage(
        'Business information not available.',
        isError: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          businessId: businessId,
        ),
      ),
    );
  }

  Future<void> _openEditProduct(
    ProductModel product,
  ) async {
    final String? businessId = _businessId;

    if (businessId == null) {
      _showMessage(
        'Business information not available.',
        isError: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          businessId: businessId,
          product: product,
        ),
      ),
    );
  }

  Future<void> _deleteProduct(
    ProductModel product,
  ) async {
    final bool? confirmed =
        await showDialog<bool>(
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
                Navigator.pop(
                  context,
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
              ),
              onPressed: () {
                Navigator.pop(
                  context,
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

    final String? businessId =
        _businessId;

    if (businessId == null) {
      _showMessage(
        'Business information not available.',
        isError: true,
      );
      return;
    }

    try {
      await _productRepository.deleteProduct(
        businessId,
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

  Future<void> _toggleProductStatus(
    ProductModel product,
  ) async {
    final String? businessId =
        _businessId;

    if (businessId == null) {
      _showMessage(
        'Business information not available.',
        isError: true,
      );
      return;
    }

    try {
      await _productRepository.setProductStatus(
        businessId,
        product.id,
        !product.isActive,
      );

      if (!mounted) return;

      _showMessage(
        product.isActive
            ? 'Product deactivated.'
            : 'Product activated.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to update product status.',
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
          behavior:
              SnackBarBehavior.floating,
          backgroundColor: isError
              ? AppColors.danger
              : AppColors.success,
        ),
      );
  }

  List<ProductModel> _filterProducts(
    List<ProductModel> products,
  ) {
    if (_searchQuery.isEmpty) {
      return products;
    }

    return products.where(
      (product) {
        return product.name
                .toLowerCase()
                .contains(_searchQuery) ||
            product.category
                .toLowerCase()
                .contains(_searchQuery) ||
            product.unit
                .toLowerCase()
                .contains(_searchQuery);
      },
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    if (_loadingBusiness) {
      return Scaffold(
        backgroundColor:
            theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Products',
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_businessError != null ||
        _business == null) {
      return _buildBusinessError(
        context,
        theme,
      );
    }

    final String businessId =
        _business!.id;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Products',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadBusiness,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<ProductModel>>(
        stream:
            _productRepository.watchProducts(
          businessId,
        ),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(
              context,
              theme,
            );
          }

          final List<ProductModel>
              allProducts =
              snapshot.data ?? [];

          final List<ProductModel>
              filteredProducts =
              _filterProducts(
            allProducts,
          );

          return _buildContent(
            context,
            theme,
            allProducts,
            filteredProducts,
          );
        },
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _openAddProduct,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Add Product',
        ),
      ),
    );
  }

  Widget _buildBusinessError(
    BuildContext context,
    ThemeData theme,
  ) {
    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Products',
        ),
      ),
      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.business_outlined,
                size: 60,
                color:
                    AppColors.danger,
              ),
              const SizedBox(
                height: 18,
              ),
              Text(
                'Business profile unavailable',
                textAlign:
                    TextAlign.center,
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
                _businessError ??
                    'Please complete your business setup before managing products.',
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
                    _loadBusiness,
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
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    List<ProductModel> allProducts,
    List<ProductModel> filteredProducts,
  ) {
    final int activeCount =
        allProducts.where(
      (product) => product.isActive,
    ).length;

    final int lowStockCount =
        allProducts.where(
      (product) =>
          product.currentStock <=
          product.minimumStock,
    ).length;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadBusiness();
      },
      child: ListView(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          100,
        ),
        children: [
          _buildHeader(
            theme,
            allProducts.length,
            activeCount,
            lowStockCount,
          ),
          const SizedBox(height: 18),
          _buildSearchField(theme),
          const SizedBox(height: 20),
          if (allProducts.isEmpty)
            _buildEmptyState(
              context,
              theme,
            )
          else if (filteredProducts.isEmpty)
            _buildNoSearchResults(
              context,
              theme,
            )
          else
            _buildProductList(
              context,
              theme,
              filteredProducts,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    int totalProducts,
    int activeProducts,
    int lowStockProducts,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Product Management',
          style: theme
              .textTheme
              .headlineSmall
              ?.copyWith(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Manage your products, prices and stock.',
          style: theme
              .textTheme
              .bodyMedium
              ?.copyWith(
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool compact =
                constraints.maxWidth < 600;

            if (compact) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child:
                            _buildSummaryCard(
                          theme,
                          'Products',
                          totalProducts
                              .toString(),
                          Icons
                              .inventory_2_outlined,
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child:
                            _buildSummaryCard(
                          theme,
                          'Active',
                          activeProducts
                              .toString(),
                          Icons
                              .check_circle_outline_rounded,
                          AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  _buildSummaryCard(
                    theme,
                    'Low Stock',
                    lowStockProducts
                        .toString(),
                    Icons
                        .warning_amber_rounded,
                    AppColors.warning,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child:
                      _buildSummaryCard(
                    theme,
                    'Products',
                    totalProducts
                        .toString(),
                    Icons
                        .inventory_2_outlined,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child:
                      _buildSummaryCard(
                    theme,
                    'Active',
                    activeProducts
                        .toString(),
                    Icons
                        .check_circle_outline_rounded,
                    AppColors.success,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child:
                      _buildSummaryCard(
                    theme,
                    'Low Stock',
                    lowStockProducts
                        .toString(),
                    Icons
                        .warning_amber_rounded,
                    AppColors.warning,
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
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
                color:
                    color.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  13,
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
                    value,
                    style: theme
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(
    ThemeData theme,
  ) {
    return TextField(
      controller:
          _searchController,
      textInputAction:
          TextInputAction.search,
      decoration:
          InputDecoration(
        hintText:
            'Search products...',
        prefixIcon: const Icon(
          Icons.search_rounded,
        ),
        suffixIcon:
            _searchQuery.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear',
                    onPressed: () {
                      _searchController
                          .clear();
                    },
                    icon: const Icon(
                      Icons.clear_rounded,
                    ),
                  )
                : null,
        filled: true,
        fillColor: theme
            .colorScheme
            .surface,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme
                .colorScheme
                .outline
                .withValues(
              alpha: 0.15,
            ),
          ),
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme
                .colorScheme
                .outline
                .withValues(
              alpha: 0.15,
            ),
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              const BorderSide(
            color:
                AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildProductList(
    BuildContext context,
    ThemeData theme,
    List<ProductModel> products,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          '${products.length} product${products.length == 1 ? '' : 's'}',
          style: theme
              .textTheme
              .titleMedium
              ?.copyWith(
            fontWeight:
                FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...products.map(
          (product) =>
              _buildProductCard(
            context,
            theme,
            product,
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    ThemeData theme,
    ProductModel product,
  ) {
    final bool isLowStock =
        product.currentStock <=
            product.minimumStock &&
        product.isActive;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: () {
          _openEditProduct(product);
        },
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildProductIcon(
                    product,
                  ),
                  const SizedBox(
                    width: 13,
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
                                product.name,
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
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            _buildStatusChip(
                              product,
                            ),
                          ],
                        ),
                        if (product
                            .category
                            .isNotEmpty) ...[
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            product.category,
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
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected:
                        (value) {
                      if (value ==
                          'edit') {
                        _openEditProduct(
                          product,
                        );
                      } else if (value ==
                          'toggle') {
                        _toggleProductStatus(
                          product,
                        );
                      } else if (value ==
                          'delete') {
                        _deleteProduct(
                          product,
                        );
                      }
                    },
                    itemBuilder:
                        (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          leading: Icon(
                            Icons
                                .edit_outlined,
                          ),
                          title:
                              Text('Edit'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: ListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          leading: Icon(
                            product
                                    .isActive
                                ? Icons
                                    .visibility_off_outlined
                                : Icons
                                    .visibility_outlined,
                          ),
                          title: Text(
                            product.isActive
                                ? 'Deactivate'
                                : 'Activate',
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          leading: Icon(
                            Icons
                                .delete_outline_rounded,
                            color:
                                AppColors.danger,
                          ),
                          title: Text(
                            'Delete',
                            style:
                                TextStyle(
                              color:
                                  AppColors
                                      .danger,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(
                height: 16,
              ),
              Container(
                padding:
                    const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: theme
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(
                    alpha: 0.35,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (
                    context,
                    constraints,
                  ) {
                    final bool compact =
                        constraints.maxWidth <
                            500;

                    final Widget stock =
                        _ProductInfo(
                      label: 'Stock',
                      value:
                          '${_formatNumber(product.currentStock)} ${product.unit}',
                      icon: Icons
                          .inventory_outlined,
                      color: isLowStock
                          ? AppColors
                              .warning
                          : AppColors.info,
                    );

                    final Widget purchase =
                        _ProductInfo(
                      label: 'Purchase',
                      value:
                          '₹${_formatMoney(product.purchasePrice)}',
                      icon: Icons
                          .shopping_cart_outlined,
                      color:
                          AppColors.info,
                    );

                    final Widget selling =
                        _ProductInfo(
                      label: 'Selling',
                      value:
                          '₹${_formatMoney(product.sellingPrice)}',
                      icon: Icons
                          .sell_outlined,
                      color:
                          AppColors.success,
                    );

                    final Widget minimum =
                        _ProductInfo(
                      label: 'Min. Stock',
                      value:
                          '${_formatNumber(product.minimumStock)} ${product.unit}',
                      icon: Icons
                          .warning_amber_outlined,
                      color:
                          AppColors.warning,
                    );

                    if (compact) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child:
                                    stock,
                              ),
                              Expanded(
                                child:
                                    purchase,
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
                                    selling,
                              ),
                              Expanded(
                                child:
                                    minimum,
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: stock,
                        ),
                        Expanded(
                          child: purchase,
                        ),
                        Expanded(
                          child: selling,
                        ),
                        Expanded(
                          child: minimum,
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (isLowStock) ...[
                const SizedBox(
                  height: 10,
                ),
                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration:
                      BoxDecoration(
                    color: AppColors.warning
                        .withValues(
                      alpha: 0.08,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .warning_amber_rounded,
                        color:
                            AppColors.warning,
                        size: 18,
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: Text(
                          'Low stock — minimum level is ${_formatNumber(product.minimumStock)} ${product.unit}.',
                          style:
                              const TextStyle(
                            color: AppColors
                                .warning,
                            fontWeight:
                                FontWeight
                                    .w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductIcon(
    ProductModel product,
  ) {
    final Color color =
        product.isActive
            ? AppColors.primary
            : AppColors.darkTextSecondary;

    return Container(
      width: 50,
      height: 50,
      decoration:
          BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        color: color,
        size: 25,
      ),
    );
  }

  Widget _buildStatusChip(
    ProductModel product,
  ) {
    final bool active =
        product.isActive;

    final Color color = active
        ? AppColors.success
        : AppColors.danger;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.09,
        ),
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
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
            Container(
              width: 82,
              height: 82,
              decoration:
                  BoxDecoration(
                color: AppColors.primary
                    .withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),
              child: const Icon(
                Icons
                    .inventory_2_outlined,
                size: 42,
                color:
                    AppColors.primary,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Text(
              'No Products Yet',
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
              'Add your first product to start managing inventory.',
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
              height: 22,
            ),
            FilledButton.icon(
              onPressed:
                  _openAddProduct,
              icon: const Icon(
                Icons.add_rounded,
              ),
              label: const Text(
                'Add Product',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults(
    BuildContext context,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 45,
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(
              height: 14,
            ),
            Text(
              'No Products Found',
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
              'Try searching with another product name or category.',
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

  Widget _buildErrorState(
    BuildContext context,
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color:
                  AppColors.danger,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Unable to load products',
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
            Text(
              'Please check your internet connection and Firebase configuration.',
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
              onPressed: () {
                setState(() {});
              },
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

  String _formatNumber(
    double value,
  ) {
    if (value ==
        value.roundToDouble()) {
      return value
          .toInt()
          .toString();
    }

    return value
        .toStringAsFixed(2)
        .replaceFirst(
          RegExp(r'\.?0+$'),
          '',
        );
  }

  String _formatMoney(
    double value,
  ) {
    if (value ==
        value.roundToDouble()) {
      return value
          .toInt()
          .toString();
    }

    return value.toStringAsFixed(2);
  }
}

class _ProductInfo
    extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ProductInfo({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: color,
        ),
        const SizedBox(
          width: 8,
        ),
        Expanded(
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
                    .labelSmall
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
              const SizedBox(
                height: 2,
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
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}