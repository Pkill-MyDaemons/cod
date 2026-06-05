import 'dart:io';

enum SandboxType { docker, restricted }

enum ContainerStatus { idle, starting, running, error }

// Environment variables too sensitive to expose to agent-run commands
const _stripEnv = {
  'AWS_SECRET_ACCESS_KEY', 'AWS_ACCESS_KEY_ID', 'AWS_SESSION_TOKEN',
  'ANTHROPIC_API_KEY', 'OPENAI_API_KEY', 'GEMINI_API_KEY',
  'GITHUB_TOKEN', 'GH_TOKEN', 'NPM_TOKEN', 'PYPI_TOKEN',
  'DOCKER_PASSWORD', 'GOOGLE_APPLICATION_CREDENTIALS',
};

class SandboxService {
  SandboxType _type = SandboxType.restricted;
  String? _containerId;
  ContainerStatus _status = ContainerStatus.idle;
  String _workingDir = '';

  SandboxType get type => _type;
  ContainerStatus get status => _status;

  // Detect whether Docker is available on this platform
  Future<SandboxType> detect() async {
    // Process.run is unavailable on mobile
    if (Platform.isIOS || Platform.isAndroid) {
      _type = SandboxType.restricted;
      return _type;
    }
    try {
      final r = await Process.run('docker', ['info', '--format', '{{.ServerVersion}}'])
          .timeout(const Duration(seconds: 4));
      if (r.exitCode == 0 && (r.stdout as String).trim().isNotEmpty) {
        _type = SandboxType.docker;
        return _type;
      }
    } catch (_) {}
    _type = SandboxType.restricted;
    return _type;
  }

  // Start a persistent Docker container for this session
  Future<void> start({
    required String workingDir,
    String image = 'ubuntu:24.04',
    bool networkEnabled = false,
  }) async {
    _workingDir = workingDir;

    if (_type == SandboxType.restricted) {
      _status = ContainerStatus.running;
      return;
    }

    if (_containerId != null) await stop();

    _status = ContainerStatus.starting;
    final id = 'cod-${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Pull image silently if missing (docker run does this, but explicit pull
      // gives us better error messages)
      await Process.run('docker', ['pull', image])
          .timeout(const Duration(minutes: 3));

      final r = await Process.run('docker', [
        'run', '-d',
        '--name', id,
        '-v', '$workingDir:/workspace:rw',
        '-w', '/workspace',
        '--memory=512m',
        '--cpus=1.0',
        '--pids-limit=128',
        '--security-opt=no-new-privileges',
        if (!networkEnabled) '--network=none',
        image,
        'tail', '-f', '/dev/null', // keep alive
      ]).timeout(const Duration(seconds: 30));

      if (r.exitCode != 0) {
        throw Exception((r.stderr as String).trim());
      }

      _containerId = id;
      _status = ContainerStatus.running;
    } catch (e) {
      _status = ContainerStatus.error;
      rethrow;
    }
  }

  // Execute a shell command in the sandbox
  Future<String> exec(String command, {String? workingDir}) async {
    if (_type == SandboxType.docker && _containerId != null) {
      return _execDocker(command);
    }
    return _execRestricted(command, workingDir ?? _workingDir);
  }

  Future<String> _execDocker(String command) async {
    final r = await Process.run(
      'docker', ['exec', _containerId!, 'sh', '-c', command],
      runInShell: false,
    ).timeout(const Duration(seconds: 30));
    return _mergeOutput(r);
  }

  Future<String> _execRestricted(String command, String? cwd) async {
    // Build a sanitised environment
    final env = Map<String, String>.from(Platform.environment);
    for (final k in _stripEnv) {
      env.remove(k);
    }
    // Normalise PATH to avoid picking up unexpected binaries
    env['PATH'] =
        '/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:/opt/homebrew/sbin';

    final r = await Process.run(
      'sh', ['-c', command],
      workingDirectory: (cwd != null && cwd.isNotEmpty) ? cwd : null,
      environment: env,
      runInShell: false,
    ).timeout(const Duration(seconds: 30));
    return _mergeOutput(r);
  }

  String _mergeOutput(ProcessResult r) {
    final out = (r.stdout as String).trim();
    final err = (r.stderr as String).trim();
    final parts = [if (out.isNotEmpty) out, if (err.isNotEmpty) 'stderr:\n$err'];
    return parts.isEmpty ? '(no output)' : parts.join('\n');
  }

  Future<void> stop() async {
    _status = ContainerStatus.idle;
    if (_containerId == null) return;
    try {
      await Process.run('docker', ['rm', '-f', _containerId!])
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
    _containerId = null;
  }

  Future<void> dispose() => stop();
}
