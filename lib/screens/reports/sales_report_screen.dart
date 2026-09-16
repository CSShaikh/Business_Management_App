import 'dart:typed_data';

import '../../core/widgets/app_date_picker.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:public_file_saver/public_file_saver.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/payment_model.dart';
import '../../models/sale_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/sale_repository.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final BusinessRepository _businessRepository = BusinessRepository();
  final SaleRepository _saleRepository = SaleRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _refreshing = false;
  bool _downloadingPdf = false;

  BusinessModel? _business;

  String? _errorMessage;
  String _searchQuery = '';

  DateTime? _startDate;
  DateTime? _endDate;

  String _paymentFilter = 'All';

  List<SaleModel> _allSales = <SaleModel>[];
  List<PaymentModel> _allPayments = <PaymentModel>[];

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
  // LOAD
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
      final BusinessModel? business = await _businessRepository
          .getBusinessForCurrentUser();

      if (business == null) {
        throw Exception('Business information is not available.');
      }

      final List<dynamic> result = await Future.wait<dynamic>([
        _saleRepository.getSales(businessId: business.id),
        _paymentRepository.getPayments(businessId: business.id),
      ]);

      final List<SaleModel> sales = result[0] as List<SaleModel>;

      final List<PaymentModel> payments = result[1] as List<PaymentModel>;

      if (!mounted) return;

      setState(() {
        _business = business;
        _allSales = sales;
        _allPayments = payments;
        _loading = false;
        _refreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

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
          : null,
      helpText: 'Select reporting period',
      saveText: 'Apply',
      cancelText: 'Cancel',
    );

    if (selected == null || !mounted) {
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

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  // ===========================================================================
  // FILTERED DATA
  // ===========================================================================

  List<SaleModel> get _filteredSales {
    final String query = _searchQuery.trim().toLowerCase();

    final List<SaleModel> sales = _allSales.where((sale) {
      if (_startDate != null && sale.date.isBefore(_startDate!)) {
        return false;
      }

      if (_endDate != null && sale.date.isAfter(_endDate!)) {
        return false;
      }

      if (_paymentFilter != 'All' &&
          sale.paymentStatus.toLowerCase() != _paymentFilter.toLowerCase()) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final bool invoiceMatch = sale.invoiceNumber.toLowerCase().contains(
        query,
      );

      final bool customerMatch = sale.customerName.toLowerCase().contains(
        query,
      );

      final bool notesMatch = sale.notes.toLowerCase().contains(query);

      final bool productMatch = sale.items.any(
        (item) => item.productName.toLowerCase().contains(query),
      );

      return invoiceMatch || customerMatch || notesMatch || productMatch;
    }).toList();

    sales.sort((a, b) => b.date.compareTo(a.date));

    return sales;
  }

  List<PaymentModel> get _filteredPayments {
    return _allPayments.where((payment) {
      if (_startDate != null && payment.date.isBefore(_startDate!)) {
        return false;
      }

      if (_endDate != null && payment.date.isAfter(_endDate!)) {
        return false;
      }

      return true;
    }).toList();
  }

  // ===========================================================================
  // CALCULATIONS
  // ===========================================================================

  double _totalSales(List<SaleModel> sales) {
    return sales.fold<double>(0, (sum, sale) => sum + sale.total);
  }

  double _totalCollected(List<SaleModel> sales, List<PaymentModel> payments) {
    final double salePaid = sales.fold<double>(
      0,
      (sum, sale) => sum + sale.paidAmount,
    );

    final double separatePayments = payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );

    return salePaid + separatePayments;
  }

  double _totalOutstanding(List<SaleModel> sales, List<PaymentModel> payments) {
    final double outstanding =
        _totalSales(sales) - _totalCollected(sales, payments);

    return outstanding > 0 ? outstanding : 0;
  }

  double _saleGrossProfit(SaleModel sale) {
    double cost = 0;

    for (final item in sale.items) {
      cost += item.costPrice * item.quantity;
    }

    return sale.total - cost;
  }

  double _totalGrossProfit(List<SaleModel> sales) {
    return sales.fold<double>(0, (sum, sale) => sum + _saleGrossProfit(sale));
  }

  double _totalCost(List<SaleModel> sales) {
    double total = 0;

    for (final sale in sales) {
      for (final item in sale.items) {
        total += item.costPrice * item.quantity;
      }
    }

    return total;
  }

  double _totalQuantity(List<SaleModel> sales) {
    double total = 0;

    for (final sale in sales) {
      for (final item in sale.items) {
        total += item.quantity;
      }
    }

    return total;
  }

  double _profitMargin(List<SaleModel> sales) {
    final double total = _totalSales(sales);

    if (total <= 0) {
      return 0;
    }

    return (_totalGrossProfit(sales) / total) * 100;
  }

  double _collectionRate(List<SaleModel> sales, List<PaymentModel> payments) {
    final double total = _totalSales(sales);

    if (total <= 0) {
      return 0;
    }

    return (_totalCollected(sales, payments) / total) * 100;
  }

  int _countStatus(List<SaleModel> sales, String status) {
    return sales
        .where(
          (sale) => sale.paymentStatus.toLowerCase() == status.toLowerCase(),
        )
        .length;
  }

  // ===========================================================================
  // GROUPING
  // ===========================================================================

  Map<String, _CustomerSalesSummary> _customerWiseSales(
    List<SaleModel> sales,
    List<PaymentModel> payments,
  ) {
    final Map<String, _CustomerSalesSummary> result =
        <String, _CustomerSalesSummary>{};

    for (final SaleModel sale in sales) {
      final String customer = sale.customerName.trim().isEmpty
          ? 'Walk-in Customer'
          : sale.customerName.trim();

      final _CustomerSalesSummary old =
          result[customer] ?? _CustomerSalesSummary(name: customer);

      final double outstanding = sale.total - sale.paidAmount;

      result[customer] = _CustomerSalesSummary(
        name: customer,
        sales: old.sales + sale.total,
        collected: old.collected + sale.paidAmount,
        outstanding: old.outstanding + (outstanding > 0 ? outstanding : 0),
        profit: old.profit + _saleGrossProfit(sale),
        invoiceCount: old.invoiceCount + 1,
      );
    }

    for (final PaymentModel payment in payments) {
      final String customer = payment.customerName.trim().isEmpty
          ? 'Walk-in Customer'
          : payment.customerName.trim();

      final _CustomerSalesSummary old =
          result[customer] ?? _CustomerSalesSummary(name: customer);

      final double collected = old.collected + payment.amount;

      final double outstanding = old.sales - collected;

      result[customer] = _CustomerSalesSummary(
        name: customer,
        sales: old.sales,
        collected: collected,
        outstanding: outstanding > 0 ? outstanding : 0,
        profit: old.profit,
        invoiceCount: old.invoiceCount,
      );
    }

    final List<_CustomerSalesSummary> values = result.values.toList();

    values.sort((a, b) => b.sales.compareTo(a.sales));

    return {for (final item in values) item.name: item};
  }

  Map<String, _ProductSalesSummary> _productWiseSales(List<SaleModel> sales) {
    final Map<String, _ProductSalesSummary> result =
        <String, _ProductSalesSummary>{};

    for (final SaleModel sale in sales) {
      for (final item in sale.items) {
        final String name = item.productName.trim().isEmpty
            ? 'Unknown Product'
            : item.productName.trim();

        final _ProductSalesSummary old =
            result[name] ?? _ProductSalesSummary(name: name);

        final double itemRevenue = item.quantity * item.sellingRate;

        final double cost = item.costPrice * item.quantity;

        final double adjustment = sale.total - sale.subtotal;

        final double allocatedAdjustment =
            sale.subtotal > 0 && sale.subtotal.isFinite
            ? adjustment * (itemRevenue / sale.subtotal)
            : 0;

        final double revenue = itemRevenue + allocatedAdjustment;

        result[name] = _ProductSalesSummary(
          name: name,
          quantity: old.quantity + item.quantity,
          revenue: old.revenue + revenue,
          cost: old.cost + cost,
          profit: old.profit + revenue - cost,
          invoiceCount: old.invoiceCount + 1,
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

  String _date(DateTime value) {
    return DateFormat('dd MMM yyyy').format(value);
  }

  String _dateRangeText() {
    if (_startDate == null || _endDate == null) {
      return 'All Dates';
    }

    return '${DateFormat('dd MMM yyyy').format(_startDate!)}'
        ' - '
        '${DateFormat('dd MMM yyyy').format(_endDate!)}';
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
  // APP BAR
  // ===========================================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () {
          Navigator.of(context).maybePop();
        },
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Sales Report'),
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
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState(theme)
          : _buildReportBody(theme),
    );
  }

  Widget _buildReportBody(ThemeData theme) {
    final List<SaleModel> sales = _filteredSales;

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
                    _buildHeader(theme),
                    const SizedBox(height: 20),
                    _buildDateFilter(theme),
                    const SizedBox(height: 20),
                    _buildSummaryCards(
                      theme,
                      sales,
                      _filteredPayments,
                      isDesktop,
                    ),
                    const SizedBox(height: 20),
                    _buildPaymentStatusSection(theme, sales),
                    const SizedBox(height: 20),
                    _buildSearchAndFilters(theme),
                    const SizedBox(height: 20),
                    _buildCustomerWiseSection(theme, sales, _filteredPayments),
                    const SizedBox(height: 20),
                    _buildProductWiseSection(theme, sales),
                    const SizedBox(height: 20),
                    _buildInvoiceSection(theme, sales),
                    const SizedBox(height: 20),
                    _buildReportFooter(theme, sales, _filteredPayments),
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

  Widget _buildHeader(ThemeData theme) {
    final String businessName =
        _business?.businessName.trim().isNotEmpty == true
        ? _business!.businessName.trim()
        : 'Business';

    return _ReportCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales Report',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Analyze sales, collections, '
                  'customers and product performance.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.70,
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
  // DATE UI
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
    List<SaleModel> sales,
    List<PaymentModel> payments,
    bool isDesktop,
  ) {
    final double totalSales = _totalSales(sales);

    final double collected = _totalCollected(sales, payments);

    final double outstanding = _totalOutstanding(sales, payments);

    final double profit = _totalGrossProfit(sales);

    final List<_SummaryItem> items = [
      _SummaryItem(
        title: 'Total Sales',
        value: _currency(totalSales),
        subtitle: '${sales.length} invoices',
        icon: Icons.trending_up_rounded,
        color: AppColors.primary,
      ),
      _SummaryItem(
        title: 'Collected',
        value: _currency(collected),
        subtitle:
            '${_collectionRate(sales, payments).toStringAsFixed(1)}% collection',
        icon: Icons.payments_rounded,
        color: AppColors.success,
      ),
      _SummaryItem(
        title: 'Outstanding',
        value: _currency(outstanding),
        subtitle: 'Customer receivable',
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.warning,
      ),
      _SummaryItem(
        title: 'Gross Profit',
        value: _currency(profit),
        subtitle: '${_profitMargin(sales).toStringAsFixed(1)}% margin',
        icon: Icons.auto_graph_rounded,
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

  Widget _buildPaymentStatusSection(ThemeData theme, List<SaleModel> sales) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.pie_chart_rounded,
            title: 'Payment Status',
            subtitle: 'Invoice-level payment status distribution',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatusChip(
                label: 'Paid',
                count: _countStatus(sales, 'paid'),
                color: AppColors.success,
              ),
              _StatusChip(
                label: 'Partial',
                count: _countStatus(sales, 'partial'),
                color: AppColors.warning,
              ),
              _StatusChip(
                label: 'Unpaid',
                count: _countStatus(sales, 'unpaid'),
                color: AppColors.danger,
              ),
            ],
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 700;

          final Widget search = TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search invoice, customer, notes or product',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();

                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          );

          final Widget filter = DropdownButtonFormField<String>(
            initialValue: _paymentFilter,
            decoration: const InputDecoration(
              labelText: 'Payment Status',
              prefixIcon: Icon(Icons.filter_alt_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All')),
              DropdownMenuItem(value: 'Paid', child: Text('Paid')),
              DropdownMenuItem(value: 'Partial', child: Text('Partial')),
              DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid')),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _paymentFilter = value;
              });
            },
          );

          if (compact) {
            return Column(
              children: [search, const SizedBox(height: 12), filter],
            );
          }

          return Row(
            children: [
              Expanded(flex: 2, child: search),
              const SizedBox(width: 12),
              Expanded(child: filter),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // CUSTOMER-WISE
  // ===========================================================================

  Widget _buildCustomerWiseSection(
    ThemeData theme,
    List<SaleModel> sales,
    List<PaymentModel> payments,
  ) {
    final List<_CustomerSalesSummary> customers = _customerWiseSales(
      sales,
      payments,
    ).values.toList();

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.groups_rounded,
            title: 'Customer-wise Sales',
            subtitle: 'Sales and collection by customer',
          ),
          const SizedBox(height: 18),
          if (customers.isEmpty)
            const _EmptyInline(
              icon: Icons.groups_outlined,
              message: 'No customer sales available for the selected filters.',
            )
          else
            ...customers
                .take(10)
                .map((customer) => _CustomerSalesTile(summary: customer)),
        ],
      ),
    );
  }

  // ===========================================================================
  // PRODUCT-WISE
  // ===========================================================================

  Widget _buildProductWiseSection(ThemeData theme, List<SaleModel> sales) {
    final List<_ProductSalesSummary> products = _productWiseSales(
      sales,
    ).values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.inventory_2_rounded,
            title: 'Product-wise Sales',
            subtitle: 'Revenue, quantity and profit by product',
          ),
          const SizedBox(height: 18),
          if (products.isEmpty)
            const _EmptyInline(
              icon: Icons.inventory_2_outlined,
              message: 'No product sales available for the selected filters.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 650) {
                  return Column(
                    children: products
                        .take(15)
                        .map((product) => _ProductSalesTile(summary: product))
                        .toList(),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 28,
                    headingTextStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Quantity')),
                      DataColumn(label: Text('Revenue')),
                      DataColumn(label: Text('Cost')),
                      DataColumn(label: Text('Profit')),
                    ],
                    rows: products
                        .take(20)
                        .map(
                          (product) => DataRow(
                            cells: [
                              DataCell(Text(product.name)),
                              DataCell(
                                Text(
                                  '${_number(product.quantity)} ${product.unit}',
                                ),
                              ),
                              DataCell(Text(_currency(product.revenue))),
                              DataCell(Text(_currency(product.cost))),
                              DataCell(
                                Text(
                                  _currency(product.profit),
                                  style: TextStyle(
                                    color: product.profit >= 0
                                        ? AppColors.success
                                        : AppColors.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // INVOICE LIST
  // ===========================================================================

  Widget _buildInvoiceSection(ThemeData theme, List<SaleModel> sales) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.receipt_long_rounded,
            title: 'Invoice Details',
            subtitle: 'Detailed sales invoice performance',
          ),
          const SizedBox(height: 18),
          if (sales.isEmpty)
            const _EmptyInline(
              icon: Icons.receipt_long_outlined,
              message: 'No sales available for the selected filters.',
            )
          else
            ...sales
                .take(30)
                .map(
                  (sale) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InvoiceTile(
                      sale: sale,
                      currency: _currency,
                      date: _date,
                      statusColor: _statusColor,
                      onTap: () => _showSaleDetails(sale),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SALE DETAILS
  // ===========================================================================

  void _showSaleDetails(SaleModel sale) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);

        final double profit = _saleGrossProfit(sale);

        final double outstanding = sale.total - sale.paidAmount;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.invoiceNumber.trim().isEmpty
                        ? 'Sale Details'
                        : sale.invoiceNumber,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _date(sale.date),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DetailInfoRow(
                    label: 'Customer',
                    value: sale.customerName.trim().isEmpty
                        ? 'Walk-in Customer'
                        : sale.customerName,
                  ),
                  _DetailInfoRow(
                    label: 'Payment Method',
                    value: sale.paymentMethod.trim().isEmpty
                        ? 'Not specified'
                        : sale.paymentMethod,
                  ),
                  _DetailInfoRow(
                    label: 'Payment Status',
                    value: sale.paymentStatus,
                  ),
                  _DetailInfoRow(
                    label: 'Subtotal',
                    value: _currency(sale.subtotal),
                  ),
                  _DetailInfoRow(
                    label: 'Discount',
                    value: _currency(sale.discount),
                  ),
                  _DetailInfoRow(label: 'Tax', value: _currency(sale.tax)),
                  _DetailInfoRow(
                    label: 'Total',
                    value: _currency(sale.total),
                    bold: true,
                  ),
                  _DetailInfoRow(
                    label: 'Paid',
                    value: _currency(sale.paidAmount),
                  ),
                  _DetailInfoRow(
                    label: 'Outstanding',
                    value: _currency(outstanding > 0 ? outstanding : 0),
                  ),
                  _DetailInfoRow(
                    label: 'Gross Profit',
                    value: _currency(profit),
                    valueColor: profit >= 0
                        ? AppColors.success
                        : AppColors.danger,
                    bold: true,
                  ),
                  if (sale.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Notes',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(sale.notes, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Items',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...sale.items.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_number(item.quantity)} ${item.unit} × ${_currency(item.sellingRate)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _currency(item.total),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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

  Widget _buildReportFooter(
    ThemeData theme,
    List<SaleModel> sales,
    List<PaymentModel> payments,
  ) {
    return _ReportCard(
      child: Wrap(
        spacing: 24,
        runSpacing: 14,
        children: [
          _FooterMetric(label: 'Invoices', value: sales.length.toString()),
          _FooterMetric(
            label: 'Items Sold',
            value: _number(_totalQuantity(sales)),
          ),
          _FooterMetric(
            label: 'Sales Cost',
            value: _currency(_totalCost(sales)),
          ),
          _FooterMetric(
            label: 'Profit Margin',
            value: '${_profitMargin(sales).toStringAsFixed(2)}%',
          ),
          _FooterMetric(
            label: 'Customer Payments',
            value: _currency(
              payments.fold<double>(0, (sum, payment) => sum + payment.amount),
            ),
          ),
          _FooterMetric(
            label: 'Collection Rate',
            value: '${_collectionRate(sales, payments).toStringAsFixed(2)}%',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PDF
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

    return 'Sales_Report_${start}_to_$end.pdf';
  }

  String _businessDetailText() {
    final BusinessModel? business = _business;

    if (business == null) {
      return '';
    }

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
    if (_business == null || _downloadingPdf) {
      return;
    }

    setState(() {
      _downloadingPdf = true;
    });

    try {
      final List<SaleModel> sales = _filteredSales;

      final List<PaymentModel> payments = _filteredPayments;

      final pw.Document document = pw.Document();

      final String businessName = _business!.businessName.trim().isEmpty
          ? 'Business'
          : _business!.businessName.trim();

      final String businessDetails = _businessDetailText();

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
          header: (context) {
            return pw.Column(
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
                    pw.Text('Sales Report', style: titleStyle),
                    pw.Text(_dateRangeText(), style: smallStyle),
                  ],
                ),
                pw.SizedBox(height: 10),
              ],
            );
          },
          footer: (context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Business Management App', style: smallStyle),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: smallStyle,
                  ),
                ],
              ),
            );
          },
          build: (context) {
            return [
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
                          'Total Sales',
                          _pdfCurrency(_totalSales(sales)),
                        ),
                        _pdfMetric(
                          'Collected',
                          _pdfCurrency(_totalCollected(sales, payments)),
                        ),
                        _pdfMetric(
                          'Outstanding',
                          _pdfCurrency(_totalOutstanding(sales, payments)),
                        ),
                        _pdfMetric(
                          'Gross Profit',
                          _pdfCurrency(_totalGrossProfit(sales)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Invoice Details', style: titleStyle),
              pw.SizedBox(height: 8),
              if (sales.isEmpty)
                pw.Text(
                  'No sales available for the selected filters.',
                  style: smallStyle,
                )
              else
                pw.TableHelper.fromTextArray(
                  headers: const [
                    'Date',
                    'Invoice',
                    'Customer',
                    'Total',
                    'Paid',
                    'Balance',
                    'Status',
                  ],
                  data: sales.map((sale) {
                    final double balance = sale.total - sale.paidAmount;

                    return [
                      _date(sale.date),
                      sale.invoiceNumber.trim().isEmpty
                          ? '-'
                          : sale.invoiceNumber,
                      sale.customerName.trim().isEmpty
                          ? 'Walk-in Customer'
                          : sale.customerName,
                      _pdfCurrency(sale.total),
                      _pdfCurrency(sale.paidAmount),
                      _pdfCurrency(balance > 0 ? balance : 0),
                      sale.paymentStatus,
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
              pw.Text('Customer-wise Sales', style: titleStyle),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Customer',
                  'Invoices',
                  'Sales',
                  'Collected',
                  'Outstanding',
                  'Profit',
                ],
                data: _customerWiseSales(sales, payments).values.map((
                  customer,
                ) {
                  return [
                    customer.name,
                    customer.invoiceCount.toString(),
                    _pdfCurrency(customer.sales),
                    _pdfCurrency(customer.collected),
                    _pdfCurrency(customer.outstanding),
                    _pdfCurrency(customer.profit),
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
              pw.Text('Product-wise Sales', style: titleStyle),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Product',
                  'Quantity',
                  'Revenue',
                  'Cost',
                  'Profit',
                ],
                data:
                    (_productWiseSales(sales).values.toList()
                          ..sort((a, b) => b.revenue.compareTo(a.revenue)))
                        .map((product) {
                          return [
                            product.name,
                            '${_number(product.quantity)} ${product.unit}'
                                .trim(),
                            _pdfCurrency(product.revenue),
                            _pdfCurrency(product.cost),
                            _pdfCurrency(product.profit),
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
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 5,
                ),
              ),
            ];
          },
        ),
      );

      final Uint8List bytes = Uint8List.fromList(await document.save());

      final PublicSavedFile? result = await PublicFileSaver().saveBytes(
        bytes: bytes,
        fileName: _pdfFileName(),
        mimeType: 'application/pdf',
        subDir: 'Business Management Reports',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result != null && result.isSuccess
                ? 'Sales Report PDF saved successfully.'
                : 'PDF save was cancelled or failed.',
          ),
          behavior: SnackBarBehavior.fixed,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to create Sales Report PDF: $e'),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _ReportCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 52,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 12),
                Text(
                  'Unable to load sales report',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Something went wrong.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadReport,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
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
// DATE PRESET BUTTON
// =============================================================================

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

// =============================================================================
// SUMMARY MODEL
// =============================================================================

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

// =============================================================================
// CUSTOMER SUMMARY
// =============================================================================

class _CustomerSalesSummary {
  final String name;
  final double sales;
  final double collected;
  final double outstanding;
  final double profit;
  final int invoiceCount;

  const _CustomerSalesSummary({
    required this.name,
    this.sales = 0,
    this.collected = 0,
    this.outstanding = 0,
    this.profit = 0,
    this.invoiceCount = 0,
  });
}

// =============================================================================
// PRODUCT SUMMARY
// =============================================================================

class _ProductSalesSummary {
  final String name;
  final double quantity;
  final double revenue;
  final double cost;
  final double profit;
  final int invoiceCount;
  final String unit;

  const _ProductSalesSummary({
    required this.name,
    this.quantity = 0,
    this.revenue = 0,
    this.cost = 0,
    this.profit = 0,
    this.invoiceCount = 0,
    this.unit = '',
  });
}

// =============================================================================
// REPORT CARD
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
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
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

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 21),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_outward_rounded,
                size: 18,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.title,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 21),
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
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.65,
                  ),
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
// STATUS CHIP
// =============================================================================

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            count.toString(),
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CUSTOMER TILE
// =============================================================================

class _CustomerSalesTile extends StatelessWidget {
  final _CustomerSalesSummary summary;

  const _CustomerSalesTile({required this.summary});

  String _currency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 600;

          final Widget customer = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.invoiceCount} invoice${summary.invoiceCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.65,
                    ),
                  ),
                ),
              ],
            ),
          );

          final Widget metrics = compact
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 10,
                    children: [
                      _MiniMetric(
                        label: 'Sales',
                        value: _currency(summary.sales),
                      ),
                      _MiniMetric(
                        label: 'Collected',
                        value: _currency(summary.collected),
                      ),
                      _MiniMetric(
                        label: 'Outstanding',
                        value: _currency(summary.outstanding),
                      ),
                      _MiniMetric(
                        label: 'Profit',
                        value: _currency(summary.profit),
                      ),
                    ],
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniMetric(
                      label: 'Sales',
                      value: _currency(summary.sales),
                    ),
                    const SizedBox(width: 22),
                    _MiniMetric(
                      label: 'Collected',
                      value: _currency(summary.collected),
                    ),
                    const SizedBox(width: 22),
                    _MiniMetric(
                      label: 'Outstanding',
                      value: _currency(summary.outstanding),
                    ),
                    const SizedBox(width: 22),
                    _MiniMetric(
                      label: 'Profit',
                      value: _currency(summary.profit),
                    ),
                  ],
                );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [customer, metrics],
            );
          }

          return Row(children: [customer, metrics]);
        },
      ),
    );
  }
}

