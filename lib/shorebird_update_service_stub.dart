enum ShorebirdUpdateStatus { upToDate, outdated, restartRequired, unavailable }

enum ShorebirdUpdateFailure { network, server, download, noUpdate, unknown }

enum ShorebirdPatchStateKind {
  newPatchReady,
  rollbackPending,
  noNextPatch,
  unknown,
}

class ShorebirdPatchState {
  const ShorebirdPatchState(this.kind, {this.patchNumber});

  final ShorebirdPatchStateKind kind;
  final int? patchNumber;
}

class ShorebirdUpdateException implements Exception {
  const ShorebirdUpdateException(this.failure);

  final ShorebirdUpdateFailure failure;
}

class ShorebirdUpdateService {
  bool get isAvailable => false;

  Future<ShorebirdUpdateStatus> check() async =>
      ShorebirdUpdateStatus.unavailable;

  Future<ShorebirdPatchState> readPatchState() async =>
      const ShorebirdPatchState(ShorebirdPatchStateKind.unknown);

  Future<ShorebirdPatchState> downloadAndVerify() async =>
      const ShorebirdPatchState(ShorebirdPatchStateKind.unknown);
}
