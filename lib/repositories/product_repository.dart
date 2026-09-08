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
    final CollectionReference<Map<String, dynamic>> products =
        _products(product.businessId);

    final DocumentReference<Map<String, dynamic>> document =
        product.id.trim().isEmpty
            ? products.doc()
            : products.doc(product.id);

    final DateTime now = DateTime.now();

    final ProductModel productToSave = ProductModel(
      id: document.id,
      businessId: product.businessId,
      name: product.name.trim(),
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
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _products(businessId)
            .doc(productId)
            .get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return _fromMap(
      snapshot.data()!,
      snapshot.id,
      businessId,
    );
  }

  // ---------------------------------------------------------------------------
  // Get All Products
  // ---------------------------------------------------------------------------

  Future<List<ProductModel>> getProducts(
    String businessId,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _products(businessId)
            .orderBy('name')
            .get();

    return snapshot.docs
        .map(
          (document) => _fromMap(
            document.data(),
            document.id,
            businessId,
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
    return _products(businessId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) {
            return snapshot.docs
                .map(
                  (document) => _fromMap(
                    document.data(),
                    document.id,
                    businessId,
                  ),
                )
                .toList();
          },
        );
  }

  // ---------------------------------------------------------------------------
  // Update Product
  // ---------------------------------------------------------------------------

  Future<void> updateProduct(
    ProductModel product,
  ) async {
    if (product.id.trim().isEmpty) {
      throw ArgumentError(
        'Product ID cannot be empty.',
      );
    }

    final ProductModel productToUpdate =
        ProductModel(
      id: product.id,
      businessId: product.businessId,
      name: product.name.trim(),
      category: product.category.trim(),
      unit: product.unit.trim(),
      purchasePrice: product.purchasePrice,
      sellingPrice: product.sellingPrice,
      currentStock: product.currentStock,
      minimumStock: product.minimumStock,
      isActive: product.isActive,
      createdAt: product.createdAt,
      updatedAt: DateTime.now(),
    );

    await _products(product.businessId)
        .doc(product.id)
        .update(
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
    if (productId.trim().isEmpty) {
      throw ArgumentError(
        'Product ID cannot be empty.',
      );
    }

    await _products(businessId)
        .doc(productId)
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
    await _products(businessId)
        .doc(productId)
        .update({
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(
        DateTime.now(),
      ),
    });
  }

  // ---------------------------------------------------------------------------
  // Update Stock
  // ---------------------------------------------------------------------------

  Future<void> updateStock(
    String businessId,
    String productId,
    double newStock,
  ) async {
    if (newStock < 0) {
      throw ArgumentError(
        'Stock cannot be negative.',
      );
    }

    await _products(businessId)
        .doc(productId)
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
  // Safe Number Conversion
  // ---------------------------------------------------------------------------

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }
}