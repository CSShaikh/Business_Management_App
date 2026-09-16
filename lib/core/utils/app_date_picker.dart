import 'package:flutter/material.dart';

/// App-wide non-scrolling calendar pickers.
///
/// These pickers intentionally use one fixed calendar month at a time.
/// Users select dates directly from the calendar; there is no text-input
/// mode and the calendar itself never becomes vertically scrollable.
class AppDatePicker {
  const AppDatePicker._();

  static Future<DateTime?> showDatePicker({
    required BuildContext context,
    required DateTime firstDate,
    required DateTime lastDate,
    DateTime? initialDate,
    DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
    String? helpText,
    String cancelText = 'Cancel',
    String confirmText = 'OK',
    Widget Function(BuildContext, Widget?)? builder,
  }) async {
    // Kept for call-site compatibility. This custom picker is always calendar-only.
    assert(initialEntryMode == DatePickerEntryMode.calendar ||
        initialEntryMode == DatePickerEntryMode.input);
    final DateTime safeFirst = _dateOnly(firstDate);
    final DateTime safeLast = _dateOnly(lastDate);
    final DateTime fallback = _dateOnly(initialDate ?? DateTime.now());
    final DateTime safeInitial = _clampDate(fallback, safeFirst, safeLast);

    final Widget dialog = _CalendarDialog(
      firstDate: safeFirst,
      lastDate: safeLast,
      initialDate: safeInitial,
      rangeMode: false,
      helpText: helpText ?? 'Select date',
      cancelText: cancelText,
      confirmText: confirmText,
    );

    final Widget child = builder?.call(context, dialog) ?? dialog;
    return showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (_) => child,
    );
  }

  static Future<DateTimeRange?> showDateRangePicker({
    required BuildContext context,
    required DateTime firstDate,
    required DateTime lastDate,
    DateTimeRange? initialDateRange,
    DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
    String? helpText,
    String cancelText = 'Cancel',
    String saveText = 'Save',
    Widget Function(BuildContext, Widget?)? builder,
  }) async {
    // Kept for call-site compatibility. This custom picker is always calendar-only.
    assert(initialEntryMode == DatePickerEntryMode.calendar ||
        initialEntryMode == DatePickerEntryMode.input);
    final DateTime safeFirst = _dateOnly(firstDate);
    final DateTime safeLast = _dateOnly(lastDate);

    DateTime? start;
    DateTime? end;
    if (initialDateRange != null) {
      final DateTime initialStart =
          _clampDate(_dateOnly(initialDateRange.start), safeFirst, safeLast);
      final DateTime initialEnd =
          _clampDate(_dateOnly(initialDateRange.end), safeFirst, safeLast);
      if (!initialStart.isAfter(initialEnd)) {
        start = initialStart;
        end = initialEnd;
      }
    }

    final Widget dialog = _CalendarDialog(
      firstDate: safeFirst,
      lastDate: safeLast,
      initialStartDate: start,
      initialEndDate: end,
      rangeMode: true,
      helpText: helpText ?? 'Select date range',
      cancelText: cancelText,
      confirmText: saveText,
    );

    final Widget child = builder?.call(context, dialog) ?? dialog;
    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: false,
      builder: (_) => child,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _clampDate(
    DateTime value,
    DateTime first,
    DateTime last,
  ) {
    if (value.isBefore(first)) return first;
    if (value.isAfter(last)) return last;
    return value;
  }
}

