import 'package:flutter/material.dart';

import '../../core/navigation/app_navigation_controller.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/app_date_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_number_format.dart';
import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../models/ledger_transaction_model.dart';
import '../../models/payment_model.dart';
import '../../models/purchase_model.dart';
import '../../models/sale_model.dart';
import '../../models/supplier_model.dart';
import '../../models/supplier_payment_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/purchase_repository.dart';
import '../../repositories/sale_repository.dart';
import '../../repositories/supplier_payment_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../services/ledger/ledger_service.dart';
import '../../services/ledger/supplier_ledger_service.dart';
import '../../services/payment/payment_ledger_service.dart';
import '../../core/widgets/app_responsive_page.dart';

class AddPaymentScreen extends StatefulWidget {
  final PaymentModel? payment;
  final bool isEditMode;

  const AddPaymentScreen({super.key, this.payment, this.isEditMode = false});

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final BusinessRepository _businessRepository = BusinessRepository();
  final CustomerRepository _customerRepository = CustomerRepository();
  final SupplierRepository _supplierRepository = SupplierRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();
  final SupplierPaymentRepository _supplierPaymentRepository =
      SupplierPaymentRepository();
  final SaleRepository _saleRepository = SaleRepository();
  final PurchaseRepository _purchaseRepository = PurchaseRepository();

  final LedgerService _ledgerService = LedgerService();
  final SupplierLedgerService _supplierLedgerService = SupplierLedgerService();
  final PaymentLedgerService _paymentLedgerService = PaymentLedgerService();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _formatAmount(double value) => AppNumberFormat.amount(value);

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  static const List<String> _paymentMethods = <String>[
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
    'Other',
  ];

  BusinessModel? _business;

  List<CustomerModel> _customers = <CustomerModel>[];
  List<SupplierModel> _suppliers = <SupplierModel>[];

  CustomerModel? _selectedCustomer;
  SupplierModel? _selectedSupplier;

  DateTime _paymentDate = DateTime.now();
  String _paymentMethod = 'Cash';

  bool _isSupplierPayment = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingBalance = false;

  double? _selectedPartyBalance;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _cleanError(Object error) {
    final String message = error.toString().trim();
    if (message.startsWith('Exception:')) {
      return message.substring('Exception:'.length).trim();
    }
    return message.isEmpty ? 'Something went wrong.' : message;
  }

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final BusinessModel? business = await _businessRepository
          .getBusinessForCurrentUser();

      if (business == null || business.id.trim().isEmpty) {
        throw StateError('Business profile is not available.');
      }

      final String businessId = business.id.trim();

      final List<dynamic> results = await Future.wait<dynamic>([
        _customerRepository.getCustomers(businessId: businessId),
        _supplierRepository.getSuppliers(businessId),
      ]);

      final List<CustomerModel> customers = results[0] as List<CustomerModel>;
      final List<SupplierModel> suppliers = results[1] as List<SupplierModel>;

