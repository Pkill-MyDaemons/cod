class ProviderConfig {
  final String id;
  final String name;
  final String apiKey;
  final String baseUrl;
  final String selectedModel;
  final List<String> models;

  const ProviderConfig({
    required this.id,
    required this.name,
    this.apiKey = '',
    this.baseUrl = '',
    required this.selectedModel,
    required this.models,
  });

  ProviderConfig copyWith({
    String? apiKey,
    String? baseUrl,
    String? selectedModel,
  }) =>
      ProviderConfig(
        id: id,
        name: name,
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        selectedModel: selectedModel ?? this.selectedModel,
        models: models,
      );
}

class AppConfig {
  final String activeProviderId;
  final Map<String, ProviderConfig> providers;

  const AppConfig({
    required this.activeProviderId,
    required this.providers,
  });

  ProviderConfig get active =>
      providers[activeProviderId] ?? providers.values.first;

  AppConfig copyWith({
    String? activeProviderId,
    Map<String, ProviderConfig>? providers,
  }) =>
      AppConfig(
        activeProviderId: activeProviderId ?? this.activeProviderId,
        providers: providers ?? this.providers,
      );

  static AppConfig get defaults => AppConfig(
        activeProviderId: 'claude',
        providers: {
          'claude': const ProviderConfig(
            id: 'claude',
            name: 'Claude',
            selectedModel: 'claude-sonnet-4-6',
            models: [
              'claude-sonnet-4-6',
              'claude-opus-4-8',
              'claude-haiku-4-5-20251001',
            ],
          ),
          'gemini': const ProviderConfig(
            id: 'gemini',
            name: 'Gemini',
            selectedModel: 'gemini-2.0-flash',
            models: [
              'gemini-2.0-flash',
              'gemini-1.5-pro',
              'gemini-1.5-flash',
            ],
          ),
          'groq': const ProviderConfig(
            id: 'groq',
            name: 'Groq',
            selectedModel: 'llama-3.3-70b-versatile',
            models: [
              'llama-3.3-70b-versatile',
              'llama-3.1-8b-instant',
              'mixtral-8x7b-32768',
            ],
          ),
          'ollama': const ProviderConfig(
            id: 'ollama',
            name: 'Ollama',
            baseUrl: 'http://localhost:11434',
            selectedModel: 'llama3.2',
            models: ['llama3.2', 'mistral', 'codellama', 'gemma2'],
          ),
        },
      );
}
