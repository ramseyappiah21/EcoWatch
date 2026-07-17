# EcoWatch Tarkwa API

Node.js/Express REST backend with direct PostgreSQL access, local/MinIO media storage, JWT admin auth, USSD webhook, and DBSCAN hotspot detection.

## Architecture

```
Flutter App  ──►  REST API (Express)  ──►  PostgreSQL
                         │
                         └──►  Object storage (local / MinIO / S3)
```

## Prerequisites (Windows)

Install these **before** running the backend:

| Tool | Download | Verify |
|------|----------|--------|
| **Node.js 20 LTS** | https://nodejs.org/ | Close and reopen PowerShell, then `node -v` and `npm -v` |
| **Docker Desktop** | https://www.docker.com/products/docker-desktop/ | Start Docker Desktop, then `docker -v` |

Flutter is already installed on your machine; Node.js and Docker are not yet.

## Quick start

Run **one command per line** in PowerShell (do not paste `>>` continuation prompts).

```powershell
cd C:\Users\ramse\source\repos\EcoWatch\backend
```

### 1. Start infrastructure

```powershell
docker compose up -d
```

> Use `docker`, not `\docker`. Docker must be running (Docker Desktop open).

This starts:
- **PostgreSQL 16** on `localhost:5432`
- **MinIO** on `localhost:9000` (console `9001`)

### 2. Configure environment

```powershell
Copy-Item .env.example .env
```

> `.env.example` lives in the `backend` folder — run this **after** `cd backend`.

### 3. Install and migrate

```powershell
npm install
npm run db:migrate
npm run db:seed
```

### 4. Run API

```powershell
npm run dev
```

API base URL: `http://localhost:3000/v1`

Health check: `GET http://localhost:3000/health`

**Admin portal (single login for everyone):** http://localhost:3000/admin

Platform owner: **Tarkwa-Nsuaem Municipal Assembly**. Participating agencies manage incidents in their mandate.

Demo accounts (not shown on the login page): [docs/DEMO_ACCOUNTS.md](../docs/DEMO_ACCOUNTS.md).

Legacy `/admin/officer/*` URLs redirect to `/admin`.

**API smoke tests:** `npm.cmd run test:api`

## API endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/v1/reports` | — | Submit anonymous report (multipart media) |
| GET | `/v1/reports/track/:token` | — | Track report status |
| GET | `/v1/reports` | JWT | List reports (dashboard) |
| PATCH | `/v1/reports/:id/status` | JWT | Update report status |
| POST | `/v1/auth/login` | — | Admin login |
| GET | `/v1/maps/hotspots` | — | DBSCAN hotspot clusters |
| GET | `/v1/analytics` | JWT | Analytics dashboard data |
| GET | `/v1/analytics/export` | JWT | CSV export |
| POST | `/v1/ussd/webhook` | — | Africa's Talking USSD |
| GET | `/v1/public/emergency-contacts` | — | NADMO, Fire, EPA |
| GET | `/v1/public/announcements` | — | Public announcements |
| POST | `/v1/sync/batch` | — | Offline batch queue stub |

## Severity scoring (PRD)

| Signal | Points |
|--------|--------|
| Has image/video | +2 |
| Another report within 1 km (30 days) | +3 |
| Submitted within 24 hours | +1 |
| **Maximum** | **6** |

## Hotspot detection

### Current clusters (DBSCAN)

- **Algorithm:** DBSCAN (`eps=1 km`, `minPts=5`)
- **Window:** last 30 days
- **Job:** runs on startup and every 6 hours

### Hotspot growth trend

A 30-day rolling window tracks how the number of DBSCAN clusters (and reports within them) changes over time.

API:

- `GET /v1/analytics` — includes `hotspots` and `hotspotGrowth`
- `GET /v1/analytics/hotspots` — current hotspot detail with growth trend

Admin **Map** shows current hotspots as solid circles; the **Analytics** tab charts hotspot growth.

## Privacy

- No reporter login for mobile submissions
- No IMEI or IP storage
- Tracking tokens: `EW-XXXX-XXXX`
- USSD phone numbers stored as SHA-256 hash only

## Flutter integration

Set in `lib/core/constants/app_constants.dart`:

```dart
static const String apiBaseUrl = 'http://localhost:3000/v1';
```

For Android emulator use `http://10.0.2.2:3000/v1`.

## Production notes

- Change `JWT_SECRET` and admin passwords
- Wire `mediaService.js` to MinIO/S3/Cloudinary
- Configure Africa's Talking webhook URL to `/v1/ussd/webhook`
- Enable HTTPS and restrict `CORS_ORIGIN`
