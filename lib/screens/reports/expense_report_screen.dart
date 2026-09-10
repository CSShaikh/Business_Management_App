import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/expense_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/expense_repository.dart';

class ExpenseReportScreen extends StatefulWidget {
  const ExpenseReportScreen({
    super.key,
  });

  @override
  State<ExpenseReportScreen> createState() =>
      _ExpenseReportScreenState();
}

class _ExpenseReportScreenState
    extends State<ExpenseReportScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final ExpenseRepository _expenseRepository =
      ExpenseRepository();

  final TextEditingController _searchController =
      TextEditingController();

  bool _loading = true;
  bool _refreshing = false;

  String? _errorMessage;

  String _searchQuery = '';
  String _categoryFilter = 'All';
  String _paymentMethodFilter = 'All';

  DateTime? _startDate;
  DateTime? _endDate;

  List<ExpenseModel> _allExpenses =
      <ExpenseModel>[];

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
      final business =
          await _businessRepository
              .getBusinessForCurrentUser();

      if (business == null) {
        throw Exception(
          'Business information is not available.',
        );
      }

      final List<ExpenseModel> expenses =
          await _expenseRepository.getExpenses(
        businessId: business.id,
      );

      if (!mounted) return;

      setState(() {
        _allExpenses = expenses;
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
    await _loadReport(
      showLoader: false,
    );
  }

  // ===========================================================================
  // DATE
  // ===========================================================================

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
          _startDate != null &&
                  _endDate != null
              ? DateTimeRange(
                  start: _startDate!,
                  end: _endDate!,
                )
              : DateTimeRange(
                  start: DateTime(
                    now.year,
                    now.month,
                    1,
                  ),
                  end: now,
                ),
      helpText: 'Select Expense Report Period',
      saveText: 'Apply',
    );

    if (selected == null) return;

    setState(() {
      _startDate = DateTime(
        selected.start.year,
        selected.start.month,
        selected.start.day,
      );

      _endDate = DateTime(
        selected.end.year,
        selected.end.month,
        selected.end.day,
        23,
        59,
        59,
        999,
      );
    });
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  // ===========================================================================
  // FILTER
  // ===========================================================================

  List<ExpenseModel> get _filteredExpenses {
    final String query =
        _searchQuery.trim().toLowerCase();

    final List<ExpenseModel> result =
        _allExpenses.where((expense) {
      if (_startDate != null &&
          expense.date.isBefore(_startDate!)) {
        return false;
      }

      if (_endDate != null &&
          expense.date.isAfter(_endDate!)) {
        return false;
      }

      if (_categoryFilter != 'All' &&
          expense.category.toLowerCase() !=
              _categoryFilter.toLowerCase()) {
        return false;
      }

      if (_paymentMethodFilter != 'All' &&
          expense.paymentMethod
                  .toLowerCase() !=
              _paymentMethodFilter
                  .toLowerCase()) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return expense.category
              .toLowerCase()
              .contains(query) ||
          expense.description
              .toLowerCase()
              .contains(query) ||
          expense.notes
              .toLowerCase()
              .contains(query) ||
          expense.paymentMethod
              .toLowerCase()
              .contains(query);
    }).toList();

    result.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return result;
  }

  // ===========================================================================
  // CALCULATIONS
  // ===========================================================================

  double _totalExpenses(
    List<ExpenseModel> expenses,
  ) {
    return expenses.fold(
      0,
      (sum, expense) =>
          sum + expense.amount,
    );
  }

  double _todayExpenses(
    List<ExpenseModel> expenses,
  ) {
    final DateTime now = DateTime.now();

    return expenses
        .where(
          (expense) =>
              expense.date.year ==
                  now.year &&
              expense.date.month ==
                  now.month &&
              expense.date.day ==
                  now.day,
        )
        .fold(
          0,
          (sum, expense) =>
              sum + expense.amount,
        );
  }

  double _averageExpense(
    List<ExpenseModel> expenses,
  ) {
    if (expenses.isEmpty) return 0;

    return _totalExpenses(expenses) /
        expenses.length;
  }

  Map<String, double> _categoryTotals(
    List<ExpenseModel> expenses,
  ) {
    final Map<String, double> result =
        <String, double>{};

    for (final expense in expenses) {
      final String category =
          expense.category.trim().isEmpty
              ? 'Other'
              : expense.category.trim();

      result[category] =
          (result[category] ?? 0) +
              expense.amount;
    }

    return result;
  }

  Map<String, int> _categoryCounts(
    List<ExpenseModel> expenses,
  ) {
    final Map<String, int> result =
        <String, int>{};

    for (final expense in expenses) {
      final String category =
          expense.category.trim().isEmpty
              ? 'Other'
              : expense.category.trim();

      result[category] =
          (result[category] ?? 0) + 1;
    }

    return result;
  }

  Map<String, double> _paymentMethodTotals(
    List<ExpenseModel> expenses,
  ) {
    final Map<String, double> result =
        <String, double>{};

    for (final expense in expenses) {
      final String method =
          expense.paymentMethod.trim().isEmpty
              ? 'Other'
              : expense.paymentMethod.trim();

      result[method] =
          (result[method] ?? 0) +
              expense.amount;
    }

    return result;
  }

  List<String> get _availableCategories {
    final Set<String> categories =
        <String>{};

    for (final expense in _allExpenses) {
      final String category =
          expense.category.trim();

      if (category.isNotEmpty) {
        categories.add(category);
      }
    }

    final List<String> result =
        categories.toList();

    result.sort();

    return result;
  }

  List<String> get _availablePaymentMethods {
    final Set<String> methods =
        <String>{};

    for (final expense in _allExpenses) {
      final String method =
          expense.paymentMethod.trim();

      if (method.isNotEmpty) {
        methods.add(method);
      }
    }

    final List<String> result =
        methods.toList();

    result.sort();

    return result;
  }

  // ===========================================================================
  // FORMAT
  // ===========================================================================

  String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  String _date(DateTime date) {
    return DateFormat(
      'dd MMM yyyy',
    ).format(date);
  }

  String _dateRangeText() {
    if (_startDate == null ||
        _endDate == null) {
      return 'All Dates';
    }

    return '${DateFormat('dd MMM yyyy').format(_startDate!)}'
        ' → '
        '${DateFormat('dd MMM yyyy').format(_endDate!)}';
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

    final List<ExpenseModel> expenses =
        _filteredExpenses;

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
                    _buildDateFilter(theme),
                    const SizedBox(height: 20),
                    _buildSummaryCards(
                      theme,
                      expenses,
                      isDesktop,
                    ),
                    const SizedBox(height: 20),
                    _buildFilters(theme),
                    const SizedBox(height: 20),
                    _buildCategorySection(
                      theme,
                      expenses,
                    ),
                    const SizedBox(height: 20),
                    _buildPaymentMethodSection(
                      theme,
                      expenses,
                    ),
                    const SizedBox(height: 20),
                    _buildExpenseList(
                      theme,
                      expenses,
                    ),
                    const SizedBox(height: 20),
                    _buildFooter(
                      theme,
                      expenses,
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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.danger,
            AppColors.warning,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color:
                  Colors.white.withValues(
                alpha: 0.15,
              ),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expense Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Track business expenses, categories and payment methods.',
                  style: TextStyle(
                    color:
                        Colors.white.withValues(
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
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white.withValues(
                      alpha: 0.14,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      30,
                    ),
                  ),
                  child: Text(
                    _dateRangeText(),
                    style:
                        const TextStyle(
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
              onPressed:
                  _refreshing
                      ? null
                      : _refreshReport,
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                            Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color:
                          Colors.white,
                    ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DATE
  // ===========================================================================

  Widget _buildDateFilter(
    ThemeData theme,
  ) {
    final bool hasFilter =
        _startDate != null &&
            _endDate != null;

    return _ReportCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment:
            WrapCrossAlignment.center,
        children: [
          const Icon(
            Icons.date_range_rounded,
            size: 21,
          ),
          Text(
            'Report Period',
            style:
                theme.textTheme.titleMedium
                    ?.copyWith(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: theme
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Text(
              _dateRangeText(),
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed:
                _selectDateRange,
            icon: const Icon(
              Icons.calendar_month_rounded,
              size: 18,
            ),
            label: Text(
              hasFilter
                  ? 'Change Period'
                  : 'Select Period',
            ),
          ),
          if (hasFilter)
            OutlinedButton.icon(
              onPressed:
                  _clearDateFilter,
              icon: const Icon(
                Icons.clear_rounded,
                size: 18,
              ),
              label:
                  const Text('Clear'),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummaryCards(
    ThemeData theme,
    List<ExpenseModel> expenses,
    bool isDesktop,
  ) {
    final List<_SummaryItem> items = [
      _SummaryItem(
        title: 'Total Expenses',
        value: _currency(
          _totalExpenses(expenses),
        ),
        subtitle:
            '${expenses.length} expense${expenses.length == 1 ? '' : 's'}',
        icon:
            Icons.account_balance_wallet_rounded,
        color: AppColors.danger,
      ),
      _SummaryItem(
        title: 'Today',
        value: _currency(
          _todayExpenses(expenses),
        ),
        subtitle:
            'Today\'s expense',
        icon:
            Icons.today_rounded,
        color: AppColors.warning,
      ),
      _SummaryItem(
        title: 'Average Expense',
        value: _currency(
          _averageExpense(expenses),
        ),
        subtitle:
            'Per transaction',
        icon:
            Icons.analytics_rounded,
        color: AppColors.primary,
      ),
      _SummaryItem(
        title: 'Categories',
        value: _categoryTotals(
          expenses,
        ).length.toString(),
        subtitle:
            'Expense categories',
        icon:
            Icons.category_rounded,
        color: AppColors.secondary,
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
            isDesktop ? 1.9 : 1.45,
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
          TextField(
            controller:
                _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery =
                    value.trim().toLowerCase();
              });
            },
            decoration:
                InputDecoration(
              hintText:
                  'Search category, description, payment method or notes...',
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
          ),
          const SizedBox(height: 16),
          Text(
            'Category',
            style: theme
                .textTheme
                .labelLarge
                ?.copyWith(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _buildHorizontalChips(
            values: [
              'All',
              ..._availableCategories,
            ],
            selected:
                _categoryFilter,
            onSelected: (value) {
              setState(() {
                _categoryFilter =
                    value;
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Payment Method',
            style: theme
                .textTheme
                .labelLarge
                ?.copyWith(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _buildHorizontalChips(
            values: [
              'All',
              ..._availablePaymentMethods,
            ],
            selected:
                _paymentMethodFilter,
            onSelected: (value) {
              setState(() {
                _paymentMethodFilter =
                    value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalChips({
    required List<String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map(
        (value) {
          final bool isSelected =
              selected == value;

          return ChoiceChip(
            label: Text(value),
            selected: isSelected,
            onSelected: (_) =>
                onSelected(value),
            selectedColor:
                AppColors.primary
                    .withValues(
              alpha: 0.13,
            ),
            side: BorderSide(
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(context)
                      .colorScheme
                      .outlineVariant,
            ),
            labelStyle: TextStyle(
              color: isSelected
                  ? AppColors.primary
                  : null,
              fontWeight: isSelected
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          );
        },
      ).toList(),
    );
  }

  // ===========================================================================
  // CATEGORY
  // ===========================================================================

  Widget _buildCategorySection(
    ThemeData theme,
    List<ExpenseModel> expenses,
  ) {
    final Map<String, double> totals =
        _categoryTotals(expenses);

    final Map<String, int> counts =
        _categoryCounts(expenses);

    final List<MapEntry<String, double>>
        entries =
        totals.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(a.value),
          );

    final double total =
        _totalExpenses(expenses);

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.category_rounded,
            title:
                'Category-wise Expenses',
            subtitle:
                'See where your business money is being spent',
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.category_outlined,
              message:
                  'No expense categories available.',
            )
          else
            ...entries.map(
              (entry) {
                final double percentage =
                    total > 0
                        ? (entry.value /
                                total) *
                            100
                        : 0;

                return _CategoryTile(
                  category:
                      entry.key,
                  amount:
                      entry.value,
                  percentage:
                      percentage,
                  count:
                      counts[entry.key] ??
                          0,
                  currency:
                      _currency,
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAYMENT METHOD
  // ===========================================================================

  Widget _buildPaymentMethodSection(
    ThemeData theme,
    List<ExpenseModel> expenses,
  ) {
    final Map<String, double> totals =
        _paymentMethodTotals(expenses);

    final List<MapEntry<String, double>>
        entries =
        totals.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(a.value),
          );

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.payments_rounded,
            title:
                'Payment Method Analysis',
            subtitle:
                'Expense amount by payment method',
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.payments_outlined,
              message:
                  'No payment method data available.',
            )
          else
            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final bool wide =
                    constraints.maxWidth >=
                        650;

                if (!wide) {
                  return Column(
                    children:
                        entries.map(
                      (entry) {
                        return _PaymentMethodTile(
                          method:
                              entry.key,
                          amount:
                              entry.value,
                          currency:
                              _currency,
                        );
                      },
                    ).toList(),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount:
                      entries.length,
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        constraints.maxWidth >=
                                1000
                            ? 3
                            : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio:
                        2.7,
                  ),
                  itemBuilder: (
                    context,
                    index,
                  ) {
                    final entry =
                        entries[index];

                    return _PaymentMethodTile(
                      method: entry.key,
                      amount:
                          entry.value,
                      currency:
                          _currency,
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
  // EXPENSE LIST
  // ===========================================================================

  Widget _buildExpenseList(
    ThemeData theme,
    List<ExpenseModel> expenses,
  ) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:
                Icons.receipt_long_rounded,
            title:
                'Expense-wise Details',
            subtitle:
                '${expenses.length} matching expense${expenses.length == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 18),
          if (expenses.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.receipt_long_outlined,
              message:
                  'No expenses found for the selected filters.',
            )
          else
            ...expenses.map(
              (expense) {
                return _ExpenseTile(
                  expense: expense,
                  currency: _currency,
                  date: _date,
                  onTap: () {
                    _showExpenseDetails(
                      expense,
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
  // DETAILS
  // ===========================================================================

  void _showExpenseDetails(
    ExpenseModel expense,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final ThemeData theme =
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
                  Text(
                    'Expense Details',
                    style: theme
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _date(expense.date),
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
                  _DetailRow(
                    label: 'Category',
                    value:
                        expense.category,
                  ),
                  _DetailRow(
                    label: 'Amount',
                    value:
                        _currency(
                      expense.amount,
                    ),
                    bold: true,
                    valueColor:
                        AppColors.danger,
                  ),
                  _DetailRow(
                    label:
                        'Payment Method',
                    value:
                        expense.paymentMethod,
                  ),
                  if (expense.description
                      .trim()
                      .isNotEmpty)
                    _DetailRow(
                      label:
                          'Description',
                      value:
                          expense.description,
                    ),
                  if (expense.notes
                      .trim()
                      .isNotEmpty)
                    _DetailRow(
                      label: 'Notes',
                      value:
                          expense.notes,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // FOOTER
  // ===========================================================================

  Widget _buildFooter(
    ThemeData theme,
    List<ExpenseModel> expenses,
  ) {
    final Map<String, double> categoryTotals =
        _categoryTotals(expenses);

    final String topCategory =
        categoryTotals.isEmpty
            ? '—'
            : (categoryTotals.entries.toList()
                  ..sort(
                    (a, b) =>
                        b.value.compareTo(
                      a.value,
                    ),
                  ))
                .first
                .key;

    return _ReportCard(
      child: Wrap(
        spacing: 24,
        runSpacing: 14,
        children: [
          _FooterMetric(
            label: 'Expenses',
            value:
                expenses.length.toString(),
          ),
          _FooterMetric(
            label: 'Total',
            value: _currency(
              _totalExpenses(expenses),
            ),
          ),
          _FooterMetric(
            label: 'Average',
            value: _currency(
              _averageExpense(expenses),
            ),
          ),
          _FooterMetric(
            label: 'Top Category',
            value: topCategory,
          ),
        ],
      ),
    );
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
                    color:
                        AppColors.danger
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
                  'Unable to load Expense Report',
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
                      const Text(
                    'Try Again',
                  ),
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
// DATA
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

class _ReportCard extends StatelessWidget {
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
          color:
              item.color.withValues(
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
// CATEGORY TILE
// =============================================================================

class _CategoryTile
    extends StatelessWidget {
  final String category;
  final double amount;
  final double percentage;
  final int count;
  final String Function(double) currency;

  const _CategoryTile({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.count,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
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
          alpha: 0.42,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration:
                          BoxDecoration(
                        color:
                            AppColors.danger
                                .withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      child: const Icon(
                        Icons.category_rounded,
                        color:
                            AppColors.danger,
                        size: 20,
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        category,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style: theme
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    currency(amount),
                    style: theme
                        .textTheme
                        .bodyLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    '$count transaction${count == 1 ? '' : 's'}',
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
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value:
                  (percentage / 100)
                      .clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: theme
                  .colorScheme
                  .outlineVariant
                  .withValues(
                alpha: 0.35,
              ),
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                AppColors.danger,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Align(
            alignment:
                Alignment.centerRight,
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color:
                    AppColors.danger,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PAYMENT METHOD TILE
// =============================================================================

class _PaymentMethodTile
    extends StatelessWidget {
  final String method;
  final double amount;
  final String Function(double) currency;

  const _PaymentMethodTile({
    required this.method,
    required this.amount,
    required this.currency,
  });

  IconData _icon() {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money_rounded;
      case 'upi':
        return Icons.qr_code_rounded;
      case 'bank transfer':
      case 'bank':
        return Icons.account_balance_rounded;
      case 'cheque':
        return Icons.receipt_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.42,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color:
                  AppColors.primary
                      .withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: Icon(
              _icon(),
              color:
                  AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(
            width: 11,
          ),
          Expanded(
            child: Text(
              method,
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
          ),
          Text(
            currency(amount),
            style: theme
                .textTheme
                .bodyMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EXPENSE TILE
// =============================================================================

class _ExpenseTile
    extends StatelessWidget {
  final ExpenseModel expense;
  final String Function(double) currency;
  final String Function(DateTime) date;
  final VoidCallback onTap;

  const _ExpenseTile({
    required this.expense,
    required this.currency,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

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
          border: Border.all(
            color: theme
                .colorScheme
                .outlineVariant
                .withValues(
              alpha: 0.35,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(
                color:
                    AppColors.danger
                        .withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color:
                    AppColors.danger,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    expense.category
                            .trim()
                            .isEmpty
                        ? 'Other'
                        : expense.category,
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
                  const SizedBox(height: 4),
                  if (expense.description
                      .trim()
                      .isNotEmpty)
                    Text(
                      expense.description,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .bodySmall,
                    ),
                  const SizedBox(height: 3),
                  Text(
                    '${date(expense.date)} • ${expense.paymentMethod}',
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
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  currency(
                    expense.amount,
                  ),
                  style: theme
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                    color:
                        AppColors.danger,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
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
  final bool bold;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
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
                color: valueColor,
                fontWeight:
                    bold
                        ? FontWeight.w800
                        : FontWeight.w600,
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

// =============================================================================
// FOOTER
// =============================================================================

class _FooterMetric
    extends StatelessWidget {
  final String label;
  final String value;

  const _FooterMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: theme
              .textTheme
              .bodySmall
              ?.copyWith(
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme
              .textTheme
              .bodySmall
              ?.copyWith(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }
}