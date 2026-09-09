import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/business_model.dart';
import '../repositories/business_repository.dart';

class BusinessProvider extends ChangeNotifier {
  BusinessProvider({
    BusinessRepository? repository,
  }) : _repository =
            repository ?? BusinessRepository();

  final BusinessRepository _repository;

  BusinessModel? _business;

  bool _isLoading = false;

  String? _errorMessage;

  StreamSubscription<BusinessModel?>?
      _businessSubscription;

  // ============================================================
  // GETTERS
  // ============================================================

  BusinessModel? get business => _business;

  bool get isLoading => _isLoading;

  bool get hasBusiness => _business != null;

  String? get errorMessage => _errorMessage;

  String get businessId =>
      _business?.id.trim() ?? '';

  String get businessName =>
      _business?.businessName.trim() ?? '';

  String get ownerId =>
      _business?.ownerId.trim() ?? '';

  String get ownerName =>
      _business?.ownerName.trim() ?? '';

  String get mobile =>
      _business?.mobile.trim() ?? '';

  String get email =>
      _business?.email.trim() ?? '';

  String get address =>
      _business?.address.trim() ?? '';

  String get gstNumber =>
      _business?.gstNumber.trim() ?? '';

  String get businessType =>
      _business?.businessType.trim() ?? '';

  String get logoUrl =>
      _business?.logoUrl.trim() ?? '';

  // ============================================================
  // LOAD CURRENT USER BUSINESS
  // ============================================================

  Future<BusinessModel?> loadBusiness() async {
    if (_isLoading) {
      return _business;
    }

    _setLoading(true);
    _clearError();

    try {
      final BusinessModel? business =
          await _repository
              .getBusinessForCurrentUser();

      _business = business;

      return business;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to load business details.',
        ),
      );

      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // LOAD BUSINESS BY ID
  // ============================================================

  Future<BusinessModel?> loadBusinessById(
    String businessId,
  ) async {
    final String id = businessId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return null;
    }

    _setLoading(true);
    _clearError();

    try {
      final BusinessModel? business =
          await _repository.getBusiness(id);

      _business = business;

      return business;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to load business details.',
        ),
      );

      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // WATCH BUSINESS
  // ============================================================

  void watchBusiness(
    String businessId,
  ) {
    final String id = businessId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return;
    }

    _businessSubscription?.cancel();

    _clearError();

    _businessSubscription =
        _repository.watchBusiness(id).listen(
      (BusinessModel? business) {
        _business = business;
        notifyListeners();
      },
      onError: (Object error) {
        _setError(
          _formatError(
            error,
            fallback:
                'Unable to listen for business updates.',
          ),
        );
      },
    );
  }

  // ============================================================
  // WATCH CURRENT USER BUSINESS
  // ============================================================

  Future<void> watchCurrentUserBusiness() async {
    final BusinessModel? business =
        await loadBusiness();

    if (business == null) {
      return;
    }

    watchBusiness(business.id);
  }

  // ============================================================
  // UPDATE BUSINESS
  // ============================================================

  Future<bool> updateBusiness(
    BusinessModel business,
  ) async {
    final String id = business.id.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return false;
    }

    if (business.ownerId.trim().isEmpty) {
      _setError('Business owner ID is required.');
      return false;
    }

    if (business.businessName.trim().isEmpty) {
      _setError('Business name is required.');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      await _repository.updateBusiness(
        business,
      );

      final BusinessModel? updatedBusiness =
          await _repository.getBusiness(id);

      _business = updatedBusiness;

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to update business details.',
        ),
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // CHECK BUSINESS EXISTS
  // ============================================================

  Future<bool> checkBusinessExists(
    String ownerId,
  ) async {
    final String id = ownerId.trim();

    if (id.isEmpty) {
      _setError('Owner ID is required.');
      return false;
    }

    _clearError();

    try {
      return await _repository.hasBusiness(id);
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to check business profile.',
        ),
      );

      return false;
    }
  }

  // ============================================================
  // SET BUSINESS
  // ============================================================

  void setBusiness(
    BusinessModel? business,
  ) {
    _business = business;
    _clearError();
    notifyListeners();
  }

  // ============================================================
  // CLEAR BUSINESS
  // ============================================================

  void clearBusiness() {
    _business = null;
    _clearError();
    notifyListeners();
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<BusinessModel?> refresh() {
    return loadBusiness();
  }

  // ============================================================
  // ERROR HANDLING
  // ============================================================

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

  // ============================================================
  // LOADING STATE
  // ============================================================

  void _setLoading(
    bool value,
  ) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  // ============================================================
  // ERROR FORMATTER
  // ============================================================

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

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _businessSubscription?.cancel();
    super.dispose();
  }
}