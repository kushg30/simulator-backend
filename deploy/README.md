# Deployment

Backend runs on **Render**, database on **Neon** (Postgres), frontend on **Vercel**
(`caserun.in`). Nothing here contains secrets — credentials live in each host's
environment-variable settings.

## 1. Database — Neon

The full schema and the seed content for both simulations are in this folder:

- `neon_schema.sql` — every table, constraint and index (no owner/privileges)
- `neon_seed.sql`   — authored content for both simulations (no runtime/test data)

To (re)load a Neon branch from scratch:

```bash
NEON='postgresql://neondb_owner:<PASSWORD>@<host>.neon.tech/neondb?sslmode=require'
psql "$NEON" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"   # wipes everything
psql "$NEON" -f neon_schema.sql
psql "$NEON" -f neon_seed.sql
```

To regenerate these files from a working local database:

```bash
pg_dump -h 127.0.0.1 -U postgres -d simulator_db --schema-only --no-owner --no-privileges -f neon_schema.sql
pg_dump -h 127.0.0.1 -U postgres -d simulator_db --data-only --no-owner \
  -t simulations -t simulation_roles -t rounds -t artifacts \
  -t decisions -t decision_options -t artifact_conditions \
  -t sim2_answer_key -t catalogue_artifacts -t sim2_wiki_entries \
  -f neon_seed.sql
```

## 2. Backend — Render

`application.properties` reads everything from the environment. Set these in the
Render service (Environment tab):

| Variable | Value |
|---|---|
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://<host>.neon.tech/neondb?sslmode=require` |
| `SPRING_DATASOURCE_USERNAME` | `neondb_owner` |
| `SPRING_DATASOURCE_PASSWORD` | the Neon password |
| `FACULTY_ACCESS_TOKEN` | a strong secret (guards every `/api/faculty/*` route) |
| `SIM2_UPLOAD_DIR` | `/tmp/uploads` (or a mounted disk to keep uploaded files) |

Everything else has a safe default in `application.properties`.

> Render's disk is ephemeral. Uploaded workbooks in `SIM2_UPLOAD_DIR` are lost on
> restart unless a persistent disk is mounted. They are review-only and never
> parsed, so this is acceptable unless you need them kept.

CORS already allows all origins, so the Vercel frontend can call the API.

## 3. Frontend — Vercel

Set one environment variable (Project → Settings → Environment Variables), then
redeploy (CRA bakes `REACT_APP_*` in at build time):

| Variable | Value |
|---|---|
| `REACT_APP_API_BASE` | the Render backend base URL, e.g. `https://simulator-backend.onrender.com` (no trailing slash, must be https) |

`vercel.json` rewrites all paths to `index.html` so deep links (`/sim2`,
`/faculty`) load directly.

## URLs

- Students: `https://caserun.in/sim2`
- Facilitator console: `https://caserun.in/faculty`
- Simulation 1 (unchanged): `https://caserun.in/teamjoin`
