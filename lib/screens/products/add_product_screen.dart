import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/product_model.dart';
import '../../repositories/product_repository.dart';

class AddProductScreen extends StatefulWidget {
  final String businessId;
  final ProductModel? product;

  const AddProductScreen({
    super.key,
    required this.businessId,
    this.product,
  });

  bool get isEditing => product != null;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final ProductRepository _productRepository =
      ProductRepository();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _categoryController =
      TextEditingController();

  final TextEditingController _purchasePriceController =
      TextEditingController();

  final TextEditingController _sellingPriceController =
      TextEditingController();

  final TextEditingController _stockController =
      TextEditingController();

  final TextEditingController _minimumStockController =
      TextEditingController();

  String _selectedUnit = 'KG';

  bool _isActive = true;
  bool _isSaving = false;

  static const List<String> _units = [
    'KG',
    'Gram',
    'Liter',
    'Piece',
    'Box',
    'Packet',
    'Dozen',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    final ProductModel? product = widget.product;

    if (product != null) {
      _nameController.text = product.name;
      _categoryController.text = product.category;
      _purchasePriceController.text =
          _formatNumber(product.purchasePrice);
      _sellingPriceController.text =
          _formatNumber(product.sellingPrice);
      _stockController.text =
          _formatNumber(product.currentStock);
      _minimumStockController.text =
          _formatNumber(product.minimumStock);

      if (_units.contains(product.unit)) {
        _selectedUnit = product.unit;
      } else {
        _selectedUnit = 'Other';
      }

      _isActive = product.isActive;
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

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  double _parseDouble(String value) {
    return double.tryParse(
          value.trim(),
        ) ??
        0.0;
  }

  Future<void> _saveProduct() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String name =
        _nameController.text.trim();

    final String category =
        _categoryController.text.trim();

    final double purchasePrice =
        _parseDouble(
      _purchasePriceController.text,
    );

    final double sellingPrice =
        _parseDouble(
      _sellingPriceController.text,
    );

    final double currentStock =
        _parseDouble(
      _stockController.text,
    );

    final double minimumStock =
        _parseDouble(
      _minimumStockController.text,
    );

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isEditing) {
        final ProductModel oldProduct =
            widget.product!;

        final ProductModel updatedProduct =
            ProductModel(
          id: oldProduct.id,
          businessId: widget.businessId,
          name: name,
          category: category,
          unit: _selectedUnit,
          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,
          currentStock: currentStock,
          minimumStock: minimumStock,
          isActive: _isActive,
          createdAt: oldProduct.createdAt,
          updatedAt: DateTime.now(),
        );

        await _productRepository.updateProduct(
          updatedProduct,
        );
      } else {
        final ProductModel newProduct =
            ProductModel(
          id: '',
          businessId: widget.businessId,
          name: name,
          category: category,
          unit: _selectedUnit,
          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,
          currentStock: currentStock,
          minimumStock: minimumStock,
          isActive: _isActive,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _productRepository.createProduct(
          newProduct,
        );
      }

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

      _showError(
        'Unable to save product. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String? _requiredValidator(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'This field is required';
    }

    return null;
  }

  String? _numberValidator(
    String? value, {
    bool allowZero = true,
  }) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'This field is required';
    }

    final double? number =
        double.tryParse(value.trim());

    if (number == null) {
      return 'Enter a valid number';
    }

    if (number < 0) {
      return 'Cannot be negative';
    }

