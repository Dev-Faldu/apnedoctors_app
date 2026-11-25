"""Getting in, on the server: age, consent, parent consent, the daily job, launch state and pro sign-up.

Runs every migration on Supabase's own Postgres image as the real roles (see test_database.py for how to start it).
Case IDs come from docs/product/specs/getting-in.md.
"""
import datetime
import json
import unittest
import uuid

import psycopg

from test_database import Db

IST = datetime.timezone(datetime.timedelta(hours=5, minutes=30))


def today():
    return datetime.datetime.now(IST).date()


class GettingIn(Db):
    # ---- helpers -------------------------------------------------------------------------------
    def new_user(self, phone=None):
        self.as_owner()
        uid = uuid.uuid4()
        self.q("insert into auth.users (id, aud, role, phone) values (%s, 'authenticated', 'authenticated', %s)",
               uid, phone)
        return uid

    def call(self, sql, *args):
        return self.one(sql, *args)

    def error(self, sql, *args):
        """The error code word the function raised (the app maps it to plain words), or None."""
        self.cur.execute('savepoint e')
        try:
            self.cur.execute(sql, args)
        except psycopg.Error as e:
            self.cur.execute('rollback to savepoint e')
            return e.diag.message_primary, e.diag.message_detail
        self.cur.execute('release savepoint e')
        return None

    def profile(self, uid):
        self.as_owner()
        cols = ('first_name', 'last_name', 'gender', 'birth_year', 'birth_month', 'birth_estimated', 'age_band',
                'parent_consent', 'onboarding_step', 'blocked_until', 'account_status', 'onboarded_at')
        row = self.q(f"select {', '.join(cols)} from public.profiles where id = %s", uid)[0]
        return dict(zip(cols, row))

    def years_ago(self, years, month_offset=-1):
        """A (year, month) that makes someone `years` old today (born a month before this one, by default)."""
        t = today()
        m = t.month + month_offset
        y = t.year - years
        while m < 1:
            m += 12
            y -= 1
        while m > 12:
            m -= 12
            y += 1
        return y, m

    def basics(self, uid, year=None, month=None, age=None, first='Priya', gender='woman', confirm=False):
        self.as_user(uid)
        return self.call('select public.set_basics(%s, %s, %s, %s, %s, %s, %s)',
                         first, 'Sharma', gender, year, month, age, confirm)

    def adult(self):
        u = self.new_user()
        self.basics(u, *self.years_ago(30))
        return u

    def teen(self, phone='919811111111'):
        u = self.new_user(phone)
        self.basics(u, *self.years_ago(15))
        return u


