import 'package:uuid/uuid.dart';
import 'message.dart';

class Session {
  final String id;
  String title;
  final List<Message> messages;
  final DateTime createdAt;
  DateTime updatedAt;
  String providerId;
  String modelId;

  Session({
    String? id,
    String? title,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.providerId,
    required this.modelId,
  })  : id = id ?? const Uuid().v4(),
        title = title ?? 'New chat',
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static String titleFrom(String text) {
    final s = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return s.length > 42 ? '${s.substring(0, 39)}...' : s;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'providerId': providerId,
        'modelId': modelId,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as String,
        title: json['title'] as String,
        messages: (json['messages'] as List)
            .map((m) => Message.fromJson(m as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        providerId: json['providerId'] as String,
        modelId: json['modelId'] as String,
      );
}
