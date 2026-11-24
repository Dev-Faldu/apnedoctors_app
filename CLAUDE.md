# ApneDoctors: engineering guide

ApneDoctors is a complete care app for India: feel unwell → find a doctor → book → pay → consult →
medicines, lab tests, admission → records → follow-up, for yourself and your family. Built on ABDM
(ABHA, HFR, HPR, consent). Always write the name as **ApneDoctors**. English only for now.

## Read first, every session

@docs/product/memory.md

- Edge cases with IDs: [`docs/product/edge-cases.md`](docs/product/edge-cases.md). A feature is done only
  when its cases are handled and tested. Name case IDs in tests and commits (`EC-LAUNCH-07`).
- Screens and what's built: [`docs/product/screen-map.md`](docs/product/screen-map.md).
- When a decision changes, update `memory.md` in the same commit.

## Repo map

| Path | What lives there |
|---|---|
| `apps/patient/` | The patient app (Flutter, iOS + Android). How to run and test: [`apps/patient/CLAUDE.md`](apps/patient/CLAUDE.md). |
| `supabase/` | Database: `migrations/` (append-only), `deploy.py` (applies them to the live project), `tests/`. |
| `docs/design/kalighat-pop/` | Design boards (HTML, they animate) and their generators. The source of truth for look and motion. |
| `docs/product/` | Memory, edge cases, screen map. |

The legacy Expo app and the old Supabase project live in `Dev-Faldu/apnedoctors-app`. Don't change them.

## Rules

**Design ("Kalighat pop", approved)**
- Colours, type and sizes only from `apps/patient/lib/core/theme/tokens.dart`. No ad-hoc values.
- No plain emoji (draw icons), no static screens (gentle motion, respect reduced motion), no Instagram or
  Snapchat patterns, one idea per screen, 24 px side margins, body text 16 px or larger, WCAG AA.
- Check every screen at 360×640 and 390×844. Match the boards frame for frame (`apps/patient/tool/design_compare`).

**Health and safety (non-negotiable)**
- The app never diagnoses, names conditions, or suggests or doses medicines. Only verified doctors do.
- Crisis and emergency messages are screened before any reply and routed to Tele-MANAS 14416 and 112.
  Abuse goes to 1098 / 181, sextortion to 1930.
- No calorie counting, weight targets or restriction language. No made-up numbers or fake urgency.
- Ages 13+. 13–17 need verified parental consent (DPDP) before chat, public posts or medicines.

**Data and security**
- Supabase: row-level security on every table; clients call security-definer functions that check the
  rules first. Internal functions are revoked from public/anon/authenticated, granted to service_role only.
- Migrations are append-only. Never edit one that has shipped.
- Never commit secrets or tokens. The Supabase URL and publishable key are public by design.

**Code**
- Every change comes with tests; `flutter analyze` clean; goldens for every screen at 360×640 and 390×844.
- Copy is short, friendly and accurate. Errors tell people what to do next.

## Database (Supabase project `yljfnbudjdijwjshqaba`, ap-south-1)

```bash
docker run -d --name adpg -e POSTGRES_PASSWORD=postgres -p 54322:5432 supabase/postgres:17.6.1.054
python3 -m unittest discover -s supabase/tests -v          # every migration, as the real roles
SUPABASE_ACCESS_TOKEN=<token> python3 supabase/deploy.py    # apply new migrations to the live project
SUPABASE_ACCESS_TOKEN=<token> python3 supabase/tests/live_check.py
```

In the "ApneDoctors" cloud environment the token is a network secret: use `SUPABASE_ACCESS_TOKEN=proxy-injected`.
Never edit a shipped migration; add a new one. Every new table: RLS on, explicit grants, tests in
`supabase/tests/test_database.py`, and a line in `live_check.py` when it changes what the public can do.

## Git
- This repo: `Dev-Faldu/apnedoctors_app`. Work happens on `flutter-v1` until the founder says otherwise.
- Before pushing, check `git remote -v` points at `https://github.com/Dev-Faldu/apnedoctors_app`.
