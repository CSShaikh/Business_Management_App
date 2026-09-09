import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/theme/app_colors.dart';
import '../../models/product_model.dart';
import '../../repositories/product_repository.dart';

class AddProductScreen extends StatefulWidget {
  final ProductModel? product;
  final String businessId;

  const AddProductScreen({
    super.key,
    required this.businessId,
    this.product,
  });

  bool get isEditMode => product != null;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minimumStockController = TextEditingController();

  final ProductRepository _productRepository = ProductRepository();

  String _selectedUnit = 'KG';

  bool _isActive = true;
  bool _isSaving = false;

  final List<String> _units = const [
    'KG',
    'Gram',
    'Liter',
    'Piece',
    'Box',
    'Packet',
    'Dozen',
    'Other',
  ];

  final List<String> _categories = const [
    'Spices',
    'Powder',
    'Grocery',
    'Food',
    'Beverages',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    final ProductModel? product = widget.product;

    if (product != null) {
      _nameController.text = product.name;
      _categoryController.text = product.category;

      _selectedUnit = product.unit;

      _purchasePriceController.text =
          product.purchasePrice.toStringAsFixed(2);

      _sellingPriceController.text =
          product.sellingPrice.toStringAsFixed(2);

      _stockController.text = product.currentStock.toString();
      _minimumStockController.text = product.minimumStock.toString();

      _isActive = product.isActive;

      if (!_units.contains(_selectedUnit)) {
        _selectedUnit = 'Other';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _minimumStockController.dispose();

    super.dispose();
  }

  double _parseDouble(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final String businessId = widget.businessId.trim();

    if (businessId.isEmpty) {
      _showMessage(
        'Business information is missing.',
        isError: true,
      );
      return;
    }

    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final DateTime now = DateTime.now();

      final String name = _nameController.text.trim();
      final String category = _categoryController.text.trim();

      final double purchasePrice = _parseDouble(
        _purchasePriceController.text,
      );

      final double sellingPrice = _parseDouble(
        _sellingPriceController.text,
      );

      /*
       * IMPORTANT:
       *
       * When editing an existing product, currentStock is intentionally
       * preserved from the existing product.
       *
       * Stock should be changed through:
       * - Purchase
       * - Sale
       * - Stock adjustment
       *
       * It should not be accidentally overwritten from the product edit form.
       */
      final double currentStock = widget.isEditMode
          ? widget.product!.currentStock
          : _parseDouble(
              _stockController.text,
            );

      final double minimumStock = _parseDouble(
        _minimumStockController.text,
      );

      if (purchasePrice < 0) {
        _showMessage(
          'Purchase price cannot be negative.',
          isError: true,
        );
        return;
      }

      if (sellingPrice < 0) {
        _showMessage(
          'Selling price cannot be negative.',
          isError: true,
        );
        return;
      }

      if (currentStock < 0) {
        _showMessage(
          'Current stock cannot be negative.',
          isError: true,
        );
        return;
      }

      if (minimumStock < 0) {
        _showMessage(
          'Minimum stock cannot be negative.',
          isError: true,
        );
        return;
      }

      if (widget.isEditMode) {
        final ProductModel oldProduct = widget.product!;

        final ProductModel updatedProduct = ProductModel(
          id: oldProduct.id,

          // Preserve original business ownership.
          businessId: oldProduct.businessId,

          name: name,
          category: category,
          unit: _selectedUnit,

          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,

          // NEVER overwrite stock while editing product details.
          currentStock: oldProduct.currentStock,

          minimumStock: minimumStock,
          isActive: _isActive,

          createdAt: oldProduct.createdAt,
          updatedAt: now,
        );

        await _productRepository.updateProduct(
          updatedProduct,
        );

        if (!mounted) {
          return;
        }

        _showMessage(
          'Product updated successfully.',
        );

        Navigator.pop(
          context,
          true,
        );
      } else {
        final ProductModel product = ProductModel(
          id: '',
          businessId: businessId,

          name: name,
          category: category,
          unit: _selectedUnit,

          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,

          currentStock: currentStock,
          minimumStock: minimumStock,

          isActive: _isActive,

          createdAt: now,
          updatedAt: now,
        );

        await _productRepository.createProduct(
          product,
        );

        if (!mounted) {
          return;
        }

        _showMessage(
          'Product added successfully.',
        );

        Navigator.pop(
          context,
          true,
        );
      }
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        e.message ?? 'Something went wrong.',
        isError: true,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to save product. Please try again.',
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
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? AppColors.danger
              : AppColors.success,
        ),
      );
  }

