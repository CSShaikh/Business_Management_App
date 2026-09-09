import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/product_model.dart';
import '../../models/purchase_model.dart';
import '../../models/supplier_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/purchase_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../core/services/purchase_stock_service.dart';

class AddPurchaseScreen extends StatefulWidget {
  final PurchaseModel? purchase;

  const AddPurchaseScreen({
    super.key,
    this.purchase,
  });

  bool get isEditMode => purchase != null;

  @override
  State<AddPurchaseScreen> createState() =>
      _AddPurchaseScreenState();
}

class _PurchaseDraftItem {
  final ProductModel product;
  double quantity;
  double purchaseRate;

  _PurchaseDraftItem({
    required this.product,
    required this.quantity,
    required this.purchaseRate,
  });

  double get total => quantity * purchaseRate;
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();

  final BusinessRepository _businessRepository =
      BusinessRepository();

  final SupplierRepository _supplierRepository =
      SupplierRepository();

  final ProductRepository _productRepository =
      ProductRepository();

  final PurchaseRepository _purchaseRepository =
      PurchaseRepository();

  final PurchaseStockService _purchaseStockService =
      PurchaseStockService();

  final TextEditingController _discountController =
      TextEditingController();

  final TextEditingController _taxController =
      TextEditingController();

  final TextEditingController _paidAmountController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  BusinessModel? _business;

  SupplierModel? _selectedSupplier;

  final List<_PurchaseDraftItem> _items = [];

  DateTime _purchaseDate = DateTime.now();

