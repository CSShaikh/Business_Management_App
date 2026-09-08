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
    return firestore
        .collection('businesses')
        .doc(businessId)
        .collection('customers');
  }

  Future<void> createCustomer(
    CustomerModel customer,
  ) async {
    await _customers(customer.businessId)
        .doc(customer.id)
        .set({
      'id': customer.id,
      'businessId': customer.businessId,
      'name': customer.name,
      'ownerName': customer.ownerName,
      'address': customer.address,
      'mobile': customer.mobile,
      'email': customer.email,
      'gstNumber': customer.gstNumber,
      'notes': customer.notes,
      'createdAt': Timestamp.fromDate(customer.createdAt),
      'updatedAt': Timestamp.fromDate(customer.updatedAt),
    });
  }

  Future<CustomerModel?> getCustomer(
    String businessId,
    String customerId,
  ) async {
    final snapshot =
        await _customers(businessId).doc(customerId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return _fromMap(
      snapshot.data()!,
      snapshot.id,
    );
  }

  Future<List<CustomerModel>> getCustomers(
    String businessId,
  ) async {
    final snapshot =
        await _customers(businessId).orderBy('name').get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.data(),
            doc.id,
          ),
        )
        .toList();
  }

  Stream<List<CustomerModel>> watchCustomers(
    String businessId,
  ) {
    return _customers(businessId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<void> updateCustomer(
    CustomerModel customer,
  ) async {
    await _customers(customer.businessId)
        .doc(customer.id)
        .update({
      'name': customer.name,
      'ownerName': customer.ownerName,
      'address': customer.address,
      'mobile': customer.mobile,
      'email': customer.email,
      'gstNumber': customer.gstNumber,
      'notes': customer.notes,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteCustomer({
    required String businessId,
    required String customerId,
  }) async {
    await _customers(businessId)
        .doc(customerId)
        .delete();
  }

  CustomerModel _fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return CustomerModel(
      id: data['id'] as String? ?? documentId,
      businessId: data['businessId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      mobile: data['mobile'] as String? ?? '',
      email: data['email'] as String? ?? '',
      gstNumber: data['gstNumber'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      createdAt: dateFromFirestore(data['createdAt']),
      updatedAt: dateFromFirestore(data['updatedAt']),
    );
  }
}