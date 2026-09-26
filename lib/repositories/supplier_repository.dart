import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/supplier_model.dart';
import 'base_repository.dart';

class SupplierRepository extends BaseRepository {
  SupplierRepository({
    super.firestore,
  });

  CollectionReference<Map<String, dynamic>> _suppliers(
    String businessId,
  ) {
    return firestore
        .collection('businesses')
        .doc(businessId.trim())
        .collection('suppliers');
  }

  // ---------------------------------------------------------------------------
  // Create Supplier
  // ---------------------------------------------------------------------------

  Future<SupplierModel> createSupplier(
    SupplierModel supplier,
  ) async {
    final String businessId = supplier.businessId.trim();
    final String requestedSupplierId = supplier.id.trim();
    final String name = supplier.name.trim();

    if (businessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty.');
    }

    if (name.isEmpty) {
      throw ArgumentError(
        'Supplier name cannot be empty.',
      );
    }

    await _ensureNoDuplicateSupplier(
      supplier,
      businessId: businessId,
      ignoreSupplierId: requestedSupplierId.isEmpty ? null : requestedSupplierId,
    );

    final DateTime now = DateTime.now();

    final DocumentReference<Map<String, dynamic>> document =
        requestedSupplierId.isEmpty
            ? _suppliers(businessId).doc()
            : _suppliers(businessId).doc(requestedSupplierId);
    final String supplierId = document.id;

    final SupplierModel savedSupplier = SupplierModel(
      id: supplierId,
      businessId: businessId,
      name: name,
      contactPerson: supplier.contactPerson.trim(),
      mobile: supplier.mobile.trim(),
      email: supplier.email.trim(),
      address: supplier.address.trim(),
      gstNumber: supplier.gstNumber.trim(),
      notes: supplier.notes.trim(),
      createdAt: supplier.createdAt,
      updatedAt: now,
    );

    await document.set({
      'id': savedSupplier.id,
      'businessId': savedSupplier.businessId,
      'name': savedSupplier.name,
      'contactPerson': savedSupplier.contactPerson,
      'mobile': savedSupplier.mobile,
      'email': savedSupplier.email,
      'address': savedSupplier.address,
      'gstNumber': savedSupplier.gstNumber,
      'notes': savedSupplier.notes,
      'createdAt': Timestamp.fromDate(
        savedSupplier.createdAt,
      ),
      'updatedAt': Timestamp.fromDate(
        savedSupplier.updatedAt,
      ),
    });

    return savedSupplier;
  }

  // ---------------------------------------------------------------------------
  // Get Supplier
  // ---------------------------------------------------------------------------

