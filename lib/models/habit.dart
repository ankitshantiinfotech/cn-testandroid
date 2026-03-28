// Model representing a single habit/activity
class Habit {
  final int? id;
  final String name;
  final String emoji;
  final int orderIndex;

  Habit({
    this.id,
    required this.name,
    required this.emoji,
    required this.orderIndex,
  });

  // Convert to Map for database storage
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'order_index': orderIndex,
      };

  // Create Habit from database Map
  factory Habit.fromMap(Map<String, dynamic> map) => Habit(
        id: map['id'] as int?,
        name: map['name'] as String,
        emoji: map['emoji'] as String,
        orderIndex: map['order_index'] as int,
      );
}
