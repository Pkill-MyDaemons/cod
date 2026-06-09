import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/gmail_service.dart';
import '../state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final update = ref.watch(updateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (update.hasUpdate) ...[
            _UpdateBanner(update: update),
            const SizedBox(height: 16),
          ],
          _SectionHeader('Active provider'),
          const SizedBox(height: 8),
          _ProviderSelector(
            activeId: config.activeProviderId,
            providers: config.providers.values.toList(),
            onChanged: (id) => ref.read(configProvider.notifier).setActiveProvider(id),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Providers'),
          const SizedBox(height: 8),
          ...config.providers.values.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProviderCard(providerId: p.id),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Gmail'),
          const SizedBox(height: 8),
          const _GmailCard(),
          const SizedBox(height: 24),
          _SectionHeader('Minnow companion'),
          const SizedBox(height: 8),
          const _CompanionCard(),
          const SizedBox(height: 24),
          _SectionHeader('About'),
          const SizedBox(height: 8),
          _AboutCard(update: update),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
      );
}

class _ProviderSelector extends StatelessWidget {
  final String activeId;
  final List providers;
  final void Function(String) onChanged;

  const _ProviderSelector({
    required this.activeId,
    required this.providers,
    required this.onChanged,
  });

  static const _colors = {
    'claude': Color(0xFFDA7756),
    'gemini': Color(0xFF4285F4),
    'groq': Color(0xFF00B4D8),
    'ollama': Color(0xFF7CB77C),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: providers.map((p) {
        final isActive = p.id == activeId;
        final color = _colors[p.id] ?? cs.primary;
        return GestureDetector(
          onTap: () => onChanged(p.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.2) : cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? color : cs.surfaceContainerHigh,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Text(
              p.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive ? color : cs.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ProviderCard extends ConsumerStatefulWidget {
  final String providerId;
  const _ProviderCard({required this.providerId});

  @override
  ConsumerState<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends ConsumerState<_ProviderCard> {
  late TextEditingController _keyCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _modelCtrl;
  bool _keyVisible = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(configProvider);
    final p = config.providers[widget.providerId]!;
    _keyCtrl = TextEditingController(text: p.apiKey);
    _urlCtrl = TextEditingController(text: p.baseUrl);
    _modelCtrl = TextEditingController(text: p.selectedModel);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _urlCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    final p = config.providers[widget.providerId]!;
    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(configProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                p.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              if (p.id != 'ollama')
                _KeyStatusDot(hasKey: p.apiKey.isNotEmpty),
            ],
          ),
          const SizedBox(height: 12),
          // Model picker
          TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(labelText: 'Model'),
            onChanged: (v) => notifier.setModel(p.id, v),
          ),
          const SizedBox(height: 10),
          // API key (not shown for ollama)
          if (p.id != 'ollama') ...[
            TextFormField(
              controller: _keyCtrl,
              obscureText: !_keyVisible,
              decoration: InputDecoration(
                labelText: 'API key',
                suffixIcon: IconButton(
                  icon: Icon(_keyVisible ? Icons.visibility_off : Icons.visibility, size: 18),
                  onPressed: () => setState(() => _keyVisible = !_keyVisible),
                ),
              ),
              onChanged: (v) => notifier.setApiKey(p.id, v),
            ),
          ],
          // Base URL (ollama only)
          if (p.id == 'ollama') ...[
            const SizedBox(height: 2),
            TextFormField(
              controller: _urlCtrl,
              decoration: const InputDecoration(labelText: 'Base URL'),
              onChanged: (v) => notifier.setBaseUrl(p.id, v),
            ),
          ],
        ],
      ),
    );
  }
}

class _KeyStatusDot extends StatelessWidget {
  final bool hasKey;
  const _KeyStatusDot({required this.hasKey});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasKey ? Colors.green.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          hasKey ? 'key set' : 'no key',
          style: TextStyle(
            fontSize: 11,
            color: hasKey ? Colors.green.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ── Gmail card ────────────────────────────────────────────────────────────────

class _GmailCard extends ConsumerStatefulWidget {
  const _GmailCard();

  @override
  ConsumerState<_GmailCard> createState() => _GmailCardState();
}

class _GmailCardState extends ConsumerState<_GmailCard> {
  bool _connected = false;
  String _email = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = await GmailService.instance.userEmail;
    final connected = await GmailService.instance.isConnected;
    if (!mounted) return;
    setState(() { _email = email; _connected = connected; });
  }

  Future<void> _disconnect() async {
    await GmailService.instance.disconnect();
    ref.read(emailProvider.notifier).disconnect();
    setState(() { _connected = false; _email = ''; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Gmail', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_connected)
                Row(
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.green)),
                    const SizedBox(width: 5),
                    Text(_email,
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurface.withOpacity(0.6))),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _disconnect,
                      child: Text('disconnect',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.error,
                              decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
            ],
          ),
          if (!_connected) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                try {
                  final email = await GmailService.instance.connect();
                  if (mounted) setState(() { _connected = true; _email = email; });
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              },
              icon: const Icon(Icons.login, size: 16),
              label: const Text('Connect Google Account'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Update banner ─────────────────────────────────────────────────────────────

class _UpdateBanner extends StatelessWidget {
  final dynamic update;
  const _UpdateBanner({required this.update});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final latestVersion = update.info?.latestVersion ?? '';
    final releaseUrl = update.info?.releaseUrl ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update_outlined, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'v$latestVersion is available',
              style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary, fontSize: 13),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: releaseUrl.isNotEmpty
                ? () => launchUrl(Uri.parse(releaseUrl))
                : null,
            child: const Text('Download', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── About card ────────────────────────────────────────────────────────────────

class _AboutCard extends ConsumerWidget {
  final dynamic update;
  const _AboutCard({required this.update});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final version = update.currentVersion;
    final isChecking = update.isChecking;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            version.isEmpty ? 'Cod' : 'Cod v$version',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (isChecking)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            GestureDetector(
              onTap: () => ref.read(updateProvider.notifier).checkForUpdates(force: true),
              child: Text(
                update.hasUpdate ? 'Update available' : 'Check for updates',
                style: TextStyle(
                  fontSize: 12,
                  color: update.hasUpdate ? cs.primary : cs.onSurface.withOpacity(0.5),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Companion / Minnow card ───────────────────────────────────────────────────

class _CompanionCard extends ConsumerWidget {
  const _CompanionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final sync = ref.read(minnowSyncProvider);
    final qr = sync.qrData;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Minnow', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Open Minnow on your phone and scan this code. Works anywhere — Wi-Fi or cellular.',
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
          ),
          const SizedBox(height: 16),
          Center(
            child: QrImageView(
              data: qr,
              version: QrVersions.auto,
              size: 160,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: sync.sessionId)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copy, size: 12, color: cs.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 5),
                Text(
                  'Session: ${sync.sessionId.substring(0, 8)}…',
                  style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
