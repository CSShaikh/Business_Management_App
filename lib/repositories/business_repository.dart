import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/business_model.dart';
import 'base_repository.dart';

class BusinessRepository extends BaseRepository {
  BusinessRepository({
    super.firestore,
  });

  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _businesses {
    return firestore.collection('businesses');
  }

  // ---------------------------------------------------------------------------
  // CREATE BUSINESS
  // ---------------------------------------------------------------------------

  Future<String> createBusiness(BusinessModel business) async {
    final existingBusiness = await getBusinessForOwner(
      business.ownerId,
    );

    if (existingBusiness != null) {
      throw Exception(
        'A business profile already exists for this account.',
      );
    }

    final document = _businesses.doc();

    final businessWithId = BusinessModel(
      id: document.id,
      ownerId: business.ownerId,
      businessName: business.businessName,
      mobile: business.mobile,
      email: business.email,
      address: business.address,
      gstNumber: business.gstNumber,
      ownerName: business.ownerName,
      businessType: business.businessType,
      logoUrl: business.logoUrl,
      createdAt: business.createdAt,
      updatedAt: business.updatedAt,
    );

    await document.set(
      _toMap(businessWithId),
    );

    return document.id;
  }

  // ---------------------------------------------------------------------------
  // GET BUSINESS BY ID
  // ---------------------------------------------------------------------------

  Future<BusinessModel?> getBusiness(
    String businessId,
  ) async {
    final snapshot = await _businesses
        .doc(businessId)
        .get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return _fromMap(
      snapshot.id,
      snapshot.data()!,
    );
  }

  // ---------------------------------------------------------------------------
  // GET BUSINESS FOR OWNER
  // ---------------------------------------------------------------------------

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
      document.id,
      document.data(),
    );
  }

  // ---------------------------------------------------------------------------
  // GET BUSINESS FOR CURRENT LOGGED-IN USER
  // ---------------------------------------------------------------------------

  Future<BusinessModel?> getBusinessForCurrentUser() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    return getBusinessForOwner(
      user.uid,
    );
  }

  // ---------------------------------------------------------------------------
  // WATCH BUSINESS
  // ---------------------------------------------------------------------------

  Stream<BusinessModel?> watchBusiness(
    String businessId,
  ) {
    return _businesses
        .doc(businessId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      return _fromMap(
        snapshot.id,
        snapshot.data()!,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // UPDATE BUSINESS
  // ---------------------------------------------------------------------------

  Future<void> updateBusiness(
    BusinessModel business,
  ) async {
    final updatedBusiness = BusinessModel(
      id: business.id,
      ownerId: business.ownerId,
      businessName: business.businessName,
      mobile: business.mobile,
      email: business.email,
      address: business.address,
      gstNumber: business.gstNumber,
      ownerName: business.ownerName,
      businessType: business.businessType,
      logoUrl: business.logoUrl,
      createdAt: business.createdAt,
      updatedAt: DateTime.now(),
    );

    await _businesses
        .doc(business.id)
        .update(
          _toMap(updatedBusiness),
        );
  }

  // ---------------------------------------------------------------------------
  // DELETE BUSINESS
  // ---------------------------------------------------------------------------

  Future<void> deleteBusiness(
    String businessId,
  ) async {
    await _businesses
        .doc(businessId)
        .delete();
  }

  // ---------------------------------------------------------------------------
  // CHECK BUSINESS EXISTS
  // ---------------------------------------------------------------------------

  Future<bool> hasBusiness(
    String ownerId,
  ) async {
    final business = await getBusinessForOwner(
      ownerId,
    );

    return business != null;
  }

  // ---------------------------------------------------------------------------
  // FIRESTORE MAP
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _toMap(
    BusinessModel business,
  ) {
    return {
      'ownerId': business.ownerId,
      'businessName': business.businessName,
      'mobile': business.mobile,
      'email': business.email,
      'address': business.address,
      'gstNumber': business.gstNumber,
      'ownerName': business.ownerName,
      'businessType': business.businessType,
      'logoUrl': business.logoUrl,
      'createdAt': Timestamp.fromDate(
        business.createdAt,
      ),
      'updatedAt': Timestamp.fromDate(
        business.updatedAt,
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // FIRESTORE -> MODEL
  // ---------------------------------------------------------------------------

  BusinessModel _fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return BusinessModel(
      id: id,
      ownerId: data['ownerId']?.toString() ?? '',
      businessName:
          data['businessName']?.toString() ?? '',
      mobile:
          data['mobile']?.toString() ?? '',
      email:
          data['email']?.toString() ?? '',
      address:
          data['address']?.toString() ?? '',
      gstNumber:
          data['gstNumber']?.toString() ?? '',
      ownerName:
          data['ownerName']?.toString() ?? '',
      businessType:
          data['businessType']?.toString() ?? '',
      logoUrl:
          data['logoUrl']?.toString() ?? '',
      createdAt: dateFromFirestore(
        data['createdAt'],
      ),
      updatedAt: dateFromFirestore(
        data['updatedAt'],
      ),
    );
  }
}