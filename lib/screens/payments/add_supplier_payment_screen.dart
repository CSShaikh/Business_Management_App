import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/supplier_model.dart';
import '../../models/supplier_payment_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../repositories/supplier_payment_repository.dart';
import '../../services/ledger/supplier_ledger_service.dart';

class AddSupplierPaymentScreen extends StatefulWidget {
  final SupplierPaymentModel? payment;

  const AddSupplierPaymentScreen({
    super.key,
    this.payment,
  });

  bool get isEditMode => payment != null;

  @override
  State<AddSupplierPaymentScreen> createState() =>
      _AddSupplierPaymentScreenState();
}

class _AddSupplierPaymentScreenState
    extends State<AddSupplierPaymentScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final BusinessRepository _businessRepository =
      BusinessRepository();

  final SupplierRepository _supplierRepository =
      SupplierRepository();

  final SupplierPaymentRepository _paymentRepository =
      SupplierPaymentRepository();

  final SupplierLedgerService _supplierLedgerService =
      SupplierLedgerService();

  final TextEditingController _amountController =
      TextEditingController();

  final TextEditingController _referenceController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  final TextEditingController _supplierSearchController =
      TextEditingController();

  final DateFormat _dateFormat =
      DateFormat('dd MMM yyyy');

  final NumberFormat _currencyFormat =
      NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static const List<String> _paymentMethods =
      <String>[
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
    'Other',
  ];

  BusinessModel? _business;

  List<SupplierModel> _suppliers =
      <SupplierModel>[];

  SupplierModel? _selectedSupplier;

  DateTime _paymentDate = DateTime.now();

  String _paymentMethod = 'Cash';

  double _outstanding = 0;

  bool _isLoading = true;

  bool _isSaving = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _supplierSearchController.dispose();

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
      final BusinessModel? business =
          await _businessRepository
              .getBusinessForCurrentUser();

      if (business == null) {
        throw StateError(
          'Business profile not found. Please complete business setup.',
        );
      }

      final String businessId =
          business.id.trim();

      if (businessId.isEmpty) {
        throw StateError(
          'Business ID is missing.',
        );
      }

      final List<SupplierModel> suppliers =
          await _supplierRepository.getSuppliers(
        businessId,
      );

      SupplierModel? selectedSupplier;

      if (widget.payment != null) {
        final String paymentSupplierId =
            widget.payment!.supplierId.trim();

        if (paymentSupplierId.isNotEmpty) {
          for (final SupplierModel supplier
              in suppliers) {
            if (supplier.id.trim() ==
                paymentSupplierId) {
              selectedSupplier = supplier;
              break;
            }
          }

          if (selectedSupplier == null) {
            try {
              selectedSupplier =
                  await _supplierRepository.getSupplier(
                businessId,
                paymentSupplierId,
              );
            } catch (_) {
              selectedSupplier = null;
            }
          }
        }

        _amountController.text =
            widget.payment!.amount.toStringAsFixed(2);

        _referenceController.text =
            widget.payment!.transactionReference;

        _notesController.text =
            widget.payment!.notes;

        _paymentDate =
            widget.payment!.date;

        final String existingMethod =
            widget.payment!.paymentMethod.trim();

        if (_paymentMethods.contains(
          existingMethod,
        )) {
          _paymentMethod = existingMethod;
        } else {
          _paymentMethod = 'Other';
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _business = business;
        _suppliers = suppliers;
        _selectedSupplier = selectedSupplier;
        _isLoading = false;
      });

      await _loadOutstanding();
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

  Future<void> _loadOutstanding() async {
    final BusinessModel? business =
        _business;

    final SupplierModel? supplier =
        _selectedSupplier;

    if (business == null ||
        supplier == null ||
        business.id.trim().isEmpty ||
        supplier.id.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _outstanding = 0;
        });
      }

      return;
    }

    try {
      double balance =
          await _supplierLedgerService
              .getSupplierBalance(
        businessId: business.id.trim(),
        supplierId: supplier.id.trim(),
      );

      /*
       * During edit, the existing payment is already included in the
       * supplier's ledger. Therefore add the old payment amount back
       * so the current payment can be edited without incorrectly
       * rejecting the original amount.
       */
      if (widget.payment != null &&
          widget.payment!.supplierId.trim() ==
              supplier.id.trim()) {
        balance += widget.payment!.amount;
      }

      if (balance < 0) {
        balance = 0;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _outstanding = balance;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _outstanding = 0;
      });
    }
  }

  // ===========================================================================
  // SUPPLIER SELECTION
  // ===========================================================================

  Future<void> _selectSupplier() async {
    if (_isSaving || _isLoading) {
      return;
    }

    final SupplierModel? selected =
        await showModalBottomSheet<SupplierModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return _SupplierPickerSheet(
          suppliers: _suppliers,
          selectedSupplier: _selectedSupplier,
        );
      },
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _selectedSupplier = selected;
    });

    _amountController.clear();

    await _loadOutstanding();
  }

  // ===========================================================================
  // DATE
  // ===========================================================================

  Future<void> _selectDate() async {
    if (_isSaving) {
      return;
    }

    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _paymentDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _paymentDate.hour,
        _paymentDate.minute,
        _paymentDate.second,
      );
    });
  }

  // ===========================================================================
  // VALIDATION / HELPERS
  // ===========================================================================

  double _parseAmount(String value) {
    return double.tryParse(
          value
              .trim()
              .replaceAll(',', ''),
        ) ??
        0;
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

  // ===========================================================================
  // SAVE
  // ===========================================================================

  Future<void> _savePayment() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final BusinessModel? business =
        _business;

    final SupplierModel? supplier =
        _selectedSupplier;

    if (business == null) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );
      return;
    }

    if (supplier == null) {
      _showMessage(
        'Please select a supplier.',
        isError: true,
      );
      return;
    }

    final String businessId =
        business.id.trim();

    final String supplierId =
        supplier.id.trim();

    final String supplierName =
        supplier.name.trim();

    if (businessId.isEmpty) {
      _showMessage(
        'Business ID is missing.',
        isError: true,
      );
      return;
    }

    if (supplierId.isEmpty) {
      _showMessage(
        'Supplier ID is missing.',
        isError: true,
      );
      return;
    }

    if (supplierName.isEmpty) {
      _showMessage(
        'Supplier name is missing.',
        isError: true,
      );
      return;
    }

    final double amount =
        _parseAmount(
      _amountController.text,
    );

    if (!amount.isFinite ||
        amount <= 0) {
      _showMessage(
        'Payment amount must be greater than zero.',
        isError: true,
      );
      return;
    }

    final double currentOutstanding =
        _outstanding;

    if (!currentOutstanding.isFinite ||
        currentOutstanding < 0) {
      _showMessage(
        'Unable to calculate supplier outstanding balance.',
        isError: true,
      );
      return;
    }

    if (amount >
        currentOutstanding +
            0.000001) {
      _showMessage(
        'Payment cannot be greater than outstanding payable '
        '(${_currencyFormat.format(currentOutstanding)}).',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isEditMode) {
        await _updateExistingPayment(
          businessId: businessId,
          supplier: supplier,
          amount: amount,
        );
      } else {
        await _createNewPayment(
          businessId: businessId,
          supplier: supplier,
          amount: amount,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        widget.isEditMode
            ? 'Supplier payment updated and ledger corrected successfully.'
            : 'Supplier payment recorded and supplier ledger updated successfully.',
      );

      await Future<void>.delayed(
        const Duration(
          milliseconds: 350,
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

      _showMessage(
        widget.isEditMode
            ? 'Unable to update supplier payment: ${_cleanError(e)}'
            : 'Unable to save supplier payment: ${_cleanError(e)}',
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

  // ===========================================================================
  // CREATE PAYMENT
  // ===========================================================================

  Future<void> _createNewPayment({
    required String businessId,
    required SupplierModel supplier,
    required double amount,
  }) async {
    SupplierPaymentModel? createdPayment;

    try {
      /*
       * Re-check the supplier balance immediately before saving.
       * This protects against a stale balance if another payment was
       * recorded after the screen was opened.
       */
      final double latestBalance =
          await _supplierLedgerService
              .getSupplierBalance(
        businessId: businessId,
        supplierId: supplier.id.trim(),
      );

      if (latestBalance <=
          0.000001) {
        throw StateError(
          'This supplier has no outstanding payable.',
        );
      }

      if (amount >
          latestBalance +
              0.000001) {
        throw StateError(
          'Payment exceeds the current supplier outstanding payable '
          'of ${_currencyFormat.format(latestBalance)}.',
        );
      }

      final DateTime now =
          DateTime.now();

      final SupplierPaymentModel payment =
          SupplierPaymentModel(
        id: '',
        businessId: businessId,
        supplierId: supplier.id.trim(),
        supplierName: supplier.name.trim(),
        amount: amount,
        date: _paymentDate,
        paymentMethod:
            _paymentMethod.trim(),
        transactionReference:
            _referenceController.text.trim(),
        notes: _notesController.text.trim(),
        createdAt: now,
      );

      createdPayment =
          await _paymentRepository
              .createPayment(payment);

      try {
        /*
         * IMPORTANT:
         *
         * SupplierLedgerService expects:
         *   businessId
         *   paymentAmount
         *   supplierId
         *   supplierName
         *
         * It does NOT accept:
         *   payment
         *   balanceBefore
         */
        await _supplierLedgerService
            .createSupplierPaymentLedgerEntry(
          businessId: businessId,
          paymentAmount: amount,
          supplierId: supplier.id.trim(),
          supplierName: supplier.name.trim(),
        );
      } catch (ledgerError) {
        /*
         * Payment document was created but ledger creation failed.
         * Remove the payment document so the database does not contain
         * a payment without its corresponding ledger transaction.
         */
        try {
          await _paymentRepository
              .deletePayment(
            businessId: businessId,
            paymentId: createdPayment.id,
          );
        } catch (_) {
          // Preserve original ledger error.
        }

        rethrow;
      }
    } catch (_) {
      rethrow;
    }
  }

  // ===========================================================================
  // UPDATE PAYMENT
  // ===========================================================================

  Future<void> _updateExistingPayment({
    required String businessId,
    required SupplierModel supplier,
    required double amount,
  }) async {
    final SupplierPaymentModel? oldPayment =
        widget.payment;

    if (oldPayment == null) {
      throw StateError(
        'Existing supplier payment was not found.',
      );
    }

    final String oldPaymentId =
        oldPayment.id.trim();

    if (oldPaymentId.isEmpty) {
      throw StateError(
        'Existing payment ID is missing.',
      );
    }

    final String oldSupplierId =
        oldPayment.supplierId.trim();

    final String oldSupplierName =
        oldPayment.supplierName.trim();

    if (oldSupplierId.isEmpty) {
      throw StateError(
        'Existing supplier ID is missing.',
      );
    }

    bool oldLedgerReversed = false;

    bool paymentUpdated = false;

    bool newLedgerCreated = false;

    try {
      /*
       * If the supplier itself is changed during edit, the old supplier
       * ledger must be reversed first. The new payment then gets posted
       * to the newly selected supplier.
       */
      await _supplierLedgerService
          .createSupplierPaymentReversal(
        businessId: businessId,
        paymentAmount: oldPayment.amount,
        supplierId: oldSupplierId,
        supplierName: oldSupplierName.isEmpty
            ? supplier.name.trim()
            : oldSupplierName,
      );

      oldLedgerReversed = true;

      /*
       * Check the new supplier's current payable after the old payment
       * has been reversed.
       *
       * If editing the same supplier, reversing the old payment increases
       * the available payable by the old payment amount.
       */
      final double latestBalance =
          await _supplierLedgerService
              .getSupplierBalance(
        businessId: businessId,
        supplierId: supplier.id.trim(),
      );

      if (amount >
          latestBalance +
              0.000001) {
        throw StateError(
          'Payment exceeds the current supplier outstanding payable '
          'of ${_currencyFormat.format(latestBalance)}.',
        );
      }

      final SupplierPaymentModel updatedPayment =
          oldPayment.copyWith(
        businessId: businessId,
        supplierId: supplier.id.trim(),
        supplierName: supplier.name.trim(),
        amount: amount,
        date: _paymentDate,
        paymentMethod:
            _paymentMethod.trim(),
        transactionReference:
            _referenceController.text.trim(),
        notes: _notesController.text.trim(),
      );

      await _paymentRepository
          .updatePayment(
        updatedPayment,
      );

      paymentUpdated = true;

      try {
        /*
         * Same actual SupplierLedgerService API:
         * businessId + paymentAmount + supplierId + supplierName
         */
        await _supplierLedgerService
            .createSupplierPaymentLedgerEntry(
          businessId: businessId,
          paymentAmount: amount,
          supplierId: supplier.id.trim(),
          supplierName: supplier.name.trim(),
        );

        newLedgerCreated = true;
      } catch (ledgerError) {
        /*
         * Restore the old payment document first.
         */
        try {
          await _paymentRepository
              .updatePayment(
            oldPayment,
          );
          paymentUpdated = false;
        } catch (_) {
          // Preserve original ledger error.
        }

        rethrow;
      }
    } catch (e) {
      /*
       * If the new ledger was created but something later failed,
       * reverse that new ledger entry.
       */
      if (newLedgerCreated) {
        try {
          await _supplierLedgerService
              .createSupplierPaymentReversal(
            businessId: businessId,
            paymentAmount: amount,
            supplierId: supplier.id.trim(),
            supplierName: supplier.name.trim(),
          );
        } catch (_) {
          // Preserve original error.
        }
      }

      /*
       * Restore the original payment document if it was changed.
       */
      if (paymentUpdated) {
        try {
          await _paymentRepository
              .updatePayment(
            oldPayment,
          );
        } catch (_) {
          // Preserve original error.
        }
      }

      /*
       * Restore the original supplier ledger entry if the old ledger
       * was already reversed.
       */
      if (oldLedgerReversed) {
        try {
          await _supplierLedgerService
              .createSupplierPaymentLedgerEntry(
            businessId: businessId,
            paymentAmount: oldPayment.amount,
            supplierId: oldSupplierId,
            supplierName: oldSupplierName.isEmpty
                ? supplier.name.trim()
                : oldSupplierName,
          );
        } catch (_) {
          // Preserve original error.
        }
      }

      rethrow;
    }
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
        appBar: AppBar(
          title: Text(
            widget.isEditMode
                ? 'Edit Supplier Payment'
                : 'Add Supplier Payment',
          ),
        ),
        body: const Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditMode
                ? 'Edit Supplier Payment'
                : 'Add Supplier Payment',
          ),
        ),
        body: Center(
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
                  _errorMessage!,
                  textAlign:
                      TextAlign.center,
                  style: theme
                      .textTheme
                      .bodyLarge,
                ),
                const SizedBox(
                  height: 20,
                ),
                OutlinedButton.icon(
                  onPressed:
                      _isSaving
                          ? null
                          : _initialize,
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
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? 'Edit Supplier Payment'
              : 'Add Supplier Payment',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (
              BuildContext context,
              BoxConstraints constraints,
            ) {
              final bool isWide =
                  constraints.maxWidth >=
                      900;

              return SingleChildScrollView(
                padding:
                    const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(
                      maxWidth: 1100,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .stretch,
                      children: <Widget>[
                        _buildHeader(),
                        const SizedBox(
                          height: 16,
                        ),
                        if (isWide)
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: <Widget>[
                              Expanded(
                                child:
                                    _buildSupplierCard(),
                              ),
                              const SizedBox(
                                width: 16,
                              ),
                              Expanded(
                                child:
                                    _buildPaymentCard(),
                              ),
                            ],
                          )
                        else ...<Widget>[
                          _buildSupplierCard(),
                          const SizedBox(
                            height: 16,
                          ),
                          _buildPaymentCard(),
                        ],
                        const SizedBox(
                          height: 16,
                        ),
                        _buildNotesCard(),
                        const SizedBox(
                          height: 16,
                        ),
                        _buildSummaryCard(),
                        const SizedBox(
                          height: 20,
                        ),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final bool isEdit =
        widget.isEditMode;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: <Color>[
            AppColors.primary,
            AppColors.secondary,
          ],
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: 0.16,
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(
            width: 16,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isEdit
                      ? 'Update supplier payment'
                      : 'Record supplier payment',
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  isEdit
                      ? 'Update payment details and keep the supplier ledger synchronized.'
                      : 'Record a payment against the supplier outstanding balance.',
                  style:
                      TextStyle(
                    color: Colors
                        .white
                        .withValues(
                      alpha: 0.86,
                    ),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle(
              icon:
                  Icons.business_rounded,
              title: 'Supplier',
              subtitle:
                  'Select the supplier receiving the payment',
            ),
            const SizedBox(
              height: 16,
            ),
            InkWell(
              onTap:
                  _isSaving
                      ? null
                      : _selectSupplier,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              child: InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText:
                      'Supplier',
                  prefixIcon:
                      Icon(
                    Icons
                        .business_outlined,
                  ),
                  suffixIcon:
                      Icon(
                    Icons
                        .keyboard_arrow_down_rounded,
                  ),
                ),
                child: Text(
                  _selectedSupplier
                          ?.name ??
                      'Select supplier',
                  style: TextStyle(
                    color:
                        _selectedSupplier ==
                                null
                            ? themeLightSecondary(
                                context,
                              )
                            : null,
                    fontWeight:
                        _selectedSupplier ==
                                null
                            ? FontWeight.w400
                            : FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (_selectedSupplier !=
                null) ...<Widget>[
              const SizedBox(
                height: 12,
              ),
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  12,
                ),
                decoration:
                    BoxDecoration(
                  color: AppColors
                      .primary
                      .withValues(
                    alpha: 0.06,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    _supplierInfoRow(
                      Icons
                          .phone_rounded,
                      _selectedSupplier!
                              .mobile
                              .trim()
                              .isEmpty
                          ? 'Mobile number not available'
                          : _selectedSupplier!
                              .mobile,
                    ),
                    if (_selectedSupplier!
                        .contactPerson
                        .trim()
                        .isNotEmpty) ...<Widget>[
                      const SizedBox(
                        height: 7,
                      ),
                      _supplierInfoRow(
                        Icons
                            .person_outline_rounded,
                        _selectedSupplier!
                            .contactPerson,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color? themeLightSecondary(
    BuildContext context,
  ) {
    return Theme.of(context)
        .colorScheme
        .onSurfaceVariant;
  }

  Widget _supplierInfoRow(
    IconData icon,
    String text,
  ) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 17,
          color:
              AppColors.primary,
        ),
        const SizedBox(
          width: 8,
        ),
        Expanded(
          child: Text(
            text,
            style:
                const TextStyle(
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle(
              icon:
                  Icons.receipt_long_rounded,
              title:
                  'Payment Details',
              subtitle:
                  'Enter amount, date and payment method',
            ),
            const SizedBox(
              height: 16,
            ),
            _buildAmountField(),
            const SizedBox(
              height: 14,
            ),
            InkWell(
              onTap:
                  _isSaving
                      ? null
                      : _selectDate,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              child: InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText:
                      'Payment Date',
                  prefixIcon:
                      Icon(
                    Icons
                        .calendar_month_rounded,
                  ),
                  suffixIcon:
                      Icon(
                    Icons
                        .edit_calendar_rounded,
                  ),
                ),
                child: Text(
                  _dateFormat.format(
                    _paymentDate,
                  ),
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
                prefixIcon:
                    Icon(
                  Icons
                      .account_balance_wallet_rounded,
                ),
              ),
              items:
                  _paymentMethods.map(
                (
                  String method,
                ) {
                  return DropdownMenuItem<
                      String>(
                    value: method,
                    child:
                        Text(method),
                  );
                },
              ).toList(),
              onChanged:
                  _isSaving
                      ? null
                      : (
                          String? value,
                        ) {
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
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller:
          _amountController,
      enabled: !_isSaving,
      keyboardType:
          const TextInputType
              .numberWithOptions(
        decimal: true,
      ),
      decoration:
          const InputDecoration(
        labelText:
            'Payment Amount',
        hintText:
            'Enter amount',
        prefixIcon:
            Icon(
          Icons
              .currency_rupee_rounded,
        ),
      ),
      validator: (
        String? value,
      ) {
        final double amount =
            _parseAmount(
          value ?? '',
        );

        if (!amount.isFinite ||
            amount <= 0) {
          return 'Enter a valid payment amount';
        }

        return null;
      },
      onChanged: (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle(
              icon:
                  Icons.notes_rounded,
              title: 'Notes',
              subtitle:
                  'Optional payment reference and notes',
            ),
            const SizedBox(
              height: 16,
            ),
            TextFormField(
              controller:
                  _referenceController,
              enabled: !_isSaving,
              textInputAction:
                  TextInputAction.next,
              maxLength: 100,
              decoration:
                  const InputDecoration(
                labelText:
                    'Transaction Reference',
                hintText:
                    'Optional transaction ID / reference',
                prefixIcon:
                    Icon(
                  Icons
                      .receipt_long_rounded,
                ),
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            TextFormField(
              controller:
                  _notesController,
              enabled: !_isSaving,
              maxLines: 4,
              maxLength: 500,
              decoration:
                  const InputDecoration(
                labelText: 'Notes',
                hintText:
                    'Add optional payment notes',
                prefixIcon:
                    Icon(
                  Icons.notes_rounded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final double amount =
        _parseAmount(
      _amountController.text,
    );

    final double remaining =
        (_outstanding - amount)
            .clamp(
      0,
      double.infinity,
    );

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle(
              icon:
                  Icons.account_balance_wallet_rounded,
              title:
                  'Payment Summary',
              subtitle:
                  'Review payable balance before saving',
            ),
            const SizedBox(
              height: 18,
            ),
            _summaryRow(
              'Current Outstanding',
              _currencyFormat.format(
                _outstanding,
              ),
              valueColor:
                  AppColors.danger,
            ),
            const SizedBox(
              height: 12,
            ),
            _summaryRow(
              'This Payment',
              _currencyFormat.format(
                amount,
              ),
              valueColor:
                  AppColors.primary,
            ),
            const Divider(
              height: 28,
            ),
            _summaryRow(
              'Remaining Payable',
              _currencyFormat.format(
                remaining,
              ),
              valueColor:
                  remaining > 0
                      ? AppColors.danger
                      : AppColors.success,
              large: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool large = false,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize:
                  large ? 15 : 14,
              fontWeight:
                  large
                      ? FontWeight.w800
                      : FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(
          width: 12,
        ),
        Text(
          value,
          style: TextStyle(
            fontSize:
                large ? 18 : 15,
            fontWeight:
                FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    final double amount =
        _parseAmount(
      _amountController.text,
    );

    final bool validAmount =
        amount > 0 &&
            amount <=
                _outstanding +
                    0.000001;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed:
            _isSaving ||
                    !validAmount ||
                    _selectedSupplier ==
                        null
                ? null
                : _savePayment,
        icon: _isSaving
            ? const SizedBox(
                width: 19,
                height: 19,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      Colors.white,
                ),
              )
            : const Icon(
                Icons
                    .check_circle_outline_rounded,
              ),
        label: Text(
          _isSaving
              ? 'Saving...'
              : widget.isEditMode
                  ? 'Update Payment'
                  : 'Save Payment',
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION TITLE
// =============================================================================

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
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration:
              BoxDecoration(
            color: AppColors.primary
                .withValues(
              alpha: 0.10,
            ),
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
          child: Icon(
            icon,
            color:
                AppColors.primary,
            size: 21,
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: 3,
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                )
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
      ],
    );
  }
}

// =============================================================================
// SUPPLIER PICKER
// =============================================================================

class _SupplierPickerSheet
    extends StatefulWidget {
  final List<SupplierModel> suppliers;
  final SupplierModel? selectedSupplier;

  const _SupplierPickerSheet({
    required this.suppliers,
    required this.selectedSupplier,
  });

  @override
  State<_SupplierPickerSheet>
      createState() =>
          _SupplierPickerSheetState();
}

class _SupplierPickerSheetState
    extends State<_SupplierPickerSheet> {
  final TextEditingController
      _searchController =
      TextEditingController();

  String _query = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _handleSearchChanged,
    );
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _query =
          _searchController.text
              .trim()
              .toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController
        .removeListener(
      _handleSearchChanged,
    );

    _searchController.dispose();

    super.dispose();
  }

  List<SupplierModel>
      get _filteredSuppliers {
    if (_query.isEmpty) {
      return widget.suppliers;
    }

    return widget.suppliers
        .where(
      (
        SupplierModel supplier,
      ) {
        return supplier.name
                .toLowerCase()
                .contains(_query) ||
            supplier.contactPerson
                .toLowerCase()
                .contains(_query) ||
            supplier.mobile
                .toLowerCase()
                .contains(_query) ||
            supplier.email
                .toLowerCase()
                .contains(_query) ||
            supplier.address
                .toLowerCase()
                .contains(_query) ||
            supplier.gstNumber
                .toLowerCase()
                .contains(_query);
      },
    ).toList();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final List<SupplierModel>
        suppliers =
        _filteredSuppliers;

    return SafeArea(
      child: SizedBox(
        height:
            MediaQuery.sizeOf(
                  context,
                ).height *
                0.78,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            4,
            16,
            16,
          ),
          child: Column(
            children: <Widget>[
              Text(
                'Select Supplier',
                style: Theme.of(
                  context,
                )
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: 14,
              ),
              TextField(
                controller:
                    _searchController,
                autofocus: true,
                decoration:
                    InputDecoration(
                  hintText:
                      'Search supplier...',
                  prefixIcon:
                      const Icon(
                    Icons
                        .search_rounded,
                  ),
                  suffixIcon:
                      _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed:
                                  () {
                                _searchController
                                    .clear();
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
              Expanded(
                child: suppliers.isEmpty
                    ? const Center(
                        child: Text(
                          'No suppliers found.',
                        ),
                      )
                    : ListView.separated(
                        itemCount:
                            suppliers.length,
                        separatorBuilder:
                            (
                          BuildContext
                              context,
                          int index,
                        ) {
                          return const Divider(
                            height: 1,
                          );
                        },
                        itemBuilder:
                            (
                          BuildContext
                              context,
                          int index,
                        ) {
                          final SupplierModel
                              supplier =
                              suppliers[
                                  index];

                          final bool
                              selected =
                              widget
                                      .selectedSupplier
                                      ?.id ==
                                  supplier.id;

                          return ListTile(
                            contentPadding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 5,
                            ),
                            leading:
                                CircleAvatar(
                              backgroundColor:
                                  AppColors
                                      .primary
                                      .withValues(
                                alpha: 0.10,
                              ),
                              child:
                                  const Icon(
                                Icons
                                    .business_rounded,
                                color:
                                    AppColors
                                        .primary,
                              ),
                            ),
                            title:
                                Text(
                              supplier.name,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            subtitle:
                                _buildSubtitle(
                              supplier,
                            ),
                            trailing:
                                selected
                                    ? const Icon(
                                        Icons
                                            .check_circle_rounded,
                                        color:
                                            AppColors
                                                .success,
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

  Widget? _buildSubtitle(
    SupplierModel supplier,
  ) {
    final String mobile =
        supplier.mobile.trim();

    final String contact =
        supplier.contactPerson.trim();

    if (mobile.isEmpty &&
        contact.isEmpty) {
      return null;
    }

    if (mobile.isNotEmpty &&
        contact.isNotEmpty) {
      return Text(
        '$contact • $mobile',
        overflow:
            TextOverflow.ellipsis,
      );
    }

    return Text(
      mobile.isNotEmpty
          ? mobile
          : contact,
      overflow:
          TextOverflow.ellipsis,
    );
  }
}