// =============================================================================
// PRODUCT TILE
// =============================================================================

class _ProductSalesTile extends StatelessWidget {
  final _ProductSalesSummary summary;

  const _ProductSalesTile({required this.summary});

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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _MiniMetric(
                label: 'Quantity',
                value: '${_number(summary.quantity)} ${summary.unit}',
              ),
              _MiniMetric(label: 'Revenue', value: _currency(summary.revenue)),
              _MiniMetric(label: 'Cost', value: _currency(summary.cost)),
              _MiniMetric(
                label: 'Profit',
                value: _currency(summary.profit),
                valueColor: summary.profit >= 0
                    ? AppColors.success
                    : AppColors.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MINI METRIC
// =============================================================================

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MiniMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.textTheme.labelSmall?.color?.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// INVOICE TILE
// =============================================================================

class _InvoiceTile extends StatelessWidget {
  final SaleModel sale;
  final String Function(double) currency;
  final String Function(DateTime) date;
  final Color Function(String) statusColor;
  final VoidCallback onTap;

  const _InvoiceTile({
    required this.sale,
    required this.currency,
    required this.date,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color color = statusColor(sale.paymentStatus);

    final double outstanding = sale.total - sale.paidAmount;

    final String customer = sale.customerName.trim().isEmpty
        ? 'Walk-in Customer'
        : sale.customerName;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool compact = constraints.maxWidth < 650;

            final Widget mainInfo = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sale.invoiceNumber.trim().isEmpty
                              ? 'Invoice'
                              : sale.invoiceNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sale.paymentStatus,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    date(sale.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.60,
                      ),
                    ),
                  ),
                ],
              ),
            );

            final Widget financials = compact
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 10,
                      children: [
                        _MiniMetric(
                          label: 'Total',
                          value: currency(sale.total),
                        ),
                        _MiniMetric(
                          label: 'Paid',
                          value: currency(sale.paidAmount),
                        ),
                        _MiniMetric(
                          label: 'Outstanding',
                          value: currency(outstanding > 0 ? outstanding : 0),
                        ),
                      ],
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MiniMetric(label: 'Total', value: currency(sale.total)),
                      const SizedBox(width: 20),
                      _MiniMetric(
                        label: 'Paid',
                        value: currency(sale.paidAmount),
                      ),
                      const SizedBox(width: 20),
                      _MiniMetric(
                        label: 'Outstanding',
                        value: currency(outstanding > 0 ? outstanding : 0),
                      ),
                    ],
                  );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [mainInfo, financials],
              );
            }

            return Row(
              children: [
                mainInfo,
                financials,
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right_rounded),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// DETAIL INFO ROW
// =============================================================================

class _DetailInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _DetailInfoRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.70,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor,
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
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 38,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FOOTER METRIC
// =============================================================================

class _FooterMetric extends StatelessWidget {
  final String label;
  final String value;

  const _FooterMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.textTheme.labelSmall?.color?.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
