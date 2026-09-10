import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/customer_model.dart';
import '../../models/ledger_transaction_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/ledger_provider.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({
    super.key,
  });

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String? _selectedCustomerId;

  String _transactionFilter = 'All';

  DateTime? _startDate;
  DateTime? _endDate;

  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // INITIALIZE
  // ===========================================================================

  Future<void> _initialize() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isInitializing = true;
    });

    final BusinessProvider businessProvider =
        context.read<BusinessProvider>();

    final CustomerProvider customerProvider =
        context.read<CustomerProvider>();

    try {
      await businessProvider.loadBusiness();

      if (!mounted) {
        return;
      }

      final String businessId =
          businessProvider.business?.id.trim() ?? '';

      if (businessId.isEmpty) {
        customerProvider.setBusinessId('');

        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }

        return;
      }

      customerProvider.setBusinessId(businessId);

      await customerProvider.loadAndWatchCustomers(
        businessId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
      });

      _showMessage(
        _cleanError(e),
        isError: true,
      );
    }
  }

  // ===========================================================================
  // CUSTOMER LEDGER
  // ===========================================================================

  Future<void> _loadCustomerLedger(
    String customerId,
  ) async {
    final BusinessProvider businessProvider =
        context.read<BusinessProvider>();

    final LedgerProvider ledgerProvider =
        context.read<LedgerProvider>();

    final String businessId =
        businessProvider.business?.id.trim() ?? '';

    final String normalizedCustomerId =
        customerId.trim();

    if (businessId.isEmpty) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );
      return;
    }

    if (normalizedCustomerId.isEmpty) {
      ledgerProvider.clearError();
      return;
    }

    final CustomerProvider customerProvider =
        context.read<CustomerProvider>();

    final CustomerModel? customer =
        customerProvider.findCustomerById(
      normalizedCustomerId,
    );

    final String customerName =
        customer?.name.trim() ?? '';

    ledgerProvider.setContext(
      businessId: businessId,
      customerId: normalizedCustomerId,
    );

    await ledgerProvider.loadAndWatchCustomerTransactions(
      businessId: businessId,
      customerId: normalizedCustomerId,
    );

    if (!mounted) {
      return;
    }

    if (customerName.isNotEmpty) {
      _showMessage(
        '$customerName ledger loaded.',
      );
    }
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<void> _refresh() async {
    final BusinessProvider businessProvider =
        context.read<BusinessProvider>();

    final CustomerProvider customerProvider =
        context.read<CustomerProvider>();

    final LedgerProvider ledgerProvider =
        context.read<LedgerProvider>();

    try {
      await businessProvider.refresh();

      if (!mounted) {
        return;
      }

      final String businessId =
          businessProvider.business?.id.trim() ?? '';

      if (businessId.isEmpty) {
        customerProvider.setBusinessId('');
        ledgerProvider.clearError();

        return;
      }

      customerProvider.setBusinessId(businessId);

      await customerProvider.loadAndWatchCustomers(
        businessId,
      );

      if (!mounted) {
        return;
      }

      if (_selectedCustomerId != null &&
          _selectedCustomerId!.trim().isNotEmpty) {
        ledgerProvider.setContext(
          businessId: businessId,
          customerId: _selectedCustomerId!,
        );

        await ledgerProvider
            .loadAndWatchCustomerTransactions(
          businessId: businessId,
          customerId: _selectedCustomerId!,
        );
      } else {
        ledgerProvider.clearError();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(e),
        isError: true,
      );
    }
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  void _onSearchChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ===========================================================================
  // CUSTOMER SELECTION
  // ===========================================================================

  Future<void> _onCustomerChanged(
    String? customerId,
  ) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedCustomerId = customerId;
      _transactionFilter = 'All';
      _startDate = null;
      _endDate = null;
    });

    if (customerId == null ||
        customerId.trim().isEmpty) {
      context.read<LedgerProvider>().clearError();
      return;
    }

    await _loadCustomerLedger(customerId);
  }

  // ===========================================================================
  // DATE FILTER
  // ===========================================================================

  Future<void> _selectStartDate() async {
    final DateTime now = DateTime.now();

    final DateTime initialDate =
        _startDate ??
        _endDate ??
        now;

    final DateTime? selected =
        await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDate: initialDate,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _startDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );

      if (_endDate != null &&
          _endDate!.isBefore(_startDate!)) {
        _endDate = null;
      }
    });
  }

  Future<void> _selectEndDate() async {
    final DateTime now = DateTime.now();

    final DateTime initialDate =
        _endDate ??
        _startDate ??
        now;

    final DateTime? selected =
        await showDatePicker(
      context: context,
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDate: initialDate,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _endDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _transactionFilter = 'All';
      _startDate = null;
      _endDate = null;
    });
  }

  // ===========================================================================
  // FILTERED TRANSACTIONS
  // ===========================================================================

  List<LedgerTransactionModel> _filteredTransactions(
    List<LedgerTransactionModel> transactions,
  ) {
    final String search =
        _searchController.text.trim().toLowerCase();

    return transactions.where(
      (LedgerTransactionModel transaction) {
        final String type =
            transaction.transactionType.toLowerCase();

        final String notes =
            transaction.notes.toLowerCase();

        final String reference =
            transaction.referenceId.toLowerCase();

        final String customerName =
            transaction.customerName.toLowerCase();

        final bool matchesSearch =
            search.isEmpty ||
            type.contains(search) ||
            notes.contains(search) ||
            reference.contains(search) ||
            customerName.contains(search);

        if (!matchesSearch) {
          return false;
        }

        final bool matchesType =
            _transactionFilter == 'All' ||
            type == _transactionFilter.toLowerCase();

        if (!matchesType) {
          return false;
        }

        final DateTime transactionDate =
            transaction.date;

        if (_startDate != null) {
          final DateTime start = DateTime(
            _startDate!.year,
            _startDate!.month,
            _startDate!.day,
          );

          if (transactionDate.isBefore(start)) {
            return false;
          }
        }

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

          if (transactionDate.isAfter(end)) {
            return false;
          }
        }

        return true;
      },
    ).toList(growable: false);
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Consumer3<
        BusinessProvider,
        CustomerProvider,
        LedgerProvider>(
      builder: (
        context,
        businessProvider,
        customerProvider,
        ledgerProvider,
        child,
      ) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Customer Ledger',
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed:
                    _isInitializing
                        ? null
                        : _refresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
              ),
            ],
          ),
          body: _buildBody(
            context,
            businessProvider,
            customerProvider,
            ledgerProvider,
          ),
        );
      },
    );
  }

  // ===========================================================================
  // BODY
  // ===========================================================================

  Widget _buildBody(
    BuildContext context,
    BusinessProvider businessProvider,
    CustomerProvider customerProvider,
    LedgerProvider ledgerProvider,
  ) {
    if (_isInitializing ||
        businessProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (businessProvider.errorMessage != null &&
        businessProvider.business == null) {
      return _buildErrorState(
        context,
        businessProvider.errorMessage!,
      );
    }

    final String businessId =
        businessProvider.business?.id.trim() ?? '';

    if (businessId.isEmpty) {
      return _buildNoBusinessState(context);
    }

    final List<CustomerModel> customers =
        customerProvider.customers;

    final List<LedgerTransactionModel> transactions =
        _filteredTransactions(
      ledgerProvider.transactions,
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          final bool wide =
              constraints.maxWidth >= 900;

          return SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              wide ? 24 : 16,
              16,
              wide ? 24 : 16,
              32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 1400,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 16),
                    _buildCustomerSelector(
                      context,
                      customers,
                    ),
                    const SizedBox(height: 16),
                    if (_selectedCustomerId != null)
                      ...[
                        _buildSummary(
                          context,
                          ledgerProvider,
                          transactions,
                        ),
                        const SizedBox(height: 16),
                        _buildFilters(context),
                        const SizedBox(height: 16),
                        _buildLedgerSection(
                          context,
                          ledgerProvider,
                          transactions,
                        ),
                      ]
                    else
                      _buildSelectCustomerState(
                        context,
                        customers.isEmpty,
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
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(
              alpha: 0.12,
            ),
            AppColors.secondary.withValues(
              alpha: 0.08,
            ),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.outline
              .withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary
                  .withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Ledger',
                  style: theme
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track sales, payments and outstanding customer balances.',
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
        ],
      ),
    );
  }

  // ===========================================================================
  // CUSTOMER SELECTOR
  // ===========================================================================

  Widget _buildCustomerSelector(
    BuildContext context,
    List<CustomerModel> customers,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Select Customer / Hotel',
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue:
                  _selectedCustomerId,
              isExpanded: true,
              decoration:
                  const InputDecoration(
                labelText:
                    'Customer / Hotel',
                hintText:
                    'Select customer',
                prefixIcon: Icon(
                  Icons.person_rounded,
                ),
              ),
              items: customers.map(
                (CustomerModel customer) {
                  return DropdownMenuItem<String>(
                    value: customer.id,
                    child: Text(
                      customer.name,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  );
                },
              ).toList(),
              onChanged:
                  customers.isEmpty
                      ? null
                      : _onCustomerChanged,
            ),
            if (customers.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'No customers available. Add a customer first.',
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
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummary(
    BuildContext context,
    LedgerProvider ledgerProvider,
    List<LedgerTransactionModel> transactions,
  ) {
    final double balance =
        transactions.isNotEmpty
            ? transactions.last.balanceAfter
            : ledgerProvider.currentBalance;

    final double debit =
        transactions.fold<double>(
      0,
      (
        double total,
        LedgerTransactionModel transaction,
      ) {
        return total +
            transaction.amount;
      },
    );


    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final bool compact =
            constraints.maxWidth < 650;

        final List<Widget> cards = [
          _summaryCard(
            context,
            title: 'Current Balance',
            value: _formatCurrency(
              balance,
            ),
            icon: Icons.account_balance_rounded,
            iconColor:
                balance > 0
                    ? AppColors.warning
                    : AppColors.success,
          ),
          _summaryCard(
            context,
            title: 'Transactions',
            value:
                transactions.length.toString(),
            icon: Icons.receipt_long_rounded,
            iconColor:
                AppColors.primary,
          ),
          _summaryCard(
            context,
            title: 'Filtered Amount',
            value: _formatCurrency(
              debit,
            ),
            icon: Icons.currency_rupee_rounded,
            iconColor:
                AppColors.secondary,
          ),
        ];

        if (compact) {
          return Column(
            children: cards
                .map(
                  (Widget card) => Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: cards
              .map(
                (Widget card) => Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 5,
                    ),
                    child: card,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    final ThemeData theme =
        Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(14),
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
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: theme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FILTERS
  // ===========================================================================

  Widget _buildFilters(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller:
                  _searchController,
              decoration: InputDecoration(
                labelText:
                    'Search transactions',
                hintText:
                    'Search type, reference or notes...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                ),
                suffixIcon:
                    _searchController
                            .text
                            .trim()
                            .isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController
                                  .clear();
                            },
                            icon: const Icon(
                              Icons
                                  .clear_rounded,
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (
                BuildContext context,
                BoxConstraints constraints,
              ) {
                final bool stacked =
                    constraints.maxWidth < 700;

                final Widget typeDropdown =
                    DropdownButtonFormField<String>(
                  initialValue:
                      _transactionFilter,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Transaction Type',
                    prefixIcon: Icon(
                      Icons.swap_vert_rounded,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem<String>(
                      value: 'All',
                      child: Text('All'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'SALE',
                      child: Text('Sale'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'PAYMENT',
                      child: Text('Payment'),
                    ),
                  ],
                  onChanged: (
                    String? value,
                  ) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _transactionFilter =
                          value;
                    });
                  },
                );

                final Widget startDate =
                    _dateFilterButton(
                  context,
                  label: 'From',
                  date: _startDate,
                  onPressed:
                      _selectStartDate,
                );

                final Widget endDate =
                    _dateFilterButton(
                  context,
                  label: 'To',
                  date: _endDate,
                  onPressed:
                      _selectEndDate,
                );

                if (stacked) {
                  return Column(
                    children: [
                      typeDropdown,
                      const SizedBox(
                        height: 12,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: startDate,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: endDate,
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      SizedBox(
                        width: double.infinity,
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              _clearFilters,
                          icon: const Icon(
                            Icons
                                .filter_alt_off_rounded,
                          ),
                          label: const Text(
                            'Clear Filters',
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: typeDropdown,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: startDate,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: endDate,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _clearFilters,
                      icon: const Icon(
                        Icons
                            .filter_alt_off_rounded,
                      ),
                      label: const Text(
                        'Clear',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateFilterButton(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(
        Icons.calendar_today_rounded,
        size: 18,
      ),
      label: Text(
        date == null
            ? label
            : '$label: ${_formatDate(date)}',
        overflow:
            TextOverflow.ellipsis,
      ),
    );
  }

  // ===========================================================================
  // LEDGER SECTION
  // ===========================================================================

  Widget _buildLedgerSection(
    BuildContext context,
    LedgerProvider ledgerProvider,
    List<LedgerTransactionModel> transactions,
  ) {
    final ThemeData theme =
        Theme.of(context);

    if (ledgerProvider.isLoading &&
        transactions.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (ledgerProvider.errorMessage != null &&
        transactions.isEmpty) {
      return _buildErrorCard(
        context,
        ledgerProvider.errorMessage!,
      );
    }

    if (transactions.isEmpty) {
      return _buildEmptyLedger(
        context,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color:
                      AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Transaction History',
                    style: theme
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${transactions.length} records',
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
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            ListView.separated(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              itemCount:
                  transactions.length,
              separatorBuilder:
                  (
                BuildContext context,
                int index,
              ) =>
                  const Divider(height: 1),
              itemBuilder:
                  (
                BuildContext context,
                int index,
              ) {
                final LedgerTransactionModel
                    transaction =
                    transactions[index];

                return _buildTransactionTile(
                  context,
                  transaction,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TRANSACTION TILE
  // ===========================================================================

  Widget _buildTransactionTile(
    BuildContext context,
    LedgerTransactionModel transaction,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final String type =
        transaction.transactionType
            .trim()
            .toUpperCase();

    final bool isPayment =
        type == 'PAYMENT';

    final Color color =
        isPayment
            ? AppColors.success
            : AppColors.primary;

    final IconData icon =
        isPayment
            ? Icons.payments_rounded
            : Icons.receipt_long_rounded;

    return InkWell(
      onTap: () {
        _showTransactionDetails(
          context,
          transaction,
        );
      },
      borderRadius:
          BorderRadius.circular(12),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 4,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(13),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _transactionTitle(
                            transaction,
                          ),
                          style: theme
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Text(
                        _formatCurrency(
                          transaction.amount,
                        ),
                        style: TextStyle(
                          color: color,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatDateTime(
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
                  if (transaction.notes
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      transaction.notes,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _transactionChip(
                        context,
                        type.isEmpty
                            ? 'TRANSACTION'
                            : type,
                        color,
                      ),
                      if (transaction
                          .referenceId
                          .trim()
                          .isNotEmpty)
                        _transactionChip(
                          context,
                          'Ref: ${transaction.referenceId}',
                          AppColors.info,
                        ),
                      _transactionChip(
                        context,
                        'Balance: ${_formatCurrency(transaction.balanceAfter)}',
                        transaction.balanceAfter >
                                0
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionChip(
    BuildContext context,
    String text,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }

  // ===========================================================================
  // TRANSACTION DETAILS
  // ===========================================================================

  void _showTransactionDetails(
    BuildContext context,
    LedgerTransactionModel transaction,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (
        BuildContext context,
      ) {
        final ThemeData theme =
            Theme.of(context);

        return SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              30,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaction Details',
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                _detailRow(
                  context,
                  'Type',
                  transaction.transactionType,
                ),
                _detailRow(
                  context,
                  'Amount',
                  _formatCurrency(
                    transaction.amount,
                  ),
                ),
                _detailRow(
                  context,
                  'Balance Before',
                  _formatCurrency(
                    transaction.balanceBefore,
                  ),
                ),
                _detailRow(
                  context,
                  'Balance After',
                  _formatCurrency(
                    transaction.balanceAfter,
                  ),
                ),
                _detailRow(
                  context,
                  'Date',
                  _formatDateTime(
                    transaction.date,
                  ),
                ),
                if (transaction.referenceId
                    .trim()
                    .isNotEmpty)
                  _detailRow(
                    context,
                    'Reference',
                    transaction.referenceId,
                  ),
                if (transaction.notes
                    .trim()
                    .isNotEmpty)
                  _detailRow(
                    context,
                    'Notes',
                    transaction.notes,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 13,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme
                .colorScheme
                .outline
                .withValues(alpha: 0.18),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATES
  // ===========================================================================

  Widget _buildSelectCustomerState(
    BuildContext context,
    bool noCustomers,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 60,
          horizontal: 24,
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                noCustomers
                    ? Icons.person_add_alt_1_rounded
                    : Icons
                        .account_balance_wallet_outlined,
                size: 58,
                color: AppColors.primary
                    .withValues(alpha: 0.65),
              ),
              const SizedBox(height: 16),
              Text(
                noCustomers
                    ? 'No Customers Yet'
                    : 'Select a Customer',
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
                noCustomers
                    ? 'Add a customer or hotel to start maintaining ledgers.'
                    : 'Select a customer or hotel above to view their complete ledger.',
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
      ),
    );
  }

  Widget _buildEmptyLedger(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 60,
          horizontal: 24,
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 58,
                color: theme
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.55),
              ),
              const SizedBox(height: 16),
              Text(
                'No Ledger Transactions',
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
                'No transactions match the selected filters.',
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
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed:
                    _clearFilters,
                icon: const Icon(
                  Icons.filter_alt_off_rounded,
                ),
                label: const Text(
                  'Clear Filters',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoBusinessState(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.business_outlined,
              size: 64,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Business Not Found',
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please complete your business setup first.',
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _initialize,
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

  Widget _buildErrorState(
    BuildContext context,
    String message,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 60,
              color:
                  AppColors.danger,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Ledger',
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
              message,
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _initialize,
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

  Widget _buildErrorCard(
    BuildContext context,
    String message,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _refresh,
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
  // HELPERS
  // ===========================================================================

  String _transactionTitle(
    LedgerTransactionModel transaction,
  ) {
    final String type =
        transaction.transactionType
            .trim()
            .toUpperCase();

    switch (type) {
      case 'SALE':
        return 'Sale';
      case 'PAYMENT':
        return 'Payment Received';
      case 'RETURN':
        return 'Sale Return';
      case 'ADJUSTMENT':
        return 'Balance Adjustment';
      default:
        return transaction.transactionType
                .trim()
                .isEmpty
            ? 'Transaction'
            : transaction.transactionType;
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

  String _formatDate(
    DateTime value,
  ) {
    return DateFormat(
      'dd MMM yyyy',
    ).format(value);
  }

  String _formatDateTime(
    DateTime value,
  ) {
    return DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(value);
  }

  String _cleanError(
    Object error,
  ) {
    String message =
        error.toString().trim();

    if (message.startsWith(
      'Exception: ',
    )) {
      message = message.substring(
        'Exception: '.length,
      );
    }

    if (message.startsWith(
      'Bad state: ',
    )) {
      message = message.substring(
        'Bad state: '.length,
      );
    }

    return message.isEmpty
        ? 'Something went wrong.'
        : message;
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
          backgroundColor:
              isError
                  ? AppColors.danger
                  : AppColors.success,
        ),
      );
  }
}