-- Store reporter phone for USSD transactional SMS (token + status updates).
ALTER TABLE reports ADD COLUMN IF NOT EXISTS reporter_phone VARCHAR(30);
