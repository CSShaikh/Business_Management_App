import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';
import 'base_repository.dart';

class ProductRepository extends BaseRepository {
  ProductRepository({
    super.firestore,
  });

  // ---------------------------------------------------------------------------
  // Collection Reference
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _products(
    String businessId,
  ) {
    return firestore
        .collection('businesses')
        .doc(businessId)
        .collection('products');
  }

  // ---------------------------------------------------------------------------
  // Create Product
  // ---------------------------------------------------------------------------

  Future<ProductModel> createProduct(
    ProductModel product,
  ) async {
    final String businessId = product.businessId.trim();

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    final String name = product.name.trim();

    if (name.isEmpty) {
      throw ArgumentError(
        'Product name cannot be empty.',
      );
    }

    _validateNumericValues(
      purchasePrice: product.purchasePrice,
      sellingPrice: product.sellingPrice,
      currentStock: product.currentStock,
      minimumStock: product.minimumStock,
    );

    final CollectionReference<Map<String, dynamic>> products =
        _products(businessId);

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
      createdAt: product.createdAt,
      updatedAt: now,
    );

    await document.set(
      _toMap(productToSave),
    );

    return productToSave;
  }

  // ---------------------------------------------------------------------------
  // Get Single Product
  // ---------------------------------------------------------------------------

  Future<ProductModel?> getProduct(
    String businessId,
    String productId,
  ) async {
    final String normalizedBusinessId = businessId.trim();
    final String normalizedProductId = productId.trim();

    if (normalizedBusinessId.isEmpty ||
        normalizedProductId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _products(normalizedBusinessId)
            .doc(normalizedProductId)
            .get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return _fromMap(
      snapshot.data()!,
      snapshot.id,
      normalizedBusinessId,
    );
  }

  // ---------------------------------------------------------------------------
  // Get All Products
  // ---------------------------------------------------------------------------

  Future<List<ProductModel>> getProducts(
    String businessId,
  ) async {
    final String normalizedBusinessId = businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _products(normalizedBusinessId)
            .orderBy('name')
            .get();

    return snapshot.docs
        .map(
          (document) => _fromMap(
            document.data(),
            document.id,
            normalizedBusinessId,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Watch Products - Real Time
  // ---------------------------------------------------------------------------

  Stream<List<ProductModel>> watchProducts(
    String businessId,
  ) {
    final String normalizedBusinessId = businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      return const Stream<List<ProductModel>>.empty();
    }

    return _products(normalizedBusinessId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) {
            return snapshot.docs
                .map(
                  (document) => _fromMap(
                    document.data(),
                    document.id,
                    normalizedBusinessId,
                  ),
                )
                .toList();
          },
        );
  }

  // ---------------------------------------------------------------------------
  // Update Product
  //
  // IMPORTANT:
  // currentStock is intentionally NOT taken from the incoming ProductModel.
  //
  // Product editing should update product information such as:
  // - name
  // - category
  // - unit
  // - purchase price
  // - selling price
  // - minimum stock
  // - active status
  //
  // Stock must continue to be changed through purchase, sale, or inventory
  // stock-adjustment operations.
  // ---------------------------------------------------------------------------

  Future<void> updateProduct(
    ProductModel product,
  ) async {
    final String businessId = product.businessId.trim();
    final String productId = product.id.trim();
    final String name = product.name.trim();

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (productId.isEmpty) {
      throw ArgumentError(
        'Product ID cannot be empty.',
      );
    }

    if (name.isEmpty) {
      throw ArgumentError(
        'Product name cannot be empty.',
      );
    }

    _validateNumericValues(
      purchasePrice: product.purchasePrice,
      sellingPrice: product.sellingPrice,
      currentStock: product.currentStock,
      minimumStock: product.minimumStock,
    );

    final DocumentReference<Map<String, dynamic>> document =
        _products(businessId).doc(productId);

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'Product not found.',
      );
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

      // Preserve the actual stock stored in Firestore.
      currentStock: existingProduct.currentStock,

      minimumStock: product.minimumStock,
      isActive: product.isActive,
      createdAt: existingProduct.createdAt,
      updatedAt: DateTime.now(),
    );

    await document.update(
      _toMap(productToUpdate),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete Product
  // ---------------------------------------------------------------------------

  Future<void> deleteProduct(
    String businessId,
    String productId,
  ) async {
    final String normalizedBusinessId = businessId.trim();
    final String normalizedProductId = productId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedProductId.isEmpty) {
      throw ArgumentError(
        'Product ID cannot be empty.',
      );
    }

    await _products(normalizedBusinessId)
        .doc(normalizedProductId)
        .delete();
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
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedProductId.isEmpty) {
      throw ArgumentError(
        'Product ID cannot be empty.',
      );
    }

    await _products(normalizedBusinessId)
        .doc(normalizedProductId)
        .update({
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(
        DateTime.now(),
      ),
    });
  }

  // ---------------------------------------------------------------------------
  // Update Stock
  //
  // This method is kept for direct stock updates where required.
  // Normal stock movement should preferably go through StockRepository so
  // that the corresponding stock transaction is also recorded.
  // ---------------------------------------------------------------------------

  Future<void> updateStock(
    String businessId,
    String productId,
    double newStock,
  ) async {
    final String normalizedBusinessId = businessId.trim();
    final String normalizedProductId = productId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedProductId.isEmpty) {
      throw ArgumentError(
        'Product ID cannot be empty.',
      );
    }

    if (!newStock.isFinite || newStock < 0) {
      throw ArgumentError(
        'Stock must be a finite number greater than or equal to zero.',
      );
    }

    await _products(normalizedBusinessId)
        .doc(normalizedProductId)
        .update({
      'currentStock': newStock,
      'updatedAt': Timestamp.fromDate(
        DateTime.now(),
      ),
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
    final List<ProductModel> products =
        await getProducts(businessId);

    final String searchText =
        query.trim().toLowerCase();

    if (searchText.isEmpty) {
      return products;
    }

    return products.where(
      (product) {
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
    ).toList();
  }

  // ---------------------------------------------------------------------------
  // Get Active Products
  // ---------------------------------------------------------------------------

  Future<List<ProductModel>> getActiveProducts(
    String businessId,
  ) async {
    final List<ProductModel> products =
        await getProducts(businessId);

    return products
        .where(
          (product) => product.isActive,
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Get Low Stock Products
  // ---------------------------------------------------------------------------

  Future<List<ProductModel>> getLowStockProducts(
    String businessId,
  ) async {
    final List<ProductModel> products =
        await getProducts(businessId);

    return products
        .where(
          (product) =>
              product.currentStock <=
              product.minimumStock,
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Convert ProductModel -> Firestore Map
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _toMap(
    ProductModel product,
  ) {
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
      'createdAt': Timestamp.fromDate(
        product.createdAt,
      ),
      'updatedAt': Timestamp.fromDate(
        product.updatedAt,
      ),
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
      businessId:
          data['businessId'] as String? ?? businessId,
      name: data['name'] as String? ?? '',
      category:
          data['category'] as String? ?? '',
      unit: data['unit'] as String? ?? '',
      purchasePrice:
          _toDouble(data['purchasePrice']),
      sellingPrice:
          _toDouble(data['sellingPrice']),
      currentStock:
          _toDouble(data['currentStock']),
      minimumStock:
          _toDouble(data['minimumStock']),
      isActive:
          data['isActive'] as bool? ?? true,
      createdAt:
          dateFromFirestore(data['createdAt']),
      updatedAt:
          dateFromFirestore(data['updatedAt']),
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
    if (!purchasePrice.isFinite ||
        purchasePrice < 0) {
      throw ArgumentError(
        'Purchase price must be a finite number greater than or equal to zero.',
      );
    }

    if (!sellingPrice.isFinite ||
        sellingPrice < 0) {
      throw ArgumentError(
        'Selling price must be a finite number greater than or equal to zero.',
      );
    }

    if (!currentStock.isFinite ||
        currentStock < 0) {
      throw ArgumentError(
        'Current stock must be a finite number greater than or equal to zero.',
      );
    }

    if (!minimumStock.isFinite ||
        minimumStock < 0) {
      throw ArgumentError(
        'Minimum stock must be a finite number greater than or equal to zero.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Safe Number Conversion
  // ---------------------------------------------------------------------------

  double _toDouble(
    dynamic value,
  ) {
    if (value is num) {
      final double result = value.toDouble();

      if (result.isFinite) {
        return result;
      }

      return 0;
    }

    if (value is String) {
      final double? result =
          double.tryParse(value);

      if (result != null &&
          result.isFinite) {
        return result;
      }
    }

    return 0;
  }
}
