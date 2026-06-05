import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import 'provider.dart';

class GeminiProvider implements LLMProvider {
  @override
  String get id => 'gemini';
  @override
  String get name => 'Gemini';

  @override
  Stream<String> stream({
    required List<Message> messages,
    required String model,
    required String apiKey,
    String? baseUrl,
    int maxTokens = 4096,
  }) async* {
    final client = http.Client();
    try {
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?key=$apiKey&alt=sse';

      final systemParts = messages
          .where((m) => m.role == MessageRole.system)
          .map((m) => m.content)
          .join('\n');

      final contents = messages
          .where((m) => m.role != MessageRole.system)
          .map((m) => {
                'role': m.role == MessageRole.user ? 'user' : 'model',
                'parts': [
                  {'text': m.content}
                ],
              })
          .toList();

      final request = http.Request('POST', Uri.parse(url));
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode({
        'contents': contents,
        if (systemParts.isNotEmpty)
          'systemInstruction': {
            'parts': [
              {'text': systemParts}
            ]
          },
        'generationConfig': {'maxOutputTokens': maxTokens},
      });

      final response = await client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('Gemini ${response.statusCode}: $body');
      }

      String buf = '';
      await for (final bytes in response.stream) {
        buf += utf8.decode(bytes);
        final lines = buf.split('\n');
        buf = lines.removeLast();
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data.isEmpty) continue;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final candidates = json['candidates'] as List?;
            if (candidates == null || candidates.isEmpty) continue;
            final content = candidates[0]['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List?;
            if (parts == null || parts.isEmpty) continue;
            final text = parts[0]['text'] as String?;
            if (text != null) yield text;
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }
}
