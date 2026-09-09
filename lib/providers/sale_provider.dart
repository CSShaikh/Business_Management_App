import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sale_model.dart';
import '../repositories/sale_repository.dart';

class SaleProvider extends ChangeNotifier {
  SaleProvider({
    SaleRepository? repository,
  }) : _repository = repository ?? SaleRepository();

  final SaleRepository _repository;

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------

  List<SaleModel> _sales = [];

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;

  String _businessId = '';

  StreamSubscription<List<SaleModel>>?
      _saleSubscription;

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  List<SaleModel> get sales =>
      List.unmodifiable(_sales);

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get hasSales =>
      _sales.isNotEmpty;

  bool get isEmpty =>
      _sales.isEmpty;

  String? get errorMessage =>
      _errorMessage;

  String get businessId =>
      _businessId;

  int get saleCount =>
      _sales.length;

  double get totalSalesAmount {
    return _sales.fold<double>(
      0,
      (double total, SaleModel sale) =>
          total + sale.total,
    );
  }

  double get totalReceivedAmount {
    return _sales.fold<double>(
      0,
      (double total, SaleModel sale) =>
          total + sale.paidAmount,
    );
  }

  double get totalPendingAmount {
    return _sales.fold<double>(
      0,
      (double total, SaleModel sale) {
        final double pending =
            sale.total - sale.paidAmount;

        return total +
            (pending < 0 ? 0 : pending);
      },
    );
  }

  double get totalDiscount {
    return _sales.fold<double>(
      0,
      (double total, SaleModel sale) =>
          total + sale.discount,
    );
  }

  double get totalTax {
    return _sales.fold<double>(
      0,
      (double total, SaleModel sale) =>
          total + sale.tax,
    );
  }

  List<SaleModel> get paidSales {
    return _sales.where(
      (SaleModel sale) {
        return sale.paymentStatus
                .trim()
                .toLowerCase() ==
            'paid';
      },
    ).toList();
  }

  List<SaleModel> get partialSales {
    return _sales.where(
      (SaleModel sale) {
        return sale.paymentStatus
                .trim()
                .toLowerCase() ==
            'partial';
      },
    ).toList();
  }

  List<SaleModel> get unpaidSales {
    return _sales.where(
      (SaleModel sale) {
        final String status =
            sale.paymentStatus
                .trim()
                .toLowerCase();

        return status == 'unpaid' ||
            status == 'pending';
      },
    ).toList();
  }

  int get paidSaleCount =>
      paidSales.length;

  int get partialSaleCount =>
      partialSales.length;

  int get unpaidSaleCount =>
      unpaidSales.length;

  List<SaleModel> get todaySales {
    final DateTime now =
        DateTime.now();

    return _sales.where(
      (SaleModel sale) {
        return sale.date.year ==
                now.year &&
            sale.date.month ==
                now.month &&
            sale.date.day ==
                now.day;
      },
    ).toList();
  }

  double get todaySalesAmount {
    return todaySales.fold<double>(
      0,
      (double total, SaleModel sale) =>
          total + sale.total,
    );
  }

  double get todayReceivedAmount {
    return todaySales.fold<double>(
      0,
      (double total, SaleModel sale) =>
          total + sale.paidAmount,
    );
  }

  double get todayPendingAmount {
    return todaySales.fold<double>(
      0,
      (double total, SaleModel sale) {
        final double pending =
            sale.total - sale.paidAmount;

        return total +
            (pending < 0 ? 0 : pending);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUSINESS ID
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
      clearSales();
    }
  }

  // ---------------------------------------------------------------------------
  // LOAD SALES
  // ---------------------------------------------------------------------------

  Future<List<SaleModel>> loadSales({
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required to load sales.',
      );
      return [];
    }

    _businessId = id;

    _setLoading(true);
    _clearError();

    try {
      final List<SaleModel> sales =
          await _repository.getSales(
        businessId: id,
      );

      _sales =
          List<SaleModel>.from(
        sales,
      );

      return List<SaleModel>.from(
        _sales,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to load sales.',
        ),
      );

      return [];
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // WATCH SALES
  // ---------------------------------------------------------------------------

  void watchSales({
    String? businessId,
  }) {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required to watch sales.',
      );
      return;
    }

    _businessId = id;

    _saleSubscription?.cancel();

    _clearError();

