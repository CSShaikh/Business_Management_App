import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../models/payment_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/payment_repository.dart';

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
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final business =
          await _businessRepository
              .getBusinessForCurrentUser();

      if (!mounted) {
        return;
      }

      if (business == null ||
          business.id.trim().isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Business profile not found.';
        });
        return;
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
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load payment data.';
      });
    }
  }

  Future<void> _selectPaymentDate() async {
    final now = DateTime.now();

    final selected =
        await showDatePicker(
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

      await _paymentRepository
          .createPayment(payment);

      if (!mounted) {
        return;
      }

      _showMessage(
        'Payment recorded successfully.',
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
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
      onChanged: (_) {
        setState(() {});
      },
      decoration: _inputDecoration(
        label: 'Amount',
        icon:
            Icons.currency_rupee_rounded,
        hint: 'Enter payment amount',
      ),
      validator: (value) {
        final text =
            value?.trim() ?? '';

        if (text.isEmpty) {
          return 'Please enter amount';
        }

        final amount = double.tryParse(
          text.replaceAll(',', ''),
        );

        if (amount == null ||
            !amount.isFinite) {
          return 'Enter a valid amount';
        }

        if (amount <= 0) {
          return 'Amount must be greater than zero';
        }

        return null;
      },
    );
  }

  Widget _buildReferenceField() {
    return TextFormField(
      controller:
          _referenceController,
      enabled: !_isSaving,
      textInputAction:
          TextInputAction.next,
      decoration: _inputDecoration(
        label: 'Transaction Reference',
        icon:
            Icons.receipt_long_rounded,
        hint:
            'UPI ID, cheque no., transaction ID...',
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      enabled: !_isSaving,
      minLines: 3,
      maxLines: 5,
      textInputAction:
          TextInputAction.newline,
      decoration: _inputDecoration(
        label: 'Notes',
        icon: Icons.notes_rounded,
        hint:
            'Add any additional notes',
      ),
    );
  }

  Widget _buildPaymentSummary() {
    final amount =
        double.tryParse(
              _amountController.text
                  .trim()
                  .replaceAll(',', ''),
            ) ??
            0;

    final safeAmount =
        amount.isFinite ? amount : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success
                .withValues(alpha: 0.10),
            AppColors.primary
                .withValues(alpha: 0.08),
          ],
        ),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.success
              .withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.success
                  .withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(14),
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
                  'Payment Amount',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(height: 3),
                Text(
                  _currencyFormat.format(
                    safeAmount,
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        color:
                            AppColors.success,
                        fontWeight:
                            FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
          if (_selectedCustomer != null)
            Flexible(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    'Received from',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _selectedCustomer!
                        .name
                        .trim(),
                    textAlign:
                        TextAlign.end,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context)
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
      child: child,
    );
  }

  Widget _buildSectionTitle(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary
                .withValues(alpha: 0.10),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
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

  Widget _buildPageHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: 0.15),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons
                  .account_balance_wallet_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Record Payment',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight:
                            FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Record money received from a customer or hotel.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: Colors.white
                            .withValues(
                          alpha: 0.82,
                        ),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed:
            _isSaving ? null : _savePayment,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons
                    .check_circle_outline_rounded,
              ),
        label: Text(
          _isSaving
              ? 'SAVING PAYMENT...'
              : 'SAVE PAYMENT',
        ),
      ),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final isDesktop =
            constraints.maxWidth >= 1000;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  isDesktop ? 1100 : 700,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  30,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildPageHeader(),
                    const SizedBox(height: 16),
                    _buildPaymentSummary(),
                    const SizedBox(height: 16),

                    _buildFormCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            'Payment Information',
                            'Enter the payment transaction details.',
                            Icons.payments_rounded,
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          if (isDesktop)
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child:
                                      _buildCustomerSelector(),
                                ),
                                const SizedBox(
                                  width: 14,
                                ),
                                Expanded(
                                  child:
                                      _buildAmountField(),
                                ),
                              ],
                            )
                          else ...[
                            _buildCustomerSelector(),
                            const SizedBox(
                              height: 14,
                            ),
                            _buildAmountField(),
                          ],
                          const SizedBox(
                            height: 14,
                          ),
                          if (isDesktop)
                            Row(
                              children: [
                                Expanded(
                                  child:
                                      _buildPaymentMethodSelector(),
                                ),
                                const SizedBox(
                                  width: 14,
                                ),
                                Expanded(
                                  child:
                                      _buildDateSelector(),
                                ),
                              ],
                            )
                          else ...[
                            _buildPaymentMethodSelector(),
                            const SizedBox(
                              height: 14,
                            ),
                            _buildDateSelector(),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildFormCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            'Additional Information',
                            'Optional transaction details.',
                            Icons
                                .description_outlined,
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          _buildReferenceField(),
                          const SizedBox(
                            height: 14,
                          ),
                          _buildNotesField(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Payment',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 56,
                            color:
                                AppColors.danger,
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          Text(
                            _errorMessage!,
                            textAlign:
                                TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          FilledButton.icon(
                            onPressed:
                                _loadData,
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
                  )
                : _buildContent(),
      ),
    );
  }
}