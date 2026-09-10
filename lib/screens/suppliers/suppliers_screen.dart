import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/supplier_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/supplier_provider.dart';
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
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';
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

  void _onSearchChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _searchQuery =
          _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    final BusinessProvider businessProvider =
        context.read<BusinessProvider>();

    final SupplierProvider supplierProvider =
        context.read<SupplierProvider>();

    await businessProvider.loadBusiness();

    if (!mounted) {
      return;
    }

    final String businessId =
        businessProvider.business?.id.trim() ?? '';

    if (businessId.isEmpty) {
      return;
    }

    supplierProvider.setBusinessId(
      businessId,
    );

    await supplierProvider.loadAndWatchSuppliers();

    if (!mounted) {
      return;
    }

  }

  Future<void> _refresh() async {
    final BusinessProvider businessProvider =
        context.read<BusinessProvider>();

    final SupplierProvider supplierProvider =
        context.read<SupplierProvider>();

    await businessProvider.refresh();

    if (!mounted) {
      return;
    }

    final String businessId =
        businessProvider.business?.id.trim() ?? '';

    if (businessId.isEmpty) {
      return;
    }

    supplierProvider.setBusinessId(
      businessId,
    );

    await supplierProvider.loadAndWatchSuppliers();
  }

  Future<void> _openAddSupplier() async {
    final BusinessProvider businessProvider =
        context.read<BusinessProvider>();

    final String businessId =
        businessProvider.business?.id.trim() ?? '';

    if (businessId.isEmpty) {
      _showMessage(
        'Business information is not available.',
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

  Future<void> _openEditSupplier(
    SupplierModel supplier,
  ) async {
    final BusinessProvider businessProvider =
        context.read<BusinessProvider>();

    final String businessId =
        businessProvider.business?.id.trim() ?? '';

    if (businessId.isEmpty) {
      _showMessage(
        'Business information is not available.',
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
            'Are you sure you want to delete '
            '"${supplier.name}"?',
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

    if (!mounted) {
      return;
    }

    if (confirmed != true) {
      return;
    }

    final SupplierProvider supplierProvider =
        context.read<SupplierProvider>();

    try {
      await supplierProvider.deleteSupplier(
        supplierId: supplier.id,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Supplier deleted successfully.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        supplierProvider.errorMessage ??
            'Unable to delete supplier.',
        isError: true,
      );
    }
  }

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
            supplier.address
                .toLowerCase()
                .contains(_searchQuery) ||
            supplier.gstNumber
                .toLowerCase()
                .contains(_searchQuery);
      },
    ).toList();
  }

  void _clearSearch() {
    _searchController.clear();
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
              : AppColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    final BusinessProvider businessProvider =
        context.watch<BusinessProvider>();

    final SupplierProvider supplierProvider =
        context.watch<SupplierProvider>();

    if (businessProvider.isLoading &&
        businessProvider.business == null) {
      return Scaffold(
        backgroundColor:
            theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Suppliers',
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (businessProvider.errorMessage != null &&
        businessProvider.business == null) {
      return _buildBusinessError(
        context,
        theme,
        businessProvider.errorMessage!,
      );
    }

    if (businessProvider.business == null) {
      return _buildBusinessError(
        context,
        theme,
        'Business profile not found. '
            'Please complete business setup.',
      );
    }

    final List<SupplierModel> allSuppliers =
        supplierProvider.suppliers;

    final List<SupplierModel>
        filteredSuppliers =
        _filterSuppliers(
      allSuppliers,
    );

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
            onPressed:
                supplierProvider.isLoading
                    ? null
                    : _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(
        context,
        theme,
        supplierProvider,
        allSuppliers,
        filteredSuppliers,
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

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    SupplierProvider provider,
    List<SupplierModel> allSuppliers,
    List<SupplierModel> filteredSuppliers,
  ) {
    if (provider.isLoading &&
        allSuppliers.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (provider.errorMessage != null &&
        allSuppliers.isEmpty) {
      return _buildErrorState(
        context,
        theme,
        provider.errorMessage!,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          110,
        ),
        children: [
          _buildHeader(
            theme,
            allSuppliers.length,
          ),
          const SizedBox(height: 18),
          _buildSearchField(theme),
          const SizedBox(height: 20),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(
              alpha: 0.12,
            ),
            AppColors.secondary.withValues(
              alpha: 0.08,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color:
                  AppColors.primary.withValues(
                alpha: 0.12,
              ),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Supplier Management',
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your suppliers and supplier details',
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    color: theme
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(
                          alpha: 0.65,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color: theme.dividerColor
                    .withValues(
                  alpha: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                Text(
                  totalSuppliers.toString(),
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                    color:
                        AppColors.primary,
                  ),
                ),
                Text(
                  'Suppliers',
                  style:
                      theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(
    ThemeData theme,
  ) {
    return TextField(
      controller: _searchController,
      textInputAction:
          TextInputAction.search,
      decoration: InputDecoration(
        hintText:
            'Search by name, contact, mobile or GST...',
        prefixIcon: const Icon(
          Icons.search_rounded,
        ),
        suffixIcon:
            _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    onPressed:
                        _clearSearch,
                    icon: const Icon(
                      Icons.clear_rounded,
                    ),
                  ),
        filled: true,
        fillColor: theme.cardColor,
      ),
    );
  }

  Widget _buildSupplierList(
    BuildContext context,
    ThemeData theme,
    List<SupplierModel> suppliers,
  ) {
    return Column(
      children: [
        for (int index = 0;
            index < suppliers.length;
            index++) ...[
          _buildSupplierCard(
            context,
            theme,
            suppliers[index],
          ),
          if (index !=
              suppliers.length - 1)
            const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildSupplierCard(
    BuildContext context,
    ThemeData theme,
    SupplierModel supplier,
  ) {
    final String initials =
        _getInitials(supplier.name);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: () {
          _showSupplierDetails(
            context,
            supplier,
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildSupplierAvatar(
                initials,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name,
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
                    if (supplier
                        .contactPerson
                        .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        supplier.contactPerson,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: theme
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(
                                alpha: 0.65,
                              ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      children: [
                        if (supplier.mobile
                            .isNotEmpty)
                          _InfoChip(
                            icon:
                                Icons.phone_outlined,
                            label:
                                supplier.mobile,
                          ),
                        if (supplier.email
                            .isNotEmpty)
                          _InfoChip(
                            icon:
                                Icons.email_outlined,
                            label:
                                supplier.email,
                          ),
                        if (supplier.gstNumber
                            .isNotEmpty)
                          _InfoChip(
                            icon: Icons
                                .receipt_long_outlined,
                            label:
                                supplier.gstNumber,
                          ),
                      ],
                    ),
                    if (supplier.address
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Icon(
                            Icons
                                .location_on_outlined,
                            size: 17,
                            color: theme
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(
                                  alpha: 0.60,
                                ),
                          ),
                          const SizedBox(
                            width: 6,
                          ),
                          Expanded(
                            child: Text(
                              supplier.address,
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style: theme
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: theme
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withValues(
                                      alpha:
                                          0.65,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildSupplierMenu(
                context,
                supplier,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierAvatar(
    String initials,
  ) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(
              alpha: 0.16,
            ),
            AppColors.secondary.withValues(
              alpha: 0.12,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildSupplierMenu(
    BuildContext context,
    SupplierModel supplier,
  ) {
    return PopupMenuButton<String>(
      tooltip: 'Supplier options',
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _openEditSupplier(
              supplier,
            );
            break;

          case 'delete':
            _deleteSupplier(
              supplier,
            );
            break;
        }
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 20,
                ),
                SizedBox(width: 10),
                Text('Edit'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
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
    );
  }

  Future<void> _showSupplierDetails(
    BuildContext context,
    SupplierModel supplier,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final ThemeData theme =
            Theme.of(sheetContext);

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
                Row(
                  children: [
                    _buildSupplierAvatar(
                      _getInitials(
                        supplier.name,
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            supplier.name,
                            style: theme
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                          if (supplier
                              .contactPerson
                              .isNotEmpty)
                            Text(
                              supplier
                                  .contactPerson,
                              style: theme
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                color: theme
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(
                                      alpha:
                                          0.65,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 22,
                ),
                _DetailRow(
                  icon:
                      Icons.phone_outlined,
                  label: 'Mobile',
                  value:
                      supplier.mobile,
                ),
                _DetailRow(
                  icon:
                      Icons.email_outlined,
                  label: 'Email',
                  value:
                      supplier.email,
                ),
                _DetailRow(
                  icon: Icons
                      .location_on_outlined,
                  label: 'Address',
                  value:
                      supplier.address,
                ),
                _DetailRow(
                  icon: Icons
                      .receipt_long_outlined,
                  label: 'GST Number',
                  value:
                      supplier.gstNumber,
                ),
                if (supplier.notes
                    .isNotEmpty)
                  _DetailRow(
                    icon: Icons
                        .notes_outlined,
                    label: 'Notes',
                    value:
                        supplier.notes,
                  ),
                const SizedBox(
                  height: 18,
                ),
                SizedBox(
                  width:
                      double.infinity,
                  child:
                      FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        sheetContext,
                      );

                      if (!mounted) {
                        return;
                      }

                      _openEditSupplier(
                        supplier,
                      );
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                    ),
                    label: const Text(
                      'Edit Supplier',
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

  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
  ) {
    return _StateCard(
      icon:
          Icons.local_shipping_outlined,
      title: 'No suppliers yet',
      description:
          'Add your first supplier to start managing supplier information.',
      actionLabel: 'Add Supplier',
      onAction: _openAddSupplier,
    );
  }

  Widget _buildNoSearchResults(
    BuildContext context,
    ThemeData theme,
  ) {
    return _StateCard(
      icon:
          Icons.search_off_rounded,
      title: 'No suppliers found',
      description:
          'Try another supplier name, contact, mobile number or GST number.',
      actionLabel: 'Clear Search',
      onAction: _clearSearch,
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ThemeData theme,
    String error,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: _StateCard(
          icon:
              Icons.error_outline_rounded,
          title:
              'Unable to load suppliers',
          description: error,
          actionLabel: 'Retry',
          onAction: () async {
            _initialized = false;
            await _initialize();
          },
        ),
      ),
    );
  }

  Widget _buildBusinessError(
    BuildContext context,
    ThemeData theme,
    String message,
  ) {
    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Suppliers',
        ),
        actions: [
          IconButton(
            tooltip: 'Retry',
            onPressed: () async {
              _initialized = false;
              await _initialize();
            },
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: _StateCard(
            icon:
                Icons.business_outlined,
            title:
                'Business information unavailable',
            description: message,
            actionLabel: 'Retry',
            onAction: () async {
              _initialized = false;
              await _initialize();
            },
          ),
        ),
      ),
    );
  }

  String _getInitials(
    String name,
  ) {
    final String value =
        name.trim();

    if (value.isEmpty) {
      return 'S';
    }

    final List<String> parts =
        value.split(
      RegExp(r'\s+'),
    );

    if (parts.length == 1) {
      return parts.first
          .substring(
        0,
        parts.first.length >= 2
            ? 2
            : 1,
      )
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'
        .toUpperCase();
  }
}

class _InfoChip
    extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.dividerColor
            .withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme
                .textTheme
                .bodySmall
                ?.color
                ?.withValues(
                  alpha: 0.65,
                ),
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 170,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
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

    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 15,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color: AppColors.primary
                  .withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: Icon(
              icon,
              size: 19,
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
                  label,
                  style: theme
                      .textTheme
                      .labelMedium
                      ?.copyWith(
                    color: theme
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(
                          alpha: 0.60,
                        ),
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
                        FontWeight.w600,
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

class _StateCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(28),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration:
                  BoxDecoration(
                color: AppColors.primary
                    .withValues(
                  alpha: 0.10,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color:
                    AppColors.primary,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            Text(
              title,
              textAlign:
                  TextAlign.center,
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              description,
              textAlign:
                  TextAlign.center,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: theme
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(
                      alpha: 0.65,
                    ),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(
                Icons.arrow_forward_rounded,
              ),
              label: Text(
                actionLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}