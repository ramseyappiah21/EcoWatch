# EcoWatch Tarkwa

Mobile and USSD-based civic engagement platform for environmental monitoring in Tarkwa-Nsuaem, Ghana.

## Ownership model

EcoWatch is a **shared municipal platform** owned by **Tarkwa-Nsuaem Municipal Assembly**. Participating government agencies manage incidents within their legal mandate. Incidents are routed automatically by category.

## Features

- **Anonymous incident reporting** with GPS map pin, text, and photo/video evidence
- **Privacy-first design** — no voice recordings (voice can identify reporters in small communities)
- Automatic multi-agency routing (including chemical spill → EPA + Fire + NADMO + Police)
- Role-specific dashboards (municipal, agency, officer, emergency, police, research)
- Case assignment, investigation notes, field photos, escalation
- Expanded investigation statuses
- Agency performance and response-time monitoring
- Public announcements management
- Audit logs (super admin, append-only)
- Platform settings (super admin)
- In-app notifications (including emergency severity alerts)
- DBSCAN hotspot detection with a 30-day growth trend
- Researcher anonymized analytics and export

## Presentation

See **[docs/PRESENTATION.md](docs/PRESENTATION.md)** for a step-by-step demo script and talking points.

## Hosting (public website)

Deploy API + admin + Flutter web with HTTPS: **[docs/HOSTING.md](docs/HOSTING.md)**  
(Render blueprint: `render.yaml`, Docker: `Dockerfile`)

## Admin Portal

Officials sign in at http://localhost:3000/admin  

Demo emails and passwords (for review / screenshots only — **not shown on the login page**):  
**[docs/DEMO_ACCOUNTS.md](docs/DEMO_ACCOUNTS.md)**

## Getting Started

```bash
# Backend
cd backend
docker compose up -d postgres
npm install
npm run db:seed
npm run dev

# Flutter app
flutter pub get
flutter run
```

## Documentation

- [Presentation guide](docs/PRESENTATION.md)
- [Architecture](docs/ARCHITECTURE.md)
- [USSD Module](docs/USSD_MODULE.md)
- [Backend Recommendations](docs/BACKEND_RECOMMENDATIONS.md)
