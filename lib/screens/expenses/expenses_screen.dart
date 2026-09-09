import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/expense_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/expense_repository.dart';
import 'add_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
  });

  @override
  State<ExpensesScreen> createState() =>
      _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final ExpenseRepository _expenseRepository =
      ExpenseRepository();

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

  BusinessModel? _business;

  StreamSubscription<List<ExpenseModel>>?
      _expenseSubscription;

  List<ExpenseModel> _expenses = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';

  String _categoryFilter = 'All';
  String _paymentMethodFilter = 'All';

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
    _expenseSubscription?.cancel();
    _searchController
        .removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final business =
          await _businessRepository
              .getBusinessForCurrentUser();

      if (!mounted) {
        return;
      }

      if (business == null) {
        setState(() {
          _business = null;
          _isLoading = false;
          _errorMessage =
              'Business profile not found.';
        });
        return;
      }

      _expenseSubscription?.cancel();

      _expenseSubscription =
          _expenseRepository
              .watchExpenses(
        businessId: business.id,
      )
              .listen(
        (expenses) {
          if (!mounted) {
            return;
          }

          setState(() {
            _business = business;
            _expenses = expenses;
            _isLoading = false;
            _errorMessage = null;
          });
        },
        onError: (Object error) {
          if (!mounted) {
            return;
          }

          setState(() {
            _isLoading = false;
            _errorMessage =
                'Unable to load expenses.';
          });
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load business information.';
      });
    }
  }

  void _onSearchChanged() {
    final query =
        _searchController.text.trim();

    if (_searchQuery == query) {
      return;
    }

    setState(() {
      _searchQuery = query;
    });
  }

  List<ExpenseModel> get _filteredExpenses {
    final query =
        _searchQuery.toLowerCase();

    return _expenses.where(
      (expense) {
        final matchesSearch =
            query.isEmpty ||
                expense.category
                    .toLowerCase()
                    .contains(query) ||
                expense.description
                    .toLowerCase()
                    .contains(query) ||
                expense.paymentMethod
                    .toLowerCase()
                    .contains(query) ||
                expense.notes
                    .toLowerCase()
                    .contains(query);

        final matchesCategory =
            _categoryFilter == 'All' ||
                expense.category
                        .trim()
                        .toLowerCase() ==
                    _categoryFilter
                        .trim()
                        .toLowerCase();

        final matchesPaymentMethod =
            _paymentMethodFilter == 'All' ||
                expense.paymentMethod
                        .trim()
                        .toLowerCase() ==
                    _paymentMethodFilter
                        .trim()
                        .toLowerCase();

        return matchesSearch &&
            matchesCategory &&
            matchesPaymentMethod;
      },
    ).toList();
  }

  List<String> get _categories {
    final values = _expenses
        .map(
          (expense) =>
              expense.category.trim(),
        )
        .where(
          (category) =>
              category.isNotEmpty,
        )
        .toSet()
        .toList();

    values.sort();

    return [
      'All',
      ...values,
    ];
  }

  List<String> get _paymentMethods {
    final values = _expenses
        .map(
          (expense) =>
              expense.paymentMethod.trim(),
        )
        .where(
          (method) =>
              method.isNotEmpty,
        )
        .toSet()
        .toList();

    values.sort();

    return [
      'All',
      ...values,
    ];
  }

  double get _totalExpenses {
    return _filteredExpenses.fold<double>(
      0,
      (total, expense) =>
          total + expense.amount,
    );
  }

  double get _todayTotal {
    final now = DateTime.now();

    return _expenses
        .where(
          (expense) =>
              expense.date.year ==
                  now.year &&
              expense.date.month ==
                  now.month &&
              expense.date.day ==
                  now.day,
        )
        .fold<double>(
          0,
          (total, expense) =>
              total + expense.amount,
        );
  }

  double get _monthlyTotal {
    final now = DateTime.now();

    return _expenses
        .where(
          (expense) =>
              expense.date.year ==
                  now.year &&
              expense.date.month ==
                  now.month,
        )
        .fold<double>(
          0,
          (total, expense) =>
              total + expense.amount,
        );
  }

  Future<void> _openAddExpense() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AddExpenseScreen(),
      ),
    );

    if (result == true && mounted) {
      _showMessage(
        'Expense saved successfully.',
      );
    }
  }

  Future<void> _deleteExpense(
    ExpenseModel expense,
  ) async {
    final shouldDelete =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Expense?',
          ),
          content: Text(
            'Are you sure you want to delete this ${expense.category} expense of ${_currencyFormat.format(expense.amount)}?',
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

    if (shouldDelete != true ||
        _business == null) {
      return;
    }

    try {
      await _expenseRepository
          .deleteExpense(
        businessId: _business!.id,
        expenseId: expense.id,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Expense deleted successfully.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to delete expense.',
        isError: true,
      );
    }
  }

  void _showExpenseDetails(
    ExpenseModel expense,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
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
                        color: AppColors
                            .danger
                            .withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                      child: const Icon(
                        Icons
                            .receipt_long_rounded,
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
                            expense.category,
                            style: Theme.of(
                              context,
                            )
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            _dateFormat
                                .format(
                              expense.date,
                            ),
                            style:
                                Theme.of(
                              context,
                            )
                                    .textTheme
                                    .bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _currencyFormat
                          .format(
                        expense.amount,
                      ),
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            color:
                                AppColors
                                    .danger,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 22,
                ),
                _detailRow(
                  'Payment Method',
                  expense.paymentMethod,
                  Icons
                      .account_balance_wallet_outlined,
                ),
                if (expense.description
                    .trim()
                    .isNotEmpty)
                  _detailRow(
                    'Description',
                    expense.description,
                    Icons
                        .description_outlined,
                  ),
                if (expense.notes
                    .trim()
                    .isNotEmpty)
                  _detailRow(
                    'Notes',
                    expense.notes,
                    Icons.notes_outlined,
                  ),
                if (expense.receiptUrl
                    .trim()
                    .isNotEmpty)
                  _detailRow(
                    'Receipt',
                    expense.receiptUrl,
                    Icons
                        .attach_file_rounded,
                  ),
                const SizedBox(
                  height: 14,
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
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
                      color:
                          AppColors.danger,
                    ),
                    label: const Text(
                      'Delete Expense',
                    ),
                    style: OutlinedButton
                        .styleFrom(
                      foregroundColor:
                          AppColors.danger,
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

  Widget _detailRow(
    String title,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color:
                AppColors.primary,
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
                  title,
                  style: Theme.of(
                    context,
                  )
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  )
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

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
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

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
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
                alpha: 0.55,
              ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(
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
              size: 21,
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
                  title,
                  style: Theme.of(
                    context,
                  )
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  )
                      .textTheme
                      .titleMedium
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
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding:
          const EdgeInsets.all(14),
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
                alpha: 0.55,
              ),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller:
                _searchController,
            decoration:
                InputDecoration(
              hintText:
                  'Search expenses...',
              prefixIcon:
                  const Icon(
                Icons.search_rounded,
              ),
              suffixIcon:
                  _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController
                                .clear();
                          },
                          icon:
                              const Icon(
                            Icons
                                .clear_rounded,
                          ),
                        ),
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              final compact =
                  constraints.maxWidth <
                      550;

              if (compact) {
                return Column(
                  children: [
                    _buildFilter(
                      label: 'Category',
                      value:
                          _categoryFilter,
                      values: _categories,
                      onChanged:
                          (value) {
                        setState(() {
                          _categoryFilter =
                              value ??
                                  'All';
                        });
                      },
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    _buildFilter(
                      label:
                          'Payment Method',
                      value:
                          _paymentMethodFilter,
                      values:
                          _paymentMethods,
                      onChanged:
                          (value) {
                        setState(() {
                          _paymentMethodFilter =
                              value ??
                                  'All';
                        });
                      },
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child:
                        _buildFilter(
                      label: 'Category',
                      value:
                          _categoryFilter,
                      values: _categories,
                      onChanged:
                          (value) {
                        setState(() {
                          _categoryFilter =
                              value ??
                                  'All';
                        });
                      },
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child:
                        _buildFilter(
                      label:
                          'Payment Method',
                      value:
                          _paymentMethodFilter,
                      values:
                          _paymentMethods,
                      onChanged:
                          (value) {
                        setState(() {
                          _paymentMethodFilter =
                              value ??
                                  'All';
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilter({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String?>
        onChanged,
  }) {
    return DropdownButtonFormField<
        String>(
      initialValue:
          values.contains(value)
              ? value
              : 'All',
      isExpanded: true,
      decoration:
          InputDecoration(
        labelText: label,
        prefixIcon:
            const Icon(
          Icons.filter_alt_outlined,
        ),
      ),
      items: values.map(
        (item) {
          return DropdownMenuItem<
              String>(
            value: item,
            child: Text(
              item,
              overflow:
                  TextOverflow.ellipsis,
            ),
          );
        },
      ).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildExpenseItem(
    ExpenseModel expense,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: InkWell(
        onTap: () {
          _showExpenseDetails(
            expense,
          );
        },
        borderRadius:
            BorderRadius.circular(16),
        child: Padding(
          padding:
              const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color: AppColors.danger
                      .withValues(
                    alpha: 0.09,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: const Icon(
                  Icons
                      .receipt_long_rounded,
                  color:
                      AppColors.danger,
                  size: 21,
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
                      expense.category,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      expense.description
                              .trim()
                              .isEmpty
                          ? expense
                              .paymentMethod
                          : expense
                              .description,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .bodySmall,
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      _dateFormat.format(
                        expense.date,
                      ),
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            fontSize: 11,
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
                    _currencyFormat
                        .format(
                      expense.amount,
                    ),
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .titleSmall
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
                    height: 5,
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
                          .primary
                          .withValues(
                        alpha: 0.08,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        7,
                      ),
                    ),
                    child: Text(
                      expense
                          .paymentMethod,
                      style: const TextStyle(
                        color:
                            AppColors
                                .primary,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                width: 4,
              ),
              const Icon(
                Icons
                    .chevron_right_rounded,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters =
        _searchQuery.isNotEmpty ||
            _categoryFilter != 'All' ||
            _paymentMethodFilter !=
                'All';

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration:
                  BoxDecoration(
                color: AppColors.primary
                    .withValues(
                  alpha: 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters
                    ? Icons
                        .search_off_rounded
                    : Icons
                        .receipt_long_outlined,
                size: 34,
                color:
                    AppColors.primary,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            Text(
              hasFilters
                  ? 'No expenses found'
                  : 'No expenses yet',
              style: Theme.of(
                context,
              )
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
              hasFilters
                  ? 'Try changing your search or filters.'
                  : 'Record your first business expense to see it here.',
              textAlign:
                  TextAlign.center,
              style: Theme.of(
                context,
              )
                  .textTheme
                  .bodyMedium,
            ),
            if (!hasFilters) ...[
              const SizedBox(
                height: 18,
              ),
              FilledButton.icon(
                onPressed:
                    _openAddExpense,
                icon: const Icon(
                  Icons
                      .add_rounded,
                ),
                label: const Text(
                  'ADD EXPENSE',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .cloud_off_rounded,
                size: 56,
                color:
                    AppColors.danger,
              ),
              const SizedBox(
                height: 16,
              ),
              Text(
                _errorMessage!,
                textAlign:
                    TextAlign.center,
                style: Theme.of(
                  context,
                )
                    .textTheme
                    .titleMedium,
              ),
              const SizedBox(
                height: 16,
              ),
              FilledButton.icon(
                onPressed:
                    _loadBusiness,
                icon: const Icon(
                  Icons
                      .refresh_rounded,
                ),
                label: const Text(
                  'RETRY',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final isDesktop =
            constraints.maxWidth >=
                1000;

        return SingleChildScrollView(
          padding:
              EdgeInsets.fromLTRB(
            isDesktop ? 28 : 16,
            16,
            isDesktop ? 28 : 16,
            30,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 1250,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  _buildHeader(),
                  const SizedBox(
                    height: 16,
                  ),
                  LayoutBuilder(
                    builder: (
                      context,
                      summaryConstraints,
                    ) {
                      final compact =
                          summaryConstraints
                                  .maxWidth <
                              650;

                      if (compact) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child:
                                      _buildSummaryCard(
                                    title:
                                        'Total Expenses',
                                    value:
                                        _currencyFormat.format(
                                      _totalExpenses,
                                    ),
                                    icon:
                                        Icons
                                            .account_balance_wallet_rounded,
                                    color:
                                        AppColors.danger,
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child:
                                      _buildSummaryCard(
                                    title:
                                        'Today',
                                    value:
                                        _currencyFormat.format(
                                      _todayTotal,
                                    ),
                                    icon:
                                        Icons
                                            .today_rounded,
                                    color:
                                        AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            _buildSummaryCard(
                              title:
                                  'This Month',
                              value:
                                  _currencyFormat.format(
                                _monthlyTotal,
                              ),
                              icon:
                                  Icons
                                      .calendar_month_rounded,
                              color:
                                  AppColors.primary,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child:
                                _buildSummaryCard(
                              title:
                                  'Total Expenses',
                              value:
                                  _currencyFormat.format(
                                _totalExpenses,
                              ),
                              icon:
                                  Icons
                                      .account_balance_wallet_rounded,
                              color:
                                  AppColors.danger,
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child:
                                _buildSummaryCard(
                              title:
                                  'Today',
                              value:
                                  _currencyFormat.format(
                                _todayTotal,
                              ),
                              icon:
                                  Icons
                                      .today_rounded,
                              color:
                                  AppColors.warning,
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child:
                                _buildSummaryCard(
                              title:
                                  'This Month',
                              value:
                                  _currencyFormat.format(
                                _monthlyTotal,
                              ),
                              icon:
                                  Icons
                                      .calendar_month_rounded,
                              color:
                                  AppColors.primary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  _buildSearchAndFilters(),
                  const SizedBox(
                    height: 18,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Expenses',
                          style: Theme.of(
                            context,
                          )
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                        ),
                      ),
                      Text(
                        '${_filteredExpenses.length} records',
                        style: Theme.of(
                          context,
                        )
                            .textTheme
                            .bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  if (_filteredExpenses
                      .isEmpty)
                    SizedBox(
                      height: 320,
                      child:
                          _buildEmptyState(),
                    )
                  else
                    ..._filteredExpenses
                        .map(
                          _buildExpenseItem,
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Expenses',
                style: Theme.of(context)
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
                'Track and manage your business expenses.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(
          width: 10,
        ),
        FilledButton.icon(
          onPressed:
              _openAddExpense,
          icon: const Icon(
            Icons.add_rounded,
          ),
          label: const Text(
            'ADD EXPENSE',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expenses',
          style: TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),
      floatingActionButton:
          MediaQuery.sizeOf(context)
                      .width <
                  600
              ? FloatingActionButton.extended(
                  onPressed:
                      _openAddExpense,
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                  label: const Text(
                    'Add Expense',
                  ),
                )
              : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : _buildContent(),
      ),
    );
  }
}
