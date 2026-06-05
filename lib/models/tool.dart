class Tool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const Tool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  Map<String, dynamic> toClaudeJson() => {
        'name': name,
        'description': description,
        'input_schema': inputSchema,
      };

  Map<String, dynamic> toOpenAIJson() => {
        'type': 'function',
        'function': {'name': name, 'description': description, 'parameters': inputSchema},
      };

  Map<String, dynamic> toGeminiJson() => {
        'name': name,
        'description': description,
        'parameters': inputSchema,
      };
}

class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> input;

  const ToolCall({required this.id, required this.name, required this.input});
}

sealed class AgentEvent {
  const AgentEvent();
}

class AgentText extends AgentEvent {
  final String text;
  const AgentText(this.text);
}

class AgentToolStart extends AgentEvent {
  final ToolCall call;
  const AgentToolStart(this.call);
}

class AgentToolDone extends AgentEvent {
  final String toolName;
  final String result;
  const AgentToolDone(this.toolName, this.result);
}

class AgentCommandOutput extends AgentEvent {
  final String line;
  const AgentCommandOutput(this.line);
}

class AgentComplete extends AgentEvent {
  const AgentComplete();
}

class AgentError extends AgentEvent {
  final String message;
  const AgentError(this.message);
}
