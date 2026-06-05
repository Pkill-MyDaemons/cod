class GmailThread {
  final String id;
  final String subject;
  final String from;
  final String snippet;
  final DateTime date;
  final bool isUnread;
  List<GmailMessage>? messages;
  String? aiSummary;
  String? aiDraft;

  GmailThread({
    required this.id,
    required this.subject,
    required this.from,
    required this.snippet,
    required this.date,
    required this.isUnread,
    this.messages,
    this.aiSummary,
    this.aiDraft,
  });
}

class GmailMessage {
  final String id;
  final String from;
  final String to;
  final String subject;
  final String body;
  final DateTime date;
  final String? messageId;

  const GmailMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.subject,
    required this.body,
    required this.date,
    this.messageId,
  });
}

enum EmailMode { summaryOnly, draftWait, autoSend }

extension EmailModeX on EmailMode {
  String get label => switch (this) {
        EmailMode.summaryOnly => 'Summarize',
        EmailMode.draftWait => 'Draft reply',
        EmailMode.autoSend => 'Auto send',
      };
}
