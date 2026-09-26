import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';
import 'base_repository.dart';

class ProductRepository extends BaseRepository {
  ProductRepository({super.firestore});

  // ---------------------------------------------------------------------------
  // Collection Reference
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _products(String businessId) {
    return firestore
        .collection('businesses')
        .doc(businessId)
        .collection('products');
  }

  // ---------------------------------------------------------------------------
  // Create Product
  // ---------------------------------------------------------------------------

  Future<ProductModel> createProduct(ProductModel product) async {
    final String businessId = product.businessId.trim();

    if (businessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty.');
    }

    final String name = product.name.trim();

    if (name.isEmpty) {
      throw ArgumentError('Product name cannot be empty.');
    }

    _validateNumericValues(
      purchasePrice: product.purchasePrice,
      sellingPrice: product.sellingPrice,
      currentStock: product.currentStock,
      minimumStock: product.minimumStock,
    );

    final CollectionReference<Map<String, dynamic>> products = _products(
      businessId,
    );

    final DocumentReference<Map<String, dynamic>> document =
        product.id.trim().isEmpty
        ? products.doc()
        : products.doc(product.id.trim());

    final DateTime now = DateTime.now();

    final ProductModel productToSave = ProductModel(
      id: document.id,
      businessId: businessId,
      name: name,
      category: product.category.trim(),
      unit: product.unit.trim(),
      purchasePrice: product.purchasePrice,
      sellingPrice: product.sellingPrice,
      currentStock: product.currentStock,
      minimumStock: product.minimumStock,
      isActive: product.isActive,
      supplierId: product.supplierId.trim(),
      supplierName: product.supplierName.trim(),
      createdAt: product.createdAt,
      updatedAt: now,
    );

    await document.set(_toMap(productToSave));

    return productToSave;
  }

  // ---------------------------------------------------------------------------
  // Get Single Product
  // ---------------------------------------------------------------------------

