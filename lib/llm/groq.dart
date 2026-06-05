import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import 'provider.dart';

class GroqProvider implements LLMProvider {
  @override
  String get id => 'groq';
  @override
  String get name => 'Groq';

  @override
  Stream<String> stream({
    required List<Message> messages,
    required String model,
    required String apiKey,
    String? baseUrl,
    int maxTokens = 4096,
  }) async* {
    yield* openAICompatStream(
      url: 'https://api.groq.com/openai/v1/chat/completions',
      messages: messages,
      model: model,
      apiKey: apiKey,
      maxTokens: maxTokens,
    );
  }

  static Stream<String> openAICompatStream({
    required String url,
    required List<Message> messages,
    required String model,
    required String apiKey,
    int maxTokens = 4096,
  }) async* {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(url));
      request.headers.addAll({
        'authorization': 'Bearer $apiKey',
        'content-type': 'application/json',
      });
      request.body = jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'stream': true,
        'messages': messages
            .map((m) => {'role': m.role.name, 'content': m.content})
            .toList(),
      });

      final response = await client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('API ${response.statusCode}: $body');
      }

      String buf = '';
      await for (final bytes in response.stream) {
        buf += utf8.decode(bytes);
        final lines = buf.split('\n');
        buf = lines.removeLast();
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data == '[DONE]' || data.isEmpty) continue;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final choices = json['choices'] as List?;
            if (choices == null || choices.isEmpty) continue;
            final delta = choices[0]['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null) yield content;
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }
}
