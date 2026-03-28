import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/habit.dart';
import '../models/habit_record.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  List<Habit> _habits = [];
  Map<int, bool> _completedMap = {}; // habitId -> isCompleted
  bool _isLoading = true;
  late String _today;
  String _lastSaved = '';

  @override
  void initState() {
    super.initState();
    _today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final habits = await db.getAllHabits();
    final records = await db.getRecordsForDate(_today);

    // Build a map: habitId → completed status
    final Map<int, bool> completedMap = {};
    for (final habit in habits) {
      completedMap[habit.id!] = false; // default: not completed
    }
    for (final record in records) {
      completedMap[record.habitId] = record.isCompleted;
    }

    setState(() {
      _habits = habits;
      _completedMap = completedMap;
      _isLoading = false;
    });
  }

  /// Toggles a habit and INSTANTLY saves to local database (offline)
  Future<void> _toggleHabit(int habitId, bool newValue) async {
    // Save to database first
    await DatabaseHelper.instance.toggleRecord(habitId, _today, newValue);

    // Then update UI
    setState(() {
      _completedMap[habitId] = newValue;
      _lastSaved = 'Saved ✓  ${DateFormat('hh:mm a').format(DateTime.now())}';
    });
  }

  int get _completedCount =>
      _completedMap.values.where((v) => v).length;

  double get _progress =>
      _habits.isEmpty ? 0 : _completedCount / _habits.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTopSection(),
                _buildSaveIndicator(),
                Expanded(child: _buildHabitList()),
                _buildBottomSummary(),
              ],
            ),
    );
  }

  // ─── TOP SECTION (AppBar + Progress) ─────────────────────────────────────

  Widget _buildTopSection() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Daily Checklist',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, d MMMM yyyy')
                              .format(DateTime.now()),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Completion percentage badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(_progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_completedCount of ${_habits.length} habits done',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      if (_completedCount == _habits.length &&
                          _habits.isNotEmpty)
                        const Text(
                          '🎉 Complete!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 10,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _progress == 1.0
                            ? const Color(0xFF4CAF50)
                            : Colors.white,
                      ),
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

  // ─── AUTO-SAVE INDICATOR ─────────────────────────────────────────────────

  Widget _buildSaveIndicator() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _lastSaved.isEmpty
          ? const Color(0xFFF8F9FE)
          : const Color(0xFFE8F5E9),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          if (_lastSaved.isNotEmpty) ...[
            const Icon(Icons.cloud_done, size: 14, color: Color(0xFF4CAF50)),
            const SizedBox(width: 6),
          ],
          Text(
            _lastSaved.isEmpty
                ? '📱 Saved locally on your phone'
                : _lastSaved,
            style: TextStyle(
              fontSize: 11,
              color: _lastSaved.isEmpty
                  ? Colors.grey.shade500
                  : const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HABITS LIST ─────────────────────────────────────────────────────────

  Widget _buildHabitList() {
    // Group habits into categories
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      itemCount: _habits.length,
      itemBuilder: (context, index) {
        final habit = _habits[index];
        final isCompleted = _completedMap[habit.id!] ?? false;
        return _buildHabitTile(habit, isCompleted, index);
      },
    );
  }

  Widget _buildHabitTile(Habit habit, bool isCompleted, int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isCompleted
            ? const Color(0xFFEEEBFF)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          onTap: () => _toggleHabit(habit.id!, !isCompleted),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Emoji icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF6C63FF).withOpacity(0.15)
                        : const Color(0xFFF8F9FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      habit.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Habit name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? Colors.grey.shade500
                              : const Color(0xFF1A1A2E),
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: Colors.grey,
                        ),
                      ),
                      Text(
                        isCompleted ? 'Completed ✓' : 'Tap to mark done',
                        style: TextStyle(
                          fontSize: 11,
                          color: isCompleted
                              ? const Color(0xFF6C63FF)
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),

                // Animated checkbox
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? const Color(0xFF6C63FF)
                        : Colors.transparent,
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF6C63FF)
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── BOTTOM SUMMARY ──────────────────────────────────────────────────────

  Widget _buildBottomSummary() {
    final remaining = _habits.length - _completedCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  remaining == 0
                      ? '🎯 All done! Amazing work!'
                      : '$remaining habit${remaining == 1 ? '' : 's'} remaining',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: remaining == 0
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  'Data saved automatically offline',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (remaining > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_completedCount ✅',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
