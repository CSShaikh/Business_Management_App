import 'package:business_management_app/models/purchase_model.dart';
import 'package:business_management_app/repositories/product_repository.dart';
import 'package:business_management_app/repositories/stock_repository.dart';

/// Handles inventory changes created by purchase transactions.
///
/// A purchase increases product stock.
///
/// When a purchase is edited or deleted, the previously added stock can be
/// reversed through [reversePurchaseStock].
class PurchaseStockService {
  final StockRepository stockRepository;
  final ProductRepository productRepository;

  PurchaseStockService({
    StockRepository? stockRepository,
    ProductRepository? productRepository,
  }) : stockRepository = stockRepository ?? StockRepository(),
       productRepository = productRepository ?? ProductRepository();

  // ===========================================================================
  // PROCESS PURCHASE STOCK
  // ===========================================================================

  /// Adds purchased quantities to product stock.
  ///
  /// This should be called after a purchase has been successfully created or
  /// when an edited purchase has been prepared after reversing the old stock.
  Future<void> processPurchaseStock({required PurchaseModel purchase}) async {
    final String businessId = purchase.businessId.trim();

    if (purchase.items.isEmpty) {
      return;
    }

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty when processing purchase stock.',
      );
    }

    final List<_ProcessedStockItem> processedItems = [];

    try {
      for (final item in purchase.items) {
        final String productId = item.productId.trim();

        final String productName = item.productName.trim();

        _validateItem(
          productId: productId,
          productName: productName,
          quantity: item.quantity,
          purchaseRate: item.purchaseRate,
        );

        await stockRepository.stockIn(
          businessId: businessId,
          productId: productId,
          quantity: item.quantity,
          unitCost: item.purchaseRate,
          referenceId: purchase.id,
          date: purchase.date,
          notes: 'Stock added for purchase transaction',
        );

        // Keep the product master record's latest purchase rate synchronized
        // with the rate used in this purchase. The stock transaction above
        // already updates currentStock atomically.
        await productRepository.updatePurchasePrice(
          businessId: businessId,
          productId: productId,
          purchasePrice: item.purchaseRate,
        );

        processedItems.add(
          _ProcessedStockItem(
            productId: productId,
            quantity: item.quantity,
            unitCost: item.purchaseRate,
          ),
        );
      }
    } catch (error) {
      // -----------------------------------------------------------------------
      // ROLLBACK PARTIALLY PROCESSED PURCHASE
      // -----------------------------------------------------------------------
      //
      // A purchase can contain multiple products. StockRepository processes
      // each product independently, so if a later item fails, earlier items
      // must be reversed to avoid leaving partial stock.
      //

      for (final processed in processedItems.reversed) {
        try {
          await stockRepository.stockOut(
            businessId: businessId,
            productId: processed.productId,
            quantity: processed.quantity,
            unitCost: processed.unitCost,
            referenceId: purchase.id,
            date: DateTime.now(),
            notes: 'Rollback for failed purchase stock processing',
          );
        } catch (_) {
          // Preserve the original error.
        }
      }

      rethrow;
    }
  }

  // ===========================================================================
  // REVERSE PURCHASE STOCK
  // ===========================================================================

  /// Removes the stock previously added by a purchase.
  ///
  /// This is required when:
  /// - an existing purchase is edited;
  /// - a purchase is deleted.
  ///
  /// The method applies the inverse inventory operation for every item.
  Future<void> reversePurchaseStock({required PurchaseModel purchase}) async {
    final String businessId = purchase.businessId.trim();

    if (purchase.items.isEmpty) {
      return;
    }

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty when reversing purchase stock.',
      );
    }

    final List<_ProcessedStockItem> reversedItems = [];

    try {
      for (final item in purchase.items) {
        final String productId = item.productId.trim();

        final String productName = item.productName.trim();

        _validateItem(
          productId: productId,
          productName: productName,
          quantity: item.quantity,
          purchaseRate: item.purchaseRate,
        );

        await stockRepository.stockOut(
          businessId: businessId,
          productId: productId,
          quantity: item.quantity,
          unitCost: item.purchaseRate,
          referenceId: purchase.id,
          date: DateTime.now(),
          notes: 'Stock reversed for purchase transaction',
        );

        reversedItems.add(
          _ProcessedStockItem(
            productId: productId,
            quantity: item.quantity,
            unitCost: item.purchaseRate,
          ),
        );
      }
    } catch (error) {
      // -----------------------------------------------------------------------
      // ROLLBACK PARTIALLY REVERSED PURCHASE
      // -----------------------------------------------------------------------
      //
      // If one of the stock-out operations fails, restore the items that were
      // already reversed so the inventory remains in its original state.
      //

      for (final reversed in reversedItems.reversed) {
        try {
          await stockRepository.stockIn(
            businessId: businessId,
            productId: reversed.productId,
            quantity: reversed.quantity,
            unitCost: reversed.unitCost,
            referenceId: purchase.id,
            date: DateTime.now(),
            notes: 'Rollback for failed purchase stock reversal',
          );
        } catch (_) {
          // Preserve the original error.
        }
      }

      rethrow;
    }
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  void _validateItem({
    required String productId,
    required String productName,
    required double quantity,
    required double purchaseRate,
  }) {
    if (productId.isEmpty) {
      throw ArgumentError(
        'Product ID cannot be empty for purchase item: '
        '${productName.isEmpty ? 'Unknown product' : productName}',
      );
    }

    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError(
        'Purchase quantity must be greater than zero for '
        '${productName.isEmpty ? productId : productName}.',
      );
    }

    if (!purchaseRate.isFinite || purchaseRate < 0) {
      throw ArgumentError(
        'Purchase rate cannot be negative for '
        '${productName.isEmpty ? productId : productName}.',
      );
    }
  }
}

// =============================================================================
// INTERNAL STOCK TRACKING
// =============================================================================

class _ProcessedStockItem {
  final String productId;
  final double quantity;
  final double unitCost;

  const _ProcessedStockItem({
    required this.productId,
    required this.quantity,
    required this.unitCost,
  });
}
