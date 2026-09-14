import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/ledger_transaction_model.dart';
import '../../models/supplier_model.dart';
import '../../models/supplier_payment_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/supplier_payment_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../services/ledger/supplier_ledger_service.dart';
import 'add_supplier_payment_screen.dart';

class SupplierPaymentScreen extends StatefulWidget {
  const SupplierPaymentScreen({
    super.key,
  });

  @override
  State<SupplierPaymentScreen> createState() =>
      _SupplierPaymentScreenState();
}

class _SupplierPaymentScreenState
    extends State<SupplierPaymentScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final SupplierRepository _supplierRepository =
      SupplierRepository();

  final SupplierPaymentRepository _paymentRepository =
      SupplierPaymentRepository();

  final SupplierLedgerService _supplierLedgerService =
      SupplierLedgerService();

  final TextEditingController _searchController =
      TextEditingController();

  final List<String> _paymentMethods = <String>[
    'All',
    'Cash',
    'UPI',
    'Card',
    'Bank Transfer',
    'Cheque',
    'Other',
  ];

  String? _businessId;

  List<SupplierPaymentModel> _payments =
      <SupplierPaymentModel>[];

  List<SupplierModel> _suppliers =
      <SupplierModel>[];

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isDeleting = false;

  String? _errorMessage;

  String _searchQuery = '';

  String _selectedPaymentMethod = 'All';

  String _selectedSupplierId = 'All';

  String _selectedStatus = 'All';

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _handleSearchChanged,
    );

    _initialize();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();

    super.dispose();
  }

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  Future<void> _initialize() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final business = await _businessRepository
          .getBusinessForCurrentUser();

      if (!mounted) {
        return;
      }

      if (business == null ||
          business.id.trim().isEmpty) {
        setState(() {
          _isLoading = false;
          _businessId = null;
          _errorMessage =
              'Business profile not found. '
              'Please complete business setup first.';
        });

        return;
      }

      final String businessId =
          business.id.trim();

      final results = await Future.wait<dynamic>([
        _paymentRepository.getPayments(
          businessId: businessId,
        ),
        _supplierRepository.getSuppliers(
          businessId,
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _businessId = businessId;

        _payments =
            results[0] as List<SupplierPaymentModel>;

        _suppliers =
            results[1] as List<SupplierModel>;

        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _cleanError(e);
      });
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing) {
      return;
    }

    final String? businessId = _businessId;

    if (businessId == null ||
        businessId.trim().isEmpty) {
      await _initialize();
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      final results = await Future.wait<dynamic>([
        _paymentRepository.getPayments(
          businessId: businessId,
        ),
        _supplierRepository.getSuppliers(
          businessId,
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _payments =
            results[0] as List<SupplierPaymentModel>;

        _suppliers =
            results[1] as List<SupplierModel>;

        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRefreshing = false;
      });

      _showMessage(
        'Unable to refresh supplier payments: '
        '${_cleanError(e)}',
        isError: true,
      );
    }
  }

  // ===========================================================================
  // SEARCH / FILTERS
  // ===========================================================================

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _searchQuery =
          _searchController.text.trim();
    });
  }

  bool get _hasActiveFilters {
    return _searchQuery.trim().isNotEmpty ||
        _selectedPaymentMethod != 'All' ||
        _selectedSupplierId != 'All' ||
        _selectedStatus != 'All' ||
        _startDate != null ||
        _endDate != null;
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedPaymentMethod = 'All';
      _selectedSupplierId = 'All';
      _selectedStatus = 'All';
      _startDate = null;
      _endDate = null;
    });
  }

  List<SupplierPaymentModel> _filteredPayments() {
    final String query =
        _searchQuery.trim().toLowerCase();

    return _payments.where(
      (SupplierPaymentModel payment) {
        // ---------------------------------------------------------------------
        // SEARCH
        // ---------------------------------------------------------------------

        if (query.isNotEmpty) {
          final String supplierName =
              payment.supplierName.toLowerCase();

          final String supplierId =
              payment.supplierId.toLowerCase();

          final String method =
              payment.paymentMethod.toLowerCase();

          final String reference =
              payment.transactionReference
                  .toLowerCase();

          final String notes =
              payment.notes.toLowerCase();

          final String amount =
              payment.amount.toStringAsFixed(2);

          final bool matchesSearch =
              supplierName.contains(query) ||
                  supplierId.contains(query) ||
                  method.contains(query) ||
                  reference.contains(query) ||
                  notes.contains(query) ||
                  amount.contains(query);

          if (!matchesSearch) {
            return false;
          }
        }

        // ---------------------------------------------------------------------
        // PAYMENT METHOD
        // ---------------------------------------------------------------------

        if (_selectedPaymentMethod != 'All' &&
            payment.paymentMethod.trim() !=
                _selectedPaymentMethod) {
          return false;
        }

        // ---------------------------------------------------------------------
        // SUPPLIER
        // ---------------------------------------------------------------------

        if (_selectedSupplierId != 'All' &&
            payment.supplierId.trim() !=
                _selectedSupplierId) {
          return false;
        }

        // ---------------------------------------------------------------------
        // STATUS
        // ---------------------------------------------------------------------

        // Supplier payment records are completed payment transactions.
        // Therefore the only meaningful status is Paid.
        if (_selectedStatus == 'Paid') {
          // Always true for a valid SupplierPaymentModel.
        }

        // ---------------------------------------------------------------------
        // DATE RANGE
        // ---------------------------------------------------------------------

        final DateTime paymentDate =
            payment.date;

        if (_startDate != null) {
          final DateTime start = DateTime(
            _startDate!.year,
            _startDate!.month,
            _startDate!.day,
          );

          if (paymentDate.isBefore(start)) {
            return false;
          }
        }

        if (_endDate != null) {
          final DateTime endExclusive =
              DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day + 1,
          );

          if (!paymentDate.isBefore(
            endExclusive,
          )) {
            return false;
          }
        }

        return true;
      },
    ).toList();
  }

  // ===========================================================================
  // DATE FILTER
  // ===========================================================================

  Future<void> _selectStartDate() async {
    final DateTime initialDate =
        _startDate ??
            _endDate ??
            DateTime.now();

    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    if (_endDate != null &&
        selected.isAfter(_endDate!)) {
      _showMessage(
        'Start date cannot be after end date.',
        isError: true,
      );

      return;
    }

    setState(() {
      _startDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );
    });
  }

  Future<void> _selectEndDate() async {
    final DateTime initialDate =
        _endDate ??
            _startDate ??
            DateTime.now();

    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    if (_startDate != null &&
        selected.isBefore(_startDate!)) {
      _showMessage(
        'End date cannot be before start date.',
        isError: true,
      );

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

  // ===========================================================================
  // ADD / EDIT
  // ===========================================================================

  Future<void> _openAddPayment() async {
    final bool? result =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) =>
            const AddSupplierPaymentScreen(),
      ),
    );

    if (result == true) {
      await _refresh();
    }
  }

  Future<void> _openEditPayment(
    SupplierPaymentModel payment,
  ) async {
    if (_isDeleting) {
      return;
    }

    final bool? result =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) =>
            AddSupplierPaymentScreen(
          payment: payment,
        ),
      ),
    );

    if (result == true) {
      await _refresh();
    }
  }

  // ===========================================================================
  // DELETE
  // ===========================================================================

  Future<void> _deletePayment(
    SupplierPaymentModel payment,
  ) async {
    if (_isDeleting) {
      return;
    }

    final String businessId =
        _businessId?.trim() ?? '';

    if (businessId.isEmpty) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );

      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Supplier Payment?',
          ),
          content: Text(
            'Are you sure you want to delete '
            'this payment of '
            '${_formatCurrency(payment.amount)} '
            'made to ${payment.supplierName}?\n\n'
            'The supplier ledger entry will also '
            'be reversed.',
          ),
          actions: <Widget>[
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

    setState(() {
      _isDeleting = true;
    });

    LedgerTransactionModel? createdReversal;

    try {
      // -----------------------------------------------------------------------
      // 1. CHECK WHETHER PAYMENT LEDGER ENTRY EXISTS
      // -----------------------------------------------------------------------

      final List<LedgerTransactionModel>
          transactions =
          await _supplierLedgerService
              .getSupplierTransactions(
        businessId: businessId,
        supplierId: payment.supplierId.trim(),
      );

      final List<LedgerTransactionModel>
          paymentEntries =
          transactions.where(
        (LedgerTransactionModel transaction) {
          return transaction.referenceId.trim() ==
                  payment.id.trim() &&
              transaction.transactionType
                      .trim()
                      .toUpperCase() ==
                  SupplierLedgerService
                      .supplierPaymentType;
        },
      ).toList();

      // -----------------------------------------------------------------------
      // 2. REVERSE SUPPLIER LEDGER
      // -----------------------------------------------------------------------

      if (paymentEntries.isNotEmpty) {
        final bool reversalAlreadyExists =
            transactions.any(
          (LedgerTransactionModel transaction) {
            return transaction.referenceId
                        .trim() ==
                    payment.id.trim() &&
                transaction.transactionType
                        .trim()
                        .toUpperCase() ==
                    SupplierLedgerService
                        .supplierPaymentReversalType;
          },
        );

        if (!reversalAlreadyExists) {
          createdReversal =
              await _supplierLedgerService
                  .createSupplierPaymentReversal(
            businessId: businessId,
            paymentAmount: payment.amount,
            supplierId: payment.supplierId.trim(),
            supplierName: payment.supplierName.trim(),
            referenceId: payment.id.trim(),
            notes:
                'Reversal for supplier payment ${payment.id.trim()}.',
          );
        }
      }

      // -----------------------------------------------------------------------
      // 3. DELETE PAYMENT DOCUMENT
      // -----------------------------------------------------------------------

      await _paymentRepository.deletePayment(
        businessId: businessId,
        paymentId: payment.id.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _payments.removeWhere(
          (SupplierPaymentModel item) =>
              item.id.trim() ==
              payment.id.trim(),
        );

        _isDeleting = false;
      });

      _showMessage(
        createdReversal == null
            ? 'Supplier payment deleted successfully.'
            : 'Supplier payment deleted and '
              'supplier ledger reversed successfully.',
      );
    } catch (e) {
      // -----------------------------------------------------------------------
      // ROLLBACK LEDGER REVERSAL
      // -----------------------------------------------------------------------

      if (createdReversal != null) {
        try {
          await _supplierLedgerService
              .deleteTransaction(
            businessId: businessId,
            transactionId:
                createdReversal.id,
          );
        } catch (_) {
          // Preserve original error.
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleting = false;
      });

      _showMessage(
        'Unable to delete supplier payment: '
        '${_cleanError(e)}',
        isError: true,
      );
    }
  }

  // ===========================================================================
  // DETAILS
  // ===========================================================================

  Future<void> _showPaymentDetails(
    SupplierPaymentModel payment,
  ) async {
    final String businessId =
        _businessId?.trim() ?? '';

    double supplierBalance = 0;

    if (businessId.isNotEmpty &&
        payment.supplierId.trim().isNotEmpty) {
      try {
        supplierBalance =
            await _supplierLedgerService
                .getSupplierBalance(
          businessId: businessId,
          supplierId: payment.supplierId.trim(),
        );
      } catch (_) {
        supplierBalance = 0;
      }
    }

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final ThemeData theme =
            Theme.of(sheetContext);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
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
                const SizedBox(height: 20),

                _DetailTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Supplier',
                  value:
                      payment.supplierName,
                ),

                _DetailTile(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Amount',
                  value:
                      _formatCurrency(
                    payment.amount,
                  ),
                  valueColor:
                      AppColors.success,
                ),

                _DetailTile(
                  icon:
                      Icons.calendar_month_outlined,
                  label: 'Payment Date',
                  value:
                      DateFormat(
                    'dd MMM yyyy',
                  ).format(payment.date),
                ),

                _DetailTile(
                  icon:
                      Icons.account_balance_wallet_outlined,
                  label: 'Payment Method',
                  value:
                      payment.paymentMethod
                              .trim()
                              .isEmpty
                          ? 'Not specified'
                          : payment.paymentMethod,
                ),

                if (payment.transactionReference
                    .trim()
                    .isNotEmpty)
                  _DetailTile(
                    icon:
                        Icons.receipt_long_outlined,
                    label:
                        'Transaction Reference',
                    value:
                        payment.transactionReference,
                  ),

                if (payment.notes
                    .trim()
                    .isNotEmpty)
                  _DetailTile(
                    icon: Icons.notes_outlined,
                    label: 'Notes',
                    value:
                        payment.notes,
                  ),

                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(16),
                  decoration:
                      BoxDecoration(
                    color: AppColors.primary
                        .withValues(
                      alpha: 0.07,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    border: Border.all(
                      color: AppColors.primary
                          .withValues(
                        alpha: 0.15,
                      ),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration:
                            BoxDecoration(
                          color: AppColors
                              .primary
                              .withValues(
                            alpha: 0.10,
                          ),
                          shape:
                              BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
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
                              CrossAxisAlignment
                                  .start,
                          children: <Widget>[
                            Text(
                              'Current Supplier Payable',
                              style: theme
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: theme
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              _formatCurrency(
                                supplierBalance,
                              ),
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

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        sheetContext,
                      );

                      _openEditPayment(
                        payment,
                      );
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                    ),
                    label: const Text(
                      'EDIT PAYMENT',
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

  // ===========================================================================
  // UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor:
            theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Supplier Payments',
          ),
        ),
        body: const Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null &&
        _payments.isEmpty) {
      return Scaffold(
        backgroundColor:
            theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Supplier Payments',
          ),
        ),
        body: _buildErrorState(
          theme,
        ),
      );
    }

    final List<SupplierPaymentModel>
        filteredPayments =
        _filteredPayments();

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Supplier Payments',
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isRefreshing
                ? null
                : _refresh,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
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
                    const BoxConstraints(
                  maxWidth: 1250,
                ),
                child: ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    100,
                  ),
                  children: <Widget>[
                    _buildHeader(
                      theme,
                      isDesktop,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    _buildSummary(
                      theme,
                      filteredPayments,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    _buildFilters(
                      theme,
                      isDesktop,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildPaymentList(
                      theme,
                      filteredPayments,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _isDeleting
            ? null
            : _openAddPayment,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Add Payment',
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    bool isDesktop,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Supplier Payments',
                style: theme
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Track payments made to your suppliers '
                'and keep supplier balances synchronized.',
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
        if (isDesktop) ...[
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: _isDeleting
                ? null
                : _openAddPayment,
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text(
              'Add Payment',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummary(
    ThemeData theme,
    List<SupplierPaymentModel>
        filteredPayments,
  ) {
    final double filteredTotal =
        filteredPayments.fold<double>(
      0,
      (
        double sum,
        SupplierPaymentModel payment,
      ) =>
          sum + payment.amount,
    );

    final double overallTotal =
        _payments.fold<double>(
      0,
      (
        double sum,
        SupplierPaymentModel payment,
      ) =>
          sum + payment.amount,
    );

    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final bool compact =
            constraints.maxWidth < 650;

        final List<Widget> cards =
            <Widget>[
          _SummaryCard(
            title: 'Total Paid',
            value:
                _formatCurrency(overallTotal),
            icon:
                Icons.payments_outlined,
            iconColor:
                AppColors.success,
          ),
          _SummaryCard(
            title: 'Filtered',
            value:
                _formatCurrency(filteredTotal),
            icon:
                Icons.filter_alt_outlined,
            iconColor:
                AppColors.primary,
          ),
          _SummaryCard(
            title: 'Transactions',
            value:
                '${filteredPayments.length}',
            icon:
                Icons.receipt_long_outlined,
            iconColor:
                AppColors.warning,
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
                        const EdgeInsets.only(
                      right: 10,
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

  Widget _buildFilters(
    ThemeData theme,
    bool isDesktop,
  ) {
    final Widget searchField =
        TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText:
            'Search supplier, amount, reference...',
        prefixIcon: const Icon(
          Icons.search_rounded,
        ),
        suffixIcon:
            _searchQuery.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController
                          .clear();
                    },
                    icon: const Icon(
                      Icons.clear_rounded,
                    ),
                  )
                : null,
      ),
    );

    final Widget methodDropdown =
        DropdownButtonFormField<String>(
      initialValue:
          _selectedPaymentMethod,
      decoration:
          const InputDecoration(
        labelText: 'Payment Method',
        prefixIcon: Icon(
          Icons.account_balance_wallet_outlined,
        ),
      ),
      items: _paymentMethods
          .map(
            (String method) =>
                DropdownMenuItem<String>(
              value: method,
              child: Text(method),
            ),
          )
          .toList(),
      onChanged: (String? value) {
        if (value == null) {
          return;
        }

        setState(() {
          _selectedPaymentMethod =
              value;
        });
      },
    );

    final Widget supplierDropdown =
        DropdownButtonFormField<String>(
      initialValue:
          _supplierDropdownValue(),
      isExpanded: true,
      decoration:
          const InputDecoration(
        labelText: 'Supplier',
        prefixIcon: Icon(
          Icons.local_shipping_outlined,
        ),
      ),
      items: <DropdownMenuItem<String>>[
        const DropdownMenuItem<String>(
          value: 'All',
          child: Text(
            'All Suppliers',
          ),
        ),
        ..._suppliers.map(
          (SupplierModel supplier) =>
              DropdownMenuItem<String>(
            value: supplier.id,
            child: Text(
              supplier.name,
              overflow:
                  TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (String? value) {
        if (value == null) {
          return;
        }

        setState(() {
          _selectedSupplierId =
              value;
        });
      },
    );

    final Widget dateButton =
        OutlinedButton.icon(
      onPressed: _showDateRangeSheet,
      icon: const Icon(
        Icons.date_range_rounded,
      ),
      label: Text(
        _dateFilterLabel(),
        overflow:
            TextOverflow.ellipsis,
      ),
      style:
          OutlinedButton.styleFrom(
        minimumSize:
            const Size.fromHeight(56),
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.filter_alt_outlined,
                  color:
                      AppColors.primary,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  'Search & Filters',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (_hasActiveFilters)
                  TextButton(
                    onPressed:
                        _clearFilters,
                    child:
                        const Text(
                      'CLEAR',
                    ),
                  ),
              ],
            ),
            const SizedBox(
              height: 14,
            ),
            if (isDesktop)
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 2,
                    child: searchField,
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child:
                        supplierDropdown,
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child:
                        methodDropdown,
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child:
                        dateButton,
                  ),
                ],
              )
            else
              Column(
                children: <Widget>[
                  searchField,
                  const SizedBox(
                    height: 10,
                  ),
                  supplierDropdown,
                  const SizedBox(
                    height: 10,
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child:
                            methodDropdown,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child:
                            dateButton,
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PAYMENT LIST
  // ===========================================================================

  Widget _buildPaymentList(
    ThemeData theme,
    List<SupplierPaymentModel>
        payments,
  ) {
    if (payments.isEmpty) {
      return _buildEmptyState(
        theme,
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Payment History',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${payments.length} records',
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
        const SizedBox(
          height: 12,
        ),
        ...payments.map(
          (SupplierPaymentModel payment) =>
              _buildPaymentCard(
            theme,
            payment,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(
    ThemeData theme,
    SupplierPaymentModel payment,
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
          _showPaymentDetails(
            payment,
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color: AppColors
                      .success
                      .withValues(
                    alpha: 0.10,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .payments_outlined,
                  color:
                      AppColors.success,
                ),
              ),
              const SizedBox(
                width: 13,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            payment
                                .supplierName,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Text(
                          _formatCurrency(
                            payment.amount,
                          ),
                          style: theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w800,
                            color:
                                AppColors
                                    .success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            payment
                                .paymentMethod
                                .trim()
                                .isEmpty
                                ? 'Payment'
                                : payment
                                    .paymentMethod,
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
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        const Text(
                          '•',
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Text(
                          DateFormat(
                            'dd MMM yyyy',
                          ).format(
                            payment.date,
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
                      ],
                    ),
                    if (payment
                        .transactionReference
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        'Ref: ${payment.transactionReference}',
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color:
                              AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(
                width: 4,
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected:
                    (String value) {
                  if (value == 'view') {
                    _showPaymentDetails(
                      payment,
                    );
                  } else if (value ==
                      'edit') {
                    _openEditPayment(
                      payment,
                    );
                  } else if (value ==
                      'delete') {
                    _deletePayment(
                      payment,
                    );
                  }
                },
                itemBuilder:
                    (
                  BuildContext context,
                ) =>
                        <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'view',
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      leading: Icon(
                        Icons
                            .visibility_outlined,
                      ),
                      title:
                          Text('View'),
                    ),
                  ),
                  const PopupMenuItem<String>(
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
                  const PopupMenuItem<String>(
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
                        style: TextStyle(
                          color:
                              AppColors.danger,
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
  }

  // ===========================================================================
  // EMPTY / ERROR
  // ===========================================================================

  Widget _buildEmptyState(
    ThemeData theme,
  ) {
    final bool hasFilters =
        _hasActiveFilters;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 44,
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration:
                  BoxDecoration(
                color: AppColors
                    .primary
                    .withValues(
                  alpha: 0.10,
                ),
                shape:
                    BoxShape.circle,
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
            const SizedBox(
              height: 16,
            ),
            Text(
              hasFilters
                  ? 'No payments found'
                  : 'No supplier payments recorded',
              style: theme
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
                  : 'Supplier payment transactions will appear here.',
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
            if (hasFilters)
              OutlinedButton.icon(
                onPressed:
                    _clearFilters,
                icon: const Icon(
                  Icons
                      .filter_alt_off_rounded,
                ),
                label: const Text(
                  'CLEAR FILTERS',
                ),
              )
            else
              FilledButton.icon(
                onPressed:
                    _openAddPayment,
                icon: const Icon(
                  Icons.add_rounded,
                ),
                label: const Text(
                  'ADD PAYMENT',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons
                  .error_outline_rounded,
              size: 56,
              color:
                  AppColors.danger,
            ),
            const SizedBox(
              height: 14,
            ),
            Text(
              _errorMessage ??
                  'Unable to load supplier payments.',
              textAlign:
                  TextAlign.center,
              style: theme
                  .textTheme
                  .bodyLarge,
            ),
            const SizedBox(
              height: 18,
            ),
            FilledButton.icon(
              onPressed:
                  _initialize,
              icon: const Icon(
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

  // ===========================================================================
  // DATE RANGE SHEET
  // ===========================================================================

  Future<void> _showDateRangeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (
        BuildContext sheetContext,
      ) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              20,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Date Filter',
                  style: Theme.of(
                    sheetContext,
                  )
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child:
                          _dateSelectionTile(
                        label:
                            'Start Date',
                        date:
                            _startDate,
                        onPressed:
                            _selectStartDate,
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child:
                          _dateSelectionTile(
                        label:
                            'End Date',
                        date:
                            _endDate,
                        onPressed:
                            _selectEndDate,
                      ),
                    ),
                  ],
                ),
                if (_startDate != null ||
                    _endDate != null) ...[
                  const SizedBox(
                    height: 12,
                  ),
                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _startDate =
                              null;
                          _endDate = null;
                        });

                        Navigator.pop(
                          sheetContext,
                        );
                      },
                      icon: const Icon(
                        Icons.clear_rounded,
                      ),
                      label: const Text(
                        'Clear Date Filter',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dateSelectionTile({
    required String label,
    required DateTime? date,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(
        Icons.calendar_month_outlined,
      ),
      label: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        mainAxisSize:
            MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
            ),
          ),
          Text(
            date == null
                ? 'Select'
                : DateFormat(
                    'dd MMM yyyy',
                  ).format(date),
            overflow:
                TextOverflow.ellipsis,
          ),
        ],
      ),
      style:
          OutlinedButton.styleFrom(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _supplierDropdownValue() {
    if (_selectedSupplierId ==
        'All') {
      return 'All';
    }

    final bool exists =
        _suppliers.any(
      (SupplierModel supplier) =>
          supplier.id ==
          _selectedSupplierId,
    );

    return exists
        ? _selectedSupplierId
        : 'All';
  }

  String _dateFilterLabel() {
    if (_startDate == null &&
        _endDate == null) {
      return 'Date Range';
    }

    if (_startDate != null &&
        _endDate != null) {
      return '${DateFormat('dd/MM/yy').format(_startDate!)}'
          ' - '
          '${DateFormat('dd/MM/yy').format(_endDate!)}';
    }

    if (_startDate != null) {
      return 'From ${DateFormat('dd/MM/yy').format(_startDate!)}';
    }

    return 'Until ${DateFormat('dd/MM/yy').format(_endDate!)}';
  }

  String _formatCurrency(
    double value,
  ) {
    return '₹${NumberFormat('#,##0.00').format(value)}';
  }

  String _cleanError(
    Object error,
  ) {
    final String message =
        error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
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
}

// =============================================================================
// SUMMARY CARD
// =============================================================================

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration:
                  BoxDecoration(
                color: iconColor.withValues(
                  alpha: 0.10,
                ),
                shape:
                    BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
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
                  const SizedBox(
                    height: 4,
                  ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DETAIL TILE
// =============================================================================

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color: theme
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
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
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  style: theme
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w600,
                    color:
                        valueColor,
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