import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/product_repository.dart';
import '../../core/services/sale_stock_service.dart';
import '../../models/ledger_transaction_model.dart';
import '../../repositories/sale_repository.dart';
import '../../services/ledger/ledger_service.dart';

class AddSaleScreen extends StatefulWidget {
  final SaleModel? sale;

  const AddSaleScreen({
    super.key,
    this.sale,
  });

  bool get isEditMode => sale != null;

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final BusinessRepository _businessRepository =
      BusinessRepository();

  final ProductRepository _productRepository =
      ProductRepository();

  final CustomerRepository _customerRepository =
      CustomerRepository();

  final SaleRepository _saleRepository =
      SaleRepository();

  final SaleStockService _saleStockService =
      SaleStockService();

  final LedgerService _ledgerService =
      LedgerService();

  final TextEditingController _discountController =
      TextEditingController(text: '0');

  final TextEditingController _taxController =
      TextEditingController(text: '0');

  final TextEditingController _paidController =
      TextEditingController(text: '0');

  final TextEditingController _notesController =
      TextEditingController();

  BusinessModel? _business;
  CustomerModel? _selectedCustomer;

  List<ProductModel> _products = <ProductModel>[];

  final List<_SaleDraftItem> _items =
      <_SaleDraftItem>[];

  bool _loading = true;
  bool _saving = false;

  String? _errorMessage;

  String _paymentMethod = 'Cash';

  @override
  void initState() {
    super.initState();

    _discountController.addListener(
      _refreshTotals,
    );

    _taxController.addListener(
      _refreshTotals,
    );

    _paidController.addListener(
      _refreshTotals,
    );

    _loadData();
  }