    if (!allowZero && number == 0) {
      return 'Value must be greater than 0';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing =
        widget.isEditing;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Edit Product'
              : 'Add Product',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool isWide =
                constraints.maxWidth >= 800;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal:
                    isWide ? 40 : 16,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 900,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _PageHeader(
                          isEditing: isEditing,
                        ),

                        const SizedBox(
                          height: 24,
                        ),

                        _SectionCard(
                          title: 'Basic Information',
                          icon: Icons.inventory_2_outlined,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller:
                                    _nameController,
                                label:
                                    'Product Name',
                                hint:
                                    'e.g. Ginger',
                                icon:
                                    Icons.inventory_2_outlined,
                                validator:
                                    _requiredValidator,
                                textCapitalization:
                                    TextCapitalization.words,
                              ),

                              const SizedBox(
                                height: 16,
                              ),

                              _buildTextField(
                                controller:
                                    _categoryController,
                                label:
                                    'Category',
                                hint:
                                    'e.g. Spices',
                                icon:
                                    Icons.category_outlined,
                                textCapitalization:
                                    TextCapitalization.words,
                              ),

                              const SizedBox(
                                height: 16,
                              ),

                              _buildUnitDropdown(),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        _SectionCard(
                          title: 'Pricing',
                          icon:
                              Icons.currency_rupee_rounded,
                          child: LayoutBuilder(
                            builder: (
                              context,
                              sectionConstraints,
                            ) {
                              final bool twoColumns =
                                  sectionConstraints
                                          .maxWidth >=
                                      550;

                              if (!twoColumns) {
                                return Column(
                                  children: [
                                    _buildNumberField(
                                      controller:
                                          _purchasePriceController,
                                      label:
                                          'Purchase Price',
                                      hint:
                                          '0.00',
                                    ),
                                    const SizedBox(
                                      height: 16,
                                    ),
                                    _buildNumberField(
                                      controller:
                                          _sellingPriceController,
                                      label:
                                          'Selling Price',
                                      hint:
                                          '0.00',
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(
                                    child:
                                        _buildNumberField(
                                      controller:
                                          _purchasePriceController,
                                      label:
                                          'Purchase Price',
                                      hint:
                                          '0.00',
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child:
                                        _buildNumberField(
                                      controller:
                                          _sellingPriceController,
                                      label:
                                          'Selling Price',
                                      hint:
                                          '0.00',
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        _SectionCard(
                          title: 'Inventory',
                          icon:
                              Icons.warehouse_outlined,
                          child: LayoutBuilder(
                            builder: (
                              context,
                              sectionConstraints,
                            ) {
                              final bool twoColumns =
                                  sectionConstraints
                                          .maxWidth >=
                                      550;

                              if (!twoColumns) {
                                return Column(
                                  children: [
                                    _buildNumberField(
                                      controller:
                                          _stockController,
                                      label:
                                          'Current Stock',
                                      hint:
                                          '0',
                                    ),
                                    const SizedBox(
                                      height: 16,
                                    ),
                                    _buildNumberField(
                                      controller:
                                          _minimumStockController,
                                      label:
                                          'Minimum Stock',
                                      hint:
                                          '0',
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(
                                    child:
                                        _buildNumberField(
                                      controller:
                                          _stockController,
                                      label:
                                          'Current Stock',
                                      hint:
                                          '0',
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child:
                                        _buildNumberField(
                                      controller:
                                          _minimumStockController,
                                      label:
                                          'Minimum Stock',
                                      hint:
                                          '0',
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        _SectionCard(
                          title: 'Product Status',
                          icon:
                              Icons.toggle_on_outlined,
                          child: SwitchListTile(
                            contentPadding:
                                EdgeInsets.zero,
                            title: const Text(
                              'Active Product',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              _isActive
                                  ? 'Product is available for sales.'
                                  : 'Product is currently inactive.',
                              style: TextStyle(
                                color:
                                    Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                            ),
                            value: _isActive,
                            onChanged:
                                _isSaving
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _isActive =
                                              value;
                                        });
                                      },
                          ),
                        ),

                        const SizedBox(
                          height: 28,
                        ),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed:
                                _isSaving
                                    ? null
                                    : _saveProduct,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2.2,
                                      color:
                                          Colors.white,
                                    ),
                                  )
                                : Icon(
                                    isEditing
                                        ? Icons
                                            .save_outlined
                                        : Icons
                                            .add_rounded,
                                  ),
                            label: Text(
                              _isSaving
                                  ? 'Saving...'
                                  : isEditing
                                      ? 'Update Product'
                                      : 'Save Product',
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed:
                                _isSaving
                                    ? null
                                    : () {
                                        Navigator.pop(
                                          context,
                                        );
                                      },
                            child: const Text(
                              'Cancel',
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 24,
                        ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization =
        TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isSaving,
      textCapitalization: textCapitalization,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isSaving,
      keyboardType:
          const TextInputType.numberWithOptions(
        decimal: true,
      ),
      validator: (value) {
        return _numberValidator(value);
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(
          Icons.currency_rupee_rounded,
        ),
      ),
    );
  }

  Widget _buildUnitDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedUnit,
      decoration: const InputDecoration(
        labelText: 'Unit',
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
}

// ============================================================
// PAGE HEADER
// ============================================================

class _PageHeader extends StatelessWidget {
  final bool isEditing;

  const _PageHeader({
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(
              alpha: 0.12,
            ),
            AppColors.secondary.withValues(
              alpha: 0.08,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(
            alpha: 0.15,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary
                  .withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing
                      ? 'Edit Product'
                      : 'Add New Product',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  isEditing
                      ? 'Update product information and inventory details.'
                      : 'Add product details, pricing and stock information.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SECTION CARD
// ============================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary
                        .withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w800,
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
}