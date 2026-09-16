import 'dart:typed_data';
import '../../core/widgets/app_date_picker.dart';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_number_format.dart';
import '../../models/purchase_model.dart';
import '../../models/supplier_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/purchase_provider.dart';

class SupplierStatementScreen extends StatefulWidget {
  const SupplierStatementScreen({
    super.key,
    required this.supplier,
  });

  final SupplierModel supplier;

  @override
  State<SupplierStatementScreen> createState() => _SupplierStatementScreenState();
}

class _SupplierStatementScreenState extends State<SupplierStatementScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _initialized = false;
  bool _sharing = false;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;
    final business = context.read<BusinessProvider>();
    final purchases = context.read<PurchaseProvider>();
    if (business.businessId.isEmpty) await business.loadBusiness();
    final id = business.businessId;
    if (id.isNotEmpty) {
      purchases.setBusinessId(id);
      if (purchases.purchases.isEmpty) {
        await purchases.loadPurchases(businessId: id);
      }
      if (mounted) setState(() {});
    }
  }

  List<PurchaseModel> get _allSupplierPurchases {
    final list = context.read<PurchaseProvider>().purchases.where((p) {
      return p.supplierId.trim() == widget.supplier.id.trim();
    }).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<PurchaseModel> get _filteredPurchases {
    final start = _startDate == null ? null : DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final end = _endDate == null ? null : DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59, 999);
    return _allSupplierPurchases.where((p) {
      final status = p.paymentStatus.trim().toLowerCase();
      final statusOk = _filter == 'All' || (_filter == 'Paid' && status == 'paid') || (_filter == 'Pending' && status != 'paid');
      final dateOk = (start == null || !p.date.isBefore(start)) && (end == null || !p.date.isAfter(end));
      return statusOk && dateOk;
    }).toList();
  }

  double _total(List<PurchaseModel> list) => list.fold(0, (v, p) => v + p.total);
  double _paid(List<PurchaseModel> list) => list.fold(0, (v, p) => v + p.paidAmount);
  double _pending(List<PurchaseModel> list) => list.fold(0, (v, p) => v + (p.total - p.paidAmount).clamp(0, double.infinity));

  String _money(double value) => AppNumberFormat.amount(value);
  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initialStart = _startDate ?? DateTime(now.year, now.month, now.day);
    final initialEnd = _endDate ?? initialStart;
    final range = await AppDatePicker.showDateRangePicker(
      context: context,
      
      initialEntryMode: DatePickerEntryMode.calendar,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: DateTimeRange(
        start: initialStart.isAfter(initialEnd) ? initialEnd : initialStart,
        end: initialEnd.isBefore(initialStart) ? initialStart : initialEnd,
      ),
      helpText: 'Select purchase statement period',
    );
    if (range != null && mounted) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  void _clearRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  Future<Uint8List> _buildPdf() async {
    final business = context.read<BusinessProvider>().business;
    final list = _filteredPurchases;
    final doc = pw.Document();
    final businessName = business?.businessName.trim().isNotEmpty == true ? business!.businessName : 'Business';
    final period = _startDate == null ? 'All transactions' : '${_date(_startDate!)} to ${_date(_endDate!)}';
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text('Supplier Statement • Page ${context.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (context) => [
          pw.Text(businessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          if (business?.mobile.trim().isNotEmpty == true) pw.Text(business!.mobile),
          if (business?.address.trim().isNotEmpty == true) pw.Text(business!.address),
          pw.SizedBox(height: 12),
          pw.Text('SUPPLIER STATEMENT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Supplier: ${widget.supplier.name}'),
          if (widget.supplier.mobile.trim().isNotEmpty) pw.Text('Mobile: ${widget.supplier.mobile}'),
          if (widget.supplier.gstNumber.trim().isNotEmpty) pw.Text('GST: ${widget.supplier.gstNumber}'),
          pw.Text('Period: $period'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Purchase', 'Date', 'Total', 'Paid', 'Pending', 'Status'],
            data: list.map((p) => [p.id, _date(p.date), 'Rs. ${p.total.toStringAsFixed(2)}', 'Rs. ${p.paidAmount.toStringAsFixed(2)}', 'Rs. ${(p.total-p.paidAmount).clamp(0,double.infinity).toStringAsFixed(2)}', p.paymentStatus]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.all(4),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Total Purchase: Rs. ${_total(list).toStringAsFixed(2)}'),
          pw.Text('Paid: Rs. ${_paid(list).toStringAsFixed(2)}'),
          pw.Text('Pending: Rs. ${_pending(list).toStringAsFixed(2)}'),
          pw.Text('Transactions: ${list.length}'),
          pw.SizedBox(height: 16),
          ...list.map((p) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('${p.id} • ${_date(p.date)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ...p.items.map((i) => pw.Text('  ${i.productName} • ${i.quantity} ${i.unit} • Rs. ${i.total.toStringAsFixed(2)}')),
            ]),
          )),
        ],
      ),
    );
    return doc.save();
  }

  Future<void> _sharePdf() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _buildPdf();
      final file = XFile.fromData(bytes, name: 'supplier_statement_${widget.supplier.name.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')}.pdf', mimeType: 'application/pdf');
      await SharePlus.instance.share(ShareParams(files: [file], text: 'Supplier statement for ${widget.supplier.name}.'));
    } catch (e) {
      _message('Unable to share PDF: ${_cleanError(e)}', true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _shareImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _buildPdf();
      final pages = await Printing.raster(bytes, pages: [0], dpi: 144).toList();
      if (pages.isEmpty) throw Exception('Unable to create statement image.');
      final imageBytes = await pages.first.toPng();
      final file = XFile.fromData(imageBytes, name: 'supplier_statement_${widget.supplier.name.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')}.png', mimeType: 'image/png');
      await SharePlus.instance.share(ShareParams(files: [file], text: 'Supplier statement image for ${widget.supplier.name}.'));
    } catch (e) {
      _message('Unable to share image: ${_cleanError(e)}', true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final bytes = await _buildPdf();
      await Printing.sharePdf(bytes: bytes, filename: 'supplier_statement.pdf');
    } catch (e) {
      _message('Unable to create PDF: ${_cleanError(e)}', true);
    }
  }

  String _cleanError(Object e) {
    final s = e.toString().replaceFirst('Exception:', '').trim();
    return s.isEmpty ? 'Something went wrong.' : s;
  }

  void _message(String text, [bool error = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? AppColors.danger : null));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchaseProvider>(
      builder: (context, provider, _) {
        final list = _filteredPurchases;
        final total = _total(list);
        final paid = _paid(list);
        final pending = _pending(list);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Supplier Statement'),
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
            actions: [
              IconButton(tooltip: 'Download / share PDF', onPressed: list.isEmpty ? null : _downloadPdf, icon: const Icon(Icons.picture_as_pdf_outlined)),
              IconButton(tooltip: 'Share PDF', onPressed: list.isEmpty || _sharing ? null : _sharePdf, icon: const Icon(Icons.share_outlined)),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(widget.supplier.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                if (widget.supplier.mobile.isNotEmpty) Text(widget.supplier.mobile),
                const SizedBox(height: 16),
                Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Statement period', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text(_startDate == null ? 'All transactions' : '${_date(_startDate!)} → ${_date(_endDate!)}'),
                  ])),
                  OutlinedButton.icon(onPressed: _pickRange, icon: const Icon(Icons.date_range_outlined), label: const Text('Select dates')),
                  if (_startDate != null) IconButton(onPressed: _clearRange, tooltip: 'Clear dates', icon: const Icon(Icons.clear)),
                ]))),
                const SizedBox(height: 10),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                  for (final value in ['All', 'Paid', 'Pending']) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(value), selected: _filter == value, onSelected: (_) => setState(() => _filter = value))),
                ])),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _summary('Purchase', _money(total), Icons.shopping_cart_outlined)),
                  const SizedBox(width: 10),
                  Expanded(child: _summary('Paid', _money(paid), Icons.check_circle_outline)),
                  const SizedBox(width: 10),
                  Expanded(child: _summary('Pending', _money(pending), Icons.pending_actions_outlined)),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: Text('Recent Purchases', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                  OutlinedButton.icon(onPressed: list.isEmpty || _sharing ? null : _shareImage, icon: const Icon(Icons.image_outlined), label: const Text('Image')),
                ]),
                const SizedBox(height: 8),
                if (list.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No purchase transactions found for this period.')))),
                ...list.map((p) => Card(margin: const EdgeInsets.only(bottom: 10), child: ExpansionTile(
                  leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
                  title: Text(p.id, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${_date(p.date)} • ${p.paymentStatus}'),
                  trailing: Text(_money(p.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [
                    ...p.items.map((i) => ListTile(contentPadding: EdgeInsets.zero, title: Text(i.productName), subtitle: Text('${i.quantity} ${i.unit} × ${_money(i.purchaseRate)}'), trailing: Text(_money(i.total)))),
                    const Divider(),
                    Align(alignment: Alignment.centerRight, child: Text('Paid: ${_money(p.paidAmount)} • Pending: ${_money((p.total-p.paidAmount).clamp(0,double.infinity))}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  ],
                ))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summary(String title, String value, IconData icon) {
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 20, color: AppColors.primary), const SizedBox(height: 8), Text(title, style: const TextStyle(fontSize: 12)), const SizedBox(height: 3), FittedBox(alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)))])));
  }
}