  String _paymentMethod = 'Cash';

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  final List<String> _paymentMethods = const [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
    'Credit',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _taxController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final business =
          await _businessRepository.getBusinessForCurrentUser();

      if (!mounted) {
        return;
      }

      if (business == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Business information was not found.';
        });
        return;
      }

      _business = business;

      if (widget.purchase != null) {
        await _loadExistingPurchase(widget.purchase!);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load purchase information.';
      });
    }
  }

  Future<void> _loadExistingPurchase(
    PurchaseModel purchase,
  ) async {
    _purchaseDate = purchase.date;

    _paymentMethod = purchase.paymentMethod.isEmpty
        ? 'Cash'
        : purchase.paymentMethod;

    if (!_paymentMethods.contains(_paymentMethod)) {
      _paymentMethod = 'Other';
    }

    _discountController.text =
        purchase.discount.toStringAsFixed(2);

    _taxController.text =
        purchase.tax.toStringAsFixed(2);

    _paidAmountController.text =
        purchase.paidAmount.toStringAsFixed(2);

    _notesController.text = purchase.notes;

    if (purchase.supplierId.isNotEmpty &&
        _business != null) {
      try {
        _selectedSupplier =
            await _supplierRepository.getSupplier(
          _business!.id,
          purchase.supplierId,
        );
      } catch (_) {
        _selectedSupplier = null;
      }
    }

    final products = _business == null
        ? <ProductModel>[]
        : await _productRepository.getProducts(
            _business!.id,
          );

    for (final item in purchase.items) {
      ProductModel? product;

      for (final candidate in products) {
        if (candidate.id == item.productId) {
          product = candidate;
          break;
        }
      }

      if (product != null) {
        _items.add(
          _PurchaseDraftItem(
            product: product,
            quantity: item.quantity,
            purchaseRate: item.purchaseRate,
          ),
        );
      }
    }
  }

  double _parseDouble(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }

  double get _subtotal {
    return _items.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
  }

  double get _discount {
    final value = _parseDouble(
      _discountController.text,
    );

    if (value < 0) {
      return 0;
    }

    return value;
  }

  double get _tax {
    final value = _parseDouble(
      _taxController.text,
    );

    if (value < 0) {
      return 0;
    }

    return value;
  }

  double get _total {
    final value = _subtotal - _discount + _tax;

    return value < 0 ? 0 : value;
  }

  double get _paidAmount {
    final value = _parseDouble(
      _paidAmountController.text,
    );

    if (value < 0) {
      return 0;
    }

    return value;
  }

  double get _outstanding {
    final value = _total - _paidAmount;

    return value < 0 ? 0 : value;
  }

  String get _paymentStatus {
    const tolerance = 0.000001;

    if (_total <= tolerance) {
      return 'Paid';
    }

    if (_paidAmount <= tolerance) {
      return 'Unpaid';
    }

    if (_paidAmount >= _total - tolerance) {
      return 'Paid';
    }

    return 'Partial';
  }

  Future<void> _selectSupplier() async {
    if (_business == null) {
      return;
    }

    final suppliers =
        await _supplierRepository.getSuppliers(
      _business!.id,
    );

    if (!mounted) {
      return;
    }

    final selected =
        await showModalBottomSheet<SupplierModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _SupplierPickerSheet(
          suppliers: suppliers,
          selectedSupplier: _selectedSupplier,
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedSupplier = selected;
      });
    }
  }

  Future<void> _addProduct() async {
    if (_business == null) {
      return;
    }

    final products =
        await _productRepository.getActiveProducts(
      _business!.id,
    );

    if (!mounted) {
      return;
    }

    final selected =
        await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _ProductPickerSheet(
          products: products,
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    final existingIndex = _items.indexWhere(
      (item) => item.product.id == selected.id,
    );

    if (existingIndex >= 0) {
      setState(() {
        _items[existingIndex].quantity += 1;
      });

      _showMessage(
        '${selected.name} quantity increased.',
      );
      return;
    }

    setState(() {
      _items.add(
        _PurchaseDraftItem(
          product: selected,
          quantity: 1,
          purchaseRate: selected.purchasePrice,
        ),
      );
    });
  }

  Future<void> _editItem(int index) async {
    final item = _items[index];

    final quantityController = TextEditingController(
      text: _formatNumber(item.quantity),
    );

    final rateController = TextEditingController(
      text: item.purchaseRate.toStringAsFixed(2),
    );

    final result =
        await showDialog<Map<String, double>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.product.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,3}'),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(
                    Icons.numbers_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: rateController,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}'),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Purchase Rate',
                  prefixIcon: Icon(
                    Icons.currency_rupee_rounded,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final quantity =
                    _parseDouble(
                  quantityController.text,
                );

                final rate =
                    _parseDouble(
                  rateController.text,
                );

                if (quantity <= 0 || rate < 0) {
                  return;
                }

                Navigator.pop(
                  context,
                  {
                    'quantity': quantity,
                    'rate': rate,
                  },
                );
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );

    quantityController.dispose();
    rateController.dispose();

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      item.quantity = result['quantity'] ?? 1;
      item.purchaseRate = result['rate'] ?? 0;
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _purchaseDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _purchaseDate.hour,
        _purchaseDate.minute,
        _purchaseDate.second,
      );
    });
  }

  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_business == null) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );
      return;
    }

    if (_selectedSupplier == null) {
      _showMessage(
        'Please select a supplier.',
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

    if (_total <= 0) {
      _showMessage(
        'Purchase total must be greater than zero.',
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

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();

      final purchaseItems = _items.map(
        (item) {
          return PurchaseItemModel(
            productId: item.product.id,
            productName: item.product.name,
            quantity: item.quantity,
            unit: item.product.unit,
            purchaseRate: item.purchaseRate,
            total: item.total,
          );
        },
      ).toList();

      final purchase = PurchaseModel(
        id: widget.purchase?.id ?? '',
        businessId: _business!.id,
        supplierId: _selectedSupplier!.id,
        supplierName: _selectedSupplier!.name,
        items: purchaseItems,
        subtotal: _subtotal,
        discount: _discount,
        tax: _tax,
        total: _total,
        paidAmount: _paidAmount,
        paymentStatus: _paymentStatus,
        paymentMethod: _paymentMethod,
        date: _purchaseDate,
        notes: _notesController.text.trim(),
        createdAt: widget.purchase?.createdAt ?? now,
      );

      /*
       * IMPORTANT:
       *
       * New Purchase:
       * PurchaseRepository creates the purchase first.
       * Then PurchaseStockService increases product stock.
       *
       * Edit Purchase:
       * Existing stock handling is intentionally not performed
       * here yet because the old purchase stock must first be
       * reversed before applying the new purchase quantities.
       *
       * This prevents accidentally adding the edited purchase
       * quantity on top of the existing stock.
       */

      if (widget.isEditMode) {
        await _purchaseRepository.updatePurchase(
          purchase,
        );
      } else {
        await _purchaseRepository.createPurchase(
          purchase,
        );

        await _purchaseStockService.processPurchaseStock(
          purchase: purchase,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditMode
                ? 'Purchase updated successfully.'
                : 'Purchase saved and stock updated successfully.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showMessage(
        'Unable to save purchase: $e',
        isError: true,
      );
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.danger : null,
      ),
    );
  }

  String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditMode
                ? 'Edit Purchase'
                : 'Add Purchase',
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditMode
                ? 'Edit Purchase'
                : 'Add Purchase',
          ),
        ),
        body: Center(
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
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _initialize();
                  },
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? 'Edit Purchase'
              : 'Add Purchase',
        ),
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final isDesktop =
                constraints.maxWidth >= 1000;

            final content = isDesktop
                ? _buildDesktopLayout()
                : _buildMobileLayout();

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 28 : 16,
                20,
                isDesktop ? 28 : 16,
                110,
              ),
              child: content,
            );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildSupplierCard(),
        const SizedBox(height: 16),
        _buildDateAndPaymentCard(),
        const SizedBox(height: 16),
        _buildProductsCard(),
        const SizedBox(height: 16),
        _buildSummaryCard(),
        const SizedBox(height: 16),
        _buildNotesCard(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildSupplierCard(),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildDateAndPaymentCard(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildProductsCard(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildNotesCard(),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildSummaryCard(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSupplierCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.store_rounded,
              title: 'Supplier',
              subtitle:
                  'Select the supplier for this purchase',
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectSupplier,
              borderRadius:
                  BorderRadius.circular(12),
              child: InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText: 'Supplier',
                  prefixIcon: Icon(
                    Icons.business_rounded,
                  ),
                  suffixIcon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                  ),
                ),
                child: Text(
                  _selectedSupplier?.name ??
                      'Select supplier',
                  style: TextStyle(
                    color: _selectedSupplier == null
                        ? AppColors
                            .lightTextSecondary
                        : null,
                    fontWeight:
                        _selectedSupplier == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (_selectedSupplier != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withValues(alpha: 0.06),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_rounded,
                      size: 17,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedSupplier!
                                .mobile
                                .trim()
                                .isEmpty
                            ? 'Mobile number not available'
                            : _selectedSupplier!
                                .mobile,
                        style: const TextStyle(
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateAndPaymentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.receipt_long_rounded,
              title: 'Purchase Details',
              subtitle:
                  'Date and payment information',
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDate,
              borderRadius:
                  BorderRadius.circular(12),
              child: InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText: 'Purchase Date',
                  prefixIcon: Icon(
                    Icons.calendar_month_rounded,
                  ),
                  suffixIcon: Icon(
                    Icons.edit_calendar_rounded,
                  ),
                ),
                child: Text(
                  DateFormat(
                    'dd MMM yyyy',
                  ).format(_purchaseDate),
                ),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration:
                  const InputDecoration(
                labelText: 'Payment Method',
                prefixIcon: Icon(
                  Icons.payments_rounded,
                ),
              ),
              items: _paymentMethods
                  .map(
                    (method) =>
                        DropdownMenuItem<String>(
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
                  _paymentMethod = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _SectionTitle(
                    icon: Icons.inventory_2_rounded,
                    title: 'Products',
                    subtitle:
                        'Add products included in this purchase',
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                  label: const Text(
                    'Add Product',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_items.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 30,
                ),
                decoration: BoxDecoration(
                  color: AppColors
                      .lightBackground,
                  borderRadius:
                      BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.lightBorder,
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 40,
                      color: AppColors
                          .lightTextSecondary,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No products added',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap Add Product to start the purchase.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color: AppColors
                            .lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  ...List.generate(
                    _items.length,
                    (index) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 10,
                        ),
                        child: _PurchaseItemCard(
                          item: _items[index],
                          index: index,
                          onEdit: () =>
                              _editItem(index),
                          onDelete: () =>
                              _removeItem(index),
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.calculate_rounded,
              title: 'Amount Summary',
              subtitle:
                  'Review the final purchase amount',
            ),
            const SizedBox(height: 16),
            _AmountRow(
              label: 'Subtotal',
              value: _subtotal,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _discountController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}'),
                ),
              ],
              onChanged: (_) {
                setState(() {});
              },
              decoration:
                  const InputDecoration(
                labelText: 'Discount',
                prefixIcon: Icon(
                  Icons.discount_outlined,
                ),
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _taxController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}'),
                ),
              ],
              onChanged: (_) {
                setState(() {});
              },
              decoration:
                  const InputDecoration(
                labelText: 'Tax',
                prefixIcon: Icon(
                  Icons.percent_rounded,
                ),
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _AmountRow(
              label: 'Total',
              value: _total,
              isBold: true,
              large: true,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller:
                  _paidAmountController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}'),
                ),
              ],
              onChanged: (_) {
                setState(() {});
              },
              validator: (value) {
                final paid =
                    _parseDouble(value ?? '');

                if (paid < 0) {
                  return 'Invalid paid amount.';
                }

                if (paid > _total) {
                  return 'Cannot exceed total.';
                }

                return null;
              },
              decoration:
                  const InputDecoration(
                labelText: 'Paid Amount',
                prefixIcon: Icon(
                  Icons.payments_outlined,
                ),
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _PaymentStatusChip(
                  status: _paymentStatus,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _AmountRow(
              label: 'Outstanding',
              value: _outstanding,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.notes_rounded,
              title: 'Notes',
              subtitle:
                  'Optional notes for this purchase',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              minLines: 4,
              maxLines: 7,
              textCapitalization:
                  TextCapitalization.sentences,
              decoration:
                  const InputDecoration(
                hintText:
                    'Enter purchase notes...',
                alignLabelWithHint: true,
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
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          10,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              color: Colors.black
                  .withValues(alpha: 0.08),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        Navigator.pop(context);
                      },
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed:
                    _isSaving ? null : _savePurchase,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.check_rounded,
                      ),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : widget.isEditMode
                          ? 'Update Purchase'
                          : 'Save Purchase',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary
                .withValues(alpha: 0.10),
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color:
                      AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PurchaseItemCard extends StatelessWidget {
  final _PurchaseDraftItem item;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PurchaseItemCard({
    required this.item,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary
                  .withValues(alpha: 0.10),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_formatNumber(item.quantity)} ${item.product.unit} × ${_currency(item.purchaseRate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color:
                        AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _currency(item.total),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            onSelected: (value) {
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
                      Icon(
                        Icons.edit_outlined,
                      ),
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
                        color:
                            AppColors.danger,
                      ),
                      SizedBox(width: 10),
                      Text('Remove'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  static String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  final bool large;

  const _AmountRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: large ? 15 : 13,
              fontWeight: isBold
                  ? FontWeight.w800
                  : FontWeight.w500,
            ),
          ),
        ),
        Text(
          NumberFormat.currency(
            locale: 'en_IN',
            symbol: '₹',
            decimalDigits: 2,
          ).format(value),
          style: TextStyle(
            fontSize: large ? 18 : 14,
            fontWeight: isBold
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PaymentStatusChip extends StatelessWidget {
  final String status;

  const _PaymentStatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color color;

    switch (status.toLowerCase()) {
      case 'paid':
        color = AppColors.success;
        break;
      case 'partial':
        color = AppColors.warning;
        break;
      case 'unpaid':
        color = AppColors.danger;
        break;
      default:
        color = AppColors.info;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SupplierPickerSheet extends StatefulWidget {
  final List<SupplierModel> suppliers;
  final SupplierModel? selectedSupplier;

  const _SupplierPickerSheet({
    required this.suppliers,
    required this.selectedSupplier,
  });

  @override
  State<_SupplierPickerSheet> createState() =>
      _SupplierPickerSheetState();
}

class _SupplierPickerSheetState
    extends State<_SupplierPickerSheet> {
  final TextEditingController _searchController =
      TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SupplierModel> get _filtered {
    final query =
        _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return widget.suppliers;
    }

    return widget.suppliers.where(
      (supplier) {
        return supplier.name
                .toLowerCase()
                .contains(query) ||
            supplier.contactPerson
                .toLowerCase()
                .contains(query) ||
            supplier.mobile
                .toLowerCase()
                .contains(query) ||
            supplier.email
                .toLowerCase()
                .contains(query);
      },
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height:
            MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16,
          ),
          child: Column(
            children: [
              TextField(
                controller:
                    _searchController,
                onChanged: (_) {
                  setState(() {});
                },
                decoration:
                    const InputDecoration(
                  hintText:
                      'Search supplier...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No suppliers found.',
                        ),
                      )
                    : ListView.separated(
                        itemCount:
                            _filtered.length,
                        separatorBuilder:
                            (_, _) =>
                                const Divider(
                          height: 1,
                        ),
                        itemBuilder:
                            (context, index) {
                          final supplier =
                              _filtered[index];

                          final selected =
                              widget.selectedSupplier
                                      ?.id ==
                                  supplier.id;

                          return ListTile(
                            leading:
                                CircleAvatar(
                              backgroundColor:
                                  AppColors
                                      .primary
                                      .withValues(
                                    alpha: 0.10,
                                  ),
                              child: const Icon(
                                Icons.business_rounded,
                                color:
                                    AppColors.primary,
                              ),
                            ),
                            title: Text(
                              supplier.name,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            subtitle:
                                supplier.mobile
                                        .trim()
                                        .isEmpty
                                    ? null
                                    : Text(
                                        supplier.mobile,
                                      ),
                            trailing: selected
                                ? const Icon(
                                    Icons
                                        .check_circle_rounded,
                                    color:
                                        AppColors.success,
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(
                                context,
                                supplier,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  final List<ProductModel> products;

  const _ProductPickerSheet({
    required this.products,
  });

  @override
  State<_ProductPickerSheet> createState() =>
      _ProductPickerSheetState();
}

class _ProductPickerSheetState
    extends State<_ProductPickerSheet> {
  final TextEditingController _searchController =
      TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductModel> get _filtered {
    final query =
        _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return widget.products;
    }

    return widget.products.where(
      (product) {
        return product.name
                .toLowerCase()
                .contains(query) ||
            product.category
                .toLowerCase()
                .contains(query) ||
            product.unit
                .toLowerCase()
                .contains(query);
      },
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height:
            MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16,
          ),
          child: Column(
            children: [
              TextField(
                controller:
                    _searchController,
                onChanged: (_) {
                  setState(() {});
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
              const SizedBox(height: 12),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No active products found.',
                        ),
                      )
                    : ListView.separated(
                        itemCount:
                            _filtered.length,
                        separatorBuilder:
                            (_, _) =>
                                const Divider(
                          height: 1,
                        ),
                        itemBuilder:
                            (context, index) {
                          final product =
                              _filtered[index];

                          return ListTile(
                            leading:
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
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  10,
                                ),
                              ),
                              child: const Icon(
                                Icons
                                    .inventory_2_rounded,
                                color:
                                    AppColors.primary,
                              ),
                            ),
                            title: Text(
                              product.name,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${product.category.isEmpty ? 'Product' : product.category} • ${product.unit} • Stock: ${_formatNumber(product.currentStock)}',
                            ),
                            trailing: Text(
                              NumberFormat.currency(
                                locale: 'en_IN',
                                symbol: '₹',
                                decimalDigits: 2,
                              ).format(
                                product.purchasePrice,
                              ),
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(
                                context,
                                product,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}