  Future<ProductModel?> getProduct(String businessId, String productId) async {
    final String normalizedBusinessId = businessId.trim();
    final String normalizedProductId = productId.trim();

    if (normalizedBusinessId.isEmpty || normalizedProductId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _products(
      normalizedBusinessId,
    ).doc(normalizedProductId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return _fromMap(snapshot.data()!, snapshot.id, normalizedBusinessId);
  }

  // ---------------------------------------------------------------------------
  // Get All Products
  // ---------------------------------------------------------------------------

  Future<List<ProductModel>> getProducts(String businessId) async {
    final String normalizedBusinessId = businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _products(
      normalizedBusinessId,
    ).orderBy('name').get();

    return snapshot.docs
        .map(
          (document) =>
              _fromMap(document.data(), document.id, normalizedBusinessId),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Watch Products - Real Time
  // ---------------------------------------------------------------------------

  Stream<List<ProductModel>> watchProducts(String businessId) {
    final String normalizedBusinessId = businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      return const Stream<List<ProductModel>>.empty();
    }

    return _products(normalizedBusinessId).orderBy('name').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map(
            (document) =>
                _fromMap(document.data(), document.id, normalizedBusinessId),
          )
          .toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Update Product
  //
  // Current stock is now editable from AddProductScreen in edit mode.
  //
  // The incoming ProductModel.currentStock is intentionally saved so the
  // user can directly increase or decrease the product stock from the
  // product edit screen.
  // ---------------------------------------------------------------------------

  Future<void> updateProduct(ProductModel product) async {
    final String businessId = product.businessId.trim();
    final String productId = product.id.trim();
    final String name = product.name.trim();

    if (businessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty.');
    }

    if (productId.isEmpty) {
      throw ArgumentError('Product ID cannot be empty.');
    }

    if (name.isEmpty) {
      throw ArgumentError('Product name cannot be empty.');
    }

    _validateNumericValues(
      purchasePrice: product.purchasePrice,
      sellingPrice: product.sellingPrice,
      currentStock: product.currentStock,
      minimumStock: product.minimumStock,
    );

    final DocumentReference<Map<String, dynamic>> document = _products(
      businessId,
    ).doc(productId);

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await document
        .get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Product not found.');
    }

    final ProductModel existingProduct = _fromMap(
      snapshot.data()!,
      snapshot.id,
      businessId,
    );

    final ProductModel productToUpdate = ProductModel(
      id: existingProduct.id,
      businessId: existingProduct.businessId,

      name: name,
      category: product.category.trim(),
      unit: product.unit.trim(),

      purchasePrice: product.purchasePrice,
      sellingPrice: product.sellingPrice,

      // Allow current stock to be changed during product editing.
      currentStock: product.currentStock,

      minimumStock: product.minimumStock,
      isActive: product.isActive,
      supplierId: product.supplierId.trim().isEmpty ? existingProduct.supplierId : product.supplierId.trim(),
      supplierName: product.supplierName.trim().isEmpty ? existingProduct.supplierName : product.supplierName.trim(),

      // Preserve original creation timestamp.
      createdAt: existingProduct.createdAt,

      updatedAt: DateTime.now(),
    );

    await document.update(_toMap(productToUpdate));
  }

  // ---------------------------------------------------------------------------
  // Update Purchase Price
  //
  // Purchase transactions update the product's latest purchase rate without
  // overwriting any other product fields. This keeps inventory stock changes
  // and product master data in sync while allowing the product listener to
  // refresh the Products screen immediately.
  // ---------------------------------------------------------------------------

  Future<void> updatePurchasePrice({
    required String businessId,
    required String productId,
    required double purchasePrice,
  }) async {
    final String normalizedBusinessId = businessId.trim();
    final String normalizedProductId = productId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty.');
    }

    if (normalizedProductId.isEmpty) {
      throw ArgumentError('Product ID cannot be empty.');
    }

    if (!purchasePrice.isFinite || purchasePrice < 0) {
      throw ArgumentError(
        'Purchase price must be a finite non-negative value.',
      );
    }

    final DocumentReference<Map<String, dynamic>> document = _products(
      normalizedBusinessId,
    ).doc(normalizedProductId);

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await document
        .get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Product not found.');
    }

    final Map<String, dynamic> data = snapshot.data()!;
    final String storedBusinessId = (data['businessId'] ?? normalizedBusinessId)
        .toString()
        .trim();

    if (storedBusinessId != normalizedBusinessId) {
      throw StateError('Product does not belong to this business.');
    }

    await document.update({
      'purchasePrice': purchasePrice,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ---------------------------------------------------------------------------
  // SUPPLIER-SPECIFIC PRODUCT VARIANT
  // ---------------------------------------------------------------------------

  Future<ProductModel?> findSupplierVariant({
    required String businessId,
    required String productName,
    required String supplierId,
  }) async {
    final String id = businessId.trim();
    final String name = productName.trim().toLowerCase();
    final String supplier = supplierId.trim();
    if (id.isEmpty || name.isEmpty || supplier.isEmpty) return null;

    final List<ProductModel> products = await getProducts(id);
    for (final ProductModel product in products) {
      if (product.name.trim().toLowerCase() == name &&
          product.supplierId.trim() == supplier) {
        return product;
      }
    }
    return null;
  }

  /// Assigns a supplier to a legacy/direct product that currently has no
  /// supplier. This lets the first purchase reuse the existing product
  /// instead of creating a duplicate product document.
  Future<ProductModel> assignSupplierToProduct({
    required String businessId,
    required String productId,
    required String supplierId,
    required String supplierName,
  }) async {
    final String normalizedBusinessId = businessId.trim();
    final String normalizedProductId = productId.trim();
    final String normalizedSupplierId = supplierId.trim();
    final String normalizedSupplierName = supplierName.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty.');
    }
    if (normalizedProductId.isEmpty) {
      throw ArgumentError('Product ID cannot be empty.');
    }
    if (normalizedSupplierId.isEmpty) {
      throw ArgumentError('Supplier ID cannot be empty.');
    }

    final DocumentReference<Map<String, dynamic>> document = _products(
      normalizedBusinessId,
    ).doc(normalizedProductId);

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Product not found.');
    }

    final ProductModel existingProduct = _fromMap(
      snapshot.data()!,
      snapshot.id,
      normalizedBusinessId,
    );

    // Never overwrite an already supplier-specific product with another
    // supplier. Such a purchase must use/create a separate variant.
    if (existingProduct.supplierId.trim().isNotEmpty &&
        existingProduct.supplierId.trim() != normalizedSupplierId) {
      throw StateError('Product is already assigned to another supplier.');
    }

    await document.update({
      'supplierId': normalizedSupplierId,
      'supplierName': normalizedSupplierName,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return ProductModel(
      id: existingProduct.id,
      businessId: existingProduct.businessId,
      name: existingProduct.name,
      category: existingProduct.category,
      unit: existingProduct.unit,
      purchasePrice: existingProduct.purchasePrice,
      sellingPrice: existingProduct.sellingPrice,
      currentStock: existingProduct.currentStock,
      minimumStock: existingProduct.minimumStock,
      isActive: existingProduct.isActive,
      supplierId: normalizedSupplierId,
      supplierName: normalizedSupplierName,
      createdAt: existingProduct.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<ProductModel> createSupplierVariant({
    required ProductModel baseProduct,
    required String supplierId,
    required String supplierName,
    required double purchasePrice,
  }) async {
    final DateTime now = DateTime.now();
    return createProduct(
      ProductModel(
        id: '',
        businessId: baseProduct.businessId,
        name: baseProduct.name,
        category: baseProduct.category,
        unit: baseProduct.unit,
        purchasePrice: purchasePrice,
        sellingPrice: baseProduct.sellingPrice,
        currentStock: 0,
        minimumStock: baseProduct.minimumStock,
        isActive: true,
        supplierId: supplierId.trim(),
        supplierName: supplierName.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete Product
  // ---------------------------------------------------------------------------

  Future<void> deleteProduct(String businessId, String productId) async {
    final String normalizedBusinessId = businessId.trim();
    final String normalizedProductId = productId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty.');
    }

    if (normalizedProductId.isEmpty) {
      throw ArgumentError('Product ID cannot be empty.');
    }

    await _products(normalizedBusinessId).doc(normalizedProductId).delete();
  }

  // ---------------------------------------------------------------------------
  // Activate / Deactivate Product
  // ---------------------------------------------------------------------------

  Future<void> setProductStatus(
    String businessId,
    String productId,
    bool isActive,
  ) async {
    final String normalizedBusinessId = businessId.trim();
    final String normalizedProductId = productId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty.');
    }

    if (normalizedProductId.isEmpty) {
      throw ArgumentError('Product ID cannot be empty.');
    }

    await _products(normalizedBusinessId).doc(normalizedProductId).update({
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ---------------------------------------------------------------------------
  // Update Stock
  //
  // This method remains available for dedicated stock operations.
  //
  // It directly updates currentStock. For normal purchase/sale flows,
  // StockRepository should still be preferred because those flows also
  // maintain stock transaction history.
  // ---------------------------------------------------------------------------

  Future<void> updateStock(
    String businessId,
    String productId,
    double newStock,
  ) async {
    final String normalizedBusinessId = businessId.trim();
    final String normalizedProductId = productId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty.');
    }

    if (normalizedProductId.isEmpty) {
      throw ArgumentError('Product ID cannot be empty.');
    }

    if (!newStock.isFinite || newStock < 0) {
      throw ArgumentError(
        'Stock must be a finite number greater than or equal to zero.',
      );
    }

    await _products(normalizedBusinessId).doc(normalizedProductId).update({
      'currentStock': newStock,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ---------------------------------------------------------------------------
  // Search Products
  //
  // Firestore does not provide simple contains-search.
  // So for MVP we load products and filter them locally.
  // ---------------------------------------------------------------------------

  Future<List<ProductModel>> searchProducts(
    String businessId,
    String query,
  ) async {
    final List<ProductModel> products = await getProducts(businessId);

    final String searchText = query.trim().toLowerCase();

    if (searchText.isEmpty) {
      return products;
    }

    return products.where((product) {
      return product.name.toLowerCase().contains(searchText) ||
          product.category.toLowerCase().contains(searchText) ||
          product.unit.toLowerCase().contains(searchText);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Get Active Products
  // ---------------------------------------------------------------------------

  Future<List<ProductModel>> getActiveProducts(String businessId) async {
    final List<ProductModel> products = await getProducts(businessId);

    return products.where((product) => product.isActive).toList();
  }

  // ---------------------------------------------------------------------------
  // Get Low Stock Products
  // ---------------------------------------------------------------------------

  Future<List<ProductModel>> getLowStockProducts(String businessId) async {
    final List<ProductModel> products = await getProducts(businessId);

    return products
        .where((product) => product.currentStock <= product.minimumStock)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Convert ProductModel -> Firestore Map
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _toMap(ProductModel product) {
    return {
      'id': product.id,
      'businessId': product.businessId,
      'name': product.name,
      'category': product.category,
      'unit': product.unit,
      'purchasePrice': product.purchasePrice,
      'sellingPrice': product.sellingPrice,
      'currentStock': product.currentStock,
      'minimumStock': product.minimumStock,
      'isActive': product.isActive,
      'supplierId': product.supplierId,
      'supplierName': product.supplierName,
      'createdAt': Timestamp.fromDate(product.createdAt),
      'updatedAt': Timestamp.fromDate(product.updatedAt),
    };
  }

  // ---------------------------------------------------------------------------
  // Convert Firestore Map -> ProductModel
  // ---------------------------------------------------------------------------

  ProductModel _fromMap(
    Map<String, dynamic> data,
    String documentId,
    String businessId,
  ) {
    return ProductModel(
      id: data['id'] as String? ?? documentId,
      businessId: data['businessId'] as String? ?? businessId,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      unit: data['unit'] as String? ?? '',
      purchasePrice: _toDouble(data['purchasePrice']),
      sellingPrice: _toDouble(data['sellingPrice']),
      currentStock: _toDouble(data['currentStock']),
      minimumStock: _toDouble(data['minimumStock']),
      isActive: data['isActive'] as bool? ?? true,
      supplierId: data['supplierId']?.toString() ?? '',
      supplierName: data['supplierName']?.toString() ?? '',
      createdAt: dateFromFirestore(data['createdAt']),
      updatedAt: dateFromFirestore(data['updatedAt']),
    );
  }

  // ---------------------------------------------------------------------------
  // Validate Numeric Product Values
  // ---------------------------------------------------------------------------

  void _validateNumericValues({
    required double purchasePrice,
    required double sellingPrice,
    required double currentStock,
    required double minimumStock,
  }) {
    if (!purchasePrice.isFinite || purchasePrice < 0) {
      throw ArgumentError(
        'Purchase price must be a finite number greater than or equal to zero.',
      );
    }

    if (!sellingPrice.isFinite || sellingPrice < 0) {
      throw ArgumentError(
        'Selling price must be a finite number greater than or equal to zero.',
      );
    }

    if (!currentStock.isFinite || currentStock < 0) {
      throw ArgumentError(
        'Current stock must be a finite number greater than or equal to zero.',
      );
    }

    if (!minimumStock.isFinite || minimumStock < 0) {
      throw ArgumentError(
        'Minimum stock must be a finite number greater than or equal to zero.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Safe Number Conversion
  // ---------------------------------------------------------------------------

  double _toDouble(dynamic value) {
    if (value is num) {
      final double result = value.toDouble();

      if (result.isFinite) {
        return result;
      }

      return 0;
    }

    if (value is String) {
      final double? result = double.tryParse(value);

      if (result != null && result.isFinite) {
        return result;
      }
    }

    return 0;
  }
}
