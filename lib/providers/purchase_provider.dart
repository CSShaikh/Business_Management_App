import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/purchase_model.dart';
import '../repositories/purchase_repository.dart';

class PurchaseProvider extends ChangeNotifier {
  PurchaseProvider({
    PurchaseRepository? repository,
  }) : _repository = repository ?? PurchaseRepository();

  final PurchaseRepository _repository;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  List<PurchaseModel> _purchases = [];

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;

  String _businessId = '';

  StreamSubscription<List<PurchaseModel>>?
      _purchaseSubscription;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  List<PurchaseModel> get purchases =>
      List.unmodifiable(_purchases);

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get hasPurchases =>
      _purchases.isNotEmpty;

  bool get isEmpty =>
      _purchases.isEmpty;

  String? get errorMessage =>
      _errorMessage;

  String get businessId =>
      _businessId;

  int get purchaseCount =>
      _purchases.length;

  double get totalPurchaseAmount {
    return _purchases.fold<double>(
      0,
      (total, purchase) =>
          total + purchase.total,
    );
  }

  double get totalPaidAmount {
    return _purchases.fold<double>(
      0,
      (total, purchase) =>
          total + purchase.paidAmount,
    );
  }

  double get totalOutstandingAmount {
    return _purchases.fold<double>(
      0,
      (total, purchase) =>
          total +
          (purchase.total -
              purchase.paidAmount),
    );
  }

  int get paidPurchaseCount {
    return _purchases
        .where(
          (purchase) =>
              purchase.paymentStatus
                  .toLowerCase() ==
              'paid',
        )
        .length;
  }

  int get partialPurchaseCount {
    return _purchases
        .where(
          (purchase) =>
              purchase.paymentStatus
                  .toLowerCase() ==
              'partial',
        )
        .length;
  }

  int get unpaidPurchaseCount {
    return _purchases
        .where(
          (purchase) =>
              purchase.paymentStatus
                      .toLowerCase() ==
                  'unpaid' ||
              purchase.paymentStatus
                      .toLowerCase() ==
                  'pending',
        )
        .length;
  }

  List<PurchaseModel> get paidPurchases {
    return _purchases
        .where(
          (purchase) =>
              purchase.paymentStatus
                  .toLowerCase() ==
              'paid',
        )
        .toList();
  }

  List<PurchaseModel> get partialPurchases {
    return _purchases
        .where(
          (purchase) =>
              purchase.paymentStatus
                  .toLowerCase() ==
              'partial',
        )
        .toList();
  }

  List<PurchaseModel> get unpaidPurchases {
    return _purchases
        .where(
          (purchase) {
            final String status =
                purchase.paymentStatus
                    .trim()
                    .toLowerCase();

            return status == 'unpaid' ||
                status == 'pending';
          },
        )
        .toList();
  }

  List<PurchaseModel> get todayPurchases {
    final DateTime now = DateTime.now();

    return _purchases
        .where(
          (purchase) =>
              purchase.date.year ==
                  now.year &&
              purchase.date.month ==
                  now.month &&
              purchase.date.day ==
                  now.day,
        )
        .toList();
  }

  double get todayPurchaseAmount {
    return todayPurchases.fold<double>(
      0,
      (total, purchase) =>
          total + purchase.total,
    );
  }

  // ---------------------------------------------------------------------------
  // Business ID
  // ---------------------------------------------------------------------------

  void setBusinessId(
    String businessId,
  ) {
    final String id =
        businessId.trim();

    if (_businessId == id) {
      return;
    }

    _businessId = id;

    if (id.isEmpty) {
      clearPurchases();
    }
  }

  // ---------------------------------------------------------------------------
  // Load purchases
  // ---------------------------------------------------------------------------

  Future<List<PurchaseModel>> loadPurchases({
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required to load purchases.',
      );
      return [];
    }

    _businessId = id;

    _setLoading(true);
    _clearError();

