// lib/services/PermissionCoordinator.dart
import 'dart:async';
import 'package:flutter/services.dart';                 // PlatformException
import 'package:permission_handler/permission_handler.dart';

/// Serialize permission requests across the whole app.
class PermissionCoordinator {
  PermissionCoordinator._();
  static final instance = PermissionCoordinator._();

  Future<void>? _inflight;

  bool _isAlreadyRunningError(Object e) =>
      e is PlatformException && e.code == 'PermissionHandler.PermissionManager';

  /// Request a batch (Set or List). Retries a few times if plugin says "already running".
  Future<Map<Permission, PermissionStatus>> request(Iterable<Permission> perms) async {
    // Wait for any in-flight app-level request.
    while (_inflight != null) {
      await _inflight;
    }
    final completer = Completer<void>();
    _inflight = completer.future;

    try {
      final list = perms.toList();
      if (list.isEmpty) return <Permission, PermissionStatus>{};

      int attempt = 0;
      while (true) {
        try {
          return await list.request(); // permission_handler extension
        } catch (e) {
          if (_isAlreadyRunningError(e) && attempt < 3) {
            attempt++;
            // brief backoff to allow the other dialog/request to conclude
            await Future.delayed(Duration(milliseconds: 200 * attempt));
            continue;
          }
          rethrow;
        }
      }
    } finally {
      completer.complete();
      _inflight = null;
    }
  }

  /// Read current statuses (no dialogs).
  Future<Map<Permission, PermissionStatus>> statuses(Iterable<Permission> perms) async {
    final map = <Permission, PermissionStatus>{};
    for (final p in perms) {
      map[p] = await p.status;
    }
    return map;
  }

  /// True if all given permissions are granted.
  Future<bool> allGranted(Iterable<Permission> perms) async {
    final m = await statuses(perms);
    return m.values.every((s) => s.isGranted);
  }
}
