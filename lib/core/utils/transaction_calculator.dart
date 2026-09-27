import '../../models/purchase_model.dart';
import '../../models/sale_model.dart';

/// Single source of truth for transaction arithmetic used by forms,
/// repositories and reports.
class TransactionCalculator {
  TransactionCalculator._();

  static double saleItemTotal(SaleItemModel item) {
    final double base = item.quantity * item.sellingRate;
    final double value = base - item.discount + item.tax;
    return value.isFinite && value > 0 ? value : 0;
  }

  static double saleSubtotal(Iterable<SaleItemModel> items) {
    return items.fold<double>(
      0,
      (sum, item) => sum + saleItemTotal(item),
    );
  }

  static double saleTotal({
    required Iterable<SaleItemModel> items,
    required double discount,
    required double tax,
  }) {
    final double value = saleSubtotal(items) - discount + tax;
    return value.isFinite && value > 0 ? value : 0;
  }

  static double purchaseItemTotal(PurchaseItemModel item) {
    final double value = item.quantity * item.purchaseRate;
    return value.isFinite && value > 0 ? value : 0;
  }

  static double purchaseSubtotal(Iterable<PurchaseItemModel> items) {
    return items.fold<double>(
      0,
      (sum, item) => sum + purchaseItemTotal(item),
    );
  }

  static double purchaseTotal({
    required Iterable<PurchaseItemModel> items,
    required double discount,
    required double tax,
  }) {
    final double value = purchaseSubtotal(items) - discount + tax;
    return value.isFinite && value > 0 ? value : 0;
  }

  static double outstanding({
    required double total,
    required double paid,
  }) {
    final double value = total - paid;
    return value.isFinite && value > 0 ? value : 0;
  }
}
