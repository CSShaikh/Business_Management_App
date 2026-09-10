import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/payment_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/payment_provider.dart';
import 'add_payment_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({
    super.key,
  });

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
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

      final PaymentProvider paymentProvider =
          context.read<PaymentProvider>();

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

      paymentProvider.setBusinessId(
        businessId,
      );

      await paymentProvider.loadAndWatchPayments(
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
            'Unable to load payments. Please try again.';
      });
    }
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }

    try {
      final BusinessProvider businessProvider =
          context.read<BusinessProvider>();

      final PaymentProvider paymentProvider =
          context.read<PaymentProvider>();

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

        paymentProvider.setBusinessId(
          businessId,
        );

        await paymentProvider.loadAndWatchPayments(
          businessId: businessId,
        );
      } else {
        await paymentProvider.refresh();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to refresh payments.',
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
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

  List<PaymentModel> _filterPayments(
    List<PaymentModel> payments,
  ) {
    final String query =
        _searchQuery.trim().toLowerCase();

    return payments.where((payment) {
      // Search
      if (query.isNotEmpty) {
        final String customerName =
            payment.customerName.toLowerCase();

        final String method =
            payment.paymentMethod.toLowerCase();

        final String reference =
            payment.transactionReference.toLowerCase();

        final String notes =
            payment.notes.toLowerCase();

        final String amount =
            payment.amount.toStringAsFixed(2);

        final bool matchesSearch =
            customerName.contains(query) ||
                method.contains(query) ||
                reference.contains(query) ||
                notes.contains(query) ||
                amount.contains(query);

        if (!matchesSearch) {
          return false;
        }
      }

      // Payment method
      if (_selectedPaymentMethod != 'All' &&
          payment.paymentMethod !=
              _selectedPaymentMethod) {
        return false;
      }

      // Date range
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

        if (payment.date.isBefore(start) ||
            payment.date.isAfter(end)) {
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
      (double total, PaymentModel payment) {
        return total + payment.amount;
      },
    );
  }

  double _calculateTodayTotal(
    List<PaymentModel> payments,
  ) {
    final DateTime now = DateTime.now();

    return payments.fold<double>(
      0,
      (double total, PaymentModel payment) {
        final DateTime date = payment.date;

        final bool isToday =
            date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;

        if (isToday) {
          return total + payment.amount;
        }

        return total;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DATE FILTER
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
      initialDateRange: _selectedDateRange,
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
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

  bool get _hasFilters {
    return _searchQuery.trim().isNotEmpty ||
        _selectedPaymentMethod != 'All' ||
        _selectedDateRange != null;
  }

  // ---------------------------------------------------------------------------
  // ADD PAYMENT
  // ---------------------------------------------------------------------------

  Future<void> _openAddPayment() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddPaymentScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    final PaymentProvider paymentProvider =
        context.read<PaymentProvider>();

    await paymentProvider.refresh();
  }

  // ---------------------------------------------------------------------------
  // DELETE PAYMENT
  // ---------------------------------------------------------------------------

  

  // ---------------------------------------------------------------------------
  // PAYMENT DETAILS
  // ---------------------------------------------------------------------------

  void _showPaymentDetails(
    PaymentModel payment,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (
        BuildContext context,
      ) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surface,
              borderRadius:
                  BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailsHeader(
                    context,
                    payment,
                  ),
                  const SizedBox(height: 20),
                  _detailTile(
                    context,
                    icon: Icons.person_rounded,
                    label: 'Customer',
                    value:
                        payment.customerName.trim().isEmpty
                            ? 'Unknown Customer'
                            : payment.customerName,
                  ),
                  _detailTile(
                    context,
                    icon:
                        Icons.currency_rupee_rounded,
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
                    icon:
                        Icons.calendar_today_rounded,
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
                      icon:
                          Icons.receipt_long_rounded,
                      label:
                          'Transaction Reference',
                      value:
                          payment.transactionReference,
                    ),
                  if (payment.notes
                      .trim()
                      .isNotEmpty)
                    _detailTile(
                      context,
                      icon: Icons.notes_rounded,
                      label: 'Notes',
                      value: payment.notes,
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    
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
    PaymentModel payment,
  ) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color:
                AppColors.success.withValues(
              alpha: 0.12,
            ),
            borderRadius:
                BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.payments_rounded,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Details',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                _dateFormat.format(
                  payment.date,
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
          const EdgeInsets.only(bottom: 10),
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

  // ---------------------------------------------------------------------------
  // MAIN BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_pageError != null ||
        _businessId == null ||
        !_initialized) {
      return _buildPageError();
    }

    return Consumer<PaymentProvider>(
      builder: (
        BuildContext context,
        PaymentProvider paymentProvider,
        Widget? child,
      ) {
        if (paymentProvider.isLoading &&
            paymentProvider.payments.isEmpty) {
          return const Scaffold(
            body: Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        if (paymentProvider.errorMessage != null &&
            paymentProvider.payments.isEmpty) {
          return _buildProviderError(
            paymentProvider.errorMessage!,
          );
        }

        final List<PaymentModel> allPayments =
            paymentProvider.payments;

        final List<PaymentModel> filteredPayments =
            _filterPayments(
          allPayments,
        );

        final double totalReceived =
            _calculateTotal(
          allPayments,
        );

        final double filteredTotal =
            _calculateTotal(
          filteredPayments,
        );

        final double todayTotal =
            _calculateTodayTotal(
          allPayments,
        );

        return _buildScreen(
          allPayments: allPayments,
          filteredPayments:
              filteredPayments,
          totalReceived: totalReceived,
          filteredTotal: filteredTotal,
          todayTotal: todayTotal,
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
        title: const Text(
          'Payments',
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.business_center_outlined,
                size: 56,
                color: AppColors.warning,
              ),
              const SizedBox(height: 16),
              Text(
                _pageError ??
                    'Business profile not found.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _initialize,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text(
                  'RETRY',
                ),
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
        title: const Text(
          'Payments',
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: AppColors.danger,
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
  // SCREEN
  // ---------------------------------------------------------------------------

  Widget _buildScreen({
    required List<PaymentModel> allPayments,
    required List<PaymentModel>
        filteredPayments,
    required double totalReceived,
    required double filteredTotal,
    required double todayTotal,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payments',
        ),
        actions: [
          if (_hasFilters)
            IconButton(
              tooltip: 'Clear filters',
              onPressed: _clearFilters,
              icon: const Icon(
                Icons.filter_alt_off_rounded,
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
        onPressed: _openAddPayment,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'ADD PAYMENT',
        ),
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
                  constraints.maxWidth >= 1000;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop
                        ? 1250
                        : double.infinity,
                  ),
                  child: SingleChildScrollView(
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
                          CrossAxisAlignment.start,
                      children: [
                        _buildHeader(
                          allPayments.length,
                          todayTotal,
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryCards(
                          totalReceived:
                              totalReceived,
                          filteredTotal:
                              filteredTotal,
                          todayTotal:
                              todayTotal,
                          filteredCount:
                              filteredPayments.length,
                          totalCount:
                              allPayments.length,
                          isDesktop:
                              isDesktop,
                        ),
                        const SizedBox(height: 16),
                        _buildFilters(
                          isDesktop:
                              isDesktop,
                        ),
                        const SizedBox(height: 16),
                        _buildPaymentList(
                          filteredPayments,
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
    int paymentCount,
    double todayTotal,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
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
                        color:
                            Colors.white.withValues(
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
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.13,
                ),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  const Text(
                    'TODAY',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight:
                          FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _currencyFormat.format(
                      todayTotal,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
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
  // SUMMARY
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCards({
    required double totalReceived,
    required double filteredTotal,
    required double todayTotal,
    required int filteredCount,
    required int totalCount,
    required bool isDesktop,
  }) {
    final List<Widget> cards = [
      _summaryCard(
        icon: Icons.payments_rounded,
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
        icon: Icons.today_rounded,
        title: 'Today',
        value:
            _currencyFormat.format(
          todayTotal,
        ),
        subtitle:
            'Received today',
        color: AppColors.info,
      ),
      _summaryCard(
        icon: Icons.filter_alt_rounded,
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
        children: cards.map(
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
        color:
            Theme.of(context)
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            Theme.of(context)
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
              const Spacer(),
              if (_hasFilters)
                TextButton(
                  onPressed: _clearFilters,
                  child:
                      const Text('CLEAR'),
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
      onChanged: (String value) {
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
                      _searchController.clear();

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
    return DropdownButtonFormField<String>(
      initialValue:
          _selectedPaymentMethod,
      decoration: const InputDecoration(
        labelText: 'Payment Method',
        prefixIcon: Icon(
          Icons.account_balance_wallet_outlined,
        ),
      ),
      items: _paymentMethods.map(
        (String method) {
          return DropdownMenuItem<String>(
            value: method,
            child: Text(method),
          );
        },
      ).toList(),
      onChanged: (String? value) {
        if (value == null) {
          return;
        }

        setState(() {
          _selectedPaymentMethod = value;
        });
      },
    );
  }

  Widget _dateFilterButton() {
    final bool hasDate =
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

  // ---------------------------------------------------------------------------
  // PAYMENT LIST
  // ---------------------------------------------------------------------------

  Widget _buildPaymentList(
    List<PaymentModel> payments,
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
                color:
                    AppColors.primary.withValues(
                  alpha: 0.1,
                ),
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
          (PaymentModel payment) =>
              _paymentCard(payment),
        ),
      ],
    );
  }

  Widget _paymentCard(
    PaymentModel payment,
  ) {
    final String customerName =
        payment.customerName.trim().isEmpty
            ? 'Unknown Customer'
            : payment.customerName;

    return Card(
      margin:
          const EdgeInsets.only(bottom: 10),
      elevation: 0,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: () {
          _showPaymentDetails(payment);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                      AppColors.success.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.arrow_downward_rounded,
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
                      customerName,
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
                          payment.paymentMethod,
                          AppColors.primary,
                        ),
                        Text(
                          _dateFormat.format(
                            payment.date,
                          ),
                          style: Theme.of(context)
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
                Icons.chevron_right_rounded,
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

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    final bool hasFilters =
        _hasFilters;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 50,
      ),
      decoration: BoxDecoration(
        color:
            Theme.of(context)
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
              color:
                  AppColors.primary.withValues(
                alpha: 0.1,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilters
                  ? Icons.search_off_rounded
                  : Icons.payments_outlined,
              size: 34,
              color: AppColors.primary,
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
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(
                Icons.filter_alt_off_rounded,
              ),
              label:
                  const Text('CLEAR FILTERS'),
            ),
          ] else ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openAddPayment,
              icon: const Icon(
                Icons.add_rounded,
              ),
              label:
                  const Text('ADD PAYMENT'),
            ),
          ],
        ],
      ),
    );
  }
}