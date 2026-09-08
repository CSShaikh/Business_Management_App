class BusinessModel {
  final String id;
  final String ownerId;
  final String businessName;
  final String mobile;
  final String email;
  final String address;
  final String gstNumber;
  final String ownerName;
  final String businessType;
  final String logoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BusinessModel({
    required this.id,
    required this.ownerId,
    required this.businessName,
    required this.mobile,
    this.email = '',
    this.address = '',
    this.gstNumber = '',
    this.ownerName = '',
    this.businessType = '',
    this.logoUrl = '',
    required this.createdAt,
    required this.updatedAt,
  });
}