// Talks to the real ApneDoctors Supabase project through the app's own code. Off by default:
//   flutter test --dart-define=LIVE=true test/live
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:apnedoctors/core/config/env.dart';
import 'package:apnedoctors/features/get_started/code_verifier.dart';
import 'package:apnedoctors/features/get_started/phone_code_sender.dart';
import 'package:apnedoctors/features/welcome/doctors_online.dart';
import 'package:apnedoctors/shared/indian_phone.dart';

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

  // Uses a Supabase test number (fixed code, no SMS is sent). Its code is never in the repo.
  test('GS1: Send code asks Supabase for a real code (test number, no SMS)', () async {
    final result = await SupabasePhoneCodeSender(client).send(parseIndianPhone('+91 90000 00001') as PhoneOk);
    // a second run within a minute meets Supabase's own wait, which the screen shows as a countdown (GI-26)
    expect(result is CodeSent || result is SendWait, isTrue, reason: '$result');
  }, skip: !live);

  // GS2 end to end on a Supabase test number: a real send, then the real check. The test number's fixed code is
  // given at run time (--dart-define=TEST_CODE=...), never written in the repo.
  const testCode = String.fromEnvironment('TEST_CODE');
  test('GS2: the right code signs in; a wrong one is rejected (test number, no SMS)', () async {
    final phone = parseIndianPhone('+91 90000 00002') as PhoneOk;
    final sent = await SupabasePhoneCodeSender(client).send(phone);
    expect(sent is CodeSent || sent is SendWait, isTrue, reason: '$sent');
    final verifier = SupabaseCodeVerifier(client);
    final wrong = testCode == '000000' ? '111111' : '000000';
    expect(await verifier.verify(phone, wrong), isA<VerifyRejected>());
    expect(await verifier.verify(phone, testCode), isA<Verified>());
    expect(client.auth.currentSession, isNotNull);
    await client.auth.signOut();
  }, skip: !live || testCode.isEmpty);
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
