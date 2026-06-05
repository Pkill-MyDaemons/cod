import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tool.dart';

class AgentLLM {
  Future<AgentLLMResponse> call({
    required List<Map<String, dynamic>> messages,
    required List<Tool> tools,
    required String model,
    required String apiKey,
    String? system,
    int maxTokens = 8192,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      if (system != null && system.isNotEmpty) 'system': system,
      'tools': tools.map((t) => t.toClaudeJson()).toList(),
      'messages': messages,
    };

    final resp = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw Exception('Claude ${resp.statusCode}: ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    String text = '';
    final calls = <ToolCall>[];

    for (final block in json['content'] as List) {
      final b = block as Map<String, dynamic>;
      switch (b['type'] as String) {
        case 'text':
          text += b['text'] as String;
        case 'tool_use':
          calls.add(ToolCall(
            id: b['id'] as String,
            name: b['name'] as String,
            input: Map<String, dynamic>.from(b['input'] as Map),
          ));
      }
    }

    return AgentLLMResponse(
      text: text,
      toolCalls: calls,
      stopReason: json['stop_reason'] as String,
    );
  }
}

class AgentLLMResponse {
  final String text;
  final List<ToolCall> toolCalls;
  final String stopReason;

  const AgentLLMResponse({
    required this.text,
    required this.toolCalls,
    required this.stopReason,
  });

  bool get hasToolCalls => toolCalls.isNotEmpty;
}
