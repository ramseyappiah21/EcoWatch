-- Legacy migration (no-op). Super admin is required for the municipal platform (see 009).
-- Previous versions deleted super_admin here, which broke re-seeding when announcements
-- referenced that user. Kept as an ordered placeholder only.

SELECT 1;
