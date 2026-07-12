# Host EcoWatch (website + API + admin)

EcoWatch runs as **one web service**: Flutter citizen web, `/admin` portal, and `/v1` API, plus a **PostgreSQL** database.

## What you get after deploy

| URL | Purpose |
|-----|---------|
| `https://YOUR-APP.onrender.com/` | Citizen web app |
| `https://YOUR-APP.onrender.com/admin` | Official portal |
| `https://YOUR-APP.onrender.com/health` | Health check |
| `https://YOUR-APP.onrender.com/v1/...` | REST API |

Demo logins: [DEMO_ACCOUNTS.md](DEMO_ACCOUNTS.md) (not shown on the login page).

---

## Recommended: Render (free HTTPS)

### 1. Push this repo to GitHub

If the project is not on GitHub yet:

```powershell
cd C:\Users\ramse\source\repos\EcoWatch
git status
# commit hosting files if needed, then:
# git remote add origin https://github.com/YOUR_USER/EcoWatch.git
# git push -u origin main
```

### 2. Create a Render account

1. Go to [https://render.com](https://render.com) and sign up (GitHub login is easiest).
2. Click **New** → **Blueprint**.
3. Select the **EcoWatch** repository.
4. Render reads `render.yaml` and creates:
   - a **PostgreSQL** database (`ecowatch-db`)
   - a **Web service** that builds the `Dockerfile` (Flutter web + Node API)

### 3. Deploy

Click **Apply**. The Docker image is **Node-only** (API + `/admin`) so it fits Render’s free tier.  
Citizen Flutter web is optional (see below).

When status is **Live**, open the service URL. Root `/` redirects to `/admin` until Flutter web is bundled.

### 4. Seed demo accounts (no Shell / no payment)

Render **Shell is paid**. Use either method:

**A — Env var (easiest)**  
On the web service → **Environment** → add:

| Key | Value |
|-----|--------|
| `SEED_ON_BOOT` | `true` |

Then **Manual Deploy → Deploy latest commit**.  
On startup the server creates the demo users. Logins: [DEMO_ACCOUNTS.md](DEMO_ACCOUNTS.md).

**B — Seed from your PC**  
1. Render Postgres → copy **External Database URL**  
2. On your PC:

```powershell
cd C:\Users\ramse\source\repos\EcoWatch\backend
$env:DATABASE_URL="paste-external-url-here"
$env:NODE_ENV="production"
npm run db:seed
```

### 5. Point the Android app (optional)

Set `apiBaseUrl` in `lib/core/constants/app_constants.dart` to:

`https://YOUR-APP.onrender.com/v1`

Then rebuild the APK.

### 6. USSD (optional)

Africa’s Talking callback:

`https://YOUR-APP.onrender.com/v1/ussd/webhook`

Add `AT_API_KEY`, `AT_USERNAME`, and `AT_SHORT_CODE` in Render → Environment.

---

## After deploy checklist

- [ ] `GET /health` returns `"status":"ok"` and `"database":"ok"`
- [ ] `/admin` login works with a seeded account
- [ ] Citizen web at `/` loads
- [ ] Change or rotate `JWT_SECRET` if you shared it (Render can auto-generate)

---

## Free-tier note

Render’s free web service **sleeps after idle**. The first request after sleep may take ~30–60 seconds. For a permanent municipal deployment, upgrade to a paid plan or use a VPS.

---

## Alternative: Railway

1. [railway.app](https://railway.app) → New Project → Deploy from GitHub.
2. Add a **PostgreSQL** plugin; copy `DATABASE_URL` into the web service.
3. Set root directory / Dockerfile to the repo `Dockerfile`.
4. Set `JWT_SECRET` (random string) and `CORS_ORIGIN=*`.
5. Seed: `node src/db/seed.js` in the service shell.

---

## Alternative: VPS (DigitalOcean / Contabo)

1. Install Docker on the VPS.
2. Run managed Postgres or `docker compose` with Postgres.
3. Build and run:

```bash
docker build -t ecowatch .
docker run -d -p 80:3000 \
  -e DATABASE_URL="postgresql://..." \
  -e JWT_SECRET="long-random-secret" \
  -e CORS_ORIGIN="*" \
  --name ecowatch ecowatch
```

4. Put **Caddy** or **Nginx** in front for HTTPS (Let’s Encrypt).

---

## Local Docker test (optional)

```powershell
cd C:\Users\ramse\source\repos\EcoWatch
docker build -t ecowatch .
docker run --rm -p 3000:3000 `
  -e DATABASE_URL="postgresql://ecowatch:ecowatch@host.docker.internal:5432/ecowatch" `
  -e JWT_SECRET="local-test-secret" `
  ecowatch
```

(Requires your local Postgres from `backend/docker compose up -d postgres`.)

---

## Optional: include citizen Flutter web

On your PC (then commit and push):

```powershell
cd C:\Users\ramse\source\repos\EcoWatch
flutter build web --release
New-Item -ItemType Directory -Force -Path backend\public\web | Out-Null
Copy-Item -Recurse -Force build\web\* backend\public\web\
git add backend/public/web
git commit -m "Add Flutter web build for hosting"
git push
```

## If deploy failed

1. Open the failed deploy → **Logs** and copy the red error lines.
2. Common fixes already in this repo:
   - **No Flutter in Docker** (avoids OOM / image pull failures)
   - **Postgres SSL** enabled in production (`pool.js`)
3. Confirm env vars on the web service: `DATABASE_URL`, `JWT_SECRET`, `NODE_ENV=production`.
4. Click **Manual Deploy → Clear build cache & deploy**.

## Files added for hosting

| File | Role |
|------|------|
| `Dockerfile` | Node API + admin portal |
| `render.yaml` | One-click Render database + web service |
| `.dockerignore` | Keeps the image build smaller |
