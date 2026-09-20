import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

String _safeBusinessId(String businessId) {
  final String value = businessId.trim();
  if (value.isEmpty) {
    return 'default';
  }
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
}

Future<Directory> _signatureDirectory() async {
  final Directory root = await getApplicationSupportDirectory();
  final Directory directory = Directory(
    '${root.path}${Platform.pathSeparator}business_signatures',
  );
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return directory;
}

Future<File> _signatureFile(String businessId) async {
  final Directory directory = await _signatureDirectory();
  return File(
    '${directory.path}${Platform.pathSeparator}${_safeBusinessId(businessId)}.signature',
  );
}

Future<void> saveSignature({
  required String businessId,
  required Uint8List bytes,
}) async {
  if (bytes.isEmpty) {
    throw const FileSystemException('Signature image is empty.');
  }
  final File file = await _signatureFile(businessId);
  await file.writeAsBytes(bytes, flush: true);
}

Future<Uint8List?> readSignature({required String businessId}) async {
  final File file = await _signatureFile(businessId);
  if (!await file.exists()) {
    return null;
  }
  final Uint8List bytes = await file.readAsBytes();
  return bytes.isEmpty ? null : bytes;
}

Future<void> deleteSignature({required String businessId}) async {
  final File file = await _signatureFile(businessId);
  if (await file.exists()) {
    await file.delete();
  }
}
