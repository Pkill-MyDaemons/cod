import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tool.dart';
import '../services/agent_service.dart';
import '../services/sandbox_service.dart';
import '../state/code.dart';
import '../state/providers.dart';
import '../widgets/file_tree.dart';
import '../widgets/provider_badge.dart';

class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key});

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  double _sidebarWidth = 220;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Open folder',
    );
    if (path != null && mounted) {
      await ref.read(codeProvider.notifier).setWorkingDir(path);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || ref.read(codeProvider).isRunning) return;
    _inputCtrl.clear();

    final config = ref.read(configProvider);
    if (config.active.apiKey.isEmpty && config.activeProviderId != 'ollama') {
      _showSnack('Set a Claude API key in Settings first.');
      return;
    }

    // Switch to agent tab so the user sees the response
    ref.read(codeProvider.notifier).showAgentTab();

    final notifier = ref.read(codeProvider.notifier);
    final workingDir = ref.read(codeProvider).workingDir;
    notifier.addEntry(CodeEntry.user(text));
    notifier.setRunning(true);
    _scrollToBottom();

    final system = workingDir.isNotEmpty
        ? 'You are an expert coding assistant with access to file system and shell tools.\n'
          'Working directory: $workingDir\n'
          'Be concise. Use tools to understand the codebase before answering.'
        : 'You are an expert coding assistant. Be concise and think step-by-step.';

    final service = AgentService();
    await for (final event in service.run(
      initialPrompt: text,
      tools: AgentService.codeTools,
      model: config.active.selectedModel,
      apiKey: config.active.apiKey,
      system: system,
      workingDir: workingDir.isNotEmpty ? workingDir : null,
      commandRunner: ref.read(codeProvider.notifier).commandRunner,
    )) {
      switch (event) {
        case AgentText(:final text):
          if (text.isNotEmpty) notifier.addEntry(CodeEntry.assistant(text));
        case AgentToolStart(:final call):
          notifier.addEntry(CodeEntry.toolCall(call.name, _summarise(call.input)));
        case AgentToolDone(:final toolName, :final result):
          notifier.addEntry(CodeEntry.toolResult(toolName, result));
        case AgentComplete():
          break;
        case AgentError(:final message):
          notifier.addEntry(CodeEntry.error(message));
      }
      _scrollToBottom();
    }

    notifier.setRunning(false);
    _scrollToBottom();
  }

  String _summarise(Map<String, dynamic> input) {
    if (input.containsKey('path')) return '"${input['path']}"';
    if (input.containsKey('command')) return '"${input['command']}"';
    if (input.containsKey('pattern')) return '"${input['pattern']}" in ${input['directory'] ?? '.'}';
    return input.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final codeState = ref.watch(codeProvider);
    final config = ref.watch(configProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Code'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ProviderBadge(
              providerId: config.activeProviderId,
              modelId: config.active.selectedModel,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Clear conversation',
            onPressed: () => ref.read(codeProvider.notifier).clearConversation(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sandbox status strip
          _SandboxBar(state: codeState),
          // Main split area
          Expanded(
            child: Row(
              children: [
                // ── Left: file explorer ───────────────────────────────────
                SizedBox(
                  width: _sidebarWidth,
                  child: _FilePanel(
                    workingDir: codeState.workingDir,
                    selectedPath: codeState.activeFileIndex != null
                        ? codeState.openFiles[codeState.activeFileIndex!].path
                        : null,
                    onPickFolder: _pickFolder,
                    onFileTap: (path) =>
                        ref.read(codeProvider.notifier).openFile(path),
                  ),
                ),
                // ── Draggable divider ─────────────────────────────────────
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) => setState(() {
                      _sidebarWidth =
                          (_sidebarWidth + d.delta.dx).clamp(120.0, 480.0);
                    }),
                    child: Container(
                      width: 4,
                      color: cs.surfaceContainerHigh,
                    ),
                  ),
                ),
                // ── Right: tab bar + content ──────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      _TabBar(state: codeState),
                      Expanded(
                        child: codeState.activeFileIndex == null
                            ? _AgentPanel(
                                entries: codeState.entries,
                                scrollCtrl: _scrollCtrl,
                                workingDir: codeState.workingDir,
                              )
                            : _FileViewerPanel(
                                file: codeState
                                    .openFiles[codeState.activeFileIndex!],
                              ),
                      ),
                      // Input always visible; always targets agent
                      _InputBar(
                        ctrl: _inputCtrl,
                        running: codeState.isRunning,
                        onSend: _send,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── File explorer panel ───────────────────────────────────────────────────────

class _FilePanel extends StatelessWidget {
  final String workingDir;
  final String? selectedPath;
  final VoidCallback onPickFolder;
  final void Function(String) onFileTap;

  const _FilePanel({
    required this.workingDir,
    required this.onPickFolder,
    required this.onFileTap,
    this.selectedPath,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final folderName = workingDir.isEmpty
        ? 'No folder'
        : workingDir.split('/').last;

    return Container(
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: folder name + open button
          InkWell(
            onTap: onPickFolder,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.folder_outlined,
                      size: 14, color: cs.primary.withOpacity(0.7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      folderName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withOpacity(0.55),
                        letterSpacing: 0.8,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Open folder',
                    child: Icon(Icons.drive_folder_upload_outlined,
                        size: 16, color: cs.onSurface.withOpacity(0.4)),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Tree
          Expanded(
            child: FileTree(
              workingDir: workingDir,
              selectedPath: selectedPath,
              onFileTap: onFileTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends ConsumerWidget {
  final CodeState state;
  const _TabBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(codeProvider.notifier);
    final isAgentActive = state.activeFileIndex == null;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.surfaceContainerHigh)),
      ),
      child: Row(
        children: [
          // Agent tab (always first)
          _Tab(
            label: 'Agent',
            icon: Icons.smart_toy_outlined,
            isActive: isAgentActive,
            onTap: notifier.showAgentTab,
          ),
          // File tabs
          ...state.openFiles.asMap().entries.map((e) {
            final isActive = state.activeFileIndex == e.key;
            return _Tab(
              label: e.value.name,
              icon: Icons.insert_drive_file_outlined,
              isActive: isActive,
              onTap: () => notifier.showFileTab(e.key),
              onClose: () => notifier.closeFile(e.key),
            );
          }),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _Tab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? cs.surface : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isActive ? cs.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color: isActive
                    ? cs.primary
                    : cs.onSurface.withOpacity(0.45)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive
                      ? cs.onSurface
                      : cs.onSurface.withOpacity(0.5),
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close,
                    size: 12, color: cs.onSurface.withOpacity(0.4)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sandbox status strip ──────────────────────────────────────────────────────

class _SandboxBar extends ConsumerWidget {
  final CodeState state;
  const _SandboxBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    if (state.sandboxType == null) return const SizedBox.shrink();

    final isDocker = state.sandboxType == SandboxType.docker;
    final (icon, label, color) = switch (state.containerStatus) {
      ContainerStatus.idle =>
        (Icons.circle_outlined,
         isDocker ? 'Docker ready — set a folder to start container' : 'Restricted mode',
         cs.onSurface.withOpacity(0.3)),
      ContainerStatus.starting =>
        (Icons.hourglass_empty, 'Starting container…', Colors.amber.shade400),
      ContainerStatus.running => isDocker
          ? (Icons.circle, '🐳  ${state.sandboxImage}  ·  isolated', Colors.green.shade400)
          : (Icons.shield_outlined, 'Restricted sandbox  ·  sanitised env', Colors.green.shade400),
      ContainerStatus.error =>
        (Icons.warning_amber_outlined, 'Sandbox error', cs.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: cs.surfaceContainer,
      child: Row(
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              state.sandboxError != null ? 'Error: ${state.sandboxError}' : label,
              style: TextStyle(
                fontSize: 11,
                color: state.sandboxError != null ? cs.error : color,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state.containerStatus == ContainerStatus.error ||
              (state.containerStatus == ContainerStatus.idle &&
                  state.workingDir.isNotEmpty))
            GestureDetector(
              onTap: () => ref.read(codeProvider.notifier).restartSandbox(),
              child: Text('retry',
                  style: TextStyle(fontSize: 11, color: cs.primary)),
            ),
        ],
      ),
    );
  }
}

// ── Agent conversation panel ──────────────────────────────────────────────────

class _AgentPanel extends StatelessWidget {
  final List<CodeEntry> entries;
  final ScrollController scrollCtrl;
  final String workingDir;

  const _AgentPanel({
    required this.entries,
    required this.scrollCtrl,
    required this.workingDir,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return _EmptyAgent(workingDir: workingDir);
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: entries.length,
      itemBuilder: (_, i) => _EntryTile(entry: entries[i]),
    );
  }
}

class _EmptyAgent extends StatelessWidget {
  final String workingDir;
  const _EmptyAgent({required this.workingDir});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final suggestions = [
      'List the files in this project',
      'Explain the main entry point',
      'Find all TODO comments',
      'Run the tests and fix any failures',
      'Summarise recent git changes',
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.smart_toy_outlined, size: 36, color: cs.primary.withOpacity(0.35)),
        const SizedBox(height: 12),
        Text(
          workingDir.isNotEmpty ? workingDir.split('/').last : 'Code agent',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: cs.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 20),
        ...suggestions.map((s) => _SuggestionTile(text: s)),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String text;
  const _SuggestionTile({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.surfaceContainerHigh),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_forward, size: 13, color: cs.primary.withOpacity(0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6))),
          ),
        ],
      ),
    );
  }
}

// ── File viewer panel ─────────────────────────────────────────────────────────

class _FileViewerPanel extends StatelessWidget {
  final CodeFile file;
  const _FileViewerPanel({required this.file});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lines = file.content.split('\n');

    return Column(
      children: [
        // File path breadcrumb
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: cs.surfaceContainerLow,
          child: Text(
            file.path,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: cs.onSurface.withOpacity(0.45),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Content
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(lines.length, (i) {
                      return _CodeLine(
                        lineNumber: i + 1,
                        totalLines: lines.length,
                        content: lines[i],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Footer: line count
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              Text(
                '${lines.length} lines',
                style: TextStyle(
                    fontSize: 11, color: cs.onSurface.withOpacity(0.35)),
              ),
              const SizedBox(width: 16),
              Text(
                file.name.contains('.') ? '.${file.name.split('.').last}' : 'plain',
                style: TextStyle(
                    fontSize: 11, color: cs.onSurface.withOpacity(0.35)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: file.content)),
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 12, color: cs.onSurface.withOpacity(0.3)),
                    const SizedBox(width: 4),
                    Text('copy',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurface.withOpacity(0.3))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CodeLine extends StatelessWidget {
  final int lineNumber;
  final int totalLines;
  final String content;

  const _CodeLine({
    required this.lineNumber,
    required this.totalLines,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final numWidth = '${totalLines}'.length * 8.0 + 16.0;

    return SizedBox(
      height: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Line number
          Container(
            width: numWidth,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 12),
            color: cs.surfaceContainerLow,
            child: Text(
              '$lineNumber',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: cs.onSurface.withOpacity(0.25),
                height: 1,
              ),
            ),
          ),
          // Code content
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 24),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: cs.onSurface.withOpacity(0.88),
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Entry tiles (agent output) ────────────────────────────────────────────────

class _EntryTile extends StatefulWidget {
  final CodeEntry entry;
  const _EntryTile({required this.entry});

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = widget.entry;

    return switch (e.type) {
      CodeEntryType.user => Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.85),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(e.content,
                style: TextStyle(color: cs.onPrimary, fontSize: 13, height: 1.4)),
          ),
        ),
      CodeEntryType.assistantText => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: MarkdownBody(
            data: e.content,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                  fontSize: 13, color: cs.onSurface, height: 1.55),
              code: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  backgroundColor: cs.surfaceContainerHigh,
                  color: cs.primary.withOpacity(0.9)),
              codeblockDecoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      CodeEntryType.toolCall => Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.terminal, size: 13, color: Color(0xFF3B82F6)),
              const SizedBox(width: 6),
              Text(e.label ?? '',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3B82F6),
                      fontFamily: 'monospace')),
              const SizedBox(width: 6),
              Expanded(
                child: Text(e.content,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.55),
                        fontFamily: 'monospace'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      CodeEntryType.toolResult => GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.surfaceContainerHigh),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 13, color: Colors.green.shade400),
                    const SizedBox(width: 5),
                    Text(e.label ?? '',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade400)),
                    const Spacer(),
                    Text(
                      _expanded
                          ? '${e.content.split('\n').length} lines ▲'
                          : '${e.content.split('\n').length} lines ▼',
                      style: TextStyle(
                          fontSize: 10, color: cs.onSurface.withOpacity(0.3)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Clipboard.setData(ClipboardData(text: e.content)),
                      child: Icon(Icons.copy,
                          size: 12, color: cs.onSurface.withOpacity(0.3)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _expanded
                      ? e.content
                      : e.content.split('\n').take(3).join('\n'),
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: cs.onSurface.withOpacity(0.65),
                      height: 1.4),
                ),
              ],
            ),
          ),
        ),
      CodeEntryType.error => Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(e.content,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error, fontSize: 12)),
        ),
    };
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool running;
  final VoidCallback onSend;

  const _InputBar(
      {required this.ctrl, required this.running, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.surfaceContainerHigh)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLines: 4,
              minLines: 1,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Ask the agent…',
                hintStyle: TextStyle(color: Colors.white24),
              ),
            ),
          ),
          const SizedBox(width: 8),
          running
              ? SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.primary),
                    ),
                  ),
                )
              : IconButton.filled(
                  onPressed: onSend,
                  icon: const Icon(Icons.arrow_upward),
                  style: IconButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                  ),
                ),
        ],
      ),
    );
  }
}
