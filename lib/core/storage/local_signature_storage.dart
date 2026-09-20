import 'local_signature_storage_stub.dart'
    if (dart.library.io) 'local_signature_storage_io.dart' as platform;

import 'dart:typed_data';

/// Stores the authorised-signatory signature on the current device/computer.
///
/// Native platforms use app-private storage. Web uses browser-local storage
/// through the platform implementation. The signature is never uploaded to
/// Firebase Storage.
class LocalSignatureStorage {
  LocalSignatureStorage._();

  static Future<void> save({
    required String businessId,
    required Uint8List bytes,
  }) {
    return platform.saveSignature(businessId: businessId, bytes: bytes);
  }

  static Future<Uint8List?> read({required String businessId}) {
    return platform.readSignature(businessId: businessId);
  }

  static Future<void> delete({required String businessId}) {
    return platform.deleteSignature(businessId: businessId);
  }
}
