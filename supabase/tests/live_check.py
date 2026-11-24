"""Checks the live project the way the app and the public see it. Writes nothing.

    SUPABASE_ACCESS_TOKEN=<token> python3 supabase/tests/live_check.py

Uses the public URL and publishable key (as the app does) for the API checks, and the Management API
(read-only queries and Supabase's security advisor) for the database checks.
"""
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request

HERE = pathlib.Path(__file__).resolve().parents[1]
REF = (HERE / 'project-ref').read_text().strip()
URL = f'https://{REF}.supabase.co'
KEY = 'sb_publishable_pGrEpGT8AXMufKOXy9HunQ_en7KRst8'  # public by design
TOKEN = os.environ.get('SUPABASE_ACCESS_TOKEN')
failures = []


def call(method, url, body=None, headers=None):
    req = urllib.request.Request(url, data=None if body is None else json.dumps(body).encode(), method=method,
                                 headers={'Content-Type': 'application/json', **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read().decode()
            return r.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, raw


def public(method, path, body=None):
    return call(method, f'{URL}{path}', body, {'apikey': KEY, 'Authorization': f'Bearer {KEY}'})


def check(name, ok, detail=''):
    print(('PASS ' if ok else 'FAIL ') + name + (f'  ({detail})' if detail and not ok else ''))
    if not ok:
        failures.append(name)


status, body = public('POST', '/rest/v1/rpc/doctors_online', {})
check('anyone can ask how many verified doctors are online', status == 200 and isinstance(body, dict)
      and isinstance(body.get('count'), int) and isinstance(body.get('faces'), list), f'{status} {body}')
print(f'     live answer: {body}')

status, body = public('GET', '/rest/v1/doctors?select=*')
check('the public cannot read the doctors directory', status in (401, 403), f'{status} {body}')
status, body = public('POST', '/rest/v1/doctors', {'full_name': 'Fake Doctor', 'hpr_id': '12345678901234'})
check('the public cannot add a doctor', status in (401, 403), f'{status} {body}')
status, body = public('GET', '/rest/v1/doctor_presence?select=*')
check('the public cannot read presence', status in (401, 403), f'{status} {body}')
status, body = public('POST', '/rest/v1/rpc/set_doctor_presence', {'online': True})
check('the public cannot set presence', status in (401, 403, 404), f'{status} {body}')

if TOKEN:
    def query(sql):
        return call('POST', f'https://api.supabase.com/v1/projects/{REF}/database/query', {'query': sql},
                    {'Authorization': f'Bearer {TOKEN}'})

    status, rows = query("""select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
                            where n.nspname = 'public' and c.relkind in ('r','p') and not c.relrowsecurity""")
    check('every public table has row-level security', status in (200, 201) and rows == [], f'{status} {rows}')
    status, rows = query("""select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                            where n.nspname in ('public','private')
                              and has_function_privilege('anon', p.oid, 'execute') order by 1""")
    check('the public can run only doctors_online', status in (200, 201) and [r['proname'] for r in rows] == ['doctors_online'],
          f'{status} {rows}')
    status, rows = query("""begin;
                            create table public.zz_rls_probe (id int);
                            select relrowsecurity as rls from pg_class where oid = 'public.zz_rls_probe'::regclass;
                            rollback;""")
    check('new tables still get row-level security automatically', status in (200, 201) and rows and rows[-1].get('rls') is True,
          f'{status} {rows}')
    status, rows = query('select version from supabase_migrations.schema_migrations order by 1')
    local = sorted(p.stem.partition('_')[0] for p in (HERE / 'migrations').glob('*.sql'))
    check('every migration in the repo is applied', status in (200, 201) and [r['version'] for r in rows] == local, f'{rows}')
    status, auth = call('GET', f'https://api.supabase.com/v1/projects/{REF}/config/auth', None, {'Authorization': f'Bearer {TOKEN}'})
    check('sign-in methods are only the decided ones (no email, no anonymous accounts)', status == 200
          and auth.get('external_email_enabled') is False and auth.get('external_anonymous_users_enabled') is False, f'{status}')
    status, adv = call('GET', f'https://api.supabase.com/v1/projects/{REF}/advisors/security', None,
                       {'Authorization': f'Bearer {TOKEN}'})
    lints = (adv or {}).get('lints', []) if isinstance(adv, dict) else []
    errors = [l for l in lints if l.get('level') == 'ERROR']
    check("Supabase's security advisor finds no errors", status == 200 and not errors, f'{status} {errors or adv}')
    for l in lints:
        print(f"     advisor {l.get('level')}: {l.get('title')} — {l.get('detail', '')[:160]}")
else:
    print('skip database checks: set SUPABASE_ACCESS_TOKEN')

sys.exit(1 if failures else 0)
