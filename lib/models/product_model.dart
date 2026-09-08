class ProductModel {
  final String id;
  final String businessId;
  final String name;
  final String category;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;
  final double currentStock;
  final double minimumStock;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.category,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.currentStock,
    required this.minimumStock,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });
}