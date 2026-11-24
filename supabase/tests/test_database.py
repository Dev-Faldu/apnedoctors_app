"""Database tests: every migration, run on Supabase's own Postgres image as the real roles.

    docker run -d --name adpg -e POSTGRES_PASSWORD=postgres -p 54322:5432 supabase/postgres:17.6.1.054
    python3 -m unittest discover -s supabase/tests -v

Everything happens in one transaction that is rolled back at the end, so the database stays clean and
the tests can run again. Each test works inside its own savepoint. Set TEST_DATABASE_URL to use another
database.
"""
import json
import os
import pathlib
import unittest
import uuid

import psycopg

ROOT = pathlib.Path(__file__).resolve().parents[2]
MIGRATIONS = sorted((ROOT / 'supabase' / 'migrations').glob('*.sql'))
URL = os.environ.get('TEST_DATABASE_URL', 'postgresql://postgres:postgres@127.0.0.1:54322/postgres')


class Db(unittest.TestCase):
    conn: psycopg.Connection

    @classmethod
    def setUpClass(cls):
        cls.conn = psycopg.connect(URL, autocommit=False)
        with cls.conn.cursor() as cur:
            for m in MIGRATIONS:  # applied as `postgres`, like the hosted project
                cur.execute(m.read_text())

    @classmethod
    def tearDownClass(cls):
        cls.conn.rollback()
        cls.conn.close()

    def setUp(self):
        self.cur = self.conn.cursor()
        self.cur.execute('savepoint t')

    def tearDown(self):
        self.cur.execute('rollback to savepoint t')
        self.cur.execute('reset role')
        self.cur.close()

    # ---- helpers -------------------------------------------------------------------------------
    def q(self, sql, *args):
        self.cur.execute(sql, args)
        return self.cur.fetchall() if self.cur.description else None

    def one(self, sql, *args):
        return self.q(sql, *args)[0][0]

    def as_anon(self):
        self.cur.execute('reset role')
        self.cur.execute("select set_config('request.jwt.claim.sub', '', true), set_config('request.jwt.claims', '', true)")
        self.cur.execute('set local role anon')

    def as_user(self, user_id):
        self.cur.execute('reset role')
        claims = json.dumps({'sub': str(user_id), 'role': 'authenticated'})
        self.cur.execute("select set_config('request.jwt.claim.sub', %s, true), set_config('request.jwt.claims', %s, true)",
                         (str(user_id), claims))
        self.cur.execute('set local role authenticated')

    def as_owner(self):
        self.cur.execute('reset role')

    def denied(self, sql, *args):
        """True when the statement is refused (no privilege, RLS or a raised rule)."""
        self.cur.execute('savepoint d')
        try:
            self.cur.execute(sql, args)
        except (psycopg.errors.InsufficientPrivilege, psycopg.errors.RaiseException) as e:
            self.cur.execute('rollback to savepoint d')
            return e
        self.cur.execute('release savepoint d')
        return None

    def new_user(self):
        uid = uuid.uuid4()
        self.q("insert into auth.users (id, aud, role, email) values (%s, 'authenticated', 'authenticated', %s)",
               uid, f'{uid}@example.test')
        return uid

    def new_doctor(self, name, *, verified=True, user=None, hpr=None):
        hpr = hpr or str(uuid.uuid4().int)[:14]
        return self.one(
            'insert into public.doctors (full_name, hpr_id, verified_at, user_id) values (%s, %s, %s, %s) returning id',
            name, hpr, 'now()' if verified else None, user)

    def seen(self, doctor, ago_seconds):
        self.q("insert into public.doctor_presence (doctor_id, last_seen_at) values (%s, now() - make_interval(secs => %s))",
               doctor, ago_seconds)

    def online(self):
        return self.one('select public.doctors_online()')


