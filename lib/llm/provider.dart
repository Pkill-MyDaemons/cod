import '../models/message.dart';

abstract class LLMProvider {
  String get id;
  String get name;

  Stream<String> stream({
    required List<Message> messages,
    required String model,
    required String apiKey,
    String? baseUrl,
    int maxTokens = 4096,
  });
}
