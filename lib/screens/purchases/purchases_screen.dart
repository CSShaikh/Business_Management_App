import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_date_picker.dart';

import '../../core/services/purchase_stock_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_number_format.dart';
import '../../models/ledger_transaction_model.dart';
import '../../models/purchase_model.dart';
import '../../models/supplier_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../services/ledger/supplier_ledger_service.dart';
import 'add_purchase_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({
    super.key,
  });

  @override
  State<PurchasesScreen> createState() =>
      _PurchasesScreenState();
}

class _PurchasesScreenState
    extends State<PurchasesScreen> {
  final SupplierLedgerService _supplierLedgerService =
      SupplierLedgerService();

  final PurchaseStockService _purchaseStockService =
      PurchaseStockService();

  String? _businessId;

  bool _isInitializing = true;

  String _searchQuery = '';

  String _selectedStatus = 'All';

  String _selectedSupplierId = 'All';

  DateTime? _startDate;

  DateTime? _endDate;

  final List<String> _statusFilters = const [
    'All',
    'Paid',
    'Partial',
    'Unpaid',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _initialize();
      },
    );
  }

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  Future<void> _initialize() async {
    try {
      final BusinessProvider businessProvider =
          context.read<BusinessProvider>();

      final PurchaseProvider purchaseProvider =
          context.read<PurchaseProvider>();

      final SupplierProvider supplierProvider =
          context.read<SupplierProvider>();

      await businessProvider.loadBusiness();

      if (!mounted) {
        return;
      }

      final String businessId =
          businessProvider.business?.id.trim() ?? '';

      if (businessId.isEmpty) {
        setState(() {
          _isInitializing = false;
          _businessId = null;
        });

        return;
      }

      _businessId = businessId;

      purchaseProvider.setBusinessId(
        businessId,
      );

      supplierProvider.setBusinessId(
        businessId,
      );

      await Future.wait([
        purchaseProvider.loadAndWatchPurchases(
          businessId: businessId,
        ),
        supplierProvider.loadAndWatchSuppliers(
          businessId: businessId,
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _refresh() async {
    final String? businessId =
        _businessId;

    if (businessId == null ||
        businessId.trim().isEmpty) {
      await _initialize();
      return;
    }

    final PurchaseProvider purchaseProvider =
        context.read<PurchaseProvider>();

    final SupplierProvider supplierProvider =
        context.read<SupplierProvider>();

    try {
      await Future.wait([
        purchaseProvider.refresh(),
        supplierProvider.refresh(),
      ]);
    } catch (_) {
      // Providers keep their own error state.
    }
  }

  // ===========================================================================
  // FILTERING
  // ===========================================================================

  List<PurchaseModel> _getFilteredPurchases(
    List<PurchaseModel> purchases,
  ) {
    final String query =
        _searchQuery.trim().toLowerCase();

    return purchases.where(
      (purchase) {
        // ---------------------------------------------------------------
        // SEARCH
        // ---------------------------------------------------------------

        if (query.isNotEmpty) {
          final bool matchesSearch =
              purchase.supplierName
                      .toLowerCase()
                      .contains(query) ||
                  purchase.supplierId
                      .toLowerCase()
                      .contains(query) ||
                  purchase.notes
                      .toLowerCase()
                      .contains(query) ||
                  purchase.paymentMethod
                      .toLowerCase()
                      .contains(query);

          if (!matchesSearch) {
            return false;
          }
        }

        // ---------------------------------------------------------------
        // PAYMENT STATUS
        // ---------------------------------------------------------------

        if (_selectedStatus != 'All') {
          final String status =
              purchase.paymentStatus
                  .trim()
                  .toLowerCase();

          if (status !=
              _selectedStatus.toLowerCase()) {
            return false;
          }
        }

        // ---------------------------------------------------------------
        // SUPPLIER
        // ---------------------------------------------------------------

        if (_selectedSupplierId != 'All') {
          if (purchase.supplierId.trim() !=
              _selectedSupplierId.trim()) {
            return false;
          }
        }

        // ---------------------------------------------------------------
        // START DATE
        // ---------------------------------------------------------------

        if (_startDate != null) {
          final DateTime start = DateTime(
            _startDate!.year,
            _startDate!.month,
            _startDate!.day,
          );

          final DateTime purchaseDate = DateTime(
            purchase.date.year,
            purchase.date.month,
            purchase.date.day,
          );

          if (purchaseDate.isBefore(start)) {
            return false;
          }
        }

        // ---------------------------------------------------------------
        // END DATE
        // ---------------------------------------------------------------

        if (_endDate != null) {
          final DateTime end = DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
          );

          final DateTime purchaseDate = DateTime(
            purchase.date.year,
            purchase.date.month,
            purchase.date.day,
          );

          if (purchaseDate.isAfter(end)) {
            return false;
          }
        }

        return true;
      },
    ).toList();
  }

  // ===========================================================================
  // ADD PURCHASE
  // ===========================================================================

  Future<void> _openAddPurchase() async {
    final bool? result =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) =>
            const AddPurchaseScreen(),
      ),
    );

    if (result == true) {
      await _refresh();
    }
  }

  // ===========================================================================
  // EDIT PURCHASE
  // ===========================================================================

  Future<void> _openEditPurchase(
    PurchaseModel purchase,
  ) async {
    final bool? result =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) =>
            AddPurchaseScreen(
          purchase: purchase,
        ),
      ),
    );

    if (result == true) {
      await _refresh();
    }
  }

  // ===========================================================================
  // DELETE PURCHASE
  // ===========================================================================

  Future<void> _deletePurchase(
    PurchaseModel purchase,
  ) async {
    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Purchase?',
          ),
          content: Text(
            'This will delete the purchase record of '
            '${purchase.supplierName}. '
            'Stock received from this purchase will be restored and '
            'the supplier ledger entry will be reversed. '
            'This action cannot be undone.',
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

    if (confirmed != true ||
        !mounted) {
      return;
    }

    final String? businessId =
        _businessId;

    if (businessId == null ||
        businessId.trim().isEmpty) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );

      return;
    }

    final String normalizedBusinessId =
        businessId.trim();

    final String purchaseId =
        purchase.id.trim();

    if (purchaseId.isEmpty) {
      _showMessage(
        'Invalid purchase ID.',
        isError: true,
      );

      return;
    }

    final PurchaseProvider
        purchaseProvider =
        context.read<PurchaseProvider>();

    bool stockReversed = false;

    final List<LedgerTransactionModel>
        createdLedgerReversals =
        <LedgerTransactionModel>[];

    try {
      // -----------------------------------------------------------------------
      // 1. CAPTURE CURRENT SUPPLIER LEDGER STATE
      // -----------------------------------------------------------------------
      //
      // We keep the existing transaction IDs so that rollback can remove only
      // the reversal transaction created by this delete attempt.
      //
      final String supplierId =
          purchase.supplierId.trim();

      final Set<String>
          existingSupplierTransactionIds =
          <String>{};

      if (supplierId.isNotEmpty) {
        final List<LedgerTransactionModel>
            existingTransactions =
            await _supplierLedgerService
                .getSupplierTransactions(
          businessId:
              normalizedBusinessId,
          supplierId: supplierId,
        );

        existingSupplierTransactionIds.addAll(
          existingTransactions
              .map(
                (transaction) =>
                    transaction.id.trim(),
              )
              .where(
                (id) => id.isNotEmpty,
              ),
        );
      }

      // -----------------------------------------------------------------------
      // 2. RESTORE STOCK
      // -----------------------------------------------------------------------
      //
      // The purchase document is not deleted until the stock has been
      // successfully restored.
      //
      await _purchaseStockService
          .reversePurchaseStock(
        purchase: purchase,
      );

      stockReversed = true;

      // -----------------------------------------------------------------------
      // 3. REVERSE SUPPLIER LEDGER
      // -----------------------------------------------------------------------
      //
      // Only supplier-linked purchases need supplier ledger correction.
      // SupplierLedgerService safely reverses only the active PURCHASE entry
      // belonging to this purchase.
      //
      if (supplierId.isNotEmpty) {
        await _supplierLedgerService
            .reverseActivePurchaseLedger(
          purchase: purchase,
        );

        final List<LedgerTransactionModel>
            updatedTransactions =
            await _supplierLedgerService
                .getSupplierTransactions(
          businessId:
              normalizedBusinessId,
          supplierId: supplierId,
        );

        for (final LedgerTransactionModel
            transaction in updatedTransactions) {
          final String transactionId =
              transaction.id.trim();

          final String type =
              transaction.transactionType
                  .trim()
                  .toUpperCase();

          if (transactionId.isEmpty ||
              existingSupplierTransactionIds
                  .contains(transactionId)) {
            continue;
          }

          if (transaction.referenceId
                      .trim() ==
                  purchaseId &&
              type ==
                  SupplierLedgerService
                      .purchaseReversalType) {
            createdLedgerReversals.add(
              transaction,
            );
          }
        }
      }

      // -----------------------------------------------------------------------
      // 4. DELETE PURCHASE DOCUMENT
      // -----------------------------------------------------------------------
      final bool deleted =
          await purchaseProvider.deletePurchase(
        purchaseId: purchaseId,
        businessId: normalizedBusinessId,
      );

      if (!deleted) {
        throw StateError(
          purchaseProvider.errorMessage
                      ?.trim()
                      .isNotEmpty ==
                  true
              ? purchaseProvider
                  .errorMessage!
                  .trim()
              : 'Unable to delete the purchase record.',
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        createdLedgerReversals.isEmpty
            ? 'Purchase deleted and stock restored successfully.'
            : 'Purchase deleted, stock restored and supplier ledger reversed successfully.',
      );
    } catch (e) {
      // -----------------------------------------------------------------------
      // ROLLBACK SUPPLIER LEDGER
      // -----------------------------------------------------------------------
      //
      // If purchase deletion fails after a supplier ledger reversal was
      // created, remove only the reversal transactions created during this
      // delete attempt.
      //
      for (final LedgerTransactionModel
          transaction
          in createdLedgerReversals.reversed) {
        try {
          await _supplierLedgerService
              .deleteTransaction(
            businessId:
                normalizedBusinessId,
            transactionId:
                transaction.id,
          );
        } catch (_) {
          // Preserve the original operation error.
        }
      }

      // -----------------------------------------------------------------------
      // ROLLBACK STOCK
      // -----------------------------------------------------------------------
      //
      // Restore the original stock state when stock had already been reversed.
      //
      if (stockReversed) {
        try {
          await _purchaseStockService
              .processPurchaseStock(
            purchase: purchase,
          );
        } catch (_) {
          // Preserve the original operation error.
        }
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to delete purchase: '
        '${_cleanError(e)}',
        isError: true,
      );
    }
  }

  // ===========================================================================
  // DETAILS
  // ===========================================================================

  Future<void> _openPurchaseDetails(
    PurchaseModel purchase,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _PurchaseDetailsSheet(
          purchase: purchase,
        );
      },
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Purchases',
          ),
        ),
        body: const Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_businessId == null ||
        _businessId!.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Purchases',
          ),
        ),
        body:
            _buildNoBusinessState(theme),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Purchases',
          style: TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: Consumer2<
          PurchaseProvider,
          SupplierProvider>(
        builder: (
          context,
          purchaseProvider,
          supplierProvider,
          child,
        ) {
          final List<PurchaseModel>
              purchases =
              purchaseProvider.purchases;

          if (purchaseProvider.isLoading &&
              purchases.isEmpty) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (purchaseProvider.errorMessage !=
                  null &&
              purchases.isEmpty) {
            return _buildErrorState(
              theme,
              purchaseProvider
                  .errorMessage!,
            );
          }

          final List<PurchaseModel>
              filteredPurchases =
              _getFilteredPurchases(
            purchases,
          );

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                110,
              ),
              children: [
                _buildHeader(
                  theme,
                  purchases,
                ),
                const SizedBox(
                  height: 20,
                ),
                _buildSearchField(
                  theme,
                ),
                const SizedBox(
                  height: 12,
                ),
                _buildFilters(
                  theme,
                  supplierProvider
                      .suppliers,
                ),
                const SizedBox(
                  height: 20,
                ),
                _buildPurchaseList(
                  theme,
                  purchases,
                  filteredPurchases,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _openAddPurchase,
        icon: const Icon(
          Icons.add_shopping_cart_rounded,
        ),
        label: const Text(
          'Add Purchase',
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(
    ThemeData theme,
    List<PurchaseModel> purchases,
  ) {
    double total = 0;

    double paid = 0;

    double outstanding = 0;

    int partial = 0;

    int unpaid = 0;

    for (final PurchaseModel purchase
        in purchases) {
      total += purchase.total;

      paid += purchase.paidAmount;

      final double pending =
          purchase.total -
              purchase.paidAmount;

      if (pending > 0) {
        outstanding += pending;
      }

      if (purchase.paymentStatus
              .toLowerCase() ==
          'partial') {
        partial++;
      }

      if (purchase.paymentStatus
              .toLowerCase() ==
          'unpaid') {
        unpaid++;
      }
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Purchase Management',
          style: theme
              .textTheme
              .headlineSmall
              ?.copyWith(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        const SizedBox(
          height: 5,
        ),
        Text(
          'Track purchases, supplier payments and outstanding amounts.',
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
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool compact =
                constraints.maxWidth <
                    760;

            final List<Widget>
                cards = [
              _buildSummaryCard(
                theme,
                title:
                    'Total Purchase',
                value:
                    _formatCurrency(total),
                icon: Icons
                    .shopping_cart_checkout_rounded,
                color:
                    AppColors.primary,
              ),
              _buildSummaryCard(
                theme,
                title: 'Paid',
                value:
                    _formatCurrency(paid),
                icon: Icons
                    .check_circle_outline_rounded,
                color:
                    AppColors.success,
              ),
              _buildSummaryCard(
                theme,
                title:
                    'Outstanding',
                value:
                    _formatCurrency(
                  outstanding,
                ),
                icon: Icons
                    .pending_actions_rounded,
                color:
                    AppColors.warning,
              ),
              _buildSummaryCard(
                theme,
                title:
                    'Partial / Unpaid',
                value:
                    '${partial + unpaid}',
                icon: Icons
                    .receipt_long_outlined,
                color:
                    AppColors.danger,
              ),
            ];

            if (compact) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child:
                            cards[0],
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child:
                            cards[1],
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child:
                            cards[2],
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child:
                            cards[3],
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child:
                      cards[0],
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child:
                      cards[1],
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child:
                      cards[2],
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child:
                      cards[3],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // SUMMARY CARD
  // ===========================================================================

  Widget _buildSummaryCard(
    ThemeData theme, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(
                color:
                    color.withValues(
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
      ),
    );
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Widget _buildSearchField(
    ThemeData theme,
  ) {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery =
              value.trim();
        });
      },
      decoration:
          InputDecoration(
        hintText:
            'Search supplier, notes or payment method...',
        prefixIcon:
            const Icon(
          Icons.search_rounded,
        ),
        suffixIcon:
            _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip:
                        'Clear',
                    onPressed: () {
                      setState(() {
                        _searchQuery =
                            '';
                      });
                    },
                    icon:
                        const Icon(
                      Icons
                          .clear_rounded,
                    ),
                  ),
        filled: true,
        fillColor: theme
            .colorScheme
            .surface,
      ),
    );
  }

  // ===========================================================================
  // FILTERS
  // ===========================================================================

  Widget _buildFilters(
    ThemeData theme,
    List<SupplierModel> suppliers,
  ) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final bool stacked =
            constraints.maxWidth <
                700;

        final Widget statusDropdown =
            DropdownButtonFormField<
                String>(
          initialValue:
              _selectedStatus,
          isExpanded: true,
          decoration:
              const InputDecoration(
            labelText:
                'Payment Status',
            prefixIcon:
                Icon(
              Icons
                  .payments_outlined,
            ),
          ),
          items:
              _statusFilters.map(
            (status) {
              return DropdownMenuItem<
                  String>(
                value: status,
                child: Text(
                  status,
                ),
              );
            },
          ).toList(),
          onChanged:
              (value) {
            if (value ==
                null) {
              return;
            }

            setState(() {
              _selectedStatus =
                  value;
            });
          },
        );

        final List<
                DropdownMenuItem<
                    String>>
            supplierItems = [
          const DropdownMenuItem<
              String>(
            value: 'All',
            child: Text(
              'All Suppliers',
            ),
          ),
          ...suppliers.map(
            (supplier) {
              return DropdownMenuItem<
                  String>(
                value:
                    supplier.id,
                child: Text(
                  supplier.name,
                  overflow:
                      TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ];

        final bool selectedSupplierStillExists =
            _selectedSupplierId ==
                    'All' ||
                suppliers.any(
                  (supplier) =>
                      supplier.id ==
                      _selectedSupplierId,
                );

        if (!selectedSupplierStillExists) {
          WidgetsBinding.instance
              .addPostFrameCallback(
            (_) {
              if (!mounted) {
                return;
              }

              setState(() {
                _selectedSupplierId =
                    'All';
              });
            },
          );
        }

        final Widget supplierDropdown =
            DropdownButtonFormField<
                String>(
          initialValue:
              selectedSupplierStillExists
                  ? _selectedSupplierId
                  : 'All',
          isExpanded: true,
          decoration:
              const InputDecoration(
            labelText:
                'Supplier',
            prefixIcon:
                Icon(
              Icons
                  .person_outline_rounded,
            ),
          ),
          items:
              supplierItems,
          onChanged:
              (value) {
            if (value ==
                null) {
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
          onPressed:
              _selectDateRange,
          icon: const Icon(
            Icons
                .date_range_rounded,
          ),
          label: Text(
            _dateRangeLabel,
          ),
        );

        if (stacked) {
          return Column(
            children: [
              statusDropdown,
              const SizedBox(
                height: 12,
              ),
              supplierDropdown,
              const SizedBox(
                height: 12,
              ),
              Align(
                alignment:
                    Alignment.centerLeft,
                child:
                    dateButton,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  statusDropdown,
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
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 4,
              ),
              child:
                  dateButton,
            ),
          ],
        );
      },
    );
  }

  String get _dateRangeLabel {
    if (_startDate == null &&
        _endDate == null) {
      return 'Date Range';
    }

    if (_startDate != null &&
        _endDate != null) {
      return '${DateFormat('dd MMM yyyy').format(_startDate!)}'
          ' - '
          '${DateFormat('dd MMM yyyy').format(_endDate!)}';
    }

    if (_startDate != null) {
      return 'From ${DateFormat('dd MMM yyyy').format(_startDate!)}';
    }

    return 'Until ${DateFormat('dd MMM yyyy').format(_endDate!)}';
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange?
        selectedRange =
        await AppDatePicker.showDateRangePicker(
      context: context,
      
      initialEntryMode: DatePickerEntryMode.calendar,
      firstDate: DateTime(
        2020,
        1,
        1,
      ),
      lastDate: DateTime(
        2100,
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
              : null,
    );

    if (!mounted ||
        selectedRange == null) {
      return;
    }

    setState(() {
      _startDate =
          selectedRange.start;

      _endDate =
          selectedRange.end;
    });
  }

  // ===========================================================================
  // PURCHASE LIST
  // ===========================================================================

  Widget _buildPurchaseList(
    ThemeData theme,
    List<PurchaseModel> allPurchases,
    List<PurchaseModel>
        filteredPurchases,
  ) {
    if (allPurchases.isEmpty) {
      return _buildEmptyState(
        theme,
        title:
            'No purchases yet',
        subtitle:
            'Add your first purchase to start tracking supplier stock and payables.',
      );
    }

    if (filteredPurchases.isEmpty) {
      return _buildEmptyState(
        theme,
        title:
            'No matching purchases',
        subtitle:
            'Try changing your search or filters.',
      );
    }

    return Column(
      children:
          filteredPurchases.map(
        (purchase) {
          return Padding(
            padding:
                const EdgeInsets.only(
              bottom: 12,
            ),
            child:
                _buildPurchaseCard(
              theme,
              purchase,
            ),
          );
        },
      ).toList(),
    );
  }

  // ===========================================================================
  // PURCHASE CARD
  // ===========================================================================

  Widget _buildPurchaseCard(
    ThemeData theme,
    PurchaseModel purchase,
  ) {
    final double outstanding =
        (purchase.total -
                purchase.paidAmount)
            .clamp(
      0,
      double.infinity,
    );

    final String status =
        purchase.paymentStatus
            .trim();

    final Color statusColor =
        _statusColor(status);

    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            _openPurchaseDetails(
          purchase,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(
            16,
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration:
                        BoxDecoration(
                      color: AppColors
                          .primary
                          .withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        13,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons
                          .shopping_cart_rounded,
                      color:
                          AppColors
                              .primary,
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
                          purchase
                                  .supplierName
                                  .trim()
                                  .isEmpty
                              ? 'Unknown Supplier'
                              : purchase
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
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(
                            purchase.date,
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
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  PopupMenuButton<
                      String>(
                    tooltip:
                        'Purchase actions',
                    onSelected:
                        (value) {
                      if (value ==
                          'edit') {
                        _openEditPurchase(
                          purchase,
                        );
                      } else if (value ==
                          'delete') {
                        _deletePurchase(
                          purchase,
                        );
                      }
                    },
                    itemBuilder:
                        (context) {
                      return const [
                        PopupMenuItem<
                            String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons
                                    .edit_outlined,
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Text(
                                'Edit',
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem<
                            String>(
                          value:
                              'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons
                                    .delete_outline_rounded,
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Text(
                                'Delete',
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(
                height: 14,
              ),
              const Divider(
                height: 1,
              ),
              const SizedBox(
                height: 14,
              ),
              LayoutBuilder(
                builder: (
                  context,
                  constraints,
                ) {
                  final bool compact =
                      constraints
                              .maxWidth <
                          650;

                  final Widget
                      totalBlock =
                      _purchaseAmountBlock(
                    theme,
                    label:
                        'Total',
                    value:
                        _formatCurrency(
                      purchase.total,
                    ),
                  );

                  final Widget
                      paidBlock =
                      _purchaseAmountBlock(
                    theme,
                    label:
                        'Paid',
                    value:
                        _formatCurrency(
                      purchase
                          .paidAmount,
                    ),
                  );

                  final Widget
                      outstandingBlock =
                      _purchaseAmountBlock(
                    theme,
                    label:
                        'Outstanding',
                    value:
                        _formatCurrency(
                      outstanding,
                    ),
                  );

                  if (compact) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child:
                                  totalBlock,
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            Expanded(
                              child:
                                  paidBlock,
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child:
                                  outstandingBlock,
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            Expanded(
                              child:
                                  _statusChip(
                                status,
                                statusColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child:
                            totalBlock,
                      ),
                      Expanded(
                        child:
                            paidBlock,
                      ),
                      Expanded(
                        child:
                            outstandingBlock,
                      ),
                      _statusChip(
                        status,
                        statusColor,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _purchaseAmountBlock(
    ThemeData theme, {
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
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
          height: 4,
        ),
        Text(
          value,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: theme
              .textTheme
              .titleSmall
              ?.copyWith(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(
    String status,
    Color color,
  ) {
    final String label =
        status.trim().isEmpty
            ? 'Unknown'
            : status;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(
          10,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }

  Color _statusColor(
    String status,
  ) {
    switch (status
        .trim()
        .toLowerCase()) {
      case 'paid':
        return AppColors.success;

      case 'partial':
        return AppColors.warning;

      case 'unpaid':
        return AppColors.danger;

      default:
        return AppColors.info;
    }
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmptyState(
    ThemeData theme, {
    required String title,
    required String subtitle,
  }) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          28,
        ),
        child: Column(
          children: [
            Icon(
              Icons
                  .shopping_cart_outlined,
              size: 52,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(
              height: 14,
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
              height: 6,
            ),
            Text(
              subtitle,
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
    );
  }

  // ===========================================================================
  // NO BUSINESS
  // ===========================================================================

  Widget _buildNoBusinessState(
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .business_outlined,
              size: 56,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Business information is not available.',
              textAlign:
                  TextAlign.center,
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
            Text(
              'Please complete your business setup before managing purchases.',
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
            FilledButton.icon(
              onPressed:
                  _initialize,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
                  const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================

  Widget _buildErrorState(
    ThemeData theme,
    String message,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .error_outline_rounded,
              size: 56,
              color:
                  AppColors.danger,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Unable to load purchases',
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
            const SizedBox(
              height: 18,
            ),
            FilledButton.icon(
              onPressed:
                  _refresh,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
                  const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PURCHASE DETAILS MESSAGE
  // ===========================================================================

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
          content:
              Text(message),
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              isError
                  ? AppColors.danger
                  : AppColors.success,
        ),
      );
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

  // ===========================================================================
  // CURRENCY
  // ===========================================================================

  String _formatCurrency(
    double value,
  ) {
    return AppNumberFormat.amount(value);
  }
}

// =============================================================================
// PURCHASE DETAILS SHEET
// =============================================================================

class _PurchaseDetailsSheet
    extends StatelessWidget {
  final PurchaseModel purchase;

  const _PurchaseDetailsSheet({
    required this.purchase,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final double outstanding =
        (purchase.total -
                purchase.paidAmount)
            .clamp(
      0,
      double.infinity,
    );

    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Purchase Details',
                style: theme
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: 6,
              ),
              Text(
                DateFormat(
                  'dd MMM yyyy, hh:mm a',
                ).format(
                  purchase.date,
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
              const SizedBox(
                height: 20,
              ),
              _DetailSection(
                title: 'Supplier',
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    _InfoRow(
                      icon: Icons
                          .person_outline_rounded,
                      label:
                          'Supplier',
                      value:
                          purchase
                              .supplierName,
                    ),
                    if (purchase
                        .supplierId
                        .trim()
                        .isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          top: 12,
                        ),
                        child:
                            _InfoRow(
                          icon: Icons
                              .badge_outlined,
                          label:
                              'Supplier ID',
                          value:
                              purchase
                                  .supplierId,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              _DetailSection(
                title: 'Items',
                child: Column(
                  children: purchase
                      .items
                      .map(
                    (item) {
                      return Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          bottom: 14,
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Expanded(
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    item
                                        .productName,
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ),
                                  Text(
                                    '${_formatNumber(item.quantity)} ${item.unit} × ${_formatCurrency(item.purchaseRate)}',
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
                              width: 12,
                            ),
                            Text(
                              _formatCurrency(
                                item.total,
                              ),
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ).toList(),
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              _DetailSection(
                title: 'Payment Summary',
                child: Column(
                  children: [
                    _SummaryRow(
                      label:
                          'Subtotal',
                      value:
                          _formatCurrency(
                        purchase
                            .subtotal,
                      ),
                    ),
                    if (purchase
                            .discount >
                        0)
                      _SummaryRow(
                        label:
                            'Discount',
                        value:
                            '-${_formatCurrency(purchase.discount)}',
                      ),
                    if (purchase
                            .tax >
                        0)
                      _SummaryRow(
                        label:
                            'Tax',
                        value:
                            _formatCurrency(
                          purchase.tax,
                        ),
                      ),
                    const Divider(
                      height: 20,
                    ),
                    _SummaryRow(
                      label:
                          'Total',
                      value:
                          _formatCurrency(
                        purchase
                            .total,
                      ),
                      bold: true,
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    _SummaryRow(
                      label:
                          'Paid',
                      value:
                          _formatCurrency(
                        purchase
                            .paidAmount,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    _SummaryRow(
                      label:
                          'Outstanding',
                      value:
                          _formatCurrency(
                        outstanding,
                      ),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              _DetailSection(
                title: 'Payment',
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons
                          .payments_outlined,
                      label:
                          'Payment Status',
                      value:
                          purchase
                              .paymentStatus,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    _InfoRow(
                      icon: Icons
                          .account_balance_wallet_outlined,
                      label:
                          'Payment Method',
                      value: purchase
                              .paymentMethod
                              .trim()
                              .isEmpty
                          ? 'Not specified'
                          : purchase
                              .paymentMethod,
                    ),
                  ],
                ),
              ),
              if (purchase.notes
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 16,
                ),
                _DetailSection(
                  title: 'Notes',
                  child: Text(
                    purchase.notes,
                    style: theme
                        .textTheme
                        .bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DETAIL SECTION
// =============================================================================

class _DetailSection
    extends StatelessWidget {
  final String title;

  final Widget child;

  const _DetailSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
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
            const SizedBox(
              height: 14,
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// INFO ROW
// =============================================================================

class _InfoRow
    extends StatelessWidget {
  final IconData icon;

  final String label;

  final String value;

  const _InfoRow({
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

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: theme
              .colorScheme
              .primary,
        ),
        const SizedBox(
          width: 10,
        ),
        SizedBox(
          width: 110,
          child: Text(
            label,
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
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Text(
            value,
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
    );
  }
}

// =============================================================================
// SUMMARY ROW
// =============================================================================

class _SummaryRow
    extends StatelessWidget {
  final String label;

  final String value;

  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme
                .textTheme
                .bodyMedium
                ?.copyWith(
              fontWeight:
                  bold
                      ? FontWeight.w800
                      : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: theme
              .textTheme
              .bodyMedium
              ?.copyWith(
            fontWeight:
                bold
                    ? FontWeight.w800
                    : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// HELPERS
// =============================================================================

String _formatCurrency(
  double value,
) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(value);
}

String _formatNumber(
  double value,
) {
  if (value ==
      value.roundToDouble()) {
    return value
        .toInt()
        .toString();
  }

  return value.toStringAsFixed(2);
}
