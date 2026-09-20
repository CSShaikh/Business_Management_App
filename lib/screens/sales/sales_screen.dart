import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/services/professional_sales_bill_pdf_service.dart';
import '../../core/services/sale_stock_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../models/ledger_transaction_model.dart';
import '../../models/sale_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/sale_repository.dart';
import '../../services/ledger/ledger_service.dart';
import 'add_sale_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final BusinessRepository _businessRepository = BusinessRepository();

  final SaleRepository _saleRepository = SaleRepository();

  final CustomerRepository _customerRepository = CustomerRepository();

  final SaleStockService _saleStockService = SaleStockService();

  final LedgerService _ledgerService = LedgerService();

  final TextEditingController _searchController = TextEditingController();

  BusinessModel? _business;

  Stream<List<SaleModel>>? _salesStream;

  bool _loadingBusiness = true;
  String? _businessError;

  String _searchQuery = '';

  /// Prevents duplicate edit/delete operations for the same sale.
  final Set<String> _busySaleIds = <String>{};

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_handleSearchChanged);

    _loadBusiness();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // SEARCH LISTENER
  // ===========================================================================

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }

    final String newQuery = _searchController.text.trim().toLowerCase();

    if (newQuery == _searchQuery) {
      return;
    }

    setState(() {
      _searchQuery = newQuery;
    });
  }

  // ===========================================================================
  // BUSINESS
  // ===========================================================================

  Future<void> _loadBusiness() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loadingBusiness = true;
      _businessError = null;
    });

    try {
      final BusinessModel? business = await _businessRepository
          .getBusinessForCurrentUser();

      if (!mounted) {
        return;
      }

      if (business == null) {
        setState(() {
          _business = null;
          _salesStream = null;
          _loadingBusiness = false;
          _businessError =
              'Business profile not found. Please complete business setup.';
        });
        return;
      }

      final String businessId = business.id.trim();

      if (businessId.isEmpty) {
        setState(() {
          _business = null;
          _salesStream = null;
          _loadingBusiness = false;
          _businessError = 'Business information is invalid. Please complete business setup again.';
        });
        return;
      }

      setState(() {
        _business = business;

        // Keep one stable stream instance instead of creating a new Firestore
        // stream on every build/search keystroke.
        _salesStream = _saleRepository.watchSales(businessId: businessId);

        _loadingBusiness = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _business = null;
        _salesStream = null;
        _loadingBusiness = false;
        _businessError = _cleanError(e);
      });
    }
  }

  // ===========================================================================
  // EDIT SALE
  // ===========================================================================

  Future<void> _openEditSale(SaleModel sale) async {
    final BusinessModel? business = _business;

    if (business == null) {
      _showMessage('Business information is not available.', isError: true);
      return;
    }

    final String saleId = sale.id.trim();

    if (saleId.isEmpty) {
      _showMessage('This sale has an invalid ID.', isError: true);
      return;
    }

    if (_busySaleIds.contains(saleId)) {
      return;
    }

    setState(() {
      _busySaleIds.add(saleId);
    });

    try {
      final bool? updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => AddSaleScreen(sale: sale)),
      );

      if (!mounted) {
        return;
      }

      if (updated == true) {
        _showMessage('Sale updated successfully.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busySaleIds.remove(saleId);
        });
      }
    }
  }

  // ===========================================================================
  // ADD SALE
  // ===========================================================================

  Future<void> _openAddSale() async {
    if (_business == null) {
      _showMessage('Business information is not available.', isError: true);
      return;
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddSaleScreen()),
    );
  }

  // ===========================================================================
  // SALE DETAILS
  // ===========================================================================

  Future<CustomerModel?> _loadSaleCustomer(SaleModel sale) async {
    final BusinessModel? business = _business;
    if (business == null || sale.customerId.trim().isEmpty) {
      return null;
    }

    try {
      return await _customerRepository.getCustomer(
        businessId: business.id,
        customerId: sale.customerId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _printSaleInvoice(SaleModel sale) async {
    final BusinessModel? business = _business;
    if (business == null) {
      _showMessage('Business information is not available.', isError: true);
      return;
    }

    try {
      final CustomerModel? customer = await _loadSaleCustomer(sale);
      final Uint8List bytes =
          await ProfessionalSalesBillPdfService.generateSingleSale(
            business: business,
            sale: sale,
            customer: customer,
          );

      await Printing.layoutPdf(
        name:
            'Invoice_${sale.invoiceNumber.trim().isEmpty ? sale.id : sale.invoiceNumber}.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to prepare invoice: ${_cleanError(e)}',
          isError: true,
        );
      }
    }
  }

  Future<void> _shareSaleInvoice(SaleModel sale) async {
    final BusinessModel? business = _business;
    if (business == null) {
      _showMessage('Business information is not available.', isError: true);
      return;
    }

    try {
      final CustomerModel? customer = await _loadSaleCustomer(sale);
      final Uint8List bytes =
          await ProfessionalSalesBillPdfService.generateSingleSale(
            business: business,
            sale: sale,
            customer: customer,
          );

      final String number = sale.invoiceNumber.trim().isEmpty
          ? sale.id.trim()
          : sale.invoiceNumber.trim();
      final String fileName = 'Invoice_${number.isEmpty ? 'Sale' : number}.pdf';

      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to share invoice: ${_cleanError(e)}',
          isError: true,
        );
      }
    }
  }

  void _showSaleDetails(SaleModel sale) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sale.invoiceNumber.isEmpty
                                  ? 'Sale'
                                  : sale.invoiceNumber,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat('dd MMM yyyy, hh:mm a')
                                  .format(sale.date),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      _StatusChip(status: sale.paymentStatus),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // ----------------------------------------------------------------
                  // CUSTOMER
                  // ----------------------------------------------------------------
                  _DetailSection(
                    title: 'Customer',
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          child: Icon(Icons.person_outline_rounded, size: 21),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sale.customerName.isEmpty
                                ? 'Walk-in Customer'
                                : sale.customerName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ----------------------------------------------------------------
                  // ITEMS
                  // ----------------------------------------------------------------
                  _DetailSection(
                    title: 'Items',
                    child: Column(
                      children: sale.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${_formatNumber(item.quantity)} ${item.unit} × ${_formatCurrency(item.sellingRate)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatCurrency(item.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 6),

                  _SummaryCard(
                    subtotal: sale.subtotal,
                    discount: sale.discount,
                    tax: sale.tax,
                    total: sale.total,
                    paid: sale.paidAmount,
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _printSaleInvoice(sale);
                          },
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Print Bill'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            _shareSaleInvoice(sale);
                          },
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share Bill'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Payment Method',
                    value: sale.paymentMethod.isEmpty
                        ? 'Not specified'
                        : sale.paymentMethod,
                  ),

                  if (sale.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.notes_rounded,
                      label: 'Notes',
                      value: sale.notes,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // DELETE SALE
  // ===========================================================================

  Future<void> _deleteSale(SaleModel sale) async {
    final BusinessModel? business = _business;

    if (business == null) {
      _showMessage('Business information is not available.', isError: true);
      return;
    }

    final String businessId = business.id.trim();

    final String saleId = sale.id.trim();

    if (businessId.isEmpty) {
      _showMessage('Business ID is invalid.', isError: true);
      return;
    }

    if (saleId.isEmpty) {
      _showMessage('This sale has an invalid ID.', isError: true);
      return;
    }

    if (_busySaleIds.contains(saleId)) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Sale?'),
          content: Text(
            'Are you sure you want to delete '
            '${sale.invoiceNumber.isEmpty ? 'this sale' : sale.invoiceNumber}?\n\n'
            'The sold stock will be restored and all active customer ledger '
            'entries created for this sale will be reversed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _busySaleIds.add(saleId);
    });

    bool stockReversed = false;

    final List<LedgerTransactionModel> createdReversals =
        <LedgerTransactionModel>[];

    try {
      // =====================================================================
      // 1. PREPARE CUSTOMER LEDGER REVERSALS
      // =====================================================================
      //
      // A paid sale normally creates two ledger entries:
      //
      //   SALE         -> increases customer outstanding
      //   SALE_PAYMENT -> decreases customer outstanding
      //
      // When deleting a fully paid sale, the current balance may therefore be
      // zero. Reversing the SALE entry first would incorrectly try to reduce
      // the balance below zero.
      //
      // Correct order is:
      //
      //   SALE_PAYMENT_REVERSAL -> restore the paid amount
      //   SALE_REVERSAL         -> remove the sale amount
      //
      // This also works for unpaid and partially paid sales.
      // =====================================================================

      LedgerTransactionModel? saleLedger;
      LedgerTransactionModel? salePaymentLedger;
      double ledgerBalance = 0;

      if (sale.customerId.trim().isNotEmpty) {
        final String customerId = sale.customerId.trim();

        final List<LedgerTransactionModel> transactions = await _ledgerService
            .getCustomerTransactions(
              businessId: businessId,
              customerId: customerId,
            );

        // Find the active SALE entry belonging to this sale.
        for (final LedgerTransactionModel transaction in transactions) {
          final String type = transaction.transactionType.trim().toUpperCase();

          if (transaction.referenceId.trim() == saleId &&
              type == LedgerService.saleType &&
              transaction.amount > 0) {
            saleLedger = transaction;
            break;
          }
        }

        // Find the active SALE_PAYMENT entry belonging to this sale.
        for (final LedgerTransactionModel transaction in transactions) {
          final String type = transaction.transactionType.trim().toUpperCase();

          if (transaction.referenceId.trim() == saleId &&
              type == LedgerService.salePaymentType &&
              transaction.amount > 0) {
            salePaymentLedger = transaction;
            break;
          }
        }

        // If there is no active ledger entry for this sale, there is nothing
        // to reverse. Do not create artificial ledger transactions.
        if (saleLedger != null || salePaymentLedger != null) {
          ledgerBalance = await _ledgerService.getCustomerBalance(
            businessId: businessId,
            customerId: customerId,
          );

          if (!ledgerBalance.isFinite || ledgerBalance < -0.000001) {
            throw Exception(
              'Customer ledger balance is invalid. '
              'The sale cannot be deleted safely.',
            );
          }

          if (ledgerBalance.abs() <= 0.000001) {
            ledgerBalance = 0;
          }
        }
      }

      // =====================================================================
      // 2. RESTORE STOCK
      // =====================================================================

      await _saleStockService.reverseSaleStock(sale: sale);

      stockReversed = true;

      // =====================================================================
      // 3. REVERSE CUSTOMER SALE PAYMENT FIRST
      // =====================================================================
      //
      // This is essential for paid/partially-paid sales. It increases the
      // outstanding balance back to the amount that existed before the sale
      // payment was recorded.
      // =====================================================================

      if (salePaymentLedger != null) {
        final String customerId = sale.customerId.trim();

        final String customerName = sale.customerName.trim().isEmpty
            ? salePaymentLedger.customerName.trim()
            : sale.customerName.trim();

        final LedgerTransactionModel paymentReversal = await _ledgerService
            .createSalePaymentReversal(
              businessId: businessId,
              customerId: customerId,
              customerName: customerName,
              paymentAmount: salePaymentLedger.amount,
              balanceBefore: ledgerBalance,
              referenceId: saleId,
              date: DateTime.now(),
              notes:
                  'Payment reversal for deleted sale '
                  '${sale.invoiceNumber.isEmpty ? saleId : sale.invoiceNumber}',
            );

        createdReversals.add(paymentReversal);

        ledgerBalance = paymentReversal.balanceAfter;
      }

      // =====================================================================
      // 4. REVERSE CUSTOMER SALE
      // =====================================================================

      if (saleLedger != null) {
        final String customerId = sale.customerId.trim();

        final String customerName = sale.customerName.trim().isEmpty
            ? saleLedger.customerName.trim()
            : sale.customerName.trim();

        if (saleLedger.amount > ledgerBalance + 0.000001) {
          throw Exception(
            'Customer ledger history is inconsistent. '
            'The sale cannot be deleted safely. '
            'Please correct the customer ledger/payment history first.',
          );
        }

        final LedgerTransactionModel saleReversal = await _ledgerService
            .createSaleReversal(
              businessId: businessId,
              customerId: customerId,
              customerName: customerName,
              saleAmount: saleLedger.amount,
              balanceBefore: ledgerBalance,
              referenceId: saleId,
              date: DateTime.now(),
              notes:
                  'Reversal for deleted sale '
                  '${sale.invoiceNumber.isEmpty ? saleId : sale.invoiceNumber}',
            );

        createdReversals.add(saleReversal);
      }

      // =====================================================================
      // 5. DELETE SALE DOCUMENT
      // =====================================================================

      await _saleRepository.deleteSale(businessId: businessId, saleId: saleId);

      if (!mounted) {
        return;
      }

      _showMessage(
        createdReversals.isEmpty
            ? 'Sale deleted and stock restored successfully.'
            : 'Sale deleted, stock restored and customer ledger reversed successfully.',
      );
    } catch (e) {
      // =====================================================================
      // ROLLBACK LEDGER REVERSALS
      // =====================================================================

      for (final LedgerTransactionModel reversal in createdReversals.reversed) {
        try {
          await _ledgerService.deleteTransaction(
            businessId: businessId,
            transactionId: reversal.id,
          );
        } catch (_) {
          // Keep the original error.
        }
      }

      // =====================================================================
      // ROLLBACK STOCK
      // =====================================================================

      if (stockReversed) {
        try {
          await _saleStockService.processSaleStock(sale: sale);
        } catch (_) {
          // Keep the original error.
        }
      }

      if (!mounted) {
        return;
      }

      _showMessage('Unable to delete sale: ${_cleanError(e)}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busySaleIds.remove(saleId);
        });
      }
    }
  }

  // ===========================================================================
  // SEARCH / FILTER
  // ===========================================================================

  List<SaleModel> _filterSales(List<SaleModel> sales) {
    if (_searchQuery.isEmpty) {
      return sales;
    }

    return sales.where((sale) {
      final String invoice = sale.invoiceNumber.trim().toLowerCase();

      final String customer = sale.customerName.trim().toLowerCase();

      final String notes = sale.notes.trim().toLowerCase();

      final bool productMatch = sale.items.any((item) {
        return item.productName.trim().toLowerCase().contains(_searchQuery);
      });

      return invoice.contains(_searchQuery) ||
          customer.contains(_searchQuery) ||
          notes.contains(_searchQuery) ||
          productMatch;
    }).toList();
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _cleanError(Object error) {
    final String message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_loadingBusiness) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_businessError != null) {
      return _buildErrorState();
    }

    final BusinessModel? business = _business;

    final Stream<List<SaleModel>>? salesStream = _salesStream;

    if (business == null || salesStream == null) {
      return _buildNoBusinessState();
    }

    return StreamBuilder<List<SaleModel>>(
      stream: salesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildStreamErrorState(snapshot.error.toString());
        }

        final List<SaleModel> allSales = snapshot.data ?? <SaleModel>[];

        final List<SaleModel> sales = _filterSales(allSales);

        return RefreshIndicator(
          onRefresh: _loadBusiness,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth >= 900;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 28 : 16,
                  vertical: 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isDesktop),
                        const SizedBox(height: 20),
                        _buildSummary(allSales, isDesktop),
                        const SizedBox(height: 20),
                        _buildSearchCard(),
                        const SizedBox(height: 20),
                        _buildSalesSection(sales),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(bool isDesktop) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.point_of_sale_rounded,
            color: AppColors.success,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              Text(
                'Manage sales, invoices and payments.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (isDesktop)
          FilledButton.icon(
            onPressed: _openAddSale,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Sale'),
          ),
      ],
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummary(List<SaleModel> sales, bool isDesktop) {
    double total = 0;
    double paid = 0;
    double outstanding = 0;

    for (final SaleModel sale in sales) {
      if (sale.total.isFinite && sale.total > 0) {
        total += sale.total;
      }

      if (sale.paidAmount.isFinite && sale.paidAmount > 0) {
        paid += sale.paidAmount;
      }

      final double balance = sale.total - sale.paidAmount;

      if (balance.isFinite && balance > 0) {
        outstanding += balance;
      }
    }

    final int count = sales.length;

    final List<Widget> cards = [
      _SummaryMetricCard(
        icon: Icons.receipt_long_rounded,
        title: 'Total Sales',
        value: _formatCurrency(total),
        subtitle: '$count invoice${count == 1 ? '' : 's'}',
        color: AppColors.primary,
      ),
      _SummaryMetricCard(
        icon: Icons.payments_rounded,
        title: 'Collected',
        value: _formatCurrency(paid),
        subtitle: 'Amount received',
        color: AppColors.success,
      ),
      _SummaryMetricCard(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Outstanding',
        value: _formatCurrency(outstanding),
        subtitle: 'Amount pending',
        color: AppColors.warning,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map(
              (card) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: card,
                ),
              ),
            )
            .toList(),
      );
    }

    return Column(
      children: [
        cards[0],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: cards[1]),
            const SizedBox(width: 12),
            Expanded(child: cards[2]),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Widget _buildSearchCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search invoice, customer or product...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            border: InputBorder.none,
            filled: false,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SALES LIST
  // ===========================================================================

  Widget _buildSalesSection(List<SaleModel> sales) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _searchQuery.isEmpty ? 'Recent Sales' : 'Search Results',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${sales.length}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (sales.isEmpty)
              _buildEmptyState()
            else
              ...sales.map((sale) {
                return _SaleListTile(
                  sale: sale,
                  isBusy: _busySaleIds.contains(sale.id.trim()),
                  onTap: () {
                    if (_busySaleIds.contains(sale.id.trim())) {
                      return;
                    }

                    _showSaleDetails(sale);
                  },
                  onEdit: () {
                    _openEditSale(sale);
                  },
                  onDelete: () {
                    _deleteSale(sale);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmptyState() {
    final bool searching = _searchQuery.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 46),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                searching
                    ? Icons.search_off_rounded
                    : Icons.receipt_long_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              searching ? 'No sales found' : 'No sales yet',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              searching
                  ? 'Try a different invoice, customer or product.'
                  : 'Create your first sale to see it here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (!searching) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _openAddSale,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Sale'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ERROR STATES
  // ===========================================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: AppColors.danger,
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load business',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _businessError ?? 'Something went wrong.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadBusiness,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBusinessState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Business profile not found.\n'
          'Please complete business setup.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildStreamErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: AppColors.danger,
            ),
            const SizedBox(height: 14),
            Text(
              'Unable to load sales',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _cleanError(error),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {
                _loadBusiness();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FORMATTERS
  // ===========================================================================

  String _formatCurrency(double value) {
    final double safeValue = value.isFinite ? value : 0;

    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: safeValue.truncateToDouble() == safeValue ? 0 : 2,
    ).format(safeValue);
  }

  String _formatNumber(double value) {
    if (!value.isFinite) {
      return '0';
    }

    return value.truncateToDouble() == value
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }
}

// =============================================================================
// SUMMARY METRIC CARD
// =============================================================================

class _SummaryMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _SummaryMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool compact = constraints.maxWidth < 180;

            final Widget details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );

            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(height: 10),
                      details,
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// SALE LIST TILE
// =============================================================================

class _SaleListTile extends StatelessWidget {
  final SaleModel sale;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SaleListTile({
    required this.sale,
    required this.isBusy,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatCurrency(double value) {
    final double safeValue = value.isFinite ? value : 0;

    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: safeValue.truncateToDouble() == safeValue ? 0 : 2,
    ).format(safeValue);
  }

  @override
  Widget build(BuildContext context) {
    final double outstanding = sale.total - sale.paidAmount;

    final bool hasOutstanding = outstanding.isFinite && outstanding > 0;

    return Opacity(
      opacity: isBusy ? 0.60 : 1,
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: isBusy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.success,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            sale.invoiceNumber.isEmpty
                                ? 'Sale'
                                : sale.invoiceNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: sale.paymentStatus),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sale.customerName.isEmpty
                          ? 'Walk-in Customer'
                          : sale.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(sale.date)} • ${sale.items.length} item${sale.items.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(sale.total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasOutstanding
                        ? 'Due ${_formatCurrency(outstanding)}'
                        : 'Paid',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasOutstanding
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'More options',
                enabled: !isBusy,
                onSelected: isBusy
                    ? null
                    : (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.danger,
                          ),
                          SizedBox(width: 10),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// STATUS CHIP
// =============================================================================

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  Color _color() {
    switch (status.trim().toLowerCase()) {
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

  String _label() {
    final String normalized = status.trim();

    if (normalized.isEmpty) {
      return 'Unknown';
    }

    switch (normalized.toLowerCase()) {
      case 'paid':
        return 'Paid';

      case 'partial':
        return 'Partial';

      case 'unpaid':
        return 'Unpaid';

      default:
        if (normalized.length == 1) {
          return normalized.toUpperCase();
        }

        return normalized[0].toUpperCase() + normalized.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _color();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// =============================================================================
// DETAIL SECTION
// =============================================================================

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// =============================================================================
// SUMMARY CARD
// =============================================================================

class _SummaryCard extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paid;

  const _SummaryCard({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paid,
  });

  String _currency(double value) {
    final double safeValue = value.isFinite ? value : 0;

    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: safeValue.truncateToDouble() == safeValue ? 0 : 2,
    ).format(safeValue);
  }

  @override
  Widget build(BuildContext context) {
    final double rawOutstanding = total - paid;

    final double outstanding = rawOutstanding.isFinite && rawOutstanding > 0
        ? rawOutstanding
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _row(context, 'Subtotal', _currency(subtotal)),
          if (discount.isFinite && discount > 0)
            _row(context, 'Discount', '- ${_currency(discount)}'),
          if (tax.isFinite && tax > 0) _row(context, 'Tax', _currency(tax)),
          const Divider(height: 20),
          _row(context, 'Total', _currency(total), bold: true),
          const SizedBox(height: 8),
          _row(context, 'Paid', _currency(paid), valueColor: AppColors.success),
          const SizedBox(height: 8),
          _row(
            context,
            'Outstanding',
            _currency(outstanding),
            valueColor: outstanding > 0 ? AppColors.warning : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// INFO ROW
// =============================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value)),
      ],
    );
  }
}
