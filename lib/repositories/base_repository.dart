import 'package:cloud_firestore/cloud_firestore.dart';

abstract class BaseRepository {
  final FirebaseFirestore firestore;

  BaseRepository({
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> collection(
    String path,
  ) {
    return firestore.collection(path);
  }

  DocumentReference<Map<String, dynamic>> document(
    String path,
  ) {
    return firestore.doc(path);
  }

  DateTime dateFromFirestore(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }
}