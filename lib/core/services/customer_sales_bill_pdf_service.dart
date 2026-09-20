import 'dart:typed_data';

import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../models/sale_model.dart';
import 'professional_sales_bill_pdf_service.dart';

/// Public customer-sales-bill API.
///
/// The actual rendering is delegated to the same professional invoice
/// renderer used by normal sales invoices, so PDF and image outputs share one
/// layout and one local-device logo source.
class CustomerSalesBillPdfService {
  CustomerSalesBillPdfService._();

  static Future<Uint8List> generateSalesBillPdf({
    required BusinessModel business,
    required CustomerModel customer,
    required List<SaleModel> sales,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    return ProfessionalSalesBillPdfService.generateSalesRange(
      business: business,
      customer: customer,
      sales: sales,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
