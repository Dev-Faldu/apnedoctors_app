// Talks to the real ApneDoctors Supabase project through the app's own code. Off by default:
//   flutter test --dart-define=LIVE=true test/live
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:apnedoctors/core/config/env.dart';
import 'package:apnedoctors/features/welcome/doctors_online.dart';

const live = bool.fromEnvironment('LIVE');

void main() {
  late SupabaseClient client;

  setUpAll(() {
    HttpOverrides.global = _RealNetwork(); // flutter_test blocks HTTP; this test needs the real network
    client = SupabaseClient(Env.supabaseUrl, Env.supabasePublishableKey);
  });
  tearDownAll(() => client.dispose());

  test('Welcome reads the live count of verified doctors online', () async {
    final online = await DoctorsOnlineSource(client).fetch();
    // null when nobody is online (the chip stays hidden); otherwise a real, positive count
    expect(online == null || online.count > 0, isTrue);
  }, skip: !live);

  test('EC-SEC-05: the public key cannot read the doctors directory', () async {
    await expectLater(
      client.from('doctors').select(),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
  }, skip: !live);

  test('EC-SEC-04: the public key cannot add a doctor or go online', () async {
    await expectLater(
      client.from('doctors').insert({'full_name': 'Not A Doctor', 'hpr_id': '12345678901234'}),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(client.rpc('set_doctor_presence', params: {'online': true}), throwsA(isA<PostgrestException>()));
  }, skip: !live);
}

/// The machine's own network: its proxy (HTTPS_PROXY) and any extra trusted certificate (SSL_CERT_FILE).
class _RealNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final extra = Platform.environment['SSL_CERT_FILE'];
    final ctx = context ?? SecurityContext(withTrustedRoots: true);
    if (extra != null && File(extra).existsSync()) ctx.setTrustedCertificates(extra);
    return super.createHttpClient(ctx)..findProxy = HttpClient.findProxyFromEnvironment;
  }
}
