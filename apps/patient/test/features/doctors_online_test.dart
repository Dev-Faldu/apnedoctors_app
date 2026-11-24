import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/core/theme/tokens.dart';
import 'package:apnedoctors/features/welcome/doctors_online.dart';

void main() {
  group('reading the backend answer (public.doctors_online)', () {
    test('EC-COPY-01: nobody online means no chip', () {
      expect(DoctorsOnline.fromJson({'count': 0, 'faces': []}), isNull);
    });

    test('a live count keeps the board tints in order', () {
      final d = DoctorsOnline.fromJson({
        'count': 14,
        'faces': [
          {'id': 'a', 'initials': 'AR'},
          {'id': 'b', 'initials': 'KM'},
          {'id': 'c', 'initials': 'SN'},
        ],
      })!;
      expect(d.count, 14);
      expect(d.faces.map((f) => f.initials), ['AR', 'KM', 'SN']);
      expect(d.faces.map((f) => f.tint), [AdColors.avatarIndigo, AdColors.avatarRose, AdColors.avatarLeaf]);
      expect(d, boardDoctorsOnline);
    });

    test('a broken answer is an error, never a guess', () {
      expect(() => DoctorsOnline.fromJson(null), throwsFormatException);
      expect(() => DoctorsOnline.fromJson({'count': '3', 'faces': []}), throwsFormatException);
      expect(() => DoctorsOnline.fromJson({'count': 3}), throwsFormatException);
    });
  });

  group('keeping the count live', () {
    const every = Duration(milliseconds: 5);
    final one = DoctorsOnline.fromJson({'count': 1, 'faces': []});

    test('asks again on a schedule', () async {
      var calls = 0;
      final values = await watchDoctorsOnline(() async {
        calls++;
        return one;
      }, every: every).take(3).toList();
      expect(values, [one, one, one]);
      expect(calls, 3);
    });

    test('EC-LAUNCH-11: offline from the start means no chip, and it keeps trying', () async {
      var calls = 0;
      final values = await watchDoctorsOnline(() async {
        calls++;
        if (calls < 3) throw TimeoutException('offline');
        return one;
      }, every: every).take(3).toList();
      expect(values, [null, null, one]);
    });

    test('a short outage keeps the last count; a long one hides it (EC-INFRA-01)', () async {
      var clock = DateTime(2026);
      var calls = 0;
      final stream = watchDoctorsOnline(
        () async {
          calls++;
          if (calls == 1) return one;
          throw TimeoutException('offline');
        },
        every: every,
        now: () => clock,
      );
      final seen = <DoctorsOnline?>[];
      final sub = stream.listen(seen.add);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(seen, [one], reason: 'still within 2 minutes of the last answer');
      clock = clock.add(const Duration(minutes: 3));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(seen.first, one);
      expect(seen.last, isNull, reason: 'nobody can vouch for that number any more');
      await sub.cancel();
    });
  });
}
