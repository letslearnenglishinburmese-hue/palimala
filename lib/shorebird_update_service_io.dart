import 'dart:io';

import 'package:shorebird_code_push/shorebird_code_push.dart';

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
  ShorebirdUpdateService({ShorebirdUpdater? updater})
    : _updater = updater ?? ShorebirdUpdater();

  final ShorebirdUpdater _updater;
  bool _downloadInProgress = false;

  bool get isAvailable => _updater.isAvailable;

  Future<ShorebirdUpdateStatus> check() async {
    try {
      final status = await _updater.checkForUpdate();
      return switch (status) {
        UpdateStatus.upToDate => ShorebirdUpdateStatus.upToDate,
        UpdateStatus.outdated => ShorebirdUpdateStatus.outdated,
        UpdateStatus.restartRequired => ShorebirdUpdateStatus.restartRequired,
        UpdateStatus.unavailable => ShorebirdUpdateStatus.unavailable,
      };
    } on UpdateException catch (error) {
      throw ShorebirdUpdateException(
        _classifyFailure(error, reason: error.reason),
      );
    } on Object catch (error) {
      throw ShorebirdUpdateException(_classifyFailure(error));
    }
  }

  Future<ShorebirdPatchState> readPatchState() async {
    try {
      final patches = await Future.wait([
        _updater.readCurrentPatch(),
        _updater.readNextPatch(),
      ]);
      final current = patches[0];
      final next = patches[1];

      if (current != null && next == null) {
        return const ShorebirdPatchState(
          ShorebirdPatchStateKind.rollbackPending,
        );
      }
      if (next == null || current?.number == next.number) {
        return const ShorebirdPatchState(ShorebirdPatchStateKind.noNextPatch);
      }
      return ShorebirdPatchState(
        ShorebirdPatchStateKind.newPatchReady,
        patchNumber: next.number,
      );
    } on Object {
      return const ShorebirdPatchState(ShorebirdPatchStateKind.unknown);
    }
  }

  Future<ShorebirdPatchState> downloadAndVerify() async {
    if (_downloadInProgress) {
      return const ShorebirdPatchState(ShorebirdPatchStateKind.unknown);
    }
    _downloadInProgress = true;
    try {
      final before = await readPatchState();
      if (before.kind == ShorebirdPatchStateKind.newPatchReady ||
          before.kind == ShorebirdPatchStateKind.rollbackPending) {
        return before;
      }

      try {
        await _updater.update();
      } on UpdateException catch (error) {
        throw ShorebirdUpdateException(
          _classifyFailure(error, reason: error.reason),
        );
      } on Object catch (error) {
        throw ShorebirdUpdateException(_classifyFailure(error));
      }

      // update() can complete normally when another SDK update is already in
      // progress. Only report ready if the patch state confirms it.
      return await readPatchState();
    } finally {
      _downloadInProgress = false;
    }
  }

  ShorebirdUpdateFailure _classifyFailure(
    Object error, {
    UpdateFailureReason? reason,
  }) {
    final message = error.toString().toLowerCase();
    if (error is SocketException ||
        message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('name or service not known') ||
        message.contains('network is unreachable') ||
        message.contains('connection timed out')) {
      return ShorebirdUpdateFailure.network;
    }
    if (RegExp(
      r'(?:http(?: status)?|status(?: code)?|response code)\s*[:=]?\s*5\d\d\b',
    ).hasMatch(message)) {
      return ShorebirdUpdateFailure.server;
    }
    if (reason == UpdateFailureReason.downloadFailed ||
        reason == UpdateFailureReason.installFailed) {
      return ShorebirdUpdateFailure.download;
    }
    if (reason == UpdateFailureReason.noUpdate) {
      return ShorebirdUpdateFailure.noUpdate;
    }
    return ShorebirdUpdateFailure.unknown;
  }
}
