# EcoWatch — Presentation Guide

Demo platform for **Tarkwa-Nsuaem Municipal Assembly** environmental incident reporting and multi-agency coordination.

## Before you present

```bash
# Terminal 1 — backend
cd backend
docker compose up -d postgres
npm install
npm run db:seed
npm run dev

# Terminal 2 — Flutter app
flutter pub get
flutter run -d windows   # or chrome / android
```

Open the admin portal: **http://localhost:3000/admin**

## Privacy story (lead with this)

- Citizens report **anonymously** — no account required.
- We collect **text, photos, and videos** — **no voice recordings** (voice can identify people in small communities).
- The citizen’s live GPS is **not submitted** — only the incident map pin.
- Researchers see **anonymized aggregates only** (no media, no exact locations).

## Demo flow (15 minutes)

### 1. Citizen mobile app (3 min)

1. Open the app → skip login or tap **Continue without account**.
2. **Report** → pick a category (e.g. **Illegal Mining** or **Waste Dumping**).
3. Attach a **photo** (optional video).
4. Add a short **text description**.
5. Mark location on the map → **Submit**.
6. Show the **tracking token** (`EW-XXXX-XXXX`).

### 2. Track status (1 min)

1. Go to **Track** tab.
2. Enter the tracking token → show status updates.

### 3. Agency admin receives report (3 min)

1. Admin portal → sign in as **EPA**: `epa@ecowatch.gov` / `epa123`
2. Show the new report in the table (category, severity, description, photo).
3. Point out **multi-agency routing** on a chemical spill if seeded.

### 4. Assign officer (2 min)

1. While status is **Received**, assign **EPA Officer**: `epa.officer@ecowatch.gov` / `epaoff123`
2. Explain: assignment is only available at **Received**.

### 5. Officer investigation (3 min)

1. Sign in as **EPA Officer**.
2. Open **My Cases** → advance status: **Under Investigation** → **Site Visited** → **Awaiting Action** → **Resolved**.
3. Add investigation notes or field photo if time allows.

### 6. Admin closes case (1 min)

1. Back to **EPA Admin** → show live status badge updating.
2. **Close** the case when resolved.

### 7. Municipal oversight (2 min)

1. Sign in as **Municipal Admin**: `municipal@ecowatch.gov` / `municipal123`
2. Show cross-agency view, map hotspots, performance tab.

### 8. Research portal (optional, 1 min)

1. `researcher@ecowatch.gov` / `researcher123`
2. Show anonymized export — no tokens, no media, blurred coordinates.

## Role cheat sheet

Full list: **[DEMO_ACCOUNTS.md](DEMO_ACCOUNTS.md)**

| Role | Email | Password |
|------|-------|----------|
| Super Admin | superadmin@ecowatch.gov | superadmin123 |
| Municipal Admin | municipal@ecowatch.gov | municipal123 |
| EPA Admin | epa@ecowatch.gov | epa123 |
| EPA Officer | epa.officer@ecowatch.gov | epaoff123 |
| NADMO Emergency | nadmoemg@ecowatch.gov | nadmoemg123 |
| Researcher | researcher@ecowatch.gov | researcher123 |

## Talking points

- **Shared municipal platform** — TNMA owns the system; agencies operate within mandate.
- **Automatic routing** — category drives EPA, Fire, NADMO, Police, WRC, Forestry, Waste.
- **Privacy by design** — anonymous reporting, no voice, researcher anonymization.
- **Operational workflow** — receive → assign → investigate → resolve → close.
- **Hotspot detection** — DBSCAN clusters of recent incidents shown on the map, with a 30-day growth trend.

## If something breaks

- **No reports?** Re-run `npm run db:seed` and submit a fresh report from the app.
- **Officer can’t update?** Case must be assigned to that officer; only officers advance investigation status.
- **Can’t assign?** Status must be **Received**; refresh the admin page.
- **Map empty?** Ensure backend is running on port 3000 and Flutter API base URL points to it.