class Profiles(GettingIn):
    def test_every_new_account_gets_a_profile_at_the_first_step(self):
        u = self.new_user()
        p = self.profile(u)
        self.assertEqual((p['onboarding_step'], p['account_status'], p['parent_consent']), ('basics', 'active', 'not_needed'))

    def test_gs3_an_adult_goes_on_to_the_data_consent(self):
        u = self.new_user()
        r = self.basics(u, *self.years_ago(30))
        self.assertEqual(r, {'result': 'ok', 'next_step': 'data_consent', 'age_band': '18+'})
        p = self.profile(u)
        self.assertEqual((p['first_name'], p['last_name'], p['gender'], p['birth_estimated']), ('Priya', 'Sharma', 'woman', False))

    def test_gs4_a_teen_goes_on_to_parent_consent(self):
        u = self.new_user()
        r = self.basics(u, *self.years_ago(15))
        self.assertEqual(r['next_step'], 'parent')
        p = self.profile(u)
        self.assertEqual((p['age_band'], p['parent_consent']), ('13-17', 'needed'))

    def test_ages_are_cautious_about_this_months_birthday(self):
        # born this month 18 years ago: we assume the birthday hasn't come yet, so still 17
        u = self.new_user()
        y, m = self.years_ago(18, month_offset=0)
        self.assertEqual(self.basics(u, y, m)['age_band'], '13-17')

    def test_gi_41_under_13_saves_nothing_and_blocks_the_account_for_a_day(self):
        u = self.new_user()
        r = self.basics(u, *self.years_ago(10))
        self.assertEqual(r['result'], 'under_13')
        p = self.profile(u)
        self.assertIsNone(p['first_name'])
        self.assertIsNone(p['birth_year'])
        self.assertIsNotNone(p['blocked_until'])
        self.as_user(u)
        self.assertEqual(self.error('select public.set_basics(%s, null, %s, %s, %s)', 'Priya', 'woman',
                                    *self.years_ago(30))[0], 'age_blocked')

    def test_g7_only_know_your_age_is_stored_as_an_estimate(self):
        u = self.new_user()
        r = self.basics(u, age=52)
        self.assertEqual(r['age_band'], '18+')
        p = self.profile(u)
        self.assertEqual((p['birth_year'], p['birth_month'], p['birth_estimated']), (today().year - 52, None, True))

    def test_gi_46_an_estimated_age_under_18_needs_month_and_year(self):
        u = self.new_user()
        self.as_user(u)
        self.assertEqual(self.error("select public.set_basics('Priya', null, 'woman', null, null, 16)")[0], 'exact_birth_needed')
        self.assertEqual(self.error("select public.set_basics('Priya', null, 'woman', null, null, 9)")[0], 'exact_birth_needed')

    def test_gi_40_impossible_dates_and_over_100_needs_a_confirm(self):
        u = self.new_user()
        self.as_user(u)
        t = today()
        nxt = (t.month % 12) + 1
        for year, month in ((t.year + 1, 1), (t.year - 121, 5), (1990, 13), (1990, 0)):
            self.assertEqual(self.error("select public.set_basics('Priya', null, 'woman', %s, %s)", year, month)[0],
                             'birth_invalid', (year, month))
        if nxt > t.month:  # a month later this year hasn't happened yet
            self.assertEqual(self.error("select public.set_basics('Priya', null, 'woman', %s, %s)", t.year, nxt)[0], 'birth_invalid')
        self.assertEqual(self.error("select public.set_basics('Priya', null, 'woman', null, null, 105)")[0], 'confirm_age')
        self.assertEqual(self.basics(u, age=105, confirm=True)['result'], 'ok')

    def test_gi_42_the_birth_date_is_locked_once_saved(self):
        u = self.new_user()
        y, m = self.years_ago(30)
        self.basics(u, y, m)
        self.as_user(u)
        self.assertEqual(self.error("select public.set_basics('Priya', null, 'woman', %s, %s)", y - 1, m)[0], 'birth_date_locked')
        self.assertEqual(self.error("select public.set_basics('Priya', null, 'woman', null, null, 40)")[0], 'birth_date_locked')
        # the same date with a new name is fine
        self.assertEqual(self.basics(u, y, m, first='Priyanka')['result'], 'ok')
        self.assertEqual(self.profile(u)['first_name'], 'Priyanka')

    def test_name_and_gender_are_needed(self):
        u = self.new_user()
        self.as_user(u)
        y, m = self.years_ago(30)
        self.assertEqual(self.error("select public.set_basics('  ', null, 'woman', %s, %s)", y, m)[0], 'name_needed')
        self.assertEqual(self.error("select public.set_basics('Priya', null, 'unknown', %s, %s)", y, m)[0], 'gender_needed')

    def test_ec_sec_nobody_writes_a_profile_directly(self):
        u = self.new_user()
        self.as_user(u)
        self.assertIsNotNone(self.denied("update public.profiles set age_band = '18+'"))
        self.assertIsNotNone(self.denied("update public.profiles set onboarding_step = 'done'"))
        self.as_anon()
        self.assertIsNotNone(self.denied("select public.set_basics('Priya', null, 'woman', 1990, 5)"))
        self.assertIsNotNone(self.denied('select * from public.profiles'))

    def test_people_see_only_their_own_profile(self):
        a, b = self.new_user(), self.new_user()
        self.as_user(a)
        self.assertEqual([r[0] for r in self.q('select id from public.profiles')], [a])


