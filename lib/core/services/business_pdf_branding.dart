import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/business_model.dart';

class BusinessPdfBranding {
  BusinessPdfBranding._();

  static Future<pw.MemoryImage?> loadLogo(BusinessModel business) async {
    try {
      final String url = business.logoUrl.trim();
      if (url.isNotEmpty) {
        final Uint8List? bytes = await FirebaseStorage.instance
            .refFromURL(url)
            .getData(4 * 1024 * 1024);
        if (bytes != null && bytes.isNotEmpty) {
          return pw.MemoryImage(bytes);
        }
      }
    } catch (_) {}

    try {
      final ByteData data = await rootBundle.load('assets/icon/app_icon.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static pw.Widget header({
    required BusinessModel business,
    required pw.MemoryImage? logo,
    required String title,
    pw.TextStyle? titleStyle,
    pw.TextStyle? bodyStyle,
  }) {
    final pw.TextStyle heading =
        titleStyle ??
        pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold);
    final pw.TextStyle body = bodyStyle ?? const pw.TextStyle(fontSize: 8.5);

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 52,
            height: 52,
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: logo == null
                ? pw.Center(child: pw.Text('LOGO', style: body))
                : pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  business.businessName.trim().isEmpty
                      ? 'Business Management'
                      : business.businessName.trim(),
                  style: heading,
                ),
                if (business.businessType.trim().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(business.businessType.trim(), style: body),
                  ),
                if (business.address.trim().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(business.address.trim(), style: body),
                  ),
                if (business.mobile.trim().isNotEmpty ||
                    business.email.trim().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(
                      [
                        if (business.mobile.trim().isNotEmpty)
                          'Mobile: ${business.mobile.trim()}',
                        if (business.email.trim().isNotEmpty)
                          'Email: ${business.email.trim()}',
                      ].join('   '),
                      style: body,
                    ),
                  ),
                if (business.gstNumber.trim().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(
                      'GSTIN: ${business.gstNumber.trim()}',
                      style: body,
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              title.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
