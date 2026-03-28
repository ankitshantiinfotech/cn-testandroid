import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/habit.dart';
import '../models/habit_record.dart';

/// Singleton class managing all SQLite database operations.
/// Data persists permanently on device even after app is closed.
class DatabaseHelper {
  // Singleton pattern – only one instance exists
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Get (or create) the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('routine_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  /// Creates the tables and inserts your default habits on first launch
  Future<void> _createDB(Database db, int version) async {
    // Table to store habit definitions
    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        order_index INTEGER NOT NULL
      )
    ''');

    // Table to store daily check-in records
    await db.execute('''
      CREATE TABLE habit_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (habit_id) REFERENCES habits (id),
        UNIQUE(habit_id, date)
      )
    ''');

    // Insert your 15 default habits
    final defaultHabits = [
      {'name': 'Wake up at 6:00 AM', 'emoji': '⏰', 'order_index': 0},
      {'name': 'Warm-up', 'emoji': '🤸', 'order_index': 1},
      {'name': 'Gym', 'emoji': '💪', 'order_index': 2},
      {'name': '6K Steps', 'emoji': '👟', 'order_index': 3},
      {'name': 'Skin Care', 'emoji': '✨', 'order_index': 4},
      {'name': 'Drink 3L Water', 'emoji': '💧', 'order_index': 5},
      {'name': 'No Junk Food', 'emoji': '🚫', 'order_index': 6},
      {'name': 'No Sugar', 'emoji': '🍬', 'order_index': 7},
      {'name': 'Save Something', 'emoji': '💰', 'order_index': 8},
      {'name': 'Reading (2 pages)', 'emoji': '📚', 'order_index': 9},
      {'name': 'Listen 2 Podcasts', 'emoji': '🎧', 'order_index': 10},
      {'name': 'Speaking Practice (2 min)', 'emoji': '🗣️', 'order_index': 11},
      {'name': 'Speak 30 Sentences', 'emoji': '💬', 'order_index': 12},
      {'name': 'Audio/Video Practice', 'emoji': '🎬', 'order_index': 13},
      {'name': '30 Min Reels Limit', 'emoji': '📱', 'order_index': 14},
    ];

    final batch = db.batch();
    for (final habit in defaultHabits) {
      batch.insert('habits', habit);
    }
    await batch.commit(noResult: true);
  }

  // ─── HABIT OPERATIONS ────────────────────────────────────────────────────

  /// Returns all habits ordered by position
  Future<List<Habit>> getAllHabits() async {
    final db = await database;
    final maps = await db.query('habits', orderBy: 'order_index');
    return maps.map((map) => Habit.fromMap(map)).toList();
  }

  // ─── RECORD OPERATIONS ───────────────────────────────────────────────────

  /// Returns all records for a specific date
  Future<List<HabitRecord>> getRecordsForDate(String date) async {
    final db = await database;
    final maps = await db.query(
      'habit_records',
      where: 'date = ?',
      whereArgs: [date],
    );
    return maps.map((map) => HabitRecord.fromMap(map)).toList();
  }

  /// Toggles (saves/updates) a habit's completion status for a date.
  /// Uses INSERT OR REPLACE so it always works, whether record exists or not.
  Future<void> toggleRecord(int habitId, String date, bool isCompleted) async {
    final db = await database;
    await db.insert(
      'habit_records',
      {
        'habit_id': habitId,
        'date': date,
        'is_completed': isCompleted ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all records within a date range (inclusive)
  Future<List<HabitRecord>> getRecordsForDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'habit_records',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date',
    );
    return maps.map((map) => HabitRecord.fromMap(map)).toList();
  }

  // ─── STREAK TRACKING ─────────────────────────────────────────────────────

  /// Calculates how many consecutive days you completed at least 1 habit.
  /// Counts backwards from today.
  Future<int> getCurrentStreak() async {
    final db = await database;
    final habits = await getAllHabits();
    if (habits.isEmpty) return 0;

    int streak = 0;
    var date = DateTime.now();

    for (int i = 0; i < 365; i++) {
      // Format date as YYYY-MM-DD
      final dateStr = _formatDate(date);

      final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM habit_records WHERE date = ? AND is_completed = 1',
        [dateStr],
      );

      final count = (result.first['cnt'] as int?) ?? 0;
      if (count == 0) break;

      streak++;
      date = date.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Calculates best (longest) streak ever achieved
  Future<int> getBestStreak() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT DISTINCT date FROM habit_records WHERE is_completed = 1 ORDER BY date',
    );

    if (result.isEmpty) return 0;

    int bestStreak = 1;
    int currentStreak = 1;

    for (int i = 1; i < result.length; i++) {
      final prev = DateTime.parse(result[i - 1]['date'] as String);
      final curr = DateTime.parse(result[i]['date'] as String);
      final diff = curr.difference(prev).inDays;

      if (diff == 1) {
        currentStreak++;
        if (currentStreak > bestStreak) bestStreak = currentStreak;
      } else {
        currentStreak = 1;
      }
    }

    return bestStreak;
  }

  /// Returns completion percentage for each day in a month
  Future<Map<String, double>> getMonthlyCompletionRates(
    int year,
    int month,
  ) async {
    final db = await database;
    final habits = await getAllHabits();
    final habitCount = habits.length;
    if (habitCount == 0) return {};

    final startDate = _formatDate(DateTime(year, month, 1));
    final endDate =
        _formatDate(DateTime(year, month + 1, 0)); // Last day of month

    final result = await db.rawQuery(
      '''
      SELECT date, SUM(is_completed) as completed
      FROM habit_records
      WHERE date >= ? AND date <= ?
      GROUP BY date
    ''',
      [startDate, endDate],
    );

    final Map<String, double> rates = {};
    for (final row in result) {
      final date = row['date'] as String;
      final completed = (row['completed'] as int?) ?? 0;
      rates[date] = completed / habitCount;
    }
    return rates;
  }

  // ─── UTILITIES ────────────────────────────────────────────────────────────

  /// Formats DateTime to YYYY-MM-DD string
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
