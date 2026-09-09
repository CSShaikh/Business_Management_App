import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';

class CustomerProvider extends ChangeNotifier {
  CustomerProvider({
    CustomerRepository? repository,
  }) : _repository = repository ?? CustomerRepository();

  final CustomerRepository _repository;

  // ===========================================================================
  // STATE
  // ===========================================================================

  List<CustomerModel> _customers = <CustomerModel>[];

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;

  String _businessId = '';

  StreamSubscription<List<CustomerModel>>?
      _customersSubscription;

  // ===========================================================================
  // GETTERS
  // ===========================================================================

  List<CustomerModel> get customers =>
      List<CustomerModel>.unmodifiable(_customers);

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get hasCustomers => _customers.isNotEmpty;

  bool get isEmpty => _customers.isEmpty;

  int get customerCount => _customers.length;

  String get businessId => _businessId;

  String? get errorMessage => _errorMessage;

  // ===========================================================================
  // BUSINESS ID
  // ===========================================================================

  void setBusinessId(String businessId) {
    final String normalizedId = businessId.trim();

    if (_businessId == normalizedId) {
      return;
    }

    _businessId = normalizedId;

    _customersSubscription?.cancel();
    _customersSubscription = null;

    _customers = <CustomerModel>[];

    _clearError();

    notifyListeners();
  }

  // ===========================================================================
  // LOAD CUSTOMERS
  // ===========================================================================

  Future<List<CustomerModel>> loadCustomers([
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return <CustomerModel>[];
    }

    _businessId = id;

    if (_isLoading) {
      return customers;
    }

    _setLoading(true);
    _clearError();

    try {
      final List<CustomerModel> loadedCustomers =
          await _repository.getCustomers(
        businessId: id,
      );

      _customers = loadedCustomers;

      return customers;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to load customers.',
        ),
      );

