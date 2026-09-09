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
import '../../repositories/sale_repository.dart';
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
final BusinessRepository _businessRepository = BusinessRepository();

final ProductRepository _productRepository = ProductRepository();

final CustomerRepository _customerRepository = CustomerRepository();

final SaleRepository _saleRepository = SaleRepository();

final SaleStockService _saleStockService = SaleStockService();

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
final List<_SaleDraftItem> _items = <_SaleDraftItem>[];

bool _loading = true;
bool _saving = false;

String? _errorMessage;

String _paymentMethod = 'Cash';

@override
void initState() {
super.initState();


_discountController.addListener(_refreshTotals);
_taxController.addListener(_refreshTotals);
_paidController.addListener(_refreshTotals);

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
      await _businessRepository.getBusinessForCurrentUser();

  if (business == null) {
    throw Exception(
      'Business profile not found. Please complete business setup first.',
    );
  }

  final List<ProductModel> products =
      await _productRepository.getActiveProducts(
    business.id,
  );

  if (!mounted) return;

  if (widget.isEditMode) {
    await _loadExistingSaleData(
      business: business,
      products: products,
      sale: widget.sale!,
    );
  }

  if (!mounted) return;

  setState(() {
    _business = business;
    _products = products;
    _loading = false;
    _errorMessage = null;
  });
} catch (e) {
  if (!mounted) return;

  setState(() {
    _loading = false;
    _errorMessage =
        'Unable to load products and business information.';
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
    throw Exception('Sale does not belong to the current business.');
  }

  CustomerModel? customer;

  if (sale.customerId.trim().isNotEmpty) {
    customer = await _customerRepository.getCustomer(
      businessId: business.id,
      customerId: sale.customerId.trim(),
    );
  }

  final List<_SaleDraftItem> draftItems = <_SaleDraftItem>[];

  for (final SaleItemModel saleItem in sale.items) {
    final String productId = saleItem.productId.trim();
    if (productId.isEmpty) {
      throw Exception('Sale contains an item with an invalid product ID.');
    }

    ProductModel? product;

    for (final ProductModel candidate in products) {
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

    draftItems.add(
      _SaleDraftItem(
        product: product,
        quantity: saleItem.quantity,
        sellingRate: saleItem.sellingRate,
      ),
    );
  }

  _selectedCustomer = customer;
  _items
    ..clear()
    ..addAll(draftItems);

  _discountController.text = _formatNumber(sale.discount);
  _taxController.text = _formatNumber(sale.tax);
  _paidController.text = _formatNumber(sale.paidAmount);
  _notesController.text = sale.notes;
  _paymentMethod = sale.paymentMethod.trim().isEmpty
      ? 'Cash'
      : sale.paymentMethod;
}

// ===========================================================================
// TOTALS
// ===========================================================================

double get _subtotal {
double value = 0;


for (final _SaleDraftItem item in _items) {
  value += item.total;
}

return value;


}

double get _discount {
return _parseAmount(_discountController.text);
}

double get _tax {
return _parseAmount(_taxController.text);
}

double get _total {
final double value = _subtotal - _discount + _tax;


return value < 0 ? 0 : value;


}

double get _paidAmount {
return _parseAmount(_paidController.text);
}

double get _outstanding {
final double value = _total - _paidAmount;


return value < 0 ? 0 : value;


}

String get _paymentStatus {
if (_total <= 0) {
return 'unpaid';
}


if (_paidAmount <= 0) {
  return 'unpaid';
}

if (_paidAmount >= _total) {
  return 'paid';
}

return 'partial';


}

double _parseAmount(String value) {
return double.tryParse(value.trim()) ?? 0;
}

void _refreshTotals() {
if (!mounted) return;


setState(() {});


}

// ===========================================================================
// ADD PRODUCT
// ===========================================================================

Future<void> _selectProduct() async {
if (_products.isEmpty) {
_showMessage(
'No active products available.',
isError: true,
);
return;
}


final ProductModel? product =
    await showModalBottomSheet<ProductModel>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheetContext) {
    return _ProductPicker(
      products: _products,
      existingProductIds: _items
          .map(
            (item) => item.product.id,
          )
          .toSet(),
    );
  },
);

if (product == null) {
  return;
}

final bool alreadyAdded = _items.any(
  (item) => item.product.id == product.id,
);

if (alreadyAdded) {
  _showMessage(
    '${product.name} is already added.',
    isError: true,
  );
  return;
}

setState(() {
  _items.add(
    _SaleDraftItem(
      product: product,
      quantity: 1,
      sellingRate: product.sellingPrice,
    ),
  );
});


}

