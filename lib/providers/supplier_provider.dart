import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/supplier_model.dart';
import '../repositories/supplier_repository.dart';

class SupplierProvider extends ChangeNotifier {
  SupplierProvider({
    SupplierRepository? repository,
  }) : _repository = repository ?? SupplierRepository();

  final SupplierRepository _repository;

  List<SupplierModel> _suppliers = [];

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;

  String _businessId = '';

  StreamSubscription<List<SupplierModel>>? _suppliersSubscription;

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  List<SupplierModel> get suppliers =>
      List<SupplierModel>.unmodifiable(_suppliers);

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get hasSuppliers => _suppliers.isNotEmpty;

  bool get isEmpty => _suppliers.isEmpty;

  String? get errorMessage => _errorMessage;

  String get businessId => _businessId;

  int get supplierCount => _suppliers.length;

  // ---------------------------------------------------------------------------
  // BUSINESS ID
  // ---------------------------------------------------------------------------

  void setBusinessId(String businessId) {
    final String id = businessId.trim();

    if (_businessId == id) {
      return;
    }

    _businessId = id;

    if (id.isEmpty) {
      clearSuppliers();
    }
  }

  // ---------------------------------------------------------------------------
  // LOAD SUPPLIERS
  // ---------------------------------------------------------------------------

