import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer_model.dart';
import 'base_repository.dart';

class CustomerRepository extends BaseRepository {
  CustomerRepository({
    super.firestore,
  });

  CollectionReference<Map<String, dynamic>> _customers(
    String businessId,
  ) {
    final normalizedBusinessId = businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty.');
    }

    return firestore
        .collection('businesses')
        .doc(normalizedBusinessId)
        .collection('customers');
  }

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  Future<String> createCustomer(
    CustomerModel customer,
  ) async {
    _validateCustomer(customer);

    final businessId = customer.businessId.trim();

    final doc = _customers(businessId).doc();

    final now = DateTime.now();

    final normalizedCustomer = CustomerModel(
      id: doc.id,
      businessId: businessId,
      name: customer.name.trim(),
      ownerName: customer.ownerName.trim(),
      mobile: customer.mobile.trim(),
      email: customer.email.trim().toLowerCase(),
      address: customer.address.trim(),
      gstNumber: customer.gstNumber.trim().toUpperCase(),
      notes: customer.notes.trim(),
      createdAt: customer.createdAt,
      updatedAt: now,
    );

    await doc.set(
      _toMap(normalizedCustomer),
    );

    return doc.id;
  }

  // ---------------------------------------------------------------------------
  // GET SINGLE CUSTOMER
  // ---------------------------------------------------------------------------

  Future<CustomerModel?> getCustomer({
    required String businessId,
    required String customerId,
  }) async {
    final normalizedBusinessId = businessId.trim();
    final normalizedCustomerId = customerId.trim();

    if (normalizedBusinessId.isEmpty ||
        normalizedCustomerId.isEmpty) {
      return null;
    }

    final snapshot = await _customers(
      normalizedBusinessId,
    ).doc(normalizedCustomerId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return _fromMap(
      snapshot.id,
      snapshot.data()!,
      fallbackBusinessId: normalizedBusinessId,
    );
  }

  // ---------------------------------------------------------------------------
  // GET ALL CUSTOMERS
  // ---------------------------------------------------------------------------

  Future<List<CustomerModel>> getCustomers({
    required String businessId,
  }) async {
    final normalizedBusinessId = businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      return [];
    }

    final snapshot = await _customers(
      normalizedBusinessId,
    ).orderBy('name').get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.id,
            doc.data(),
            fallbackBusinessId: normalizedBusinessId,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // WATCH CUSTOMERS
  // ---------------------------------------------------------------------------

  Stream<List<CustomerModel>> watchCustomers({
    required String businessId,
  }) {
    final normalizedBusinessId = businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      return Stream.value(<CustomerModel>[]);
    }

    return _customers(
      normalizedBusinessId,
    ).orderBy('name').snapshots().map(
          (snapshot) {
            return snapshot.docs
                .map(
                  (doc) => _fromMap(
                    doc.id,
                    doc.data(),
                    fallbackBusinessId: normalizedBusinessId,
                  ),
                )
                .toList();
          },
        );
  }

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  Future<void> updateCustomer(
    CustomerModel customer,
  ) async {
    _validateCustomer(customer);

    final businessId = customer.businessId.trim();
    final customerId = customer.id.trim();

    if (customerId.isEmpty) {
      throw ArgumentError(
        'Customer ID cannot be empty.',
      );
    }

    final customerRef = _customers(
      businessId,
    ).doc(customerId);

    final existingSnapshot = await customerRef.get();

    if (!existingSnapshot.exists ||
        existingSnapshot.data() == null) {
      throw StateError(
        'Customer not found.',
      );
    }

    final existingData = existingSnapshot.data()!;

    final existingBusinessId =
        existingData['businessId']?.toString().trim() ?? '';

    final preservedBusinessId =
        existingBusinessId.isNotEmpty
            ? existingBusinessId
            : businessId;

    final existingCreatedAt =
        dateFromFirestore(
      existingData['createdAt'],
    );

    final updatedCustomer = CustomerModel(
      id: customerId,
      businessId: preservedBusinessId,
      name: customer.name.trim(),
      ownerName: customer.ownerName.trim(),
      mobile: customer.mobile.trim(),
      email: customer.email.trim().toLowerCase(),
      address: customer.address.trim(),
      gstNumber: customer.gstNumber.trim().toUpperCase(),
      notes: customer.notes.trim(),
      createdAt: existingCreatedAt,
      updatedAt: DateTime.now(),
    );

    await customerRef.update(
      _toMap(updatedCustomer),
    );
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<void> deleteCustomer({
    required String businessId,
    required String customerId,
  }) async {
    final normalizedBusinessId = businessId.trim();
    final normalizedCustomerId = customerId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedCustomerId.isEmpty) {
      throw ArgumentError(
        'Customer ID cannot be empty.',
      );
    }

    final customerRef = _customers(
      normalizedBusinessId,
    ).doc(normalizedCustomerId);

    final snapshot = await customerRef.get();

    if (!snapshot.exists) {
      throw StateError(
        'Customer not found.',
      );
    }

    await customerRef.delete();
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  Future<List<CustomerModel>> searchCustomers({
    required String businessId,
    required String query,
  }) async {
    final customers = await getCustomers(
      businessId: businessId,
    );

    final searchQuery = query.trim().toLowerCase();

    if (searchQuery.isEmpty) {
      return customers;
    }

    return customers.where(
      (customer) {
        return customer.name
                .toLowerCase()
                .contains(searchQuery) ||
            customer.ownerName
                .toLowerCase()
                .contains(searchQuery) ||
            customer.mobile
                .toLowerCase()
                .contains(searchQuery) ||
            customer.email
                .toLowerCase()
                .contains(searchQuery) ||
            customer.gstNumber
                .toLowerCase()
                .contains(searchQuery) ||
            customer.address
                .toLowerCase()
                .contains(searchQuery);
      },
    ).toList();
  }

  // ---------------------------------------------------------------------------
  // ACTIVE / TOTAL HELPERS
  // ---------------------------------------------------------------------------

  Future<int> getCustomerCount({
    required String businessId,
  }) async {
    final normalizedBusinessId = businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      return 0;
    }

    final snapshot = await _customers(
      normalizedBusinessId,
    ).count().get();

    return snapshot.count ?? 0;
  }

  // ---------------------------------------------------------------------------
  // FIRESTORE -> MODEL
  // ---------------------------------------------------------------------------

  CustomerModel _fromMap(
    String id,
    Map<String, dynamic> data, {
    String fallbackBusinessId = '',
  }) {
    final businessId =
        data['businessId']?.toString().trim() ??
            '';

    return CustomerModel(
      id: id,
      businessId: businessId.isNotEmpty
          ? businessId
          : fallbackBusinessId,
      name: data['name']?.toString().trim() ?? '',
      ownerName:
          data['ownerName']?.toString().trim() ?? '',
      address:
          data['address']?.toString().trim() ?? '',
      mobile:
          data['mobile']?.toString().trim() ?? '',
      email:
          data['email']?.toString().trim() ?? '',
      gstNumber:
          data['gstNumber']?.toString().trim() ?? '',
      notes:
          data['notes']?.toString().trim() ?? '',
      createdAt: dateFromFirestore(
        data['createdAt'],
      ),
      updatedAt: dateFromFirestore(
        data['updatedAt'],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MODEL -> FIRESTORE
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _toMap(
    CustomerModel customer,
  ) {
    return {
      'businessId': customer.businessId.trim(),
      'name': customer.name.trim(),
      'ownerName': customer.ownerName.trim(),
      'address': customer.address.trim(),
      'mobile': customer.mobile.trim(),
      'email': customer.email.trim().toLowerCase(),
      'gstNumber':
          customer.gstNumber.trim().toUpperCase(),
      'notes': customer.notes.trim(),
      'createdAt':
          Timestamp.fromDate(customer.createdAt),
      'updatedAt':
          Timestamp.fromDate(customer.updatedAt),
    };
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  void _validateCustomer(
    CustomerModel customer,
  ) {
    if (customer.businessId.trim().isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (customer.name.trim().isEmpty) {
      throw ArgumentError(
        'Customer name cannot be empty.',
      );
    }

    if (customer.id.trim().isEmpty &&
        customer.createdAt.isAfter(
          DateTime.now().add(
            const Duration(minutes: 1),
          ),
        )) {
      throw ArgumentError(
        'Invalid customer creation date.',
      );
    }
  }
}