// ===========================================================================
// SELECT CUSTOMER
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

  if (!mounted) return;

  final CustomerModel? customer =
      await showModalBottomSheet<CustomerModel>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return _CustomerPicker(
        customers: customers,
      );
    },
  );

  if (customer == null) {
    return;
  }

  setState(() {
    _selectedCustomer = customer;
  });
} catch (e) {
  if (!mounted) return;

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
  if (_saving) return;

  final BusinessModel? business = _business;

  if (business == null) {
    _showMessage(
      'Business information is not available.',
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

  if (_discount < 0 || _tax < 0 || _paidAmount < 0) {
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

  if (_paidAmount > _total) {
    _showMessage(
      'Paid amount cannot be greater than total.',
      isError: true,
    );
    return;
  }

  // In edit mode, stock validation must allow the quantity already present
  // in the old sale. The old sale stock is restored before the new sale
  // quantity is applied, so the final stock check is performed against the
  // current product stock plus the old quantity for matching products.
  final SaleModel? oldSale = widget.sale;
  final Map<String, double> oldQuantities = <String, double>{};

  if (oldSale != null) {
    for (final SaleItemModel item in oldSale.items) {
      final String productId = item.productId.trim();
      if (productId.isNotEmpty) {
        oldQuantities[productId] =
            (oldQuantities[productId] ?? 0) + item.quantity;
      }
    }
  }

  for (final _SaleDraftItem item in _items) {
    if (item.quantity <= 0) {
      _showMessage(
        'Quantity must be greater than zero.',
        isError: true,
      );
      return;
    }

    if (item.sellingRate < 0) {
      _showMessage(
        'Selling rate cannot be negative.',
        isError: true,
      );
      return;
    }

    final double availableStock =
        item.product.currentStock +
        (oldQuantities[item.product.id] ?? 0);

    if (item.quantity > availableStock) {
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
    final DateTime now = DateTime.now();
    final String invoiceNumber = oldSale?.invoiceNumber ??
        await _saleRepository.generateInvoiceNumber(
          businessId: business.id,
        );

    final List<SaleItemModel> saleItems = _items.map(
      (item) {
        return SaleItemModel(
          productId: item.product.id,
          productName: item.product.name,
          quantity: item.quantity,
          unit: item.product.unit,
          sellingRate: item.sellingRate,
          discount: 0,
          tax: 0,
          total: item.total,
          costPrice: item.product.purchasePrice,
        );
      },
    ).toList();

    final SaleModel sale = SaleModel(
      id: oldSale?.id ?? '',
      businessId: business.id,
      customerId: _selectedCustomer?.id ?? '',
      customerName: _selectedCustomer?.name ?? '',
      items: saleItems,
      subtotal: _subtotal,
      discount: _discount,
      tax: _tax,
      total: _total,
      paidAmount: _paidAmount,
      paymentStatus: _paymentStatus,
      paymentMethod: _paymentMethod,
      date: oldSale?.date ?? now,
      notes: _notesController.text.trim(),
      invoiceNumber: invoiceNumber,
      createdAt: oldSale?.createdAt ?? now,
    );

    if (oldSale == null) {
      final SaleModel savedSale =
          await _saleRepository.createSale(sale);

      try {
        await _saleStockService.processSaleStock(
          sale: savedSale,
        );
      } catch (stockError) {
        try {
          await _saleRepository.deleteSale(
            businessId: business.id,
            saleId: savedSale.id,
          );
        } catch (_) {
          // Preserve the original stock error for the user.
        }

        rethrow;
      }
    } else {
      // Reverse the old sale first, apply the new sale stock, and only then
      // update the sale document. If the new stock operation fails, restore
      // the old stock so the existing sale remains valid.
      await _saleStockService.reverseSaleStock(
        sale: oldSale,
      );

      try {
        await _saleStockService.processSaleStock(
          sale: sale,
        );
      } catch (stockError) {
        try {
          await _saleStockService.processSaleStock(
            sale: oldSale,
          );
        } catch (_) {
          // Preserve the original stock error for the user.
        }

        rethrow;
      }

      try {
        await _saleRepository.updateSale(sale);
      } catch (updateError) {
        try {
          await _saleStockService.reverseSaleStock(
            sale: sale,
          );
          await _saleStockService.processSaleStock(
            sale: oldSale,
          );
        } catch (_) {
          // Preserve the original update error for the user.
        }

        rethrow;
      }
    }

    if (!mounted) return;

    _showMessage(
      widget.isEditMode
          ? 'Sale $invoiceNumber updated successfully. Stock adjusted.'
          : 'Sale $invoiceNumber created successfully. Stock updated.',
    );

    await Future<void>.delayed(
      const Duration(milliseconds: 500),
    );

    if (!mounted) return;

    Navigator.pop(
      context,
      true,
    );
  } catch (e) {
    if (!mounted) return;

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

String _cleanError(Object error) {
final String message = error.toString();


if (message.startsWith('Exception: ')) {
  return message.substring('Exception: '.length);
}

return message;


}

// ===========================================================================
// EDIT QUANTITY
// ===========================================================================

Future<void> _editQuantity(
_SaleDraftItem item,
) async {
final TextEditingController controller =
TextEditingController(
text: _formatNumber(item.quantity),
);


final double? quantity = await showDialog<double>(
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
        decoration: InputDecoration(
          labelText: 'Quantity',
          suffixText: item.product.unit,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
          },
          child: const Text(
            'Cancel',
          ),
        ),
        FilledButton(
          onPressed: () {
            final double? value =
                double.tryParse(
              controller.text.trim(),
            );

            Navigator.pop(
              dialogContext,
              value,
            );
          },
          child: const Text(
            'Update',
          ),
        ),
      ],
    );
  },
);

controller.dispose();

if (quantity == null) {
  return;
}

if (quantity <= 0) {
  _showMessage(
    'Quantity must be greater than zero.',
    isError: true,
  );
  return;
}

if (quantity > item.product.currentStock) {
  _showMessage(
    'Only ${_formatNumber(item.product.currentStock)} '
    '${item.product.unit} available in stock.',
    isError: true,
  );
  return;
}

setState(() {
  item.quantity = quantity;
});


}

// ===========================================================================
// EDIT RATE
// ===========================================================================

Future<void> _editRate(
_SaleDraftItem item,
) async {
final TextEditingController controller =
TextEditingController(
text: item.sellingRate.toStringAsFixed(2),
);


final double? rate = await showDialog<double>(
  context: context,
  builder: (dialogContext) {
    return AlertDialog(
      title: const Text(
        'Selling Rate',
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType:
            const TextInputType.numberWithOptions(
          decimal: true,
        ),
        decoration: const InputDecoration(
          labelText: 'Rate',
          prefixText: '₹ ',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
          },
          child: const Text(
            'Cancel',
          ),
        ),
        FilledButton(
          onPressed: () {
            final double? value =
                double.tryParse(
              controller.text.trim(),
            );

            Navigator.pop(
              dialogContext,
              value,
            );
          },
          child: const Text(
            'Update',
          ),
        ),
      ],
    );
  },
);

controller.dispose();

if (rate == null) {
  return;
}

if (rate < 0) {
  _showMessage(
    'Selling rate cannot be negative.',
    isError: true,
  );
  return;
}

setState(() {
  item.sellingRate = rate;
});


}

// ===========================================================================
// REMOVE ITEM
// ===========================================================================

void _removeItem(
_SaleDraftItem item,
) {
setState(() {
_items.remove(item);
});
}

// ===========================================================================
// MESSAGE
// ===========================================================================

void _showMessage(
String message, {
bool isError = false,
}) {
if (!mounted) return;


ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          isError ? AppColors.danger : null,
    ),
  );


}

