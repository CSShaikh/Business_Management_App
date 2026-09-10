import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/purchase_stock_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/purchase_model.dart';
import '../../models/supplier_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/supplier_provider.dart';
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
  final PurchaseStockService
      _purchaseStockService =
      PurchaseStockService();

  String? _businessId;

  bool _isInitializing = true;
  bool _isRefreshing = false;

  String _searchQuery = '';

  String _statusFilter = 'All';

  String _supplierFilter = 'All';

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        _initialize();
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isInitializing = true;
    });

    try {
      final BusinessProvider
          businessProvider =
          context.read<
              BusinessProvider>();

      String? businessId =
          businessProvider.business?.id;

      if (businessId == null ||
          businessId.trim().isEmpty) {
        await businessProvider.loadBusiness();

        businessId =
            businessProvider.business?.id;
      }

      if (businessId == null ||
          businessId.trim().isEmpty) {
        throw StateError(
          'Business information is not available.',
        );
      }

      _businessId =
          businessId.trim();

      final PurchaseProvider
          purchaseProvider =
          // ignore: use_build_context_synchronously
          context.read<
              PurchaseProvider>();

      purchaseProvider
          .setBusinessId(
        _businessId!,
      );

      await purchaseProvider
          .loadAndWatchPurchases(
        businessId:
            _businessId,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to load purchases: '
        '${_cleanError(e)}',
        isError: true,
      );
    } finally {
      if (!mounted) {
        // ignore: control_flow_in_finally
        return;
      }

      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing) {
      return;
    }

    final String? businessId =
        _businessId;

    if (businessId == null ||
        businessId.trim().isEmpty) {
      await _initialize();
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      await context
          .read<PurchaseProvider>()
          .loadPurchases(
        businessId:
            businessId,
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to refresh purchases: '
          '${_cleanError(e)}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  List<PurchaseModel> _filteredPurchases(
    List<PurchaseModel> purchases,
  ) {
    final String query =
        _searchQuery.trim().toLowerCase();

    return purchases.where(
      (PurchaseModel purchase) {
        if (_statusFilter != 'All' &&
            purchase.paymentStatus
                    .trim()
                    .toLowerCase() !=
                _statusFilter
                    .trim()
                    .toLowerCase()) {
          return false;
        }

        if (_supplierFilter != 'All' &&
            purchase.supplierId !=
                _supplierFilter) {
          return false;
        }

        if (_fromDate != null) {
          final DateTime from =
              DateTime(
            _fromDate!.year,
            _fromDate!.month,
            _fromDate!.day,
          );

          final DateTime purchaseDate =
              DateTime(
            purchase.date.year,
            purchase.date.month,
            purchase.date.day,
          );

          if (purchaseDate
              .isBefore(from)) {
            return false;
          }
        }

        if (_toDate != null) {
          final DateTime to =
              DateTime(
            _toDate!.year,
            _toDate!.month,
            _toDate!.day,
            23,
            59,
            59,
            999,
          );

          if (purchase.date.isAfter(to)) {
            return false;
          }
        }

        if (query.isEmpty) {
          return true;
        }

        final String supplierName =
            purchase.supplierName
                .toLowerCase();

        final String notes =
            purchase.notes
                .toLowerCase();

        final String paymentMethod =
            purchase.paymentMethod
                .toLowerCase();

        final bool itemMatch =
            purchase.items.any(
          (PurchaseItemModel item) {
            return item.productName
                    .toLowerCase()
                    .contains(query) ||
                item.productId
                    .toLowerCase()
                    .contains(query);
          },
        );

        return supplierName
                .contains(query) ||
            notes.contains(query) ||
            paymentMethod
                .contains(query) ||
            purchase.paymentStatus
                .toLowerCase()
                .contains(query) ||
            itemMatch;
      },
    ).toList();
  }

  Future<void> _selectFromDate() async {
    final DateTime? date =
        await showDatePicker(
      context: context,
      initialDate:
          _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date == null ||
        !mounted) {
      return;
    }

    setState(() {
      _fromDate = date;

      if (_toDate != null &&
          _toDate!.isBefore(date)) {
        _toDate = date;
      }
    });
  }

  Future<void> _selectToDate() async {
    final DateTime? date =
        await showDatePicker(
      context: context,
      initialDate:
          _toDate ?? DateTime.now(),
      firstDate: _fromDate ??
          DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date == null ||
        !mounted) {
      return;
    }

    setState(() {
      _toDate = date;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _statusFilter = 'All';
      _supplierFilter = 'All';
      _fromDate = null;
      _toDate = null;
    });
  }

  Future<void> _openAddPurchase() async {
    final bool? result =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) =>
            const AddPurchaseScreen(),
      ),
    );

    if (result == true &&
        mounted) {
      await _refresh();
    }
  }

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

    if (result == true &&
        mounted) {
      await _refresh();
    }
  }

  Future<void> _deletePurchase(
    PurchaseModel purchase,
  ) async {
    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Delete Purchase?',
          ),
          content: Text(
            'This will permanently delete the '
            'purchase from ${purchase.supplierName} '
            'and reverse the stock added by this purchase.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
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
              child:
                  const Text('Delete'),
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

    if (purchase.id.trim().isEmpty) {
      _showMessage(
        'Purchase ID is not available.',
        isError: true,
      );
      return;
    }

    if (purchase.businessId.trim() !=
        businessId.trim()) {
      _showMessage(
        'This purchase does not belong to the current business.',
        isError: true,
      );
      return;
    }

    final PurchaseProvider
        purchaseProvider =
        context.read<PurchaseProvider>();

    final List<PurchaseItemModel>
        reversedItems =
        <PurchaseItemModel>[];

    bool deleteAttempted = false;

    try {
      /*
       * IMPORTANT:
       *
       * Purchase document delete se pehle stock reverse
       * karna zaroori hai.
       *
       * Har successful stock reversal ko list mein store
       * kar rahe hain. Agar beech mein koi item fail ho jaye
       * to pehle reverse kiye gaye items restore kar diye
       * jayenge.
       */
      for (final PurchaseItemModel item
          in purchase.items) {
        if (item.productId
            .trim()
            .isEmpty) {
          throw ArgumentError(
            'Purchase contains an invalid product ID.',
          );
        }

        if (item.quantity <= 0) {
          throw ArgumentError(
            'Purchase contains an invalid quantity '
            'for ${item.productName}.',
          );
        }

        if (item.purchaseRate < 0) {
          throw ArgumentError(
            'Purchase contains an invalid purchase rate '
            'for ${item.productName}.',
          );
        }

        await _purchaseStockService
            .stockRepository
            .stockOut(
          businessId:
              businessId,
          productId:
              item.productId,
          quantity:
              item.quantity,
          unitCost:
              item.purchaseRate,
          referenceId:
              purchase.id,
          date:
              DateTime.now(),
          notes:
              'Stock reversed for deleted purchase',
        );

        reversedItems.add(item);
      }

      /*
       * Stock successfully reverse ho gaya.
       * Ab actual purchase document delete karo.
       */
      deleteAttempted = true;

      await purchaseProvider
          .deletePurchase(
        purchaseId:
            purchase.id,
        businessId:
            businessId,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Purchase deleted successfully and stock reversed.',
      );
    } catch (e) {
      /*
       * Agar purchase document delete attempt nahi hua,
       * iska matlab stock reversal ke beech failure hua.
       *
       * Successfully reversed stock ko restore karo.
       */
      if (!deleteAttempted &&
          reversedItems.isNotEmpty) {
        await _restoreReversedItems(
          purchase,
          reversedItems,
        );
      }

      /*
       * Agar delete attempt ke baad error aaya,
       * provider delete fail hua hoga.
       *
       * Inner stock state ko restore karo.
       */
      if (deleteAttempted &&
          reversedItems.isNotEmpty) {
        await _restoreReversedItems(
          purchase,
          reversedItems,
        );
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

  Future<void> _restoreReversedItems(
    PurchaseModel purchase,
    List<PurchaseItemModel> items,
  ) async {
    for (final PurchaseItemModel item
        in items.reversed) {
      try {
        await _purchaseStockService
            .stockRepository
            .stockIn(
          businessId:
              purchase.businessId,
          productId:
              item.productId,
          quantity:
              item.quantity,
          unitCost:
              item.purchaseRate,
          referenceId:
              purchase.id,
          date:
              DateTime.now(),
          notes:
              'Rollback of failed purchase deletion',
        );
      } catch (_) {
        /*
         * Original error ko preserve karna important hai.
         * Individual stock repository transaction already
         * protects the product stock from invalid values.
         */
      }
    }
  }

  Future<void> _openPurchaseDetails(
    PurchaseModel purchase,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (
        BuildContext context,
      ) {
        return _PurchaseDetailsSheet(
          purchase: purchase,
          onEdit: () {
            Navigator.pop(
              context,
            );

            _openEditPurchase(
              purchase,
            );
          },
        );
      },
    );
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
          content:
              Text(message),
          backgroundColor:
              isError
                  ? AppColors.danger
                  : null,
        ),
      );
  }

  String _cleanError(Object error) {
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

  String _currency(
    double value,
  ) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  @override
  Widget build(
    BuildContext context,
  ) {


    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title:
              const Text('Purchases'),
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
          title:
              const Text('Purchases'),
        ),
        body: _buildErrorState(
          context,
          'Business information is not available.',
        ),
      );
    }

    return Consumer2<
        PurchaseProvider,
        SupplierProvider>(
      builder: (
        BuildContext context,
        PurchaseProvider purchaseProvider,
        SupplierProvider supplierProvider,
        Widget? child,
      ) {
        final List<PurchaseModel>
            purchases =
            _filteredPurchases(
          purchaseProvider.purchases,
        );

        final double total =
            purchases.fold<double>(
          0,
          (
            double sum,
            PurchaseModel purchase,
          ) =>
              sum + purchase.total,
        );

        final double paid =
            purchases.fold<double>(
          0,
          (
            double sum,
            PurchaseModel purchase,
          ) =>
              sum +
              purchase.paidAmount,
        );

        final double outstanding =
            purchases.fold<double>(
          0,
          (
            double sum,
            PurchaseModel purchase,
          ) {
            final double value =
                purchase.total -
                    purchase.paidAmount;

            return sum +
                (value < 0
                    ? 0
                    : value);
          },
        );

        return Scaffold(
          appBar: AppBar(
            title:
                const Text(
              'Purchases',
            ),
            actions: <Widget>[
              IconButton(
                tooltip:
                    'Refresh',
                onPressed:
                    _isRefreshing
                        ? null
                        : _refresh,
                icon:
                    _isRefreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Icon(
                            Icons
                                .refresh_rounded,
                          ),
              ),
            ],
          ),
          floatingActionButton:
              FloatingActionButton
                  .extended(
            onPressed:
                _openAddPurchase,
            icon: const Icon(
              Icons.add_rounded,
            ),
            label:
                const Text(
              'Add Purchase',
            ),
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child:
                      _buildSummary(
                    context,
                    total,
                    paid,
                    outstanding,
                  ),
                ),
                SliverToBoxAdapter(
                  child:
                      _buildFilters(
                    context,
                    supplierProvider
                        .suppliers,
                  ),
                ),
                if (purchases.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody:
                        false,
                    child:
                        _buildEmptyState(
                      context,
                      purchaseProvider
                          .purchases
                          .isEmpty,
                    ),
                  )
                else
                  SliverPadding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      16,
                      4,
                      16,
                      110,
                    ),
                    sliver:
                        SliverList(
                      delegate:
                          SliverChildBuilderDelegate(
                        (
                          BuildContext
                              context,
                          int index,
                        ) {
                          final PurchaseModel
                              purchase =
                              purchases[
                                  index];

                          return Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              bottom: 12,
                            ),
                            child:
                                _PurchaseCard(
                              purchase:
                                  purchase,
                              onTap:
                                  () =>
                                      _openPurchaseDetails(
                                purchase,
                              ),
                              onEdit:
                                  () =>
                                      _openEditPurchase(
                                purchase,
                              ),
                              onDelete:
                                  () =>
                                      _deletePurchase(
                                purchase,
                              ),
                              currency:
                                  _currency,
                            ),
                          );
                        },
                        childCount:
                            purchases.length,
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

  Widget _buildSummary(
    BuildContext context,
    double total,
    double paid,
    double outstanding,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        12,
      ),
      child: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          final bool compact =
              constraints.maxWidth <
                  700;

          final List<Widget> cards =
              <Widget>[
            _SummaryCard(
              title:
                  'Purchase Total',
              value:
                  _currency(total),
              icon:
                  Icons
                      .shopping_cart_rounded,
              color:
                  AppColors.info,
            ),
            _SummaryCard(
              title:
                  'Paid',
              value:
                  _currency(paid),
              icon:
                  Icons
                      .payments_rounded,
              color:
                  AppColors.success,
            ),
            _SummaryCard(
              title:
                  'Outstanding',
              value:
                  _currency(
                outstanding,
              ),
              icon:
                  Icons
                      .account_balance_wallet_outlined,
              color:
                  AppColors.warning,
            ),
          ];

          if (!compact) {
            return Row(
              children:
                  cards
                      .map(
                (
                  Widget card,
                ) =>
                    Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      right: 8,
                    ),
                    child:
                        card,
                  ),
                ),
              ).toList(),
            );
          }

          return Column(
            children:
                cards
                    .map(
              (
                Widget card,
              ) =>
                  Padding(
                padding:
                    const EdgeInsets
                        .only(
                  bottom: 8,
                ),
                child:
                    card,
              ),
            ).toList(),
          );
        },
      ),
    );
  }

  Widget _buildFilters(
    BuildContext context,
    List<SupplierModel> suppliers,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      child: Card(
        child: Padding(
          padding:
              const EdgeInsets.all(14),
          child: Column(
            children: <Widget>[
              TextField(
                onChanged: (
                  String value,
                ) {
                  setState(() {
                    _searchQuery =
                        value;
                  });
                },
                decoration:
                    InputDecoration(
                  hintText:
                      'Search supplier, product, notes...',
                  prefixIcon:
                      const Icon(
                    Icons
                        .search_rounded,
                  ),
                  suffixIcon:
                      _searchQuery
                              .isEmpty
                          ? null
                          : IconButton(
                              onPressed:
                                  () {
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
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              LayoutBuilder(
                builder: (
                  BuildContext context,
                  BoxConstraints
                      constraints,
                ) {
                  final bool compact =
                      constraints
                              .maxWidth <
                          700;

                  final Widget status =
                      DropdownButtonFormField<
                          String>(
                    initialValue:
                        _statusFilter,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Payment Status',
                    ),
                    items:
                        const <
                            DropdownMenuItem<
                                String>>[
                      DropdownMenuItem<
                          String>(
                        value: 'All',
                        child:
                            Text('All'),
                      ),
                      DropdownMenuItem<
                          String>(
                        value: 'Paid',
                        child:
                            Text('Paid'),
                      ),
                      DropdownMenuItem<
                          String>(
                        value: 'Partial',
                        child:
                            Text(
                          'Partial',
                        ),
                      ),
                      DropdownMenuItem<
                          String>(
                        value: 'Unpaid',
                        child:
                            Text(
                          'Unpaid',
                        ),
                      ),
                    ],
                    onChanged:
                        (
                      String? value,
                    ) {
                      if (value ==
                          null) {
                        return;
                      }

                      setState(() {
                        _statusFilter =
                            value;
                      });
                    },
                  );

                  final Widget supplier =
                      DropdownButtonFormField<
                          String>(
                    initialValue:
                        _supplierFilter,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Supplier',
                    ),
                    items: <DropdownMenuItem<
                        String>>[
                      const DropdownMenuItem<
                          String>(
                        value: 'All',
                        child:
                            Text(
                          'All Suppliers',
                        ),
                      ),
                      ...suppliers.map(
                        (
                          SupplierModel
                              supplier,
                        ) {
                          return DropdownMenuItem<
                              String>(
                            value:
                                supplier.id,
                            child:
                                Text(
                              supplier.name,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          );
                        },
                      ),
                    ],
                    onChanged:
                        (
                      String? value,
                    ) {
                      if (value ==
                          null) {
                        return;
                      }

                      setState(() {
                        _supplierFilter =
                            value;
                      });
                    },
                  );

                  final Widget dates =
                      Row(
                    children:
                        <Widget>[
                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              _selectFromDate,
                          icon:
                              const Icon(
                            Icons
                                .calendar_month_rounded,
                          ),
                          label:
                              Text(
                            _fromDate ==
                                    null
                                ? 'From Date'
                                : DateFormat(
                                    'dd MMM yyyy',
                                  ).format(
                                    _fromDate!,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              _selectToDate,
                          icon:
                              const Icon(
                            Icons
                                .event_rounded,
                          ),
                          label:
                              Text(
                            _toDate ==
                                    null
                                ? 'To Date'
                                : DateFormat(
                                    'dd MMM yyyy',
                                  ).format(
                                    _toDate!,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  );

                  if (compact) {
                    return Column(
                      children:
                          <Widget>[
                        status,
                        const SizedBox(
                          height: 10,
                        ),
                        supplier,
                        const SizedBox(
                          height: 10,
                        ),
                        dates,
                      ],
                    );
                  }

                  return Column(
                    children:
                        <Widget>[
                      Row(
                        children:
                            <Widget>[
                          Expanded(
                            child:
                                status,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child:
                                supplier,
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      dates,
                    ],
                  );
                },
              ),
              const SizedBox(
                height: 8,
              ),
              Align(
                alignment:
                    Alignment.centerRight,
                child:
                    TextButton.icon(
                  onPressed:
                      _clearFilters,
                  icon:
                      const Icon(
                    Icons
                        .filter_alt_off_rounded,
                  ),
                  label:
                      const Text(
                    'Clear Filters',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool noPurchases,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
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
              child:
                  const Icon(
                Icons
                    .shopping_cart_outlined,
                size: 38,
                color:
                    AppColors.primary,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              noPurchases
                  ? 'No purchases yet'
                  : 'No matching purchases',
              style:
                  Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              noPurchases
                  ? 'Create your first purchase to automatically increase stock.'
                  : 'Try changing the search or filters.',
              textAlign:
                  TextAlign.center,
              style:
                  Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    color:
                        Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                  ),
            ),
            const SizedBox(
              height: 18,
            ),
            if (noPurchases)
              FilledButton.icon(
                onPressed:
                    _openAddPurchase,
                icon:
                    const Icon(
                  Icons
                      .add_rounded,
                ),
                label:
                    const Text(
                  'Add Purchase',
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
              size: 54,
              color:
                  AppColors.danger,
            ),
            const SizedBox(
              height: 14,
            ),
            Text(
              message,
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(
              height: 18,
            ),
            FilledButton.icon(
              onPressed:
                  _initialize,
              icon:
                  const Icon(
                Icons
                    .refresh_rounded,
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
}

class _SummaryCard
    extends StatelessWidget {
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
    return Card(
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
                color:
                    color.withValues(
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
                    style:
                        const TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    value,
                    style:
                        const TextStyle(
                      fontSize: 18,
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

class _PurchaseCard
    extends StatelessWidget {
  final PurchaseModel purchase;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(double)
      currency;

  const _PurchaseCard({
    required this.purchase,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.currency,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final Color statusColor =
        _statusColor(
      purchase.paymentStatus,
    );

    final double outstanding =
        purchase.total -
            purchase.paidAmount >
        0
            ? purchase.total -
                purchase.paidAmount
            : 0;

    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration:
                        BoxDecoration(
                      color: AppColors
                          .info
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
                          AppColors.info,
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
                          purchase
                                  .supplierName
                                  .trim()
                                  .isEmpty
                              ? 'Supplier'
                              : purchase
                                  .supplierName,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          DateFormat(
                            'dd MMM yyyy',
                          ).format(
                            purchase.date,
                          ),
                          style:
                              const TextStyle(
                            fontSize: 12,
                            color: AppColors
                                .lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(
                    status:
                        purchase.paymentStatus,
                    color:
                        statusColor,
                  ),
                  PopupMenuButton<
                      String>(
                    onSelected:
                        (
                      String value,
                    ) {
                      if (value ==
                          'edit') {
                        onEdit();
                      } else if (value ==
                          'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder:
                        (
                      BuildContext
                          context,
                    ) {
                      return const <
                          PopupMenuEntry<
                              String>>[
                        PopupMenuItem<
                            String>(
                          value: 'edit',
                          child: Row(
                            children: <
                                Widget>[
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
                          value: 'delete',
                          child: Row(
                            children: <
                                Widget>[
                              Icon(
                                Icons
                                    .delete_outline_rounded,
                                color:
                                    AppColors
                                        .danger,
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    purchase.items
                        .take(3)
                        .map(
                  (
                    PurchaseItemModel item,
                  ) {
                    return Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration:
                          BoxDecoration(
                        color: AppColors
                            .lightBackground,
                        borderRadius:
                            BorderRadius
                                .circular(
                          8,
                        ),
                      ),
                      child: Text(
                        '${item.productName} × ${_formatNumber(item.quantity)}',
                        style:
                            const TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
              if (purchase.items.length >
                  3) ...<Widget>[
                const SizedBox(
                  height: 7,
                ),
                Text(
                  '+${purchase.items.length - 3} more products',
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color: AppColors
                        .lightTextSecondary,
                  ),
                ),
              ],
              const SizedBox(
                height: 14,
              ),
              const Divider(
                height: 1,
              ),
              const SizedBox(
                height: 12,
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ValueColumn(
                      label:
                          'Total',
                      value:
                          currency(
                        purchase.total,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _ValueColumn(
                      label:
                          'Paid',
                      value:
                          currency(
                        purchase.paidAmount,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _ValueColumn(
                      label:
                          'Pending',
                      value:
                          currency(
                        outstanding,
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

  static Color _statusColor(
    String status,
  ) {
    switch (
        status.toLowerCase()) {
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

  static String _formatNumber(
    double value,
  ) {
    if (value ==
        value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}

class _StatusChip
    extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusChip({
    required this.status,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        status.isEmpty
            ? 'Unknown'
            : status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }
}

class _ValueColumn
    extends StatelessWidget {
  final String label;
  final String value;

  const _ValueColumn({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style:
              const TextStyle(
            fontSize: 11,
            color: AppColors
                .lightTextSecondary,
          ),
        ),
        const SizedBox(
          height: 3,
        ),
        Text(
          value,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _PurchaseDetailsSheet
    extends StatelessWidget {
  final PurchaseModel purchase;
  final VoidCallback onEdit;

  const _PurchaseDetailsSheet({
    required this.purchase,
    required this.onEdit,
  });

  String _currency(
    double value,
  ) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final double outstanding =
        purchase.total -
                purchase.paidAmount >
            0
        ? purchase.total -
            purchase.paidAmount
        : 0;

    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Purchase Details',
                      style:
                          Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        onEdit,
                    icon:
                        const Icon(
                      Icons
                          .edit_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 8,
              ),
              _DetailRow(
                label:
                    'Supplier',
                value:
                    purchase
                        .supplierName,
              ),
              _DetailRow(
                label:
                    'Date',
                value:
                    DateFormat(
                  'dd MMM yyyy',
                ).format(
                  purchase.date,
                ),
              ),
              _DetailRow(
                label:
                    'Payment Method',
                value:
                    purchase
                        .paymentMethod,
              ),
              _DetailRow(
                label:
                    'Payment Status',
                value:
                    purchase
                        .paymentStatus,
              ),
              const SizedBox(
                height: 14,
              ),
              const Text(
                'Products',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              ...purchase.items.map(
                (
                  PurchaseItemModel item,
                ) {
                  return Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      bottom: 8,
                    ),
                    child: Container(
                      padding:
                          const EdgeInsets
                              .all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        color: AppColors
                            .lightBackground,
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: <Widget>[
                                Text(
                                  item.productName,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                  ),
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  '${item.quantity} ${item.unit} × ${_currency(item.purchaseRate)}',
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        12,
                                    color:
                                        AppColors
                                            .lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _currency(
                              item.total,
                            ),
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              const SizedBox(
                height: 10,
              ),
              _DetailRow(
                label:
                    'Subtotal',
                value:
                    _currency(
                  purchase.subtotal,
                ),
              ),
              _DetailRow(
                label:
                    'Discount',
                value:
                    _currency(
                  purchase.discount,
                ),
              ),
              _DetailRow(
                label:
                    'Tax',
                value:
                    _currency(
                  purchase.tax,
                ),
              ),
              _DetailRow(
                label:
                    'Total',
                value:
                    _currency(
                  purchase.total,
                ),
                bold: true,
              ),
              _DetailRow(
                label:
                    'Paid',
                value:
                    _currency(
                  purchase.paidAmount,
                ),
              ),
              _DetailRow(
                label:
                    'Outstanding',
                value:
                    _currency(
                  outstanding,
                ),
                bold: true,
              ),
              if (purchase.notes
                  .trim()
                  .isNotEmpty) ...<Widget>[
                const SizedBox(
                  height: 12,
                ),
                const Text(
                  'Notes',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 6,
                ),
                Text(
                  purchase.notes,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow
    extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style:
                  TextStyle(
                fontWeight:
                    bold
                        ? FontWeight.w800
                        : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            textAlign:
                TextAlign.end,
            style:
                TextStyle(
              fontWeight:
                  bold
                      ? FontWeight.w800
                      : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}