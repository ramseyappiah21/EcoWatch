-- Routes each new report to super admin + assigned category officer
CREATE TABLE IF NOT EXISTS report_routing (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id         UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  recipient_role    VARCHAR(50) NOT NULL,
  recipient_user_id UUID REFERENCES users(id),
  category          VARCHAR(50) NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_report_routing_report_id ON report_routing(report_id);
CREATE INDEX IF NOT EXISTS idx_report_routing_recipient ON report_routing(recipient_user_id);
