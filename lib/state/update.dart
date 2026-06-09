import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/update_service.dart';

class UpdateState {
  final bool isChecking;
  final String currentVersion;
  final UpdateInfo? info;

  const UpdateState({
    this.isChecking = false,
    this.currentVersion = '',
    this.info,
  });

  bool get hasUpdate => info?.isUpdateAvailable == true;

  UpdateState copyWith({bool? isChecking, String? currentVersion, UpdateInfo? info}) =>
      UpdateState(
        isChecking: isChecking ?? this.isChecking,
        currentVersion: currentVersion ?? this.currentVersion,
        info: info ?? this.info,
      );
}

class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() {
    Future.microtask(_loadVersion);
    return const UpdateState();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    state = state.copyWith(currentVersion: info.version);
    await _doCheck(force: false);
  }

  Future<void> checkForUpdates({bool force = false}) => _doCheck(force: force);

  Future<void> _doCheck({required bool force}) async {
    if (state.isChecking) return;
    final version = state.currentVersion;
    if (version.isEmpty) return;

    state = state.copyWith(isChecking: true);
    final info = await UpdateService().check(version, force: force);
    state = state.copyWith(isChecking: false, info: info);
  }
}
