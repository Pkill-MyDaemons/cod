import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/email_model.dart';
import '../services/gmail_service.dart';

enum EmailConnectionStatus { unknown, connected, disconnected }

class EmailState {
  final EmailConnectionStatus status;
  final List<GmailThread> threads;
  final bool loading;
  final String? error;
  final String userEmail;

  const EmailState({
    this.status = EmailConnectionStatus.unknown,
    this.threads = const [],
    this.loading = false,
    this.error,
    this.userEmail = '',
  });

  EmailState copyWith({
    EmailConnectionStatus? status,
    List<GmailThread>? threads,
    bool? loading,
    String? error,
    String? userEmail,
    bool clearError = false,
  }) =>
      EmailState(
        status: status ?? this.status,
        threads: threads ?? this.threads,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        userEmail: userEmail ?? this.userEmail,
      );
}

class EmailNotifier extends Notifier<EmailState> {
  @override
  EmailState build() {
    Future.microtask(_checkConnection);
    return const EmailState();
  }

  Future<void> _checkConnection() async {
    final connected = await GmailService.instance.isConnected;
    if (connected) {
      final email = await GmailService.instance.userEmail;
      state = state.copyWith(
          status: EmailConnectionStatus.connected, userEmail: email);
      await refresh();
    } else {
      state = state.copyWith(status: EmailConnectionStatus.disconnected);
    }
  }

  Future<void> connect() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final email = await GmailService.instance.connect();
      state = state.copyWith(
        status: EmailConnectionStatus.connected,
        userEmail: email,
        loading: false,
      );
      await refresh();
    } catch (e) {
      state = state.copyWith(
          loading: false,
          status: EmailConnectionStatus.disconnected,
          error: e.toString());
    }
  }

  Future<void> disconnect() async {
    await GmailService.instance.disconnect();
    state = const EmailState(status: EmailConnectionStatus.disconnected);
  }

  Future<void> refresh() async {
    if (state.status != EmailConnectionStatus.connected) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final threads = await GmailService.instance.listThreads();
      state = state.copyWith(threads: threads, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<GmailThread?> loadThread(String id) async {
    try {
      final thread = await GmailService.instance.loadMessages(id);
      final threads = state.threads.map((t) => t.id == id ? thread : t).toList();
      state = state.copyWith(threads: threads);
      return thread;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  void setAiSummary(String threadId, String summary) {
    final threads = state.threads.map((t) {
      if (t.id != threadId) return t;
      t.aiSummary = summary;
      return t;
    }).toList();
    state = state.copyWith(threads: threads);
  }

  void setAiDraft(String threadId, String draft) {
    final threads = state.threads.map((t) {
      if (t.id != threadId) return t;
      t.aiDraft = draft;
      return t;
    }).toList();
    state = state.copyWith(threads: threads);
  }

  Future<void> markRead(String threadId) async {
    try {
      await GmailService.instance.markRead(threadId);
      final threads = state.threads.map((t) {
        if (t.id != threadId) return t;
        return GmailThread(
          id: t.id,
          subject: t.subject,
          from: t.from,
          snippet: t.snippet,
          date: t.date,
          isUnread: false,
          messages: t.messages,
          aiSummary: t.aiSummary,
          aiDraft: t.aiDraft,
        );
      }).toList();
      state = state.copyWith(threads: threads);
    } catch (_) {}
  }
}
