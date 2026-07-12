# Backend Technology Recommendations — EcoWatch

## Requirements Summary

| Requirement | Weight |
|-------------|--------|
| GIS / geospatial queries | High |
| Real-time report updates | High |
| AI model serving (optional cloud) | Medium |
| USSD webhook + SMS | High |
| Offline sync API | High |
| Scalability (municipal → national) | Medium |
| Cost (university → NGO budget) | High |
| Security / RBAC | High |
| Development speed | High |

---

## Option Comparison

### 1. Firebase (Firestore + Cloud Functions)

**Pros**
- Fastest MVP; real-time listeners for report tracking
- Built-in auth, push notifications (FCM)
- Cloud Functions for USSD webhook and SMS triggers
- Generous free tier for prototypes

**Cons**
- Geospatial queries limited (need GeoFirestore extension)
- Complex analytics queries expensive at scale
- Vendor lock-in; Ghana data residency concerns
- AI serving requires separate Vertex/GCF setup

**Best for**: Rapid prototype, small municipal deployment

---

### 2. Supabase (PostgreSQL + PostGIS + Edge Functions)

**Pros**
- PostgreSQL + **PostGIS** excellent for heatmaps and bounding-box queries
- Real-time subscriptions on report tables
- Row Level Security for RBAC
- Open source; self-hostable for data sovereignty
- Edge Functions for USSD webhooks

**Cons**
- Flutter SDK less mature than Firebase for offline
- AI model hosting still external
- Free tier limits on edge function invocations

**Best for**: GIS-heavy apps needing SQL analytics

---

### 3. Node.js + PostgreSQL + PostGIS

**Pros**
- Full control; Express/Fastify + Prisma/TypeORM
- PostGIS for hotspots, clustering, spatial indexes
- Easy Africa's Talking SDK integration
- Large ecosystem; hire-friendly

**Cons**
- More infrastructure to manage (API server, DB, Redis)
- Real-time requires Socket.io or separate service
- Security/auth built from scratch (Passport/JWT)

**Best for**: Teams comfortable with JS/TS DevOps

---

### 4. Django + PostgreSQL + PostGIS

**Pros**
- **GeoDjango** — first-class GIS support
- Admin panel out of the box (report moderation)
- Strong RBAC, ORM, migrations
- Python ecosystem for AI (TensorFlow serving, Celery workers)
- Excellent for university projects with Python familiarity

**Cons**
- Heavier than Node for simple APIs
- Real-time needs Django Channels
- Mobile team may prefer separate API docs (DRF)

**Best for**: GIS + admin + AI pipeline in one stack

---

### 5. Laravel + MySQL

**Pros**
- Rapid API development (Sanctum auth)
- Good documentation; popular in Ghana
- Queue system for SMS/offline sync jobs

**Cons**
- MySQL spatial support weaker than PostGIS
- AI/ML integration less natural than Python
- Real-time requires Laravel Reverb/Pusher

**Best for**: PHP teams; less ideal for heavy GIS

---

## Recommendation

### Primary: **Django + PostgreSQL + PostGIS**

**Why EcoWatch fits Django best:**

1. **GIS**: GeoDjango handles report coordinates, hotspot aggregation, and bounding-box queries natively — critical for Tarkwa heatmaps.
2. **AI integration**: Celery workers can run TensorFlow/PyTorch for server-side image verification alongside on-device TFLite.
3. **Admin dashboard**: Django Admin accelerates field officer workflows before building custom admin UI.
4. **University project**: Demonstrates full-stack competence; well-documented for thesis.
5. **Security**: Built-in auth, permissions, and audit logs align with RBAC requirements.
6. **USSD**: Simple webhook view + Africa's Talking Python SDK.

### Secondary: **Supabase** if team prefers managed infrastructure

Choose Supabase when you want PostgreSQL/PostGIS without server management and can accept vendor dependency.

### Avoid as primary: Firebase for this project

Real-time is attractive, but geospatial analytics, complex severity queries, and Ghana data governance favor PostgreSQL.

---

## Suggested API Structure (Backend-Agnostic)

```
POST   /v1/reports              # Submit report
GET    /v1/reports/track/:token # Track by token
PATCH  /v1/reports/:id/status   # Officer update
GET    /v1/maps/hotspots        # GeoJSON hotspots
GET    /v1/analytics?period=    # Dashboard data
POST   /v1/ussd/webhook         # Africa's Talking
POST   /v1/auth/login           # Official users
POST   /v1/sync/batch           # Offline batch upload
```

The Flutter app's `ApiClient` and `ApiEndpoints` are ready for this contract.

---

## Migration Path from Current Flutter App

1. Implement Django REST Framework API matching models in `lib/models/`
2. Create `DioReportRemoteDataSource implements ReportRemoteDataSource`
3. Swap providers in `dependency_injection.dart`
4. Add JWT interceptor to `ApiClient`
5. Enable FCM for push notifications
6. Deploy USSD webhook on same domain

No UI changes required — repository pattern isolates the swap.
