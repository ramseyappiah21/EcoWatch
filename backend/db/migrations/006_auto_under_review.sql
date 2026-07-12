-- New reports arrive under review; migrate legacy submitted rows.
ALTER TABLE reports ALTER COLUMN status SET DEFAULT 'underReview';

UPDATE reports SET status = 'underReview', updated_at = NOW()
WHERE status = 'submitted';

INSERT INTO report_status_history (report_id, status, message)
SELECT r.id, 'underReview', 'Report received — under review'
FROM reports r
WHERE r.status = 'underReview'
  AND NOT EXISTS (
    SELECT 1 FROM report_status_history h
    WHERE h.report_id = r.id AND h.status = 'underReview'
  );
