import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/expense_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/expense_repository.dart';

class AddExpenseScreen extends StatefulWidget {
  final ExpenseModel? expense;

  const AddExpenseScreen({
    super.key,
    this.expense,
  });

  bool get isEditMode => expense != null;

  @override
  State<AddExpenseScreen> createState() =>
      _AddExpenseScreenState();
}

class _AddExpenseScreenState
    extends State<AddExpenseScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final BusinessRepository _businessRepository =
      BusinessRepository();

  final ExpenseRepository _expenseRepository =
      ExpenseRepository();

  final TextEditingController _amountController =
      TextEditingController();

  final TextEditingController _categoryController =
      TextEditingController();

  final TextEditingController _descriptionController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  final TextEditingController _receiptUrlController =
      TextEditingController();

  BusinessModel? _business;

  DateTime _expenseDate = DateTime.now();

  String _paymentMethod = 'Cash';

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  static const List<String> _paymentMethods = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
    'Card',
    'Other',
  ];

  static const List<String> _commonCategories = [
    'Rent',
    'Electricity',
    'Water',
    'Internet',
    'Salary',
    'Transport',
    'Fuel',
    'Maintenance',
    'Office Supplies',
    'Marketing',
    'Food',
    'Travel',
    'Other',
  ];

  final NumberFormat _currencyFormat =
      NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  final DateFormat _dateFormat =
      DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();

    _initializeControllers();
    _loadBusiness();
  }

  void _initializeControllers() {
    final expense = widget.expense;

    if (expense == null) {
      return;
    }

    _amountController.text =
        expense.amount.toString();

    _categoryController.text =
        expense.category;

    _descriptionController.text =
        expense.description;

    _notesController.text =
        expense.notes;

    _receiptUrlController.text =
        expense.receiptUrl;

    _expenseDate = expense.date;

    if (_paymentMethods.contains(
      expense.paymentMethod,
    )) {
      _paymentMethod = expense.paymentMethod;
    } else if (expense.paymentMethod
        .trim()
        .isNotEmpty) {
      _paymentMethod = expense.paymentMethod.trim();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _receiptUrlController.dispose();

    super.dispose();
  }

  Future<void> _loadBusiness() async {
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

      if (business == null) {
        setState(() {
          _business = null;
          _isLoading = false;
          _errorMessage =
              'Business profile not found.';
        });
        return;
      }

      setState(() {
        _business = business;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load business information.';
      });
    }
  }

  Future<void> _selectExpenseDate() async {
    final now = DateTime.now();

    final selectedDate =
        await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(
        now.year + 2,
        12,
        31,
      ),
    );

    if (selectedDate == null ||
        !mounted) {
      return;
    }

    setState(() {
      _expenseDate = selectedDate;
    });
  }

  Future<void> _selectCategory() async {
    final selected =
        await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              20,
            ),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                child: Text(
                  'Select Expense Category',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ..._commonCategories.map(
                (category) {
                  final isSelected =
                      _categoryController.text
                              .trim()
                              .toLowerCase() ==
                          category.toLowerCase();

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary
                            .withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(11),
                      ),
                      child: Icon(
                        _categoryIcon(category),
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(category),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(
                        context,
                        category,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _categoryController.text = selected;
    });
  }

  IconData _categoryIcon(
    String category,
  ) {
    switch (category.toLowerCase()) {
      case 'rent':
        return Icons.home_work_rounded;
      case 'electricity':
        return Icons.bolt_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'internet':
        return Icons.wifi_rounded;
      case 'salary':
        return Icons.people_alt_rounded;
      case 'transport':
        return Icons.local_shipping_rounded;
      case 'fuel':
        return Icons.local_gas_station_rounded;
      case 'maintenance':
        return Icons.build_rounded;
      case 'office supplies':
        return Icons.inventory_2_rounded;
      case 'marketing':
        return Icons.campaign_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'travel':
        return Icons.flight_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Future<void> _saveExpense() async {
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

    final amount = double.tryParse(
      _amountController.text
          .trim()
          .replaceAll(',', ''),
    );

    if (amount == null ||
        !amount.isFinite ||
        amount <= 0) {
      _showMessage(
        'Enter a valid expense amount.',
        isError: true,
      );
      return;
    }

    final category =
        _categoryController.text.trim();

    if (category.isEmpty) {
      _showMessage(
        'Please select an expense category.',
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

      final existingExpense =
          widget.expense;

      final businessId =
          existingExpense != null &&
                  existingExpense.businessId
                      .trim()
                      .isNotEmpty
              ? existingExpense.businessId.trim()
              : business.id.trim();

      if (existingExpense != null &&
          existingExpense.id.trim().isEmpty) {
        throw StateError(
          'Expense ID is missing.',
        );
      }

      final expense = ExpenseModel(
        id: existingExpense?.id.trim() ?? '',
        businessId: businessId,
        category: category,
        amount: amount,
        date: _expenseDate,
        paymentMethod: paymentMethod,
        description:
            _descriptionController.text.trim(),
        notes: _notesController.text.trim(),
        receiptUrl:
            _receiptUrlController.text.trim(),
        createdAt:
            existingExpense?.createdAt ?? now,
      );

      if (widget.isEditMode) {
        await _expenseRepository.updateExpense(
          expense,
        );
      } else {
        await _expenseRepository.createExpense(
          expense,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        widget.isEditMode
            ? 'Expense updated successfully.'
            : 'Expense saved successfully.',
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
        widget.isEditMode
            ? 'Failed to update expense: ${_cleanError(e)}'
            : 'Failed to save expense: ${_cleanError(e)}',
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

  Widget _buildHeader() {
    final isEdit = widget.isEditMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.danger,
            Color(0xFFB91C1C),
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
              color: Colors.white.withValues(
                alpha: 0.15,
              ),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
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
                  isEdit
                      ? 'Edit Expense'
                      : 'Add Expense',
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
                  isEdit
                      ? 'Update your business expense details.'
                      : 'Record a new business expense.',
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

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      enabled: !_isSaving,
      keyboardType:
          const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration: _inputDecoration(
        label: 'Amount',
        icon: Icons.currency_rupee_rounded,
        hint: 'Enter expense amount',
      ),
      onChanged: (_) {
        setState(() {});
      },
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

  Widget _buildCategoryField() {
    return TextFormField(
      controller: _categoryController,
      enabled: !_isSaving,
      readOnly: true,
      onTap: _selectCategory,
      decoration: _inputDecoration(
        label: 'Expense Category',
        icon: Icons.category_rounded,
        hint: 'Select category',
      ).copyWith(
        suffixIcon: const Icon(
          Icons.keyboard_arrow_down_rounded,
        ),
      ),
      validator: (value) {
        if (value == null ||
            value.trim().isEmpty) {
          return 'Please select a category';
        }

        return null;
      },
    );
  }

  Widget _buildPaymentMethodField() {
    return DropdownButtonFormField<String>(
      initialValue:
          _paymentMethods.contains(
        _paymentMethod,
      )
              ? _paymentMethod
              : null,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Payment Method',
        icon:
            Icons.account_balance_wallet_rounded,
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

  Widget _buildDateField() {
    return InkWell(
      onTap: _isSaving
          ? null
          : _selectExpenseDate,
      borderRadius:
          BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration(
          label: 'Expense Date',
          icon: Icons.calendar_today_rounded,
        ),
        child: Text(
          _dateFormat.format(
            _expenseDate,
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller:
          _descriptionController,
      enabled: !_isSaving,
      textInputAction:
          TextInputAction.next,
      decoration: _inputDecoration(
        label: 'Description',
        icon: Icons.description_outlined,
        hint:
            'e.g. Office electricity bill',
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      enabled: !_isSaving,
      minLines: 3,
      maxLines: 5,
      decoration: _inputDecoration(
        label: 'Notes',
        icon: Icons.notes_rounded,
        hint:
            'Add additional information',
      ),
    );
  }

  Widget _buildReceiptField() {
    return TextFormField(
      controller:
          _receiptUrlController,
      enabled: !_isSaving,
      keyboardType:
          TextInputType.url,
      decoration: _inputDecoration(
        label: 'Receipt URL',
        icon: Icons.attach_file_rounded,
        hint:
            'Optional receipt/document URL',
      ),
    );
  }

  Widget _buildSectionCard({
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
              .withValues(alpha: 0.55),
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

  Widget _buildAmountPreview() {
    final amount =
        double.tryParse(
              _amountController.text
                  .trim()
                  .replaceAll(',', ''),
            ) ??
            0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger
            .withValues(alpha: 0.07),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.danger
              .withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_rounded,
            color: AppColors.danger,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Expense Amount',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w600,
                  ),
            ),
          ),
          Text(
            _currencyFormat.format(
              amount.isFinite ? amount : 0,
            ),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  color:
                      AppColors.danger,
                  fontWeight:
                      FontWeight.w800,
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
            _isSaving ? null : _saveExpense,
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
            : Icon(
                widget.isEditMode
                    ? Icons.save_rounded
                    : Icons
                        .check_circle_outline_rounded,
              ),
        label: Text(
          _isSaving
              ? 'SAVING...'
              : widget.isEditMode
                  ? 'UPDATE EXPENSE'
                  : 'SAVE EXPENSE',
        ),
      ),
    );
  }

  Widget _buildForm() {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final isDesktop =
            constraints.maxWidth >= 900;

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1000,
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
                    _buildHeader(),
                    const SizedBox(height: 16),

                    _buildSectionCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            'Expense Details',
                            'Enter the basic expense information.',
                            Icons
                                .receipt_long_rounded,
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
                                      _buildCategoryField(),
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
                            _buildCategoryField(),
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
                                      _buildPaymentMethodField(),
                                ),
                                const SizedBox(
                                  width: 14,
                                ),
                                Expanded(
                                  child:
                                      _buildDateField(),
                                ),
                              ],
                            )
                          else ...[
                            _buildPaymentMethodField(),
                            const SizedBox(
                              height: 14,
                            ),
                            _buildDateField(),
                          ],
                          const SizedBox(
                            height: 16,
                          ),
                          _buildAmountPreview(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildSectionCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            'Additional Information',
                            'Optional details for better record keeping.',
                            Icons
                                .description_outlined,
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          _buildDescriptionField(),
                          const SizedBox(
                            height: 14,
                          ),
                          _buildNotesField(),
                          const SizedBox(
                            height: 14,
                          ),
                          _buildReceiptField(),
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
        title: Text(
          widget.isEditMode
              ? 'Edit Expense'
              : 'Add Expense',
          style: const TextStyle(
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
                            style: Theme.of(
                              context,
                            )
                                .textTheme
                                .titleMedium,
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          FilledButton.icon(
                            onPressed:
                                _loadBusiness,
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
                : _buildForm(),
      ),
    );
  }
}
