"""Apply new migrations to the live Supabase project through the Management API.

    SUPABASE_ACCESS_TOKEN=<token> python3 supabase/deploy.py            # apply what is new
    SUPABASE_ACCESS_TOKEN=<token> python3 supabase/deploy.py --dry-run  # list what would run

- Migrations are tracked in supabase_migrations.schema_migrations, the table the Supabase CLI uses.
- Each migration runs in one transaction with its tracking row: all of it applies, or none of it.
- Migrations are append-only: if a migration that already shipped was edited, nothing runs.
- Never commit a token. Revoke a token you have pasted anywhere.
"""
import json
import os
import pathlib
import secrets
import sys
import urllib.error
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
REF = os.environ.get('SUPABASE_PROJECT_REF') or (HERE / 'project-ref').read_text().strip()
TOKEN = os.environ.get('SUPABASE_ACCESS_TOKEN')
API = f'https://api.supabase.com/v1/projects/{REF}'


def query(sql):
    req = urllib.request.Request(f'{API}/database/query', data=json.dumps({'query': sql}).encode(), method='POST',
                                 headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {TOKEN}'})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        raise SystemExit(f'Supabase refused the query ({e.code}): {e.read().decode()[:2000]}')


def literal(text):
    tag = f'm{secrets.token_hex(6)}'
    assert f'${tag}$' not in text
    return f'${tag}${text}${tag}$'


def main():
    if not TOKEN:
        raise SystemExit('Set SUPABASE_ACCESS_TOKEN (Supabase → Account → Access Tokens). Never commit it.')
    dry = '--dry-run' in sys.argv
    query("""create schema if not exists supabase_migrations;
             create table if not exists supabase_migrations.schema_migrations (version text primary key);
             alter table supabase_migrations.schema_migrations add column if not exists statements text[];
             alter table supabase_migrations.schema_migrations add column if not exists name text;""")
    shipped = {r['version']: r for r in query('select version, name, statements from supabase_migrations.schema_migrations')}

    files = sorted((HERE / 'migrations').glob('*.sql'))
    pending = []
    for f in files:
        version, _, name = f.stem.partition('_')
        sql = f.read_text()
        if version in shipped:
            stored = shipped[version].get('statements') or []
            if stored and stored != [sql]:
                raise SystemExit(f'{f.name} shipped already and has been edited since. Add a new migration instead.')
            continue
        pending.append((version, name, sql, f.name))

    if not pending:
        print(f'{REF}: up to date ({len(files)} migrations).')
        return
    for version, name, sql, fname in pending:
        if dry:
            print(f'would apply {fname}')
            continue
        query(f"""begin;
{sql}
insert into supabase_migrations.schema_migrations (version, name, statements)
values ({literal(version)}, {literal(name)}, array[{literal(sql)}]);
commit;""")
        print(f'applied {fname}')


if __name__ == '__main__':
    main()
