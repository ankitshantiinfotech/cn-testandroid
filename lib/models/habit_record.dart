// Model representing whether a habit was completed on a specific date
class HabitRecord {
  final int? id;
  final int habitId;
  final String date; // Format: YYYY-MM-DD
  final bool isCompleted;

  HabitRecord({
    this.id,
    required this.habitId,
    required this.date,
    required this.isCompleted,
  });

  // Convert to Map for database storage
  Map<String, dynamic> toMap() => {
        'id': id,
        'habit_id': habitId,
        'date': date,
        'is_completed': isCompleted ? 1 : 0,
      };

  // Create HabitRecord from database Map
  factory HabitRecord.fromMap(Map<String, dynamic> map) => HabitRecord(
        id: map['id'] as int?,
        habitId: map['habit_id'] as int,
        date: map['date'] as String,
        isCompleted: (map['is_completed'] as int) == 1,
      );
}
