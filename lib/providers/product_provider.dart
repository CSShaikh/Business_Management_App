import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/product_model.dart';
import '../repositories/product_repository.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider({
    ProductRepository? repository,
  }) : _repository = repository ?? ProductRepository();

  final ProductRepository _repository;

  // ===========================================================================
  // STATE
  // ===========================================================================

  List<ProductModel> _products = <ProductModel>[];

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;

  StreamSubscription<List<ProductModel>>? _productsSubscription;

  String _businessId = '';

  // ===========================================================================
  // GETTERS
  // ===========================================================================

  List<ProductModel> get products =>
      List<ProductModel>.unmodifiable(_products);

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get hasProducts => _products.isNotEmpty;

  bool get isEmpty => _products.isEmpty;

  String? get errorMessage => _errorMessage;

  String get businessId => _businessId;

  int get productCount => _products.length;

  int get activeProductCount =>
      _products.where((ProductModel product) => product.isActive).length;

  int get inactiveProductCount =>
      _products.where((ProductModel product) => !product.isActive).length;

  List<ProductModel> get activeProducts => _products
      .where(
        (ProductModel product) => product.isActive,
      )
      .toList(growable: false);

  List<ProductModel> get inactiveProducts => _products
      .where(
        (ProductModel product) => !product.isActive,
      )
      .toList(growable: false);

  List<ProductModel> get lowStockProducts => _products
      .where(
        (ProductModel product) =>
            product.currentStock <= product.minimumStock,
      )
      .toList(growable: false);

  int get lowStockCount => lowStockProducts.length;

  double get totalStockValue {
    double total = 0;

    for (final ProductModel product in _products) {
      total += product.currentStock * product.purchasePrice;
    }

    return total;
  }

  double get totalPotentialSalesValue {
    double total = 0;

    for (final ProductModel product in _products) {
      total += product.currentStock * product.sellingPrice;
    }

    return total;
  }

  // ===========================================================================
  // BUSINESS ID
  // ===========================================================================

  void setBusinessId(String businessId) {
    final String normalizedId = businessId.trim();

    if (_businessId == normalizedId) {
      return;
    }

    _businessId = normalizedId;

    _productsSubscription?.cancel();
    _productsSubscription = null;

    _products = <ProductModel>[];

    _clearError();

    notifyListeners();
  }

  // ===========================================================================
  // LOAD PRODUCTS
  // ===========================================================================

  Future<List<ProductModel>> loadProducts([
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return <ProductModel>[];
    }

    _businessId = id;

    if (_isLoading) {
      return products;
    }

    _setLoading(true);
    _clearError();

    try {
      final List<ProductModel> loadedProducts =
          await _repository.getProducts(id);

      _products = loadedProducts;

      return products;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to load products.',
        ),
      );

      return <ProductModel>[];
    } finally {
      _setLoading(false);
    }
  }

  // ===========================================================================
  // REAL-TIME PRODUCT LISTENER
  // ===========================================================================

  void watchProducts([
    String? businessId,
  ]) {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return;
    }

    _businessId = id;

    _productsSubscription?.cancel();

    _clearError();

    _productsSubscription = _repository
        .watchProducts(id)
        .listen(
      (List<ProductModel> updatedProducts) {
        _products = updatedProducts;
        notifyListeners();
      },
      onError: (Object error) {
        _setError(
          _formatError(
            error,
            fallback: 'Unable to listen for product updates.',
          ),
        );
      },
    );
  }

  // ===========================================================================
  // START REAL-TIME WATCHING
  // ===========================================================================

  Future<void> loadAndWatchProducts([
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return;
    }

    _businessId = id;

    await loadProducts(id);

    if (_errorMessage == null) {
      watchProducts(id);
    }
  }

  // ===========================================================================
  // GET SINGLE PRODUCT
  // ===========================================================================

  Future<ProductModel?> getProduct(
    String productId, [
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String normalizedProductId =
        productId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return null;
    }

    if (normalizedProductId.isEmpty) {
      _setError('Product ID is required.');
      return null;
    }

    try {
      return await _repository.getProduct(
        id,
        normalizedProductId,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to load product.',
        ),
      );

      return null;
    }
  }

  // ===========================================================================
  // CREATE PRODUCT
  // ===========================================================================

  Future<ProductModel?> createProduct(
    ProductModel product,
  ) async {
    final String id = product.businessId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return null;
    }

    if (product.name.trim().isEmpty) {
      _setError('Product name is required.');
      return null;
    }

    _setSaving(true);
    _clearError();

    try {
      final ProductModel createdProduct =
          await _repository.createProduct(product);

      _businessId = id;

      _upsertLocalProduct(createdProduct);

      return createdProduct;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to create product.',
        ),
      );

      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ===========================================================================
  // UPDATE PRODUCT
  // ===========================================================================

  Future<bool> updateProduct(
    ProductModel product,
  ) async {
    final String id = product.businessId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return false;
    }

    if (product.id.trim().isEmpty) {
      _setError('Product ID is required.');
      return false;
    }

    if (product.name.trim().isEmpty) {
      _setError('Product name is required.');
      return false;
    }

    _setSaving(true);
    _clearError();

    try {
      await _repository.updateProduct(product);

      final ProductModel? updatedProduct =
          await _repository.getProduct(
        id,
        product.id,
      );

      if (updatedProduct != null) {
        _upsertLocalProduct(updatedProduct);
      } else {
        await loadProducts(id);
      }

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to update product.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ===========================================================================
  // DELETE PRODUCT
  // ===========================================================================

  Future<bool> deleteProduct(
    String productId, [
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String normalizedProductId =
        productId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return false;
    }

    if (normalizedProductId.isEmpty) {
      _setError('Product ID is required.');
      return false;
    }

    _setSaving(true);
    _clearError();

    try {
      await _repository.deleteProduct(
        id,
        normalizedProductId,
      );

      _products.removeWhere(
        (ProductModel product) =>
            product.id == normalizedProductId,
      );

      notifyListeners();

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to delete product.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ===========================================================================
  // ACTIVATE / DEACTIVATE PRODUCT
  // ===========================================================================

  Future<bool> setProductStatus(
    String productId,
    bool isActive, [
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String normalizedProductId =
        productId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return false;
    }

    if (normalizedProductId.isEmpty) {
      _setError('Product ID is required.');
      return false;
    }

    _setSaving(true);
    _clearError();

    try {
      await _repository.setProductStatus(
        id,
        normalizedProductId,
        isActive,
      );

      final int index = _products.indexWhere(
        (ProductModel product) =>
            product.id == normalizedProductId,
      );

      if (index != -1) {
        final ProductModel product = _products[index];

        _products[index] = ProductModel(
          id: product.id,
          businessId: product.businessId,
          name: product.name,
          category: product.category,
          unit: product.unit,
          purchasePrice: product.purchasePrice,
          sellingPrice: product.sellingPrice,
          currentStock: product.currentStock,
          minimumStock: product.minimumStock,
          isActive: isActive,
          createdAt: product.createdAt,
          updatedAt: DateTime.now(),
        );

        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to update product status.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ===========================================================================
  // UPDATE STOCK
  // ===========================================================================

  Future<bool> updateStock(
    String productId,
    double newStock, [
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String normalizedProductId =
        productId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return false;
    }

    if (normalizedProductId.isEmpty) {
      _setError('Product ID is required.');
      return false;
    }

    if (!newStock.isFinite || newStock < 0) {
      _setError(
        'Stock must be greater than or equal to zero.',
      );
      return false;
    }

    _setSaving(true);
    _clearError();

    try {
      await _repository.updateStock(
        id,
        normalizedProductId,
        newStock,
      );

      final int index = _products.indexWhere(
        (ProductModel product) =>
            product.id == normalizedProductId,
      );

      if (index != -1) {
        final ProductModel product = _products[index];

        _products[index] = ProductModel(
          id: product.id,
          businessId: product.businessId,
          name: product.name,
          category: product.category,
          unit: product.unit,
          purchasePrice: product.purchasePrice,
          sellingPrice: product.sellingPrice,
          currentStock: newStock,
          minimumStock: product.minimumStock,
          isActive: product.isActive,
          createdAt: product.createdAt,
          updatedAt: DateTime.now(),
        );

        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to update product stock.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ===========================================================================
  // SEARCH PRODUCTS
  // ===========================================================================

  Future<List<ProductModel>> searchProducts(
    String query, [
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return <ProductModel>[];
    }

    try {
      return await _repository.searchProducts(
        id,
        query,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to search products.',
        ),
      );

      return <ProductModel>[];
    }
  }

  // ===========================================================================
  // GET ACTIVE PRODUCTS FROM FIRESTORE
  // ===========================================================================

  Future<List<ProductModel>> getActiveProducts([
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return <ProductModel>[];
    }

    try {
      return await _repository.getActiveProducts(id);
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to load active products.',
        ),
      );

      return <ProductModel>[];
    }
  }

  // ===========================================================================
  // GET LOW STOCK PRODUCTS FROM FIRESTORE
  // ===========================================================================

  Future<List<ProductModel>> getLowStockProducts([
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return <ProductModel>[];
    }

    try {
      return await _repository.getLowStockProducts(id);
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to load low stock products.',
        ),
      );

      return <ProductModel>[];
    }
  }

  // ===========================================================================
  // LOCAL FILTERING
  // ===========================================================================

  List<ProductModel> filterProducts(
    String query,
  ) {
    final String searchText =
        query.trim().toLowerCase();

    if (searchText.isEmpty) {
      return products;
    }

    return _products
        .where(
          (ProductModel product) {
            return product.name
                    .toLowerCase()
                    .contains(searchText) ||
                product.category
                    .toLowerCase()
                    .contains(searchText) ||
                product.unit
                    .toLowerCase()
                    .contains(searchText);
          },
        )
        .toList(growable: false);
  }

  // ===========================================================================
  // FIND PRODUCT LOCALLY
  // ===========================================================================

  ProductModel? findProductById(
    String productId,
  ) {
    final String id = productId.trim();

    if (id.isEmpty) {
      return null;
    }

    for (final ProductModel product in _products) {
      if (product.id == id) {
        return product;
      }
    }

    return null;
  }

  // ===========================================================================
  // CLEAR PRODUCTS
  // ===========================================================================

  void clearProducts() {
    _products = <ProductModel>[];
    notifyListeners();
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<List<ProductModel>> refresh() {
    return loadProducts();
  }

  // ===========================================================================
  // ERROR HANDLING
  // ===========================================================================

  void clearError() {
    _clearError();
  }

  void _clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  // ===========================================================================
  // LOADING / SAVING STATE
  // ===========================================================================

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  void _setSaving(bool value) {
    if (_isSaving == value) {
      return;
    }

    _isSaving = value;
    notifyListeners();
  }

  // ===========================================================================
  // LOCAL UPSERT
  // ===========================================================================

  void _upsertLocalProduct(
    ProductModel product,
  ) {
    final int index = _products.indexWhere(
      (ProductModel existingProduct) =>
          existingProduct.id == product.id,
    );

    if (index == -1) {
      _products = <ProductModel>[
        ..._products,
        product,
      ];
    } else {
      final List<ProductModel> updatedProducts =
          List<ProductModel>.from(_products);

      updatedProducts[index] = product;

      _products = updatedProducts;
    }

    notifyListeners();
  }

  // ===========================================================================
  // ERROR FORMATTER
  // ===========================================================================

  String _formatError(
    Object error, {
    required String fallback,
  }) {
    final String message =
        error.toString().trim();

    if (message.isEmpty) {
      return fallback;
    }

    if (message.startsWith('Exception:')) {
      final String cleaned =
          message.replaceFirst(
        'Exception:',
        '',
      ).trim();

      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    return message;
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _productsSubscription?.cancel();
    super.dispose();
  }
}