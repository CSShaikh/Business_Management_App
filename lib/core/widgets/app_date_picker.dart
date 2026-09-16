import 'package:flutter/material.dart';

/// App-wide date pickers.
///
/// These pickers intentionally do not expose Flutter's text/input mode.
/// A single month is rendered at a time and the user moves between months
/// with the arrow buttons. Range selection is handled directly in the grid.
class AppDatePicker {
  const AppDatePicker._();

  static Future<DateTime?> showDatePicker({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
    String? helpText,
    String? cancelText,
    String? confirmText,
    TransitionBuilder? builder,
    SelectableDayPredicate? selectableDayPredicate,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    Locale? locale,
    // Kept for source compatibility with Flutter's API. Input mode is
    // intentionally not exposed by this app-level picker.
    Icon? switchToInputEntryModeIcon,
    Icon? switchToCalendarEntryModeIcon,
    String? errorFormatText,
    String? errorInvalidText,
    String? fieldHintText,
    String? fieldLabelText,
    TextInputType? keyboardType,
  }) async {
    final DateTime first = _dateOnly(firstDate);
    final DateTime last = _dateOnly(lastDate);
    DateTime current = _dateOnly(initialDate);
    if (current.isBefore(first)) current = first;
    if (current.isAfter(last)) current = last;

    Widget dialog = _AppDateDialog(
      firstDate: first,
      lastDate: last,
      initialDate: current,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
      selectableDayPredicate: selectableDayPredicate,
    );

    if (builder != null) {
      dialog = Builder(
        builder: (dialogContext) => builder(dialogContext, dialog),
      );
    }

    return showDialog<DateTime>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      builder: (_) => dialog,
    );
  }

  static Future<DateTimeRange?> showDateRangePicker({
    required BuildContext context,
    required DateTime firstDate,
    required DateTime lastDate,
    DateTimeRange? initialDateRange,
    DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
    String? helpText,
    String? cancelText,
    String? saveText,
    TransitionBuilder? builder,
    SelectableDayPredicate? selectableDayPredicate,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    Locale? locale,
    Icon? switchToInputEntryModeIcon,
    Icon? switchToCalendarEntryModeIcon,
    String? errorFormatText,
    String? errorInvalidText,
    String? fieldStartHintText,
    String? fieldEndHintText,
    String? fieldStartLabelText,
    String? fieldEndLabelText,
  }) async {
    final DateTime first = _dateOnly(firstDate);
    final DateTime last = _dateOnly(lastDate);

    DateTime? start = initialDateRange == null
        ? null
        : _dateOnly(initialDateRange.start);
    DateTime? end = initialDateRange == null
        ? null
        : _dateOnly(initialDateRange.end);

    if (start != null && start.isBefore(first)) start = first;
    if (start != null && start.isAfter(last)) start = last;
    if (end != null && end.isBefore(first)) end = first;
    if (end != null && end.isAfter(last)) end = last;
    if (start != null && end != null && end.isBefore(start)) {
      final DateTime temp = start;
      start = end;
      end = temp;
    }

    final DateTime visibleMonth = DateTime(
      (start ?? end ?? DateTime.now()).year,
      (start ?? end ?? DateTime.now()).month,
    );

    Widget dialog = _AppDateRangeDialog(
      firstDate: first,
      lastDate: last,
      initialStart: start,
      initialEnd: end,
      initialMonth: visibleMonth,
      helpText: helpText,
      cancelText: cancelText,
      saveText: saveText,
      selectableDayPredicate: selectableDayPredicate,
    );

    if (builder != null) {
      dialog = Builder(
        builder: (dialogContext) => builder(dialogContext, dialog),
      );
    }

    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      builder: (_) => dialog,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

class _AppDateDialog extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime initialDate;
  final String? helpText;
  final String? cancelText;
  final String? confirmText;
  final SelectableDayPredicate? selectableDayPredicate;

  const _AppDateDialog({
    required this.firstDate,
    required this.lastDate,
    required this.initialDate,
    this.helpText,
    this.cancelText,
    this.confirmText,
    this.selectableDayPredicate,
  });

  @override
  State<_AppDateDialog> createState() => _AppDateDialogState();
}

