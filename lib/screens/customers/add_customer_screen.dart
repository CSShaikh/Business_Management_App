import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/customer_model.dart';
import '../../repositories/customer_repository.dart';

class AddCustomerScreen extends StatefulWidget {
  final String businessId;
  final CustomerModel? customer;

  const AddCustomerScreen({
    super.key,
    required this.businessId,
    this.customer,
  });

  bool get isEditMode => customer != null;

  @override
  State<AddCustomerScreen> createState() =>
      _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final CustomerRepository _customerRepository = CustomerRepository();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _gstController;
  late final TextEditingController _notesController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final customer = widget.customer;

    _nameController = TextEditingController(
      text: customer?.name ?? '',
    );

    _ownerNameController = TextEditingController(
      text: customer?.ownerName ?? '',
    );

    _mobileController = TextEditingController(
      text: customer?.mobile ?? '',
    );

    _emailController = TextEditingController(
      text: customer?.email ?? '',
    );

    _addressController = TextEditingController(
      text: customer?.address ?? '',
    );

    _gstController = TextEditingController(
      text: customer?.gstNumber ?? '',
    );

    _notesController = TextEditingController(
      text: customer?.notes ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final formState = _formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    final businessId = widget.businessId.trim();

    if (businessId.isEmpty) {
      _showMessage(
        'Business information is missing.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();

      if (widget.isEditMode) {
        await _updateCustomer(now);
      } else {
        await _createCustomer(now);
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        widget.isEditMode
            ? 'Customer updated successfully.'
            : 'Customer added successfully.',
      );

      await Future.delayed(
        const Duration(milliseconds: 400),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to save customer: ${_cleanError(e)}',
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

  Future<void> _createCustomer(DateTime now) async {
    final customer = CustomerModel(
      id: '',
      businessId: widget.businessId.trim(),
      name: _nameController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      mobile: _mobileController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      address: _addressController.text.trim(),
      gstNumber: _gstController.text.trim().toUpperCase(),
      notes: _notesController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await _customerRepository.createCustomer(customer);
  }

  Future<void> _updateCustomer(DateTime now) async {
    final existingCustomer = widget.customer;

    if (existingCustomer == null) {
      throw StateError('Customer information is missing.');
    }

    if (existingCustomer.id.trim().isEmpty) {
      throw StateError('Customer ID is missing.');
    }

    final existingBusinessId =
        existingCustomer.businessId.trim();

    final businessId = existingBusinessId.isNotEmpty
        ? existingBusinessId
        : widget.businessId.trim();

    if (businessId.isEmpty) {
      throw StateError('Business ID is missing.');
    }

    final updatedCustomer = CustomerModel(
      id: existingCustomer.id.trim(),
      businessId: businessId,
      name: _nameController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      mobile: _mobileController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      address: _addressController.text.trim(),
      gstNumber: _gstController.text.trim().toUpperCase(),
      notes: _notesController.text.trim(),
      createdAt: existingCustomer.createdAt,
      updatedAt: now,
    );

    await _customerRepository.updateCustomer(
      updatedCustomer,
    );
  }

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
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
          backgroundColor:
              isError ? AppColors.danger : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? 'Edit Customer'
              : 'Add Customer',
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1000,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 32 : 16,
                    vertical: 20,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _buildPageHeader(),
                        const SizedBox(height: 20),

                        _buildBasicInformationCard(
                          isWide,
                        ),
                        const SizedBox(height: 16),

                        _buildContactInformationCard(
                          isWide,
                        ),
                        const SizedBox(height: 16),

                        _buildBusinessInformationCard(
                          isWide,
                        ),
                        const SizedBox(height: 16),

                        _buildNotesCard(),
                        const SizedBox(height: 24),

                        _buildSaveButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.16,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditMode
                      ? 'Update Customer'
                      : 'Add New Customer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.isEditMode
                      ? 'Update customer information and contact details'
                      : 'Add a customer to manage sales and payments',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.82,
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

  Widget _buildBasicInformationCard(bool isWide) {
    return _FormCard(
      title: 'Basic Information',
      icon: Icons.person_outline_rounded,
      child: _responsiveFields(
        isWide,
        [
          _buildTextField(
            controller: _nameController,
            label: 'Hotel / Customer Name',
            hint: 'e.g. Taj Hotel',
            icon: Icons.business_outlined,
            required: true,
            validator: (value) {
              final name = value?.trim() ?? '';

              if (name.isEmpty) {
                return 'Please enter customer name';
              }

              if (name.length < 2) {
                return 'Name is too short';
              }

              if (name.length > 100) {
                return 'Name is too long';
              }

              return null;
            },
          ),
          _buildTextField(
            controller: _ownerNameController,
            label: 'Owner Name',
            hint: 'e.g. Rahul Sharma',
            icon: Icons.person_outline_rounded,
            maxLength: 100,
          ),
        ],
      ),
    );
  }

  Widget _buildContactInformationCard(bool isWide) {
    return _FormCard(
      title: 'Contact Information',
      icon: Icons.contact_phone_outlined,
      child: _responsiveFields(
        isWide,
        [
          _buildTextField(
            controller: _mobileController,
            label: 'Mobile Number',
            hint: 'Enter mobile number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            maxLength: 15,
            validator: (value) {
              final mobile = value?.trim() ?? '';

              if (mobile.isEmpty) {
                return null;
              }

              final digits = mobile.replaceAll(
                RegExp(r'\D'),
                '',
              );

              if (digits.length < 10 ||
                  digits.length > 15) {
                return 'Enter a valid mobile number';
              }

              return null;
            },
          ),
          _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'customer@example.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            maxLength: 150,
            validator: (value) {
              final email = value?.trim() ?? '';

              if (email.isEmpty) {
                return null;
              }

              final emailRegex = RegExp(
                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
              );

              if (!emailRegex.hasMatch(email)) {
                return 'Enter a valid email address';
              }

              return null;
            },
          ),
          _buildTextField(
            controller: _addressController,
            label: 'Address',
            hint: 'Enter complete address',
            icon: Icons.location_on_outlined,
            maxLines: 3,
            maxLength: 300,
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessInformationCard(bool isWide) {
    return _FormCard(
      title: 'Business Information',
      icon: Icons.receipt_long_outlined,
      child: _responsiveFields(
        isWide,
        [
          _buildTextField(
            controller: _gstController,
            label: 'GST Number',
            hint: 'Optional',
            icon: Icons.receipt_long_rounded,
            textCapitalization:
                TextCapitalization.characters,
            maxLength: 15,
            validator: (value) {
              final gst = value?.trim().toUpperCase() ?? '';

              if (gst.isEmpty) {
                return null;
              }

              if (gst.length != 15) {
                return 'GST number should contain 15 characters';
              }

              final gstRegex = RegExp(
                r'^[0-9A-Z]{15}$',
              );

              if (!gstRegex.hasMatch(gst)) {
                return 'Enter a valid GST number';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return _FormCard(
      title: 'Notes',
      icon: Icons.notes_rounded,
      child: _buildTextField(
        controller: _notesController,
        label: 'Additional Notes',
        hint:
            'Add any additional information about this customer',
        icon: Icons.notes_outlined,
        maxLines: 5,
        maxLength: 500,
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _saveCustomer,
        icon: _isSaving
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Icon(
                widget.isEditMode
                    ? Icons.save_rounded
                    : Icons.add_business_rounded,
              ),
        label: Text(
          _isSaving
              ? 'Saving...'
              : widget.isEditMode
                  ? 'Update Customer'
                  : 'Save Customer',
        ),
      ),
    );
  }

  Widget _responsiveFields(
    bool isWide,
    List<Widget> fields,
  ) {
    if (!isWide) {
      return Column(
        children: [
          for (int i = 0; i < fields.length; i++) ...[
            fields[i],
            if (i < fields.length - 1)
              const SizedBox(height: 16),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: fields.map((field) {
        final isSingleField = fields.length == 1;

        return SizedBox(
          width: isSingleField
              ? double.infinity
              : 450,
          child: field,
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization =
        TextCapitalization.none,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        prefixIcon: Icon(icon),
        counterText: maxLength != null ? null : '',
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _FormCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}