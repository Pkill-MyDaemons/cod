import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../llm/agent_llm.dart';
import '../models/tool.dart';

const int _maxIterations = 20;
const int _maxFileBytes = 32768;

final _blockedCommands = RegExp(
  r'\b(sudo|rm\s+-rf|dd\s+if|mkfs|format|fdisk)\b',
  caseSensitive: false,
);

class AgentService {
  static final List<Tool> codeTools = [
    Tool(
      name: 'read_file',
      description: 'Read the contents of a file.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'File path (relative to working dir or absolute).'},
        },
        'required': ['path'],
      },
    ),
    Tool(
      name: 'write_file',
      description: 'Write (or overwrite) a file with given content.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
          'content': {'type': 'string'},
        },
        'required': ['path', 'content'],
      },
    ),
    Tool(
      name: 'list_directory',
      description: 'List files and subdirectories at a path.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'Directory path. Defaults to working directory.'},
        },
        'required': [],
      },
    ),
    Tool(
      name: 'run_command',
      description: 'Run a shell command in the working directory. Output is returned. Timeout: 30s.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'command': {'type': 'string'},
        },
        'required': ['command'],
      },
    ),
    Tool(
      name: 'search_files',
      description: 'Grep for a pattern across files in a directory.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'pattern': {'type': 'string'},
          'directory': {'type': 'string'},
        },
        'required': ['pattern', 'directory'],
      },
    ),
    Tool(
      name: 'create_directory',
      description: 'Create a directory (and any missing parents).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
        },
        'required': ['path'],
      },
    ),
  ];

  static final List<Tool> taskTools = [
    ...codeTools,
    Tool(
      name: 'mark_complete',
      description: 'Mark this task as done. Call when the task is fully completed.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'summary': {'type': 'string', 'description': 'Brief summary of what was accomplished.'},
        },
        'required': ['summary'],
      },
    ),
  ];

  Stream<AgentEvent> run({
    required String initialPrompt,
    required List<Tool> tools,
    required String model,
    required String apiKey,
    String? system,
    String? workingDir,
    /// Optional override — if provided, run_command uses this instead of
    /// the built-in Process.run. Lets the caller inject a sandbox executor.
    Future<String> Function(String command)? commandRunner,
  }) async* {
    final llm = AgentLLM();
    final messages = <Map<String, dynamic>>[
      {'role': 'user', 'content': initialPrompt},
    ];

    for (int i = 0; i < _maxIterations; i++) {
      AgentLLMResponse response;
      try {
        response = await llm.call(
          messages: messages,
          tools: tools,
          model: model,
          apiKey: apiKey,
          system: system,
        );
      } catch (e) {
        yield AgentError('LLM error: $e');
        return;
      }

      if (response.text.isNotEmpty) {
        yield AgentText(response.text);
      }

      if (!response.hasToolCalls) {
        yield const AgentComplete();
        return;
      }

      // Append assistant message with content blocks
      final assistantContent = <Map<String, dynamic>>[];
      if (response.text.isNotEmpty) {
        assistantContent.add({'type': 'text', 'text': response.text});
      }
      for (final tc in response.toolCalls) {
        assistantContent.add({
          'type': 'tool_use',
          'id': tc.id,
          'name': tc.name,
          'input': tc.input,
        });
      }
      messages.add({'role': 'assistant', 'content': assistantContent});

      // Execute tools and collect results
      final toolResults = <Map<String, dynamic>>[];
      for (final tc in response.toolCalls) {
        yield AgentToolStart(tc);
        final result = await _execute(tc, workingDir: workingDir, commandRunner: commandRunner);
        yield AgentToolDone(tc.name, result);
        toolResults.add({
          'type': 'tool_result',
          'tool_use_id': tc.id,
          'content': result,
        });
      }
      messages.add({'role': 'user', 'content': toolResults});
    }

    yield const AgentError('Max iterations reached.');
  }

  Future<String> _execute(
    ToolCall tc, {
    String? workingDir,
    Future<String> Function(String)? commandRunner,
  }) async {
    try {
      return switch (tc.name) {
        'read_file' => _readFile(tc.input['path'] as String, workingDir),
        'write_file' => _writeFile(
            tc.input['path'] as String,
            tc.input['content'] as String,
            workingDir),
        'list_directory' => _listDir(
            tc.input['path'] as String? ?? '',
            workingDir),
        'run_command' => commandRunner != null
            ? commandRunner(tc.input['command'] as String)
            : _runCommand(tc.input['command'] as String, workingDir),
        'search_files' => _searchFiles(
            tc.input['pattern'] as String,
            tc.input['directory'] as String,
            workingDir),
        'create_directory' => _createDir(tc.input['path'] as String, workingDir),
        'mark_complete' => 'Task marked complete: ${tc.input['summary']}',
        _ => 'Unknown tool: ${tc.name}',
      };
    } catch (e) {
      return 'Error: $e';
    }
  }

  String _resolve(String path, String? workingDir) {
    if (path.startsWith('/')) return path;
    if (workingDir != null && workingDir.isNotEmpty) {
      return '$workingDir/$path';
    }
    return path;
  }

  Future<String> _readFile(String path, String? workingDir) async {
    final full = _resolve(path, workingDir);
    final f = File(full);
    if (!await f.exists()) return 'File not found: $full';
    final bytes = await f.readAsBytes();
    if (bytes.length > _maxFileBytes) {
      final text = utf8.decode(bytes.sublist(0, _maxFileBytes), allowMalformed: true);
      return '$text\n\n... (truncated — ${bytes.length - _maxFileBytes} bytes omitted)';
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<String> _writeFile(String path, String content, String? workingDir) async {
    final full = _resolve(path, workingDir);
    final f = File(full);
    await f.parent.create(recursive: true);
    await f.writeAsString(content);
    return 'Wrote ${content.length} chars to $full';
  }

  Future<String> _listDir(String path, String? workingDir) async {
    final full = path.isEmpty ? (workingDir ?? '.') : _resolve(path, workingDir);
    final dir = Directory(full);
    if (!await dir.exists()) return 'Directory not found: $full';
    final entries = await dir.list().toList();
    entries.sort((a, b) {
      final aIsDir = a is Directory;
      final bIsDir = b is Directory;
      if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
      return a.path.compareTo(b.path);
    });
    return entries.map((e) {
      final name = e.path.split('/').last;
      return e is Directory ? '$name/' : name;
    }).join('\n');
  }

  Future<String> _runCommand(String command, String? workingDir) async {
    if (_blockedCommands.hasMatch(command)) {
      return 'Blocked: command contains a potentially destructive operation.';
    }
    final result = await Process.run(
      'sh',
      ['-c', command],
      workingDirectory: workingDir,
      runInShell: false,
    ).timeout(const Duration(seconds: 30));
    final out = (result.stdout as String).trim();
    final err = (result.stderr as String).trim();
    final parts = [if (out.isNotEmpty) out, if (err.isNotEmpty) 'stderr:\n$err'];
    final combined = parts.join('\n');
    if (combined.length > _maxFileBytes) {
      return combined.substring(0, _maxFileBytes) + '\n... (truncated)';
    }
    return combined.isEmpty ? '(no output)' : combined;
  }

  Future<String> _searchFiles(String pattern, String directory, String? workingDir) async {
    final full = _resolve(directory, workingDir);
    final result = await Process.run(
      'grep',
      ['-r', '-n', '--include=*.*', '-l', pattern, full],
      runInShell: false,
    ).timeout(const Duration(seconds: 15));
    final out = (result.stdout as String).trim();
    return out.isEmpty ? 'No matches found.' : out;
  }

  Future<String> _createDir(String path, String? workingDir) async {
    final full = _resolve(path, workingDir);
    await Directory(full).create(recursive: true);
    return 'Created directory: $full';
  }
}

// Standalone helper used by email screen for AI summarize/draft (streaming)
Future<String> fetchEmailAI({
  required String prompt,
  required String model,
  required String apiKey,
}) async {
  final resp = await http.post(
    Uri.parse('https://api.anthropic.com/v1/messages'),
    headers: {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: jsonEncode({
      'model': model,
      'max_tokens': 2048,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    }),
  );
  if (resp.statusCode != 200) throw Exception('${resp.statusCode}: ${resp.body}');
  final json = jsonDecode(resp.body) as Map<String, dynamic>;
  final content = json['content'] as List;
  return content
      .where((b) => (b as Map)['type'] == 'text')
      .map((b) => (b as Map)['text'] as String)
      .join('');
}
