import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/habit.dart';
import '../models/habit_record.dart';

class MonthlyViewScreen extends StatefulWidget {
  const MonthlyViewScreen({super.key});

  @override
  State<MonthlyViewScreen> createState() => _MonthlyViewScreenState();
}

class _MonthlyViewScreenState extends State<MonthlyViewScreen> {
  late DateTime _selectedMonth;
  List<Habit> _habits = [];
  // Map: date string → { habitId → isCompleted }
  Map<String, Map<int, bool>> _recordMap = {};
  bool _isLoading = true;
  late int _daysInMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final db = DatabaseHelper.instance;
    final habits = await db.getAllHabits();

    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final startDate = _fmt(DateTime(year, month, 1));
    final endDate = _fmt(DateTime(year, month, daysInMonth));

    final records = await db.getRecordsForDateRange(startDate, endDate);

    // Build nested map
    final Map<String, Map<int, bool>> recordMap = {};
    for (final record in records) {
      recordMap.putIfAbsent(record.date, () => {});
      recordMap[record.date]![record.habitId] = record.isCompleted;
    }

    setState(() {
      _habits = habits;
      _recordMap = recordMap;
      _daysInMonth = daysInMonth;
      _isLoading = false;
    });
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    final next =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    // Don't go beyond current month
    if (next.isAfter(DateTime.now())) return;
    setState(() => _selectedMonth = next);
    _loadData();
  }

  String _fmt(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _dayKey(int day) =>
      '${_selectedMonth.year.toString().padLeft(4, '0')}-'
      '${_selectedMonth.month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  bool _isToday(int day) =>
      _dayKey(day) == _fmt(DateTime.now());

  bool _isFuture(int day) =>
      DateTime(_selectedMonth.year, _selectedMonth.month, day)
          .isAfter(DateTime.now());

  // How many habits completed on a given day
  int _completedOnDay(int day) {
    final records = _recordMap[_dayKey(day)];
    if (records == null) return 0;
    return records.values.where((v) => v).length;
  }

  // Summary stats for the month
  int get _totalDaysWithAnyCompletion =>
      List.generate(_daysInMonth, (i) => i + 1)
          .where((d) => !_isFuture(d) && _completedOnDay(d) > 0)
          .length;

  double get _monthlyAverage {
    final validDays = List.generate(_daysInMonth, (i) => i + 1)
        .where((d) => !_isFuture(d))
        .toList();
    if (validDays.isEmpty || _habits.isEmpty) return 0;
    final total = validDays.fold<int>(0, (sum, d) => sum + _completedOnDay(d));
    return total / (validDays.length * _habits.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          _buildHeader(),
          if (!_isLoading) _buildSummaryBar(),
          if (!_isLoading) _buildLegend(),
          _isLoading
              ? const Expanded(
                  child: Center(child: CircularProgressIndicator()))
              : Expanded(child: _buildScrollableGrid()),
        ],
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final isCurrentMonth = _selectedMonth.year == DateTime.now().year &&
        _selectedMonth.month == DateTime.now().month;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Monthly View',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _previousMonth,
                    icon: const Icon(Icons.chevron_left,
                        color: Colors.white, size: 30),
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: isCurrentMonth ? null : _nextMonth,
                    icon: Icon(
                      Icons.chevron_right,
                      color: isCurrentMonth
                          ? Colors.white30
                          : Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SUMMARY BAR ─────────────────────────────────────────────────────────

  Widget _buildSummaryBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _summaryChip(
              '📅',
              '$_totalDaysWithAnyCompletion days',
              'Active',
              const Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryChip(
              '📊',
              '${(_monthlyAverage * 100).toInt()}%',
              'Monthly avg',
              const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryChip(
              '🎯',
              '${_habits.length}',
              'Habits',
              const Color(0xFFFF6B9D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(
      String emoji, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 13),
          ),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // ─── LEGEND ──────────────────────────────────────────────────────────────

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _legendItem(const Color(0xFF6C63FF).withOpacity(0.25), '✓ Done'),
          const SizedBox(width: 14),
          _legendItem(Colors.red.shade50, '✗ Missed'),
          const SizedBox(width: 14),
          _legendItem(Colors.grey.shade100, 'No record'),
          const Spacer(),
          Text(
            '← Scroll →',
            style:
                TextStyle(fontSize: 10, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  // ─── MAIN GRID ───────────────────────────────────────────────────────────

  Widget _buildScrollableGrid() {
    const double habitLabelWidth = 148.0;
    const double cellSize = 34.0;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed left column: habit names
          SizedBox(
            width: habitLabelWidth,
            child: Column(
              children: [
                // Empty top-left corner
                SizedBox(height: cellSize + 8),
                // Habit name labels
                Expanded(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        ..._habits.map(
                          (habit) => _habitLabel(habit, cellSize),
                        ),
                        _totalLabel(cellSize),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable right section: dates + cells
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: cellSize * _daysInMonth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header row
                    _buildDateHeader(cellSize),
                    // Data rows
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            ..._habits.map(
                              (habit) => _buildHabitRow(habit, cellSize),
                            ),
                            _buildTotalRow(cellSize),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitLabel(Habit habit, double height) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Text(habit.emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              habit.name,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalLabel(double height) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFFEEEBFF),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '✅ Total',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              color: Color(0xFF6C63FF)),
        ),
      ),
    );
  }

  Widget _buildDateHeader(double cellSize) {
    return SizedBox(
      height: cellSize + 8,
      child: Row(
        children: List.generate(_daysInMonth, (i) {
          final day = i + 1;
          final isToday = _isToday(day);
          return Container(
            width: cellSize,
            alignment: Alignment.center,
            decoration: isToday
                ? BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                  )
                : null,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday
                    ? const Color(0xFF6C63FF)
                    : Colors.grey.shade500,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHabitRow(Habit habit, double cellSize) {
    return Row(
      children: List.generate(_daysInMonth, (i) {
        final day = i + 1;
        final dateKey = _dayKey(day);
        final dayRecords = _recordMap[dateKey];
        final isCompleted = dayRecords?[habit.id!] ?? false;
        final hasData = dayRecords?.containsKey(habit.id!) ?? false;
        final future = _isFuture(day);
        final today = _isToday(day);

        Color bgColor;
        Widget? cell;

        if (future) {
          bgColor = Colors.grey.shade50;
        } else if (isCompleted) {
          bgColor = const Color(0xFF6C63FF).withOpacity(0.18);
          cell = const Icon(Icons.check, size: 12, color: Color(0xFF6C63FF));
        } else if (hasData) {
          bgColor = Colors.red.shade50;
          cell = Icon(Icons.close, size: 10, color: Colors.red.shade300);
        } else {
          bgColor = Colors.grey.shade50;
        }

        return Container(
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              right: BorderSide(color: Colors.grey.shade100),
              bottom: BorderSide(color: Colors.grey.shade100),
              left: today
                  ? const BorderSide(color: Color(0xFF6C63FF), width: 1.5)
                  : BorderSide.none,
            ),
          ),
          child: Center(child: cell),
        );
      }),
    );
  }

  Widget _buildTotalRow(double cellSize) {
    return Row(
      children: List.generate(_daysInMonth, (i) {
        final day = i + 1;
        final count = _completedOnDay(day);
        final future = _isFuture(day);

        Color bgColor = const Color(0xFFEEEBFF);
        if (future) bgColor = Colors.grey.shade100;
        if (count == _habits.length && !future && _habits.isNotEmpty) {
          bgColor = const Color(0xFF4CAF50).withOpacity(0.15);
        }

        return Container(
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              right: BorderSide(color: Colors.grey.shade200),
              top: const BorderSide(color: Color(0xFFCCC8FF)),
            ),
          ),
          child: Center(
            child: future
                ? null
                : Text(
                    count > 0 ? '$count' : '',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: count == _habits.length
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF6C63FF),
                    ),
                  ),
          ),
        );
      }),
    );
  }
}