    try {
      final List<PurchaseModel> purchases =
          await _repository.getPurchases(
        businessId: id,
      );

      _purchases =
          List<PurchaseModel>.from(
        purchases,
      );

      return List<PurchaseModel>.from(
        _purchases,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to load purchases.',
        ),
      );

      return [];
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Watch purchases
  // ---------------------------------------------------------------------------

  void watchPurchases({
    String? businessId,
  }) {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required to watch purchases.',
      );
      return;
    }

    _businessId = id;

    _purchaseSubscription?.cancel();

    _clearError();

    _purchaseSubscription =
        _repository
            .watchPurchases(
              businessId: id,
            )
            .listen(
      (
        List<PurchaseModel> purchases,
      ) {
        _purchases =
            List<PurchaseModel>.from(
          purchases,
        );

        notifyListeners();
      },
      onError: (Object error) {
        _setError(
          _formatError(
            error,
            fallback:
                'Unable to receive purchase updates.',
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Load + Watch
  // ---------------------------------------------------------------------------

  Future<void> loadAndWatchPurchases({
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return;
    }

    await loadPurchases(
      businessId: id,
    );

    watchPurchases(
      businessId: id,
    );
  }

  // ---------------------------------------------------------------------------
  // Get single purchase
  // ---------------------------------------------------------------------------

  Future<PurchaseModel?> getPurchase({
    required String purchaseId,
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String purchaseDocumentId =
        purchaseId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return null;
    }

    if (purchaseDocumentId.isEmpty) {
      _setError(
        'Purchase ID is required.',
      );
      return null;
    }

    _clearError();

    try {
      return await _repository.getPurchase(
        businessId: id,
        purchaseId: purchaseDocumentId,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to load purchase details.',
        ),
      );

      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Create purchase
  // ---------------------------------------------------------------------------

  Future<PurchaseModel?> createPurchase(
    PurchaseModel purchase,
  ) async {
    final String id =
        purchase.businessId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return null;
    }

    if (purchase.items.isEmpty) {
      _setError(
        'At least one purchase item is required.',
      );
      return null;
    }

    if (purchase.total < 0) {
      _setError(
        'Purchase total cannot be negative.',
      );
      return null;
    }

    if (purchase.paidAmount < 0) {
      _setError(
        'Paid amount cannot be negative.',
      );
      return null;
    }

    if (purchase.paidAmount >
        purchase.total) {
      _setError(
        'Paid amount cannot be greater than purchase total.',
      );
      return null;
    }

    _businessId = id;

    _setSaving(true);
    _clearError();

    try {
      final PurchaseModel savedPurchase =
          await _repository.createPurchase(
        purchase,
      );

      _upsertLocalPurchase(
        savedPurchase,
      );

      return savedPurchase;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to create purchase.',
        ),
      );

      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Update purchase
  // ---------------------------------------------------------------------------

  Future<bool> updatePurchase(
    PurchaseModel purchase,
  ) async {
    final String id =
        purchase.businessId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return false;
    }

    if (purchase.id.trim().isEmpty) {
      _setError(
        'Purchase ID is required.',
      );
      return false;
    }

    if (purchase.items.isEmpty) {
      _setError(
        'At least one purchase item is required.',
      );
      return false;
    }

    if (purchase.total < 0) {
      _setError(
        'Purchase total cannot be negative.',
      );
      return false;
    }

    if (purchase.paidAmount < 0) {
      _setError(
        'Paid amount cannot be negative.',
      );
      return false;
    }

    if (purchase.paidAmount >
        purchase.total) {
      _setError(
        'Paid amount cannot be greater than purchase total.',
      );
      return false;
    }

    _businessId = id;

    _setSaving(true);
    _clearError();

    try {
      await _repository.updatePurchase(
        purchase,
      );

      _upsertLocalPurchase(
        purchase,
      );

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to update purchase.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Delete purchase
  // ---------------------------------------------------------------------------

  Future<bool> deletePurchase({
    required String purchaseId,
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String purchaseDocumentId =
        purchaseId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return false;
    }

    if (purchaseDocumentId.isEmpty) {
      _setError(
        'Purchase ID is required.',
      );
      return false;
    }

    _businessId = id;

    _setSaving(true);
    _clearError();

    try {
      await _repository.deletePurchase(
        businessId: id,
        purchaseId: purchaseDocumentId,
      );

      _purchases.removeWhere(
        (purchase) =>
            purchase.id.trim() ==
            purchaseDocumentId,
      );

      notifyListeners();

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to delete purchase.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Update paid amount
  // ---------------------------------------------------------------------------

  Future<bool> updatePaidAmount({
    required String purchaseId,
    required double paidAmount,
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String purchaseDocumentId =
        purchaseId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return false;
    }

    if (purchaseDocumentId.isEmpty) {
      _setError(
        'Purchase ID is required.',
      );
      return false;
    }

    if (paidAmount < 0) {
      _setError(
        'Paid amount cannot be negative.',
      );
      return false;
    }

    _businessId = id;

    _setSaving(true);
    _clearError();

    try {
      await _repository.updatePaidAmount(
        businessId: id,
        purchaseId: purchaseDocumentId,
        paidAmount: paidAmount,
      );

      final int index =
          _purchases.indexWhere(
        (purchase) =>
            purchase.id.trim() ==
            purchaseDocumentId,
      );

      if (index != -1) {
        final PurchaseModel oldPurchase =
            _purchases[index];

        final String newStatus =
            _calculatePaymentStatus(
          total: oldPurchase.total,
          paidAmount: paidAmount,
        );

        final PurchaseModel updated =
            PurchaseModel(
          id: oldPurchase.id,
          businessId:
              oldPurchase.businessId,
          supplierId:
              oldPurchase.supplierId,
          supplierName:
              oldPurchase.supplierName,
          items: oldPurchase.items,
          subtotal:
              oldPurchase.subtotal,
          discount:
              oldPurchase.discount,
          tax: oldPurchase.tax,
          total: oldPurchase.total,
          paidAmount: paidAmount,
          paymentStatus: newStatus,
          paymentMethod:
              oldPurchase.paymentMethod,
          date: oldPurchase.date,
          notes: oldPurchase.notes,
          createdAt:
              oldPurchase.createdAt,
        );

        _purchases[index] =
            updated;

        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to update purchase payment.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Supplier purchases
  // ---------------------------------------------------------------------------

  Future<List<PurchaseModel>>
      getSupplierPurchases({
    required String supplierId,
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String supplierDocumentId =
        supplierId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return [];
    }

    if (supplierDocumentId.isEmpty) {
      _setError(
        'Supplier ID is required.',
      );
      return [];
    }

    _clearError();

    try {
      return await _repository
          .getSupplierPurchases(
        businessId: id,
        supplierId: supplierDocumentId,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to load supplier purchases.',
        ),
      );

      return [];
    }
  }

  void watchSupplierPurchases({
    required String supplierId,
    String? businessId,
    void Function(
      List<PurchaseModel>,
    )?
        onData,
  }) {
    final String id =
        (businessId ?? _businessId).trim();

    final String supplierDocumentId =
        supplierId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return;
    }

    if (supplierDocumentId.isEmpty) {
      _setError(
        'Supplier ID is required.',
      );
      return;
    }

    _clearError();

    _purchaseSubscription?.cancel();

    _purchaseSubscription =
        _repository
            .watchSupplierPurchases(
              businessId: id,
              supplierId:
                  supplierDocumentId,
            )
            .listen(
      (
        List<PurchaseModel> purchases,
      ) {
        onData?.call(
          List<PurchaseModel>.from(
            purchases,
          ),
        );
      },
      onError: (Object error) {
        _setError(
          _formatError(
            error,
            fallback:
                'Unable to receive supplier purchase updates.',
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  Future<List<PurchaseModel>>
      searchPurchases(
    String query, {
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return [];
    }

    _clearError();

    try {
      return await _repository
          .searchPurchases(
        businessId: id,
        query: query,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to search purchases.',
        ),
      );

      return [];
    }
  }

  List<PurchaseModel> filterPurchases(
    String query,
  ) {
    final String normalized =
        query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return List<PurchaseModel>.from(
        _purchases,
      );
    }

    return _purchases.where(
      (purchase) {
        final String supplierName =
            purchase.supplierName
                .trim()
                .toLowerCase();

        final String supplierId =
            purchase.supplierId
                .trim()
                .toLowerCase();

        final String paymentStatus =
            purchase.paymentStatus
                .trim()
                .toLowerCase();

        final String paymentMethod =
            purchase.paymentMethod
                .trim()
                .toLowerCase();

        final String notes =
            purchase.notes
                .trim()
                .toLowerCase();

        final String productNames =
            purchase.items
                .map(
                  (item) => item.productName
                      .trim()
                      .toLowerCase(),
                )
                .join(' ');

        return supplierName
                .contains(normalized) ||
            supplierId.contains(normalized) ||
            paymentStatus
                .contains(normalized) ||
            paymentMethod
                .contains(normalized) ||
            notes.contains(normalized) ||
            productNames
                .contains(normalized);
      },
    ).toList();
  }

  // ---------------------------------------------------------------------------
  // Date filtering
  // ---------------------------------------------------------------------------

  List<PurchaseModel> filterByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final DateTime start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final DateTime end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    return _purchases.where(
      (purchase) {
        return !purchase.date.isBefore(
              start,
            ) &&
            !purchase.date.isAfter(
              end,
            );
      },
    ).toList();
  }

  // ---------------------------------------------------------------------------
  // Find purchase
  // ---------------------------------------------------------------------------

  PurchaseModel? findPurchaseById(
    String purchaseId,
  ) {
    final String id =
        purchaseId.trim();

    if (id.isEmpty) {
      return null;
    }

    for (final purchase in _purchases) {
      if (purchase.id.trim() == id) {
        return purchase;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Clear
  // ---------------------------------------------------------------------------

  void clearPurchases() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;

    _purchases = [];

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  Future<void> refresh() async {
    if (_businessId.trim().isEmpty) {
      return;
    }

    await loadPurchases(
      businessId: _businessId,
    );
  }

  // ---------------------------------------------------------------------------
  // Local state helper
  // ---------------------------------------------------------------------------

  void _upsertLocalPurchase(
    PurchaseModel purchase,
  ) {
    final String purchaseId =
        purchase.id.trim();

    if (purchaseId.isEmpty) {
      return;
    }

    final int index =
        _purchases.indexWhere(
      (item) =>
          item.id.trim() ==
          purchaseId,
    );

    if (index == -1) {
      _purchases.add(purchase);
    } else {
      _purchases[index] = purchase;
    }

    _purchases.sort(
      (
        PurchaseModel a,
        PurchaseModel b,
      ) =>
          b.date.compareTo(a.date),
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Payment status helper
  // ---------------------------------------------------------------------------

  String _calculatePaymentStatus({
    required double total,
    required double paidAmount,
  }) {
    const double tolerance =
        0.000001;

    if (total <= tolerance) {
      return 'Paid';
    }

    if (paidAmount <= tolerance) {
      return 'Unpaid';
    }

    if (paidAmount >=
        total - tolerance) {
      return 'Paid';
    }

    return 'Partial';
  }

  // ---------------------------------------------------------------------------
  // Loading / saving
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
  // Error handling
  // ---------------------------------------------------------------------------

  void _clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;

    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  void _setError(
    String message,
  ) {
    final String cleaned =
        message.trim();

    _errorMessage =
        cleaned.isEmpty
            ? 'Something went wrong.'
            : cleaned;

    notifyListeners();
  }

  String _formatError(
    Object error, {
    required String fallback,
  }) {
    final String message =
        error.toString().trim();

    if (message.isEmpty) {
      return fallback;
    }

    if (message.startsWith(
      'Exception:',
    )) {
      final String cleaned =
          message
              .replaceFirst(
                'Exception:',
                '',
              )
              .trim();

      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    return message;
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;

    super.dispose();
  }
}