  Future<void> _confirmCancel() async {
    if (_isSaving) {
      return;
    }

    final bool hasData =
        _nameController.text.trim().isNotEmpty ||
        _categoryController.text.trim().isNotEmpty ||
        _purchasePriceController.text.trim().isNotEmpty ||
        _sellingPriceController.text.trim().isNotEmpty ||
        _stockController.text.trim().isNotEmpty ||
        _minimumStockController.text.trim().isNotEmpty;

    if (!hasData) {
      Navigator.pop(context);
      return;
    }

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Discard changes?',
          ),
          content: const Text(
            'Your entered product information will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Discard',
              ),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      Navigator.pop(context);
    }
  }

  String? _requiredValidator(
    String? value,
    String fieldName,
  ) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    return null;
  }

  String? _priceValidator(
    String? value,
    String fieldName,
  ) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    final double? number = double.tryParse(
      value.trim(),
    );

    if (number == null || !number.isFinite) {
      return 'Enter a valid number';
    }

    if (number < 0) {
      return '$fieldName cannot be negative';
    }

    return null;
  }

  String? _stockValidator(
    String? value,
    String fieldName,
  ) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    final double? number = double.tryParse(
      value.trim(),
    );

    if (number == null || !number.isFinite) {
      return 'Enter a valid number';
    }

    if (number < 0) {
      return '$fieldName cannot be negative';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.isEditMode;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Product' : 'Add Product',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          onPressed: _isSaving
              ? null
              : _confirmCancel,
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
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
                  constraints.maxWidth >= 900;

              final Widget content = Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildHeader(isEdit),
                  const SizedBox(height: 20),
                  _buildBasicInformationCard(),
                  const SizedBox(height: 16),
                  _buildPricingCard(),
                  const SizedBox(height: 16),
                  _buildStockCard(),
                  const SizedBox(height: 16),
                  _buildStatusCard(),
                  const SizedBox(height: 24),
                  _buildSaveButton(isEdit),
                  const SizedBox(height: 24),
                ],
              );

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 40 : 16,
                  vertical: 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1000,
                    ),
                    child: content,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEdit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(
                alpha: 0.10,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isEdit
                  ? Icons.edit_rounded
                  : Icons.inventory_2_rounded,
              color: AppColors.primary,
              size: 25,
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
                      ? 'Edit Product'
                      : 'Add New Product',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEdit
                      ? 'Update product details without changing stock.'
                      : 'Add a product to your inventory.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInformationCard() {
    return _sectionCard(
      title: 'Basic Information',
      icon: Icons.info_outline_rounded,
      children: [
        _textField(
          controller: _nameController,
          label: 'Product Name',
          hint: 'Enter product name',
          icon: Icons.inventory_2_outlined,
          validator: (value) {
            return _requiredValidator(
              value,
              'Product name',
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool stacked =
                constraints.maxWidth < 600;

            final Widget categoryField =
                _categoryField();

            final Widget unitField =
                _unitField();

            if (stacked) {
              return Column(
                children: [
                  categoryField,
                  const SizedBox(height: 16),
                  unitField,
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: categoryField,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: unitField,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _categoryField() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(
        text: _categoryController.text,
      ),
      optionsBuilder: (textEditingValue) {
        final String query =
            textEditingValue.text.trim().toLowerCase();

        if (query.isEmpty) {
          return _categories;
        }

        return _categories.where(
          (category) => category
              .toLowerCase()
              .contains(query),
        );
      },
      onSelected: (value) {
        _categoryController.text = value;
      },
      fieldViewBuilder: (
        context,
        controller,
        focusNode,
        onFieldSubmitted,
      ) {
        if (controller.text != _categoryController.text) {
          controller.text = _categoryController.text;
        }

        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: !_isSaving,
          validator: (value) {
            return _requiredValidator(
              value,
              'Category',
            );
          },
          onChanged: (value) {
            _categoryController.text = value;
          },
          decoration: const InputDecoration(
            labelText: 'Category',
            hintText: 'Select or enter category',
            prefixIcon: Icon(
              Icons.category_outlined,
            ),
          ),
        );
      },
      optionsViewBuilder: (
        context,
        onSelected,
        options,
      ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 450,
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                ),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (
                  context,
                  index,
                ) {
                  final String option =
                      options.elementAt(index);

                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.category_outlined,
                    ),
                    title: Text(option),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _unitField() {
    return DropdownButtonFormField<String>(
      initialValue: _units.contains(_selectedUnit)
          ? _selectedUnit
          : 'Other',
      decoration: const InputDecoration(
        labelText: 'Unit',
        hintText: 'Select unit',
        prefixIcon: Icon(
          Icons.straighten_outlined,
        ),
      ),
      items: _units.map(
        (unit) {
          return DropdownMenuItem<String>(
            value: unit,
            child: Text(unit),
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
                _selectedUnit = value;
              });
            },
    );
  }

  Widget _buildPricingCard() {
    return _sectionCard(
      title: 'Pricing',
      icon: Icons.payments_outlined,
      children: [
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool stacked =
                constraints.maxWidth < 600;

            final Widget purchaseField = _textField(
              controller: _purchasePriceController,
              label: 'Purchase Price',
              hint: '0.00',
              icon: Icons.shopping_cart_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                return _priceValidator(
                  value,
                  'Purchase price',
                );
              },
            );

            final Widget sellingField = _textField(
              controller: _sellingPriceController,
              label: 'Selling Price',
              hint: '0.00',
              icon: Icons.sell_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                return _priceValidator(
                  value,
                  'Selling price',
                );
              },
            );

            if (stacked) {
              return Column(
                children: [
                  purchaseField,
                  const SizedBox(height: 16),
                  sellingField,
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: purchaseField,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: sellingField,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _infoBanner(
          icon: Icons.lightbulb_outline_rounded,
          text:
              'Purchase price is used for cost and profit calculations. '
              'Selling price is used as the default sale rate.',
        ),
      ],
    );
  }

  Widget _buildStockCard() {
    return _sectionCard(
      title: 'Stock',
      icon: Icons.warehouse_outlined,
      children: [
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool stacked =
                constraints.maxWidth < 600;

            final Widget currentStockField = _textField(
              controller: _stockController,
              label: 'Current Stock',
              hint: '0',
              icon: Icons.inventory_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              readOnly: widget.isEditMode,
              validator: widget.isEditMode
                  ? null
                  : (value) {
                      return _stockValidator(
                        value,
                        'Current stock',
                      );
                    },
            );

            final Widget minimumStockField = _textField(
              controller: _minimumStockController,
              label: 'Minimum Stock',
              hint: '0',
              icon: Icons.warning_amber_rounded,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                return _stockValidator(
                  value,
                  'Minimum stock',
                );
              },
            );

            if (stacked) {
              return Column(
                children: [
                  currentStockField,
                  const SizedBox(height: 16),
                  minimumStockField,
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: currentStockField,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: minimumStockField,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _infoBanner(
          icon: Icons.sync_alt_rounded,
          text: widget.isEditMode
              ? 'Current stock is managed by purchase, sale and stock adjustment transactions. '
                  'Edit Minimum Stock below; use Inventory for stock adjustments.'
              : 'Opening stock can be entered when creating a product. After that, stock is managed through purchase, sale and stock adjustment transactions.',
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return _sectionCard(
      title: 'Product Status',
      icon: Icons.toggle_on_outlined,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Active Product',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            _isActive
                ? 'This product is available for sales.'
                : 'This product is hidden from active lists.',
            style: const TextStyle(
              color: AppColors.lightTextSecondary,
            ),
          ),
          value: _isActive,
          onChanged: _isSaving
              ? null
              : (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isEdit) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: _isSaving
            ? null
            : _saveProduct,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(
                isEdit
                    ? Icons.save_rounded
                    : Icons.add_rounded,
              ),
        label: Text(
          _isSaving
              ? 'Saving...'
              : isEdit
                  ? 'Update Product'
                  : 'Save Product',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: !_isSaving,
      readOnly: readOnly,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _infoBanner({
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(
          alpha: 0.07,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.info.withValues(
            alpha: 0.15,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: AppColors.info,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}