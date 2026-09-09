    dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../models/payment_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../services/ledger/ledger_service.dart';

class AddPaymentScreen extends StatefulWidget {
  const AddPaymentScreen({
    super.key,
  });

  @override
  State<AddPaymentScreen> createState() =>
      _AddPaymentScreenState();
}

class _AddPaymentScreenState
    extends State<AddPaymentScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final BusinessRepository _businessRepository =
      BusinessRepository();

  final CustomerRepository _customerRepository =
      CustomerRepository();

  final PaymentRepository _paymentRepository =
      PaymentRepository();

  final LedgerService _ledgerService =
      LedgerService();

  final TextEditingController _amountController =
      TextEditingController();

  final TextEditingController _referenceController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  final NumberFormat _currencyFormat =
      NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  final DateFormat _dateFormat =
      DateFormat('dd MMM yyyy');

  BusinessModel? _business;

  List<CustomerModel> _customers = [];

  CustomerModel? _selectedCustomer;

  DateTime _paymentDate = DateTime.now();

  String _paymentMethod = 'Cash';

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  static const List<String> _paymentMethods = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
    'Other',
  ];

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

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final business =
          await _businessRepository.getCurrentBusiness();

      if (business == null ||
          business.id.trim().isEmpty) {
        throw Exception(
          'Business profile is not available.',
        );
      }

      final customers =
          await _customerRepository.getCustomers(
        businessId: business.id.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _business = business;
        _customers = customers;
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

  Future<void> _selectPaymentDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(
        now.year + 2,
        12,
        31,
      ),
    );

    if (selected == null ||
        !mounted) {
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

    final formState = _formKey.currentState;

    if (formState == null ||
        !formState.validate()) {
      return;
    }

    final business = _business;

    if (business == null ||
        business.id.trim().isEmpty) {
      _showMessage(
        'Business profile is not available.',
        isError: true,
      );
      return;
    }

    final customer = _selectedCustomer;

    if (customer == null ||
        customer.id.trim().isEmpty) {
      _showMessage(
        'Please select a customer.',
        isError: true,
      );
      return;
    }

    final amount = double.tryParse(
      _amountController.text
          .trim()
          .replaceAll(',', ''),
    );

    if (amount == null ||
        !amount.isFinite ||
        amount <= 0) {
      _showMessage(
        'Enter a valid payment amount.',
        isError: true,
      );
      return;
    }

    final paymentMethod =
        _paymentMethod.trim();

    if (paymentMethod.isEmpty) {
      _showMessage(
        'Please select a payment method.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    PaymentModel? savedPayment;

    try {
      final now = DateTime.now();

      final payment = PaymentModel(
        id: '',
        businessId:
            business.id.trim(),
        customerId:
            customer.id.trim(),
        customerName:
            customer.name.trim(),
        amount: amount,
        date: _paymentDate,
        paymentMethod: paymentMethod,
        transactionReference:
            _referenceController.text.trim(),
        notes:
            _notesController.text.trim(),
        createdAt: now,
      );

      savedPayment =
          await _paymentRepository.createPayment(
        payment,
      );

      final balanceBefore =
          await _ledgerService.getCustomerBalance(
        businessId: business.id.trim(),
        customerId: customer.id.trim(),
      );

      final balanceAfter =
          balanceBefore - amount;

      await _ledgerService.createTransaction(
        businessId: business.id.trim(),
        customerId: customer.id.trim(),
        customerName: customer.name.trim(),
        transactionType: 'PAYMENT',
        amount: amount,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
        referenceId: savedPayment.id,
        date: _paymentDate,
        notes: _buildLedgerNotes(
          paymentMethod: paymentMethod,
          reference:
              _referenceController.text.trim(),
          notes:
              _notesController.text.trim(),
        ),
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Payment recorded and customer ledger updated successfully.',
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (savedPayment != null) {
        try {
          await _paymentRepository.deletePayment(
            businessId: business.id.trim(),
            paymentId: savedPayment!.id,
          );
        } catch (_) {
          // Keep the original error message if rollback also fails.
        }
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        'Failed to save payment: ${_cleanError(e)}',
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
      parts.add(
        'Method: ${paymentMethod.trim()}',
      );
    }

    if (reference.trim().isNotEmpty) {
      parts.add(
        'Reference: ${reference.trim()}',
      );
    }

    if (notes.trim().isNotEmpty) {
      parts.add(
        notes.trim(),
      );
    }

    return parts.join(' | ');
  }

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
    );
  }

  Widget _buildCustomerSelector() {
    return DropdownButtonFormField<
        CustomerModel>(
      initialValue: _selectedCustomer,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Customer / Hotel',
        icon: Icons.person_rounded,
        hint: 'Select customer',
      ),
      items: _customers.map(
        (customer) {
          return DropdownMenuItem<
              CustomerModel>(
            value: customer,
            child: Text(
              customer.name,
              overflow:
                  TextOverflow.ellipsis,
            ),
          );
        },
      ).toList(),
      onChanged: _isSaving
          ? null
          : (customer) {
              setState(() {
                _selectedCustomer =
                    customer;
              });
            },
      validator: (value) {
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

  Widget _buildPaymentMethodSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _paymentMethod,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Payment Method',
        icon: Icons
            .account_balance_wallet_rounded,
      ),
      items: _paymentMethods.map(
        (method) {
          return DropdownMenuItem<String>(
            value: method,
            child: Text(method),
          );
        },
      ).toList(),
      onChanged: _isSaving
          ? null
          : (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _paymentMethod = value;
              });
            },
      validator: (value) {
        if (value == null ||
            value.trim().isEmpty) {
          return 'Please select payment method';
        }

        return null;
      },
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap:
          _isSaving ? null : _selectPaymentDate,
      borderRadius:
          BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration(
          label: 'Payment Date',
          icon:
              Icons.calendar_today_rounded,
        ),
        child: Text(
          _dateFormat.format(
            _paymentDate,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      enabled: !_isSaving,
      keyboardType:
          const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration: _inputDecoration(
        label: 'Payment Amount',
        icon:
            Icons.currency_rupee_rounded,
        hint: 'Enter amount',
      ),
      validator: (value) {
        final amount = double.tryParse(
          (value ?? '')
              .trim()
              .replaceAll(',', ''),
        );

        if (amount == null ||
            !amount.isFinite ||
            amount <= 0) {
          return 'Enter a valid amount';
        }

        return null;
      },
    );
  }

  Widget _buildReferenceField() {
    return TextFormField(
      controller: _referenceController,
      enabled: !_isSaving,
      textInputAction:
          TextInputAction.next,
      decoration: _inputDecoration(
        label: 'Transaction Reference',
        icon: Icons.receipt_long_rounded,
        hint:
            'Optional reference / transaction ID',
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
      decoration: _inputDecoration(
        label: 'Notes',
        icon: Icons.notes_rounded,
        hint:
            'Add optional payment notes',
      ),
    );
  }

  Widget _buildSummaryCard() {
    final amount = double.tryParse(
          _amountController.text
              .trim()
              .replaceAll(',', ''),
        ) ??
        0;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.success
                        .withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
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
                        'Payment Summary',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Review payment details before saving',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _summaryItem(
                    label: 'Amount',
                    value:
                        _currencyFormat.format(
                      amount,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryItem(
                    label: 'Method',
                    value:
                        _paymentMethod,
                  ),
                ),
              ],
            ),
            if (_selectedCustomer != null)
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 14,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _summaryItem(
                        label: 'Customer',
                        value:
                            _selectedCustomer!
                                .name
                                .trim(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryItem(
                        label: 'Date',
                        value:
                            _dateFormat.format(
                          _paymentDate,
                        ),
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

  Widget _summaryItem({
    required String label,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: _isSaving
              ? null
              : () => Navigator.pop(
                    context,
                  ),
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.success
                .withOpacity(0.12),
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
                'Add Payment',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                'Record customer payment',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
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
      child: ElevatedButton.icon(
        onPressed:
            _isSaving ? null : _savePayment,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.5,
                ),
              )
            : const Icon(
                Icons.check_circle_rounded,
              ),
        label: Text(
          _isSaving
              ? 'Saving Payment...'
              : 'Save Payment',
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.danger
                    .withOpacity(0.12),
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
              style: Theme.of(context)
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
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
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

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final isWide =
              constraints.maxWidth >= 900;

          final formContent = Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              _buildCustomerSelector(),
              const SizedBox(height: 16),
              if (isWide)
                Row(
                  children: [
                    Expanded(
                      child:
                          _buildAmountField(),
                    ),
                    const SizedBox(
                      width: 16,
                    ),
                    Expanded(
                      child:
                          _buildPaymentMethodSelector(),
                    ),
                  ],
                )
              else ...[
                _buildAmountField(),
                const SizedBox(height: 16),
                _buildPaymentMethodSelector(),
              ],
              const SizedBox(height: 16),
              _buildDateSelector(),
              const SizedBox(height: 16),
              _buildReferenceField(),
              const SizedBox(height: 8),
              _buildNotesField(),
              const SizedBox(height: 8),
              _buildSummaryCard(),
              const SizedBox(height: 20),
              _buildSaveButton(),
            ],
          );

          return Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(20),
              child: formContent,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Payment',
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : _errorMessage != null &&
                    _business == null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      children: [
                        _buildHeader(),
                        const SizedBox(
                          height: 20,
                        ),
                        _buildForm(),
                        const SizedBox(
                          height: 24,
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
    
