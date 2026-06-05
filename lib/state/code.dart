import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sandbox_service.dart';

export '../services/sandbox_service.dart' show SandboxType, ContainerStatus;

// ── Entry types (agent conversation) ─────────────────────────────────────────

enum CodeEntryType { user, assistantText, toolCall, toolResult, error }

class CodeEntry {
  final CodeEntryType type;
  final String content;
  final String? label;
  final DateTime timestamp;

  CodeEntry({
    required this.type,
    required this.content,
    this.label,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory CodeEntry.user(String text) =>
      CodeEntry(type: CodeEntryType.user, content: text);
  factory CodeEntry.assistant(String text) =>
      CodeEntry(type: CodeEntryType.assistantText, content: text);
  factory CodeEntry.toolCall(String name, String input) =>
      CodeEntry(type: CodeEntryType.toolCall, content: input, label: name);
  factory CodeEntry.toolResult(String name, String result) =>
      CodeEntry(type: CodeEntryType.toolResult, content: result, label: name);
  factory CodeEntry.error(String msg) =>
      CodeEntry(type: CodeEntryType.error, content: msg);
}

// ── Open file tab ─────────────────────────────────────────────────────────────

class CodeFile {
  final String path;
  final String name;
  final String content;

  const CodeFile({required this.path, required this.name, required this.content});
}

// Sentinel so copyWith can distinguish "set to null" from "leave unchanged"
const _unset = Object();

// ── State ─────────────────────────────────────────────────────────────────────

class CodeState {
  final String workingDir;
  final List<CodeEntry> entries;
  final bool isRunning;
  // Sandbox
  final SandboxType? sandboxType;
  final ContainerStatus containerStatus;
  final String sandboxImage;
  final String? sandboxError;
  // File tabs — null activeFileIndex = Agent tab
  final List<CodeFile> openFiles;
  final int? activeFileIndex;

  const CodeState({
    this.workingDir = '',
    this.entries = const [],
    this.isRunning = false,
    this.sandboxType,
    this.containerStatus = ContainerStatus.idle,
    this.sandboxImage = 'ubuntu:24.04',
    this.sandboxError,
    this.openFiles = const [],
    this.activeFileIndex,
  });

  CodeState copyWith({
    String? workingDir,
    List<CodeEntry>? entries,
    bool? isRunning,
    SandboxType? sandboxType,
    ContainerStatus? containerStatus,
    String? sandboxImage,
    String? sandboxError,
    bool clearSandboxError = false,
    List<CodeFile>? openFiles,
    Object? activeFileIndex = _unset,
  }) =>
      CodeState(
        workingDir: workingDir ?? this.workingDir,
        entries: entries ?? this.entries,
        isRunning: isRunning ?? this.isRunning,
        sandboxType: sandboxType ?? this.sandboxType,
        containerStatus: containerStatus ?? this.containerStatus,
        sandboxImage: sandboxImage ?? this.sandboxImage,
        sandboxError: clearSandboxError ? null : (sandboxError ?? this.sandboxError),
        openFiles: openFiles ?? this.openFiles,
        activeFileIndex: identical(activeFileIndex, _unset)
            ? this.activeFileIndex
            : activeFileIndex as int?,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class CodeNotifier extends Notifier<CodeState> {
  final _sandbox = SandboxService();

  @override
  CodeState build() {
    ref.onDispose(() => _sandbox.dispose());
    Future.microtask(_detectSandbox);
    return const CodeState();
  }

  Future<void> _detectSandbox() async {
    final type = await _sandbox.detect();
    state = state.copyWith(sandboxType: type);
  }

  Future<void> setWorkingDir(String dir) async {
    if (_sandbox.status == ContainerStatus.running) await _sandbox.stop();
    state = state.copyWith(
      workingDir: dir,
      entries: [],
      openFiles: [],
      activeFileIndex: null,
      clearSandboxError: true,
      containerStatus: ContainerStatus.idle,
    );
    if (dir.isEmpty) return;

    state = state.copyWith(containerStatus: ContainerStatus.starting);
    try {
      await _sandbox.start(workingDir: dir, image: state.sandboxImage);
      state = state.copyWith(containerStatus: ContainerStatus.running);
    } catch (e) {
      state = state.copyWith(
        containerStatus: ContainerStatus.error,
        sandboxError: e.toString(),
      );
    }
  }

  Future<void> restartSandbox() => setWorkingDir(state.workingDir);

  Future<String> Function(String) get commandRunner =>
      (cmd) => _sandbox.exec(cmd,
          workingDir: state.workingDir.isNotEmpty ? state.workingDir : null);

  // ── Agent conversation ─────────────────────────────────────────────────────

  void addEntry(CodeEntry entry) =>
      state = state.copyWith(entries: [...state.entries, entry]);

  void setRunning(bool v) => state = state.copyWith(isRunning: v);

  void clearConversation() => state = state.copyWith(entries: []);

  // ── File tabs ──────────────────────────────────────────────────────────────

  Future<void> openFile(String path) async {
    // Switch to existing tab if already open
    final existing = state.openFiles.indexWhere((f) => f.path == path);
    if (existing >= 0) {
      state = state.copyWith(activeFileIndex: existing);
      return;
    }

    final file = File(path);
    if (!await file.exists()) return;

    String content;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 512 * 1024) {
        content = '(File too large to display inline — ${bytes.length ~/ 1024} KB)';
      } else {
        content = utf8.decode(bytes, allowMalformed: true);
      }
    } catch (e) {
      content = 'Error reading file: $e';
    }

    final name = path.split('/').last;
    final files = [...state.openFiles, CodeFile(path: path, name: name, content: content)];
    state = state.copyWith(openFiles: files, activeFileIndex: files.length - 1);
  }

  void closeFile(int index) {
    final files = List<CodeFile>.from(state.openFiles)..removeAt(index);
    int? newIndex = state.activeFileIndex;
    if (newIndex != null) {
      if (newIndex > index) newIndex = newIndex - 1;
      if (newIndex >= files.length) newIndex = files.isEmpty ? null : files.length - 1;
      if (newIndex == index && files.isNotEmpty) newIndex = (index - 1).clamp(0, files.length - 1);
    }
    state = state.copyWith(openFiles: files, activeFileIndex: newIndex);
  }

  void showAgentTab() => state = state.copyWith(activeFileIndex: null);

  void showFileTab(int index) => state = state.copyWith(activeFileIndex: index);
}