// ===========================================================================
// BUILD
// ===========================================================================

@override
Widget build(
BuildContext context,
) {
if (_loading) {
return Scaffold(
appBar: AppBar(
title: Text(
widget.isEditMode ? 'Edit Sale' : 'Add Sale',
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
        widget.isEditMode ? 'Edit Sale' : 'Add Sale',
      ),
    ),
    body: _buildErrorState(),
  );
}

return Scaffold(
  appBar: AppBar(
    title: Text(
      widget.isEditMode ? 'Edit Sale' : 'Add Sale',
    ),
    actions: [
      if (!_saving)
        TextButton.icon(
          onPressed: _saveSale,
          icon: const Icon(
            Icons.check_rounded,
          ),
          label: const Text(
            'Save',
          ),
        ),
    ],
  ),
  body: SafeArea(
    child: LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        if (constraints.maxWidth >= 1000) {
          return _buildDesktopLayout();
        }

        return _buildMobileLayout();
      },
    ),
  ),
);


}

// ===========================================================================
// MOBILE
// ===========================================================================

Widget _buildMobileLayout() {
return Column(
children: [
Expanded(
child: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(
16,
16,
16,
120,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
_buildCustomerSection(),
const SizedBox(
height: 16,
),
_buildItemsSection(),
const SizedBox(
height: 16,
),
_buildPaymentSection(),
const SizedBox(
height: 16,
),
_buildNotesSection(),
],
),
),
),
_buildBottomTotalBar(),
],
);
}

