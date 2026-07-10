import 'package:connectivity_plus/connectivity_plus.dart';

/// Single entry point for internet-connectivity checks used across kGallery.
///
/// Wraps `connectivity_plus` so the rest of the package never talks to it
/// directly. This keeps the connectivity dependency isolated in one place and
/// makes it easy to swap the implementation later (e.g. add a real reachability
/// probe on top of the interface check).
///
/// Note: [isConnected] reports whether the device has an active network
/// *interface* (Wi-Fi / cellular / ethernet) — not a guaranteed round-trip to
/// the internet. A Wi-Fi network with no upstream still reads as connected.
class ConnectivityService {
  ConnectivityService._();

  /// Shared instance. Use this everywhere instead of constructing new ones.
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  /// Whether the device currently has any network connection.
  ///
  /// Returns `false` only when every reported result is
  /// [ConnectivityResult.none].
  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  /// Emits `true` when a connection becomes available and `false` when it is
  /// lost. Host apps (or future in-viewer features) can listen to react to
  /// connectivity changes.
  Stream<bool> get onConnectivityChanged => _connectivity.onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none));
}