  Future<SupplierModel?> getSupplier(
    String businessId,
    String supplierId,
  ) async {
    final String normalizedBusinessId =
        businessId.trim();
    final String normalizedSupplierId =
        supplierId.trim();

    if (normalizedBusinessId.isEmpty ||
        normalizedSupplierId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _suppliers(normalizedBusinessId)
            .doc(normalizedSupplierId)
            .get();

    if (!snapshot.exists ||
        snapshot.data() == null) {
      return null;
    }

    return _fromMap(
      snapshot.data()!,
      snapshot.id,
      normalizedBusinessId,
    );
  }

  // ---------------------------------------------------------------------------
  // Get All Suppliers
  // ---------------------------------------------------------------------------

  Future<List<SupplierModel>> getSuppliers(
    String businessId,
  ) async {
    final String normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _suppliers(normalizedBusinessId)
            .orderBy('name')
            .get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.data(),
            doc.id,
            normalizedBusinessId,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Watch Suppliers
  // ---------------------------------------------------------------------------

  Stream<List<SupplierModel>> watchSuppliers(
    String businessId,
  ) {
    final String normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      return const Stream<List<SupplierModel>>.empty();
    }

    return _suppliers(normalizedBusinessId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _fromMap(
                  doc.data(),
                  doc.id,
                  normalizedBusinessId,
                ),
              )
              .toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Update Supplier
  // ---------------------------------------------------------------------------

  Future<void> updateSupplier(
    SupplierModel supplier,
  ) async {
    final String businessId =
        supplier.businessId.trim();
    final String supplierId =
        supplier.id.trim();
    final String name =
        supplier.name.trim();

    _validateIds(
      businessId: businessId,
      supplierId: supplierId,
    );

    if (name.isEmpty) {
      throw ArgumentError(
        'Supplier name cannot be empty.',
      );
    }

    await _ensureNoDuplicateSupplier(
      supplier,
      businessId: businessId,
      ignoreSupplierId: supplierId,
    );

    final DocumentReference<Map<String, dynamic>> document =
        _suppliers(businessId).doc(supplierId);

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await document.get();

    if (!snapshot.exists ||
        snapshot.data() == null) {
      throw StateError(
        'Supplier not found.',
      );
    }

    await document.update({
      'name': name,
      'contactPerson':
          supplier.contactPerson.trim(),
      'mobile': supplier.mobile.trim(),
      'email': supplier.email.trim(),
      'address': supplier.address.trim(),
      'gstNumber': supplier.gstNumber.trim(),
      'notes': supplier.notes.trim(),
      'updatedAt': Timestamp.fromDate(
        DateTime.now(),
      ),
    });
  }

  // ---------------------------------------------------------------------------
  // Delete Supplier
  // ---------------------------------------------------------------------------

  Future<void> deleteSupplier({
    required String businessId,
    required String supplierId,
  }) async {
    final String normalizedBusinessId =
        businessId.trim();
    final String normalizedSupplierId =
        supplierId.trim();

    _validateIds(
      businessId: normalizedBusinessId,
      supplierId: normalizedSupplierId,
    );

    await _suppliers(normalizedBusinessId)
        .doc(normalizedSupplierId)
        .delete();
  }

  // ---------------------------------------------------------------------------
  // Firestore -> Model
  // ---------------------------------------------------------------------------

  SupplierModel _fromMap(
    Map<String, dynamic> data,
    String documentId,
    String businessId,
  ) {
    return SupplierModel(
      id: _stringValue(
        data['id'],
        fallback: documentId,
      ),
      businessId: _stringValue(
        data['businessId'],
        fallback: businessId,
      ),
      name: _stringValue(
        data['name'],
      ),
      contactPerson: _stringValue(
        data['contactPerson'],
      ),
      mobile: _stringValue(
        data['mobile'],
      ),
      email: _stringValue(
        data['email'],
      ),
      address: _stringValue(
        data['address'],
      ),
      gstNumber: _stringValue(
        data['gstNumber'],
      ),
      notes: _stringValue(
        data['notes'],
      ),
      createdAt: dateFromFirestore(
        data['createdAt'],
      ),
      updatedAt: dateFromFirestore(
        data['updatedAt'],
      ),
    );
  }

  Future<void> _ensureNoDuplicateSupplier(
    SupplierModel supplier, {
    required String businessId,
    String? ignoreSupplierId,
  }) async {
    final String mobile = supplier.mobile.trim();
    final String name = supplier.name.trim().toLowerCase();
    final String address = supplier.address.trim().toLowerCase();
    final snapshot = await _suppliers(businessId).get();
    for (final doc in snapshot.docs) {
      if (ignoreSupplierId != null && doc.id == ignoreSupplierId.trim()) {
        continue;
      }
      final data = doc.data();
      final existingMobile = data['mobile']?.toString().trim() ?? '';
      final existingName = data['name']?.toString().trim().toLowerCase() ?? '';
      final existingAddress = data['address']?.toString().trim().toLowerCase() ?? '';
      if (mobile.isNotEmpty && existingMobile == mobile) {
        throw StateError('A supplier with mobile $mobile already exists.');
      }
      if (mobile.isEmpty && existingName == name && existingAddress == address) {
        throw StateError('This supplier already exists.');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  void _validateIds({
    required String businessId,
    required String supplierId,
  }) {
    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (supplierId.isEmpty) {
      throw ArgumentError(
        'Supplier ID cannot be empty.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Safe String Conversion
  // ---------------------------------------------------------------------------

  String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value is String) {
      return value.trim();
    }

    if (value == null) {
      return fallback;
    }

    return value.toString().trim();
  }
}
