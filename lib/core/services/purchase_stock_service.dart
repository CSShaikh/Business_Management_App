import 'package:business_management_app/models/purchase_model.dart';
import 'package:business_management_app/repositories/stock_repository.dart';

/// Handles inventory updates created by purchase transactions.
///
/// A purchase normally increases stock through [processPurchaseStock].
/// When an existing purchase is edited or deleted, its original stock
/// contribution can be reversed through [reversePurchaseStock].
class PurchaseStockService {
  final StockRepository stockRepository;

  PurchaseStockService({
    StockRepository? stockRepository,
  }) : stockRepository =
            stockRepository ?? StockRepository();

  // ===========================================================================
  // PROCESS PURCHASE STOCK
  // ===========================================================================

  /// Adds purchased quantities to product stock.
  ///
  /// This method is intended to be called after the purchase itself has been
  /// successfully saved.
  Future<void> processPurchaseStock({
    required PurchaseModel purchase,
  }) async {
    final String businessId =
        purchase.businessId.trim();

    if (purchase.items.isEmpty) {
      return;
    }

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty when processing purchase stock.',
      );
    }

    if (purchase.id.trim().isEmpty) {
      throw ArgumentError(
        'Purchase ID cannot be empty when processing purchase stock.',
      );
    }

    for (final item in purchase.items) {
      final String productId =
          item.productId.trim();

      final String productName =
          item.productName.trim();

      if (productId.isEmpty) {
        throw ArgumentError(
          'Product ID cannot be empty for purchase item: '
          '${productName.isEmpty ? 'Unknown product' : productName}',
        );
      }

      if (item.quantity <= 0) {
        throw ArgumentError(
          'Purchase quantity must be greater than zero for '
          '${productName.isEmpty ? productId : productName}.',
        );
      }

      if (item.purchaseRate < 0) {
        throw ArgumentError(
          'Purchase rate cannot be negative for '
          '${productName.isEmpty ? productId : productName}.',
        );
      }

      await stockRepository.stockIn(
        businessId: businessId,
        productId: productId,
        quantity: item.quantity,
        unitCost: item.purchaseRate,
        referenceId: purchase.id.trim(),
        date: purchase.date,
        notes:
            'Stock added for purchase transaction',
      );
    }
  }

  // ===========================================================================
  // REVERSE PURCHASE STOCK
  // ===========================================================================

  /// Reverses the stock contribution of an existing purchase.
  ///
  /// A purchase originally creates an IN stock transaction. Reversing it
  /// creates the corresponding OUT operation so the product's current stock
  /// returns to the level before that purchase.
  ///
  /// This is used when:
  ///
  /// - an existing purchase is deleted
  /// - an existing purchase is edited
  /// - a purchase operation needs to be rolled back
  ///
  /// The original purchase itself is not deleted or modified here.
  Future<void> reversePurchaseStock({
    required PurchaseModel purchase,
  }) async {
    final String businessId =
        purchase.businessId.trim();

    if (purchase.items.isEmpty) {
      return;
    }

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty when reversing purchase stock.',
      );
    }

    if (purchase.id.trim().isEmpty) {
      throw ArgumentError(
        'Purchase ID cannot be empty when reversing purchase stock.',
      );
    }

    for (final item in purchase.items) {
      final String productId =
          item.productId.trim();

      final String productName =
          item.productName.trim();

      if (productId.isEmpty) {
        throw ArgumentError(
          'Product ID cannot be empty for purchase item: '
          '${productName.isEmpty ? 'Unknown product' : productName}',
        );
      }

      if (item.quantity <= 0) {
        throw ArgumentError(
          'Purchase quantity must be greater than zero for '
          '${productName.isEmpty ? productId : productName}.',
        );
      }

      if (item.purchaseRate < 0) {
        throw ArgumentError(
          'Purchase rate cannot be negative for '
          '${productName.isEmpty ? productId : productName}.',
        );
      }

      await stockRepository.stockOut(
        businessId: businessId,
        productId: productId,
        quantity: item.quantity,
        unitCost: item.purchaseRate,
        referenceId: purchase.id.trim(),
        date: DateTime.now(),
        notes:
            'Stock reversed for purchase transaction',
      );
    }
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  /// Validates a purchase before stock processing.
  void validatePurchase(
    PurchaseModel purchase,
  ) {
    final String businessId =
        purchase.businessId.trim();

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (purchase.id.trim().isEmpty) {
      throw ArgumentError(
        'Purchase ID cannot be empty.',
      );
    }

    if (purchase.items.isEmpty) {
      throw ArgumentError(
        'Purchase must contain at least one item.',
      );
    }

    for (final item in purchase.items) {
      if (item.productId.trim().isEmpty) {
        throw ArgumentError(
          'Purchase item product ID cannot be empty.',
        );
      }

      if (item.quantity <= 0) {
        throw ArgumentError(
          'Purchase item quantity must be greater than zero.',
        );
      }

      if (item.purchaseRate < 0) {
        throw ArgumentError(
          'Purchase item rate cannot be negative.',
        );
      }
    }
  }
}
