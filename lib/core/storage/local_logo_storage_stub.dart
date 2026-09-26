import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

String _key(String businessId) {
  final String value = businessId.trim();
  return 'business_management_app.local_logo.$value';
}

Future<void> saveLogo({
  required String businessId,
  required Uint8List bytes,
  String extension = 'png',
}) async {
  if (bytes.isEmpty) {
    throw StateError('Logo image is empty.');
  }

  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString(_key(businessId), base64Encode(bytes));
}

Future<Uint8List?> readLogo({required String businessId}) async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final String? encoded = preferences.getString(_key(businessId));

  if (encoded == null || encoded.isEmpty) {
    return null;
  }

  try {
    final Uint8List bytes = base64Decode(encoded);
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> readAnyLogo() async {
  try {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    const String prefix = 'business_management_app.local_logo.';
    for (final String key in preferences.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final String? encoded = preferences.getString(key);
      if (encoded == null || encoded.isEmpty) continue;
      try {
        final Uint8List bytes = base64Decode(encoded);
        if (bytes.isNotEmpty) return bytes;
      } catch (_) {}
    }
  } catch (_) {}
  return null;
}

Future<void> deleteLogo({required String businessId}) async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.remove(_key(businessId));
}
