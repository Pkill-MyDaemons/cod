# Cod

AI-powered developer assistant for macOS — conversational chat, Gmail, Google Calendar, an agentic code editor, and task management.

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

### Gmail / Google Calendar
Tap **Connect Google Account** in Settings or the Email tab. A browser window opens, you sign in, and you're done. No credentials to configure.

---

## Installing on macOS

Download the `.dmg` from [Releases](https://github.com/Pkill-MyDaemons/cod/releases), open it, and drag Cod to Applications.

**"Apple could not verify Cod is free of malware"**

Cod is not yet notarized with Apple (that requires a $99/year developer account—this is a free open-source project). To open it anyway:

**Option A — System Settings:**
1. Try to open Cod — the warning appears
2. Open **System Settings → Privacy & Security**
3. Scroll down to the *Security* section
4. Click **Open Anyway** next to the Cod message

**Option B — Terminal:**
```sh
xattr -cr /Applications/Cod.app
```
Then open Cod normally. This removes the quarantine flag Apple sets on downloaded files.

---

## Privacy & Security

- **API keys** are stored locally in macOS `UserDefaults` and never leave your device except in direct requests to the provider you configured (Anthropic, Google, Groq, or your local Ollama instance).
- **Gmail / Calendar access** uses OAuth 2.0. Cod stores your refresh token locally. Your emails and calendar events are only fetched on demand and are never sent to any server other than Google's own APIs.
- **Code agent shell commands** run either in a Docker container (if Docker is installed) or in a restricted local shell with sensitive environment variables stripped. Commands are never sent to a remote server.
- **No analytics, no telemetry, no data collection** of any kind.
- The app makes outbound HTTPS requests only to: LLM provider APIs, Google APIs (Gmail/Calendar/OAuth), and whatever servers your own shell commands contact.

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

### Google OAuth credentials (for building from source)

The released binaries have Google OAuth credentials baked in. If you're building from source, create a `.env` file in the project root:

```
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
```

Then build with:
```sh
bash build.sh macos --release
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
