import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend/backend.dart';
import '../../core/motion/keyframes.dart';
import '../../core/theme/tokens.dart';

/// Real doctors online right now. The chip only appears when this is known and above zero:
/// ApneDoctors never shows a made-up number.
@immutable
class DoctorsOnline {
  const DoctorsOnline({required this.count, this.faces = const []});

  final int count;

  /// Up to three doctors to show on the chip: initials and a tint.
  final List<({String initials, Color tint})> faces;

  static const _tints = [AdColors.avatarIndigo, AdColors.avatarRose, AdColors.avatarLeaf];

  /// Reads the backend's answer (`public.doctors_online()`): `{"count": n, "faces": [{"id", "initials"}]}`.
  /// Null when nobody is online, so nothing is shown.
  static DoctorsOnline? fromJson(Object? json) {
    if (json is! Map) throw FormatException('doctors_online: expected an object, got $json');
    final count = json['count'];
    final faces = json['faces'];
    if (count is! int || faces is! List) throw FormatException('doctors_online: bad shape $json');
    if (count <= 0) return null;
    return DoctorsOnline(
      count: count,
      faces: [
        for (final (i, f) in faces.take(3).indexed)
          if (f is Map && f['initials'] is String && (f['initials'] as String).isNotEmpty)
            (initials: f['initials'] as String, tint: _tints[i % _tints.length]),
      ],
    );
  }

  @override
  bool operator ==(Object other) => other is DoctorsOnline && other.count == count && listEquals(other.faces, faces);

  @override
  int get hashCode => Object.hash(count, Object.hashAll(faces));
}

/// Asks the backend how many verified doctors are online now.
class DoctorsOnlineSource {
  DoctorsOnlineSource(this._client);
  final SupabaseClient _client;

  Future<DoctorsOnline?> fetch() async =>
      DoctorsOnline.fromJson(await _client.rpc('doctors_online').timeout(const Duration(seconds: 8)));
}

final doctorsOnlineSourceProvider = Provider<DoctorsOnlineSource>(
  (ref) => DoctorsOnlineSource(ref.watch(supabaseProvider)),
);

/// The live count while Welcome is on screen, refreshed every [refreshEvery].
///
/// A doctor counts as online for 2 minutes after their last "I'm here", so a known count stays good
/// for that long. If the backend can't be reached for longer, the chip goes away rather than show
/// a number nobody can vouch for. Offline at launch: no chip, no error, nothing waits (EC-LAUNCH-11).
final doctorsOnlineProvider = StreamProvider.autoDispose<DoctorsOnline?>((ref) {
  final source = ref.watch(doctorsOnlineSourceProvider);
  return watchDoctorsOnline(source.fetch);
});

const refreshEvery = Duration(seconds: 30);
const trustFor = Duration(minutes: 2);

/// The polling behind [doctorsOnlineProvider], separated so it can be tested with real timing.
Stream<DoctorsOnline?> watchDoctorsOnline(
  Future<DoctorsOnline?> Function() fetch, {
  Duration every = refreshEvery,
  Duration keep = trustFor,
  DateTime Function() now = DateTime.now,
}) async* {
  DateTime? lastGood;
  while (true) {
    try {
      final online = await fetch();
      lastGood = now();
      yield online;
    } catch (e) {
      debugPrint('doctors_online: $e');
      if (lastGood == null || now().difference(lastGood) > keep) yield null;
    }
    await Future<void>.delayed(every);
  }
}

/// "14 doctors online now": white pill with doctors' faces and a live green dot.
class DoctorsOnlineChip extends StatelessWidget {
  const DoctorsOnlineChip({super.key, required this.online, required this.time, this.reduced = false});

  final DoctorsOnline online;
  final ValueListenable<double> time;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final label = '${online.count} ${online.count == 1 ? 'doctor' : 'doctors'} online now';
    final faces = online.faces.take(3).toList();
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.only(left: 6, right: 14, top: 4, bottom: 4),
        decoration: const BoxDecoration(
          color: AdColors.white,
          borderRadius: BorderRadius.all(Radius.circular(999)),
          boxShadow: [BoxShadow(color: Color(0x0F1A1410), offset: Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (faces.isNotEmpty) ...[
              SizedBox(
                width: 32 + 22.0 * (faces.length - 1),
                height: 32,
                child: Stack(
                  children: [
                    for (var i = 0; i < faces.length; i++)
                      Positioned(left: 22.0 * i, top: 0, child: _Face(faces[i].initials, faces[i].tint)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],
            SizedBox(width: 9, height: 9, child: CustomPaint(painter: _LiveDot(time, reduced))),
            const SizedBox(width: 10),
            Flexible(child: Text(label, style: AdType.chip)),
          ],
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face(this.initials, this.tint);
  final String initials;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: tint,
        shape: BoxShape.circle,
        border: Border.all(color: AdColors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(initials, style: AdType.avatar),
    );
  }
}

/// Green dot with a ring that breathes out (`livePulse`, 2 s).
class _LiveDot extends CustomPainter {
  _LiveDot(this.time, this.reduced) : super(repaint: reduced ? null : time);
  final ValueListenable<double> time;
  final bool reduced;

  static final _ring = Keyframes(
    dim: 2, // spread px, alpha
    offsets: const [0, .6, 1],
    values: const [0, .55, 7, 0, 0, .55],
    curves: const [null, null, null],
  );
  static const _anim = CssAnim(2, infinite: true, curve: cssEaseInOut);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (!reduced) {
      final p = _anim.progress(time.value)!;
      final spread = _ring.at(p, 0, _anim.curve);
      final alpha = _ring.at(p, 1, _anim.curve);
      if (alpha > 0 && spread > 0) {
        canvas.drawCircle(c, 4.5 + spread, Paint()..color = AdColors.green.withValues(alpha: alpha.clamp(0, 1)));
      }
    }
    canvas.drawCircle(c, 4.5, Paint()..color = AdColors.green);
  }

  @override
  bool shouldRepaint(_LiveDot old) => old.reduced != reduced || old.time != time;
}

/// The board's example (14 doctors, AR/KM/SN). Only for tests that compare the chip with the board;
/// the app never shows it.
const boardDoctorsOnline = DoctorsOnline(
  count: 14,
  faces: [
    (initials: 'AR', tint: AdColors.avatarIndigo),
    (initials: 'KM', tint: AdColors.avatarRose),
    (initials: 'SN', tint: AdColors.avatarLeaf),
  ],
);