// ===========================================================================
// DESKTOP
// ===========================================================================

Widget _buildDesktopLayout() {
return Row(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Expanded(
flex: 7,
child: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(
24,
24,
12,
120,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
_buildCustomerSection(),
const SizedBox(
height: 16,
),
_buildItemsSection(),
const SizedBox(
height: 16,
),
_buildNotesSection(),
],
),
),
),
Expanded(
flex: 4,
child: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(
12,
24,
24,
120,
),
child: _buildPaymentSection(),
),
),
],
);
}

// ===========================================================================
// ERROR
// ===========================================================================

Widget _buildErrorState() {
return Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
Icons.error_outline_rounded,
size: 56,
color: Theme.of(context)
.colorScheme
.error,
),
const SizedBox(
height: 16,
),
Text(
_errorMessage ??
'Something went wrong.',
textAlign: TextAlign.center,
style: Theme.of(context)
.textTheme
.titleMedium,
),
const SizedBox(
height: 16,
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

// ===========================================================================
// CUSTOMER SECTION
// ===========================================================================

Widget _buildCustomerSection() {
return _SectionCard(
title: 'Customer',
icon: Icons.person_outline_rounded,
child: _selectedCustomer == null
? InkWell(
onTap: _selectCustomer,
borderRadius: BorderRadius.circular(12),
child: Container(
width: double.infinity,
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
border: Border.all(
color: Theme.of(context)
.colorScheme
.outline,
),
borderRadius:
BorderRadius.circular(12),
),
child: const Row(
children: [
Icon(
Icons.person_add_alt_1_rounded,
),
SizedBox(
width: 12,
),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Select Customer',
style: TextStyle(
fontWeight:
FontWeight.w600,
),
),
SizedBox(
height: 3,
),
Text(
'Optional • Leave empty for walk-in customer',
),
],
),
),
Icon(
Icons.chevron_right_rounded,
),
],
),
),
)
: Container(
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: AppColors.primary.withValues(
alpha: 0.06,
),
borderRadius:
BorderRadius.circular(12),
),
child: Row(
children: [
CircleAvatar(
backgroundColor:
AppColors.primary.withValues(
alpha: 0.12,
),
child: const Icon(
Icons.person_rounded,
color: AppColors.primary,
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
_selectedCustomer!.name,
style: const TextStyle(
fontWeight:
FontWeight.bold,
),
),
if (_selectedCustomer!
.mobile
.isNotEmpty)
Text(
_selectedCustomer!.mobile,
style: Theme.of(context)
.textTheme
.bodySmall,
),
],
),
),
IconButton(
tooltip: 'Remove customer',
onPressed: _removeCustomer,
icon: const Icon(
Icons.close_rounded,
),
),
],
),
),
);
}

// ===========================================================================
// ITEMS SECTION
// ===========================================================================

Widget _buildItemsSection() {
return _SectionCard(
title: 'Products',
icon: Icons.inventory_2_outlined,
trailing: FilledButton.icon(
onPressed: _selectProduct,
icon: const Icon(
Icons.add_rounded,
size: 18,
),
label: const Text(
'Add Product',
),
),
child: _items.isEmpty
? _buildNoItemsState()
: Column(
children: [
..._items.map(
(item) {
return _SaleItemCard(
item: item,
onQuantityTap: () {
_editQuantity(item);
},
onRateTap: () {
_editRate(item);
},
onRemove: () {
_removeItem(item);
},
);
},
),
],
),
);
}