  @override
  void dispose() {
    _discountController
      ..removeListener(_refreshTotals)
      ..dispose();

    _taxController
      ..removeListener(_refreshTotals)
      ..dispose();

    _paidController
      ..removeListener(_refreshTotals)
      ..dispose();

    _notesController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // LOAD DATA
  // ===========================================================================

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final BusinessModel? business =
          await _businessRepository
              .getBusinessForCurrentUser();

      if (business == null) {
        throw Exception(
          'Business profile not found. Please complete business setup first.',
        );
      }

      final List<ProductModel> products =
          await _productRepository.getActiveProducts(
        business.id,
      );

      if (!mounted) {
        return;
      }

      if (widget.isEditMode) {
        await _loadExistingSaleData(
          business: business,
          products: products,
          sale: widget.sale!,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _business = business;
        _products = products;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = _cleanError(e);
      });
    }
  }

  // ===========================================================================
  // LOAD EXISTING SALE FOR EDIT MODE
  // ===========================================================================

  Future<void> _loadExistingSaleData({
    required BusinessModel business,
    required List<ProductModel> products,
    required SaleModel sale,
  }) async {
    if (sale.businessId.trim() != business.id.trim()) {
      throw Exception(
        'Sale does not belong to the current business.',
      );
    }

    CustomerModel? customer;

    final String existingCustomerId =
        sale.customerId.trim();

    if (existingCustomerId.isNotEmpty) {
      customer = await _customerRepository.getCustomer(
        businessId: business.id,
        customerId: existingCustomerId,
      );

      // IMPORTANT:
      // An existing sale that already belongs to a customer must never
      // silently become a walk-in sale just because that customer document
      // is missing. Doing so can break the relationship between the sale
      // and its historical customer ledger.
      if (customer == null) {
        throw Exception(
          'Customer for this sale could not be found. '
          'Please restore the customer or cancel editing.',
        );
      }
    }

    final List<_SaleDraftItem> draftItems =
        <_SaleDraftItem>[];

    for (final SaleItemModel saleItem
        in sale.items) {
      final String productId =
          saleItem.productId.trim();

      if (productId.isEmpty) {
        throw Exception(
          'Sale contains an item with an invalid product ID.',
        );
      }

      ProductModel? product;

      for (final ProductModel candidate
          in products) {
        if (candidate.id == productId) {
          product = candidate;
          break;
        }
      }

      product ??= await _productRepository.getProduct(
        business.id,
        productId,
      );

      if (product == null) {
        throw Exception(
          'Product "${saleItem.productName}" is no longer available.',
        );
      }

      if (!saleItem.quantity.isFinite ||
          saleItem.quantity <= 0) {
        throw Exception(
          'Sale contains an invalid quantity for '
          '"${saleItem.productName}".',
        );
      }

      if (!saleItem.sellingRate.isFinite ||
          saleItem.sellingRate < 0) {
        throw Exception(
          'Sale contains an invalid selling rate for '
          '"${saleItem.productName}".',
        );
      }

      draftItems.add(
        _SaleDraftItem(
          product: product,
          quantity: saleItem.quantity,
          sellingRate: saleItem.sellingRate,
        ),
      );
    }

    if (draftItems.isEmpty) {
      throw Exception(
        'The existing sale does not contain any valid products.',
      );
    }

    _selectedCustomer = customer;

    _items
      ..clear()
      ..addAll(draftItems);

    _discountController.text =
        _formatNumber(sale.discount);

    _taxController.text =
        _formatNumber(sale.tax);

    _paidController.text =
        _formatNumber(sale.paidAmount);

    _notesController.text = sale.notes;

    if (sale.paymentMethod.trim().isNotEmpty) {
      _paymentMethod = sale.paymentMethod;
    }
  }

  // ===========================================================================
  // PRODUCT SELECTION
  // ===========================================================================

  Future<void> _showProductSelector() async {
    if (_products.isEmpty) {
      _showMessage(
        'No active products are available.',
        isError: true,
      );
      return;
    }

    final TextEditingController searchController =
        TextEditingController();

    ProductModel? selectedProduct;

    selectedProduct =
        await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setModalState,
          ) {
            final String query =
                searchController.text.trim().toLowerCase();

            final List<ProductModel> filteredProducts =
                _products.where(
              (product) {
                if (query.isEmpty) {
                  return true;
                }

                return product.name
                        .toLowerCase()
                        .contains(query) ||
                    product.category
                        .toLowerCase()
                        .contains(query) ||
                    product.id
                        .toLowerCase()
                        .contains(query);
              },
            ).toList();

            return SafeArea(
              child: Container(
                constraints:
                    const BoxConstraints(
                  maxHeight: 720,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .dividerColor,
                        borderRadius:
                            BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        18,
                        18,
                        18,
                        12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Select Product',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () {
                              Navigator.pop(
                                sheetContext,
                              );
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      child: TextField(
                        controller:
                            searchController,
                        autofocus: true,
                        onChanged: (_) {
                          setModalState(() {});
                        },
                        decoration:
                            const InputDecoration(
                          hintText:
                              'Search product...',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredProducts.isEmpty
                          ? const Center(
                              child: Text(
                                'No products found.',
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(
                                18,
                                4,
                                18,
                                24,
                              ),
                              itemCount:
                                  filteredProducts.length,
                              separatorBuilder:
                                  (_, _) =>
                                      const SizedBox(
                                height: 8,
                              ),
                              itemBuilder:
                                  (
                                context,
                                index,
                              ) {
                                final ProductModel
                                    product =
                                    filteredProducts[
                                        index];

                                return Card(
                                  child: ListTile(
                                    leading:
                                        const CircleAvatar(
                                      child: Icon(
                                        Icons
                                            .inventory_2_outlined,
                                      ),
                                    ),
                                    title: Text(
                                      product.name,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                    subtitle:
                                        Text(
                                      'Stock: ${_formatNumber(product.currentStock)} ${product.unit}\n'
                                      'Selling Rate: ${_formatCurrency(product.sellingPrice)}',
                                    ),
                                    isThreeLine:
                                        true,
                                    trailing:
                                        const Icon(
                                      Icons
                                          .chevron_right_rounded,
                                    ),
                                    onTap: () {
                                      Navigator.pop(
                                        sheetContext,
                                        product,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();

    if (selectedProduct == null ||
        !mounted) {
      return;
    }

    _addProduct(selectedProduct);
  }

  void _addProduct(ProductModel product) {
    final int existingIndex =
        _items.indexWhere(
      (item) =>
          item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      setState(() {
        final _SaleDraftItem item =
            _items[existingIndex];

        item.quantity += 1;
      });

      _refreshTotals();
      return;
    }

    setState(() {
      _items.add(
        _SaleDraftItem(
          product: product,
          quantity: 1,
          sellingRate:
              product.sellingPrice,
        ),
      );
    });

    _refreshTotals();
  }

  void _removeProduct(
    _SaleDraftItem item,
  ) {
    setState(() {
      _items.remove(item);
    });

    _refreshTotals();
  }

  // ===========================================================================
  // CUSTOMER SELECTION
  // ===========================================================================

  Future<void> _selectCustomer() async {
    final BusinessModel? business = _business;

    if (business == null) {
      return;
    }

    try {
      final List<CustomerModel> customers =
          await _customerRepository.getCustomers(
        businessId: business.id,
      );

      if (!mounted) {
        return;
      }

      final CustomerModel? customer =
          await showModalBottomSheet<CustomerModel>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return _CustomerSelectionSheet(
            customers: customers,
          );
        },
      );

      if (customer == null ||
          !mounted) {
        return;
      }

      setState(() {
        _selectedCustomer = customer;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to load customers.',
        isError: true,
      );
    }
  }

  void _removeCustomer() {
    setState(() {
      _selectedCustomer = null;
    });
  }

  // ===========================================================================
  // SAVE SALE
  // ===========================================================================

  Future<void> _saveSale() async {
    if (_saving) {
      return;
    }

    final BusinessModel? business =
        _business;

    if (business == null) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );
      return;
    }

    if (business.id.trim().isEmpty) {
      _showMessage(
        'Business ID is missing.',
        isError: true,
      );
      return;
    }

    if (_items.isEmpty) {
      _showMessage(
        'Please add at least one product.',
        isError: true,
      );
      return;
    }

    if (!_discount.isFinite ||
        !_tax.isFinite ||
        !_paidAmount.isFinite) {
      _showMessage(
        'Discount, tax and paid amount must be valid numbers.',
        isError: true,
      );
      return;
    }

    if (_discount < 0 ||
        _tax < 0 ||
        _paidAmount < 0) {
      _showMessage(
        'Discount, tax and paid amount cannot be negative.',
        isError: true,
      );
      return;
    }

    if (_discount > _subtotal) {
      _showMessage(
        'Discount cannot be greater than subtotal.',
        isError: true,
      );
      return;
    }

    if (!_total.isFinite ||
        _total < 0) {
      _showMessage(
        'Sale total is invalid.',
        isError: true,
      );
      return;
    }

    if (_paidAmount > _total) {
      _showMessage(
        'Paid amount cannot be greater than total.',
        isError: true,
      );
      return;
    }

    final SaleModel? oldSale =
        widget.sale;

    final Map<String, double> oldQuantities =
        <String, double>{};

    if (oldSale != null) {
      for (final SaleItemModel item
          in oldSale.items) {
        final String productId =
            item.productId.trim();

        if (productId.isNotEmpty) {
          oldQuantities[productId] =
              (oldQuantities[productId] ?? 0) +
                  item.quantity;
        }
      }
    }

    for (final _SaleDraftItem item
        in _items) {
      if (!item.quantity.isFinite ||
          item.quantity <= 0) {
        _showMessage(
          'Quantity must be greater than zero.',
          isError: true,
        );
        return;
      }

      if (!item.sellingRate.isFinite ||
          item.sellingRate < 0) {
        _showMessage(
          'Selling rate cannot be negative.',
          isError: true,
        );
        return;
      }

      final double availableStock =
          item.product.currentStock +
              (oldQuantities[
                      item.product.id] ??
                  0);

      if (!availableStock.isFinite ||
          availableStock < 0) {
        _showMessage(
          'Invalid stock value for ${item.product.name}.',
          isError: true,
        );
        return;
      }

      if (item.quantity >
          availableStock) {
        _showMessage(
          'Insufficient stock for ${item.product.name}. '
          'Available: ${_formatNumber(availableStock)} '
          '${item.product.unit}.',
          isError: true,
        );
        return;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      final DateTime now =
          DateTime.now();

      final String invoiceNumber =
          oldSale?.invoiceNumber.trim().isNotEmpty == true
              ? oldSale!.invoiceNumber
              : await _saleRepository
                  .generateInvoiceNumber(
        businessId: business.id,
      );

      if (invoiceNumber.trim().isEmpty) {
        throw Exception(
          'Unable to generate invoice number.',
        );
      }

      final List<SaleItemModel> saleItems =
          _items.map(
        (item) {
          return SaleItemModel(
            productId: item.product.id,
            productName: item.product.name,
            quantity: item.quantity,
            unit: item.product.unit,
            sellingRate:
                item.sellingRate,
            discount: 0,
            tax: 0,
            total: item.total,
            costPrice:
                item.product.purchasePrice,
          );
        },
      ).toList();

      final SaleModel sale =
          SaleModel(
        id: oldSale?.id ?? '',
        businessId: business.id,
        customerId:
            _selectedCustomer?.id ?? '',
        customerName:
            _selectedCustomer?.name ?? '',
        items: saleItems,
        subtotal: _subtotal,
        discount: _discount,
        tax: _tax,
        total: _total,
        paidAmount: _paidAmount,
        paymentStatus:
            _paymentStatus,
        paymentMethod:
            _paymentMethod,
        date:
            oldSale?.date ?? now,
        notes:
            _notesController.text.trim(),
        invoiceNumber:
            invoiceNumber,
        createdAt:
            oldSale?.createdAt ?? now,
      );

      // -----------------------------------------------------------------------
      // CREATE NEW SALE
      // -----------------------------------------------------------------------
      if (oldSale == null) {
        final SaleModel savedSale =
            await _saleRepository
                .createSale(sale);

        bool stockProcessed = false;

        final List<
                LedgerTransactionModel>
            createdLedgerTransactions =
            <LedgerTransactionModel>[];

        try {
          // ---------------------------------------------------------------
          // 1. DEDUCT STOCK
          // ---------------------------------------------------------------
          await _saleStockService
              .processSaleStock(
            sale: savedSale,
          );

          stockProcessed = true;

          // ---------------------------------------------------------------
          // 2. CREATE CUSTOMER LEDGER
          // ---------------------------------------------------------------
          final String customerId =
              savedSale.customerId.trim();

          final double outstanding =
              savedSale.total -
                  savedSale.paidAmount;

          if (!outstanding.isFinite ||
              outstanding < 0) {
            throw Exception(
              'Sale outstanding amount is invalid.',
            );
          }

          if (customerId.isNotEmpty &&
              outstanding > 0) {
            final double currentBalance =
                await _ledgerService
                    .getCustomerBalance(
              businessId:
                  business.id.trim(),
              customerId:
                  customerId,
            );

            final LedgerTransactionModel
                ledgerTransaction =
                await _ledgerService
                    .createSaleLedgerEntry(
              businessId:
                  business.id.trim(),
              customerId:
                  customerId,
              customerName:
                  savedSale.customerName,
              saleAmount:
                  outstanding,
              balanceBefore:
                  currentBalance,
              referenceId:
                  savedSale.id,
              date:
                  savedSale.date,
              notes:
                  'Outstanding amount for sale ${savedSale.invoiceNumber}.',
            );

            createdLedgerTransactions
                .add(
              ledgerTransaction,
            );
          }
        } catch (error) {
          // ---------------------------------------------------------------
          // ROLLBACK NEW SALE
          // ---------------------------------------------------------------

          for (final LedgerTransactionModel
              transaction
              in createdLedgerTransactions
                  .reversed) {
            try {
              await _ledgerService
                  .deleteTransaction(
                businessId:
                    business.id.trim(),
                transactionId:
                    transaction.id,
              );
            } catch (_) {
              // Preserve original error.
            }
          }

          if (stockProcessed) {
            try {
              await _saleStockService
                  .reverseSaleStock(
                sale: savedSale,
              );
            } catch (_) {
              // Preserve original error.
            }
          }

          try {
            await _saleRepository
                .deleteSale(
              businessId:
                  business.id,
              saleId:
                  savedSale.id,
            );
          } catch (_) {
            // Preserve original error.
          }

          rethrow;
        }
      }

      // -----------------------------------------------------------------------
      // EDIT EXISTING SALE
      // -----------------------------------------------------------------------
      else {
        // The old sale's customer is validated during load. At save time,
        // selecting another customer or removing the customer is an explicit
        // user action and is therefore allowed.

        // Reverse old stock first.
        await _saleStockService
            .reverseSaleStock(
          sale: oldSale,
        );

        try {
          // Apply new sale stock.
          await _saleStockService
              .processSaleStock(
            sale: sale,
          );
        } catch (stockError) {
          try {
            await _saleStockService
                .processSaleStock(
              sale: oldSale,
            );
          } catch (_) {
            // Preserve the original stock error.
          }

          rethrow;
        }

        try {
          await _saleRepository
              .updateSale(sale);
        } catch (updateError) {
          try {
            await _saleStockService
                .reverseSaleStock(
              sale: sale,
            );

            await _saleStockService
                .processSaleStock(
              sale: oldSale,
            );
          } catch (_) {
            // Preserve the original update error.
          }

          rethrow;
        }

        // Keep customer ledger synchronized with edited sale.
        final List<
                LedgerTransactionModel>
            createdLedgerTransactions =
            <LedgerTransactionModel>[];

        try {
          await _syncEditedSaleLedger(
            business: business,
            oldSale: oldSale,
            updatedSale: sale,
            createdTransactions:
                createdLedgerTransactions,
          );
        } catch (ledgerError) {
          // Restore the previous sale state.

          for (final LedgerTransactionModel
              transaction
              in createdLedgerTransactions
                  .reversed) {
            try {
              await _ledgerService
                  .deleteTransaction(
                businessId:
                    business.id,
                transactionId:
                    transaction.id,
              );
            } catch (_) {
              // Preserve original ledger error.
            }
          }

          try {
            await _saleRepository
                .updateSale(
              oldSale,
            );
          } catch (_) {
            // Preserve original ledger error.
          }

          try {
            await _saleStockService
                .reverseSaleStock(
              sale: sale,
            );

            await _saleStockService
                .processSaleStock(
              sale: oldSale,
            );
          } catch (_) {
            // Preserve original ledger error.
          }

          rethrow;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showMessage(
        widget.isEditMode
            ? 'Sale $invoiceNumber updated successfully. Stock adjusted.'
            : 'Sale $invoiceNumber created successfully. Stock updated.',
      );

      await Future<void>.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showMessage(
        widget.isEditMode
            ? 'Unable to update sale: ${_cleanError(e)}'
            : 'Unable to create sale: ${_cleanError(e)}',
        isError: true,
      );
    }
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
  // EDIT SALE -> LEDGER SYNCHRONIZATION
  // ===========================================================================

  Future<void> _syncEditedSaleLedger({
    required BusinessModel business,
    required SaleModel oldSale,
    required SaleModel updatedSale,
    required List<
            LedgerTransactionModel>
        createdTransactions,
  }) async {
    final String businessId =
        business.id.trim();

    if (businessId.isEmpty) {
      throw Exception(
        'Business ID is missing.',
      );
    }

    final String oldCustomerId =
        oldSale.customerId.trim();

    if (oldCustomerId.isNotEmpty) {
      final List<
              LedgerTransactionModel>
          oldTransactions =
          await _ledgerService
              .getCustomerTransactions(
        businessId: businessId,
        customerId:
            oldCustomerId,
      );

      final List<
              LedgerTransactionModel>
          saleHistory =
          oldTransactions
              .where(
        (transaction) {
          final String type =
              transaction.transactionType
                  .trim()
                  .toUpperCase();

          return (type == 'SALE' ||
                  type ==
                      'SALE_REVERSAL') &&
              transaction.referenceId
                      .trim() ==
                  oldSale.id.trim();
        },
      ).toList();

      // LedgerService returns customer transactions newest-first.
      //
      // Only the newest active SALE entry is reversed.
      if (saleHistory.isNotEmpty &&
          saleHistory.first.transactionType
                  .trim()
                  .toUpperCase() ==
              'SALE') {
        final LedgerTransactionModel
            activeSaleTransaction =
            saleHistory.first;

        if (!activeSaleTransaction.amount.isFinite ||
            activeSaleTransaction.amount <= 0) {
          throw Exception(
            'Existing sale ledger transaction has an invalid amount.',
          );
        }

        final double currentBalance =
            await _ledgerService
                .getCustomerBalance(
          businessId:
              businessId,
          customerId:
              oldCustomerId,
        );

        final LedgerTransactionModel
            reversal =
            await _ledgerService
                .createSaleReversal(
          businessId:
              businessId,
          customerId:
              oldCustomerId,
          customerName:
              oldSale.customerName.trim().isEmpty
                  ? activeSaleTransaction
                      .customerName
                  : oldSale.customerName,
          saleAmount:
              activeSaleTransaction
                  .amount,
          balanceBefore:
              currentBalance,
          referenceId:
              oldSale.id,
          date:
              DateTime.now(),
          notes:
              'Ledger reversal for edited sale ${oldSale.invoiceNumber}.',
        );

        createdTransactions.add(
          reversal,
        );
      }
    }

    // -------------------------------------------------------------------------
    // CREATE NEW ACTIVE SALE LEDGER
    // -------------------------------------------------------------------------
    final String newCustomerId =
        updatedSale.customerId.trim();

    final double newOutstanding =
        updatedSale.total -
            updatedSale.paidAmount;

    if (!newOutstanding.isFinite ||
        newOutstanding < 0) {
      throw Exception(
        'Updated sale outstanding amount is invalid.',
      );
    }

    if (newCustomerId.isNotEmpty &&
        newOutstanding > 0) {
      final double currentBalance =
          await _ledgerService
              .getCustomerBalance(
        businessId:
            businessId,
        customerId:
            newCustomerId,
      );

      final LedgerTransactionModel
          newSaleTransaction =
          await _ledgerService
              .createSaleLedgerEntry(
        businessId:
            businessId,
        customerId:
            newCustomerId,
        customerName:
            updatedSale.customerName,
        saleAmount:
            newOutstanding,
        balanceBefore:
            currentBalance,
        referenceId:
            updatedSale.id,
        date:
            updatedSale.date,
        notes:
            'Outstanding amount for sale ${updatedSale.invoiceNumber}.',
      );

      createdTransactions.add(
        newSaleTransaction,
      );
    }
  }

  // ===========================================================================
  // EDIT QUANTITY
  // ===========================================================================

  Future<void> _editQuantity(
    _SaleDraftItem item,
  ) async {
    final TextEditingController controller =
        TextEditingController(
      text: _formatNumber(
        item.quantity,
      ),
    );

    final double? quantity =
        await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Enter Quantity',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration:
                InputDecoration(
              labelText: 'Quantity',
              suffixText:
                  item.product.unit,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                final double?
                    parsed =
                    double.tryParse(
                  controller.text
                      .trim(),
                );

                if (parsed == null ||
                    !parsed.isFinite ||
                    parsed <= 0) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  parsed,
                );
              },
              child: const Text(
                'Apply',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (quantity == null ||
        !mounted) {
      return;
    }

    setState(() {
      item.quantity = quantity;
    });

    _refreshTotals();
  }

  // ===========================================================================
  // EDIT SELLING RATE
  // ===========================================================================

  Future<void> _editSellingRate(
    _SaleDraftItem item,
  ) async {
    final TextEditingController controller =
        TextEditingController(
      text: _formatNumber(
        item.sellingRate,
      ),
    );

    final double? rate =
        await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Enter Selling Rate',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration:
                const InputDecoration(
              labelText:
                  'Selling Rate',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                final double?
                    parsed =
                    double.tryParse(
                  controller.text
                      .trim(),
                );

                if (parsed == null ||
                    !parsed.isFinite ||
                    parsed < 0) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  parsed,
                );
              },
              child: const Text(
                'Apply',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (rate == null ||
        !mounted) {
      return;
    }

    setState(() {
      item.sellingRate = rate;
    });

    _refreshTotals();
  }

  // ===========================================================================
  // TOTAL CALCULATIONS
  // ===========================================================================

  double get _subtotal {
    return _items.fold<double>(
      0,
      (
        total,
        item,
      ) =>
          total + item.total,
    );
  }

  double get _discount {
    return double.tryParse(
          _discountController.text
              .trim(),
        ) ??
        0;
  }

  double get _tax {
    return double.tryParse(
          _taxController.text.trim(),
        ) ??
        0;
  }

  double get _paidAmount {
    return double.tryParse(
          _paidController.text.trim(),
        ) ??
        0;
  }

  double get _total {
    final double value =
        _subtotal -
            _discount +
            _tax;

    return value < 0 ? 0 : value;
  }

  double get _outstanding {
    final double value =
        _total - _paidAmount;

    return value < 0 ? 0 : value;
  }

  String get _paymentStatus {
    if (_total <= 0) {
      return 'Pending';
    }

    if (_paidAmount <= 0) {
      return 'Pending';
    }

    if (_paidAmount >= _total) {
      return 'Paid';
    }

    return 'Partial';
  }

  void _refreshTotals() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ===========================================================================
  // UI
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? 'Edit Sale'
              : 'Add Sale',
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
      bottomNavigationBar:
          _loading ||
                  _errorMessage != null
              ? null
              : _buildBottomBar(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 58,
              color: AppColors.danger,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              _errorMessage ??
                  'Something went wrong.',
              textAlign:
                  TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(
              height: 18,
            ),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 1200,
          ),
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              120,
            ),
            children: [
              _buildCustomerCard(),
              const SizedBox(
                height: 14,
              ),
              _buildProductsCard(),
              const SizedBox(
                height: 14,
              ),
              _buildSummaryCard(),
              const SizedBox(
                height: 14,
              ),
              _buildPaymentCard(),
              const SizedBox(
                height: 14,
              ),
              _buildNotesCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    final CustomerModel?
        customer =
        _selectedCustomer;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Text(
                    'Customer',
                    style: Theme.of(
                            context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 14,
            ),
            if (customer == null)
              OutlinedButton.icon(
                onPressed:
                    _selectCustomer,
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                ),
                label: const Text(
                  'Select Customer',
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.all(
                  12,
                ),
                decoration:
                    BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(
                        alpha: 0.06,
                      ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  border: Border.all(
                    color: Theme.of(context)
                        .dividerColor,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      child: Text(
                        customer.name
                                .trim()
                                .isEmpty
                            ? '?'
                            : customer.name
                                .trim()
                                .substring(
                                  0,
                                  1,
                                )
                                .toUpperCase(),
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
                            customer.name,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                          if (customer.mobile
                              .trim()
                              .isNotEmpty)
                            Text(
                              customer.mobile,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip:
                          'Change customer',
                      onPressed:
                          _selectCustomer,
                      icon: const Icon(
                        Icons.edit_rounded,
                      ),
                    ),
                    IconButton(
                      tooltip:
                          'Remove customer',
                      onPressed:
                          _removeCustomer,
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Leave customer empty for a walk-in sale.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Text(
                    'Products',
                    style: Theme.of(
                            context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : _showProductSelector,
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                  label: const Text(
                    'Add Product',
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            if (_items.isEmpty)
              _buildEmptyProducts()
            else
              ..._items.map(
                _buildProductItem,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProducts() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 34,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .dividerColor,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 44,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(
            height: 10,
          ),
          const Text(
            'No products added yet.',
            style: TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          Text(
            'Add products to create this sale.',
            style: Theme.of(context)
                .textTheme
                .bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(
    _SaleDraftItem item,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .dividerColor,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                child: Icon(
                  Icons.inventory_2_outlined,
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
                      item.product.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      'Stock: ${_formatNumber(item.product.currentStock)} ${item.product.unit}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: _saving
                    ? null
                    : () =>
                        _removeProduct(
                          item,
                        ),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color:
                      AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          Row(
            children: [
              Expanded(
                child: _ValueBox(
                  label: 'Quantity',
                  value:
                      '${_formatNumber(item.quantity)} ${item.product.unit}',
                  onTap: _saving
                      ? null
                      : () =>
                          _editQuantity(
                            item,
                          ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: _ValueBox(
                  label: 'Selling Rate',
                  value:
                      _formatCurrency(
                    item.sellingRate,
                  ),
                  onTap: _saving
                      ? null
                      : () =>
                          _editSellingRate(
                            item,
                          ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: _ValueBox(
                  label: 'Total',
                  value:
                      _formatCurrency(
                    item.total,
                  ),
                  highlighted: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Sale Summary',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
            ),
            const SizedBox(
              height: 14,
            ),
            _SummaryRow(
              label: 'Subtotal',
              value:
                  _formatCurrency(
                _subtotal,
              ),
            ),
            _SummaryRow(
              label: 'Discount',
              value:
                  _formatCurrency(
                _discount,
              ),
            ),
            _SummaryRow(
              label: 'Tax',
              value:
                  _formatCurrency(
                _tax,
              ),
            ),
            const Divider(
              height: 22,
            ),
            _SummaryRow(
              label: 'Total',
              value:
                  _formatCurrency(
                _total,
              ),
              emphasized: true,
            ),
            _SummaryRow(
              label: 'Paid',
              value:
                  _formatCurrency(
                _paidAmount,
              ),
            ),
            _SummaryRow(
              label: 'Outstanding',
              value:
                  _formatCurrency(
                _outstanding,
              ),
              emphasized:
                  _outstanding > 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Payment',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
            ),
            const SizedBox(
              height: 14,
            ),
            TextField(
              controller:
                  _paidController,
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
              decoration:
                  const InputDecoration(
                labelText:
                    'Paid Amount',
                prefixIcon: Icon(
                  Icons.payments_outlined,
                ),
              ),
            ),
            const SizedBox(
              height: 14,
            ),
            DropdownButtonFormField<
                String>(
              initialValue:
                  _paymentMethod,
              decoration:
                  const InputDecoration(
                labelText:
                    'Payment Method',
                prefixIcon: Icon(
                  Icons.account_balance_wallet_outlined,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Cash',
                  child: Text(
                    'Cash',
                  ),
                ),
                DropdownMenuItem(
                  value: 'UPI',
                  child: Text(
                    'UPI',
                  ),
                ),
                DropdownMenuItem(
                  value: 'Card',
                  child: Text(
                    'Card',
                  ),
                ),
                DropdownMenuItem(
                  value: 'Bank Transfer',
                  child: Text(
                    'Bank Transfer',
                  ),
                ),
                DropdownMenuItem(
                  value: 'Other',
                  child: Text(
                    'Other',
                  ),
                ),
              ],
              onChanged:
                  _saving
                      ? null
                      : (value) {
                          if (value ==
                              null) {
                            return;
                          }

                          setState(() {
                            _paymentMethod =
                                value;
                          });
                        },
            ),
            const SizedBox(
              height: 14,
            ),
            Row(
              children: [
                Expanded(
                  child: _StatusChip(
                    label:
                        'Payment Status',
                    value:
                        _paymentStatus,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: _StatusChip(
                    label:
                        'Outstanding',
                    value:
                        _formatCurrency(
                      _outstanding,
                    ),
                    warning:
                        _outstanding > 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
            ),
            const SizedBox(
              height: 12,
            ),
            TextField(
              controller:
                  _notesController,
              maxLines: 4,
              textCapitalization:
                  TextCapitalization
                      .sentences,
              decoration:
                  const InputDecoration(
                hintText:
                    'Add optional notes...',
                alignLabelWithHint:
                    true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12,
        ),
        decoration:
            BoxDecoration(
          color: Theme.of(context)
              .scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context)
                  .dividerColor,
            ),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1200,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                      Text(
                        _formatCurrency(
                          _total,
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : _saveSale,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .check_circle_outline_rounded,
                        ),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : widget.isEditMode
                            ? 'Update Sale'
                            : 'Save Sale',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _formatNumber(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value
          .toInt()
          .toString();
    }

    return value
        .toStringAsFixed(2)
        .replaceFirst(
          RegExp(r'\.?0+$'),
          '',
        );
  }

  String _formatCurrency(
    double value,
  ) {
    return '₹${value.toStringAsFixed(2)}';
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
          content: Text(
            message,
          ),
          backgroundColor:
              isError
                  ? AppColors.danger
                  : null,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }
}

// ============================================================================
// SALE DRAFT ITEM
// ============================================================================

class _SaleDraftItem {
  _SaleDraftItem({
    required this.product,
    required this.quantity,
    required this.sellingRate,
  });

  final ProductModel product;

  double quantity;
  double sellingRate;

  double get total {
    return quantity * sellingRate;
  }
}

// ============================================================================
// VALUE BOX
// ============================================================================

class _ValueBox extends StatelessWidget {
  const _ValueBox({
    required this.label,
    required this.value,
    this.onTap,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(
    BuildContext context,
  ) {
    final Widget child =
        Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration:
          BoxDecoration(
        color: highlighted
            ? Theme.of(context)
                .colorScheme
                .primary
                .withValues(
                  alpha: 0.07,
                )
            : null,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color: Theme.of(context)
              .dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
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
            style: TextStyle(
              fontWeight:
                  FontWeight.w700,
              color: highlighted
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                  : null,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(
      borderRadius:
          BorderRadius.circular(
        10,
      ),
      onTap: onTap,
      child: child,
    );
  }
}

// ============================================================================
// SUMMARY ROW
// ============================================================================

class _SummaryRow
    extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

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
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasized
                  ? Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      )
                  : null,
            ),
          ),
          Text(
            value,
            style: emphasized
                ? Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    )
                : const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATUS CHIP
// ============================================================================

class _StatusChip
    extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        color: warning
            ? AppColors.warning
                .withValues(
                alpha: 0.08,
              )
            : Theme.of(context)
                .colorScheme
                .primary
                .withValues(
                  alpha: 0.06,
                ),
        border: Border.all(
          color: warning
              ? AppColors.warning
                  .withValues(
                  alpha: 0.30,
                )
              : Theme.of(context)
                  .dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
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
            style: const TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOMER SELECTION SHEET
// ============================================================================

class _CustomerSelectionSheet
    extends StatefulWidget {
  const _CustomerSelectionSheet({
    required this.customers,
  });

  final List<CustomerModel> customers;

  @override
  State<
          _CustomerSelectionSheet>
      createState() =>
          _CustomerSelectionSheetState();
}

class _CustomerSelectionSheetState
    extends State<
        _CustomerSelectionSheet> {
  final TextEditingController
      _searchController =
      TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return SafeArea(
      child: Container(
        constraints:
            const BoxConstraints(
          maxHeight: 720,
        ),
        decoration:
            BoxDecoration(
          color: Theme.of(context)
              .scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(
              height: 10,
            ),
            Container(
              width: 42,
              height: 4,
              decoration:
                  BoxDecoration(
                color:
                    Theme.of(context)
                        .dividerColor,
                borderRadius:
                    BorderRadius.circular(
                  99,
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select Customer',
                      style: Theme.of(
                              context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
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
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
              ),
              child: TextField(
                controller:
                    _searchController,
                onChanged: (_) {
                  setState(() {});
                },
                decoration:
                    const InputDecoration(
                  hintText:
                      'Search customer...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            Expanded(
              child:
                  _buildCustomerList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerList() {
    final String query =
        _searchController.text
            .trim()
            .toLowerCase();

    final List<CustomerModel>
        customers =
        widget.customers.where(
      (customer) {
        if (query.isEmpty) {
          return true;
        }

        return customer.name
                .toLowerCase()
                .contains(query) ||
            customer.mobile
                .toLowerCase()
                .contains(query) ||
            customer.email
                .toLowerCase()
                .contains(query);
      },
    ).toList();

    if (customers.isEmpty) {
      return const Center(
        child: Text(
          'No customers found.',
        ),
      );
    }

    return ListView.separated(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        4,
        18,
        24,
      ),
      itemCount:
          customers.length,
      separatorBuilder:
          (_, _) =>
              const SizedBox(
        height: 8,
      ),
      itemBuilder:
          (
        context,
        index,
      ) {
        final CustomerModel
            customer =
            customers[index];

        return Card(
          child: ListTile(
            leading:
                CircleAvatar(
              child: Text(
                customer.name
                        .trim()
                        .isEmpty
                    ? '?'
                    : customer.name
                        .trim()
                        .substring(
                          0,
                          1,
                        )
                        .toUpperCase(),
              ),
            ),
            title: Text(
              customer.name,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
            ),
            subtitle:
                customer.mobile
                        .trim()
                        .isEmpty
                    ? null
                    : Text(
                        customer.mobile,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                      ),
            trailing:
                const Icon(
              Icons
                  .chevron_right_rounded,
            ),
            onTap: () {
              Navigator.pop(
                context,
                customer,
              );
            },
          ),
        );
      },
    );
  }
}