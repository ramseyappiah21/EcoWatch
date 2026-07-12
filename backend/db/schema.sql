-- EcoWatch Tarkwa — PostgreSQL schema (PostgreSQL 15+)
-- Enable PostGIS for geospatial queries: CREATE EXTENSION postgis;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE roles (
  id          SERIAL PRIMARY KEY,
  name        VARCHAR(50) NOT NULL UNIQUE,
  label       VARCHAR(100) NOT NULL,
  description TEXT,
  can_view    BOOLEAN NOT NULL DEFAULT TRUE,
  can_update  BOOLEAN NOT NULL DEFAULT FALSE,
  can_export  BOOLEAN NOT NULL DEFAULT FALSE,
  can_manage_users BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO roles (name, label, description, can_view, can_update, can_export, can_manage_users) VALUES
  ('super_admin', 'Super Administrator', 'Municipal Assembly ICT — full platform access', TRUE, TRUE, TRUE, TRUE),
  ('municipal_admin', 'Municipal Administrator', 'Municipality-wide monitoring and agency coordination', TRUE, TRUE, TRUE, TRUE),
  ('agency_admin', 'Agency Administrator', 'Manages incidents routed to their agency mandate', TRUE, TRUE, TRUE, FALSE),
  ('environmental_officer', 'Environmental Officer', 'Field investigator for assigned incidents', TRUE, TRUE, FALSE, FALSE),
  ('emergency_officer', 'Emergency Response Officer', 'Emergency incidents for Fire Service and NADMO', TRUE, TRUE, FALSE, FALSE),
  ('police_support', 'Police Support', 'Law enforcement support for criminal environmental offences', TRUE, TRUE, FALSE, FALSE),
  ('researcher', 'Researcher', 'Anonymized analytics and research export', TRUE, FALSE, TRUE, FALSE),
  ('citizen', 'Citizen', 'Registered citizen reporter', TRUE, FALSE, FALSE, FALSE)
ON CONFLICT (name) DO NOTHING;

CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  display_name  VARCHAR(120) NOT NULL,
  role_id       INTEGER NOT NULL REFERENCES roles(id),
  assigned_category VARCHAR(50),
  assigned_agency VARCHAR(50),
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_login_at TIMESTAMPTZ
);

-- Multiple staff per agency (admins + officers + emergency)
CREATE INDEX IF NOT EXISTS idx_users_assigned_category ON users(assigned_category);
CREATE INDEX IF NOT EXISTS idx_users_assigned_agency ON users(assigned_agency);

CREATE TABLE reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tracking_token  VARCHAR(20) NOT NULL UNIQUE,
  category        VARCHAR(50) NOT NULL,
  title           VARCHAR(255),
  description     TEXT NOT NULL,
  latitude        DOUBLE PRECISION NOT NULL,
  longitude       DOUBLE PRECISION NOT NULL,
  accuracy_meters DOUBLE PRECISION,
  address         TEXT,
  landmark        TEXT,
  community_name  VARCHAR(120),
  status          VARCHAR(30) NOT NULL DEFAULT 'underReview',
  severity        VARCHAR(20) NOT NULL DEFAULT 'low',
  severity_score  SMALLINT NOT NULL DEFAULT 0 CHECK (severity_score BETWEEN 0 AND 6),
  source          VARCHAR(10) NOT NULL DEFAULT 'app' CHECK (source IN ('app', 'ussd')),
  is_anonymous    BOOLEAN NOT NULL DEFAULT TRUE,
  water_body_nearby BOOLEAN NOT NULL DEFAULT FALSE,
  reporter_id     UUID REFERENCES users(id),
  reporter_phone  VARCHAR(30),
  ai_suggested_category VARCHAR(50),
  ai_confidence   DOUBLE PRECISION,
  sync_status     VARCHAR(20) NOT NULL DEFAULT 'synced',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reports_tracking_token ON reports(tracking_token);
CREATE INDEX idx_reports_status ON reports(status);
CREATE INDEX idx_reports_created_at ON reports(created_at DESC);
CREATE INDEX idx_reports_location ON reports(latitude, longitude);
CREATE INDEX idx_reports_category ON reports(category);

CREATE TABLE report_media (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id     UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  media_type    VARCHAR(10) NOT NULL CHECK (media_type IN ('photo', 'video', 'audio')),
  storage_url   TEXT NOT NULL,
  mime_type     VARCHAR(80),
  file_size_bytes BIGINT,
  ai_predicted_category VARCHAR(50),
  ai_confidence DOUBLE PRECISION,
  ai_model_version VARCHAR(50),
  captured_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_report_media_report_id ON report_media(report_id);

CREATE TABLE report_status_history (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id   UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  status      VARCHAR(30) NOT NULL,
  message     TEXT,
  updated_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_status_history_report_id ON report_status_history(report_id);

CREATE TABLE announcements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       VARCHAR(200) NOT NULL,
  body        TEXT NOT NULL,
  is_public   BOOLEAN NOT NULL DEFAULT TRUE,
  published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at  TIMESTAMPTZ,
  created_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE emergency_contacts (
  id          SERIAL PRIMARY KEY,
  name        VARCHAR(120) NOT NULL,
  agency      VARCHAR(120) NOT NULL,
  phone       VARCHAR(30) NOT NULL,
  description TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO emergency_contacts (name, agency, phone, description, sort_order) VALUES
  ('NADMO', 'National Disaster Management Organisation', '0302-772926', 'Disaster and emergency response', 1),
  ('Ghana Fire Service', 'Fire Service', '192', 'Fire emergencies', 2),
  ('EPA Ghana', 'Environmental Protection Agency', '0302-664697', 'Environmental enforcement', 3);

CREATE TABLE hotspots (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id     VARCHAR(50) NOT NULL UNIQUE,
  latitude        DOUBLE PRECISION NOT NULL,
  longitude       DOUBLE PRECISION NOT NULL,
  report_count    INTEGER NOT NULL,
  density_score   DOUBLE PRECISION NOT NULL,
  priority        VARCHAR(20) NOT NULL,
  dominant_category VARCHAR(50),
  radius_meters   DOUBLE PRECISION NOT NULL DEFAULT 1000,
  detected_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  window_start    TIMESTAMPTZ NOT NULL,
  window_end      TIMESTAMPTZ NOT NULL
);

CREATE TABLE ussd_sessions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id   VARCHAR(120) NOT NULL,
  phone_hash   VARCHAR(128) NOT NULL,
  payload      JSONB,
  report_id    UUID REFERENCES reports(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE report_routing (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id         UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  recipient_role    VARCHAR(50) NOT NULL,
  recipient_user_id UUID REFERENCES users(id),
  category          VARCHAR(50) NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_report_routing_report_id ON report_routing(report_id);
CREATE INDEX idx_report_routing_recipient ON report_routing(recipient_user_id);