Widget _buildNoItemsState() {
return Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(
vertical: 30,
horizontal: 20,
),
child: Column(
children: [
Icon(
Icons.shopping_cart_outlined,
size: 44,
color: Theme.of(context)
.colorScheme
.onSurfaceVariant,
),
const SizedBox(
height: 10,
),
Text(
'No products added',
style: Theme.of(context)
.textTheme
.titleMedium
?.copyWith(
fontWeight:
FontWeight.w600,
),
),
const SizedBox(
height: 5,
),
Text(
'Add products to create this sale.',
textAlign: TextAlign.center,
style: Theme.of(context)
.textTheme
.bodySmall
?.copyWith(
color: Theme.of(context)
.colorScheme
.onSurfaceVariant,
),
),
const SizedBox(
height: 14,
),
OutlinedButton.icon(
onPressed: _selectProduct,
icon: const Icon(
Icons.add_rounded,
),
label: const Text(
'Add Product',
),
),
],
),
);
}

// ===========================================================================
// PAYMENT SECTION
// ===========================================================================

Widget _buildPaymentSection() {
return _SectionCard(
title: 'Payment & Total',
icon: Icons.payments_outlined,
child: Column(
children: [
_AmountRow(
label: 'Subtotal',
value: _formatCurrency(_subtotal),
),
const SizedBox(
height: 12,
),
TextField(
controller: _discountController,
keyboardType:
const TextInputType.numberWithOptions(
decimal: true,
),
decoration: const InputDecoration(
labelText: 'Discount',
prefixText: '₹ ',
border: OutlineInputBorder(),
isDense: true,
),
),
const SizedBox(
height: 12,
),
TextField(
controller: _taxController,
keyboardType:
const TextInputType.numberWithOptions(
decimal: true,
),
decoration: const InputDecoration(
labelText: 'Tax',
prefixText: '₹ ',
border: OutlineInputBorder(),
isDense: true,
),
),
const SizedBox(
height: 16,
),
Container(
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: AppColors.primary.withValues(
alpha: 0.07,
),
borderRadius:
BorderRadius.circular(12),
),
child: _AmountRow(
label: 'Grand Total',
value: _formatCurrency(_total),
large: true,
),
),
const SizedBox(
height: 16,
),
TextField(
controller: _paidController,
keyboardType:
const TextInputType.numberWithOptions(
decimal: true,
),
decoration: const InputDecoration(
labelText: 'Paid Amount',
prefixText: '₹ ',
border: OutlineInputBorder(),
isDense: true,
),
),
const SizedBox(
height: 12,
),
_AmountRow(
label: 'Outstanding',
value: _formatCurrency(_outstanding),
valueColor: _outstanding > 0
? AppColors.danger
: AppColors.success,
),
const SizedBox(
height: 16,
),
DropdownButtonFormField<String>(
initialValue: _paymentMethod,
decoration: const InputDecoration(
labelText: 'Payment Method',
border: OutlineInputBorder(),
isDense: true,
),
items: const [
DropdownMenuItem(
value: 'Cash',
child: Text('Cash'),
),
DropdownMenuItem(
value: 'UPI',
child: Text('UPI'),
),
DropdownMenuItem(
value: 'Card',
child: Text('Card'),
),
DropdownMenuItem(
value: 'Bank Transfer',
child: Text('Bank Transfer'),
),
DropdownMenuItem(
value: 'Credit',
child: Text('Credit'),
),
],
onChanged: (value) {
if (value == null) return;


          setState(() {
            _paymentMethod = value;
          });
        },
      ),
      const SizedBox(
        height: 16,
      ),
      Row(
        children: [
          const Text('Status'),
          const Spacer(),
          _PaymentStatusChip(
            status: _paymentStatus,
          ),
        ],
      ),
      const SizedBox(
        height: 20,
      ),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          onPressed:
              _saving ? null : _saveSale,
          icon: _saving
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
            _saving
                ? 'Saving...'
                : 'Create Sale',
          ),
        ),
      ),
    ],
  ),
);


}

// ===========================================================================
// NOTES
// ===========================================================================

Widget _buildNotesSection() {
return _SectionCard(
title: 'Notes',
icon: Icons.notes_rounded,
child: TextField(
controller: _notesController,
minLines: 3,
maxLines: 5,
textCapitalization:
TextCapitalization.sentences,
decoration: const InputDecoration(
hintText:
'Add optional notes for this sale...',
border: OutlineInputBorder(),
alignLabelWithHint: true,
),
),
);
}

