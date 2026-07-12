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

Click **Apply**. The first build can take **10–20 minutes** (Flutter web compile).

When status is **Live**, open the service URL.

### 4. Seed demo accounts (once)

On the Render service → **Shell** (or one-off job), run:

```bash
cd /app/backend && node src/db/seed.js
```

Or from your PC (replace URL and use the Render Postgres external connection string if you prefer local seed — usually Shell on Render is simpler).

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

## Files added for hosting

| File | Role |
|------|------|
| `Dockerfile` | Builds Flutter web + runs Node API |
| `render.yaml` | One-click Render database + web service |
| `.dockerignore` | Keeps the image build smaller |