      CustomerModel? existingCustomer;
      if (widget.isEditMode && widget.payment != null) {
        for (final CustomerModel customer in customers) {
          if (customer.id.trim() == widget.payment!.customerId.trim()) {
            existingCustomer = customer;
            break;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _business = business;
        _customers = customers;
        _suppliers = suppliers;
        _isLoading = false;

        // Existing PaymentModel records are customer payments.
        _isSupplierPayment = false;
        _selectedCustomer = existingCustomer;

        if (widget.isEditMode && widget.payment != null) {
          _amountController.text = widget.payment!.amount.toStringAsFixed(2);
          _referenceController.text = widget.payment!.transactionReference;
          _notesController.text = widget.payment!.notes;
          _paymentDate = widget.payment!.date;

          final String existingMethod = widget.payment!.paymentMethod.trim();
          if (_paymentMethods.contains(existingMethod)) {
            _paymentMethod = existingMethod;
          }
        }
      });

      if (_selectedCustomer != null) {
        await _loadCustomerBalance(_selectedCustomer!);
      }
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

  Future<void> _loadCustomerBalance(CustomerModel customer) async {
    final BusinessModel? business = _business;
    final String businessId = business?.id.trim() ?? '';
    final String customerId = customer.id.trim();

    if (businessId.isEmpty || customerId.isEmpty) {
      if (mounted) {
        setState(() {
          _selectedPartyBalance = null;
          _isLoadingBalance = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingBalance = true;
      _selectedPartyBalance = null;
    });

    try {
      /*
       * Calculate the customer receivable from the source documents instead
       * of relying only on the ledger's latest balanceAfter value.
       *
       * Customer pending =
       *   outstanding from customer sales
       *   - separate customer payments.
       *
       * SaleModel.paidAmount is the amount already paid on the sale itself.
       * PaymentModel represents payments recorded later from the customer.
       */
      final List<SaleModel> sales = await _saleRepository.getSales(
        businessId: businessId,
      );

      final List<PaymentModel> payments = await _paymentRepository.getPayments(
        businessId: businessId,
      );

      double totalSalesOutstanding = 0;
      for (final SaleModel sale in sales) {
        if (sale.customerId.trim() != customerId) {
          continue;
        }

        final double saleOutstanding = sale.total - sale.paidAmount;

        if (saleOutstanding > 0 && saleOutstanding.isFinite) {
          totalSalesOutstanding += saleOutstanding;
        }
      }

      double totalCustomerPayments = 0;
      for (final PaymentModel payment in payments) {
        if (payment.customerId.trim() != customerId) {
          continue;
        }

        if (payment.amount.isFinite && payment.amount > 0) {
          totalCustomerPayments += payment.amount;
        }
      }

      final double pending = totalSalesOutstanding - totalCustomerPayments;

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedPartyBalance = pending.isFinite && pending > 0 ? pending : 0;
        _isLoadingBalance = false;
      });
    } catch (e) {
      /*
       * Ledger remains a fallback only when source-document calculation
       * cannot be completed. This keeps the screen usable for existing data.
       */
      try {
        final double balance = await _ledgerService.getCustomerBalance(
          businessId: businessId,
          customerId: customerId,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _selectedPartyBalance = balance.isFinite && balance > 0 ? balance : 0;
          _isLoadingBalance = false;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _selectedPartyBalance = null;
          _isLoadingBalance = false;
        });

        _showMessage(
          'Unable to load customer pending amount: ${_cleanError(e)}',
          isError: true,
        );
      }
    }
  }