class Security(Db):
    def test_ec_sec_01_every_public_table_has_row_level_security(self):
        rows = self.q("""select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
                         where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity""")
        self.assertEqual(rows, [], 'tables without RLS')

    def test_ec_sec_02_anon_can_only_run_the_public_count(self):
        rows = self.q("""select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                         where n.nspname in ('public', 'private')
                           and has_function_privilege('anon', p.oid, 'execute') order by 1""")
        self.assertEqual([r[0] for r in rows], ['doctors_online'])

    def test_ec_sec_02_signed_in_people_can_count_and_doctors_can_set_presence(self):
        rows = self.q("""select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                         where n.nspname in ('public', 'private')
                           and has_function_privilege('authenticated', p.oid, 'execute') order by 1""")
        self.assertEqual([r[0] for r in rows], ['doctors_online', 'set_doctor_presence'])

    def test_ec_sec_03_the_private_schema_is_closed(self):
        for role in ('anon', 'authenticated'):
            self.assertFalse(self.one("select has_schema_privilege(%s, 'private', 'usage')", role), role)

    def test_ec_sec_04_nobody_outside_the_server_can_write_doctors_or_presence(self):
        d = self.new_doctor('Asha Rao')
        me = self.new_user()
        for who in ('anon', 'user'):
            self.as_anon() if who == 'anon' else self.as_user(me)
            self.assertIsNotNone(self.denied("insert into public.doctors (full_name, hpr_id) values ('Fake Doc', '12345678901234')"), who)
            self.assertIsNotNone(self.denied('update public.doctors set verified_at = now()'), who)
            self.assertIsNotNone(self.denied('insert into public.doctor_presence (doctor_id) values (%s)', d), who)
            self.assertIsNotNone(self.denied('delete from public.doctor_presence'), who)

    def test_ec_sec_05_the_directory_is_not_readable_by_the_public(self):
        self.new_doctor('Asha Rao')
        self.as_anon()
        self.assertIsNotNone(self.denied('select * from public.doctors'))
        self.assertIsNotNone(self.denied('select * from public.doctor_presence'))

    def test_ec_sec_05_a_doctor_sees_only_their_own_entry(self):
        me, other = self.new_user(), self.new_user()
        mine = self.new_doctor('Asha Rao', user=me)
        self.new_doctor('Kiran Mehta', user=other)
        stranger = self.new_user()
        self.as_user(me)
        self.assertEqual([r[0] for r in self.q('select id from public.doctors')], [mine])
        self.as_user(stranger)
        self.assertEqual(self.q('select id from public.doctors'), [])

    def test_hpr_ids_must_be_14_digits(self):
        self.cur.execute('savepoint h')
        with self.assertRaises(psycopg.errors.CheckViolation):
            self.q("insert into public.doctors (full_name, hpr_id) values ('Asha Rao', '71-3254-1243-5623')")
        self.cur.execute('rollback to savepoint h')


class DoctorsOnline(Db):
    def test_nobody_online_is_zero_with_no_faces(self):
        self.as_anon()
        self.assertEqual(self.online(), {'count': 0, 'faces': []})

    def test_ec_copy_01_counts_only_verified_doctors_seen_in_the_last_two_minutes(self):
        fresh = self.new_doctor('Asha Rao')
        self.seen(fresh, 30)
        self.seen(self.new_doctor('Kiran Mehta'), 119)
        self.seen(self.new_doctor('Sunil Nair'), 121)                    # gone quiet
        self.seen(self.new_doctor('Not Checked', verified=False), 5)    # not verified
        self.new_doctor('Never Online')
        self.as_anon()
        r = self.online()
        self.assertEqual(r['count'], 2)
        self.assertEqual([f['initials'] for f in r['faces']], ['AR', 'KM'])
        self.assertEqual(r['faces'][0]['id'], str(fresh))

    def test_shows_at_most_three_faces_newest_first(self):
        for i, name in enumerate(['Dr. Asha Rao', 'Kiran Mehta', 'Sunil Nair', 'Meera Iyer', 'Vikram']):
            self.seen(self.new_doctor(name), 10 + i)
        viewer = self.new_user()
        self.as_user(viewer)
        r = self.online()
        self.assertEqual(r['count'], 5)
        self.assertEqual([f['initials'] for f in r['faces']], ['AR', 'KM', 'SN'])

    def test_initials(self):
        cases = {'Asha Rao': 'AR', 'Dr. kiran  mehta': 'KM', 'dr Sunil Kumar Nair': 'SN', 'Vikram': 'V', '  Meera   Iyer ': 'MI'}
        for name, want in cases.items():
            self.assertEqual(self.one('select private.initials(%s)', name), want, name)


class Presence(Db):
    def test_a_verified_doctor_goes_online_and_away(self):
        me = self.new_user()
        self.new_doctor('Asha Rao', user=me)
        self.as_user(me)
        self.q('select public.set_doctor_presence(true)')
        self.assertEqual(self.online()['count'], 1)
        self.q('select public.set_doctor_presence(true)')  # heartbeat: still one
        self.assertEqual(self.online()['count'], 1)
        self.q('select public.set_doctor_presence(false)')
        self.assertEqual(self.online()['count'], 0)

    def test_people_who_are_not_verified_doctors_cannot_go_online(self):
        unverified, stranger = self.new_user(), self.new_user()
        self.new_doctor('Not Checked', verified=False, user=unverified)
        for uid in (stranger, unverified):
            self.as_user(uid)
            e = self.denied('select public.set_doctor_presence(true)')
            self.assertIsNotNone(e)
            self.assertIn('Only verified doctors', str(e))
        self.as_anon()
        self.assertIsNotNone(self.denied('select public.set_doctor_presence(true)'))

    def test_a_deleted_account_unlinks_the_directory_entry(self):
        me = self.new_user()
        d = self.new_doctor('Asha Rao', user=me)
        self.seen(d, 5)
        self.q('delete from auth.users where id = %s', me)
        self.assertIsNone(self.one('select user_id from public.doctors where id = %s', d))


if __name__ == '__main__':
    unittest.main()
