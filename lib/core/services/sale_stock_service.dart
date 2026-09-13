import 'package:business_management_app/models/sale_model.dart';
import 'package:business_management_app/repositories/stock_repository.dart';

/// Handles inventory changes created by sale transactions.
///
/// A successful sale decreases stock for every product item.
///
/// If processing a multi-item sale fails after one or more items have already
/// been processed, all successful stock changes from that attempt are
/// automatically compensated so the stock returns to its previous state.
///
/// A sale can also be reversed when it is deleted or before a replacement sale
/// is saved. If a multi-item reversal fails after one or more items have
/// already been restored, those successful restorations are compensated.
class SaleStockService {
  final StockRepository stockRepository;

  SaleStockService({
    StockRepository? stockRepository,
  }) : stockRepository = stockRepository ?? StockRepository();

  // ===========================================================================
  // PROCESS SALE STOCK
  // ===========================================================================

  /// Deducts sold quantities from product stock.
  ///
  /// The operation is treated as an all-or-nothing attempt:
  ///
  ///   Product A -> stock deducted
  ///   Product B -> stock deducted
  ///   Product C -> ERROR
  ///
  /// In this situation, Product A and Product B are automatically restored
  /// before the original error is rethrown.
  ///
  /// This prevents a partially processed sale from leaving inventory in an
  /// inconsistent state.
  Future<void> processSaleStock({
    required SaleModel sale,
  }) async {
    final String businessId = sale.businessId.trim();

    if (sale.items.isEmpty) {
      return;
    }

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty when processing sale stock.',
      );
    }

    final List<SaleItemModel> processedItems = <SaleItemModel>[];

    try {
      for (final SaleItemModel item in sale.items) {
        final String productId = item.productId.trim();
        final String productName = item.productName.trim();

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

        processedItems.add(item);
      }
    } catch (error) {
      // -----------------------------------------------------------------------
      // ROLLBACK SUCCESSFULLY PROCESSED ITEMS
      // -----------------------------------------------------------------------
      //
      // stockOut() has already changed the product stock for every item stored
      // in processedItems. Restore those changes in reverse order.
      //
      // Reverse order is intentional: it mirrors the transactional rollback
      // pattern and keeps the compensation sequence deterministic.
      for (final SaleItemModel item in processedItems.reversed) {
        try {
          await stockRepository.stockIn(
            businessId: businessId,
            productId: item.productId.trim(),
            quantity: item.quantity,
            unitCost: item.costPrice,
            referenceId: sale.id.trim(),
            date: DateTime.now(),
            notes:
                'Rollback of stock deduction for invoice '
                '${sale.invoiceNumber.trim()}',
          );
        } catch (_) {
          // Preserve the original processing error.
          //
          // If a compensation operation itself fails, the original exception
          // is still rethrown below so the caller receives the actual failure
          // that caused the sale stock operation to fail.
        }
      }

      rethrow;
    }
  }

  // ===========================================================================
  // REVERSE SALE STOCK
  // ===========================================================================

  /// Restores stock previously deducted by a sale.
  ///
  /// This is used when a sale is deleted or before replacing the stock impact
  /// of an edited sale.
  ///
  /// The operation is also treated as an all-or-nothing attempt:
  ///
  ///   Product A -> stock restored
  ///   Product B -> stock restored
  ///   Product C -> ERROR
  ///
  /// In this situation, Product A and Product B are automatically deducted
  /// again so the inventory returns to its previous state.
  Future<void> reverseSaleStock({
    required SaleModel sale,
  }) async {
    final String businessId = sale.businessId.trim();

    if (sale.items.isEmpty) {
      return;
    }

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty when reversing sale stock.',
      );
    }

    final List<SaleItemModel> reversedItems = <SaleItemModel>[];

    try {
      for (final SaleItemModel item in sale.items) {
        final String productId = item.productId.trim();
        final String productName = item.productName.trim();

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

        reversedItems.add(item);
      }
    } catch (error) {
      // -----------------------------------------------------------------------
      // ROLLBACK SUCCESSFULLY REVERSED ITEMS
      // -----------------------------------------------------------------------
      //
      // reverseSaleStock() has already increased stock for every item stored
      // in reversedItems. Deduct those quantities again to restore the exact
      // stock state that existed before this reversal attempt.
      for (final SaleItemModel item in reversedItems.reversed) {
        try {
          await stockRepository.stockOut(
            businessId: businessId,
            productId: item.productId.trim(),
            quantity: item.quantity,
            unitCost: item.costPrice,
            referenceId: sale.id.trim(),
            date: DateTime.now(),
            notes:
                'Rollback of stock restoration for invoice '
                '${sale.invoiceNumber.trim()}',
          );
        } catch (_) {
          // Preserve the original reversal error.
          //
          // The original error is rethrown below so callers can handle the
          // operation that actually failed.
        }
      }

      rethrow;
    }
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  void _validateSaleItem({
    required String productId,
    required String productName,
    required double quantity,
    required double costPrice,
  }) {
    final String displayName = productName.isEmpty
        ? (productId.isEmpty ? 'Unknown product' : productId)
        : productName;

    if (productId.isEmpty) {
      throw ArgumentError(
        'Product ID cannot be empty for sale item: $displayName',
      );
    }

    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError(
        'Sale quantity must be greater than zero for $displayName.',
      );
    }

    if (!costPrice.isFinite || costPrice < 0) {
      throw ArgumentError(
        'Cost price cannot be negative for $displayName.',
      );
    }
  }
}