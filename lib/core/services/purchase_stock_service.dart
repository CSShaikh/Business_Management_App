import 'package:business_management_app/models/purchase_model.dart';
import 'package:business_management_app/repositories/stock_repository.dart';

/// Handles inventory updates created by purchase transactions.
///
/// A successful purchase increases stock for every product item and creates
/// a stock-in transaction for each item through [StockRepository].
///
/// This service also supports reversing a previously processed purchase.
/// Reversal is useful when a purchase is edited or deleted.
class PurchaseStockService {
  final StockRepository stockRepository;

  PurchaseStockService({
    StockRepository? stockRepository,
  }) : stockRepository = stockRepository ?? StockRepository();

  /// Adds purchased quantities to product stock.
  ///
  /// This method should be called after the purchase itself has been
  /// successfully saved.
  ///
  /// Every purchase item must have:
  /// - a valid product ID
  /// - a quantity greater than zero
  /// - a non-negative purchase rate
  Future<void> processPurchaseStock({
    required PurchaseModel purchase,
  }) async {
    final String businessId = purchase.businessId.trim();

    if (purchase.items.isEmpty) {
      return;
    }

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty when processing purchase stock.',
      );
    }

    for (final item in purchase.items) {
      final String productId = item.productId.trim();
      final String productName = item.productName.trim();

      _validatePurchaseItem(
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
    }
  }

  /// Reverses stock that was previously added by a purchase.
  ///
  /// This is intended to be used when:
  /// - a purchase is deleted
  /// - an existing purchase is edited
  /// - a previously processed purchase needs to be rolled back
  ///
  /// Reversal creates a stock-out transaction rather than deleting the
  /// original stock-in transaction. This preserves the inventory audit trail.
  ///
  /// If the current stock is lower than the quantity being reversed,
  /// [StockRepository] will reject the operation instead of allowing
  /// negative stock.
  Future<void> reversePurchaseStock({
    required PurchaseModel purchase,
  }) async {
    final String businessId = purchase.businessId.trim();

    if (purchase.items.isEmpty) {
      return;
    }

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty when reversing purchase stock.',
      );
    }

    for (final item in purchase.items) {
      final String productId = item.productId.trim();
      final String productName = item.productName.trim();

      _validatePurchaseItem(
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
    }
  }

  /// Validates a purchase item before changing inventory.
  void _validatePurchaseItem({
    required String productId,
    required String productName,
    required double quantity,
    required double purchaseRate,
  }) {
    final String displayName = productName.isEmpty
        ? (productId.isEmpty ? 'Unknown product' : productId)
        : productName;

    if (productId.isEmpty) {
      throw ArgumentError(
        'Product ID cannot be empty for purchase item: $displayName',
      );
    }

    if (quantity <= 0) {
      throw ArgumentError(
        'Purchase quantity must be greater than zero for $displayName.',
      );
    }

    if (purchaseRate < 0) {
      throw ArgumentError(
        'Purchase rate cannot be negative for $displayName.',
      );
    }
  }
}