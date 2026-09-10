import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/payment_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/payment_repository.dart';

class PaymentReportScreen extends StatefulWidget {
  const PaymentReportScreen({super.key});

  @override
  State<PaymentReportScreen> createState() =>
      _PaymentReportScreenState();
}

class _PaymentReportScreenState
    extends State<PaymentReportScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final PaymentRepository _paymentRepository =
      PaymentRepository();

  final TextEditingController _searchController =
      TextEditingController();

  bool _loading = true;
  bool _refreshing = false;

  String? _errorMessage;
  String _searchQuery = '';

  DateTime? _startDate;
  DateTime? _endDate;

  String _selectedMethod = 'All';

  List<PaymentModel> _allPayments = <PaymentModel>[];

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
      final BusinessModel? business =
          await _businessRepository.getBusinessForCurrentUser();

      if (business == null) {
        throw Exception(
          'Business information is not available.',
        );
      }

      final List<PaymentModel> payments =
          await _paymentRepository.getPayments(
        businessId: business.id,
      );

      if (!mounted) return;

      setState(() {
        _allPayments = payments;
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
    await _loadReport(showLoader: false);
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
          _startDate != null && _endDate != null
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
      helpText: 'Select Payment Report Period',
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

  List<PaymentModel> get _filteredPayments {
    final String query =
        _searchQuery.trim().toLowerCase();

    final List<PaymentModel> result =
        _allPayments.where((payment) {
      if (_startDate != null &&
          payment.date.isBefore(_startDate!)) {
        return false;
      }

      if (_endDate != null &&
          payment.date.isAfter(_endDate!)) {
        return false;
      }

      if (_selectedMethod != 'All' &&
          payment.paymentMethod.toLowerCase() !=
              _selectedMethod.toLowerCase()) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return payment.customerName
              .toLowerCase()
              .contains(query) ||
          payment.paymentMethod
              .toLowerCase()
              .contains(query) ||
          payment.transactionReference
              .toLowerCase()
              .contains(query) ||
          payment.notes
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

  double _totalReceived(
    List<PaymentModel> payments,
  ) {
    return payments.fold(
      0,
      (sum, payment) => sum + payment.amount,
    );
  }

  double _todayReceived(
    List<PaymentModel> payments,
  ) {
    final DateTime now = DateTime.now();

    return payments
        .where(
          (payment) =>
              payment.date.year == now.year &&
              payment.date.month == now.month &&
              payment.date.day == now.day,
        )
        .fold(
          0,
          (sum, payment) => sum + payment.amount,
        );
  }

  double _averagePayment(
    List<PaymentModel> payments,
  ) {
    if (payments.isEmpty) return 0;

    return _totalReceived(payments) /
        payments.length;
  }

  Map<String, double> _methodTotals(
    List<PaymentModel> payments,
  ) {
    final Map<String, double> result =
        <String, double>{};

    for (final payment in payments) {
      final String method =
          payment.paymentMethod.trim().isEmpty
              ? 'Other'
              : payment.paymentMethod.trim();

      result[method] =
          (result[method] ?? 0) +
              payment.amount;
    }

    return result;
  }

  Map<String, _CustomerPaymentData>
      _customerTotals(
    List<PaymentModel> payments,
  ) {
    final Map<String, _CustomerPaymentData>
        result =
        <String, _CustomerPaymentData>{};

    for (final payment in payments) {
      final String customerName =
          payment.customerName.trim().isEmpty
              ? 'Unknown Customer'
              : payment.customerName.trim();

      final String customerId =
          payment.customerId.trim();

      final String key = customerId.isEmpty
          ? customerName
          : customerId;

      final _CustomerPaymentData? old =
          result[key];

      if (old == null) {
        result[key] =
            _CustomerPaymentData(
          customerId: customerId,
          customerName: customerName,
          amount: payment.amount,
          paymentCount: 1,
        );
      } else {
        result[key] =
            _CustomerPaymentData(
          customerId: customerId,
          customerName: customerName,
          amount:
              old.amount + payment.amount,
          paymentCount:
              old.paymentCount + 1,
        );
      }
    }

    return result;
  }

  Map<String, double> _monthlyTotals(
    List<PaymentModel> payments,
  ) {
    final Map<String, double> result =
        <String, double>{};

    for (final payment in payments) {
      final String key =
          '${payment.date.year}-${payment.date.month.toString().padLeft(2, '0')}';

      result[key] =
          (result[key] ?? 0) + payment.amount;
    }

    return result;
  }

  // ===========================================================================
  // FORMATTING
  // ===========================================================================

  String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  String _number(double value) {
    return NumberFormat(
      '#,##0.##',
      'en_IN',
    ).format(value);
  }

  String _date(DateTime value) {
    return DateFormat(
      'dd MMM yyyy',
    ).format(value);
  }

  String _dateTime(DateTime value) {
    return DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(value);
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

    final List<PaymentModel> payments =
        _filteredPayments;

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
                    _buildSummary(
                      theme,
                      payments,
                      isDesktop,
                    ),
                    const SizedBox(height: 20),
                    _buildFilters(theme),
                    const SizedBox(height: 20),
                    _buildMethodSection(
                      theme,
                      payments,
                    ),
                    const SizedBox(height: 20),
                    _buildMonthlySection(
                      theme,
                      payments,
                    ),
                    const SizedBox(height: 20),
                    _buildCustomerSection(
                      theme,
                      payments,
                    ),
                    const SizedBox(height: 20),
                    _buildPaymentList(
                      theme,
                      payments,
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(22),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.15,
              ),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Track received payments, collection methods and customer-wise collections.',
                  style: TextStyle(
                    color: Colors.white.withValues(
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
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withValues(
                      alpha: 0.14,
                    ),
                    borderRadius:
                        BorderRadius.circular(30),
                  ),
                  child: Text(
                    _dateRangeText(),
                    style: const TextStyle(
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
              onPressed: _refreshing
                  ? null
                  : _refreshReport,
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                    ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DATE FILTER
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
              fontWeight: FontWeight.w700,
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
            onPressed: _selectDateRange,
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
              onPressed: _clearDateFilter,
              icon: const Icon(
                Icons.clear_rounded,
                size: 18,
              ),
              label: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummary(
    ThemeData theme,
    List<PaymentModel> payments,
    bool isDesktop,
  ) {
    final double total =
        _totalReceived(payments);

    final double today =
        _todayReceived(payments);

    final double average =
        _averagePayment(payments);

    final List<_SummaryItem> items = [
      _SummaryItem(
        title: 'Total Received',
        value: _currency(total),
        subtitle:
            '${payments.length} payment${payments.length == 1 ? '' : 's'}',
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.success,
      ),
      _SummaryItem(
        title: 'Today Received',
        value: _currency(today),
        subtitle: 'Received today',
        icon: Icons.today_rounded,
        color: AppColors.primary,
      ),
      _SummaryItem(
        title: 'Average Payment',
        value: _currency(average),
        subtitle: 'Per transaction',
        icon: Icons.calculate_rounded,
        color: AppColors.secondary,
      ),
      _SummaryItem(
        title: 'Customers',
        value: _number(
          _customerTotals(payments).length
              .toDouble(),
        ),
        subtitle: 'Customers paid',
        icon: Icons.people_alt_rounded,
        color: AppColors.info,
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
            isDesktop ? 1.85 : 1.48,
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
          Text(
            'Search & Filters',
            style: theme
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery =
                    value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText:
                  'Search customer, reference, method or notes...',
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
                              _searchQuery =
                                  '';
                            });
                          },
                          icon: const Icon(
                            Icons.clear_rounded,
                          ),
                        )
                      : null,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _paymentMethods.map(
              (method) {
                final bool selected =
                    _selectedMethod ==
                        method;

                return ChoiceChip(
                  label: Text(method),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedMethod =
                          method;
                    });
                  },
                );
              },
            ).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // METHOD
  // ===========================================================================

  Widget _buildMethodSection(
    ThemeData theme,
    List<PaymentModel> payments,
  ) {
    final Map<String, double> totals =
        _methodTotals(payments);

    final List<MapEntry<String, double>>
        entries =
        totals.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(a.value),
          );

    final double grandTotal =
        _totalReceived(payments);

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.account_balance_rounded,
            title: 'Payment Method Breakdown',
            subtitle:
                'How customers are paying',
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.payments_outlined,
              message:
                  'No payment data available.',
            )
          else
            ...entries.map(
              (entry) {
                final double percentage =
                    grandTotal > 0
                        ? (entry.value /
                                grandTotal) *
                            100
                        : 0;

                return _MethodTile(
                  method: entry.key,
                  amount: entry.value,
                  percentage: percentage,
                  currency: _currency,
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MONTHLY
  // ===========================================================================

  Widget _buildMonthlySection(
    ThemeData theme,
    List<PaymentModel> payments,
  ) {
    final Map<String, double> totals =
        _monthlyTotals(payments);

    final List<MapEntry<String, double>>
        entries =
        totals.entries.toList()
          ..sort(
            (a, b) =>
                b.key.compareTo(a.key),
          );

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon:
                Icons.calendar_view_month_rounded,
            title: 'Monthly Collections',
            subtitle:
                'Payment collection by month',
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.bar_chart_rounded,
              message:
                  'No monthly payment data available.',
            )
          else
            ...entries.map(
              (entry) {
                final List<String> parts =
                    entry.key.split('-');

                final int year =
                    int.tryParse(parts[0]) ?? 0;

                final int month =
                    int.tryParse(parts[1]) ?? 1;

                final String monthName =
                    DateFormat('MMM yyyy')
                        .format(
                  DateTime(year, month),
                );

                final double total =
                    _totalReceived(
                  payments,
                );

                final double percentage =
                    total > 0
                        ? (entry.value /
                                total) *
                            100
                        : 0;

                return _MonthlyTile(
                  monthName: monthName,
                  amount: entry.value,
                  percentage: percentage,
                  currency: _currency,
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CUSTOMER
  // ===========================================================================

  Widget _buildCustomerSection(
    ThemeData theme,
    List<PaymentModel> payments,
  ) {
    final Map<String, _CustomerPaymentData>
        map =
        _customerTotals(payments);

    final List<_CustomerPaymentData>
        customers =
        map.values.toList()
          ..sort(
            (a, b) =>
                b.amount.compareTo(a.amount),
          );

    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.people_alt_rounded,
            title: 'Customer-wise Collections',
            subtitle:
                'Amount received from each customer',
          ),
          const SizedBox(height: 18),
          if (customers.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.people_outline_rounded,
              message:
                  'No customer collection data available.',
            )
          else
            ...customers.map(
              (customer) {
                final double total =
                    _totalReceived(
                  payments,
                );

                final double percentage =
                    total > 0
                        ? (customer.amount /
                                total) *
                            100
                        : 0;

                return _CustomerPaymentTile(
                  data: customer,
                  percentage: percentage,
                  currency: _currency,
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAYMENT LIST
  // ===========================================================================

  Widget _buildPaymentList(
    ThemeData theme,
    List<PaymentModel> payments,
  ) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.receipt_long_rounded,
            title: 'Payment Transactions',
            subtitle:
                '${payments.length} transaction${payments.length == 1 ? '' : 's'} found',
          ),
          const SizedBox(height: 18),
          if (payments.isEmpty)
            const _EmptyInline(
              icon:
                  Icons.receipt_long_outlined,
              message:
                  'No payments found for the selected filters.',
            )
          else
            ...payments.map(
              (payment) {
                return _PaymentTile(
                  payment: payment,
                  currency: _currency,
                  date: _date,
                  onTap: () {
                    _showPaymentDetails(
                      payment,
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

  void _showPaymentDetails(
    PaymentModel payment,
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
                    'Payment Details',
                    style: theme
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.success
                          .withValues(
                        alpha: 0.08,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                      border: Border.all(
                        color: AppColors.success
                            .withValues(
                          alpha: 0.18,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons
                              .account_balance_wallet_rounded,
                          color:
                              AppColors.success,
                          size: 32,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        Text(
                          _currency(
                            payment.amount,
                          ),
                          style: theme
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                            color:
                                AppColors.success,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        const Text(
                          'Payment Received',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DetailRow(
                    label: 'Customer',
                    value:
                        payment.customerName,
                  ),
                  _DetailRow(
                    label: 'Date',
                    value:
                        _dateTime(
                      payment.date,
                    ),
                  ),
                  _DetailRow(
                    label: 'Payment Method',
                    value:
                        payment.paymentMethod,
                  ),
                  _DetailRow(
                    label:
                        'Transaction Reference',
                    value:
                        payment.transactionReference
                                .trim()
                                .isEmpty
                            ? '—'
                            : payment
                                .transactionReference,
                  ),
                  _DetailRow(
                    label: 'Notes',
                    value:
                        payment.notes
                                .trim()
                                .isEmpty
                            ? '—'
                            : payment.notes,
                  ),
                  _DetailRow(
                    label: 'Payment ID',
                    value: payment.id,
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
                    color: AppColors.danger
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
                  'Unable to load Payment Report',
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
                      const Text('Try Again'),
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

class _CustomerPaymentData {
  final String customerId;
  final String customerName;
  final double amount;
  final int paymentCount;

  const _CustomerPaymentData({
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.paymentCount,
  });
}

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

class _ReportCard
    extends StatelessWidget {
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
          color: item.color.withValues(
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
// METHOD TILE
// =============================================================================

class _MethodTile
    extends StatelessWidget {
  final String method;
  final double amount;
  final double percentage;
  final String Function(double) currency;

  const _MethodTile({
    required this.method,
    required this.amount,
    required this.percentage,
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
          alpha: 0.40,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
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
                    10,
                  ),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color:
                      AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  method,
                  style: theme
                      .textTheme
                      .bodyLarge
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
                    .bodyLarge
                    ?.copyWith(
                  color:
                      AppColors.success,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(20),
            child:
                LinearProgressIndicator(
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
                AppColors.primary,
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
                    AppColors.primary,
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
// MONTHLY TILE
// =============================================================================

class _MonthlyTile
    extends StatelessWidget {
  final String monthName;
  final double amount;
  final double percentage;
  final String Function(double) currency;

  const _MonthlyTile({
    required this.monthName,
    required this.amount,
    required this.percentage,
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
          alpha: 0.40,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color:
                  AppColors.secondary
                      .withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color:
                  AppColors.secondary,
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
                  monthName,
                  style: theme
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${percentage.toStringAsFixed(1)}% of total collections',
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
          Text(
            currency(amount),
            style: theme
                .textTheme
                .bodyLarge
                ?.copyWith(
              color:
                  AppColors.success,
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
// CUSTOMER TILE
// =============================================================================

class _CustomerPaymentTile
    extends StatelessWidget {
  final _CustomerPaymentData data;
  final double percentage;
  final String Function(double) currency;

  const _CustomerPaymentTile({
    required this.data,
    required this.percentage,
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
          alpha: 0.40,
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
                  AppColors.success
                      .withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color:
                  AppColors.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  data.customerName,
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
                Text(
                  '${data.paymentCount} payment${data.paymentCount == 1 ? '' : 's'} • ${percentage.toStringAsFixed(1)}%',
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
          Text(
            currency(data.amount),
            style: theme
                .textTheme
                .bodyLarge
                ?.copyWith(
              color:
                  AppColors.success,
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
// PAYMENT TILE
// =============================================================================

class _PaymentTile
    extends StatelessWidget {
  final PaymentModel payment;
  final String Function(double) currency;
  final String Function(DateTime) date;
  final VoidCallback onTap;

  const _PaymentTile({
    required this.payment,
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
        ),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration:
                  BoxDecoration(
                color:
                    AppColors.success
                        .withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  11,
                ),
              ),
              child: const Icon(
                Icons.payments_rounded,
                color:
                    AppColors.success,
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
                    payment.customerName
                            .trim()
                            .isEmpty
                        ? 'Unknown Customer'
                        : payment.customerName,
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
                  const SizedBox(height: 3),
                  Text(
                    '${payment.paymentMethod} • ${date(payment.date)}',
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: theme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                  if (payment
                      .transactionReference
                      .trim()
                      .isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 3,
                      ),
                      child: Text(
                        'Ref: ${payment.transactionReference}',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: theme
                            .textTheme
                            .bodySmall,
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
                    payment.amount,
                  ),
                  style: theme
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                    color:
                        AppColors.success,
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

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 11,
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
                fontWeight:
                    FontWeight.w600,
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