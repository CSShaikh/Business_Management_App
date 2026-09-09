import 'package:business_management_app/models/sale_model.dart';
import 'package:business_management_app/repositories/stock_repository.dart';

/// Handles inventory changes created by sale transactions.
///
/// A successful sale decreases stock for every product item.
/// A sale can also be reversed when it is deleted or before
/// a replacement sale is saved.
class SaleStockService {
  final StockRepository stockRepository;

  SaleStockService({
    StockRepository? stockRepository,
  }) : stockRepository =
            stockRepository ?? StockRepository();

  Future<void> processSaleStock({
    required SaleModel sale,
  }) async {
    final String businessId =
        sale.businessId.trim();

    if (sale.items.isEmpty) {
      return;
    }

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty when processing sale stock.',
      );
    }

    for (final SaleItemModel item in sale.items) {
      final String productId =
          item.productId.trim();

      final String productName =
          item.productName.trim();

      _validateSaleItem(
        productId: productId,
        productName: productName,
        quantity: item.quantity,
        costPrice: item.costPrice,
      );

      await stockRepository.stockOut(
        businessId: businessId,
        productId: productId,
        quantity: item.quantity,
        unitCost: item.costPrice,
        referenceId: sale.id.trim(),
        date: sale.date,
        notes:
            'Stock deducted for invoice ${sale.invoiceNumber.trim()}',
      );
    }
  }

  Future<void> reverseSaleStock({
    required SaleModel sale,
  }) async {
    final String businessId =
        sale.businessId.trim();

    if (sale.items.isEmpty) {
      return;
    }

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty when reversing sale stock.',
      );
    }

    for (final SaleItemModel item in sale.items) {
      final String productId =
          item.productId.trim();

      final String productName =
          item.productName.trim();

      _validateSaleItem(
        productId: productId,
        productName: productName,
        quantity: item.quantity,
        costPrice: item.costPrice,
      );

      await stockRepository.stockIn(
        businessId: businessId,
        productId: productId,
        quantity: item.quantity,
        unitCost: item.costPrice,
        referenceId: sale.id.trim(),
        date: DateTime.now(),
        notes:
            'Stock restored for invoice ${sale.invoiceNumber.trim()}',
      );
    }
  }

  void _validateSaleItem({
    required String productId,
    required String productName,
    required double quantity,
    required double costPrice,
  }) {
    final String displayName =
        productName.isEmpty
            ? (productId.isEmpty
                ? 'Unknown product'
                : productId)
            : productName;

    if (productId.isEmpty) {
      throw ArgumentError(
        'Product ID cannot be empty for sale item: '
        '$displayName',
      );
    }

    if (!quantity.isFinite ||
        quantity <= 0) {
      throw ArgumentError(
        'Sale quantity must be greater than zero for '
        '$displayName.',
      );
    }

    if (!costPrice.isFinite ||
        costPrice < 0) {
      throw ArgumentError(
        'Cost price cannot be negative for '
        '$displayName.',
      );
    }
  }
}