class Consent(GettingIn):
    def test_gs5_care_consent_is_recorded_with_its_notice_version_and_moves_on(self):
        u = self.adult()
        self.as_user(u)
        self.assertEqual(self.call("select public.record_consent('care', 'privacy-2026-11')"), {'next_step': 'health'})
        self.call("select public.record_consent('care', 'privacy-2026-11')")  # twice: still one active consent
        rows = self.q("select purpose, notice_version, withdrawn_at from public.consents")
        self.assertEqual(rows, [('care', 'privacy-2026-11', None)])

    def test_consent_can_be_withdrawn_and_given_again(self):
        u = self.adult()
        self.as_user(u)
        self.call("select public.record_consent('care', 'privacy-2026-11')")
        self.q("select public.withdraw_consent('care')")
        self.call("select public.record_consent('care', 'privacy-2026-12')")
        rows = self.q('select notice_version, withdrawn_at is null from public.consents order by granted_at, notice_version')
        self.assertEqual(rows, [('privacy-2026-11', False), ('privacy-2026-12', True)])

    def test_teens_give_no_health_consent_before_a_parent_says_yes(self):
        u = self.teen()
        self.as_user(u)
        self.assertEqual(self.error("select public.record_consent('care', 'privacy-2026-11')")[0], 'parent_consent_needed')

    def test_only_known_purposes(self):
        u = self.adult()
        self.as_user(u)
        self.assertEqual(self.error("select public.record_consent('marketing', 'v1')")[0], 'purpose_unknown')
        self.assertEqual(self.error("select public.record_consent('care', '')")[0], 'notice_version_needed')


class ParentConsent(GettingIn):
    def test_gs4_a_request_is_normalised_and_marks_the_teen_waiting(self):
        u = self.teen()
        self.as_user(u)
        r = self.call("select public.request_parent_consent('098 7654 3210')")
        self.assertIn('request_id', r)
        self.as_owner()
        self.assertEqual(self.q('select parent_phone, status from public.parent_consent_requests'), [('919876543210', 'pending')])
        self.assertEqual(self.profile(u)['parent_consent'], 'pending')

    def test_gi_43_the_parent_number_cannot_be_the_teens_own(self):
        u = self.teen(phone='919811111111')
        self.as_user(u)
        self.assertEqual(self.error("select public.request_parent_consent('+91 98111 11111')")[0], 'own_number')

    def test_resend_waits_60_seconds(self):
        u = self.teen()
        self.as_user(u)
        self.call("select public.request_parent_consent('9876543210')")
        word, detail = self.error("select public.request_parent_consent('9876543211')")
        self.assertEqual(word, 'wait')
        self.assertTrue(0 < int(detail) <= 60)

    def test_a_new_request_replaces_the_old_one(self):
        u = self.teen()
        self.as_user(u)
        self.call("select public.request_parent_consent('9876543210')")
        self.as_owner()
        self.q("update public.parent_consent_requests set created_at = now() - interval '2 minutes'")
        self.as_user(u)
        self.call("select public.request_parent_consent('9876543211')")
        self.as_owner()
        self.assertEqual(self.q('select parent_phone, status from public.parent_consent_requests order by created_at'),
                         [('919876543210', 'replaced'), ('919876543211', 'pending')])

    def test_only_teens_and_only_indian_mobiles(self):
        a = self.adult()
        self.as_user(a)
        self.assertEqual(self.error("select public.request_parent_consent('9876543210')")[0], 'not_a_teen')
        t = self.teen()
        self.as_user(t)
        for bad in ('12345', '5876543210', '+1 415 555 0100', '1800 123 4567'):
            self.assertEqual(self.error('select public.request_parent_consent(%s)', bad)[0], 'phone_invalid', bad)

    def test_a_yes_lets_the_teen_continue_and_a_no_shows_gi_07(self):
        yes, no = self.teen('919811111111'), self.teen('919822222222')
        for u in (yes, no):
            self.as_user(u)
            self.call("select public.request_parent_consent('9876543210')")
        self.as_owner()
        ids = dict(self.q('select teen_id, id from public.parent_consent_requests'))
        self.q('select private.decide_parent_consent(%s, true)', ids[yes])
        self.q('select private.decide_parent_consent(%s, false)', ids[no])
        self.assertEqual((self.profile(yes)['parent_consent'], self.profile(yes)['onboarding_step']), ('granted', 'data_consent'))
        self.assertEqual(self.profile(no)['parent_consent'], 'declined')
        self.as_user(yes)
        self.assertEqual(self.call("select public.record_consent('care', 'privacy-2026-11')"), {'next_step': 'health'})

    def test_nobody_can_answer_for_the_parent_from_the_app(self):
        u = self.teen()
        self.as_user(u)
        self.call("select public.request_parent_consent('9876543210')")
        self.assertIsNotNone(self.denied("select private.decide_parent_consent(gen_random_uuid(), true)"))
        self.assertIsNotNone(self.denied("update public.parent_consent_requests set status = 'approved'"))