// ===========================================================================
// MOBILE BOTTOM BAR
// ===========================================================================

Widget _buildBottomTotalBar() {
return Material(
elevation: 8,
color: Theme.of(context)
.colorScheme
.surface,
child: SafeArea(
top: false,
child: Padding(
padding: const EdgeInsets.fromLTRB(
16,
12,
16,
12,
),
child: Row(
children: [
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
mainAxisSize:
MainAxisSize.min,
children: [
Text(
'Grand Total',
style: Theme.of(context)
.textTheme
.bodySmall,
),
Text(
_formatCurrency(_total),
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
FilledButton(
onPressed:
_saving ? null : _saveSale,
child: Text(
_saving
? 'Saving...'
: 'Create Sale',
),
),
],
),
),
),
);
}

// ===========================================================================
// FORMATTERS
// ===========================================================================

String _formatCurrency(double value) {
return '₹${value.toStringAsFixed(2)}';
}

String _formatNumber(double value) {
if (value == value.roundToDouble()) {
return value.toInt().toString();
}


return value.toStringAsFixed(2);


}
}

// =============================================================================
// SALE DRAFT ITEM
// =============================================================================

class _SaleDraftItem {
final ProductModel product;

double quantity;
double sellingRate;

_SaleDraftItem({
required this.product,
required this.quantity,
required this.sellingRate,
});

double get total {
return quantity * sellingRate;
}
}

// =============================================================================
// SECTION CARD
// =============================================================================

class _SectionCard extends StatelessWidget {
final String title;
final IconData icon;
final Widget child;
final Widget? trailing;

const _SectionCard({
required this.title,
required this.icon,
required this.child,
this.trailing,
});

@override
Widget build(BuildContext context) {
final Widget? trailingWidget = trailing;

return Card(
clipBehavior: Clip.antiAlias,
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 36,
height: 36,
decoration: BoxDecoration(
color: AppColors.primary.withValues(
alpha: 0.10,
),
borderRadius:
BorderRadius.circular(10),
),
child: Icon(
icon,
size: 20,
color: AppColors.primary,
),
),
const SizedBox(
width: 10,
),
Expanded(
child: Text(
title,
style: Theme.of(context)
.textTheme
.titleMedium
?.copyWith(
fontWeight:
FontWeight.bold,
),
),
),
if (trailingWidget case final Widget widget) widget,
],
),
const SizedBox(
height: 16,
),
child,
],
),
),
);
}
}

// =============================================================================
// SALE ITEM CARD
// =============================================================================

class _SaleItemCard extends StatelessWidget {
final _SaleDraftItem item;
final VoidCallback onQuantityTap;
final VoidCallback onRateTap;
final VoidCallback onRemove;

const _SaleItemCard({
required this.item,
required this.onQuantityTap,
required this.onRateTap,
required this.onRemove,
});

@override
Widget build(BuildContext context) {
return Container(
margin: const EdgeInsets.only(
bottom: 10,
),
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
border: Border.all(
color: Theme.of(context)
.colorScheme
.outlineVariant,
),
borderRadius:
BorderRadius.circular(12),
),
child: Column(
children: [
Row(
children: [
Container(
width: 42,
height: 42,
decoration: BoxDecoration(
color: AppColors.primary.withValues(
alpha: 0.08,
),
borderRadius:
BorderRadius.circular(10),
),
child: const Icon(
Icons.inventory_2_outlined,
color: AppColors.primary,
),
),
const SizedBox(
width: 10,
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
FontWeight.w600,
),
),
const SizedBox(
height: 3,
),
Text(
'Stock: ${_formatNumber(item.product.currentStock)} '
'${item.product.unit}',
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
),
),
IconButton(
tooltip: 'Remove product',
onPressed: onRemove,
icon: const Icon(
Icons.delete_outline_rounded,
color: AppColors.danger,
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
child: InkWell(
onTap: onQuantityTap,
borderRadius:
BorderRadius.circular(10),
child: _EditableValue(
label: 'Quantity',
value:
'${_formatNumber(item.quantity)} '
'${item.product.unit}',
),
),
),
const SizedBox(
width: 10,
),
Expanded(
child: InkWell(
onTap: onRateTap,
borderRadius:
BorderRadius.circular(10),
child: _EditableValue(
label: 'Selling Rate',
value: _formatCurrency(
item.sellingRate,
),
),
),
),
const SizedBox(
width: 10,
),
Expanded(
child: _EditableValue(
label: 'Amount',
value: _formatCurrency(
item.total,
),
highlight: true,
),
),
],
),
],
),
);
}

