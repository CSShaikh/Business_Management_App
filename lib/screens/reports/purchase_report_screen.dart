import 'dart:typed_data';

import '../../core/widgets/app_date_picker.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:public_file_saver/public_file_saver.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/purchase_model.dart';
import '../../models/supplier_payment_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/purchase_repository.dart';
import '../../repositories/supplier_payment_repository.dart';

class PurchaseReportScreen extends StatefulWidget {
  const PurchaseReportScreen({super.key});

  @override
  State<PurchaseReportScreen> createState() => _PurchaseReportScreenState();
}

class _PurchaseReportScreenState extends State<PurchaseReportScreen> {
  final BusinessRepository _businessRepository = BusinessRepository();

  final PurchaseRepository _purchaseRepository = PurchaseRepository();

  final SupplierPaymentRepository _supplierPaymentRepository =
      SupplierPaymentRepository();

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _refreshing = false;
  bool _downloadingPdf = false;

  BusinessModel? _business;

  String? _errorMessage;

  String _searchQuery = '';
  String _paymentFilter = 'All';

  DateTime? _startDate;
  DateTime? _endDate;

  List<PurchaseModel> _allPurchases = <PurchaseModel>[];

  List<SupplierPaymentModel> _allSupplierPayments = <SupplierPaymentModel>[];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // LOAD REPORT
  // ===========================================================================

