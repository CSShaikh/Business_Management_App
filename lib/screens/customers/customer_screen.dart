import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/customer_statement_pdf_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../models/ledger_transaction_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/ledger_provider.dart';
import 'add_customer_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({
    super.key,
  });

  @override
  State<CustomersScreen> createState() =>
      _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final BusinessProvider _businessProvider;
  late final CustomerProvider _customerProvider;

  BusinessModel? _business;

  bool _loadingBusiness = true;
  String? _businessError;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _businessProvider = context.read<BusinessProvider>();
    _customerProvider = context.read<CustomerProvider>();

    _loadBusiness();
  }

  // ============================================================
  // BUSINESS + CUSTOMER INITIALIZATION
  // ============================================================

  Future<void> _loadBusiness() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loadingBusiness = true;
      _businessError = null;
    });

    try {
      final BusinessModel? business =
          await _businessProvider.loadBusiness();

      if (!mounted) {
        return;
      }

      if (business == null) {
        setState(() {
          _business = null;
          _loadingBusiness = false;
          _businessError =
              _businessProvider.errorMessage ??
                  'Business profile not found. Please complete business setup.';
        });
        return;
      }

      final String businessId = business.id.trim();

      if (businessId.isEmpty) {
        setState(() {
          _business = business;
          _loadingBusiness = false;
          _businessError = 'Business ID is missing.';
        });
        return;
      }

      _business = business;

      _customerProvider.setBusinessId(
        businessId,
      );

      await _customerProvider.loadAndWatchCustomers(
        businessId,
      );

      if (!mounted) {
        return;
      }

      final String? customerError =
          _customerProvider.errorMessage;

      if (customerError != null &&
          _customerProvider.customers.isEmpty) {
        setState(() {
          _loadingBusiness = false;
          _businessError = customerError;
        });
        return;
      }

      setState(() {
        _loadingBusiness = false;
        _businessError = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingBusiness = false;
        _businessError =
            'Unable to load business information.';
      });
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    final BusinessModel? business = _business;

    if (business == null ||
        business.id.trim().isEmpty) {
      await _loadBusiness();
      return;
    }

    try {
      await _customerProvider.refresh();
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _customerProvider.errorMessage ??
            'Unable to refresh customers.',
        isError: true,
      );
    }
  }

  // ============================================================
  // ADD CUSTOMER
  // ============================================================

  Future<void> _openAddCustomer() async {
    final BusinessModel? business = _business;

    if (business == null ||
        business.id.trim().isEmpty) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(
          businessId: business.id,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  // ============================================================
  // EDIT CUSTOMER
  // ============================================================

  Future<void> _openEditCustomer(
    CustomerModel customer,
  ) async {
    final BusinessModel? business = _business;

    if (business == null ||
        business.id.trim().isEmpty) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(
          businessId: business.id,
          customer: customer,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  // ============================================================
  // DELETE CUSTOMER
  // ============================================================

  Future<void> _deleteCustomer(
    CustomerModel customer,
  ) async {
    final BusinessModel? business = _business;

    if (business == null ||
        business.id.trim().isEmpty) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );
      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Customer?',
          ),
          content: Text(
            'Are you sure you want to delete "${customer.name}"?',
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

    try {
      final bool deleted =
          await _customerProvider.deleteCustomer(
        customer.id,
        business.id,
      );

      if (!mounted) {
        return;
      }

      if (!deleted) {
        _showMessage(
          _customerProvider.errorMessage ??
              'Unable to delete customer.',
          isError: true,
        );
        return;
      }

      _showMessage(
        'Customer deleted successfully.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to delete customer.',
        isError: true,
      );
    }
  }

  // ============================================================
  // CUSTOMER STATEMENT
  // ============================================================

  Future<void> _openCustomerStatement(
    CustomerModel customer,
  ) async {
    final BusinessModel? business = _business;

    if (business == null ||
        business.id.trim().isEmpty) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );
      return;
    }

    final String businessId = business.id.trim();
    final String customerId = customer.id.trim();

    if (customerId.isEmpty) {
      _showMessage(
        'Customer ID is missing.',
        isError: true,
      );
      return;
    }

    final LedgerProvider ledgerProvider =
        context.read<LedgerProvider>();

    if (!mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading customer statement...',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      ledgerProvider.setContext(
        businessId: businessId,
        customerId: customerId,
      );

      await ledgerProvider.loadAndWatchCustomerTransactions(
        businessId: businessId,
        customerId: customerId,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      final String? ledgerError =
          ledgerProvider.errorMessage;

      if (ledgerError != null &&
          ledgerProvider.transactions.isEmpty) {
        _showMessage(
          ledgerError,
          isError: true,
        );
        return;
      }

      final List<LedgerTransactionModel> transactions =
          List<LedgerTransactionModel>.from(
        ledgerProvider.transactions,
      )..sort(
              (a, b) => a.date.compareTo(b.date),
            );

      await _showStatementDialog(
        business: business,
        customer: customer,
        transactions: transactions,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      _showMessage(
        'Unable to load customer statement.',
        isError: true,
      );
    }
  }

  // ============================================================
  // STATEMENT DIALOG
  // ============================================================

  Future<void> _showStatementDialog({
    required BusinessModel business,
    required CustomerModel customer,
    required List<LedgerTransactionModel> transactions,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _CustomerStatementDialog(
          business: business,
          customer: customer,
          transactions: transactions,
          onPrint: () async {
            Navigator.of(dialogContext).pop();

            await _printCustomerStatement(
              business: business,
              customer: customer,
              transactions: transactions,
            );
          },
          onShare: () async {
            Navigator.of(dialogContext).pop();

            await _shareCustomerStatement(
              business: business,
              customer: customer,
              transactions: transactions,
            );
          },
        );
      },
    );
  }

  // ============================================================
  // PRINT CUSTOMER STATEMENT
  // ============================================================

  Future<void> _printCustomerStatement({
    required BusinessModel business,
    required CustomerModel customer,
    required List<LedgerTransactionModel> transactions,
  }) async {
    try {
      await CustomerStatementPdfService.printStatement(
        business: business,
        customer: customer,
        transactions: transactions,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Customer statement sent to print.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to print customer statement.',
        isError: true,
      );
    }
  }

  // ============================================================
  // SHARE CUSTOMER STATEMENT
  // ============================================================

  Future<void> _shareCustomerStatement({
    required BusinessModel business,
    required CustomerModel customer,
    required List<LedgerTransactionModel> transactions,
  }) async {
    try {
      await CustomerStatementPdfService.shareStatement(
        business: business,
        customer: customer,
        transactions: transactions,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Customer statement is ready to share.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to share customer statement.',
        isError: true,
      );
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _setSearchQuery(
    String value,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _searchQuery = value;
    });
  }

  List<CustomerModel> _filteredCustomers(
    List<CustomerModel> customers,
  ) {
    final String query =
        _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return customers;
    }

    return customers.where(
      (customer) {
        return customer.name
                .toLowerCase()
                .contains(query) ||
            customer.ownerName
                .toLowerCase()
                .contains(query) ||
            customer.mobile
                .toLowerCase()
                .contains(query) ||
            customer.email
                .toLowerCase()
                .contains(query) ||
            customer.address
                .toLowerCase()
                .contains(query) ||
            customer.gstNumber
                .toLowerCase()
                .contains(query);
      },
    ).toList();
  }

  // ============================================================
  // MESSAGE
  // ============================================================

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
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? AppColors.danger
              : AppColors.success,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    if (_loadingBusiness) {
      return Scaffold(
        backgroundColor:
            theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Customers & Hotels',
          ),
        ),
        body: const Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_businessError != null &&
        _business == null) {
      return Scaffold(
        backgroundColor:
            theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Customers & Hotels',
          ),
        ),
        body: _buildBusinessError(
          theme,
        ),
      );
    }

    if (_business == null) {
      return Scaffold(
        backgroundColor:
            theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Customers & Hotels',
          ),
        ),
        body: _buildNoBusinessState(
          theme,
        ),
      );
    }

    return Consumer<CustomerProvider>(
      builder: (
        context,
        customerProvider,
        child,
      ) {
        if (customerProvider.isLoading &&
            customerProvider.customers.isEmpty) {
          return Scaffold(
            backgroundColor:
                theme.scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text(
                'Customers & Hotels',
              ),
            ),
            body: const Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        if (customerProvider.errorMessage !=
                null &&
            customerProvider.customers.isEmpty) {
          return Scaffold(
            backgroundColor:
                theme.scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text(
                'Customers & Hotels',
              ),
            ),
            body: _buildCustomerError(
              theme,
              customerProvider.errorMessage!,
            ),
          );
        }

        final List<CustomerModel>
            customers =
            customerProvider.customers;

        final List<CustomerModel>
            filteredCustomers =
            _filteredCustomers(
          customers,
        );

        return Scaffold(
          backgroundColor:
              theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text(
              'Customers & Hotels',
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
              ),
              const SizedBox(
                width: 4,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(
                    theme,
                    customers.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildSummaryCards(
                    theme,
                    customers,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildSearchBar(
                    theme,
                  ),
                ),
                if (filteredCustomers.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(
                      theme,
                      isSearchResult:
                          _searchQuery
                              .trim()
                              .isNotEmpty,
                    ),
                  )
                else
                  SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      100,
                    ),
                    sliver:
                        SliverList(
                      delegate:
                          SliverChildBuilderDelegate(
                        (
                          context,
                          index,
                        ) {
                          final CustomerModel
                              customer =
                              filteredCustomers[
                                  index];

                          return Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              bottom: 12,
                            ),
                            child:
                                _CustomerCard(
                              customer:
                                  customer,
                              onEdit: () {
                                _openEditCustomer(
                                  customer,
                                );
                              },
                              onDelete: () {
                                _deleteCustomer(
                                  customer,
                                );
                              },
                              onStatement: () {
                                _openCustomerStatement(
                                  customer,
                                );
                              },
                            ),
                          );
                        },
                        childCount:
                            filteredCustomers
                                .length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton:
              FloatingActionButton.extended(
            onPressed:
                _openAddCustomer,
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text(
              'Add Customer',
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
    ThemeData theme,
    int totalCustomers,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        12,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Customers & Hotels',
                  style: theme
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  '$totalCustomers customer${totalCustomers == 1 ? '' : 's'} registered',
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
            onPressed:
                _openAddCustomer,
            icon: const Icon(
              Icons.add_rounded,
            ),
            label:
                const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY CARDS
  // ============================================================

  Widget _buildSummaryCards(
    ThemeData theme,
    List<CustomerModel> customers,
  ) {
    final int withMobile =
        customers.where(
      (customer) =>
          customer.mobile.trim().isNotEmpty,
    ).length;

    final int withGst =
        customers.where(
      (customer) =>
          customer.gstNumber.trim().isNotEmpty,
    ).length;

    return SizedBox(
      height: 112,
      child: ListView(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        scrollDirection:
            Axis.horizontal,
        children: [
          _SummaryCard(
            title: 'Total',
            value:
                customers.length.toString(),
            icon:
                Icons.people_alt_rounded,
            color:
                AppColors.primary,
          ),
          const SizedBox(
            width: 12,
          ),
          _SummaryCard(
            title: 'With Mobile',
            value:
                withMobile.toString(),
            icon:
                Icons.phone_rounded,
            color:
                AppColors.success,
          ),
          const SizedBox(
            width: 12,
          ),
          _SummaryCard(
            title: 'With GST',
            value:
                withGst.toString(),
            icon:
                Icons.receipt_long_rounded,
            color:
                AppColors.secondary,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar(
    ThemeData theme,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        8,
      ),
      child: TextField(
        onChanged:
            _setSearchQuery,
        decoration:
            InputDecoration(
          hintText:
              'Search hotel, owner, mobile, email, address or GST...',
          prefixIcon:
              const Icon(
            Icons.search_rounded,
          ),
          suffixIcon:
              _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip:
                          'Clear search',
                      onPressed: () {
                        _setSearchQuery(
                          '',
                        );
                      },
                      icon:
                          const Icon(
                        Icons.clear_rounded,
                      ),
                    ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(
    ThemeData theme, {
    required bool isSearchResult,
  }) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration:
                  BoxDecoration(
                color:
                    AppColors.primary
                        .withValues(
                  alpha: 0.10,
                ),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons.business_rounded,
                size: 38,
                color:
                    AppColors.primary,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Text(
              isSearchResult
                  ? 'No customers found'
                  : 'No customers yet',
              textAlign:
                  TextAlign.center,
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              isSearchResult
                  ? 'Try a different search term.'
                  : 'Add your first hotel or customer to start managing sales and payments.',
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
            if (!isSearchResult) ...[
              const SizedBox(
                height: 20,
              ),
              FilledButton.icon(
                onPressed:
                    _openAddCustomer,
                icon:
                    const Icon(
                  Icons.add_rounded,
                ),
                label:
                    const Text(
                  'Add Customer',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUSINESS ERROR
  // ============================================================

  Widget _buildBusinessError(
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
              Icons.business_outlined,
              size: 56,
              color:
                  AppColors.danger,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Unable to load business',
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              _businessError ??
                  'Unknown error',
              textAlign:
                  TextAlign.center,
              style: theme
                  .textTheme
                  .bodyMedium,
            ),
            const SizedBox(
              height: 20,
            ),
            FilledButton.icon(
              onPressed:
                  _loadBusiness,
              icon:
                  const Icon(
                Icons.refresh_rounded,
              ),
              label:
                  const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CUSTOMER ERROR
  // ============================================================

  Widget _buildCustomerError(
    ThemeData theme,
    String error,
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
              size: 56,
              color:
                  AppColors.danger,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Unable to load customers',
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              error,
              textAlign:
                  TextAlign.center,
              style: theme
                  .textTheme
                  .bodyMedium,
            ),
            const SizedBox(
              height: 20,
            ),
            FilledButton.icon(
              onPressed:
                  _loadBusiness,
              icon:
                  const Icon(
                Icons.refresh_rounded,
              ),
              label:
                  const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NO BUSINESS
  // ============================================================

  Widget _buildNoBusinessState(
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
              Icons
                  .business_center_outlined,
              size: 56,
              color:
                  AppColors.warning,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Business profile required',
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Please complete your business setup first.',
              textAlign:
                  TextAlign.center,
              style: theme
                  .textTheme
                  .bodyMedium,
            ),
            const SizedBox(
              height: 20,
            ),
            FilledButton.icon(
              onPressed:
                  _loadBusiness,
              icon:
                  const Icon(
                Icons.refresh_rounded,
              ),
              label:
                  const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SUMMARY CARD
// ============================================================================

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
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

    return Container(
      width: 155,
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color:
            theme.cardColor,
        borderRadius:
            BorderRadius.circular(16),
        border:
            Border.all(
          color: theme
              .dividerColor
              .withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
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
              size: 21,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
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
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOMER CARD
// ============================================================================

class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStatement;

  const _CustomerCard({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
    required this.onStatement,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final bool hasMobile =
        customer.mobile.trim().isNotEmpty;

    final bool hasAddress =
        customer.address.trim().isNotEmpty;

    final bool hasGst =
        customer.gstNumber.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior:
          Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildAvatar(),
            const SizedBox(
              width: 14,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              maxLines: 2,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: theme
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            if (customer
                                .ownerName
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                'Owner: ${customer.ownerName}',
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
                      PopupMenuButton<String>(
                        tooltip:
                            'Customer options',
                        onSelected:
                            (String value) {
                          if (value ==
                              'statement') {
                            onStatement();
                          } else if (value ==
                              'edit') {
                            onEdit();
                          } else if (value ==
                              'delete') {
                            onDelete();
                          }
                        },
                        itemBuilder:
                            (context) {
                          return const [
                            PopupMenuItem<String>(
                              value: 'statement',
                              child: ListTile(
                                contentPadding:
                                    EdgeInsets.zero,
                                leading: Icon(
                                  Icons
                                      .account_balance_wallet_outlined,
                                  color:
                                      AppColors.primary,
                                ),
                                title: Text(
                                  'Customer Statement',
                                ),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: ListTile(
                                contentPadding:
                                    EdgeInsets.zero,
                                leading: Icon(
                                  Icons
                                      .edit_outlined,
                                ),
                                title:
                                    Text(
                                  'Edit',
                                ),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: ListTile(
                                contentPadding:
                                    EdgeInsets.zero,
                                leading:
                                    Icon(
                                  Icons
                                      .delete_outline_rounded,
                                  color:
                                      AppColors.danger,
                                ),
                                title:
                                    Text(
                                  'Delete',
                                ),
                              ),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hasMobile)
                        _InfoChip(
                          icon:
                              Icons.phone_outlined,
                          text:
                              customer.mobile,
                        ),
                      if (hasGst)
                        _InfoChip(
                          icon: Icons
                              .receipt_long_outlined,
                          text: 'GST',
                        ),
                    ],
                  ),
                  if (hasAddress) ...[
                    const SizedBox(
                      height: 9,
                    ),
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons
                              .location_on_outlined,
                          size: 17,
                          color: theme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Expanded(
                          child: Text(
                            customer.address,
                            maxLines: 2,
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
                        ),
                      ],
                    ),
                  ],
                  if (customer.email
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 7,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons
                              .email_outlined,
                          size: 17,
                          color: theme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Expanded(
                          child: Text(
                            customer.email,
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
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final String firstLetter =
        customer.name.trim().isEmpty
            ? '?'
            : customer.name
                .trim()
                .substring(0, 1)
                .toUpperCase();

    return Container(
      width: 48,
      height: 48,
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.secondary,
          ],
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      alignment:
          Alignment.center,
      child: Text(
        firstLetter,
        style:
            const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }
}

// ============================================================================
// INFO CHIP
// ============================================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
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
      decoration:
          BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.55,
        ),
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            text,
            style: theme
                .textTheme
                .labelSmall
                ?.copyWith(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOMER STATEMENT DIALOG
// ============================================================================

class _CustomerStatementDialog extends StatelessWidget {
  final BusinessModel business;
  final CustomerModel customer;
  final List<LedgerTransactionModel> transactions;
  final Future<void> Function() onPrint;
  final Future<void> Function() onShare;

  const _CustomerStatementDialog({
    required this.business,
    required this.customer,
    required this.transactions,
    required this.onPrint,
    required this.onShare,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final double totalSales =
        _totalByType('SALE');

    final double totalPayments =
        _totalByType('PAYMENT');

    final double balance =
        transactions.isEmpty
            ? 0
            : transactions.last.balanceAfter;

    return AlertDialog(
      titlePadding:
          const EdgeInsets.fromLTRB(
        24,
        22,
        12,
        8,
      ),
      contentPadding:
          const EdgeInsets.fromLTRB(
        24,
        8,
        24,
        16,
      ),
      actionsPadding:
          const EdgeInsets.fromLTRB(
        16,
        4,
        16,
        16,
      ),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color:
                  AppColors.primary.withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons
                  .account_balance_wallet_rounded,
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
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customer Statement',
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  customer.name.trim().isEmpty
                      ? 'Customer'
                      : customer.name.trim(),
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
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _StatementBusinessHeader(
                business: business,
              ),
              const SizedBox(
                height: 16,
              ),
              _StatementCustomerHeader(
                customer: customer,
              ),
              const SizedBox(
                height: 16,
              ),
              Row(
                children: [
                  Expanded(
                    child: _StatementMetric(
                      title: 'Sales',
                      value:
                          _formatCurrency(
                        totalSales,
                      ),
                      icon:
                          Icons
                              .trending_up_rounded,
                      color:
                          AppColors.primary,
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: _StatementMetric(
                      title: 'Received',
                      value:
                          _formatCurrency(
                        totalPayments,
                      ),
                      icon:
                          Icons
                              .payments_rounded,
                      color:
                          AppColors.success,
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: _StatementMetric(
                      title: 'Balance',
                      value:
                          _formatCurrency(
                        balance,
                      ),
                      icon:
                          Icons
                              .account_balance_wallet_outlined,
                      color: balance > 0
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 18,
              ),
              Text(
                'Recent Transactions',
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              if (transactions.isEmpty)
                _buildNoTransactions(
                  context,
                )
              else
                ...transactions
                    .reversed
                    .take(10)
                    .map(
                  (transaction) =>
                      _StatementTransactionTile(
                    transaction:
                        transaction,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child:
              const Text('Close'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            await onShare();
          },
          icon:
              const Icon(
            Icons.share_outlined,
          ),
          label:
              const Text('Share'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await onPrint();
          },
          icon:
              const Icon(
            Icons.print_outlined,
          ),
          label:
              const Text('Print'),
        ),
      ],
    );
  }

  double _totalByType(
    String transactionType,
  ) {
    double total = 0;

    for (final LedgerTransactionModel transaction
        in transactions) {
      if (transaction.transactionType
              .trim()
              .toUpperCase() ==
          transactionType) {
        total += transaction.amount;
      }
    }

    return total;
  }

  Widget _buildNoTransactions(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration:
          BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.45,
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 34,
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            'No transactions found.',
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
    );
  }
}

// ============================================================================
// STATEMENT BUSINESS HEADER
// ============================================================================

class _StatementBusinessHeader
    extends StatelessWidget {
  final BusinessModel business;

  const _StatementBusinessHeader({
    required this.business,
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
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color:
            AppColors.primary.withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(12),
        border:
            Border.all(
          color:
              AppColors.primary.withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            business.businessName.trim().isEmpty
                ? 'Business'
                : business.businessName.trim(),
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
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
          if (business.address
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height: 4,
            ),
            Text(
              business.address.trim(),
              maxLines: 2,
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
          if (business.mobile
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height: 3,
            ),
            Text(
              business.mobile.trim(),
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
    );
  }
}

// ============================================================================
// STATEMENT CUSTOMER HEADER
// ============================================================================

class _StatementCustomerHeader
    extends StatelessWidget {
  final CustomerModel customer;

  const _StatementCustomerHeader({
    required this.customer,
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
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color:
            theme.cardColor,
        borderRadius:
            BorderRadius.circular(12),
        border:
            Border.all(
          color:
              theme.dividerColor.withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                ],
              ),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            alignment:
                Alignment.center,
            child: Text(
              customer.name.trim().isEmpty
                  ? '?'
                  : customer.name
                      .trim()
                      .substring(0, 1)
                      .toUpperCase(),
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontWeight:
                    FontWeight.w800,
                fontSize: 17,
              ),
            ),
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
                  customer.name.trim().isEmpty
                      ? 'Customer'
                      : customer.name.trim(),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                if (customer.mobile
                    .trim()
                    .isNotEmpty)
                  Text(
                    customer.mobile.trim(),
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: theme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                if (customer.ownerName
                    .trim()
                    .isNotEmpty)
                  Text(
                    'Owner: ${customer.ownerName.trim()}',
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

// ============================================================================
// STATEMENT METRIC
// ============================================================================

class _StatementMetric
    extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatementMetric({
    required this.title,
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

    return Container(
      padding:
          const EdgeInsets.all(10),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(11),
        border:
            Border.all(
          color:
              color.withValues(
            alpha: 0.13,
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
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(
                width: 5,
              ),
              Expanded(
                child: Text(
                  title,
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
              ),
            ],
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: theme
                .textTheme
                .labelLarge
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATEMENT TRANSACTION TILE
// ============================================================================

class _StatementTransactionTile
    extends StatelessWidget {
  final LedgerTransactionModel transaction;

  const _StatementTransactionTile({
    required this.transaction,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final String type =
        transaction.transactionType
            .trim()
            .toUpperCase();

    final bool isSale =
        type == 'SALE';

    final bool isPayment =
        type == 'PAYMENT';

    final Color color = isSale
        ? AppColors.primary
        : isPayment
            ? AppColors.success
            : theme.colorScheme.primary;

    final String label =
        _transactionLabel(type);

    final String description =
        transaction.notes.trim().isNotEmpty
            ? transaction.notes.trim()
            : transaction.referenceId
                    .trim()
                    .isNotEmpty
                ? 'Ref: ${transaction.referenceId.trim()}'
                : label;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.all(11),
      decoration:
          BoxDecoration(
        color:
            theme.cardColor,
        borderRadius:
            BorderRadius.circular(10),
        border:
            Border.all(
          color:
              theme.dividerColor.withValues(
            alpha: 0.30,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration:
                BoxDecoration(
              color:
                  color.withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(9),
            ),
            child: Icon(
              isSale
                  ? Icons
                      .trending_up_rounded
                  : isPayment
                      ? Icons
                          .payments_rounded
                      : Icons
                          .receipt_long_outlined,
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(
            width: 9,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: theme
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Text(
                      _formatDate(
                        transaction.date,
                      ),
                      style: theme
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                        color: theme
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  description,
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
            width: 8,
          ),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(
                  transaction.amount,
                ),
                style: theme
                    .textTheme
                    .labelMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(
                height: 2,
              ),
              Text(
                _formatCurrency(
                  transaction.balanceAfter,
                ),
                style: theme
                    .textTheme
                    .labelSmall
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
    );
  }
}

// ============================================================================
// STATEMENT HELPERS
// ============================================================================

String _transactionLabel(
  String type,
) {
  switch (type) {
    case 'SALE':
      return 'Sale';

    case 'PAYMENT':
      return 'Payment';

    case 'RETURN':
      return 'Return';

    case 'ADJUSTMENT':
      return 'Adjustment';

    default:
      if (type.isEmpty) {
        return 'Transaction';
      }

      return type[0].toUpperCase() +
          type.substring(1).toLowerCase();
  }
}

String _formatDate(
  DateTime date,
) {
  final DateTime local =
      date.toLocal();

  final String day =
      local.day.toString().padLeft(
            2,
            '0',
          );

  final String month =
      local.month.toString().padLeft(
            2,
            '0',
          );

  return '$day/$month/${local.year}';
}

String _formatCurrency(
  double value,
) {
  final double rounded =
      double.parse(
    value.toStringAsFixed(2),
  );

  final bool negative =
      rounded < 0;

  final double absolute =
      rounded.abs();

  final String fixed =
      absolute.toStringAsFixed(2);

  final List<String> parts =
      fixed.split('.');

  String integerPart =
      parts[0];

  final StringBuffer formatted =
      StringBuffer();

  int count = 0;

  for (int i =
          integerPart.length - 1;
      i >= 0;
      i--) {
    formatted.write(
      integerPart[i],
    );

    count++;

    if (count == 3 &&
        i != 0) {
      formatted.write(',');
      count = 0;
    } else if (count > 3 &&
        (count - 3) % 2 == 0 &&
        i != 0) {
      formatted.write(',');
    }
  }

  integerPart =
      formatted
          .toString()
          .split('')
          .reversed
          .join();

  return '${negative ? '-' : ''}Rs. $integerPart.${parts[1]}';
}
