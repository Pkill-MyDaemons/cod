# Cod

AI-powered developer assistant with four integrated tools: conversational chat, Gmail inbox management, an agentic code editor, and autonomous task execution.

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS%20%7C%20Android%20%7C%20Windows-blue)
![Flutter](https://img.shields.io/badge/flutter-3.x-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

### Chat
- Streaming conversations with Claude, Gemini, Groq, and Ollama
- Session history with persistent storage and auto-generated titles
- Markdown rendering in responses

### Email
- Gmail OAuth 2.0 — local redirect server handles the code exchange, no copy-paste required
- Threaded inbox with unread counts
- AI-powered summarisation and draft reply generation
- One-tap send

### Code
- VSCode-style file explorer: lazy-loaded directory tree, per-language icons, draggable resize handle
- Syntax-highlighted file viewer (Atom One Dark, 20+ languages, line numbers, horizontal scroll)
- Agentic loop — the model calls tools iteratively until the task is complete:
  - `read_file`, `write_file`, `list_directory`, `create_directory`
  - `run_command` — executes shell commands inside a sandbox
  - `search_files` — grep across the working directory
- **Sandbox isolation**
  - *Docker* (when available): persistent container per session, `--network=none`, `--memory=512m`, `--pids-limit=128`, `--security-opt=no-new-privileges`
  - *Restricted fallback*: strips sensitive env vars (`AWS_*`, `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, …), normalises `PATH`
  - Status bar shows active mode; tap **retry** to restart a failed container

### Tasks
- Create and manage tasks with title, description, and status (`todo → in progress → done`)
- Per-task chat tab for discussion
- Per-task **Agent tab**: runs the code agent autonomously; calls `mark_complete` when done
- One-tap ▶ button runs a task automatically

---

## Setup

### Prerequisites
- Flutter ≥ 3.22 / Dart ≥ 3.4
- (Optional) Docker Desktop for container sandboxing

### Run
```bash
git clone https://github.com/Pkill-MyDaemons/cod
cd cod
flutter pub get
flutter run -d macos   # or ios / android / windows
```

### API Keys
Open **Settings** and enter keys for the providers you want:

| Provider | Where to get a key |
|---|---|
| Claude | [console.anthropic.com](https://console.anthropic.com) |
| Gemini | [aistudio.google.com](https://aistudio.google.com) |
| Groq | [console.groq.com](https://console.groq.com) |
| Ollama | No key — set base URL to `http://localhost:11434` |

### Gmail OAuth
1. [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials
2. Create an **OAuth 2.0 Client ID** of type *Desktop app*
3. Enable the **Gmail API** for your project
4. Paste the Client ID and Secret into Settings → Gmail, then tap **Connect**

---

## Architecture

```
lib/
├── main.dart               # Entry point; registers highlight languages
├── app.dart                # Root widget, 5-tab NavigationBar shell
├── theme.dart              # Dark theme (seed #7C3AED, bg #0C0E18)
│
├── models/                 # Pure data classes with JSON serialisation
│   ├── message.dart
│   ├── session.dart
│   ├── task.dart
│   ├── config.dart         # Provider configs + defaults
│   ├── tool.dart           # Tool, ToolCall, sealed AgentEvent hierarchy
│   └── email_model.dart
│
├── llm/                    # Provider clients
│   ├── provider.dart       # Abstract LLMProvider.stream()
│   ├── claude.dart         # Anthropic SSE
│   ├── gemini.dart         # Google SSE (?alt=sse)
│   ├── groq.dart           # OpenAI-compatible SSE
│   ├── ollama.dart         # NDJSON streaming
│   └── agent_llm.dart      # Non-streaming Claude tool-use client
│
├── services/
│   ├── agent_service.dart  # Agentic loop (max 20 iterations)
│   ├── sandbox_service.dart# Docker / restricted-env sandbox
│   └── gmail_service.dart  # OAuth2, token refresh, Gmail REST API
│
├── state/                  # Riverpod 2.x Notifier providers
│   ├── providers.dart
│   ├── sessions.dart       # Chat session list
│   ├── tasks.dart          # Task list + thread messages
│   ├── config.dart         # Active provider + keys
│   ├── email.dart          # Gmail inbox state
│   └── code.dart           # Working dir, agent log, open tabs, sandbox
│
├── screens/
│   ├── chat_screen.dart
│   ├── email_screen.dart
│   ├── code_screen.dart    # Split pane: file tree + tab bar + agent/viewer
│   ├── tasks_screen.dart
│   ├── task_detail_screen.dart
│   └── settings_screen.dart
│
└── widgets/
    ├── file_tree.dart      # Flat-list lazy directory tree
    ├── message_bubble.dart
    ├── provider_badge.dart
    └── task_tile.dart
```

**Streaming**: SSE via `http.Client().send()` + `Stream<Uint8List>`, line-buffered. Ollama uses NDJSON. The agent loop uses a separate non-streaming `AgentLLM` call to get tool-use blocks from Claude in the `tool_use` / `tool_result` multi-turn format.

**State**: `Notifier.build()` is synchronous — async init uses `Future.microtask(_load)`. `ref.onDispose` tears down Docker containers and controllers.

---

## Building

```bash
# macOS
flutter build macos --release

# Android (APK or App Bundle)
flutter build apk --release
flutter build appbundle --release

# iOS (requires Apple Developer account + Xcode signing)
flutter build ipa --release

# Windows (must run on Windows)
flutter build windows --release
```

### macOS entitlements

| Entitlement | Reason |
|---|---|
| `network.client` | LLM API calls, Gmail OAuth token exchange |
| `network.server` | Local OAuth redirect server |
| `files.user-selected.read-write` | Native folder picker |

---

## License

MIT
