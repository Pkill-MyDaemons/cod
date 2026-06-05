import 'package:uuid/uuid.dart';

enum MessageRole { user, assistant, system }

class Message {
  final String id;
  final MessageRole role;
  String content;
  final DateTime timestamp;
  bool isStreaming;

  Message({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isStreaming = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  factory Message.user(String content) =>
      Message(role: MessageRole.user, content: content);

  factory Message.assistant(String content, {bool isStreaming = false}) =>
      Message(role: MessageRole.assistant, content: content, isStreaming: isStreaming);

  factory Message.system(String content) =>
      Message(role: MessageRole.system, content: content);

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        role: MessageRole.values.byName(json['role'] as String),
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
