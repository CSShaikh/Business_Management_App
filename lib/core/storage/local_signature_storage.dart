import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_signature_storage_stub.dart'
    if (dart.library.io) 'local_signature_storage_io.dart' as platform;

String _key(String businessId) =>
    'business_management_app.local_signature.${businessId.trim()}';

class LocalSignatureStorage {
  LocalSignatureStorage._();

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static Future<void> save({
    required String businessId,
    required Uint8List bytes,
    String? ownerId,
  }) async {
    final String id = businessId.trim();
    if (id.isEmpty || bytes.isEmpty) {
      throw ArgumentError('Business ID and signature bytes are required.');
    }
    await platform.saveSignature(businessId: id, bytes: bytes);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String encoded = base64Encode(bytes);
    await preferences.setString(_key(id), encoded);
    final String owner = ownerId?.trim() ?? '';
    if (owner.isNotEmpty) {
      await preferences.setString(_key(owner), encoded);
    }
    changes.value++;
  }

  static Future<Uint8List?> read({
    required String businessId,
    String? ownerId,
  }) async {
    final String id = businessId.trim();
    if (id.isEmpty) return null;
    final Uint8List? direct = await platform.readSignature(businessId: id);
    if (direct != null && direct.isNotEmpty) return direct;
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> keys = <String>[
      _key(id),
      if ((ownerId?.trim() ?? '').isNotEmpty) _key(ownerId!.trim()),
    ];
    for (final String key in keys) {
      final String? encoded = preferences.getString(key);
      if (encoded == null || encoded.isEmpty) continue;
      try {
        final Uint8List bytes = base64Decode(encoded);
        if (bytes.isNotEmpty) {
          await platform.saveSignature(businessId: id, bytes: bytes);
          return bytes;
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<void> delete({
    required String businessId,
    String? ownerId,
  }) async {
    final String id = businessId.trim();
    if (id.isEmpty) return;
    await platform.deleteSignature(businessId: id);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(id));
    final String owner = ownerId?.trim() ?? '';
    if (owner.isNotEmpty) await preferences.remove(_key(owner));
    changes.value++;
  }
}
