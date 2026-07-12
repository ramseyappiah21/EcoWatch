/**
 * Admin workflow statuses vs citizen-facing labels.
 *
 * Admin: received → underInvestigation → siteVisited → awaitingAction → resolved → closed
 * Legacy: underReview / inProgress still accepted and mapped.
 */

const ADMIN_STATUSES = [
  'received',
  'underInvestigation',
  'siteVisited',
  'awaitingAction',
  'resolved',
  'closed',
  // legacy aliases still stored in older rows
  'underReview',
  'inProgress',
];

const STATUS_LABELS = {
  received: 'Received',
  underReview: 'Received',
  underInvestigation: 'Under Investigation',
  inProgress: 'Under Investigation',
  siteVisited: 'Site Visited',
  awaitingAction: 'Awaiting Action',
  resolved: 'Resolved',
  closed: 'Closed',
};

/** Normalize legacy statuses to the current workflow. */
function normalizeStatus(status) {
  if (status === 'underReview' || status === 'submitted') return 'received';
  if (status === 'inProgress') return 'underInvestigation';
  return status;
}

const NEXT_ADMIN_STATUS = {
  submitted: 'received',
  received: 'underInvestigation',
  underReview: 'underInvestigation',
  underInvestigation: 'siteVisited',
  inProgress: 'siteVisited',
  siteVisited: 'awaitingAction',
  awaitingAction: 'resolved',
  resolved: 'closed',
  closed: null,
};

function nextAdminStatus(currentStatus) {
  const normalized = normalizeStatus(currentStatus);
  return NEXT_ADMIN_STATUS[currentStatus] ?? NEXT_ADMIN_STATUS[normalized] ?? null;
}

const CITIZEN_STATUS_MAP = {
  submitted: 'submitted',
  received: 'submitted',
  underReview: 'submitted',
  underInvestigation: 'inProgress',
  inProgress: 'inProgress',
  siteVisited: 'inProgress',
  awaitingAction: 'inProgress',
  resolved: 'completed',
  closed: 'completed',
};

const CITIZEN_STATUS_LABELS = {
  submitted: 'Submitted',
  inProgress: 'In Progress',
  completed: 'Completed',
};

function toCitizenStatus(adminStatus) {
  return CITIZEN_STATUS_MAP[adminStatus] || adminStatus;
}

function citizenStatusLabel(adminStatus) {
  return CITIZEN_STATUS_LABELS[toCitizenStatus(adminStatus)] || adminStatus;
}

function statusLabel(adminStatus) {
  return STATUS_LABELS[adminStatus] || adminStatus;
}

/** Agency leadership / municipal oversight approve closure — not field officers. */
function canCloseReport(user) {
  return [
    'super_admin',
    'municipal_admin',
    'agency_admin',
  ].includes(user?.role);
}

/** Field officers advance investigation actions after assignment (not agency/municipal admins). */
function canAdvanceInvestigation(user) {
  return [
    'environmental_officer',
    'emergency_officer',
    'police_support',
  ].includes(user?.role);
}

module.exports = {
  ADMIN_STATUSES,
  STATUS_LABELS,
  NEXT_ADMIN_STATUS,
  nextAdminStatus,
  normalizeStatus,
  toCitizenStatus,
  citizenStatusLabel,
  statusLabel,
  canCloseReport,
  canAdvanceInvestigation,
};
