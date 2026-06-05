# cod — setup

## Prerequisites

Install Flutter: https://docs.flutter.dev/get-started/install/macos

## First-time setup

```sh
# from this directory
flutter create . --project-name cod --org com.henry --platforms=ios,android,macos
flutter pub get
flutter run
```

The `flutter create .` command scaffolds the platform-specific files (android/, ios/, macos/)
without overwriting any existing lib/ files.

## Providers

Configure API keys in the Settings tab:

| Provider | Key needed | Notes |
|----------|-----------|-------|
| Claude | Yes | https://console.anthropic.com |
| Gemini | Yes | https://aistudio.google.com |
| Groq | Yes | https://console.groq.com |
| Ollama | No | Set base URL (default: http://localhost:11434) |

## Features

- **Chat** — multi-provider AI chat with streaming, session history (swipe open drawer)
- **Tasks** — create tasks, tap status ring to cycle todo → in progress → done, tap task to open AI thread
- **Settings** — switch active provider, set API keys, choose model per provider
