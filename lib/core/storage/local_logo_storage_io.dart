import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _safeBusinessId(String businessId) {
  final String value = businessId.trim();
  if (value.isEmpty) {
    return 'default';
  }

  return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
}

String _preferencesKey(String businessId) =>
    'business_management_app.local_logo.${businessId.trim()}';

Future<Directory> _logoDirectory() async {
  final Directory root = await getApplicationSupportDirectory();
  final Directory directory =
      Directory('${root.path}${Platform.pathSeparator}business_logos');

  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  return directory;
}

Future<File> _logoFile(String businessId) async {
  final Directory directory = await _logoDirectory();
  return File(
    '${directory.path}${Platform.pathSeparator}${_safeBusinessId(businessId)}.logo',
  );
}

Future<void> saveLogo({
  required String businessId,
  required Uint8List bytes,
  String extension = 'png',
}) async {
  if (bytes.isEmpty) {
    throw const FileSystemException('Logo image is empty.');
  }

  final String id = businessId.trim();
  if (id.isEmpty) {
    throw const FileSystemException('Business ID is empty.');
  }

  // Keep the file as the primary local store, but also keep a small
  // SharedPreferences fallback. This makes the logo survive platform/path
  // differences and prevents the dashboard from silently falling back to the
  // generic business icon when the application-support file is unavailable.
  final File file = await _logoFile(id);
  await file.writeAsBytes(bytes, flush: true);

  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString(_preferencesKey(id), base64Encode(bytes));
}

Future<Uint8List?> readLogo({required String businessId}) async {
  final String id = businessId.trim();
  if (id.isEmpty) {
    return null;
  }

  try {
    final File file = await _logoFile(id);
    if (await file.exists()) {
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        return bytes;
      }
    }
  } catch (_) {
    // Fall through to the local preferences backup.
  }

  try {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? encoded = preferences.getString(_preferencesKey(id));
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    final Uint8List bytes = base64Decode(encoded);
    if (bytes.isEmpty) {
      return null;
    }

    // Repair the primary file when the fallback is the only copy available.
    try {
      final File file = await _logoFile(id);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}

    return bytes;
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> readAnyLogo() async {
  // Fallback used when the caller does not yet know the exact business ID.
  // Prefer the file store, then SharedPreferences.
  try {
    final Directory directory = await _logoDirectory();
    if (await directory.exists()) {
      await for (final FileSystemEntity entity in directory.list()) {
        if (entity is File && entity.path.endsWith('.logo')) {
          try {
            final Uint8List bytes = await entity.readAsBytes();
            if (bytes.isNotEmpty) return bytes;
          } catch (_) {}
        }
      }
    }
  } catch (_) {}

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
  final String id = businessId.trim();
  if (id.isEmpty) {
    return;
  }

  try {
    final File file = await _logoFile(id);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {}

  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.remove(_preferencesKey(id));
}