static String _formatCurrency(double value) {
return '₹${value.toStringAsFixed(2)}';
}

static String _formatNumber(double value) {
if (value == value.roundToDouble()) {
return value.toInt().toString();
}


return value.toStringAsFixed(2);


}
}

// =============================================================================
// EDITABLE VALUE
// =============================================================================

class _EditableValue extends StatelessWidget {
final String label;
final String value;
final bool highlight;

const _EditableValue({
required this.label,
required this.value,
this.highlight = false,
});

@override
Widget build(BuildContext context) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 9,
),
decoration: BoxDecoration(
color: highlight
? AppColors.primary.withValues(
alpha: 0.07,
)
: Theme.of(context)
.colorScheme
.surfaceContainerHighest
.withValues(
alpha: 0.45,
),
borderRadius:
BorderRadius.circular(10),
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
label,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: Theme.of(context)
.textTheme
.bodySmall
?.copyWith(
color: Theme.of(context)
.colorScheme
.onSurfaceVariant,
),
),
const SizedBox(
height: 3,
),
Text(
value,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
fontWeight: FontWeight.w700,
color: highlight
? AppColors.primary
: null,
),
),
],
),
);
}
}

// =============================================================================
// AMOUNT ROW
// =============================================================================

class _AmountRow extends StatelessWidget {
final String label;
final String value;
final bool large;
final Color? valueColor;

const _AmountRow({
required this.label,
required this.value,
this.large = false,
this.valueColor,
});

@override
Widget build(BuildContext context) {
return Row(
children: [
Expanded(
child: Text(
label,
style: TextStyle(
fontSize: large ? 15 : 14,
fontWeight: large
? FontWeight.w600
: FontWeight.normal,
),
),
),
Text(
value,
style: TextStyle(
fontSize: large ? 20 : 14,
fontWeight: FontWeight.bold,
color: valueColor,
),
),
],
);
}
}

// =============================================================================
// PAYMENT STATUS
// =============================================================================

class _PaymentStatusChip extends StatelessWidget {
final String status;

const _PaymentStatusChip({
required this.status,
});

@override
Widget build(BuildContext context) {
late final Color color;
late final String label;
late final IconData icon;


switch (status) {
  case 'paid':
    color = AppColors.success;
    label = 'Paid';
    icon = Icons.check_circle_outline_rounded;
    break;

  case 'partial':
    color = AppColors.warning;
    label = 'Partial';
    icon = Icons.timelapse_rounded;
    break;

  default:
    color = AppColors.danger;
    label = 'Unpaid';
    icon = Icons.pending_outlined;
}

return Container(
  padding: const EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 6,
  ),
  decoration: BoxDecoration(
    color: color.withValues(
      alpha: 0.10,
    ),
    borderRadius:
        BorderRadius.circular(20),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 16,
        color: color,
      ),
      const SizedBox(
        width: 5,
      ),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    ],
  ),
);


}
}

// =============================================================================
// PRODUCT PICKER
// =============================================================================

class _ProductPicker extends StatefulWidget {
final List<ProductModel> products;
final Set<String> existingProductIds;

const _ProductPicker({
required this.products,
required this.existingProductIds,
});

@override
State<_ProductPicker> createState() =>
_ProductPickerState();
}

