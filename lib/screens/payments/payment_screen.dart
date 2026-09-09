import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import 'add_payment_screen.dart';
import '../../models/business_model.dart';
import '../../models/payment_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/payment_repository.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({
    super.key,
  });

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final PaymentRepository _paymentRepository =
      PaymentRepository();

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

  bool _isLoadingBusiness = true;
  String? _businessError;

  String _searchQuery = '';
  String _selectedPaymentMethod = 'All';
  DateTimeRange? _selectedDateRange;

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
    _loadBusiness();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    setState(() {
      _isLoadingBusiness = true;
      _businessError = null;
    });

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
          _businessError =
              'Business profile not found.';
          _isLoadingBusiness = false;
        });
        return;
      }

      setState(() {
        _business = business;
        _isLoadingBusiness = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _businessError =
            'Unable to load business details.';
        _isLoadingBusiness = false;
      });
    }
  }

  List<PaymentModel> _filterPayments(
    List<PaymentModel> payments,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    return payments.where((payment) {
      if (query.isNotEmpty) {
        final customerName =
            payment.customerName.toLowerCase();

        final method =
            payment.paymentMethod.toLowerCase();

        final reference =
            payment.transactionReference
                .toLowerCase();

        final notes =
            payment.notes.toLowerCase();

        final amount =
            payment.amount.toStringAsFixed(2);

        final matchesSearch =
            customerName.contains(query) ||
                method.contains(query) ||
                reference.contains(query) ||
                notes.contains(query) ||
                amount.contains(query);

        if (!matchesSearch) {
          return false;
        }
      }

      if (_selectedPaymentMethod != 'All' &&
          payment.paymentMethod !=
              _selectedPaymentMethod) {
        return false;
      }

      if (_selectedDateRange != null) {
        final date = payment.date;

        final start = DateTime(
          _selectedDateRange!.start.year,
          _selectedDateRange!.start.month,
          _selectedDateRange!.start.day,
        );

        final end = DateTime(
          _selectedDateRange!.end.year,
          _selectedDateRange!.end.month,
          _selectedDateRange!.end.day,
          23,
          59,
          59,
          999,
        );

        if (date.isBefore(start) ||
            date.isAfter(end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  double _calculateTotal(
    List<PaymentModel> payments,
  ) {
    return payments.fold<double>(
      0,
      (total, payment) =>
          total + payment.amount,
    );
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();

    final selected =
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
      builder: (context, child) {
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
          child: child!,
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

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedPaymentMethod = 'All';
      _selectedDateRange = null;
    });
  }

  Future<void> _openAddPayment() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddPaymentScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _deletePayment(
    PaymentModel payment,
  ) async {
    final shouldDelete =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Payment?',
          ),
          content: Text(
            'Are you sure you want to delete this payment of '
            '${_currencyFormat.format(payment.amount)} '
            'received from ${payment.customerName}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('CANCEL'),
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
              child: const Text('DELETE'),
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
      await _paymentRepository.deletePayment(
        businessId: payment.businessId,
        paymentId: payment.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Payment deleted successfully.',
          ),
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
            'Failed to delete payment: $e',
          ),
          backgroundColor:
              AppColors.danger,
        ),
      );
    }
  }

  void _showPaymentDetails(
    PaymentModel payment,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surface,
              borderRadius:
                  BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.success
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                        child: const Icon(
                          Icons
                              .payments_rounded,
                          color:
                              AppColors.success,
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
                              'Payment Details',
                              style: Theme.of(
                                context,
                              )
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                  ),
                            ),
                            const SizedBox(
                              height: 2,
                            ),
                            Text(
                              _dateFormat.format(
                                payment.date,
                              ),
                              style: Theme.of(
                                context,
                              )
                                  .textTheme
                                  .bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(
                            context,
                          );
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _detailTile(
                    context,
                    icon: Icons
                        .person_rounded,
                    label: 'Customer',
                    value:
                        payment.customerName
                                .trim()
                                .isEmpty
                            ? 'Unknown Customer'
                            : payment.customerName,
                  ),
                  _detailTile(
                    context,
                    icon: Icons
                        .currency_rupee_rounded,
                    label: 'Amount',
                    value:
                        _currencyFormat.format(
                      payment.amount,
                    ),
                    valueColor:
                        AppColors.success,
                  ),
                  _detailTile(
                    context,
                    icon: Icons
                        .account_balance_wallet_rounded,
                    label: 'Payment Method',
                    value:
                        payment.paymentMethod,
                  ),
                  _detailTile(
                    context,
                    icon: Icons
                        .calendar_today_rounded,
                    label: 'Payment Date',
                    value:
                        _dateFormat.format(
                      payment.date,
                    ),
                  ),
                  if (payment
                      .transactionReference
                      .trim()
                      .isNotEmpty)
                    _detailTile(
                      context,
                      icon: Icons
                          .receipt_long_rounded,
                      label:
                          'Transaction Reference',
                      value: payment
                          .transactionReference,
                    ),
                  if (payment.notes
                      .trim()
                      .isNotEmpty)
                    _detailTile(
                      context,
                      icon: Icons
                          .notes_rounded,
                      label: 'Notes',
                      value:
                          payment.notes,
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                        _deletePayment(
                          payment,
                        );
                      },
                      icon: const Icon(
                        Icons
                            .delete_outline_rounded,
                      ),
                      label: const Text(
                        'DELETE PAYMENT',
                      ),
                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor:
                            AppColors.danger,
                        side: const BorderSide(
                          color:
                              AppColors.danger,
                        ),
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(13),
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
                const SizedBox(height: 3),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBusiness) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_businessError != null ||
        _business == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Payments'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Icon(
                  Icons
                      .business_center_outlined,
                  size: 56,
                  color:
                      AppColors.warning,
                ),
                const SizedBox(height: 16),
                Text(
                  _businessError ??
                      'Business profile not found.',
                  textAlign:
                      TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadBusiness,
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

    return StreamBuilder<
        List<PaymentModel>>(
      stream:
          _paymentRepository.watchPayments(
        businessId: _business!.id,
      ),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return _buildErrorState(
            snapshot.error.toString(),
          );
        }

        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        final allPayments =
            snapshot.data ?? <PaymentModel>[];

        final filteredPayments =
            _filterPayments(
          allPayments,
        );

        final totalReceived =
            _calculateTotal(
          allPayments,
        );

        final filteredTotal =
            _calculateTotal(
          filteredPayments,
        );

        return _buildScreen(
          allPayments: allPayments,
          filteredPayments:
              filteredPayments,
          totalReceived: totalReceived,
          filteredTotal: filteredTotal,
        );
      },
    );
  }

  Widget _buildScreen({
    required List<PaymentModel> allPayments,
    required List<PaymentModel>
        filteredPayments,
    required double totalReceived,
    required double filteredTotal,
  }) {
    final hasFilters =
        _searchQuery.isNotEmpty ||
            _selectedPaymentMethod !=
                'All' ||
            _selectedDateRange != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payments',
        ),
        actions: [
          if (hasFilters)
            IconButton(
              tooltip: 'Clear filters',
              onPressed: _clearFilters,
              icon: const Icon(
                Icons.filter_alt_off_rounded,
              ),
            ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _openAddPayment,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'ADD PAYMENT',
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final isDesktop =
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
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    100,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      _buildHeader(
                        allPayments.length,
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      _buildSummaryCards(
                        totalReceived:
                            totalReceived,
                        filteredTotal:
                            filteredTotal,
                        filteredCount:
                            filteredPayments
                                .length,
                        totalCount:
                            allPayments.length,
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
                      _buildPaymentList(
                        filteredPayments,
                        isDesktop,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    int paymentCount,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: 0.15),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons
                  .account_balance_wallet_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Management',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight:
                            FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$paymentCount payment${paymentCount == 1 ? '' : 's'} recorded',
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
        ],
      ),
    );
  }

  Widget _buildSummaryCards({
    required double totalReceived,
    required double filteredTotal,
    required int filteredCount,
    required int totalCount,
    required bool isDesktop,
  }) {
    final cards = [
      _summaryCard(
        icon: Icons
            .payments_rounded,
        title: 'Total Received',
        value:
            _currencyFormat.format(
          totalReceived,
        ),
        subtitle:
            '$totalCount transactions',
        color: AppColors.success,
      ),
      _summaryCard(
        icon: Icons
            .filter_alt_rounded,
        title: 'Filtered Amount',
        value:
            _currencyFormat.format(
          filteredTotal,
        ),
        subtitle:
            '$filteredCount matching',
        color: AppColors.primary,
      ),
      _summaryCard(
        icon: Icons
            .today_rounded,
        title: 'Today',
        value: 'View',
        subtitle:
            'Use date filter',
        color: AppColors.info,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map(
              (card) => Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.only(
                    right: 10,
                  ),
                  child: card,
                ),
              ),
            )
            .toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: cards[0],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: cards[1],
            ),
          ],
        ),
        const SizedBox(height: 10),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context)
              .dividerColor
              .withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  color.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
                const SizedBox(height: 3),
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color:
                            color,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters({
    required bool isDesktop,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context)
              .dividerColor
              .withValues(alpha: 0.5),
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
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
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
            ],
          ),
          const SizedBox(height: 14),
          if (isDesktop)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _searchField(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      _paymentMethodDropdown(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      _dateFilterButton(),
                ),
              ],
            )
          else ...[
            _searchField(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child:
                      _paymentMethodDropdown(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child:
                      _dateFilterButton(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText:
            'Search customer, amount, reference...',
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
                        _searchQuery = '';
                      });
                    },
                    icon: const Icon(
                      Icons.clear_rounded,
                    ),
                  )
                : null,
      ),
    );
  }

  Widget _paymentMethodDropdown() {
    return DropdownButtonFormField<
        String>(
      initialValue:
          _selectedPaymentMethod,
      decoration: const InputDecoration(
        labelText: 'Payment Method',
        prefixIcon: Icon(
          Icons
              .account_balance_wallet_outlined,
        ),
      ),
      items: _paymentMethods
          .map(
            (method) =>
                DropdownMenuItem(
              value: method,
              child: Text(method),
            ),
          )
          .toList(),
      onChanged: (value) {
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
    final hasDate =
        _selectedDateRange != null;

    return OutlinedButton.icon(
      onPressed: _selectDateRange,
      icon: const Icon(
        Icons.date_range_rounded,
      ),
      label: Text(
        hasDate
            ? '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - '
                '${DateFormat('dd/MM').format(_selectedDateRange!.end)}'
            : 'Date Range',
        overflow:
            TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize:
            const Size.fromHeight(56),
      ),
    );
  }

  Widget _buildPaymentList(
    List<PaymentModel> payments,
    bool isDesktop,
  ) {
    if (payments.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Payment History',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary
                    .withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Text(
                '${payments.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight:
                      FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...payments.map(
          (payment) =>
              _paymentCard(payment),
        ),
      ],
    );
  }

  Widget _paymentCard(
    PaymentModel payment,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      elevation: 0,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: () {
          _showPaymentDetails(
            payment,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(
            14,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.success
                      .withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons
                      .arrow_downward_rounded,
                  color:
                      AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.customerName
                              .trim()
                              .isEmpty
                          ? 'Unknown Customer'
                          : payment.customerName,
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
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      children: [
                        _smallTag(
                          payment
                              .paymentMethod,
                          AppColors.primary,
                        ),
                        Text(
                          _dateFormat.format(
                            payment.date,
                          ),
                          style: Theme.of(
                            context,
                          )
                              .textTheme
                              .bodySmall,
                        ),
                      ],
                    ),
                    if (payment
                        .transactionReference
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ref: ${payment.transactionReference}',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
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
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(
                      payment.amount,
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color:
                              AppColors.success,
                          fontWeight:
                              FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'RECEIVED',
                    style: TextStyle(
                      color:
                          AppColors.success,
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons
                    .chevron_right_rounded,
                color: Colors.grey,
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
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.09),
        borderRadius:
            BorderRadius.circular(6),
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

  Widget _buildEmptyState() {
    final hasFilters =
        _searchQuery.isNotEmpty ||
            _selectedPaymentMethod !=
                'All' ||
            _selectedDateRange != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 50,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context)
              .dividerColor
              .withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilters
                  ? Icons
                      .search_off_rounded
                  : Icons
                      .payments_outlined,
              size: 34,
              color:
                  AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No payments found'
                : 'No payments recorded',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight:
                      FontWeight.w700,
                ),
          ),
          const SizedBox(height: 7),
          Text(
            hasFilters
                ? 'Try changing your search or filters.'
                : 'Payment transactions will appear here.',
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
          if (hasFilters) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(
                Icons
                    .filter_alt_off_rounded,
              ),
              label: const Text(
                'CLEAR FILTERS',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(
    String error,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payments',
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(
            24,
          ),
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
              const SizedBox(height: 16),
              Text(
                'Unable to load payments.',
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
              const SizedBox(height: 8),
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
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  setState(() {});
                },
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
}