class _CalendarDialog extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialDate;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final bool rangeMode;
  final String helpText;
  final String cancelText;
  final String confirmText;

  const _CalendarDialog({
    required this.firstDate,
    required this.lastDate,
    required this.rangeMode,
    required this.helpText,
    required this.cancelText,
    required this.confirmText,
    this.initialDate,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late DateTime _visibleMonth;
  DateTime? _selectedDate;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;

    final DateTime anchor =
        widget.rangeMode ? (_startDate ?? DateTime.now()) : (_selectedDate ?? DateTime.now());
    _visibleMonth = DateTime(anchor.year, anchor.month);
    _visibleMonth = _clampMonth(_visibleMonth);
  }

  DateTime _clampMonth(DateTime month) {
    final DateTime firstMonth =
        DateTime(widget.firstDate.year, widget.firstDate.month);
    final DateTime lastMonth =
        DateTime(widget.lastDate.year, widget.lastDate.month);
    if (month.isBefore(firstMonth)) return firstMonth;
    if (month.isAfter(lastMonth)) return lastMonth;
    return month;
  }

  bool get _canGoPrevious {
    final DateTime firstMonth =
        DateTime(widget.firstDate.year, widget.firstDate.month);
    return _visibleMonth.isAfter(firstMonth);
  }

  bool get _canGoNext {
    final DateTime lastMonth =
        DateTime(widget.lastDate.year, widget.lastDate.month);
    return _visibleMonth.isBefore(lastMonth);
  }

  void _previousMonth() {
    if (!_canGoPrevious) return;
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _nextMonth() {
    if (!_canGoNext) return;
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  bool _isDisabled(DateTime date) =>
      date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate);

  bool _isSameDay(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  bool _isInRange(DateTime date) {
    if (_startDate == null || _endDate == null) return false;
    return !date.isBefore(_startDate!) && !date.isAfter(_endDate!);
  }

  void _selectDay(DateTime date) {
    if (_isDisabled(date)) return;

    setState(() {
      if (!widget.rangeMode) {
        _selectedDate = date;
        return;
      }

      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = date;
        _endDate = null;
      } else if (date.isBefore(_startDate!)) {
        _endDate = _startDate;
        _startDate = date;
      } else {
        _endDate = date;
      }
    });
  }

  void _confirm() {
    if (widget.rangeMode) {
      if (_startDate == null || _endDate == null) return;
      Navigator.of(context).pop(
        DateTimeRange(start: _startDate!, end: _endDate!),
      );
      return;
    }

    if (_selectedDate == null) return;
    Navigator.of(context).pop(_selectedDate);
  }

  String _headerDate(DateTime? date) {
    if (date == null) return 'Select';
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primary = theme.colorScheme.primary;
    final Color onSurface = theme.colorScheme.onSurface;
    final Color muted = theme.colorScheme.onSurfaceVariant;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.helpText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (widget.rangeMode) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _DateBox(
                        label: 'From',
                        value: _headerDate(_startDate),
                        selected: _startDate != null && _endDate == null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateBox(
                        label: 'To',
                        value: _headerDate(_endDate),
                        selected: _endDate != null,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 4),
                _DateBox(
                  label: 'Selected date',
                  value: _headerDate(_selectedDate),
                  selected: _selectedDate != null,
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: _canGoPrevious ? _previousMonth : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _monthTitle(_visibleMonth),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: _canGoNext ? _nextMonth : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: const [
                  'S', 'M', 'T', 'W', 'T', 'F', 'S',
                ].map((label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 6),
              _buildCalendarGrid(theme, primary, onSurface, muted),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(widget.cancelText),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _canConfirm ? _confirm : null,
                    child: Text(widget.confirmText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canConfirm =>
      widget.rangeMode ? _startDate != null && _endDate != null : _selectedDate != null;

  Widget _buildCalendarGrid(
    ThemeData theme,
    Color primary,
    Color onSurface,
    Color muted,
  ) {
    final DateTime first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final int leading = first.weekday % 7;
    final int daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;

    final List<Widget> cells = <Widget>[];
    for (int i = 0; i < leading; i++) {
      cells.add(const SizedBox(height: 42));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final DateTime date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
      final bool disabled = _isDisabled(date);
      final bool selected = widget.rangeMode
          ? _isSameDay(date, _startDate) || _isSameDay(date, _endDate)
          : _isSameDay(date, _selectedDate);
      final bool inRange = widget.rangeMode && _isInRange(date);
      final bool today = _isSameDay(date, DateTime.now());

      cells.add(
        InkWell(
          onTap: disabled ? null : () => _selectDay(date),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (inRange)
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: primary.withValues(alpha: 0.12),
                    ),
                  ),
                if (selected)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (today && !selected)
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primary, width: 1.2),
                    ),
                  ),
                Text(
                  '$day',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: disabled
                        ? muted.withValues(alpha: 0.45)
                        : selected
                            ? theme.colorScheme.onPrimary
                            : onSurface,
                    fontWeight: selected || today ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    while (cells.length % 7 != 0) {
      cells.add(const SizedBox(height: 42));
    }

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(
        Row(
          children: cells.sublist(i, i + 7).map((cell) => Expanded(child: cell)).toList(),
        ),
      );
    }

    return Column(children: rows);
  }

  String _monthTitle(DateTime date) {
    const months = <String>[
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;

  const _DateBox({
    required this.label,
    required this.value,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 1.4 : 1,
        ),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