class _ProductPickerState
extends State<_ProductPicker> {
final TextEditingController _searchController =
TextEditingController();

String _query = '';

@override
void initState() {
super.initState();

_searchController.addListener(
  () {
    if (!mounted) return;

    setState(() {
      _query = _searchController.text
          .trim()
          .toLowerCase();
    });
  },
);

}

@override
void dispose() {
_searchController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
final List<ProductModel> products =
widget.products.where(
(product) {
if (product.currentStock <= 0) {
return false;
}

    if (widget.existingProductIds
        .contains(product.id)) {
      return false;
    }

    if (_query.isEmpty) {
      return true;
    }

    return product.name
            .toLowerCase()
            .contains(_query) ||
        product.category
            .toLowerCase()
            .contains(_query) ||
        product.unit
            .toLowerCase()
            .contains(_query);
  },
).toList();

return SafeArea(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(
      16,
      4,
      16,
      16,
    ),
    child: Column(
      children: [
        Text(
          'Select Product',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
        ),
        const SizedBox(
          height: 14,
        ),
        TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search product...',
            prefixIcon: const Icon(
              Icons.search_rounded,
            ),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                    },
                    icon: const Icon(
                      Icons.clear_rounded,
                    ),
                  ),
            border:
                const OutlineInputBorder(),
          ),
        ),
        const SizedBox(
          height: 12,
        ),
        Expanded(
          child: products.isEmpty
              ? const Center(
                  child: Text(
                    'No products available.',
                  ),
                )
              : ListView.separated(
                  itemCount:
                      products.length,
                  separatorBuilder:
                      (context, index) =>
                          const Divider(
                    height: 1,
                  ),
                  itemBuilder:
                      (context, index) {
                    final ProductModel product =
                        products[index];

                    return ListTile(
                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 5,
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary
                                .withValues(
                          alpha: 0.10,
                        ),
                        child: const Icon(
                          Icons
                              .inventory_2_outlined,
                          color:
                              AppColors.primary,
                        ),
                      ),
                      title: Text(
                        product.name,
                      ),
                      subtitle: Text(
                        '₹${product.sellingPrice.toStringAsFixed(2)} • '
                        'Stock ${_formatNumber(product.currentStock)} '
                        '${product.unit}',
                      ),
                      trailing: const Icon(
                        Icons
                            .add_circle_outline_rounded,
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
);

}

String _formatNumber(double value) {
if (value == value.roundToDouble()) {
return value.toInt().toString();
}


return value.toStringAsFixed(2);


}
}

// =============================================================================
// CUSTOMER PICKER
// =============================================================================

class _CustomerPicker extends StatefulWidget {
final List<CustomerModel> customers;

const _CustomerPicker({
required this.customers,
});

@override
State<_CustomerPicker> createState() =>
_CustomerPickerState();
}

class _CustomerPickerState
extends State<_CustomerPicker> {
final TextEditingController _searchController =
TextEditingController();

String _query = '';

@override
void initState() {
super.initState();

_searchController.addListener(
  () {
    if (!mounted) return;

    setState(() {
      _query = _searchController.text
          .trim()
          .toLowerCase();
    });
  },
);


}

@override
void dispose() {
_searchController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
final List<CustomerModel> customers =
widget.customers.where(
(customer) {
if (_query.isEmpty) {
return true;
}


    return customer.name
            .toLowerCase()
            .contains(_query) ||
        customer.mobile
            .toLowerCase()
            .contains(_query) ||
        customer.email
            .toLowerCase()
            .contains(_query);
  },
).toList();

return SafeArea(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(
      16,
      4,
      16,
      16,
    ),
    child: Column(
      children: [
        Text(
          'Select Customer',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
        ),
        const SizedBox(
          height: 14,
        ),
        TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search customer...',
            prefixIcon: const Icon(
              Icons.search_rounded,
            ),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                    },
                    icon: const Icon(
                      Icons.clear_rounded,
                    ),
                  ),
            border:
                const OutlineInputBorder(),
          ),
        ),
        const SizedBox(
          height: 12,
        ),
        Expanded(
          child: customers.isEmpty
              ? const Center(
                  child: Text(
                    'No customers found.',
                  ),
                )
              : ListView.separated(
                  itemCount:
                      customers.length,
                  separatorBuilder:
                      (context, index) =>
                          const Divider(
                    height: 1,
                  ),
                  itemBuilder:
                      (context, index) {
                    final CustomerModel customer =
                        customers[index];

                    return ListTile(
                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 5,
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.secondary
                                .withValues(
                          alpha: 0.10,
                        ),
                        child: const Icon(
                          Icons
                              .person_outline_rounded,
                          color:
                              AppColors.secondary,
                        ),
                      ),
                      title: Text(
                        customer.name,
                      ),
                      subtitle: Text(
                        customer.mobile.isEmpty
                            ? 'No mobile number'
                            : customer.mobile,
                      ),
                      trailing: const Icon(
                        Icons
                            .chevron_right_rounded,
                      ),
                      onTap: () {
                        Navigator.pop(
                          context,
                          customer,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    ),
  ),
);

}
}
