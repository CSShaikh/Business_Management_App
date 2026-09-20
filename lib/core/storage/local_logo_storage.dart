import 'local_logo_storage_stub.dart'
    if (dart.library.io) 'local_logo_storage_io.dart' as platform;

import 'dart:typed_data';

/// Stores business logos on the current device/computer.
///
/// Native apps (Android/iOS/Windows/macOS/Linux) use the app's private
/// application-support directory. Web uses browser-local storage through the
/// platform implementation. Nothing is uploaded to Firebase Storage.
class LocalLogoStorage {
  LocalLogoStorage._();

  static Future<void> save({
    required String businessId,
    required Uint8List bytes,
    String extension = 'png',
  }) {
    return platform.saveLogo(
      businessId: businessId,
      bytes: bytes,
      extension: extension,
    );
  }

  static Future<Uint8List?> read({required String businessId}) {
    return platform.readLogo(businessId: businessId);
  }

  static Future<void> delete({required String businessId}) {
    return platform.deleteLogo(businessId: businessId);
  }
}