  Future<void> _loadReport({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _refreshing = true;
        _errorMessage = null;
      });
    }

    try {
      final business = await _businessRepository.getBusinessForCurrentUser();

      if (business == null) {
        throw Exception('Business information is not available.');
      }

      final List<PurchaseModel> purchases = await _purchaseRepository
          .getPurchases(businessId: business.id);

      final List<SupplierPaymentModel> supplierPayments =
          await _supplierPaymentRepository.getPayments(businessId: business.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _business = business;
        _allPurchases = purchases;
        _allSupplierPayments = supplierPayments;
        _loading = false;
        _refreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _refreshing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _refreshReport() async {
    await _loadReport(showLoader: false);
  }

  // ===========================================================================
  // DATE FILTER
  // ===========================================================================

  Future<void> _selectDateRange() async {
    final DateTime now = DateTime.now();

    final DateTimeRange? selected = await AppDatePicker.showDateRangePicker(
      context: context,

      initialEntryMode: DatePickerEntryMode.calendar,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      helpText: 'Select Purchase Report Period',
      saveText: 'Apply',
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _startDate = DateTime(
        selected.start.year,
        selected.start.month,
        selected.start.day,
      );

      _endDate = DateTime(
        selected.end.year,
        selected.end.month,
        selected.end.day,
        23,
        59,
        59,
        999,
      );
    });
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  void _setDateRange(DateTime start, DateTime end) {
    setState(() {
      _startDate = DateTime(start.year, start.month, start.day);
      _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    });
  }

  void _setToday() {
    final DateTime now = DateTime.now();
    _setDateRange(now, now);
  }

  void _setThisWeek() {
    final DateTime now = DateTime.now();
    final DateTime start = now.subtract(
      Duration(days: now.weekday - DateTime.monday),
    );
    _setDateRange(start, now);
  }

  void _setThisMonth() {
    final DateTime now = DateTime.now();
    _setDateRange(DateTime(now.year, now.month, 1), now);
  }

  void _setLastMonth() {
    final DateTime now = DateTime.now();
    _setDateRange(
      DateTime(now.year, now.month - 1, 1),
      DateTime(now.year, now.month, 0),
    );
  }

  // ===========================================================================
  // FILTERED PURCHASES
  // ===========================================================================

  List<PurchaseModel> get _filteredPurchases {
    final String query = _searchQuery.trim().toLowerCase();

    final List<PurchaseModel> result = _allPurchases.where((purchase) {
      if (_startDate != null && purchase.date.isBefore(_startDate!)) {
        return false;
      }

      if (_endDate != null && purchase.date.isAfter(_endDate!)) {
        return false;
      }

      if (_paymentFilter != 'All' &&
          purchase.paymentStatus.toLowerCase() !=
              _paymentFilter.toLowerCase()) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final bool supplierMatch = purchase.supplierName.toLowerCase().contains(
        query,
      );

      final bool notesMatch = purchase.notes.toLowerCase().contains(query);

      final bool productMatch = purchase.items.any((item) {
        return item.productName.toLowerCase().contains(query);
      });

      final bool idMatch = purchase.id.toLowerCase().contains(query);

      return supplierMatch || notesMatch || productMatch || idMatch;
    }).toList();

    result.sort((a, b) => b.date.compareTo(a.date));

    return result;
  }

  // ===========================================================================
  // FILTERED SUPPLIER PAYMENTS
  // ===========================================================================

  List<SupplierPaymentModel> get _filteredSupplierPayments {
    final String query = _searchQuery.trim().toLowerCase();

    final List<SupplierPaymentModel> result = _allSupplierPayments.where((
      payment,
    ) {
      if (_startDate != null && payment.date.isBefore(_startDate!)) {
        return false;
      }

      if (_endDate != null && payment.date.isAfter(_endDate!)) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return payment.supplierName.toLowerCase().contains(query) ||
          payment.paymentMethod.toLowerCase().contains(query) ||
          payment.transactionReference.toLowerCase().contains(query) ||
          payment.notes.toLowerCase().contains(query) ||
          payment.id.toLowerCase().contains(query);
    }).toList();

    result.sort((a, b) => b.date.compareTo(a.date));

    return result;
  }

  // ===========================================================================
  // CALCULATIONS
  // ===========================================================================

  double _totalPurchases(List<PurchaseModel> purchases) {
    return purchases.fold<double>(0, (sum, purchase) => sum + purchase.total);
  }

  double _totalSupplierPayments(List<SupplierPaymentModel> payments) {
    return payments.fold<double>(0, (sum, payment) => sum + payment.amount);
  }

  double _totalPaid(
    List<PurchaseModel> purchases,
    List<SupplierPaymentModel> payments,
  ) {
    final double purchasePaid = purchases.fold<double>(
      0,
      (sum, purchase) => sum + purchase.paidAmount,
    );

    return purchasePaid + _totalSupplierPayments(payments);
  }

  double _totalOutstanding(
    List<PurchaseModel> purchases,
    List<SupplierPaymentModel> payments,
  ) {
    final double outstanding =
        _totalPurchases(purchases) - _totalPaid(purchases, payments);

    return outstanding > 0 ? outstanding : 0;
  }

  double _totalDiscount(List<PurchaseModel> purchases) {
    return purchases.fold<double>(
      0,
      (sum, purchase) => sum + purchase.discount,
    );
  }

  double _totalTax(List<PurchaseModel> purchases) {
    return purchases.fold<double>(0, (sum, purchase) => sum + purchase.tax);
  }

  double _totalQuantity(List<PurchaseModel> purchases) {
    double total = 0;

    for (final purchase in purchases) {
      for (final item in purchase.items) {
        total += item.quantity;
      }
    }

    return total;
  }

  double _paymentRate(
    List<PurchaseModel> purchases,
    List<SupplierPaymentModel> payments,
  ) {
    final double total = _totalPurchases(purchases);

    if (total <= 0) {
      return 0;
    }

    return (_totalPaid(purchases, payments) / total) * 100;
  }

  // ===========================================================================
  // STATUS
  // ===========================================================================

  int _countStatus(List<PurchaseModel> purchases, String status) {
    return purchases.where((purchase) {
      return purchase.paymentStatus.toLowerCase() == status.toLowerCase();
    }).length;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppColors.success;

      case 'partial':
        return AppColors.warning;

      case 'unpaid':
        return AppColors.danger;

      default:
        return AppColors.info;
    }
  }

  // ===========================================================================
  // SUPPLIER-WISE
  // ===========================================================================

  Map<String, _SupplierPurchaseSummary> _supplierWisePurchases(
    List<PurchaseModel> purchases,
    List<SupplierPaymentModel> payments,
  ) {
    final Map<String, _SupplierPurchaseSummary> result =
        <String, _SupplierPurchaseSummary>{};

    for (final purchase in purchases) {
      final String supplierId = purchase.supplierId.trim();

      final String supplierName = purchase.supplierName.trim().isEmpty
          ? 'Unknown Supplier'
          : purchase.supplierName.trim();

      final String key = supplierId.isEmpty
          ? 'name:$supplierName'
          : 'id:$supplierId';

      final _SupplierPurchaseSummary existing =
          result[key] ?? _SupplierPurchaseSummary(name: supplierName);

      final double purchaseOutstanding = purchase.total - purchase.paidAmount;

      result[key] = _SupplierPurchaseSummary(
        name: supplierName,
        purchases: existing.purchases + purchase.total,
        paid: existing.paid + purchase.paidAmount,
        outstanding:
            existing.outstanding +
            (purchaseOutstanding > 0 ? purchaseOutstanding : 0),
        invoiceCount: existing.invoiceCount + 1,
      );
    }

    for (final payment in payments) {
      final String supplierId = payment.supplierId.trim();

      final String supplierName = payment.supplierName.trim().isEmpty
          ? 'Unknown Supplier'
          : payment.supplierName.trim();

      final String key = supplierId.isEmpty
          ? 'name:$supplierName'
          : 'id:$supplierId';

      final _SupplierPurchaseSummary existing =
          result[key] ?? _SupplierPurchaseSummary(name: supplierName);

      final double updatedOutstanding = existing.outstanding - payment.amount;

      result[key] = _SupplierPurchaseSummary(
        name: existing.name.isEmpty ? supplierName : existing.name,
        purchases: existing.purchases,
        paid: existing.paid + payment.amount,
        outstanding: updatedOutstanding > 0 ? updatedOutstanding : 0,
        invoiceCount: existing.invoiceCount,
      );
    }

    final List<_SupplierPurchaseSummary> values = result.values.toList();

    values.sort((a, b) => b.purchases.compareTo(a.purchases));

    return <String, _SupplierPurchaseSummary>{
      for (int index = 0; index < values.length; index++)
        '$index': values[index],
    };
  }

  // ===========================================================================
  // PRODUCT-WISE
  // ===========================================================================

  Map<String, _ProductPurchaseSummary> _productWisePurchases(
    List<PurchaseModel> purchases,
  ) {
    final Map<String, _ProductPurchaseSummary> result =
        <String, _ProductPurchaseSummary>{};

    for (final purchase in purchases) {
      for (final item in purchase.items) {
        final String productName = item.productName.trim().isEmpty
            ? 'Unknown Product'
            : item.productName.trim();

        final _ProductPurchaseSummary existing =
            result[productName] ?? _ProductPurchaseSummary(name: productName);

        result[productName] = _ProductPurchaseSummary(
          name: productName,
          quantity: existing.quantity + item.quantity,
          amount: existing.amount + item.total,
          invoiceCount: existing.invoiceCount + 1,
          unit: item.unit,
        );
      }
    }

    return result;
  }

  // ===========================================================================
  // FORMATTING
  // ===========================================================================

  String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  String _number(double value) {
    return NumberFormat('#,##0.##', 'en_IN').format(value);
  }

  String _date(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _dateRangeText() {
    if (_startDate == null || _endDate == null) {
      return 'All Dates';
    }

    return '${DateFormat('dd MMM yyyy').format(_startDate!)}'
        ' → '
        '${DateFormat('dd MMM yyyy').format(_endDate!)}';
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Purchase Report'),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            onPressed: _loading || _downloadingPdf ? null : _downloadPdf,
            icon: _downloadingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _refreshReport,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState(theme)
          : _buildPurchaseReportBody(theme),
    );
  }

  Widget _buildPurchaseReportBody(ThemeData theme) {
    final List<PurchaseModel> purchases = _filteredPurchases;
    final List<SupplierPaymentModel> supplierPayments =
        _filteredSupplierPayments;

    return RefreshIndicator(
      onRefresh: _refreshReport,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth >= 1000;
          final bool isTablet =
              constraints.maxWidth >= 650 && constraints.maxWidth < 1000;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop
                  ? 28
                  : isTablet
                  ? 22
                  : 16,
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1250),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(theme, isDesktop),
                    const SizedBox(height: 20),
                    _buildDateFilter(theme),
                    const SizedBox(height: 20),
                    _buildSummaryCards(
                      theme,
                      purchases,
                      supplierPayments,
                      isDesktop,
                    ),
                    const SizedBox(height: 20),
                    _buildPaymentStatus(theme, purchases),
                    const SizedBox(height: 20),
                    _buildSearchAndFilters(theme),
                    const SizedBox(height: 20),
                    _buildSupplierWiseSection(
                      theme,
                      purchases,
                      supplierPayments,
                    ),
                    const SizedBox(height: 20),
                    _buildProductWiseSection(theme, purchases),
                    const SizedBox(height: 20),
                    _buildPurchaseList(theme, purchases),
                    const SizedBox(height: 20),
                    _buildFooter(theme, purchases, supplierPayments),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(ThemeData theme, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 26 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shopping_cart_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Purchase Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Analyze purchases, supplier payments and inventory buying.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    _dateRangeText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DATE FILTER
  // ===========================================================================

  Widget _buildDateFilter(ThemeData theme) {
    final bool hasFilter = _startDate != null && _endDate != null;

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.date_range_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reporting Period',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _dateRangeText(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasFilter)
                IconButton(
                  tooltip: 'Clear date filter',
                  onPressed: _clearDateFilter,
                  icon: const Icon(Icons.clear_rounded),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DatePresetButton(label: 'Today', onPressed: _setToday),
              _DatePresetButton(label: 'This Week', onPressed: _setThisWeek),
              _DatePresetButton(label: 'This Month', onPressed: _setThisMonth),
              _DatePresetButton(label: 'Last Month', onPressed: _setLastMonth),
              _DatePresetButton(
                label: 'All Dates',
                onPressed: _clearDateFilter,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _selectDateRange,
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(
                hasFilter ? 'Change Date Range' : 'Select Date Range',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummaryCards(
    ThemeData theme,
    List<PurchaseModel> purchases,
    List<SupplierPaymentModel> supplierPayments,
    bool isDesktop,
  ) {
    final List<_SummaryItem> items = [
      _SummaryItem(
        title: 'Total Purchases',
        value: _currency(_totalPurchases(purchases)),
        subtitle:
            '${purchases.length} purchase${purchases.length == 1 ? '' : 's'}',
        icon: Icons.shopping_cart_checkout_rounded,
        color: AppColors.primary,
      ),
      _SummaryItem(
        title: 'Total Paid',
        value: _currency(_totalPaid(purchases, supplierPayments)),
        subtitle:
            '${_paymentRate(purchases, supplierPayments).toStringAsFixed(1)}% paid',
        icon: Icons.payments_rounded,
        color: AppColors.success,
      ),
      _SummaryItem(
        title: 'Outstanding',
        value: _currency(_totalOutstanding(purchases, supplierPayments)),
        subtitle: 'Supplier payable',
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.warning,
      ),
      _SummaryItem(
        title: 'Total Quantity',
        value: _number(_totalQuantity(purchases)),
        subtitle: 'Items purchased',
        icon: Icons.inventory_2_rounded,
        color: AppColors.secondary,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 4 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: isDesktop ? 180 : 156,
      ),
      itemBuilder: (context, index) {
        return _SummaryCard(item: items[index]);
      },
    );
  }

  // ===========================================================================
  // PAYMENT STATUS
  // ===========================================================================

  Widget _buildPaymentStatus(ThemeData theme, List<PurchaseModel> purchases) {
    final List<_StatusItem> items = [
      _StatusItem(
        label: 'Paid',
        count: _countStatus(purchases, 'Paid'),
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
      ),
      _StatusItem(
        label: 'Partial',
        count: _countStatus(purchases, 'Partial'),
        color: AppColors.warning,
        icon: Icons.timelapse_rounded,
      ),
      _StatusItem(
        label: 'Unpaid',
        count: _countStatus(purchases, 'Unpaid'),
        color: AppColors.danger,
        icon: Icons.pending_actions_rounded,
      ),
    ];

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.payments_outlined,
            title: 'Payment Status',
            subtitle: 'Supplier payment breakdown',
          ),

          const SizedBox(height: 18),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _StatusTile(item: item),
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: items
                    .map(
                      (item) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _StatusTile(item: item),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Widget _buildSearchAndFilters(ThemeData theme) {
    return _ReportCard(
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search supplier, product, purchase ID or notes...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();

                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear_rounded),
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 14),

          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _paymentFilter == 'All',
                  onSelected: () {
                    setState(() {
                      _paymentFilter = 'All';
                    });
                  },
                ),

                _FilterChip(
                  label: 'Paid',
                  selected: _paymentFilter == 'Paid',
                  color: AppColors.success,
                  onSelected: () {
                    setState(() {
                      _paymentFilter = 'Paid';
                    });
                  },
                ),

                _FilterChip(
                  label: 'Partial',
                  selected: _paymentFilter == 'Partial',
                  color: AppColors.warning,
                  onSelected: () {
                    setState(() {
                      _paymentFilter = 'Partial';
                    });
                  },
                ),

                _FilterChip(
                  label: 'Unpaid',
                  selected: _paymentFilter == 'Unpaid',
                  color: AppColors.danger,
                  onSelected: () {
                    setState(() {
                      _paymentFilter = 'Unpaid';
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUPPLIER WISE
  // ===========================================================================

  Widget _buildSupplierWiseSection(
    ThemeData theme,
    List<PurchaseModel> purchases,
    List<SupplierPaymentModel> supplierPayments,
  ) {
    final List<_SupplierPurchaseSummary> suppliers = _supplierWisePurchases(
      purchases,
      supplierPayments,
    ).values.toList();

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.local_shipping_rounded,
            title: 'Supplier-wise Purchases',
            subtitle: 'Purchase and payment summary by supplier',
          ),

          const SizedBox(height: 18),

          if (suppliers.isEmpty)
            const _EmptyInline(
              icon: Icons.local_shipping_outlined,
              message:
                  'No supplier purchases available for the selected filters.',
            )
          else
            ...suppliers.take(15).map((supplier) {
              return _SupplierTile(summary: supplier, currency: _currency);
            }),
        ],
      ),
    );
  }

  // ===========================================================================
  // PRODUCT WISE
  // ===========================================================================

  Widget _buildProductWiseSection(
    ThemeData theme,
    List<PurchaseModel> purchases,
  ) {
    final List<_ProductPurchaseSummary> products = _productWisePurchases(
      purchases,
    ).values.toList()..sort((a, b) => b.amount.compareTo(a.amount));

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.inventory_2_rounded,
            title: 'Product-wise Purchases',
            subtitle: 'Quantity and purchase amount by product',
          ),

          const SizedBox(height: 18),

          if (products.isEmpty)
            const _EmptyInline(
              icon: Icons.inventory_2_outlined,
              message:
                  'No product purchases available for the selected filters.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 650) {
                  return Column(
                    children: products
                        .take(15)
                        .map(
                          (product) => _ProductTile(
                            summary: product,
                            currency: _currency,
                            number: _number,
                          ),
                        )
                        .toList(),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 28,
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Quantity')),
                      DataColumn(label: Text('Purchase Amount')),
                      DataColumn(label: Text('Purchases')),
                    ],
                    rows: products.take(20).map((product) {
                      return DataRow(
                        cells: [
                          DataCell(Text(product.name)),
                          DataCell(
                            Text(
                              '${_number(product.quantity)} ${product.unit}',
                            ),
                          ),
                          DataCell(Text(_currency(product.amount))),
                          DataCell(Text(product.invoiceCount.toString())),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PURCHASE LIST
  // ===========================================================================

  Widget _buildPurchaseList(ThemeData theme, List<PurchaseModel> purchases) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.receipt_long_rounded,
            title: 'Purchase-wise Details',
            subtitle:
                '${purchases.length} matching purchase${purchases.length == 1 ? '' : 's'}',
          ),

          const SizedBox(height: 18),

          if (purchases.isEmpty)
            const _EmptyInline(
              icon: Icons.receipt_long_outlined,
              message: 'No purchases found for the selected filters.',
            )
          else
            ...purchases.map((purchase) {
              return _PurchaseTile(
                purchase: purchase,
                currency: _currency,
                date: _date,
                statusColor: _statusColor,
                onTap: () {
                  _showPurchaseDetails(purchase);
                },
              );
            }),
        ],
      ),
    );
  }

  // ===========================================================================
  // DETAILS
  // ===========================================================================

  void _showPurchaseDetails(PurchaseModel purchase) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);

        final double outstanding = purchase.total - purchase.paidAmount;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchase Details',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    _date(purchase.date),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 18),

                  _DetailRow(label: 'Purchase ID', value: purchase.id),

                  _DetailRow(label: 'Supplier', value: purchase.supplierName),

                  _DetailRow(
                    label: 'Subtotal',
                    value: _currency(purchase.subtotal),
                  ),

                  _DetailRow(
                    label: 'Discount',
                    value: _currency(purchase.discount),
                  ),

                  _DetailRow(label: 'Tax', value: _currency(purchase.tax)),

                  _DetailRow(
                    label: 'Total',
                    value: _currency(purchase.total),
                    bold: true,
                  ),

                  _DetailRow(
                    label: 'Paid',
                    value: _currency(purchase.paidAmount),
                  ),

                  _DetailRow(
                    label: 'Outstanding',
                    value: _currency(outstanding > 0 ? outstanding : 0),
                    valueColor: outstanding > 0
                        ? AppColors.warning
                        : AppColors.success,
                    bold: true,
                  ),

                  _DetailRow(
                    label: 'Payment Status',
                    value: purchase.paymentStatus,
                  ),

                  _DetailRow(
                    label: 'Payment Method',
                    value: purchase.paymentMethod,
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Products',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 10),

                  ...purchase.items.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            '${_number(item.quantity)} ${item.unit} × ${_currency(item.purchaseRate)}',
                            style: theme.textTheme.bodySmall,
                          ),

                          const SizedBox(height: 5),

                          Text(
                            'Total: ${_currency(item.total)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  if (purchase.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),

                    Text(
                      'Notes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(purchase.notes, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // FOOTER
  // ===========================================================================

  Widget _buildFooter(
    ThemeData theme,
    List<PurchaseModel> purchases,
    List<SupplierPaymentModel> supplierPayments,
  ) {
    return _ReportCard(
      child: Wrap(
        spacing: 24,
        runSpacing: 14,
        children: [
          _FooterMetric(label: 'Purchases', value: purchases.length.toString()),

          _FooterMetric(
            label: 'Quantity',
            value: _number(_totalQuantity(purchases)),
          ),

          _FooterMetric(
            label: 'Discount',
            value: _currency(_totalDiscount(purchases)),
          ),

          _FooterMetric(label: 'Tax', value: _currency(_totalTax(purchases))),

          _FooterMetric(
            label: 'Supplier Payments',
            value: _currency(_totalSupplierPayments(supplierPayments)),
          ),

          _FooterMetric(
            label: 'Payment Rate',
            value:
                '${_paymentRate(purchases, supplierPayments).toStringAsFixed(2)}%',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PDF DOWNLOAD
  // ===========================================================================

  String _pdfCurrency(double value) {
    return 'Rs. ${NumberFormat('#,##0.00', 'en_IN').format(value)}';
  }

  String _pdfFileName() {
    final String start = _startDate == null
        ? 'all'
        : DateFormat('yyyy-MM-dd').format(_startDate!);
    final String end = _endDate == null
        ? 'dates'
        : DateFormat('yyyy-MM-dd').format(_endDate!);
    return 'Purchase_Report_${start}_to_$end.pdf';
  }

  String _businessDetailsForPdf() {
    final BusinessModel? business = _business;
    if (business == null) return '';

    final List<String> details = <String>[];
    if (business.businessType.trim().isNotEmpty) {
      details.add(business.businessType.trim());
    }
    if (business.address.trim().isNotEmpty) {
      details.add(business.address.trim());
    }
    if (business.mobile.trim().isNotEmpty) {
      details.add('Mobile: ${business.mobile.trim()}');
    }
    if (business.email.trim().isNotEmpty) {
      details.add('Email: ${business.email.trim()}');
    }
    if (business.gstNumber.trim().isNotEmpty) {
      details.add('GSTIN: ${business.gstNumber.trim()}');
    }
    return details.join(' | ');
  }

  Future<void> _downloadPdf() async {
    if (_business == null || _downloadingPdf) return;

    setState(() {
      _downloadingPdf = true;
    });

    try {
      final List<PurchaseModel> purchases = _filteredPurchases;
      final List<SupplierPaymentModel> payments = _filteredSupplierPayments;
      final pw.Document document = pw.Document();

      final String businessName = _business!.businessName.trim().isEmpty
          ? 'Business'
          : _business!.businessName.trim();
      final String businessDetails = _businessDetailsForPdf();

      final pw.TextStyle titleStyle = pw.TextStyle(
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
      );
      final pw.TextStyle smallStyle = pw.TextStyle(
        fontSize: 8,
        color: PdfColors.grey700,
      );

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                businessName,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (businessDetails.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(businessDetails, style: smallStyle),
              ],
              pw.SizedBox(height: 7),
              pw.Divider(),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Purchase Report', style: titleStyle),
                  pw.Text(_dateRangeText(), style: smallStyle),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
          ),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Business Management App', style: smallStyle),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: smallStyle,
              ),
            ],
          ),
          build: (context) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    children: [
                      _pdfMetric(
                        'Total Purchases',
                        _pdfCurrency(_totalPurchases(purchases)),
                      ),
                      _pdfMetric(
                        'Paid',
                        _pdfCurrency(_totalPaid(purchases, payments)),
                      ),
                      _pdfMetric(
                        'Outstanding',
                        _pdfCurrency(_totalOutstanding(purchases, payments)),
                      ),
                      _pdfMetric(
                        'Items Purchased',
                        _number(_totalQuantity(purchases)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Purchase Details', style: titleStyle),
            pw.SizedBox(height: 8),
            if (purchases.isEmpty)
              pw.Text(
                'No purchases available for the selected filters.',
                style: smallStyle,
              )
            else
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Date',
                  'Purchase ID',
                  'Supplier',
                  'Total',
                  'Paid',
                  'Balance',
                  'Status',
                ],
                data: purchases.map((purchase) {
                  final double balance = purchase.total - purchase.paidAmount;
                  return [
                    _date(purchase.date),
                    purchase.id,
                    purchase.supplierName.trim().isEmpty
                        ? 'Unknown Supplier'
                        : purchase.supplierName,
                    _pdfCurrency(purchase.total),
                    _pdfCurrency(purchase.paidAmount),
                    _pdfCurrency(balance > 0 ? balance : 0),
                    purchase.paymentStatus,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 7),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 5,
                ),
              ),
            pw.SizedBox(height: 18),
            pw.Text('Supplier-wise Purchases', style: titleStyle),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Supplier',
                'Invoices',
                'Purchases',
                'Paid',
                'Outstanding',
              ],
              data: _supplierWisePurchases(purchases, payments).values.map((
                supplier,
              ) {
                return [
                  supplier.name,
                  supplier.invoiceCount.toString(),
                  _pdfCurrency(supplier.purchases),
                  _pdfCurrency(supplier.paid),
                  _pdfCurrency(supplier.outstanding),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 5,
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text('Product-wise Purchases', style: titleStyle),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Product',
                'Quantity',
                'Purchase Cost',
                'Invoices',
              ],
              data:
                  (_productWisePurchases(purchases).values.toList()
                        ..sort((a, b) => b.amount.compareTo(a.amount)))
                      .map((product) {
                        return [
                          product.name,
                          '${_number(product.quantity)} ${product.unit}'.trim(),
                          _pdfCurrency(product.amount),
                          product.invoiceCount.toString(),
                        ];
                      })
                      .toList(),
              headerStyle: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 5,
              ),
            ),
          ],
        ),
      );

      final Uint8List bytes = Uint8List.fromList(await document.save());

      final PublicSavedFile? saved = await PublicFileSaver().saveBytes(
        bytes: bytes,
        fileName: _pdfFileName(),
        mimeType: 'application/pdf',
        subDir: 'Business Management Reports',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved != null && saved.isSuccess
                ? 'Purchase Report PDF saved successfully.'
                : 'PDF save was cancelled or failed.',
          ),
          behavior: SnackBarBehavior.fixed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to create Purchase Report PDF: $e'),
          behavior: SnackBarBehavior.fixed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingPdf = false;
        });
      }
    }
  }

  pw.Widget _pdfMetric(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: _ReportCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.danger,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Unable to load Purchase Report',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _errorMessage ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: () => _loadReport(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DATA CLASSES
// =============================================================================

// ===========================================================================
// DATE PRESET BUTTON
// ===========================================================================

class _DatePresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DatePresetButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label),
    );
  }
}

class _SummaryItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _SupplierPurchaseSummary {
  final String name;
  final double purchases;
  final double paid;
  final double outstanding;
  final int invoiceCount;

  const _SupplierPurchaseSummary({
    required this.name,
    this.purchases = 0,
    this.paid = 0,
    this.outstanding = 0,
    this.invoiceCount = 0,
  });
}

class _ProductPurchaseSummary {
  final String name;
  final double quantity;
  final double amount;
  final int invoiceCount;
  final String unit;

  const _ProductPurchaseSummary({
    required this.name,
    this.quantity = 0,
    this.amount = 0,
    this.invoiceCount = 0,
    this.unit = '',
  });
}

class _StatusItem {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatusItem({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });
}

// =============================================================================
// CARD
// =============================================================================

class _ReportCard extends StatelessWidget {
  final Widget child;

  const _ReportCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.08 : 0.035,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// =============================================================================
// SUMMARY CARD
// =============================================================================

class _SummaryCard extends StatelessWidget {
  final _SummaryItem item;

  const _SummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: item.color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 21),
              ),

              const Spacer(),

              Icon(
                Icons.arrow_outward_rounded,
                color: item.color.withValues(alpha: 0.65),
                size: 18,
              ),
            ],
          ),

          const Spacer(),

          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: item.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION HEADER
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 22),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// STATUS TILE
// =============================================================================