class DailyJob(GettingIn):
    def test_gi_44_requests_expire_after_7_days(self):
        u = self.teen()
        self.as_user(u)
        self.call("select public.request_parent_consent('9876543210')")
        self.as_owner()
        self.q("update public.parent_consent_requests set expires_at = now() - interval '1 minute'")
        self.q('select private.daily_age_and_consent()')
        self.assertEqual(self.q('select status from public.parent_consent_requests'), [('expired',)])
        self.assertEqual(self.profile(u)['parent_consent'], 'expired')

    def test_gi_45_a_teen_who_turns_18_no_longer_needs_a_parent(self):
        u = self.teen()
        self.as_owner()
        y, m = self.years_ago(18)
        self.q('update public.profiles set birth_year = %s, birth_month = %s where id = %s', y, m, u)
        self.q('select private.daily_age_and_consent()')
        p = self.profile(u)
        self.assertEqual((p['age_band'], p['parent_consent'], p['onboarding_step']), ('18+', 'not_needed', 'data_consent'))


class Steps(GettingIn):
    def test_gs6_to_gs10_go_in_order_and_finish_onboarding(self):
        u = self.adult()
        self.as_user(u)
        self.call("select public.record_consent('care', 'privacy-2026-11')")
        self.assertEqual(self.error("select public.finish_onboarding_step('apps')"), ('step_out_of_order', 'health'))
        for step, nxt in (('health', 'medicines'), ('medicines', 'abha'), ('abha', 'apps'), ('apps', 'notifications'),
                          ('notifications', 'done')):
            self.assertEqual(self.call('select public.finish_onboarding_step(%s)', step), {'next_step': nxt})
        self.assertIsNotNone(self.profile(u)['onboarded_at'])

    def test_gi_13_keep_my_account_cancels_a_scheduled_deletion(self):
        u = self.adult()
        self.as_owner()
        self.q("update public.profiles set account_status = 'deletion_scheduled', deletion_scheduled_for = now() + interval '20 days' where id = %s", u)
        self.as_user(u)
        self.q('select public.keep_my_account()')
        self.assertEqual(self.profile(u)['account_status'], 'active')

    def test_gi_14_a_suspended_account_can_read_its_state_but_not_change_anything(self):
        u = self.adult()
        self.as_owner()
        self.q("update public.profiles set account_status = 'suspended', suspended_reason = 'Reported for abuse' where id = %s", u)
        self.as_user(u)
        self.assertEqual(self.error("select public.record_consent('care', 'v1')")[0], 'account_on_hold')
        s = self.call('select public.my_launch_state()')
        self.assertEqual((s['account_status'], s['suspended_reason']), ('suspended', 'Reported for abuse'))


class LaunchState(GettingIn):
    def test_my_launch_state_has_everything_the_router_needs(self):
        u = self.adult()
        self.as_user(u)
        self.q('select public.mark_first_home_seen()')
        s = self.call('select public.my_launch_state()')
        self.assertEqual(set(s), {'first_name', 'onboarding_step', 'age_band', 'parent_consent', 'account_status',
                                  'deletion_scheduled_for', 'suspended_reason', 'blocked_until', 'first_home_seen',
                                  'last_mode', 'roles', 'pro_application'})
        self.assertEqual((s['first_name'], s['onboarding_step'], s['first_home_seen'], s['roles'], s['pro_application']),
                         ('Priya', 'data_consent', True, [], None))

    def test_gi_15_anyone_can_read_the_minimum_app_version(self):
        self.as_anon()
        self.assertEqual(self.call('select public.app_requirements()'), {'min_version': {'android': '0.1.0', 'ios': '0.1.0'}})
        self.assertIsNotNone(self.denied('select public.my_launch_state()'))


