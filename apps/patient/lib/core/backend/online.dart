import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the phone has a network at all (Wi-Fi, mobile data, ethernet). False only when the system says there is
/// none; a network that can't reach us shows up as a failed request instead (GI-67).
///
/// If the platform can't tell, we assume online and let requests speak for themselves.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool online(List<ConnectivityResult> r) => r.isEmpty || r.any((x) => x != ConnectivityResult.none);
  try {
    yield online(await c.checkConnectivity());
    yield* c.onConnectivityChanged.map(online);
  } catch (_) {
    yield true;
  }
});
