# EcoWatch — Demo portal accounts

Seeded credentials for local demos, thesis screenshots, and examiner review.  
**Do not display these on the live login page.** They are created by `npm run db:seed` in `backend/`.

Portal URL (local): http://localhost:3000/admin

---

## Municipal / platform

| Email | Password | Role |
|-------|----------|------|
| `superadmin@ecowatch.gov` | `superadmin123` | Super Administrator (TNMA ICT) |
| `municipal@ecowatch.gov` | `municipal123` | Municipal Administrator |
| `researcher@ecowatch.gov` | `researcher123` | Researcher (anonymised view) |

---

## Agency administrators

| Email | Password | Agency |
|-------|----------|--------|
| `epa@ecowatch.gov` | `epa123` | EPA |
| `wrc@ecowatch.gov` | `wrc123` | Water Resources Commission |
| `nadmo@ecowatch.gov` | `nadmo123` | NADMO |
| `fire@ecowatch.gov` | `fire123` | Ghana National Fire Service |
| `forestry@ecowatch.gov` | `forestry123` | Forestry Commission |
| `waste@ecowatch.gov` | `waste123` | Municipal waste |
| `police@ecowatch.gov` | `police123` | Ghana Police Service |

---

## Field officers (My Cases)

Pattern: `{agency}.officer@ecowatch.gov` / `{agency}off123`

| Email | Password |
|-------|----------|
| `epa.officer@ecowatch.gov` | `epaoff123` |
| `wrc.officer@ecowatch.gov` | `wrcoff123` |
| `nadmo.officer@ecowatch.gov` | `nadmooff123` |
| `fire.officer@ecowatch.gov` | `fireoff123` |
| `forestry.officer@ecowatch.gov` | `forestryoff123` |
| `waste.officer@ecowatch.gov` | `wasteoff123` |
| `police.officer@ecowatch.gov` | `policeoff123` |

---

## Emergency officers

| Email | Password |
|-------|----------|
| `nadmo.emergency@ecowatch.gov` | `nadmoemg123` |
| `fire.emergency@ecowatch.gov` | `fireemg123` |

---

## Screenshot tips

| Capture | Suggested login |
|---------|-----------------|
| Admin incident desk | `municipal@ecowatch.gov` or `epa@ecowatch.gov` |
| Officer My Cases | `epa.officer@ecowatch.gov` |
| Emergency desk | `nadmo.emergency@ecowatch.gov` |
| Police desk | `police.officer@ecowatch.gov` |
| Researcher | `researcher@ecowatch.gov` |
| Audit / Settings | `superadmin@ecowatch.gov` |

---

## Production note

Before public hosting, change all passwords (or disable seed accounts) and issue real staff accounts via **Agencies & Users**.
