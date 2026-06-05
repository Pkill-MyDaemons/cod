import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import 'provider.dart';

class OllamaProvider implements LLMProvider {
  @override
  String get id => 'ollama';
  @override
  String get name => 'Ollama';

  @override
  Stream<String> stream({
    required List<Message> messages,
    required String model,
    required String apiKey,
    String? baseUrl,
    int maxTokens = 4096,
  }) async* {
    final base =
        (baseUrl != null && baseUrl.isNotEmpty) ? baseUrl : 'http://localhost:11434';
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('$base/api/chat'));
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode({
        'model': model,
        'stream': true,
        'messages': messages
            .map((m) => {
                  'role': switch (m.role) {
                    MessageRole.user => 'user',
                    MessageRole.assistant => 'assistant',
                    MessageRole.system => 'system',
                  },
                  'content': m.content,
                })
            .toList(),
      });

      final response = await client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('Ollama ${response.statusCode}: $body');
      }

      String buf = '';
      await for (final bytes in response.stream) {
        buf += utf8.decode(bytes);
        final lines = buf.split('\n');
        buf = lines.removeLast();
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            final msg = json['message'] as Map<String, dynamic>?;
            final content = msg?['content'] as String?;
            if (content != null && content.isNotEmpty) yield content;
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }
}