      return <CustomerModel>[];
    } finally {
      _setLoading(false);
    }
  }

  // ===========================================================================
  // REAL-TIME CUSTOMER LISTENER
  // ===========================================================================

  void watchCustomers([
    String? businessId,
  ]) {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return;
    }

    _businessId = id;

    _customersSubscription?.cancel();

    _clearError();

    _customersSubscription =
        _repository.watchCustomers(
      businessId: id,
    ).listen(
      (List<CustomerModel> updatedCustomers) {
        _customers = updatedCustomers;
        notifyListeners();
      },
      onError: (Object error) {
        _setError(
          _formatError(
            error,
            fallback:
                'Unable to listen for customer updates.',
          ),
        );
      },
    );
  }

  // ===========================================================================
  // LOAD + WATCH
  // ===========================================================================

  Future<void> loadAndWatchCustomers([
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return;
    }

    _businessId = id;

    await loadCustomers(id);

    if (_errorMessage == null) {
      watchCustomers(id);
    }
  }

  // ===========================================================================
  // GET SINGLE CUSTOMER
  // ===========================================================================

  Future<CustomerModel?> getCustomer(
    String customerId, [
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String normalizedCustomerId =
        customerId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return null;
    }

    if (normalizedCustomerId.isEmpty) {
      _setError('Customer ID is required.');
      return null;
    }

    try {
      return await _repository.getCustomer(
        businessId: id,
        customerId: normalizedCustomerId,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to load customer.',
        ),
      );

      return null;
    }
  }

  // ===========================================================================
  // CREATE CUSTOMER
  // ===========================================================================

  Future<CustomerModel?> createCustomer(
    CustomerModel customer,
  ) async {
    final String id = customer.businessId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return null;
    }

    if (customer.name.trim().isEmpty) {
      _setError('Customer name is required.');
      return null;
    }

    _setSaving(true);
    _clearError();

    try {
      final String customerId =
          await _repository.createCustomer(customer);

      _businessId = id;

      final CustomerModel createdCustomer =
          CustomerModel(
        id: customerId,
        businessId: id,
        name: customer.name.trim(),
        ownerName: customer.ownerName.trim(),
        address: customer.address.trim(),
        mobile: customer.mobile.trim(),
        email: customer.email.trim().toLowerCase(),
        gstNumber:
            customer.gstNumber.trim().toUpperCase(),
        notes: customer.notes.trim(),
        createdAt: customer.createdAt,
        updatedAt: DateTime.now(),
      );

      _upsertLocalCustomer(createdCustomer);

      return createdCustomer;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to create customer.',
        ),
      );

      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ===========================================================================
  // UPDATE CUSTOMER
  // ===========================================================================

  Future<bool> updateCustomer(
    CustomerModel customer,
  ) async {
    final String id = customer.businessId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return false;
    }

    if (customer.id.trim().isEmpty) {
      _setError('Customer ID is required.');
      return false;
    }

    if (customer.name.trim().isEmpty) {
      _setError('Customer name is required.');
      return false;
    }

    _setSaving(true);
    _clearError();

    try {
      await _repository.updateCustomer(customer);

      final CustomerModel? updatedCustomer =
          await _repository.getCustomer(
        businessId: id,
        customerId: customer.id,
      );

      if (updatedCustomer != null) {
        _upsertLocalCustomer(updatedCustomer);
      } else {
        await loadCustomers(id);
      }

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to update customer.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ===========================================================================
  // DELETE CUSTOMER
  // ===========================================================================

  Future<bool> deleteCustomer(
    String customerId, [
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String normalizedCustomerId =
        customerId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return false;
    }

    if (normalizedCustomerId.isEmpty) {
      _setError('Customer ID is required.');
      return false;
    }

    _setSaving(true);
    _clearError();

    try {
      await _repository.deleteCustomer(
        businessId: id,
        customerId: normalizedCustomerId,
      );

      _customers.removeWhere(
        (CustomerModel customer) =>
            customer.id == normalizedCustomerId,
      );

      notifyListeners();

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to delete customer.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ===========================================================================
  // SEARCH CUSTOMERS
  // ===========================================================================

  Future<List<CustomerModel>> searchCustomers(
    String query, [
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return <CustomerModel>[];
    }

    try {
      return await _repository.searchCustomers(
        businessId: id,
        query: query,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to search customers.',
        ),
      );

      return <CustomerModel>[];
    }
  }

  // ===========================================================================
  // LOCAL SEARCH
  // ===========================================================================

  List<CustomerModel> filterCustomers(
    String query,
  ) {
    final String searchText =
        query.trim().toLowerCase();

    if (searchText.isEmpty) {
      return customers;
    }

    return _customers
        .where(
          (CustomerModel customer) {
            return customer.name
                    .toLowerCase()
                    .contains(searchText) ||
                customer.ownerName
                    .toLowerCase()
                    .contains(searchText) ||
                customer.mobile
                    .toLowerCase()
                    .contains(searchText) ||
                customer.email
                    .toLowerCase()
                    .contains(searchText) ||
                customer.gstNumber
                    .toLowerCase()
                    .contains(searchText) ||
                customer.address
                    .toLowerCase()
                    .contains(searchText);
          },
        )
        .toList(growable: false);
  }

  // ===========================================================================
  // FIND CUSTOMER LOCALLY
  // ===========================================================================

  CustomerModel? findCustomerById(
    String customerId,
  ) {
    final String id = customerId.trim();

    if (id.isEmpty) {
      return null;
    }

    for (final CustomerModel customer in _customers) {
      if (customer.id == id) {
        return customer;
      }
    }

    return null;
  }

  // ===========================================================================
  // FIND BY MOBILE
  // ===========================================================================

  CustomerModel? findCustomerByMobile(
    String mobile,
  ) {
    final String normalizedMobile =
        mobile.trim();

    if (normalizedMobile.isEmpty) {
      return null;
    }

    for (final CustomerModel customer in _customers) {
      if (customer.mobile.trim() ==
          normalizedMobile) {
        return customer;
      }
    }

    return null;
  }

  // ===========================================================================
  // CUSTOMER COUNT FROM FIRESTORE
  // ===========================================================================

  Future<int> getCustomerCount([
    String? businessId,
  ]) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return 0;
    }

    try {
      return await _repository.getCustomerCount(
        businessId: id,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to get customer count.',
        ),
      );

      return 0;
    }
  }

  // ===========================================================================
  // CLEAR CUSTOMERS
  // ===========================================================================

  void clearCustomers() {
    _customers = <CustomerModel>[];
    notifyListeners();
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<List<CustomerModel>> refresh() {
    return loadCustomers();
  }

  // ===========================================================================
  // ERROR HANDLING
  // ===========================================================================

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

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  // ===========================================================================
  // LOADING
  // ===========================================================================

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  // ===========================================================================
  // SAVING
  // ===========================================================================

  void _setSaving(bool value) {
    if (_isSaving == value) {
      return;
    }

    _isSaving = value;
    notifyListeners();
  }

  // ===========================================================================
  // LOCAL UPSERT
  // ===========================================================================

  void _upsertLocalCustomer(
    CustomerModel customer,
  ) {
    final int index = _customers.indexWhere(
      (CustomerModel existingCustomer) =>
          existingCustomer.id == customer.id,
    );

    if (index == -1) {
      _customers = <CustomerModel>[
        ..._customers,
        customer,
      ];
    } else {
      final List<CustomerModel> updatedCustomers =
          List<CustomerModel>.from(_customers);

      updatedCustomers[index] = customer;

      _customers = updatedCustomers;
    }

    notifyListeners();
  }

  // ===========================================================================
  // ERROR FORMATTER
  // ===========================================================================

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

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _customersSubscription?.cancel();
    super.dispose();
  }
}