DOCTOR = {'full_name': 'Asha Rao', 'council': 'Gujarat Medical Council', 'registration_number': 'G-12345',
          'registration_year': '2012', 'speciality': 'General medicine'}


class Pro(GettingIn):
    def upload(self, uid, name, size=1000, mime='application/pdf'):
        self.as_owner()
        self.q("insert into storage.objects (bucket_id, name, owner, metadata) values ('pro-docs', %s, %s, %s)",
               name, uid, json.dumps({'size': size, 'mimetype': mime}))
        return name

    def draft(self, uid, kind='doctor', details=DOCTOR):
        self.as_user(uid)
        return self.call('select public.save_pro_application(%s, %s)', kind, json.dumps(details))['id']

    def with_documents(self, uid, app):
        for kind in ('certificate', 'government_id', 'selfie'):
            path = self.upload(uid, f'{uid}/{kind}.pdf')
            self.as_user(uid)
            self.q('select public.attach_pro_document(%s, %s, %s)', app, kind, path)

    def test_pr3_a_doctor_saves_details_checked_field_by_field(self):
        u = self.adult()
        app = self.draft(u)
        self.as_user(u)
        self.assertEqual(self.error("select public.save_pro_application('doctor', '{\"hpr_id\": \"71-3254\"}')"),
                         ('field_invalid', 'hpr_id'))
        self.assertEqual(self.error("select public.save_pro_application('doctor', '{\"salary\": \"1\"}')"),
                         ('field_unknown', 'salary'))
        self.call("select public.save_pro_application('doctor', '{\"hpr_id\": \"71325412435623\"}')")
        self.as_owner()
        self.assertEqual(self.one('select details ->> %s from public.pro_applications where id = %s', 'hpr_id', app), '71325412435623')

    def test_each_partner_kind_has_its_own_fields(self):
        u = self.adult()
        self.as_user(u)
        self.call("select public.save_pro_application('pharmacy', %s)", json.dumps(
            {'store_name': 'Shree Medicals', 'drug_licence_20': 'GJ-20-123', 'drug_licence_21': 'GJ-21-123',
             'gstin': '24ABCDE1234F1Z5', 'pharmacist_registration': 'PH-998'}))
        self.assertEqual(self.error("select public.save_pro_application('pharmacy', '{\"gstin\": \"24abcde\"}')"),
                         ('field_invalid', 'gstin'))
        self.assertEqual(self.error("select public.save_pro_application('lab', '{\"store_name\": \"X Lab\"}')"),
                         ('field_unknown', 'store_name'))

    def test_pr4_submit_needs_every_required_field_and_document(self):
        u = self.adult()
        app = self.draft(u, details={k: v for k, v in DOCTOR.items() if k != 'speciality'})
        self.as_user(u)
        self.assertEqual(self.error('select public.submit_pro_application(%s)', app), ('field_missing', 'speciality'))
        self.call("select public.save_pro_application('doctor', '{\"speciality\": \"Paediatrics\"}')")
        self.assertEqual(self.error('select public.submit_pro_application(%s)', app), ('document_missing', 'certificate'))
        self.with_documents(u, app)
        self.as_user(u)
        self.assertEqual(self.call('select public.submit_pro_application(%s)', app)['status'], 'submitted')
        self.assertEqual(self.error("select public.save_pro_application('doctor', '{\"speciality\": \"ENT\"}')")[0],
                         'application_locked')

    def test_pr4_documents_must_be_yours_uploaded_and_within_the_limits(self):
        u, other = self.adult(), self.adult()
        app = self.draft(u)
        theirs = self.upload(other, f'{other}/certificate.pdf')
        self.as_user(u)
        self.assertEqual(self.error("select public.attach_pro_document(%s, 'certificate', %s)", app, theirs)[0], 'document_not_yours')
        self.assertEqual(self.error("select public.attach_pro_document(%s, 'certificate', %s)", app, f'{u}/missing.pdf')[0],
                         'document_not_uploaded')
        big = self.upload(u, f'{u}/huge.pdf', size=11 * 1024 * 1024)
        self.as_user(u)
        self.assertEqual(self.error("select public.attach_pro_document(%s, 'certificate', %s)", app, big)[0], 'document_invalid')
        gif = self.upload(u, f'{u}/photo.gif', mime='image/gif')
        self.as_user(u)
        self.assertEqual(self.error("select public.attach_pro_document(%s, 'selfie', %s)", app, gif)[0], 'document_invalid')

    def test_pr5_needs_changes_opens_only_the_fields_that_need_fixing(self):
        u = self.adult()
        app = self.draft(u)
        self.with_documents(u, app)
        self.as_user(u)
        self.call('select public.submit_pro_application(%s)', app)
        self.as_owner()
        self.q("select private.decide_pro_application(%s, 'needs_changes', 'The council name is incomplete.', array['council', 'selfie'])", app)
        self.as_user(u)
        self.call("select public.save_pro_application('doctor', '{\"council\": \"Gujarat Medical Council, Ahmedabad\"}')")
        self.assertEqual(self.error("select public.save_pro_application('doctor', '{\"full_name\": \"Someone Else\"}')"),
                         ('field_locked', 'full_name'))
        path = self.upload(u, f'{u}/selfie-2.jpg', mime='image/jpeg')
        self.as_user(u)
        self.q("select public.attach_pro_document(%s, 'selfie', %s)", app, path)
        cert = self.upload(u, f'{u}/cert-2.pdf')
        self.as_user(u)
        self.assertEqual(self.error("select public.attach_pro_document(%s, 'certificate', %s)", app, cert),
                         ('field_locked', 'certificate'))
        self.assertEqual(self.call('select public.submit_pro_application(%s)', app)['status'], 'submitted')

    def test_approval_adds_the_role_and_pro_mode(self):
        u, patient = self.adult(), self.adult()
        app = self.draft(u)
        self.with_documents(u, app)
        self.as_user(u)
        self.call('select public.submit_pro_application(%s)', app)
        self.as_owner()
        self.q("select private.decide_pro_application(%s, 'approved')", app)
        self.as_user(u)
        self.q("select public.set_mode('pro')")
        s = self.call('select public.my_launch_state()')
        self.assertEqual((s['roles'], s['last_mode'], s['pro_application']['status']), (['doctor'], 'pro', 'approved'))
        self.as_user(patient)
        self.assertEqual(self.error("select public.set_mode('pro')")[0], 'not_a_pro')

    def test_rejections_and_changes_always_say_why(self):
        u = self.adult()
        app = self.draft(u)
        self.with_documents(u, app)
        self.as_user(u)
        self.call('select public.submit_pro_application(%s)', app)
        self.as_owner()
        self.assertEqual(self.error("select private.decide_pro_application(%s, 'rejected')", app)[0], 'reason_needed')
        self.assertEqual(self.error("select private.decide_pro_application(%s, 'needs_changes', 'Fix it')", app)[0],
                         'fix_fields_needed')

    def test_ec_sec_nobody_approves_themselves_or_reads_anothers_application(self):
        u, other = self.adult(), self.adult()
        self.draft(other)
        app = self.draft(u)
        self.as_user(u)
        self.assertIsNotNone(self.denied("update public.pro_applications set status = 'approved'"))
        self.assertIsNotNone(self.denied("insert into public.user_roles (user_id, role) values (%s, 'doctor')", u))
        self.assertIsNotNone(self.denied("select private.decide_pro_application(%s, 'approved')", app))
        self.assertEqual(len(self.q('select id from public.pro_applications')), 1)

    def test_pro_docs_bucket_is_private_with_limits(self):
        row = self.q("select public, file_size_limit, allowed_mime_types from storage.buckets where id = 'pro-docs'")
        self.assertEqual(row, [(False, 10485760, ['application/pdf', 'image/jpeg', 'image/png'])])

    def test_pro_docs_people_upload_only_into_their_own_folder(self):
        u, other = self.adult(), self.adult()
        self.as_user(u)
        self.assertIsNotNone(self.denied(
            "insert into storage.objects (bucket_id, name, owner) values ('pro-docs', %s, %s)", f'{other}/x.pdf', u))
        self.assertIsNone(self.denied(
            "insert into storage.objects (bucket_id, name, owner) values ('pro-docs', %s, %s)", f'{u}/x.pdf', u))


if __name__ == '__main__':
    unittest.main()
