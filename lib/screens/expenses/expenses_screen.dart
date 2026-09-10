import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/expense_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/expense_provider.dart';
import 'add_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
  });

  @override
  State<ExpensesScreen> createState() =>
      _ExpensesScreenState();
}

class _ExpensesScreenState
    extends State<ExpensesScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  final NumberFormat _currencyFormat =
      NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  final DateFormat _dateFormat =
      DateFormat('dd MMM yyyy');

  String? _businessId;

  bool _isInitializing = true;
  bool _initialized = false;

  String? _pageError;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedPaymentMethod = 'All';

  DateTimeRange? _selectedDateRange;

  static const List<String> _categories = [
    'All',
    'Transportation',
    'Labour',
    'Electricity',
    'Packaging',
    'Rent',
    'Fuel',
    'Maintenance',
    'Other',
  ];

  static const List<String> _paymentMethods = [
    'All',
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  Future<void> _initialize() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isInitializing = true;
      _pageError = null;
    });

    try {
      final BusinessProvider businessProvider =
          context.read<BusinessProvider>();

      final ExpenseProvider expenseProvider =
          context.read<ExpenseProvider>();

      await businessProvider.loadBusiness();

      if (!mounted) {
        return;
      }

      final String businessId =
          businessProvider.business?.id.trim() ?? '';

      if (businessId.isEmpty) {
        setState(() {
          _businessId = null;
          _isInitializing = false;
          _initialized = false;
          _pageError =
              'Business profile not found. Please complete your business setup.';
        });
        return;
      }

      _businessId = businessId;

      expenseProvider.setBusinessId(
        businessId,
      );

      await expenseProvider.loadAndWatchExpenses(
        businessId: businessId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _initialized = true;
        _pageError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _initialized = false;
        _pageError =
            'Unable to load expenses. Please try again.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }

    try {
      final BusinessProvider businessProvider =
          context.read<BusinessProvider>();

      final ExpenseProvider expenseProvider =
          context.read<ExpenseProvider>();

      await businessProvider.refresh();

      if (!mounted) {
        return;
      }

      final String businessId =
          businessProvider.business?.id.trim() ?? '';

      if (businessId.isEmpty) {
        setState(() {
          _businessId = null;
          _pageError =
              'Business profile not found.';
        });
        return;
      }

      if (_businessId != businessId) {
        _businessId = businessId;

        expenseProvider.setBusinessId(
          businessId,
        );

        await expenseProvider.loadAndWatchExpenses(
          businessId: businessId,
        );
      } else {
        await expenseProvider.refresh();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to refresh expenses.',
          ),
          backgroundColor:
              AppColors.danger,
          behavior:
              SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: _refresh,
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // FILTERING
  // ---------------------------------------------------------------------------

  List<ExpenseModel> _filterExpenses(
    List<ExpenseModel> expenses,
  ) {
    final String query =
        _searchQuery.trim().toLowerCase();

    return expenses.where((expense) {
      if (query.isNotEmpty) {
        final String category =
            expense.category.toLowerCase();

        final String paymentMethod =
            expense.paymentMethod.toLowerCase();

        final String description =
            expense.description.toLowerCase();

        final String notes =
            expense.notes.toLowerCase();

        final String amount =
            expense.amount.toStringAsFixed(2);

        final bool matchesSearch =
            category.contains(query) ||
                paymentMethod.contains(query) ||
                description.contains(query) ||
                notes.contains(query) ||
                amount.contains(query);

        if (!matchesSearch) {
          return false;
        }
      }

      if (_selectedCategory != 'All' &&
          expense.category !=
              _selectedCategory) {
        return false;
      }

      if (_selectedPaymentMethod != 'All' &&
          expense.paymentMethod !=
              _selectedPaymentMethod) {
        return false;
      }

      if (_selectedDateRange != null) {
        final DateTime start = DateTime(
          _selectedDateRange!.start.year,
          _selectedDateRange!.start.month,
          _selectedDateRange!.start.day,
        );

        final DateTime end = DateTime(
          _selectedDateRange!.end.year,
          _selectedDateRange!.end.month,
          _selectedDateRange!.end.day,
          23,
          59,
          59,
          999,
        );

        if (expense.date.isBefore(start) ||
            expense.date.isAfter(end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  double _calculateTotal(
    List<ExpenseModel> expenses,
  ) {
    return expenses.fold<double>(
      0,
      (double total, ExpenseModel expense) {
        return total + expense.amount;
      },
    );
  }

  double _calculateTodayTotal(
    List<ExpenseModel> expenses,
  ) {
    final DateTime now = DateTime.now();

    return expenses.fold<double>(
      0,
      (double total, ExpenseModel expense) {
        final DateTime date = expense.date;

        final bool isToday =
            date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;

        if (isToday) {
          return total + expense.amount;
        }

        return total;
      },
    );
  }

  bool get _hasFilters {
    return _searchQuery.trim().isNotEmpty ||
        _selectedCategory != 'All' ||
        _selectedPaymentMethod != 'All' ||
        _selectedDateRange != null;
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedCategory = 'All';
      _selectedPaymentMethod = 'All';
      _selectedDateRange = null;
    });
  }

  // ---------------------------------------------------------------------------
  // DATE RANGE
  // ---------------------------------------------------------------------------

  Future<void> _selectDateRange() async {
    final DateTime now = DateTime.now();

    final DateTimeRange? selected =
        await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(
        now.year + 2,
        12,
        31,
      ),
      initialDateRange:
          _selectedDateRange,
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                Theme.of(context)
                    .colorScheme
                    .copyWith(
              primary:
                  AppColors.primary,
            ),
          ),
          child:
              child ?? const SizedBox.shrink(),
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedDateRange = selected;
    });
  }

  // ---------------------------------------------------------------------------
  // ADD EXPENSE
  // ---------------------------------------------------------------------------

  Future<void> _openAddExpense() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const AddExpenseScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await context
        .read<ExpenseProvider>()
        .refresh();
  }

  // ---------------------------------------------------------------------------
  // EDIT EXPENSE
  // ---------------------------------------------------------------------------

  Future<void> _openEditExpense(
    ExpenseModel expense,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AddExpenseScreen(
          expense: expense,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await context
        .read<ExpenseProvider>()
        .refresh();
  }

  // ---------------------------------------------------------------------------
  // DELETE EXPENSE
  // ---------------------------------------------------------------------------

  Future<void> _deleteExpense(
    ExpenseModel expense,
  ) async {
    final bool? shouldDelete =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext context,
      ) {
        return AlertDialog(
          title: const Text(
            'Delete Expense?',
          ),
          content: Text(
            'Are you sure you want to delete this expense of '
            '${_currencyFormat.format(expense.amount)}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
                  const Text('CANCEL'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    AppColors.danger,
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
                  const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true ||
        !mounted) {
      return;
    }

    try {
      await context
          .read<ExpenseProvider>()
          .deleteExpense(
        expenseId: expense.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Expense deleted successfully.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete expense: $e',
          ),
          backgroundColor:
              AppColors.danger,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DETAILS
  // ---------------------------------------------------------------------------

  void _showExpenseDetails(
    ExpenseModel expense,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (
        BuildContext context,
      ) {
        return SafeArea(
          child: Container(
            margin:
                const EdgeInsets.all(12),
            padding:
                const EdgeInsets.all(20),
            decoration:
                BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surface,
              borderRadius:
                  BorderRadius.circular(24),
            ),
            child:
                SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  _buildDetailsHeader(
                    context,
                    expense,
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  _detailTile(
                    context,
                    icon:
                        Icons.category_rounded,
                    label: 'Category',
                    value:
                        expense.category,
                  ),
                  _detailTile(
                    context,
                    icon: Icons
                        .currency_rupee_rounded,
                    label: 'Amount',
                    value:
                        _currencyFormat
                            .format(
                      expense.amount,
                    ),
                    valueColor:
                        AppColors.danger,
                  ),
                  _detailTile(
                    context,
                    icon: Icons
                        .account_balance_wallet_rounded,
                    label:
                        'Payment Method',
                    value:
                        expense.paymentMethod,
                  ),
                  _detailTile(
                    context,
                    icon: Icons
                        .calendar_today_rounded,
                    label: 'Expense Date',
                    value:
                        _dateFormat.format(
                      expense.date,
                    ),
                  ),
                  if (expense
                      .description
                      .trim()
                      .isNotEmpty)
                    _detailTile(
                      context,
                      icon:
                          Icons.description_rounded,
                      label:
                          'Description',
                      value:
                          expense.description,
                    ),
                  if (expense.notes
                      .trim()
                      .isNotEmpty)
                    _detailTile(
                      context,
                      icon:
                          Icons.notes_rounded,
                      label: 'Notes',
                      value:
                          expense.notes,
                    ),
                  const SizedBox(
                    height: 12,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(
                              context,
                            );

                            _openEditExpense(
                              expense,
                            );
                          },
                          icon: const Icon(
                            Icons
                                .edit_outlined,
                          ),
                          label:
                              const Text(
                            'EDIT',
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(
                              context,
                            );

                            _deleteExpense(
                              expense,
                            );
                          },
                          icon: const Icon(
                            Icons
                                .delete_outline_rounded,
                          ),
                          label:
                              const Text(
                            'DELETE',
                          ),
                          style:
                              OutlinedButton
                                  .styleFrom(
                            foregroundColor:
                                AppColors
                                    .danger,
                            side:
                                const BorderSide(
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailsHeader(
    BuildContext context,
    ExpenseModel expense,
  ) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color:
                AppColors.danger.withValues(
              alpha: 0.10,
            ),
            borderRadius:
                BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons
                .account_balance_wallet_rounded,
            color: AppColors.danger,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Expense Details',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w700,
                    ),
              ),
              const SizedBox(
                height: 3,
              ),
              Text(
                _dateFormat.format(
                  expense.date,
                ),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.close_rounded,
          ),
        ),
      ],
    );
  }

  Widget _detailTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
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
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                        color: valueColor,
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

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_pageError != null ||
        _businessId == null ||
        !_initialized) {
      return _buildPageError();
    }

    return Consumer<ExpenseProvider>(
      builder: (
        BuildContext context,
        ExpenseProvider expenseProvider,
        Widget? child,
      ) {
        if (expenseProvider.isLoading &&
            expenseProvider.expenses.isEmpty) {
          return const Scaffold(
            body: Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        if (expenseProvider.errorMessage != null &&
            expenseProvider.expenses.isEmpty) {
          return _buildProviderError(
            expenseProvider.errorMessage!,
          );
        }

        final List<ExpenseModel>
            allExpenses =
            expenseProvider.expenses;

        final List<ExpenseModel>
            filteredExpenses =
            _filterExpenses(
          allExpenses,
        );

        final double totalExpenses =
            _calculateTotal(
          allExpenses,
        );

        final double filteredTotal =
            _calculateTotal(
          filteredExpenses,
        );

        final double todayTotal =
            _calculateTodayTotal(
          allExpenses,
        );

        return _buildScreen(
          allExpenses: allExpenses,
          filteredExpenses:
              filteredExpenses,
          totalExpenses:
              totalExpenses,
          filteredTotal:
              filteredTotal,
          todayTotal:
              todayTotal,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ERROR STATES
  // ---------------------------------------------------------------------------

  Widget _buildPageError() {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Expenses'),
      ),
      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.business_center_outlined,
                size: 56,
                color:
                    AppColors.warning,
              ),
              const SizedBox(
                height: 16,
              ),
              Text(
                _pageError ??
                    'Business profile not found.',
                textAlign:
                    TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w700,
                    ),
              ),
              const SizedBox(
                height: 16,
              ),
              FilledButton.icon(
                onPressed: _initialize,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label:
                    const Text('RETRY'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderError(
    String error,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Expenses'),
      ),
      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
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
                'Unable to load expenses.',
                textAlign:
                    TextAlign.center,
                style: Theme.of(context)
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
              Text(
                error,
                textAlign:
                    TextAlign.center,
                maxLines: 3,
                overflow:
                    TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
              const SizedBox(
                height: 18,
              ),
              FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label:
                    const Text('RETRY'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN SCREEN
  // ---------------------------------------------------------------------------

  Widget _buildScreen({
    required List<ExpenseModel> allExpenses,
    required List<ExpenseModel>
        filteredExpenses,
    required double totalExpenses,
    required double filteredTotal,
    required double todayTotal,
  }) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Expenses'),
        actions: [
          if (_hasFilters)
            IconButton(
              tooltip:
                  'Clear filters',
              onPressed:
                  _clearFilters,
              icon: const Icon(
                Icons
                    .filter_alt_off_rounded,
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _openAddExpense,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label:
            const Text('ADD EXPENSE'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: LayoutBuilder(
            builder: (
              BuildContext context,
              BoxConstraints constraints,
            ) {
              final bool isDesktop =
                  constraints.maxWidth >=
                      1000;

              return Center(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(
                    maxWidth: isDesktop
                        ? 1250
                        : double.infinity,
                  ),
                  child:
                      SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      110,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        _buildHeader(
                          allExpenses.length,
                          todayTotal,
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        _buildSummaryCards(
                          totalExpenses:
                              totalExpenses,
                          todayTotal:
                              todayTotal,
                          filteredTotal:
                              filteredTotal,
                          totalCount:
                              allExpenses.length,
                          filteredCount:
                              filteredExpenses
                                  .length,
                          isDesktop:
                              isDesktop,
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        _buildFilters(
                          isDesktop:
                              isDesktop,
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        _buildExpenseList(
                          filteredExpenses,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(
    int expenseCount,
    double todayTotal,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            AppColors.danger,
            Color(0xFFB91C1C),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration:
                BoxDecoration(
              color:
                  Colors.white.withValues(
                alpha: 0.15,
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: const Icon(
              Icons
                  .account_balance_wallet_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Expense Management',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.w700,
                      ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  '$expenseCount expense${expenseCount == 1 ? '' : 's'} recorded',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: Colors.white
                            .withValues(
                          alpha: 0.82,
                        ),
                      ),
                ),
              ],
            ),
          ),
          if (todayTotal > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.white
                    .withValues(
                  alpha: 0.13,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  const Text(
                    'TODAY',
                    style: TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 9,
                      fontWeight:
                          FontWeight.w700,
                      letterSpacing:
                          0.7,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    _currencyFormat
                        .format(
                      todayTotal,
                    ),
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY CARDS
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCards({
    required double totalExpenses,
    required double todayTotal,
    required double filteredTotal,
    required int totalCount,
    required int filteredCount,
    required bool isDesktop,
  }) {
    final List<Widget> cards = [
      _summaryCard(
        icon: Icons
            .account_balance_wallet_rounded,
        title: 'Total Expenses',
        value:
            _currencyFormat.format(
          totalExpenses,
        ),
        subtitle:
            '$totalCount transactions',
        color: AppColors.danger,
      ),
      _summaryCard(
        icon:
            Icons.today_rounded,
        title: 'Today',
        value:
            _currencyFormat.format(
          todayTotal,
        ),
        subtitle:
            'Spent today',
        color: AppColors.warning,
      ),
      _summaryCard(
        icon:
            Icons.filter_alt_rounded,
        title: 'Filtered',
        value:
            _currencyFormat.format(
          filteredTotal,
        ),
        subtitle:
            '$filteredCount matching',
        color: AppColors.primary,
      ),
    ];

    if (isDesktop) {
      return Row(
        children:
            cards.map(
          (Widget card) {
            return Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.only(
                  right: 10,
                ),
                child: card,
              ),
            );
          },
        ).toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: cards[0],
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: cards[1],
            ),
          ],
        ),
        const SizedBox(
          height: 10,
        ),
        cards[2],
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context)
              .dividerColor
              .withValues(
            alpha: 0.5,
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
              color:
                  color.withValues(
                alpha: 0.1,
              ),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(
            width: 11,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(
                  height: 3,
                ),
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
                            FontWeight.w700,
                      ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: color,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTERS
  // ---------------------------------------------------------------------------

  Widget _buildFilters({
    required bool isDesktop,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context)
              .dividerColor
              .withValues(
            alpha: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_list_rounded,
                size: 20,
                color:
                    AppColors.primary,
              ),
              const SizedBox(
                width: 8,
              ),
              Text(
                'Search & Filters',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w700,
                    ),
              ),
              const Spacer(),
              if (_hasFilters)
                TextButton(
                  onPressed:
                      _clearFilters,
                  child:
                      const Text('CLEAR'),
                ),
            ],
          ),
          const SizedBox(
            height: 14,
          ),
          if (isDesktop)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child:
                      _searchField(),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child:
                      _categoryDropdown(),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child:
                      _paymentMethodDropdown(),
                ),
              ],
            )
          else ...[
            _searchField(),
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                Expanded(
                  child:
                      _categoryDropdown(),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child:
                      _paymentMethodDropdown(),
                ),
              ],
            ),
          ],
          const SizedBox(
            height: 10,
          ),
          _dateFilterButton(),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller:
          _searchController,
      onChanged: (String value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration:
          InputDecoration(
        hintText:
            'Search category, description, amount...',
        prefixIcon:
            const Icon(
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
                    icon:
                        const Icon(
                      Icons.clear_rounded,
                    ),
                  )
                : null,
      ),
    );
  }

  Widget _categoryDropdown() {
    return DropdownButtonFormField<
        String>(
      initialValue:
          _selectedCategory,
      decoration:
          const InputDecoration(
        labelText: 'Category',
        prefixIcon:
            Icon(
          Icons.category_outlined,
        ),
      ),
      items: _categories.map(
        (String category) {
          return DropdownMenuItem<
              String>(
            value: category,
            child:
                Text(category),
          );
        },
      ).toList(),
      onChanged:
          (String? value) {
        if (value == null) {
          return;
        }

        setState(() {
          _selectedCategory =
              value;
        });
      },
    );
  }

  Widget _paymentMethodDropdown() {
    return DropdownButtonFormField<
        String>(
      initialValue:
          _selectedPaymentMethod,
      decoration:
          const InputDecoration(
        labelText:
            'Payment Method',
        prefixIcon: Icon(
          Icons
              .account_balance_wallet_outlined,
        ),
      ),
      items:
          _paymentMethods.map(
        (String method) {
          return DropdownMenuItem<
              String>(
            value: method,
            child:
                Text(method),
          );
        },
      ).toList(),
      onChanged:
          (String? value) {
        if (value == null) {
          return;
        }

        setState(() {
          _selectedPaymentMethod =
              value;
        });
      },
    );
  }

  Widget _dateFilterButton() {
    final bool hasDate =
        _selectedDateRange != null;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed:
            _selectDateRange,
        icon: const Icon(
          Icons.date_range_rounded,
        ),
        label: Text(
          hasDate
              ? '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - '
                  '${DateFormat('dd/MM').format(_selectedDateRange!.end)}'
              : 'Select Date Range',
          overflow:
              TextOverflow.ellipsis,
        ),
        style:
            OutlinedButton.styleFrom(
          minimumSize:
              const Size.fromHeight(
            56,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EXPENSE LIST
  // ---------------------------------------------------------------------------

  Widget _buildExpenseList(
    List<ExpenseModel> expenses,
  ) {
    if (expenses.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Expense History',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
            ),
            const SizedBox(
              width: 8,
            ),
            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration:
                  BoxDecoration(
                color: AppColors
                    .danger
                    .withValues(
                  alpha: 0.1,
                ),
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: Text(
                '${expenses.length}',
                style:
                    const TextStyle(
                  color:
                      AppColors.danger,
                  fontWeight:
                      FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 12,
        ),
        ...expenses.map(
          (ExpenseModel expense) =>
              _expenseCard(expense),
        ),
      ],
    );
  }

  Widget _expenseCard(
    ExpenseModel expense,
  ) {
    final String category =
        expense.category.trim().isEmpty
            ? 'Other'
            : expense.category;

    final String description =
        expense.description
                .trim()
                .isEmpty
            ? 'No description'
            : expense.description;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      elevation: 0,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        onTap: () {
          _showExpenseDetails(
            expense,
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.all(
            14,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color: AppColors
                      .danger
                      .withValues(
                    alpha: 0.1,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .arrow_upward_rounded,
                  color:
                      AppColors.danger,
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
                      category,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      children: [
                        _smallTag(
                          category,
                          AppColors
                              .danger,
                        ),
                        Text(
                          _dateFormat
                              .format(
                            expense.date,
                          ),
                          style: Theme.of(
                            context,
                          )
                              .textTheme
                              .bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      description,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: Theme.of(
                        context,
                      )
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
              const SizedBox(
                width: 10,
              ),
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .end,
                children: [
                  Text(
                    _currencyFormat
                        .format(
                      expense.amount,
                    ),
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color:
                              AppColors
                                  .danger,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    expense.paymentMethod,
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ),
              const SizedBox(
                width: 4,
              ),
              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallTag(
    String text,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: 0.09,
        ),
        borderRadius:
            BorderRadius.circular(
          6,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 50,
      ),
      decoration:
          BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: Theme.of(context)
              .dividerColor
              .withValues(
            alpha: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration:
                BoxDecoration(
              color: AppColors
                  .danger
                  .withValues(
                alpha: 0.1,
              ),
              shape:
                  BoxShape.circle,
            ),
            child: Icon(
              _hasFilters
                  ? Icons
                      .search_off_rounded
                  : Icons
                      .receipt_long_outlined,
              size: 34,
              color:
                  AppColors.danger,
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          Text(
            _hasFilters
                ? 'No expenses found'
                : 'No expenses recorded',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight:
                      FontWeight.w700,
                ),
          ),
          const SizedBox(
            height: 7,
          ),
          Text(
            _hasFilters
                ? 'Try changing your search or filters.'
                : 'Expense transactions will appear here.',
            textAlign:
                TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color: Theme.of(
                    context,
                  )
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),
          const SizedBox(
            height: 16,
          ),
          if (_hasFilters)
            OutlinedButton.icon(
              onPressed:
                  _clearFilters,
              icon: const Icon(
                Icons
                    .filter_alt_off_rounded,
              ),
              label:
                  const Text(
                'CLEAR FILTERS',
              ),
            )
          else
            FilledButton.icon(
              onPressed:
                  _openAddExpense,
              icon: const Icon(
                Icons.add_rounded,
              ),
              label:
                  const Text(
                'ADD EXPENSE',
              ),
            ),
        ],
      ),
    );
  }
}