  Future<void> _loadSupplierBalance(SupplierModel supplier) async {
    final BusinessModel? business = _business;
    final String businessId = business?.id.trim() ?? '';
    final String supplierId = supplier.id.trim();

    if (businessId.isEmpty || supplierId.isEmpty) {
      if (mounted) {
        setState(() {
          _selectedPartyBalance = null;
          _isLoadingBalance = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingBalance = true;
      _selectedPartyBalance = null;
    });

    try {
      /*
       * Calculate supplier payable from purchases plus separately recorded
       * supplier payments. This is independent of whether an old ledger
       * transaction exists.
       *
       * Supplier pending =
       *   purchase total
       *   - purchase-level paidAmount
       *   - separate supplier payments.
       */
      final List<PurchaseModel> purchases = await _purchaseRepository
          .getPurchases(businessId: businessId);

      final List<SupplierPaymentModel> payments =
          await _supplierPaymentRepository.getPayments(businessId: businessId);

      double totalPurchaseOutstanding = 0;
      for (final PurchaseModel purchase in purchases) {
        if (purchase.supplierId.trim() != supplierId) {
          continue;
        }

        final double purchaseOutstanding = purchase.total - purchase.paidAmount;

        if (purchaseOutstanding > 0 && purchaseOutstanding.isFinite) {
          totalPurchaseOutstanding += purchaseOutstanding;
        }
      }

      double totalSupplierPayments = 0;
      for (final SupplierPaymentModel payment in payments) {
        if (payment.supplierId.trim() != supplierId) {
          continue;
        }

        if (payment.amount.isFinite && payment.amount > 0) {
          totalSupplierPayments += payment.amount;
        }
      }

      final double pending = totalPurchaseOutstanding - totalSupplierPayments;

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedPartyBalance = pending.isFinite && pending > 0 ? pending : 0;
        _isLoadingBalance = false;
      });
    } catch (e) {
      /*
       * Ledger fallback keeps older data usable if a source collection
       * temporarily cannot be read.
       */
      try {
        final double balance = await _supplierLedgerService.getSupplierBalance(
          businessId: businessId,
          supplierId: supplierId,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _selectedPartyBalance = balance.isFinite && balance > 0 ? balance : 0;
          _isLoadingBalance = false;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _selectedPartyBalance = null;
          _isLoadingBalance = false;
        });

        _showMessage(
          'Unable to load supplier pending amount: ${_cleanError(e)}',
          isError: true,
        );
      }
    }
  }

  void _selectCustomer(CustomerModel? customer) {
    if (_isSaving || customer == null) {
      return;
    }

    setState(() {
      _selectedCustomer = customer;
      _selectedSupplier = null;
    });

    _loadCustomerBalance(customer);
  }

  void _selectSupplier(SupplierModel? supplier) {
    if (_isSaving || supplier == null) {
      return;
    }

    setState(() {
      _selectedSupplier = supplier;
      _selectedCustomer = null;
    });

    _loadSupplierBalance(supplier);
  }

  Future<void> _changePaymentType(bool supplierPayment) async {
    if (_isSaving || widget.isEditMode) {
      return;
    }

    setState(() {
      _isSupplierPayment = supplierPayment;
      _selectedCustomer = null;
      _selectedSupplier = null;
      _selectedPartyBalance = null;
      _isLoadingBalance = false;
      _amountController.clear();
    });
  }

  Future<void> _selectPaymentDate() async {
    final DateTime now = DateTime.now();

    final DateTime? selected = await AppDatePicker.showDatePicker(
      context: context,

      initialEntryMode: DatePickerEntryMode.calendar,
      initialDate: _paymentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2, 12, 31),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _paymentDate = selected;
    });
  }

  Future<void> _savePayment() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final BusinessModel? business = _business;
    if (business == null || business.id.trim().isEmpty) {
      _showMessage('Business profile is not available.', isError: true);
      return;
    }

    double? amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );

    if (amount == null || !amount.isFinite || amount <= 0) {
      _showMessage('Enter a valid payment amount.', isError: true);
      return;
    }

    if (_isLoadingBalance) {
      _showMessage(
        'Please wait while the pending amount is loading.',
        isError: true,
      );
      return;
    }

    final double? pending = _selectedPartyBalance;
    if (pending != null && amount > pending + 0.000001) {
      final String partyLabel = _isSupplierPayment
          ? 'supplier pending payable'
          : 'customer pending amount';

      _showMessage(
        'Payment amount cannot be greater than the $partyLabel of '
        '${_formatAmount(pending)}.',
        isError: true,
      );
      return;
    }

    // If the user entered the complete displayed pending amount, normalize
    // the value to the exact calculated balance. This prevents a tiny floating
    // point difference from turning a full-settlement payment into an
    // over-payment during ledger validation.
    if (pending != null && (amount - pending).abs() <= 0.01) {
      amount = pending;
    }

    if (_isSupplierPayment) {
      await _saveSupplierPayment(
        businessId: business.id.trim(),
        amount: amount,
      );
    } else {
      await _saveCustomerPayment(
        businessId: business.id.trim(),
        amount: amount,
      );
    }
  }

  Future<void> _saveCustomerPayment({
    required String businessId,
    required double amount,
  }) async {
    final CustomerModel? customer = _selectedCustomer;

    if (customer == null || customer.id.trim().isEmpty) {
      _showMessage('Please select a customer or hotel.', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    PaymentModel? oldPayment = widget.payment;
    PaymentModel? updatedPayment;
    LedgerTransactionModel? createdReversal;
    LedgerTransactionModel? createdNewLedger;

    try {
      final String paymentMethod = _paymentMethod.trim();

      if (!widget.isEditMode) {
        final String paymentId =
            'payment_${DateTime.now().microsecondsSinceEpoch}';

        final PaymentModel payment = PaymentModel(
          id: paymentId,
          businessId: businessId,
          customerId: customer.id.trim(),
          customerName: customer.name.trim(),
          amount: amount,
          date: _paymentDate,
          paymentMethod: paymentMethod,
          transactionReference: _referenceController.text.trim(),
          notes: _notesController.text.trim(),
          createdAt: DateTime.now(),
        );

        // Post the ledger entry before creating the payment document. This is
        // important because the pending-balance calculation must not already
        // include the payment that is currently being saved.
        try {
          // The pending amount displayed above is calculated from the
          // authoritative sale/payment source documents. Older businesses can
          // have incomplete or stale ledger rows, so using the ledger's
          // balanceBefore here can incorrectly reject an otherwise valid
          // full settlement. Prefer the displayed source balance and fall
          // back to the ledger only when the screen could not calculate it.
          final double balanceBefore =
              _selectedPartyBalance ??
              await _ledgerService.getCustomerBalance(
                businessId: businessId,
                customerId: customer.id.trim(),
              );

          if (amount > balanceBefore + 0.000001) {
            throw StateError(
              'Payment amount cannot be greater than the customer outstanding amount.',
            );
          }

          final double balanceAfter = (balanceBefore - amount).abs() <= 0.01
              ? 0
              : balanceBefore - amount;

          createdNewLedger = await _ledgerService.createTransaction(
            businessId: businessId,
            customerId: customer.id.trim(),
            customerName: customer.name.trim(),
            transactionType: 'PAYMENT',
            amount: amount,
            balanceBefore: balanceBefore,
            balanceAfter: balanceAfter,
            referenceId: payment.id,
            date: _paymentDate,
            notes:
                _referenceController.text.trim().isEmpty &&
                    _notesController.text.trim().isEmpty
                ? 'Customer payment received.'
                : _buildLedgerNotes(
                    paymentMethod: paymentMethod,
                    reference: _referenceController.text.trim(),
                    notes: _notesController.text.trim(),
                  ),
          );

          try {
            await _paymentRepository.createPayment(payment);
          } catch (paymentError) {
            try {
              await _ledgerService.deleteTransaction(
                businessId: businessId,
                transactionId: createdNewLedger.id,
              );
            } catch (_) {
              // Preserve the original payment creation error.
            }
            rethrow;
          }
        } catch (ledgerError) {
          rethrow;
        }
      } else {
        final PaymentModel old = oldPayment!;

        final List<LedgerTransactionModel> transactions = await _ledgerService
            .getCustomerTransactions(
              businessId: businessId,
              customerId: old.customerId.trim(),
            );

        final List<LedgerTransactionModel> oldEntries = transactions
            .where(
              (LedgerTransactionModel transaction) =>
                  transaction.referenceId.trim() == old.id.trim() &&
                  transaction.transactionType.trim().toUpperCase() == 'PAYMENT',
            )
            .toList();

        if (oldEntries.isNotEmpty) {
          final double balanceBeforeReversal = await _ledgerService
              .getCustomerBalance(
                businessId: businessId,
                customerId: old.customerId.trim(),
              );

          createdReversal = await _paymentLedgerService.createPaymentReversal(
            payment: old,
            balanceBefore: balanceBeforeReversal,
          );
        }

        updatedPayment = PaymentModel(
          id: old.id,
          businessId: businessId,
          customerId: customer.id.trim(),
          customerName: customer.name.trim(),
          amount: amount,
          date: _paymentDate,
          paymentMethod: paymentMethod,
          transactionReference: _referenceController.text.trim(),
          notes: _notesController.text.trim(),
          createdAt: old.createdAt,
        );

        await _paymentRepository.updatePayment(updatedPayment);

        final double newBalanceBefore = await _ledgerService.getCustomerBalance(
          businessId: businessId,
          customerId: customer.id.trim(),
        );

        createdNewLedger = await _paymentLedgerService.createPaymentLedgerEntry(
          payment: updatedPayment,
          balanceBefore: newBalanceBefore,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        widget.isEditMode
            ? 'Customer payment updated and ledger corrected successfully.'
            : 'Customer payment recorded and ledger updated successfully.',
      );

      if (!widget.isEditMode) {
        AppNavigationController.requestHome();
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (widget.isEditMode && oldPayment != null) {
        try {
          if (createdNewLedger != null && updatedPayment != null) {
            final double balance = await _ledgerService.getCustomerBalance(
              businessId: businessId,
              customerId: updatedPayment.customerId.trim(),
            );

            await _paymentLedgerService.createPaymentReversal(
              payment: updatedPayment,
              balanceBefore: balance,
            );
          }

          if (createdReversal != null) {
            final double balance = await _ledgerService.getCustomerBalance(
              businessId: businessId,
              customerId: oldPayment.customerId.trim(),
            );

            await _paymentLedgerService.createPaymentLedgerEntry(
              payment: oldPayment,
              balanceBefore: balance,
            );
          }

          if (updatedPayment != null) {
            await _paymentRepository.updatePayment(oldPayment);
          }
        } catch (_) {
          // Preserve the original error.
        }
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        'Failed to ${widget.isEditMode ? 'update' : 'save'} customer payment: '
        '${_cleanError(e)}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveSupplierPayment({
    required String businessId,
    required double amount,
  }) async {
    final SupplierModel? supplier = _selectedSupplier;

    if (supplier == null || supplier.id.trim().isEmpty) {
      _showMessage('Please select a supplier.', isError: true);
      return;
    }

    if (widget.isEditMode) {
      _showMessage(
        'Supplier payment editing is handled from Supplier Payments.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final String paymentId =
          'supplier_payment_${DateTime.now().microsecondsSinceEpoch}';

      final SupplierPaymentModel payment = SupplierPaymentModel(
        id: paymentId,
        businessId: businessId,
        supplierId: supplier.id.trim(),
        supplierName: supplier.name.trim(),
        amount: amount,
        date: _paymentDate,
        paymentMethod: _paymentMethod.trim(),
        transactionReference: _referenceController.text.trim(),
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      LedgerTransactionModel? createdSupplierLedger;

      // Post the supplier ledger entry before creating the payment document.
      // Otherwise the newly-created payment can reduce the outstanding
      // payable before the ledger service validates the payment.
      try {
        createdSupplierLedger = await _supplierLedgerService
            .createSupplierPaymentLedgerEntry(
              businessId: businessId,
              paymentAmount: amount,
              balanceBefore: _selectedPartyBalance,
              supplierId: supplier.id.trim(),
              supplierName: supplier.name.trim(),
              referenceId: payment.id,
            );

        try {
          await _supplierPaymentRepository.createPayment(payment);
        } catch (paymentError) {
          try {
            await _supplierLedgerService.deleteTransaction(
              businessId: businessId,
              transactionId: createdSupplierLedger.id,
            );
          } catch (_) {
            // Preserve the original payment creation error.
          }
          rethrow;
        }
      } catch (ledgerError) {
        rethrow;
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        'Supplier payment recorded and supplier ledger updated successfully.',
      );

      if (!widget.isEditMode) {
        AppNavigationController.requestHome();
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Failed to save supplier payment: ${_cleanError(e)}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _buildLedgerNotes({
    required String paymentMethod,
    required String reference,
    required String notes,
  }) {
    final List<String> parts = <String>[];
    if (paymentMethod.trim().isNotEmpty) {
      parts.add('Method: ${paymentMethod.trim()}');
    }
    if (reference.trim().isNotEmpty) {
      parts.add('Reference: ${reference.trim()}');
    }
    if (notes.trim().isNotEmpty) {
      parts.add(notes.trim());
    }
    return parts.isEmpty ? 'Customer payment received.' : parts.join(' | ');
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.danger : AppColors.success,
        ),
      );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    final ThemeData theme = Theme.of(context);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: theme.colorScheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.20),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    );
  }

  Widget _buildPartyTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Payment For',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose whether this payment is received from a customer '
              'or paid to a supplier.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.person_rounded),
                  label: Text('Customer'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.local_shipping_rounded),
                  label: Text('Supplier'),
                ),
              ],
              selected: <bool>{_isSupplierPayment},
              onSelectionChanged: (Set<bool> selection) {
                if (selection.isEmpty) {
                  return;
                }
                _changePaymentType(selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSelector() {
    return DropdownButtonFormField<CustomerModel>(
      initialValue: _selectedCustomer,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Customer / Hotel',
        icon: Icons.person_rounded,
        hint: 'Select customer',
      ),
      items: _customers.map((CustomerModel customer) {
        return DropdownMenuItem<CustomerModel>(
          value: customer,
          child: Text(
            customer.name.trim().isEmpty
                ? 'Unnamed Customer'
                : customer.name.trim(),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _isSaving ? null : _selectCustomer,
      validator: (CustomerModel? value) {
        if (value == null) {
          return 'Please select a customer';
        }
        if (value.id.trim().isEmpty) {
          return 'Invalid customer selected';
        }
        return null;
      },
    );
  }

  Widget _buildSupplierSelector() {
    return DropdownButtonFormField<SupplierModel>(
      initialValue: _selectedSupplier,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Supplier',
        icon: Icons.local_shipping_rounded,
        hint: 'Select supplier',
      ),
      items: _suppliers.map((SupplierModel supplier) {
        return DropdownMenuItem<SupplierModel>(
          value: supplier,
          child: Text(
            supplier.name.trim().isEmpty
                ? 'Unnamed Supplier'
                : supplier.name.trim(),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _isSaving ? null : _selectSupplier,
      validator: (SupplierModel? value) {
        if (value == null) {
          return 'Please select a supplier';
        }
        if (value.id.trim().isEmpty) {
          return 'Invalid supplier selected';
        }
        return null;
      },
    );
  }

  Widget _buildPendingAmountCard() {
    final ThemeData theme = Theme.of(context);
    final bool hasParty = _isSupplierPayment
        ? _selectedSupplier != null
        : _selectedCustomer != null;

    if (!hasParty) {
      return const SizedBox.shrink();
    }

    final Color accent = _isSupplierPayment
        ? AppColors.warning
        : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isSupplierPayment
                  ? Icons.account_balance_wallet_rounded
                  : Icons.pending_actions_rounded,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _isSupplierPayment
                      ? 'Supplier Pending Payable'
                      : 'Customer Pending Amount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (_isLoadingBalance)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    _selectedPartyBalance == null
                        ? 'Unable to calculate'
                        : _formatAmount(_selectedPartyBalance!),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _paymentMethod,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Payment Method',
        icon: Icons.account_balance_wallet_rounded,
      ),
      items: _paymentMethods.map((String method) {
        return DropdownMenuItem<String>(value: method, child: Text(method));
      }).toList(),
      onChanged: _isSaving
          ? null
          : (String? value) {
              if (value == null) {
                return;
              }
              setState(() {
                _paymentMethod = value;
              });
            },
      validator: (String? value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please select payment method';
        }
        return null;
      },
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: _isSaving ? null : _selectPaymentDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration(
          label: 'Payment Date',
          icon: Icons.calendar_today_rounded,
        ),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(_dateFormat.format(_paymentDate))),
            Icon(
              Icons.calendar_month_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      enabled: !_isSaving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(
        label: 'Payment Amount',
        icon: Icons.currency_rupee_rounded,
        hint: 'Enter amount',
      ),
      validator: (String? value) {
        final double? amount = double.tryParse(
          (value ?? '').trim().replaceAll(',', ''),
        );

        if (amount == null || !amount.isFinite || amount <= 0) {
          return 'Enter a valid amount';
        }

        if (_selectedPartyBalance != null &&
            amount > _selectedPartyBalance! + 0.000001) {
          return 'Amount exceeds pending balance';
        }

        return null;
      },
      onChanged: (_) {
        setState(() {});
      },
    );
  }

  Widget _buildReferenceField() {
    return TextFormField(
      controller: _referenceController,
      enabled: !_isSaving,
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(
        label: 'Transaction Reference',
        icon: Icons.receipt_long_rounded,
        hint: 'Optional reference / transaction ID',
      ),
      maxLength: 100,
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      enabled: !_isSaving,
      maxLines: 4,
      maxLength: 500,
      textCapitalization: TextCapitalization.sentences,
      decoration: _inputDecoration(
        label: 'Notes',
        icon: Icons.notes_rounded,
        hint: 'Add optional payment notes',
      ),
    );
  }

  Widget _buildSummaryCard() {
    final double amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '')) ?? 0;

    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Payment Summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isSupplierPayment
                            ? 'Review supplier payment before saving'
                            : 'Review customer payment before saving',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 520;
                final Widget amountItem = _summaryItem(
                  label: 'Amount',
                  value: _formatAmount(amount),
                );
                final Widget methodItem = _summaryItem(
                  label: 'Method',
                  value: _paymentMethod,
                );
                final Widget partyItem = _summaryItem(
                  label: _isSupplierPayment ? 'Supplier' : 'Customer',
                  value: _isSupplierPayment
                      ? (_selectedSupplier?.name.trim() ?? '')
                      : (_selectedCustomer?.name.trim() ?? ''),
                );
                final Widget dateItem = _summaryItem(
                  label: 'Date',
                  value: _dateFormat.format(_paymentDate),
                );

                if (compact) {
                  return Column(
                    children: <Widget>[
                      amountItem,
                      const SizedBox(height: 10),
                      methodItem,
                      const SizedBox(height: 10),
                      partyItem,
                      const SizedBox(height: 10),
                      dateItem,
                    ],
                  );
                }

                return Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: amountItem),
                        const SizedBox(width: 12),
                        Expanded(child: methodItem),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(child: partyItem),
                        const SizedBox(width: 12),
                        Expanded(child: dateItem),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem({required String label, required String value}) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.payments_rounded, color: AppColors.success),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.isEditMode ? 'Edit Payment' : 'Add Payment',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                widget.isEditMode
                    ? 'Edit customer payment'
                    : 'Record customer or supplier payment',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _savePayment,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_rounded),
        label: Text(
          _isSaving
              ? 'Saving Payment...'
              : widget.isEditMode
              ? 'Update Payment'
              : 'Save Payment',
        ),
      ),
    );
  }

  Widget _buildEmptyPartyState() {
    final ThemeData theme = Theme.of(context);
    final bool supplier = _isSupplierPayment;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              supplier
                  ? 'No suppliers are available. Add a supplier first, '
                        'then record the payment.'
                  : 'No customers or hotels are available. Add a customer '
                        'first, then record the payment.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!widget.isEditMode) _buildPartyTypeSelector(),
          if (!widget.isEditMode) const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    _isSupplierPayment
                        ? 'Supplier Payment'
                        : 'Customer Payment',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSupplierPayment
                        ? 'Select the supplier and enter the amount paid.'
                        : 'Select the customer and enter the amount received.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_isSupplierPayment)
                    _suppliers.isEmpty
                        ? _buildEmptyPartyState()
                        : _buildSupplierSelector()
                  else
                    _customers.isEmpty
                        ? _buildEmptyPartyState()
                        : _buildCustomerSelector(),
                  const SizedBox(height: 14),
                  _buildPendingAmountCard(),
                  if ((_isSupplierPayment
                          ? _selectedSupplier != null
                          : _selectedCustomer != null) &&
                      _selectedPartyBalance != null)
                    const SizedBox(height: 16),
                  _buildAmountField(),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          if (constraints.maxWidth < 650) {
                            return Column(
                              children: <Widget>[
                                _buildPaymentMethodSelector(),
                                const SizedBox(height: 16),
                                _buildDateSelector(),
                              ],
                            );
                          }

                          return Row(
                            children: <Widget>[
                              Expanded(child: _buildPaymentMethodSelector()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildDateSelector()),
                            ],
                          );
                        },
                  ),
                  const SizedBox(height: 16),
                  _buildReferenceField(),
                  const SizedBox(height: 8),
                  _buildNotesField(),
                  const SizedBox(height: 8),
                  _buildSummaryCard(),
                  const SizedBox(height: 20),
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 38,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Unable to load payment form',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Payment' : 'Add Payment'),
      ),
      body: AppResponsivePage(child: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && _business == null
            ? _buildErrorState()
            : RefreshIndicator(
                onRefresh: _loadData,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: <Widget>[
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1250),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _buildHeader(),
                                const SizedBox(height: 20),
                                _buildForm(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      )),
    );
  }
}
