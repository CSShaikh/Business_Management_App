import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

String _key(String businessId) {
  return 'business_management_app.local_signature.${businessId.trim()}';
}

Future<void> saveSignature({
  required String businessId,
  required Uint8List bytes,
}) async {
  if (bytes.isEmpty) {
    throw StateError('Signature image is empty.');
  }
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString(_key(businessId), base64Encode(bytes));
}

Future<Uint8List?> readSignature({required String businessId}) async {
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

Future<void> deleteSignature({required String businessId}) async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.remove(_key(businessId));
}