class _AppDateDialogState extends State<_AppDateDialog> {
  late DateTime _selected;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _month = DateTime(_selected.year, _selected.month);
  }

  void _changeMonth(int delta) {
    final DateTime next = DateTime(_month.year, _month.month + delta);
    final DateTime minMonth = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
    );
    final DateTime maxMonth = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
    );
    if (next.isBefore(minMonth) || next.isAfter(maxMonth)) return;
    setState(() => _month = next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primary = theme.colorScheme.primary;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 300),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.helpText ?? 'Select date',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              Text(
                _monthLabel(_month),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              _WeekHeader(),
              const SizedBox(height: 2),
              _MonthGrid(
                month: _month,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                selected: _selected,
                selectableDayPredicate: widget.selectableDayPredicate,
                onSelected: (date) => setState(() => _selected = date),
                selectedColor: primary,
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(widget.cancelText ?? 'Cancel'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(widget.confirmText ?? 'Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDateRangeDialog extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final DateTime initialMonth;
  final String? helpText;
  final String? cancelText;
  final String? saveText;
  final SelectableDayPredicate? selectableDayPredicate;

  const _AppDateRangeDialog({
    required this.firstDate,
    required this.lastDate,
    required this.initialMonth,
    this.initialStart,
    this.initialEnd,
    this.helpText,
    this.cancelText,
    this.saveText,
    this.selectableDayPredicate,
  });

  @override
  State<_AppDateRangeDialog> createState() => _AppDateRangeDialogState();
}

class _AppDateRangeDialogState extends State<_AppDateRangeDialog> {
  DateTime? _start;
  DateTime? _end;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
  }

  void _changeMonth(int delta) {
    final DateTime next = DateTime(_month.year, _month.month + delta);
    final DateTime minMonth = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
    );
    final DateTime maxMonth = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
    );
    if (next.isBefore(minMonth) || next.isAfter(maxMonth)) return;
    setState(() => _month = next);
  }

  void _select(DateTime date) {
    if (widget.selectableDayPredicate != null &&
        !widget.selectableDayPredicate!(date)) {
      return;
    }

    if (_start == null || _end != null) {
      setState(() {
        _start = date;
        _end = null;
      });
      return;
    }

    if (date.isBefore(_start!)) {
      setState(() {
        _start = date;
        _end = null;
      });
      return;
    }

    setState(() => _end = date);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primary = theme.colorScheme.primary;
    final String startLabel = _start == null ? 'From' : _formatDate(_start!);
    final String endLabel = _end == null ? 'To' : _formatDate(_end!);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470, minWidth: 300),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.helpText ?? 'Select date range',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _RangeBox(
                      label: 'From',
                      value: startLabel,
                      active: _start != null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RangeBox(
                      label: 'To',
                      value: endLabel,
                      active: _end != null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                _monthLabel(_month),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const _WeekHeader(),
              const SizedBox(height: 2),
              _MonthGrid(
                month: _month,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                selected: _start,
                rangeStart: _start,
                rangeEnd: _end,
                selectableDayPredicate: widget.selectableDayPredicate,
                onSelected: _select,
                selectedColor: primary,
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(widget.cancelText ?? 'Cancel'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: _start != null && _end != null
                        ? () => Navigator.of(context)
                              .pop(DateTimeRange(start: _start!, end: _end!))
                        : null,
                    child: Text(widget.saveText ?? 'Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeBox extends StatelessWidget {
  final String label;
  final String value;
  final bool active;

  const _RangeBox({
    required this.label,
    required this.value,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? selected;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final SelectableDayPredicate? selectableDayPredicate;
  final ValueChanged<DateTime> onSelected;
  final Color selectedColor;

  const _MonthGrid({
    required this.month,
    required this.firstDate,
    required this.lastDate,
    required this.selected,
    required this.onSelected,
    required this.selectedColor,
    this.rangeStart,
    this.rangeEnd,
    this.selectableDayPredicate,
  });

  @override
  Widget build(BuildContext context) {
    final int offset = DateTime(month.year, month.month, 1).weekday % 7;
    final int days = DateTime(month.year, month.month + 1, 0).day;
    final List<Widget> cells = <Widget>[];

    for (int i = 0; i < 42; i++) {
      final int day = i - offset + 1;
      if (day < 1 || day > days) {
        cells.add(const SizedBox(height: 36));
        continue;
      }

      final DateTime date = DateTime(month.year, month.month, day);
      final bool allowed =
          !date.isBefore(firstDate) &&
          !date.isAfter(lastDate) &&
          (selectableDayPredicate == null || selectableDayPredicate!(date));
      final bool isStart = rangeStart != null && _sameDay(date, rangeStart!);
      final bool isEnd = rangeEnd != null && _sameDay(date, rangeEnd!);
      final bool inRange =
          rangeStart != null &&
          rangeEnd != null &&
          !date.isBefore(rangeStart!) &&
          !date.isAfter(rangeEnd!);
      final bool isSelected = selected != null && _sameDay(date, selected!);
      final bool isToday = _sameDay(date, DateTime.now());

      cells.add(
        GestureDetector(
          onTap: allowed ? () => onSelected(date) : null,
          child: Container(
            height: 31,
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: inRange ? selectedColor.withValues(alpha: 0.18) : null,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(isStart ? 20 : 0),
                right: Radius.circular(isEnd ? 20 : 0),
              ),
            ),
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isSelected || isStart || isEnd)
                      ? selectedColor
                      : null,
                  border: isToday && !(isSelected || isStart || isEnd)
                      ? Border.all(color: selectedColor, width: 1.3)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: (isSelected || isStart || isEnd || isToday)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: !allowed
                        ? Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.30)
                        : (isSelected || isStart || isEnd)
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Keep every calendar row at a fixed, compact height. Using
    // `childAspectRatio` here makes the grid calculate a taller cell on
    // short browser windows, which can make the dialog overflow vertically.
    return GridView.builder(
      itemCount: cells.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 31,
        mainAxisSpacing: 0,
        crossAxisSpacing: 0,
      ),
      itemBuilder: (BuildContext context, int index) => cells[index],
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _monthLabel(DateTime date) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
