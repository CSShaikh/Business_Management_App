import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/business_model.dart';
import 'base_repository.dart';

class BusinessRepository extends BaseRepository {
  BusinessRepository({
    super.firestore,
  });

  CollectionReference<Map<String, dynamic>> get _businesses =>
      firestore.collection('businesses');

  DocumentReference<Map<String, dynamic>> _businessDocument(
    String businessId,
  ) {
    return _businesses.doc(businessId);
  }

  /// Creates a new business.
  ///
  /// This method first checks whether the owner already has a business.
  /// If a business already exists, it returns that existing business
  /// instead of creating another duplicate business.
  Future<BusinessModel> createBusiness(
    BusinessModel business,
  ) async {
    final BusinessModel? existingBusiness =
        await getBusinessForOwner(business.ownerId);

    if (existingBusiness != null) {
      return existingBusiness;
    }

    await _businessDocument(business.id).set({
      'id': business.id,
      'ownerId': business.ownerId,
      'businessName': business.businessName,
      'mobile': business.mobile,
      'email': business.email,
      'address': business.address,
      'gstNumber': business.gstNumber,
      'ownerName': business.ownerName,
      'businessType': business.businessType,
      'logoUrl': business.logoUrl,
      'createdAt': Timestamp.fromDate(business.createdAt),
      'updatedAt': Timestamp.fromDate(business.updatedAt),
    });

    return business;
  }

  Future<BusinessModel?> getBusiness(
    String businessId,
  ) async {
    final snapshot = await _businessDocument(businessId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return _fromMap(
      snapshot.data()!,
      snapshot.id,
    );
  }

  Future<BusinessModel?> getBusinessForOwner(
    String ownerId,
  ) async {
    final snapshot = await _businesses
        .where(
          'ownerId',
          isEqualTo: ownerId,
        )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final document = snapshot.docs.first;

    return _fromMap(
      document.data(),
      document.id,
    );
  }

  Future<void> updateBusiness(
    BusinessModel business,
  ) async {
    await _businessDocument(business.id).update({
      'businessName': business.businessName,
      'mobile': business.mobile,
      'email': business.email,
      'address': business.address,
      'gstNumber': business.gstNumber,
      'ownerName': business.ownerName,
      'businessType': business.businessType,
      'logoUrl': business.logoUrl,
      'updatedAt': Timestamp.fromDate(
        DateTime.now(),
      ),
    });
  }

  Future<void> deleteBusiness(
    String businessId,
  ) async {
    await _businessDocument(businessId).delete();
  }

  Stream<BusinessModel?> watchBusiness(
    String businessId,
  ) {
    return _businessDocument(businessId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      return _fromMap(
        snapshot.data()!,
        snapshot.id,
      );
    });
  }

  BusinessModel _fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return BusinessModel(
      id: data['id'] as String? ?? documentId,
      ownerId: data['ownerId'] as String? ?? '',
      businessName: data['businessName'] as String? ?? '',
      mobile: data['mobile'] as String? ?? '',
      email: data['email'] as String? ?? '',
      address: data['address'] as String? ?? '',
      gstNumber: data['gstNumber'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      businessType: data['businessType'] as String? ?? '',
      logoUrl: data['logoUrl'] as String? ?? '',
      createdAt: dateFromFirestore(
        data['createdAt'],
      ),
      updatedAt: dateFromFirestore(
        data['updatedAt'],
      ),
    );
  }
}