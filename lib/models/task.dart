import 'package:uuid/uuid.dart';
import 'message.dart';

enum TaskStatus { todo, inProgress, done }

extension TaskStatusX on TaskStatus {
  TaskStatus get next => switch (this) {
        TaskStatus.todo => TaskStatus.inProgress,
        TaskStatus.inProgress => TaskStatus.done,
        TaskStatus.done => TaskStatus.todo,
      };

  String get label => switch (this) {
        TaskStatus.todo => 'todo',
        TaskStatus.inProgress => 'in progress',
        TaskStatus.done => 'done',
      };
}

class Task {
  final String id;
  String title;
  String description;
  TaskStatus status;
  final List<Message> thread;
  final DateTime createdAt;
  DateTime updatedAt;
  bool hasUnread;

  Task({
    String? id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.todo,
    List<Message>? thread,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.hasUnread = false,
  })  : id = id ?? const Uuid().v4(),
        thread = thread ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status.name,
        'thread': thread.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'hasUnread': hasUnread,
      };

  bool isExpired(int ttlDays) {
    if (ttlDays <= 0) return false;
    return DateTime.now().difference(updatedAt).inSeconds >=
        ttlDays * 86400;
  }

  Duration? timeUntilExpiry(int ttlDays) {
    if (ttlDays <= 0) return null;
    final expiry = updatedAt.add(Duration(days: ttlDays));
    final remaining = expiry.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        status: TaskStatus.values.byName(json['status'] as String),
        thread: (json['thread'] as List? ?? [])
            .map((m) => Message.fromJson(m as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        hasUnread: json['hasUnread'] as bool? ?? false,
      );
}