    _saleSubscription =
        _repository
            .watchSales(
              businessId: id,
            )
            .listen(
      (
        List<SaleModel> sales,
      ) {
        _sales =
            List<SaleModel>.from(
          sales,
        );

        notifyListeners();
      },
      onError: (Object error) {
        _setError(
          _formatError(
            error,
            fallback:
                'Unable to receive sales updates.',
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // LOAD + WATCH
  // ---------------------------------------------------------------------------

  Future<void> loadAndWatchSales({
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

    await loadSales(
      businessId: id,
    );

    watchSales(
      businessId: id,
    );
  }

  // ---------------------------------------------------------------------------
  // GET SINGLE SALE
  // ---------------------------------------------------------------------------

  Future<SaleModel?> getSale({
    required String saleId,
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String saleDocumentId =
        saleId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return null;
    }

    if (saleDocumentId.isEmpty) {
      _setError(
        'Sale ID is required.',
      );
      return null;
    }

    _clearError();

    try {
      return await _repository.getSale(
        businessId: id,
        saleId: saleDocumentId,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to load sale details.',
        ),
      );

      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CREATE SALE
  // ---------------------------------------------------------------------------

  Future<SaleModel?> createSale(
    SaleModel sale,
  ) async {
    final String id =
        sale.businessId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return null;
    }

    if (sale.items.isEmpty) {
      _setError(
        'At least one sale item is required.',
      );
      return null;
    }

    if (sale.total < 0) {
      _setError(
        'Sale total cannot be negative.',
      );
      return null;
    }

    if (sale.paidAmount < 0) {
      _setError(
        'Paid amount cannot be negative.',
      );
      return null;
    }

    if (sale.paidAmount > sale.total) {
      _setError(
        'Paid amount cannot be greater than sale total.',
      );
      return null;
    }

    _businessId = id;

    _setSaving(true);
    _clearError();

    try {
      final SaleModel savedSale =
          await _repository.createSale(
        sale,
      );

      _upsertLocalSale(
        savedSale,
      );

      return savedSale;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to create sale.',
        ),
      );

      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE SALE
  // ---------------------------------------------------------------------------

  Future<bool> updateSale(
    SaleModel sale,
  ) async {
    final String id =
        sale.businessId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return false;
    }

    if (sale.id.trim().isEmpty) {
      _setError(
        'Sale ID is required.',
      );
      return false;
    }

    if (sale.items.isEmpty) {
      _setError(
        'At least one sale item is required.',
      );
      return false;
    }

    if (sale.total < 0) {
      _setError(
        'Sale total cannot be negative.',
      );
      return false;
    }

    if (sale.paidAmount < 0) {
      _setError(
        'Paid amount cannot be negative.',
      );
      return false;
    }

    if (sale.paidAmount > sale.total) {
      _setError(
        'Paid amount cannot be greater than sale total.',
      );
      return false;
    }

    _businessId = id;

    _setSaving(true);
    _clearError();

    try {
      await _repository.updateSale(
        sale,
      );

      _upsertLocalSale(
        sale,
      );

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to update sale.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE SALE
  // ---------------------------------------------------------------------------

  Future<bool> deleteSale({
    required String saleId,
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String saleDocumentId =
        saleId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return false;
    }

    if (saleDocumentId.isEmpty) {
      _setError(
        'Sale ID is required.',
      );
      return false;
    }

    _businessId = id;

    _setSaving(true);
    _clearError();

    try {
      await _repository.deleteSale(
        businessId: id,
        saleId: saleDocumentId,
      );

      _sales.removeWhere(
        (SaleModel sale) =>
            sale.id.trim() ==
            saleDocumentId,
      );

      notifyListeners();

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to delete sale.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE PAID AMOUNT
  // ---------------------------------------------------------------------------

  Future<bool> updatePaidAmount({
    required String saleId,
    required double paidAmount,
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String saleDocumentId =
        saleId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return false;
    }

    if (saleDocumentId.isEmpty) {
      _setError(
        'Sale ID is required.',
      );
      return false;
    }

    if (paidAmount < 0) {
      _setError(
        'Paid amount cannot be negative.',
      );
      return false;
    }

    final SaleModel? existingSale =
        findSaleById(
      saleDocumentId,
    );

    if (existingSale != null &&
        paidAmount > existingSale.total) {
      _setError(
        'Paid amount cannot be greater than sale total.',
      );
      return false;
    }

    _businessId = id;

    _setSaving(true);
    _clearError();

    try {
      await _repository.updatePaidAmount(
        businessId: id,
        saleId: saleDocumentId,
        paidAmount: paidAmount,
      );

      final int index =
          _sales.indexWhere(
        (SaleModel sale) =>
            sale.id.trim() ==
            saleDocumentId,
      );

      if (index != -1) {
        final SaleModel oldSale =
            _sales[index];

        final String newStatus =
            _calculatePaymentStatus(
          total: oldSale.total,
          paidAmount: paidAmount,
        );

        final SaleModel updatedSale =
            SaleModel(
          id: oldSale.id,
          businessId:
              oldSale.businessId,
          customerId:
              oldSale.customerId,
          customerName:
              oldSale.customerName,
          items: oldSale.items,
          subtotal:
              oldSale.subtotal,
          discount:
              oldSale.discount,
          tax: oldSale.tax,
          total: oldSale.total,
          paidAmount:
              paidAmount,
          paymentStatus:
              newStatus,
          paymentMethod:
              oldSale.paymentMethod,
          date: oldSale.date,
          notes: oldSale.notes,
          invoiceNumber:
              oldSale.invoiceNumber,
          createdAt:
              oldSale.createdAt,
        );

        _sales[index] =
            updatedSale;

        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to update sale payment.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // CUSTOMER SALES
  // ---------------------------------------------------------------------------

  Future<List<SaleModel>>
      getCustomerSales({
    required String customerId,
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String customerDocumentId =
        customerId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return [];
    }

    if (customerDocumentId.isEmpty) {
      _setError(
        'Customer ID is required.',
      );
      return [];
    }

    _clearError();

    try {
      return await _repository
          .getCustomerSales(
        businessId: id,
        customerId:
            customerDocumentId,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to load customer sales.',
        ),
      );

      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  Future<List<SaleModel>> searchSales(
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
      return await _repository.searchSales(
        businessId: id,
        query: query,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to search sales.',
        ),
      );

      return [];
    }
  }

  List<SaleModel> filterSales(
    String query,
  ) {
    final String normalized =
        query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return List<SaleModel>.from(
        _sales,
      );
    }

    return _sales.where(
      (SaleModel sale) {
        final String invoice =
            sale.invoiceNumber
                .trim()
                .toLowerCase();

        final String customer =
            sale.customerName
                .trim()
                .toLowerCase();

        final String customerId =
            sale.customerId
                .trim()
                .toLowerCase();

        final String status =
            sale.paymentStatus
                .trim()
                .toLowerCase();

        final String method =
            sale.paymentMethod
                .trim()
                .toLowerCase();

        final String notes =
            sale.notes
                .trim()
                .toLowerCase();

        final String products =
            sale.items
                .map(
                  (SaleItemModel item) =>
                      item.productName
                          .trim()
                          .toLowerCase(),
                )
                .join(' ');

        return invoice.contains(
              normalized,
            ) ||
            customer.contains(
              normalized,
            ) ||
            customerId.contains(
              normalized,
            ) ||
            status.contains(
              normalized,
            ) ||
            method.contains(
              normalized,
            ) ||
            notes.contains(
              normalized,
            ) ||
            products.contains(
              normalized,
            );
      },
    ).toList();
  }

  // ---------------------------------------------------------------------------
  // DATE FILTER
  // ---------------------------------------------------------------------------

  List<SaleModel> filterByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final DateTime start =
        DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final DateTime end =
        DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    return _sales.where(
      (SaleModel sale) {
        return !sale.date.isBefore(
              start,
            ) &&
            !sale.date.isAfter(
              end,
            );
      },
    ).toList();
  }

  // ---------------------------------------------------------------------------
  // CUSTOMER FILTER
  // ---------------------------------------------------------------------------

  List<SaleModel> filterByCustomer(
    String customerId,
  ) {
    final String id =
        customerId.trim();

    if (id.isEmpty) {
      return List<SaleModel>.from(
        _sales,
      );
    }

    return _sales.where(
      (SaleModel sale) =>
          sale.customerId.trim() == id,
    ).toList();
  }

  // ---------------------------------------------------------------------------
  // PAYMENT STATUS FILTER
  // ---------------------------------------------------------------------------

  List<SaleModel> filterByPaymentStatus(
    String status,
  ) {
    final String normalized =
        status.trim().toLowerCase();

    if (normalized.isEmpty) {
      return List<SaleModel>.from(
        _sales,
      );
    }

    return _sales.where(
      (SaleModel sale) =>
          sale.paymentStatus
              .trim()
              .toLowerCase() ==
          normalized,
    ).toList();
  }

  // ---------------------------------------------------------------------------
  // FIND SALE
  // ---------------------------------------------------------------------------

  SaleModel? findSaleById(
    String saleId,
  ) {
    final String id =
        saleId.trim();

    if (id.isEmpty) {
      return null;
    }

    for (final SaleModel sale
        in _sales) {
      if (sale.id.trim() == id) {
        return sale;
      }
    }

    return null;
  }

  SaleModel? findSaleByInvoice(
    String invoiceNumber,
  ) {
    final String invoice =
        invoiceNumber.trim().toLowerCase();

    if (invoice.isEmpty) {
      return null;
    }

    for (final SaleModel sale
        in _sales) {
      if (sale.invoiceNumber
              .trim()
              .toLowerCase() ==
          invoice) {
        return sale;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // CLEAR
  // ---------------------------------------------------------------------------

  void clearSales() {
    _saleSubscription?.cancel();

    _saleSubscription = null;

    _sales = [];

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> refresh() async {
    if (_businessId.trim().isEmpty) {
      return;
    }

    await loadSales(
      businessId: _businessId,
    );
  }

  // ---------------------------------------------------------------------------
  // LOCAL UPSERT
  // ---------------------------------------------------------------------------

  void _upsertLocalSale(
    SaleModel sale,
  ) {
    final String saleId =
        sale.id.trim();

    if (saleId.isEmpty) {
      return;
    }

    final int index =
        _sales.indexWhere(
      (SaleModel item) =>
          item.id.trim() == saleId,
    );

    if (index == -1) {
      _sales.add(sale);
    } else {
      _sales[index] = sale;
    }

    _sales.sort(
      (
        SaleModel a,
        SaleModel b,
      ) {
        return b.date.compareTo(
          a.date,
        );
      },
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PAYMENT STATUS
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
  // ERROR
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
  // DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _saleSubscription?.cancel();

    _saleSubscription = null;

    super.dispose();
  }
}