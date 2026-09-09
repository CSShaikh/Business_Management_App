import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/supplier_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/supplier_repository.dart';
import 'add_supplier_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({
    super.key,
  });

  @override
  State<SuppliersScreen> createState() =>
      _SuppliersScreenState();
}

class _SuppliersScreenState
    extends State<SuppliersScreen> {
  final SupplierRepository _supplierRepository =
      SupplierRepository();

  final BusinessRepository _businessRepository =
      BusinessRepository();

  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  BusinessModel? _business;
  bool _loadingBusiness = true;
  String? _businessError;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _onSearchChanged,
    );

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
        _businessError =
            'User session not found.';
      });

      return;
    }

    setState(() {
      _loadingBusiness = true;
      _businessError = null;
    });

    try {
      final BusinessModel? business =
          await _businessRepository
              .getBusinessForOwner(
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

  // ---------------------------------------------------------------------------
  // Add Supplier
  // ---------------------------------------------------------------------------

  Future<void> _openAddSupplier() async {
    final String? businessId =
        _businessId;

    if (businessId == null ||
        businessId.trim().isEmpty) {
      _showMessage(
        'Business information not available.',
        isError: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSupplierScreen(
          businessId: businessId,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Edit Supplier
  // ---------------------------------------------------------------------------

  Future<void> _openEditSupplier(
    SupplierModel supplier,
  ) async {
    final String? businessId =
        _businessId;

    if (businessId == null ||
        businessId.trim().isEmpty) {
      _showMessage(
        'Business information not available.',
        isError: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSupplierScreen(
          businessId: businessId,
          supplier: supplier,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete Supplier
  // ---------------------------------------------------------------------------

  Future<void> _deleteSupplier(
    SupplierModel supplier,
  ) async {
    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Supplier?',
          ),
          content: Text(
            'Are you sure you want to delete "${supplier.name}"?',
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

    final String? businessId =
        _businessId;

    if (businessId == null ||
        businessId.trim().isEmpty) {
      _showMessage(
        'Business information not available.',
        isError: true,
      );
      return;
    }

    try {
      await _supplierRepository
          .deleteSupplier(
        businessId: businessId,
        supplierId: supplier.id,
      );

      if (!mounted) return;

      _showMessage(
        'Supplier deleted successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to delete supplier.',
        isError: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  List<SupplierModel> _filterSuppliers(
    List<SupplierModel> suppliers,
  ) {
    if (_searchQuery.isEmpty) {
      return suppliers;
    }

    return suppliers.where(
      (supplier) {
        return supplier.name
                .toLowerCase()
                .contains(_searchQuery) ||
            supplier.contactPerson
                .toLowerCase()
                .contains(_searchQuery) ||
            supplier.mobile
                .toLowerCase()
                .contains(_searchQuery) ||
            supplier.email
                .toLowerCase()
                .contains(_searchQuery) ||
            supplier.gstNumber
                .toLowerCase()
                .contains(_searchQuery);
      },
    ).toList();
  }

  // ---------------------------------------------------------------------------
  // Snackbar
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
            'Suppliers',
          ),
        ),
        body: const Center(
          child:
              CircularProgressIndicator(),
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
          'Suppliers',
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
      body: StreamBuilder<
          List<SupplierModel>>(
        stream:
            _supplierRepository.watchSuppliers(
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

          final List<SupplierModel>
              allSuppliers =
              snapshot.data ?? [];

          final List<SupplierModel>
              filteredSuppliers =
              _filterSuppliers(
            allSuppliers,
          );

          return _buildContent(
            context,
            theme,
            allSuppliers,
            filteredSuppliers,
          );
        },
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _openAddSupplier,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Add Supplier',
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Content
  // ---------------------------------------------------------------------------

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    List<SupplierModel> allSuppliers,
    List<SupplierModel> filteredSuppliers,
  ) {
    return RefreshIndicator(
      onRefresh: _loadBusiness,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
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
            allSuppliers.length,
          ),
          const SizedBox(
            height: 18,
          ),
          _buildSearchField(theme),
          const SizedBox(
            height: 20,
          ),
          if (allSuppliers.isEmpty)
            _buildEmptyState(
              context,
              theme,
            )
          else if (filteredSuppliers.isEmpty)
            _buildNoSearchResults(
              context,
              theme,
            )
          else
            _buildSupplierList(
              context,
              theme,
              filteredSuppliers,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    int totalSuppliers,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Supplier Management',
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
          'Manage your suppliers and their contact details.',
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
        Card(
          child: Padding(
            padding:
                const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.primary
                            .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color:
                        AppColors.primary,
                  ),
                ),
                const SizedBox(
                  width: 13,
                ),
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      totalSuppliers
                          .toString(),
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total Suppliers',
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
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Search Field
  // ---------------------------------------------------------------------------

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
            'Search suppliers...',
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
        fillColor:
            theme.colorScheme.surface,
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

  // ---------------------------------------------------------------------------
  // Supplier List
  // ---------------------------------------------------------------------------

  Widget _buildSupplierList(
    BuildContext context,
    ThemeData theme,
    List<SupplierModel> suppliers,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          '${suppliers.length} supplier${suppliers.length == 1 ? '' : 's'}',
          style: theme
              .textTheme
              .titleMedium
              ?.copyWith(
            fontWeight:
                FontWeight.w700,
          ),
        ),
        const SizedBox(
          height: 12,
        ),
        ...suppliers.map(
          (supplier) =>
              _buildSupplierCard(
            context,
            theme,
            supplier,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Supplier Card
  // ---------------------------------------------------------------------------

  Widget _buildSupplierCard(
    BuildContext context,
    ThemeData theme,
    SupplierModel supplier,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: () {
          _openEditSupplier(
            supplier,
          );
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
                  _buildSupplierIcon(
                    supplier,
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
                        Text(
                          supplier.name,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        if (supplier
                            .contactPerson
                            .isNotEmpty) ...[
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            supplier
                                .contactPerson,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
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
                        _openEditSupplier(
                          supplier,
                        );
                      } else if (value ==
                          'delete') {
                        _deleteSupplier(
                          supplier,
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
                height: 15,
              ),
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(13),
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
                    13,
                  ),
                ),
                child: Column(
                  children: [
                    _buildContactRow(
                      theme,
                      Icons.phone_outlined,
                      'Mobile',
                      supplier.mobile,
                    ),
                    if (supplier.email
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 10,
                      ),
                      _buildContactRow(
                        theme,
                        Icons.email_outlined,
                        'Email',
                        supplier.email,
                      ),
                    ],
                    if (supplier.gstNumber
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 10,
                      ),
                      _buildContactRow(
                        theme,
                        Icons.receipt_long_outlined,
                        'GST',
                        supplier.gstNumber,
                      ),
                    ],
                    if (supplier.address
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 10,
                      ),
                      _buildContactRow(
                        theme,
                        Icons.location_on_outlined,
                        'Address',
                        supplier.address,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierIcon(
    SupplierModel supplier,
  ) {
    return Container(
      width: 50,
      height: 50,
      decoration:
          BoxDecoration(
        color: AppColors.primary
            .withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.local_shipping_outlined,
        color: AppColors.primary,
        size: 25,
      ),
    );
  }

  Widget _buildContactRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.info,
        ),
        const SizedBox(
          width: 9,
        ),
        SizedBox(
          width: 65,
          child: Text(
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
        ),
        const SizedBox(
          width: 8,
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 3,
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
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State
  // ---------------------------------------------------------------------------

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
                Icons.local_shipping_outlined,
                size: 42,
                color:
                    AppColors.primary,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Text(
              'No Suppliers Yet',
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
              'Add your first supplier to start managing supplier information.',
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
                  _openAddSupplier,
              icon: const Icon(
                Icons.add_rounded,
              ),
              label: const Text(
                'Add Supplier',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // No Search Results
  // ---------------------------------------------------------------------------

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
              'No Suppliers Found',
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
              'Try searching with another supplier name, contact, mobile number or GST number.',
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

  // ---------------------------------------------------------------------------
  // Business Error
  // ---------------------------------------------------------------------------

  Widget _buildBusinessError(
    BuildContext context,
    ThemeData theme,
  ) {
    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Suppliers',
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
                    'Please complete your business setup before managing suppliers.',
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

  // ---------------------------------------------------------------------------
  // Error State
  // ---------------------------------------------------------------------------

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
              'Unable to load suppliers',
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
}
