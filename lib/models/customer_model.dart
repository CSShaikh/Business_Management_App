class CustomerModel {
  final String id;
  final String businessId;
  final String name;
  final String ownerName;
  final String address;
  final String mobile;
  final String email;
  final String gstNumber;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.ownerName = '',
    this.address = '',
    this.mobile = '',
    this.email = '',
    this.gstNumber = '',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });
}