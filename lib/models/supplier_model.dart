class SupplierModel {
  final String id;
  final String businessId;
  final String name;
  final String contactPerson;
  final String mobile;
  final String email;
  final String address;
  final String gstNumber;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupplierModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.contactPerson = '',
    this.mobile = '',
    this.email = '',
    this.address = '',
    this.gstNumber = '',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });
}