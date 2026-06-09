import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message.dart';
import '../models/task.dart';
import '../services/minnow_sync.dart';
import 'providers.dart';

class TasksNotifier extends Notifier<List<Task>> {
  MinnowSync get _sync => ref.read(minnowSyncProvider);

  @override
  List<Task> build() {
    Future.microtask(_load);
    return [];
  }

  Future<File> get _file async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/cod');
    await dir.create(recursive: true);
    return File('${dir.path}/tasks.json');
  }

  Future<void> _load() async {
    final f = await _file;
    if (!await f.exists()) return;
    try {
      final raw = await f.readAsString();
      final list = jsonDecode(raw) as List;
      final tasks = list.map((t) => Task.fromJson(t as Map<String, dynamic>)).toList();
      tasks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = tasks;
      _sync.syncAllTasks(tasks);
    } catch (_) {}
  }

  Future<void> _persist() async {
    final f = await _file;
    await f.writeAsString(jsonEncode(state.map((t) => t.toJson()).toList()));
    _sync.syncAllTasks(state);
  }

  Future<Task> add({
    required String title,
    String description = '',
    TaskSkill skill = TaskSkill.general,
  }) async {
    final t = Task(title: title, description: description, skill: skill);
    state = [t, ...state];
    await _persist();
    return t;
  }

  Future<void> updateSkill(String id, TaskSkill skill) async {
    state = state.map((t) {
      if (t.id != id) return t;
      t.skill = skill;
      t.updatedAt = DateTime.now();
      return t;
    }).toList();
    await _persist();
  }

  Future<void> cycleStatus(String id) async {
    state = state.map((t) {
      if (t.id != id) return t;
      t.status = t.status.next;
      t.updatedAt = DateTime.now();
      return t;
    }).toList();
    await _persist();
  }

  Future<void> cycleStatusTo(String id, TaskStatus target) async {
    state = state.map((t) {
      if (t.id != id) return t;
      t.status = target;
      t.updatedAt = DateTime.now();
      return t;
    }).toList();
    await _persist();
  }

  Future<void> addThreadMessage(String taskId, Message msg) async {
    state = state.map((t) {
      if (t.id != taskId) return t;
      t.thread.add(msg);
      t.updatedAt = DateTime.now();
      if (msg.role == MessageRole.assistant) t.hasUnread = true;
      return t;
    }).toList();
    await _persist();
  }

  void updateThreadStreaming(String taskId, String content) {
    state = state.map((t) {
      if (t.id != taskId || t.thread.isEmpty) return t;
      t.thread.last.content = content;
      return t;
    }).toList();
  }

  Future<void> finalizeThreadStreaming(String taskId) async {
    state = state.map((t) {
      if (t.id != taskId || t.thread.isEmpty) return t;
      t.thread.last.isStreaming = false;
      t.updatedAt = DateTime.now();
      t.hasUnread = true;
      return t;
    }).toList();
    await _persist();
  }

  void markRead(String id) {
    state = state.map((t) {
      if (t.id != id) return t;
      t.hasUnread = false;
      return t;
    }).toList();
  }

  Future<void> delete(String id) async {
    state = state.where((t) => t.id != id).toList();
    await _persist();
    _sync.deleteTask(id);
  }

  Future<void> update(String id, {String? title, String? description}) async {
    state = state.map((t) {
      if (t.id != id) return t;
      if (title != null) t.title = title;
      if (description != null) t.description = description;
      t.updatedAt = DateTime.now();
      return t;
    }).toList();
    await _persist();
  }

  Future<int> pruneExpired(int ttlDays) async {
    if (ttlDays <= 0) return 0;
    final before = state.length;
    final pruned = state.where((t) => t.isExpired(ttlDays)).map((t) => t.id).toSet();
    if (pruned.isEmpty) return 0;
    state = state.where((t) => !pruned.contains(t.id)).toList();
    await _persist();
    for (final id in pruned) {
      _sync.deleteTask(id);
    }
    return before - state.length;
  }
}
