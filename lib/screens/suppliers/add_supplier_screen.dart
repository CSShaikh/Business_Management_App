import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/supplier_model.dart';
import '../../repositories/supplier_repository.dart';

class AddSupplierScreen extends StatefulWidget {
  final String businessId;
  final SupplierModel? supplier;

  const AddSupplierScreen({
    super.key,
    required this.businessId,
    this.supplier,
  });

  bool get isEditMode => supplier != null;

  @override
  State<AddSupplierScreen> createState() =>
      _AddSupplierScreenState();
}

class _AddSupplierScreenState
    extends State<AddSupplierScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final SupplierRepository _supplierRepository =
      SupplierRepository();

  late final TextEditingController _nameController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _gstNumberController;
  late final TextEditingController _notesController;

  bool _saving = false;

  bool get _isEditMode =>
      widget.supplier != null;

  @override
  void initState() {
    super.initState();

    final SupplierModel? supplier =
        widget.supplier;

    _nameController = TextEditingController(
      text: supplier?.name ?? '',
    );

    _contactPersonController =
        TextEditingController(
      text: supplier?.contactPerson ?? '',
    );

    _mobileController =
        TextEditingController(
      text: supplier?.mobile ?? '',
    );

    _emailController =
        TextEditingController(
      text: supplier?.email ?? '',
    );

    _addressController =
        TextEditingController(
      text: supplier?.address ?? '',
    );

    _gstNumberController =
        TextEditingController(
      text: supplier?.gstNumber ?? '',
    );

    _notesController =
        TextEditingController(
      text: supplier?.notes ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstNumberController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (_saving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String businessId =
        widget.businessId.trim();

    if (businessId.isEmpty) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
    });

    try {
      final DateTime now = DateTime.now();
      final SupplierModel? existingSupplier =
          widget.supplier;

      if (_isEditMode &&
          existingSupplier != null) {
        final SupplierModel updatedSupplier =
            SupplierModel(
          id: existingSupplier.id,
          businessId: existingSupplier.businessId,
          name: _nameController.text.trim(),
          contactPerson:
              _contactPersonController.text.trim(),
          mobile:
              _mobileController.text.trim(),
          email:
              _emailController.text.trim(),
          address:
              _addressController.text.trim(),
          gstNumber:
              _gstNumberController.text.trim(),
          notes:
              _notesController.text.trim(),
          createdAt:
              existingSupplier.createdAt,
          updatedAt: now,
        );

        await _supplierRepository
            .updateSupplier(
          updatedSupplier,
        );

        if (!mounted) {
          return;
        }

        _showMessage(
          'Supplier updated successfully.',
        );

        Navigator.pop(
          context,
          updatedSupplier,
        );
      } else {
        final String supplierId =
            _supplierRepository.firestore
                .collection('businesses')
                .doc(businessId)
                .collection('suppliers')
                .doc()
                .id;

        final SupplierModel newSupplier =
            SupplierModel(
          id: supplierId,
          businessId: businessId,
          name: _nameController.text.trim(),
          contactPerson:
              _contactPersonController.text.trim(),
          mobile:
              _mobileController.text.trim(),
          email:
              _emailController.text.trim(),
          address:
              _addressController.text.trim(),
          gstNumber:
              _gstNumberController.text.trim(),
          notes:
              _notesController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );

        await _supplierRepository
            .createSupplier(
          newSupplier,
        );

        if (!mounted) {
          return;
        }

        _showMessage(
          'Supplier added successfully.',
        );

        Navigator.pop(
          context,
          newSupplier,
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _isEditMode
            ? 'Unable to update supplier.'
            : 'Unable to add supplier.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEditMode
              ? 'Edit Supplier'
              : 'Add Supplier',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              final bool wide =
                  constraints.maxWidth >= 800;

              return SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  110,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(
                      maxWidth: 1000,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .stretch,
                      children: [
                        _buildPageHeader(
                          theme,
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        _buildBasicInformationCard(
                          theme,
                          wide,
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        _buildContactCard(
                          theme,
                          wide,
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        _buildBusinessDetailsCard(
                          theme,
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        _buildNotesCard(
                          theme,
                        ),
                        const SizedBox(
                          height: 24,
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

  Widget _buildPageHeader(
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          _isEditMode
              ? 'Update Supplier'
              : 'Create New Supplier',
          style: theme
              .textTheme
              .headlineSmall
              ?.copyWith(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        Text(
          _isEditMode
              ? 'Update supplier contact and business details.'
              : 'Add supplier details to manage your purchases and contacts.',
          style: theme
              .textTheme
              .bodyMedium
              ?.copyWith(
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInformationCard(
    ThemeData theme,
    bool wide,
  ) {
    return _sectionCard(
      theme,
      icon: Icons.person_outline_rounded,
      title: 'Basic Information',
      child: wide
          ? Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _textField(
                    controller:
                        _nameController,
                    label:
                        'Supplier Name',
                    hint:
                        'Enter supplier name',
                    icon:
                        Icons.store_outlined,
                    requiredField: true,
                    validator:
                        _validateName,
                  ),
                ),
                const SizedBox(
                  width: 16,
                ),
                Expanded(
                  child: _textField(
                    controller:
                        _contactPersonController,
                    label:
                        'Contact Person',
                    hint:
                        'Enter contact person name',
                    icon:
                        Icons.person_outline_rounded,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _textField(
                  controller:
                      _nameController,
                  label:
                      'Supplier Name',
                  hint:
                      'Enter supplier name',
                  icon:
                      Icons.store_outlined,
                  requiredField: true,
                  validator:
                      _validateName,
                ),
                const SizedBox(
                  height: 16,
                ),
                _textField(
                  controller:
                      _contactPersonController,
                  label:
                      'Contact Person',
                  hint:
                      'Enter contact person name',
                  icon:
                      Icons.person_outline_rounded,
                ),
              ],
            ),
    );
  }

  Widget _buildContactCard(
    ThemeData theme,
    bool wide,
  ) {
    return _sectionCard(
      theme,
      icon: Icons.contact_phone_outlined,
      title: 'Contact Information',
      child: wide
          ? Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _textField(
                    controller:
                        _mobileController,
                    label:
                        'Mobile Number',
                    hint:
                        'Enter mobile number',
                    icon:
                        Icons.phone_outlined,
                    keyboardType:
                        TextInputType.phone,
                    validator:
                        _validateMobile,
                  ),
                ),
                const SizedBox(
                  width: 16,
                ),
                Expanded(
                  child: _textField(
                    controller:
                        _emailController,
                    label:
                        'Email Address',
                    hint:
                        'Enter email address',
                    icon:
                        Icons.email_outlined,
                    keyboardType:
                        TextInputType.emailAddress,
                    validator:
                        _validateEmail,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _textField(
                  controller:
                      _mobileController,
                  label:
                      'Mobile Number',
                  hint:
                      'Enter mobile number',
                  icon:
                      Icons.phone_outlined,
                  keyboardType:
                      TextInputType.phone,
                  validator:
                      _validateMobile,
                ),
                const SizedBox(
                  height: 16,
                ),
                _textField(
                  controller:
                      _emailController,
                  label:
                      'Email Address',
                  hint:
                      'Enter email address',
                  icon:
                      Icons.email_outlined,
                  keyboardType:
                      TextInputType.emailAddress,
                  validator:
                      _validateEmail,
                ),
              ],
            ),
    );
  }

  Widget _buildBusinessDetailsCard(
    ThemeData theme,
  ) {
    return _sectionCard(
      theme,
      icon: Icons.business_outlined,
      title: 'Business Details',
      child: Column(
        children: [
          _textField(
            controller:
                _gstNumberController,
            label: 'GST Number',
            hint:
                'Enter GST number',
            icon:
                Icons.receipt_long_outlined,
            textCapitalization:
                TextCapitalization.characters,
            validator:
                _validateGst,
          ),
          const SizedBox(
            height: 16,
          ),
          _textField(
            controller:
                _addressController,
            label: 'Address',
            hint:
                'Enter supplier address',
            icon:
                Icons.location_on_outlined,
            maxLines: 3,
            textCapitalization:
                TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(
    ThemeData theme,
  ) {
    return _sectionCard(
      theme,
      icon: Icons.notes_outlined,
      title: 'Notes',
      child: _textField(
        controller:
            _notesController,
        label: 'Additional Notes',
        hint:
            'Add any additional supplier notes',
        icon:
            Icons.notes_outlined,
        maxLines: 4,
        textCapitalization:
            TextCapitalization.sentences,
      ),
    );
  }

  Widget _sectionCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
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
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.primary
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
                Text(
                  title,
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 18,
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController
        controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)?
        validator,
    TextInputType? keyboardType,
    TextCapitalization
        textCapitalization =
        TextCapitalization.none,
    int maxLines = 1,
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization:
          textCapitalization,
      maxLines: maxLines,
      validator: validator,
      enabled: !_saving,
      decoration: InputDecoration(
        labelText: requiredField
            ? '$label *'
            : label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed:
            _saving ? null : _saveSupplier,
        icon: _saving
            ? const SizedBox(
                width: 19,
                height: 19,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : Icon(
                _isEditMode
                    ? Icons.save_outlined
                    : Icons.add_rounded,
              ),
        label: Text(
          _saving
              ? 'Saving...'
              : _isEditMode
                  ? 'Update Supplier'
                  : 'Save Supplier',
        ),
      ),
    );
  }

  String? _validateName(
    String? value,
  ) {
    final String text =
        value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Supplier name is required.';
    }

    if (text.length < 2) {
      return 'Supplier name must be at least 2 characters.';
    }

    return null;
  }

  String? _validateMobile(
    String? value,
  ) {
    final String text =
        value?.trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    final String digits =
        text.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (digits.length < 10 ||
        digits.length > 15) {
      return 'Enter a valid mobile number.';
    }

    return null;
  }

  String? _validateEmail(
    String? value,
  ) {
    final String text =
        value?.trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    final bool valid = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(text);

    if (!valid) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _validateGst(
    String? value,
  ) {
    final String text =
        value?.trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    final String normalized =
        text.toUpperCase();

    if (normalized.length != 15) {
      return 'GST number must contain 15 characters.';
    }

    final bool valid = RegExp(
      r'^[0-9A-Z]{15}$',
    ).hasMatch(normalized);

    if (!valid) {
      return 'Enter a valid GST number.';
    }

    return null;
  }
}