  Future<List<SupplierModel>> loadSuppliers({
    String? businessId,
  }) async {
    final String id = (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return [];
    }

    _businessId = id;

    _setLoading(true);
    _clearError();

    try {
      final List<SupplierModel> suppliers =
          await _repository.getSuppliers(id);

      _suppliers = suppliers;

      return List<SupplierModel>.unmodifiable(_suppliers);
    } catch (error) {
      _setError(
        _formatError(
          error,
          fallback: 'Unable to load suppliers.',
        ),
      );

      return [];
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // WATCH SUPPLIERS
  // ---------------------------------------------------------------------------

  void watchSuppliers({
    String? businessId,
  }) {
    final String id = (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return;
    }

    _businessId = id;

    _suppliersSubscription?.cancel();

    _clearError();

    _suppliersSubscription = _repository
        .watchSuppliers(id)
        .listen(
      (List<SupplierModel> suppliers) {
        _suppliers = List<SupplierModel>.from(suppliers);
        notifyListeners();
      },
      onError: (Object error) {
        _setError(
          _formatError(
            error,
            fallback: 'Unable to listen for supplier updates.',
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // LOAD + WATCH
  // ---------------------------------------------------------------------------

  Future<void> loadAndWatchSuppliers({
    String? businessId,
  }) async {
    final String id = (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return;
    }

    await loadSuppliers(
      businessId: id,
    );

    watchSuppliers(
      businessId: id,
    );
  }

  // ---------------------------------------------------------------------------
  // GET SINGLE SUPPLIER
  // ---------------------------------------------------------------------------

  Future<SupplierModel?> getSupplier({
    String? businessId,
    required String supplierId,
  }) async {
    final String id = (businessId ?? _businessId).trim();
    final String supplierIdValue = supplierId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return null;
    }

    if (supplierIdValue.isEmpty) {
      _setError('Supplier ID is required.');
      return null;
    }

    try {
      return await _repository.getSupplier(
        id,
        supplierIdValue,
      );
    } catch (error) {
      _setError(
        _formatError(
          error,
          fallback: 'Unable to load supplier.',
        ),
      );

      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CREATE SUPPLIER
  // ---------------------------------------------------------------------------

  Future<bool> createSupplier(
    SupplierModel supplier,
  ) async {
    final String businessId = supplier.businessId.trim();

    if (businessId.isEmpty) {
      _setError('Business ID is required.');
      return false;
    }

    if (supplier.id.trim().isEmpty) {
      _setError('Supplier ID is required.');
      return false;
    }

    if (supplier.name.trim().isEmpty) {
      _setError('Supplier name is required.');
      return false;
    }

    _businessId = businessId;

    _setSaving(true);
    _clearError();

    try {
      await _repository.createSupplier(supplier);

      _upsertLocalSupplier(supplier);

      return true;
    } catch (error) {
      _setError(
        _formatError(
          error,
          fallback: 'Unable to create supplier.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE SUPPLIER
  // ---------------------------------------------------------------------------

  Future<bool> updateSupplier(
    SupplierModel supplier,
  ) async {
    final String businessId = supplier.businessId.trim();
    final String supplierId = supplier.id.trim();

    if (businessId.isEmpty) {
      _setError('Business ID is required.');
      return false;
    }

    if (supplierId.isEmpty) {
      _setError('Supplier ID is required.');
      return false;
    }

    if (supplier.name.trim().isEmpty) {
      _setError('Supplier name is required.');
      return false;
    }

    _businessId = businessId;

    _setSaving(true);
    _clearError();

    try {
      await _repository.updateSupplier(supplier);

      _upsertLocalSupplier(supplier);

      return true;
    } catch (error) {
      _setError(
        _formatError(
          error,
          fallback: 'Unable to update supplier.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE SUPPLIER
  // ---------------------------------------------------------------------------

  Future<bool> deleteSupplier({
    String? businessId,
    required String supplierId,
  }) async {
    final String id = (businessId ?? _businessId).trim();
    final String supplierIdValue = supplierId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return false;
    }

    if (supplierIdValue.isEmpty) {
      _setError('Supplier ID is required.');
      return false;
    }

    _businessId = id;

    _setSaving(true);
    _clearError();

    try {
      await _repository.deleteSupplier(
        businessId: id,
        supplierId: supplierIdValue,
      );

      _suppliers.removeWhere(
        (SupplierModel supplier) =>
            supplier.id.trim() == supplierIdValue,
      );

      notifyListeners();

      return true;
    } catch (error) {
      _setError(
        _formatError(
          error,
          fallback: 'Unable to delete supplier.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // FILTER SUPPLIERS
  // ---------------------------------------------------------------------------

  List<SupplierModel> filterSuppliers(
    String query,
  ) {
    final String normalizedQuery =
        query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return List<SupplierModel>.unmodifiable(
        _suppliers,
      );
    }

    return _suppliers.where(
      (SupplierModel supplier) {
        final String name =
            supplier.name.toLowerCase();

        final String contactPerson =
            supplier.contactPerson.toLowerCase();

        final String mobile =
            supplier.mobile.toLowerCase();

        final String email =
            supplier.email.toLowerCase();

        final String address =
            supplier.address.toLowerCase();

        final String gstNumber =
            supplier.gstNumber.toLowerCase();

        return name.contains(normalizedQuery) ||
            contactPerson.contains(normalizedQuery) ||
            mobile.contains(normalizedQuery) ||
            email.contains(normalizedQuery) ||
            address.contains(normalizedQuery) ||
            gstNumber.contains(normalizedQuery);
      },
    ).toList();
  }

  // ---------------------------------------------------------------------------
  // FIND SUPPLIER BY ID
  // ---------------------------------------------------------------------------

  SupplierModel? findSupplierById(
    String supplierId,
  ) {
    final String id = supplierId.trim();

    if (id.isEmpty) {
      return null;
    }

    for (final SupplierModel supplier in _suppliers) {
      if (supplier.id.trim() == id) {
        return supplier;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // FIND SUPPLIER BY MOBILE
  // ---------------------------------------------------------------------------

  SupplierModel? findSupplierByMobile(
    String mobile,
  ) {
    final String normalizedMobile =
        mobile.trim().toLowerCase();

    if (normalizedMobile.isEmpty) {
      return null;
    }

    for (final SupplierModel supplier in _suppliers) {
      if (supplier.mobile.trim().toLowerCase() ==
          normalizedMobile) {
        return supplier;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // FIND SUPPLIER BY EMAIL
  // ---------------------------------------------------------------------------

  SupplierModel? findSupplierByEmail(
    String email,
  ) {
    final String normalizedEmail =
        email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      return null;
    }

    for (final SupplierModel supplier in _suppliers) {
      if (supplier.email.trim().toLowerCase() ==
          normalizedEmail) {
        return supplier;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // CLEAR SUPPLIERS
  // ---------------------------------------------------------------------------

  void clearSuppliers() {
    _suppliers = [];
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<List<SupplierModel>> refresh() {
    return loadSuppliers();
  }

  // ---------------------------------------------------------------------------
  // ERROR
  // ---------------------------------------------------------------------------

  void clearError() {
    _clearError();
  }

  void _clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  void _setError(
    String message,
  ) {
    _errorMessage = message;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // LOADING
  // ---------------------------------------------------------------------------

  void _setLoading(
    bool value,
  ) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // SAVING
  // ---------------------------------------------------------------------------

  void _setSaving(
    bool value,
  ) {
    if (_isSaving == value) {
      return;
    }

    _isSaving = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // LOCAL SUPPLIER UPDATE
  // ---------------------------------------------------------------------------

  void _upsertLocalSupplier(
    SupplierModel supplier,
  ) {
    final String supplierId =
        supplier.id.trim();

    if (supplierId.isEmpty) {
      return;
    }

    final int existingIndex =
        _suppliers.indexWhere(
      (SupplierModel item) =>
          item.id.trim() == supplierId,
    );

    if (existingIndex == -1) {
      _suppliers = [
        ..._suppliers,
        supplier,
      ];
    } else {
      final List<SupplierModel> updated =
          List<SupplierModel>.from(
        _suppliers,
      );

      updated[existingIndex] = supplier;

      _suppliers = updated;
    }

    _suppliers.sort(
      (SupplierModel a, SupplierModel b) =>
          a.name.toLowerCase().compareTo(
                b.name.toLowerCase(),
              ),
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ERROR FORMATTER
  // ---------------------------------------------------------------------------

  String _formatError(
    Object error, {
    required String fallback,
  }) {
    final String message =
        error.toString().trim();

    if (message.isEmpty) {
      return fallback;
    }

    if (message.startsWith('Exception:')) {
      final String cleaned =
          message.replaceFirst(
        'Exception:',
        '',
      ).trim();

      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    return message;
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _suppliersSubscription?.cancel();
    super.dispose();
  }
}