class _StatusTile extends StatelessWidget {
  final _StatusItem item;

  const _StatusTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: item.color, size: 23),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              item.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          Text(
            item.count.toString(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: item.color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FILTER CHIP
// =============================================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color activeColor = color ?? theme.colorScheme.primary;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: activeColor.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected ? activeColor : theme.colorScheme.outlineVariant,
      ),
      labelStyle: TextStyle(
        color: selected ? activeColor : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

// =============================================================================
// SUPPLIER TILE
// =============================================================================

class _SupplierTile extends StatelessWidget {
  final _SupplierPurchaseSummary summary;
  final String Function(double) currency;

  const _SupplierTile({required this.summary, required this.currency});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${summary.invoiceCount} purchase${summary.invoiceCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency(summary.purchases),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Paid ${currency(summary.paid)}',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                'Due ${currency(summary.outstanding)}',
                style: TextStyle(
                  color: summary.outstanding > 0
                      ? AppColors.warning
                      : AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PRODUCT TILE
// =============================================================================

class _ProductTile extends StatelessWidget {
  final _ProductPurchaseSummary summary;
  final String Function(double) currency;
  final String Function(double) number;

  const _ProductTile({
    required this.summary,
    required this.currency,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              Text(
                currency(summary.amount),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Text(
                'Qty: ${number(summary.quantity)} ${summary.unit}',
                style: theme.textTheme.bodySmall,
              ),

              Text(
                '${summary.invoiceCount} purchase${summary.invoiceCount == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PURCHASE TILE
// =============================================================================

class _PurchaseTile extends StatelessWidget {
  final PurchaseModel purchase;
  final String Function(double) currency;
  final String Function(DateTime) date;
  final Color Function(String) statusColor;
  final VoidCallback onTap;

  const _PurchaseTile({
    required this.purchase,
    required this.currency,
    required this.date,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color color = statusColor(purchase.paymentStatus);

    final double outstanding = purchase.total - purchase.paidAmount;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.40,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.shopping_bag_rounded, color: color, size: 22),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    purchase.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    purchase.supplierName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),

                  const SizedBox(height: 3),

                  Text(
                    date(purchase.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency(purchase.total),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    purchase.paymentStatus,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                if (outstanding > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Due ${currency(outstanding)}',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 5),

            const Icon(Icons.chevron_right_rounded, size: 21),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DETAIL ROW
// =============================================================================

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EMPTY
// =============================================================================

class _EmptyInline extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyInline({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: theme.colorScheme.onSurfaceVariant),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FOOTER
// =============================================================================

class _FooterMetric extends StatelessWidget {
  final String label;
  final String value;

  const _FooterMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
